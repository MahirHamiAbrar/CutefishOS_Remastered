/*
 * Cutefish Network Monitor
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#include "monitor.h"

#include <QCryptographicHash>
#include <QDir>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QQuickWindow>
#include <QRegularExpression>
#include <QDeadlineTimer>
#include <QStandardPaths>

// The prompt counts down in QML; the gRPC side waits a little longer so the
// user's own answer always wins the race.
static constexpr auto PromptTimeout = std::chrono::seconds(30);
static constexpr size_t MaxEvents = 5000;
static constexpr qint64 MaxLogSize = 20 * 1024 * 1024;

static Monitor *s_self = nullptr;

static QString qs(const std::string &s)
{
    return QString::fromStdString(s);
}

static QString eventKey(const protocol::Event &e)
{
    const auto &c = e.connection();
    return QStringLiteral("%1|%2|%3|%4|%5").arg(e.unixnano()).arg(c.process_id())
        .arg(qs(c.dst_ip())).arg(c.dst_port()).arg(c.src_port());
}

Monitor::Monitor(QObject *parent)
    : QObject(parent)
{
    s_self = this;

    const QString dir = QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation)
        + QStringLiteral("/cutefish/netmonitor");
    QDir().mkpath(dir);
    const QString path = dir + QStringLiteral("/connections.log");
    // ponytail: one rotated generation; switch to a real log rotation if 20 MB x2 is too small.
    if (QFileInfo(path).size() > MaxLogSize) {
        QFile::remove(path + QStringLiteral(".1"));
        QFile::rename(path, path + QStringLiteral(".1"));
    }
    m_log.setFileName(path);
    m_log.open(QIODevice::Append | QIODevice::Text);
}

Monitor::~Monitor()
{
    s_self = nullptr;
}

Monitor *Monitor::self()
{
    return s_self;
}

void Monitor::ping(const protocol::Statistics &stats)
{
    QMutexLocker locker(&m_lock);
    m_lastPing = QDateTime::currentDateTime();
    m_stats = stats;

    // The daemon resends its last events on every ping; keep each one once.
    // Events arrive oldest first.
    for (const protocol::Event &event : stats.events()) {
        const QString key = eventKey(event);
        if (m_seenEvents.contains(key))
            continue;
        m_seenEvents.insert(key);
        m_events.push_front(event);
        appendToLog(event);
    }
    while (m_events.size() > MaxEvents) {
        m_seenEvents.remove(eventKey(m_events.back()));
        m_events.pop_back();
    }
    m_stats.clear_events();
}

void Monitor::appendToLog(const protocol::Event &event)
{
    if (!m_log.isOpen())
        return;
    const auto &c = event.connection();
    const QString line = QStringLiteral("%1\t%2\t%3\t%4\t%5\t%6\t%7:%8\t%9\n")
        .arg(qs(event.time()), qs(event.rule().action()), qs(event.rule().name()),
             qs(c.process_path()), QString::number(c.process_id()), qs(c.protocol()),
             qs(c.dst_host()).isEmpty() ? qs(c.dst_ip()) : qs(c.dst_host()),
             QString::number(c.dst_port()), qs(c.dst_ip()));
    m_log.write(line.toUtf8());
    m_log.flush();
}

void Monitor::subscribed(const protocol::ClientConfig &config)
{
    QMutexLocker locker(&m_lock);
    m_rules.clear();
    for (const protocol::Rule &rule : config.rules())
        m_rules.insert(qs(rule.name()), rule);
    m_lastPing = QDateTime::currentDateTime();
}

void Monitor::alert(const protocol::Alert &alert)
{
    qInfo() << "opensnitch alert:" << qs(alert.text());
}

protocol::Rule Monitor::ask(const protocol::Connection &connection)
{
    auto reply = std::make_shared<std::promise<protocol::Rule>>();
    std::future<protocol::Rule> answer = reply->get_future();

    QMetaObject::invokeMethod(this, [this, connection, reply] {
        m_pending.push_back({m_nextRequestId++, connection, reply});
        if (m_pending.size() == 1)
            showNextPrompt();
    }, Qt::QueuedConnection);

    if (answer.wait_for(PromptTimeout + std::chrono::seconds(5)) == std::future_status::ready)
        return answer.get();

    // Nobody answered: deny this one connection and ask again next time.
    return makeRule(connection, QStringLiteral("deny"), QStringLiteral("once"), QStringLiteral("process-host"));
}

void Monitor::showNextPrompt()
{
    if (m_pending.empty()) {
        if (m_prompt)
            m_prompt->hide();
        return;
    }

    if (!m_engine) {
        m_engine = new QQmlEngine(this);
        m_engine->rootContext()->setContextProperty(QStringLiteral("monitor"), this);
        QQmlComponent component(m_engine, QUrl(QStringLiteral("qrc:/qml/Prompt.qml")));
        m_prompt = qobject_cast<QQuickWindow *>(component.create());
        if (!m_prompt) {
            qWarning() << "cannot create prompt:" << component.errors();
            // Without a prompt every pending connection is denied once.
            for (Pending &p : m_pending)
                p.reply->set_value(makeRule(p.connection, "deny", "once", "process-host"));
            m_pending.clear();
            return;
        }
    }

    const Pending &p = m_pending.front();
    const auto &c = p.connection;
    const QString path = qs(c.process_path());
    m_prompt->setProperty("requestId", p.id);
    m_prompt->setProperty("processPath", path);
    m_prompt->setProperty("appName", path.isEmpty() ? tr("Unknown process") : QFileInfo(path).fileName());
    m_prompt->setProperty("pid", c.process_id());
    m_prompt->setProperty("uid", c.user_id());
    m_prompt->setProperty("host", qs(c.dst_host()));
    m_prompt->setProperty("ip", qs(c.dst_ip()));
    m_prompt->setProperty("port", c.dst_port());
    m_prompt->setProperty("protocol", qs(c.protocol()));
    m_prompt->setProperty("queued", int(m_pending.size()) - 1);
    QMetaObject::invokeMethod(m_prompt, "restart");
    m_prompt->show();
    m_prompt->raise();
    m_prompt->requestActivate();
}

void Monitor::answer(int requestId, const QString &action, const QString &duration, const QString &scope)
{
    if (m_pending.empty() || m_pending.front().id != requestId)
        return;

    Pending p = m_pending.front();
    m_pending.pop_front();

    const protocol::Rule rule = makeRule(p.connection, action, duration, scope);
    p.reply->set_value(rule);

    if (rule.duration() != "once") {
        QMutexLocker locker(&m_lock);
        m_rules.insert(qs(rule.name()), rule);
    }

    showNextPrompt();
}

protocol::Rule Monitor::makeRule(const protocol::Connection &c, const QString &action,
                                 const QString &duration, const QString &scope)
{
    auto simple = [](const char *operand, const std::string &data) {
        protocol::Operator op;
        op.set_type("simple");
        op.set_operand(operand);
        op.set_data(data);
        op.set_sensitive(false);
        return op;
    };

    const bool hasProcess = !c.process_path().empty();
    const protocol::Operator process = simple("process.path", c.process_path());
    const protocol::Operator destination = c.dst_host().empty() ? simple("dest.ip", c.dst_ip())
                                                                : simple("dest.host", c.dst_host());

    protocol::Rule rule;
    protocol::Operator *op = rule.mutable_operator_();
    QString what;
    if (scope == QLatin1String("process") && hasProcess) {
        *op = process;
        what = qs(c.process_path());
    } else if (scope == QLatin1String("host") || !hasProcess) {
        *op = destination;
        what = qs(destination.data());
    } else {
        // "This app to this host", the default: a list operator. The daemon
        // reads the list; data carries the same list as JSON for its rule files.
        op->set_type("list");
        op->set_operand("list");
        *op->add_list() = process;
        *op->add_list() = destination;
        QJsonArray list;
        for (const protocol::Operator &o : {process, destination}) {
            list.append(QJsonObject{{"type", qs(o.type())}, {"operand", qs(o.operand())},
                                    {"data", qs(o.data())}, {"sensitive", false}});
        }
        op->set_data(QJsonDocument(list).toJson(QJsonDocument::Compact).toStdString());
        what = qs(c.process_path()) + QLatin1Char('>') + qs(destination.data());
    }

    const QString durationValue = duration == QLatin1String("always") ? QStringLiteral("always")
                                : duration == QLatin1String("restart") ? QStringLiteral("until restart")
                                                                       : QStringLiteral("once");
    const QString slug = QFileInfo(what.section(QLatin1Char('>'), 0, 0)).fileName().toLower()
                             .replace(QRegularExpression(QStringLiteral("[^a-z0-9.-]")), QStringLiteral("-"));
    const QString hash = QString::fromLatin1(QCryptographicHash::hash(what.toUtf8(), QCryptographicHash::Md5).toHex().left(8));

    rule.set_name(QStringLiteral("cutefish-%1-%2-%3").arg(action, slug, hash).toStdString());
    rule.set_description(what.toStdString());
    rule.set_enabled(true);
    rule.set_precedence(false);
    rule.set_nolog(false);
    rule.set_action(action.toStdString());
    rule.set_duration(durationValue.toStdString());
    rule.set_created(QDateTime::currentSecsSinceEpoch());
    return rule;
}

bool Monitor::nextNotification(protocol::Notification *notification, std::chrono::milliseconds timeout)
{
    QMutexLocker locker(&m_lock);
    if (m_outbox.empty())
        m_notificationReady.wait(&m_lock, QDeadlineTimer(timeout));
    if (m_outbox.empty())
        return false;
    *notification = std::move(m_outbox.front());
    m_outbox.pop_front();
    return true;
}

void Monitor::streamClosed()
{
    qInfo() << "opensnitch notification stream closed";
}

// Caller holds m_lock.
void Monitor::queueNotification(protocol::Notification notification)
{
    notification.set_id(++m_notificationId);
    m_outbox.push_back(std::move(notification));
    m_notificationReady.wakeAll();
}

bool Monitor::DaemonConnected() const
{
    QMutexLocker locker(&m_lock);
    return m_lastPing.isValid() && m_lastPing.secsTo(QDateTime::currentDateTime()) < 15;
}

bool Monitor::InterceptionEnabled() const
{
    QMutexLocker locker(&m_lock);
    return m_interception;
}

QString Monitor::Stats() const
{
    QMutexLocker locker(&m_lock);
    const QJsonObject o{
        {"daemonVersion", qs(m_stats.daemon_version())},
        {"uptime", qint64(m_stats.uptime())},
        {"connections", qint64(m_stats.connections())},
        {"accepted", qint64(m_stats.accepted())},
        {"dropped", qint64(m_stats.dropped())},
        {"ignored", qint64(m_stats.ignored())},
        {"rules", qint64(m_stats.rules())},
    };
    return QString::fromUtf8(QJsonDocument(o).toJson(QJsonDocument::Compact));
}

QString Monitor::Connections(int limit) const
{
    QMutexLocker locker(&m_lock);
    QJsonArray list;
    for (const protocol::Event &e : m_events) {
        if (limit > 0 && list.size() >= limit)
            break;
        const auto &c = e.connection();
        list.append(QJsonObject{
            {"time", qs(e.time())},
            {"action", qs(e.rule().action())},
            {"rule", qs(e.rule().name())},
            {"process", qs(c.process_path())},
            {"pid", qint64(c.process_id())},
            {"uid", qint64(c.user_id())},
            {"protocol", qs(c.protocol())},
            {"host", qs(c.dst_host())},
            {"ip", qs(c.dst_ip())},
            {"port", qint64(c.dst_port())},
        });
    }
    return QString::fromUtf8(QJsonDocument(list).toJson(QJsonDocument::Compact));
}

QString Monitor::Rules() const
{
    QMutexLocker locker(&m_lock);
    QJsonArray list;
    for (const protocol::Rule &r : m_rules) {
        list.append(QJsonObject{
            {"name", qs(r.name())},
            {"description", qs(r.description())},
            {"action", qs(r.action())},
            {"duration", qs(r.duration())},
            {"enabled", r.enabled()},
            {"operand", qs(r.operator_().operand())},
            {"data", r.operator_().type() == "list" ? qs(r.description()) : qs(r.operator_().data())},
        });
    }
    return QString::fromUtf8(QJsonDocument(list).toJson(QJsonDocument::Compact));
}

void Monitor::DeleteRule(const QString &name)
{
    QMutexLocker locker(&m_lock);
    const auto it = m_rules.constFind(name);
    if (it == m_rules.constEnd())
        return;
    protocol::Notification n;
    n.set_type(protocol::DELETE_RULE);
    *n.add_rules() = it.value();
    m_rules.erase(it);
    queueNotification(std::move(n));
}

void Monitor::SetRuleAction(const QString &name, const QString &action)
{
    if (action != QLatin1String("allow") && action != QLatin1String("deny") && action != QLatin1String("reject"))
        return;
    QMutexLocker locker(&m_lock);
    auto it = m_rules.find(name);
    if (it == m_rules.end())
        return;
    it->set_action(action.toStdString());
    protocol::Notification n;
    n.set_type(protocol::CHANGE_RULE);
    *n.add_rules() = it.value();
    queueNotification(std::move(n));
}

void Monitor::SetInterception(bool enabled)
{
    QMutexLocker locker(&m_lock);
    m_interception = enabled;
    protocol::Notification n;
    n.set_type(enabled ? protocol::ENABLE_INTERCEPTION : protocol::DISABLE_INTERCEPTION);
    queueNotification(std::move(n));
}

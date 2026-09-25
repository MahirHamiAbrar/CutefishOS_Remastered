/*
 * Cutefish Network Monitor
 *
 * Holds what the OpenSnitch daemon tells the UI (connections, rules,
 * statistics), asks the user about new connections and publishes it all on
 * D-Bus (com.cutefish.NetMonitor) for the Settings page.
 *
 * The gRPC service runs on its own threads and calls in here; everything the
 * GUI or D-Bus touches is guarded by m_lock.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#ifndef MONITOR_H
#define MONITOR_H

#include "ui.pb.h"

#include <QDateTime>
#include <QFile>
#include <QHash>
#include <QMutex>
#include <QObject>
#include <QSet>
#include <QWaitCondition>

#include <chrono>
#include <deque>
#include <future>
#include <memory>

class QQmlEngine;
class QQuickWindow;

class Monitor : public QObject
{
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "com.cutefish.NetMonitor")

public:
    explicit Monitor(QObject *parent = nullptr);
    ~Monitor() override;

    static Monitor *self();

    // --- called from gRPC threads ---
    void ping(const protocol::Statistics &stats);
    void subscribed(const protocol::ClientConfig &config);
    void alert(const protocol::Alert &alert);
    //! Blocks until the user answers or the prompt times out.
    protocol::Rule ask(const protocol::Connection &connection);
    //! Waits up to @p timeout for a command to send to the daemon.
    bool nextNotification(protocol::Notification *notification, std::chrono::milliseconds timeout);
    void streamClosed();

    // --- used by the prompt window ---
    Q_INVOKABLE void answer(int requestId, const QString &action, const QString &duration, const QString &scope);

public Q_SLOTS:
    // --- D-Bus API (JSON strings keep the Settings side trivial) ---
    Q_SCRIPTABLE bool DaemonConnected() const;
    Q_SCRIPTABLE bool InterceptionEnabled() const;
    Q_SCRIPTABLE QString Stats() const;
    //! Most recent connections first: [{time, action, rule, process, pid, uid, protocol, host, ip, port}].
    Q_SCRIPTABLE QString Connections(int limit) const;
    //! [{name, action, duration, enabled, operand, data}]
    Q_SCRIPTABLE QString Rules() const;
    Q_SCRIPTABLE void DeleteRule(const QString &name);
    Q_SCRIPTABLE void SetRuleAction(const QString &name, const QString &action);
    Q_SCRIPTABLE void SetInterception(bool enabled);

private:
    struct Pending {
        int id;
        protocol::Connection connection;
        std::shared_ptr<std::promise<protocol::Rule>> reply;
    };

    void showNextPrompt();
    void queueNotification(protocol::Notification notification);
    static protocol::Rule makeRule(const protocol::Connection &c, const QString &action,
                                   const QString &duration, const QString &scope);
    void appendToLog(const protocol::Event &event);

    mutable QMutex m_lock;
    QWaitCondition m_notificationReady;

    // Guarded by m_lock.
    std::deque<protocol::Event> m_events;
    QSet<QString> m_seenEvents;
    QHash<QString, protocol::Rule> m_rules;
    protocol::Statistics m_stats;
    std::deque<protocol::Notification> m_outbox;
    QDateTime m_lastPing;
    bool m_interception = true;
    quint64 m_notificationId = 0;

    // GUI thread only.
    std::deque<Pending> m_pending;
    int m_nextRequestId = 1;
    QQmlEngine *m_engine = nullptr;
    QQuickWindow *m_prompt = nullptr;
    QFile m_log;
};

#endif // MONITOR_H

/*
 * Cutefish Network Monitor
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#include "uiservice.h"
#include "monitor.h"

#include <QDebug>

#include <atomic>
#include <thread>

using grpc::ServerContext;
using grpc::Status;

Status UiService::Ping(ServerContext *, const protocol::PingRequest *request, protocol::PingReply *reply)
{
    Monitor::self()->ping(request->stats());
    reply->set_id(request->id());
    return Status::OK;
}

Status UiService::AskRule(ServerContext *, const protocol::Connection *connection, protocol::Rule *rule)
{
    *rule = Monitor::self()->ask(*connection);
    return Status::OK;
}

Status UiService::Subscribe(ServerContext *, const protocol::ClientConfig *config, protocol::ClientConfig *reply)
{
    Monitor::self()->subscribed(*config);
    *reply = *config;
    return Status::OK;
}

Status UiService::Notifications(ServerContext *context,
                                grpc::ServerReaderWriter<protocol::Notification, protocol::NotificationReply> *stream)
{
    // The daemon keeps this stream open for as long as it is connected: we
    // write commands (rule changes, interception on/off) and it answers each
    // with a NotificationReply. One reader thread, one writer (this thread).
    std::atomic<bool> closed = false;
    std::thread reader([&] {
        protocol::NotificationReply reply;
        while (stream->Read(&reply)) {
            if (reply.code() != protocol::OK)
                qWarning() << "opensnitch rejected command" << reply.id() << QString::fromStdString(reply.data());
        }
        closed = true;
    });

    while (!closed && !context->IsCancelled()) {
        protocol::Notification notification;
        if (Monitor::self()->nextNotification(&notification, std::chrono::milliseconds(500))
            && !stream->Write(notification))
            break;
    }

    context->TryCancel();
    reader.join();
    Monitor::self()->streamClosed();
    return Status::OK;
}

Status UiService::PostAlert(ServerContext *, const protocol::Alert *alert, protocol::MsgResponse *reply)
{
    Monitor::self()->alert(*alert);
    reply->set_id(alert->id());
    return Status::OK;
}

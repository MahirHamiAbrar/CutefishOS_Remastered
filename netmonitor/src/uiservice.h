/*
 * Cutefish Network Monitor: the gRPC "UI" service the OpenSnitch daemon
 * connects to. Thin: every call is handed to Monitor.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#ifndef UISERVICE_H
#define UISERVICE_H

#include "ui.grpc.pb.h"

class UiService final : public protocol::UI::Service
{
public:
    grpc::Status Ping(grpc::ServerContext *, const protocol::PingRequest *request,
                      protocol::PingReply *reply) override;
    grpc::Status AskRule(grpc::ServerContext *, const protocol::Connection *connection,
                         protocol::Rule *rule) override;
    grpc::Status Subscribe(grpc::ServerContext *, const protocol::ClientConfig *config,
                           protocol::ClientConfig *reply) override;
    grpc::Status Notifications(grpc::ServerContext *context,
                               grpc::ServerReaderWriter<protocol::Notification, protocol::NotificationReply> *stream) override;
    grpc::Status PostAlert(grpc::ServerContext *, const protocol::Alert *alert,
                           protocol::MsgResponse *reply) override;
};

#endif // UISERVICE_H

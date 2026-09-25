/*
 * Cutefish Network Monitor
 *
 * Replaces OpenSnitch's Python UI in the Cutefish session: serves the gRPC
 * endpoint the opensnitchd daemon connects to, asks about new outgoing
 * connections with a FishUI prompt and publishes connections and rules on
 * D-Bus for the Settings "Network Monitor" page.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

#include "monitor.h"
#include "uiservice.h"

#include <QDBusConnection>
#include <QGuiApplication>

#include <grpcpp/grpcpp.h>

// Must match "Server.Address" in /etc/opensnitchd/default-config.json.
static const char *ListenAddress = "unix:///tmp/osui.sock";

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("cutefish-netmonitor"));
    app.setDesktopFileName(QStringLiteral("cutefish-netmonitor"));
    app.setQuitOnLastWindowClosed(false);

    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerService(QStringLiteral("com.cutefish.NetMonitor"))) {
        qInfo("cutefish-netmonitor is already running");
        return 0;
    }

    Monitor monitor;
    bus.registerObject(QStringLiteral("/NetMonitor"), &monitor,
                       QDBusConnection::ExportScriptableSlots);

    UiService service;
    grpc::ServerBuilder builder;
    builder.AddListeningPort(ListenAddress, grpc::InsecureServerCredentials());
    builder.RegisterService(&service);
    std::unique_ptr<grpc::Server> server = builder.BuildAndStart();
    if (!server) {
        qCritical("cutefish-netmonitor: cannot listen on %s", ListenAddress);
        return 1;
    }
    qInfo("cutefish-netmonitor: listening on %s", ListenAddress);

    const int ret = app.exec();
    server->Shutdown(std::chrono::system_clock::now() + std::chrono::seconds(1));
    return ret;
}

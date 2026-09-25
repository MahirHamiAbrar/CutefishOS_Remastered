/*
 * Cutefish Network Monitor: "an app wants to connect" prompt.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window
import FishUI 1.0 as FishUI

FishUI.Window {
    id: root

    // Fixed size: a height bound to the layout's implicit height collapsed to
    // the title bar on KWin Wayland.
    width: 480
    height: 300
    minimumWidth: width
    maximumWidth: width
    minimumHeight: height
    maximumHeight: height
    visible: false
    minimizeButtonVisible: false
    flags: Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint
    title: qsTr("Network Monitor")

    property int requestId: 0
    property string processPath
    property string appName
    property int pid: 0
    property int uid: 0
    property string host
    property string ip
    property int port: 0
    property string protocol
    property int queued: 0

    readonly property int timeout: 30
    property int remaining: timeout

    readonly property string destination: host !== "" ? host : ip

    // Called by Monitor for every new request.
    function restart() {
        remaining = timeout
        _scope.currentIndex = processPath !== "" ? 0 : 2
        _duration.currentIndex = 2
        _countdown.restart()
    }

    function reply(action) {
        _countdown.stop()
        var scopes = ["process-host", "process", "host"]
        var durations = ["once", "restart", "always"]
        monitor.answer(requestId, action, durations[_duration.currentIndex], scopes[_scope.currentIndex])
    }

    // Closing the window is a "deny once", like the timeout.
    onClosing: function(close) {
        close.accepted = false
        _duration.currentIndex = 0
        reply("deny")
    }

    Timer {
        id: _countdown
        interval: 1000
        repeat: true
        onTriggered: {
            if (--root.remaining <= 0) {
                _duration.currentIndex = 0
                root.reply("deny")
            }
        }
    }

    ColumnLayout {
        id: _layout
        anchors.fill: parent
        anchors.margins: FishUI.Units.largeSpacing
        anchors.topMargin: 0
        spacing: FishUI.Units.largeSpacing

        RowLayout {
            spacing: FishUI.Units.largeSpacing

            Image {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                sourceSize: Qt.size(48, 48)
                source: "image://icontheme/" + (root.appName !== "" ? root.appName.toLowerCase() : "network-wired")
                onStatusChanged: if (status === Image.Error) source = "image://icontheme/application-x-executable"
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: FishUI.Units.smallSpacing / 2

                Label {
                    text: qsTr("%1 wants to connect to %2").arg(root.appName).arg(root.destination)
                    font.bold: true
                    wrapMode: Text.WrapAnywhere
                    Layout.fillWidth: true
                }

                Label {
                    text: qsTr("%1 %2 port %3").arg(root.protocol.toUpperCase()).arg(root.ip).arg(root.port)
                    color: FishUI.Theme.disabledTextColor
                    Layout.fillWidth: true
                }

                Label {
                    text: root.processPath !== "" ? qsTr("%1 (pid %2, uid %3)").arg(root.processPath).arg(root.pid).arg(root.uid)
                                                  : qsTr("Kernel or unknown process")
                    color: FishUI.Theme.disabledTextColor
                    elide: Text.ElideMiddle
                    Layout.fillWidth: true
                }
            }
        }

        GridLayout {
            columns: 2
            columnSpacing: FishUI.Units.largeSpacing
            Layout.fillWidth: true

            Label { text: qsTr("Apply to") }
            ComboBox {
                id: _scope
                Layout.fillWidth: true
                model: [qsTr("This app connecting to %1").arg(root.destination),
                        qsTr("This app connecting anywhere"),
                        qsTr("Any app connecting to %1").arg(root.destination)]
            }

            Label { text: qsTr("Remember") }
            ComboBox {
                id: _duration
                Layout.fillWidth: true
                model: [qsTr("Just this once"), qsTr("Until restart"), qsTr("Forever")]
            }
        }

        RowLayout {
            spacing: FishUI.Units.largeSpacing

            Label {
                text: root.queued > 0 ? qsTr("Denied in %1 s · %2 more waiting").arg(root.remaining).arg(root.queued)
                                      : qsTr("Denied in %1 s").arg(root.remaining)
                color: FishUI.Theme.disabledTextColor
                Layout.fillWidth: true
            }

            Button {
                text: qsTr("Deny")
                onClicked: root.reply("deny")
            }

            Button {
                text: qsTr("Allow")
                flat: true
                onClicked: root.reply("allow")
            }
        }
    }
}

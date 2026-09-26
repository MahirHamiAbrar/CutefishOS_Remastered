/*
 * Cutefish lock screen for kscreenlocker (Plasma/Shell package
 * "org.cutefish.desktop", chosen through PLASMA_DEFAULT_SHELL).
 *
 * kscreenlocker's built-in fallback theme imports Plasma workspace modules
 * that Cutefish doesn't ship, so without this package the greeter crashed in
 * a loop and the session could not be unlocked. This theme only uses stock
 * Qt Quick modules and the objects the greeter provides: authenticator,
 * kscreenlocker_userName and kscreenlocker_userImage. The look follows the
 * Cutefish SDDM theme.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * any later version.
 */

import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Layouts

Item {
    id: root

    // Set by the greeter.
    property bool locked: false
    property bool capsLockOn: false
    property string notification: ""

    signal unlockRequested()

    function unlock() {
        root.notification = ""
        authenticator.startAuthenticating()
    }

    Image {
        id: wallpaper
        anchors.fill: parent
        // Oversized, so the blur doesn't darken the screen edges.
        anchors.margins: -64
        // ponytail: the default wallpaper, not the user's; the greeter has no
        // Cutefish wallpaper setting to read. Pass it in if users ask.
        source: "file:///usr/share/backgrounds/cutefishos/default.jpg"
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)
        visible: false
    }

    MultiEffect {
        anchors.fill: wallpaper
        source: wallpaper
        blurEnabled: true
        blurMax: 64
        blur: 1.0
        brightness: -0.1
    }

    Rectangle {
        // Fallback when the wallpaper file is missing.
        anchors.fill: parent
        color: "#3a4a5c"
        visible: wallpaper.status !== Image.Ready
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: card.top
        anchors.bottomMargin: root.height * 0.1
        spacing: 8

        Label {
            id: timeLabel
            Layout.alignment: Qt.AlignHCenter
            font.pointSize: 35
            color: "white"
        }

        Label {
            id: dateLabel
            Layout.alignment: Qt.AlignHCenter
            font.pointSize: 19
            color: "white"
        }

        Timer {
            running: true
            repeat: true
            triggeredOnStart: true
            interval: 1000
            onTriggered: {
                const now = new Date()
                timeLabel.text = now.toLocaleString(Qt.locale(), "hh:mm")
                dateLabel.text = now.toLocaleDateString(Qt.locale(), Locale.LongFormat)
            }
        }
    }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: 260 + 48
        height: cardLayout.implicitHeight + 48
        radius: 14
        color: Qt.rgba(1, 1, 1, 0.5)

        ColumnLayout {
            id: cardLayout
            anchors.fill: parent
            anchors.margins: 24
            spacing: 12

            Image {
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 72
                Layout.preferredHeight: 72
                source: kscreenlocker_userImage ? kscreenlocker_userImage : "image://icontheme/default-user"
                sourceSize: Qt.size(144, 144)
                fillMode: Image.PreserveAspectCrop
            }

            Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.maximumWidth: 260
                elide: Text.ElideRight
                text: kscreenlocker_userName
                font.pointSize: 13
                color: "black"
            }

            TextField {
                id: password
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 260
                Layout.preferredHeight: 40
                placeholderText: qsTr("Password")
                echoMode: TextInput.Password
                focus: true
                enabled: !authenticator.busy
                background: Rectangle {
                    color: "white"
                    radius: 10
                    opacity: 0.6
                }
                Keys.onReturnPressed: root.unlock()
                Keys.onEnterPressed: root.unlock()
                Keys.onEscapePressed: text = ""
            }

            Button {
                id: unlockButton
                Layout.alignment: Qt.AlignHCenter
                Layout.preferredWidth: 260
                Layout.preferredHeight: 40
                text: qsTr("Unlock")
                focusPolicy: Qt.NoFocus
                enabled: !authenticator.busy && !authenticator.graceLocked
                onClicked: root.unlock()
                background: Rectangle {
                    color: "white"
                    radius: 10
                    opacity: unlockButton.pressed ? 0.3 : unlockButton.hovered ? 0.4 : 0.5
                }
            }
        }
    }

    Label {
        anchors.top: card.bottom
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        font.bold: true
        color: "white"
        text: root.notification !== "" ? root.notification
                                        : root.capsLockOn ? qsTr("Caps Lock is on") : ""
    }

    Connections {
        target: authenticator

        function onFailed() {
            root.notification = qsTr("Wrong password")
            password.selectAll()
            password.forceActiveFocus()
        }
        function onInfoMessageChanged() {
            root.notification = authenticator.infoMessage
        }
        function onErrorMessageChanged() {
            root.notification = authenticator.errorMessage
        }
        function onPromptForSecretChanged() {
            authenticator.respond(password.text)
        }
        function onSucceeded() {
            Qt.quit()
        }
    }

    Component.onCompleted: password.forceActiveFocus()
}

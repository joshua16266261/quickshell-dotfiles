import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    readonly property color background: "#ee111318"
    readonly property color backgroundAlt: "#1a1d24"
    readonly property color foreground: "#e6e9ef"
    readonly property color muted: "#8b93a7"
    readonly property color accent: "#62d6e8"

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    Process {
        id: launcher
        command: ["rofi", "-show", "drun"]
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            required property var modelData

            screen: modelData
            implicitHeight: 38
            color: root.background

            anchors {
                top: true
                left: true
                right: true
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 12
                anchors.rightMargin: 12
                spacing: 12

                Rectangle {
                    implicitWidth: launcherLabel.implicitWidth + 22
                    implicitHeight: 26
                    radius: 6
                    color: launcherMouse.containsMouse ? root.accent : root.backgroundAlt

                    Text {
                        id: launcherLabel
                        anchors.centerIn: parent
                        text: "LAUNCH"
                        color: launcherMouse.containsMouse ? root.backgroundAlt : root.accent
                        font.family: "JetBrainsMono Nerd Font"
                        font.bold: true
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: launcherMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: launcher.startDetached()
                    }
                }

                Row {
                    spacing: 5

                    Repeater {
                        model: Hyprland.workspaces

                        Rectangle {
                            required property var modelData

                            implicitWidth: Math.max(24, workspaceLabel.implicitWidth + 12)
                            implicitHeight: 24
                            radius: 6
                            color: modelData.focused ? root.accent : (workspaceMouse.containsMouse ? root.backgroundAlt : "transparent")

                            Text {
                                id: workspaceLabel
                                anchors.centerIn: parent
                                text: modelData.name
                                color: modelData.focused ? root.backgroundAlt : (modelData.urgent ? "#ff7a90" : root.foreground)
                                font.family: "JetBrainsMono Nerd Font"
                                font.bold: modelData.focused
                                font.pixelSize: 12
                            }

                            MouseArea {
                                id: workspaceMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.activate()
                            }
                        }
                    }
                }

                Item {
                    Layout.fillWidth: true
                }

                Text {
                    Layout.maximumWidth: bar.width * 0.35
                    text: Hyprland.activeToplevel ? Hyprland.activeToplevel.title : "Desktop"
                    color: root.muted
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                }

                Item {
                    Layout.fillWidth: true
                }

                Rectangle {
                    implicitWidth: clockLabel.implicitWidth + 20
                    implicitHeight: 26
                    radius: 6
                    color: root.backgroundAlt

                    Text {
                        property var jpLocale: Qt.locale("ja_JP")

                        id: clockLabel
                        anchors.centerIn: parent
                        text: {
                            let now = clock.date;
                            let dateStr = now.toLocaleDateString(jpLocale, Locale.ShortFormat) // yyyy/mm/dd
                            let dayOfWeek = now.toLocaleDateString(jpLocale, "ddd"); // e.g. 水

                            let time = Qt.formatDateTime(now, "HH:mm:ss")

                            return `${time}  ${dateStr} (${dayOfWeek})`;
                        }
                        color: root.foreground
                        font.family: "JetBrainsMono Nerd Font"
                        font.bold: true
                        font.pixelSize: 15
                    }
                }
            }
        }
    }
}

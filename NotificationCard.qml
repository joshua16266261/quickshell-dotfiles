import Quickshell.Services.Notifications
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property var notification
    required property font defaultFont
    required property color background
    required property color backgroundAlt
    required property color foreground
    required property color muted
    required property color accent
    required property color red

    readonly property bool critical: notification.urgency === NotificationUrgency.Critical
    readonly property var extraActions: notification.actions.filter(action => action.identifier !== "default")
    readonly property int timeoutMs: {
        const seconds = Math.floor(notification.expireTimeout);
        return seconds > 0 ? seconds * 1000 : 5000;
    }

    implicitWidth: 380
    implicitHeight: cardContent.implicitHeight + 24
    radius: 10
    color: root.background

    border {
        width: 1
        color: root.critical ? root.red : (cardHover.hovered ? root.accent : "transparent")
    }

    function invokeDefault() {
        const action = root.notification.actions.find(candidate => candidate.identifier === "default");
        if (action) {
            action.invoke();
            if (!root.notification.resident) {
                root.notification.dismiss();
            }
        } else {
            root.notification.dismiss();
        }
    }

    HoverHandler {
        id: cardHover
    }

    TapHandler {
        onTapped: root.invokeDefault()
    }

    Timer {
        id: expireTimer

        interval: root.timeoutMs
        running: !root.critical && !cardHover.hovered
        onTriggered: root.notification.expire()
    }

    Column {
        id: cardContent

        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 12
        }

        spacing: 8

        RowLayout {
            width: parent.width

            Text {
                text: root.notification.appName === "" ? "Notification" : root.notification.appName
                color: root.muted
                elide: Text.ElideRight

                font {
                    family: root.defaultFont.family
                    pixelSize: root.defaultFont.pixelSize - 3
                    bold: true
                }

                Layout.fillWidth: true
            }

            Text {
                text: "\uF00D"
                color: closeHover.hovered ? root.red : root.muted

                font {
                    family: root.defaultFont.family
                    pixelSize: root.defaultFont.pixelSize - 3
                }

                HoverHandler {
                    id: closeHover
                }

                TapHandler {
                    onTapped: root.notification.dismiss()
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: 10

            IconImage {
                visible: root.notification.appIcon !== ""
                source: root.notification.appIcon
                implicitSize: 30
            }

            Text {
                visible: root.notification.appIcon === ""
                text: root.critical ? "\uF071" : "\uF0F3"
                color: root.critical ? root.red : root.muted

                font {
                    family: root.defaultFont.family
                    pixelSize: root.defaultFont.pixelSize + 4
                }
            }

            ColumnLayout {
                spacing: 4
                Layout.fillWidth: true

                Text {
                    visible: root.notification.summary !== ""
                    text: root.notification.summary
                    color: root.foreground
                    wrapMode: Text.Wrap

                    font {
                        family: root.defaultFont.family
                        pixelSize: root.defaultFont.pixelSize
                        bold: true
                    }

                    Layout.fillWidth: true
                }

                Text {
                    visible: root.notification.body !== ""
                    text: root.notification.body
                    color: root.foreground
                    opacity: 0.85
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText

                    font {
                        family: root.defaultFont.family
                        pixelSize: root.defaultFont.pixelSize - 1
                    }

                    Layout.fillWidth: true
                }
            }
        }

        Flow {
            visible: root.extraActions.length > 0
            width: parent.width
            spacing: 6

            Repeater {
                model: root.extraActions

                Rectangle {
                    id: actionButton

                    required property var modelData

                    implicitWidth: actionLabel.implicitWidth + 20
                    implicitHeight: actionLabel.implicitHeight + 10
                    radius: 6
                    color: actionHover.hovered ? root.accent : root.backgroundAlt

                    HoverHandler {
                        id: actionHover
                    }

                    TapHandler {
                        onTapped: {
                            actionButton.modelData.invoke();
                            if (!root.notification.resident) {
                                root.notification.dismiss();
                            }
                        }
                    }

                    Text {
                        id: actionLabel

                        anchors.centerIn: parent
                        text: actionButton.modelData.text === "" ? actionButton.modelData.identifier : actionButton.modelData.text
                        color: actionHover.hovered ? root.backgroundAlt : root.foreground

                        font {
                            family: root.defaultFont.family
                            pixelSize: root.defaultFont.pixelSize - 2
                        }
                    }
                }
            }
        }
    }
}

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Item {
    id: root

    required property font defaultFont
    required property color background
    required property color backgroundAlt
    required property color foreground
    required property color muted
    required property color accent
    required property color red

    readonly property int cardWidth: 380
    readonly property int popupTopMargin: 48
    readonly property int screenMargin: 10
    readonly property int cardSpacing: 8

    NotificationServer {
        id: notificationServer

        keepOnReload: false
        actionsSupported: true
        imageSupported: true

        onNotification: notification => {
            notification.tracked = true;
        }
    }

    ScriptModel {
        id: orderedNotifications

        values: [...notificationServer.trackedNotifications.values].reverse()
    }

    PanelWindow {
        id: popupWindow

        visible: orderedNotifications.values.length > 0
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        implicitWidth: root.cardWidth
        implicitHeight: popupCards.implicitHeight

        anchors {
            top: true
            right: true
        }

        margins {
            top: root.popupTopMargin
            right: root.screenMargin
        }

        mask: Region {
            item: popupCards
        }

        Column {
            id: popupCards

            anchors {
                top: parent.top
                right: parent.right
            }

            width: parent.width
            spacing: root.cardSpacing

            Repeater {
                model: orderedNotifications

                NotificationCard {
                    required property var modelData
                    notification: modelData

                    defaultFont: root.defaultFont
                    background: root.background
                    backgroundAlt: root.backgroundAlt
                    foreground: root.foreground
                    muted: root.muted
                    accent: root.accent
                    red: root.red
                }
            }
        }
    }
}

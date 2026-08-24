import Quickshell.Io
import QtQuick

Rectangle {
    id: root

    required property int barHeight
    required property font defaultFont
    required property color background
    required property color backgroundAlt
    required property color accent

    signal tapped

    implicitWidth: rofiLabel.implicitWidth + 1.25 * rofiLabel.font.pixelSize
    implicitHeight: barHeight

    color: root.background

    Process {
        id: launcher
        command: ["rofi", "-show", "drun"]
    }

    HoverHandler {
        id: rofiHover
    }

    TapHandler {
        onTapped: {
            root.tapped();
            launcher.startDetached();
        }
    }

    InnerBackground {
        color: rofiHover.hovered ? root.accent : root.backgroundAlt
        anchors.leftMargin: 5
        anchors.rightMargin: 5
    }

    Text {
        id: rofiLabel

        anchors {
            centerIn: parent
            verticalCenter: parent.verticalCenter
        }

        text: "Rofi"

        color: rofiHover.hovered ? root.backgroundAlt : root.accent

        font {
            family: root.defaultFont.family
            pixelSize: root.defaultFont.pixelSize
            bold: true
        }
    }
}

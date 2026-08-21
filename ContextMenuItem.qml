import QtQuick

Rectangle {
    id: root

    required property string label
    required property font defaultFont
    required property color backgroundAlt
    required property color foreground
    required property color muted
    required property color red

    property string detail: ""
    property bool dangerous: false

    signal selected

    implicitHeight: 36
    radius: 5
    color: hover.hovered ? backgroundAlt : "transparent"

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: root.selected()
    }

    Text {
        anchors {
            verticalCenter: parent.verticalCenter
            left: parent.left
            leftMargin: 9
        }
        text: root.label
        color: root.dangerous ? root.red : root.foreground
        font {
            family: root.defaultFont.family
            pixelSize: root.defaultFont.pixelSize - 3
            bold: root.dangerous
        }
    }

    Text {
        anchors {
            verticalCenter: parent.verticalCenter
            right: parent.right
            rightMargin: 9
        }
        visible: root.detail !== ""
        text: root.detail
        color: root.muted
        font {
            family: root.defaultFont.family
            pixelSize: root.defaultFont.pixelSize - 4
        }
    }
}

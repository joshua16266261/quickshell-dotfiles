import QtQuick

Rectangle {
    id: root

    required property color backgroundAlt
    required property color accent
    required property color foreground

    property real value: 0
    property bool dragging: false
    property real dragValue: 0
    readonly property real displayValue: root.dragging ? root.dragValue : root.value

    signal moved(real value)

    implicitWidth: 120
    implicitHeight: 26
    color: "transparent"
    opacity: enabled ? 1 : 0.45

    function pointerToValue(x) {
        const usable = Math.max(1, root.width - handle.width);
        const offset = Math.max(0, Math.min(usable, x - handle.width / 2));
        return offset / usable;
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onPressed: mouse => {
            root.dragging = true;
            root.dragValue = root.pointerToValue(mouse.x);
            root.moved(root.dragValue);
        }

        onPositionChanged: mouse => {
            if (pressed) {
                root.dragValue = root.pointerToValue(mouse.x);
                root.moved(root.dragValue);
            }
        }

        onReleased: root.dragging = false
        onCanceled: root.dragging = false
    }

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 13
        radius: 8
        color: root.backgroundAlt
    }

    Rectangle {
        id: fill

        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(parent.width, (parent.width - handle.width) * root.displayValue + handle.width / 2))
        height: track.height
        radius: 8
        color: root.accent
    }

    Rectangle {
        id: handle

        anchors.verticalCenter: parent.verticalCenter
        x: Math.max(0, Math.min(parent.width - width, (parent.width - width) * root.displayValue))
        width: 24
        height: 18
        radius: width / 2
        color: root.foreground
        border.width: 1
        border.color: root.backgroundAlt
    }
}

import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

Rectangle {
    id: root

    required property int barHeight
    required property var barWindow
    required property font defaultFont
    required property color background
    required property color backgroundAlt
    required property color foreground
    required property color muted
    required property color accent
    required property color red

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property int connectedCount: Bluetooth.devices.values.length
    readonly property bool highlighted: indicatorHover.hovered || bluetoothMenu.visible || escapeHighlight
    property bool escapeHighlight: false

    implicitWidth: Math.max(32, indicatorRow.implicitWidth + 16)
    implicitHeight: barHeight
    color: background

    function closeMenu() {
        bluetoothMenu.visible = false;
        menuFocusGrab.active = false;
    }

    function openMenu() {
        bluetoothMenu.anchor.updateAnchor();
        bluetoothMenu.visible = true;
        Qt.callLater(() => {
            if (bluetoothMenu.visible) {
                menuFocusGrab.active = true;
            }
        });
    }

    Timer {
        id: escapeHighlightTimer

        interval: 100
        onTriggered: root.escapeHighlight = false
    }

    ScriptModel {
        id: pairedDevices

        values: {
            if (!root.adapter) {
                return [];
            }

            return [...root.adapter.devices.values]
                .filter(device => device.paired)
                .sort((left, right) => {
                    if (left.connected !== right.connected) {
                        return left.connected ? -1 : 1;
                    }

                    return left.name.localeCompare(right.name);
                });
        }
    }

    HoverHandler {
        id: indicatorHover
    }

    TapHandler {
        onTapped: {
            if (bluetoothMenu.visible) {
                root.closeMenu();
            } else {
                root.openMenu();
            }
        }
    }

    InnerBackground {
        color: root.highlighted ? root.accent : root.background
        anchors.leftMargin: 3
        anchors.rightMargin: 3
    }

    Row {
        id: indicatorRow

        anchors.centerIn: parent
        spacing: 4

        Text {
            text: ""
            color: {
                if (root.highlighted) {
                    return root.backgroundAlt;
                } else if (!root.adapter || !root.adapter.enabled) {
                    return root.muted;
                } else if (root.connectedCount > 0) {
                    return root.accent;
                } else {
                    return root.foreground;
                }
            }
            font: root.defaultFont
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.connectedCount > 0
            text: root.connectedCount
            color: root.highlighted ? root.backgroundAlt : root.accent
            font {
                family: root.defaultFont.family
                pixelSize: root.defaultFont.pixelSize - 3
                bold: true
            }
        }
    }

    PopupWindow {
        id: bluetoothMenu

        anchor {
            item: root
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }

        implicitWidth: 340
        implicitHeight: menuColumn.implicitHeight + 24
        color: "transparent"

        Shortcut {
            enabled: bluetoothMenu.visible
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: {
                root.escapeHighlight = true;
                escapeHighlightTimer.restart();
                root.closeMenu();
            }
        }

        Rectangle {
            anchors.fill: parent
            color: root.background
            radius: 8
            border.width: 1
            border.color: root.backgroundAlt

            ColumnLayout {
                id: menuColumn

                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 8

                Rectangle {
                    id: adapterRow

                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 6
                    color: adapterRowHover.hovered ? root.backgroundAlt : "transparent"

                    HoverHandler {
                        id: adapterRowHover
                    }

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                text: "Bluetooth"
                                color: root.foreground
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize
                                    bold: true
                                }
                            }

                            Text {
                                text: {
                                    if (!root.adapter) {
                                        return "No adapter";
                                    } else if (root.adapter.state === BluetoothAdapterState.Blocked) {
                                        return "Blocked";
                                    } else if (!root.adapter.enabled) {
                                        return "Off";
                                    } else if (root.connectedCount === 0) {
                                        return "Not connected";
                                    } else if (root.connectedCount === 1) {
                                        return "1 device connected";
                                    } else {
                                        return `${root.connectedCount} devices connected`;
                                    }
                                }
                                color: root.muted
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize - 4
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: 42
                            implicitHeight: 22
                            radius: height / 2
                            color: root.adapter && root.adapter.enabled ? root.accent : root.backgroundAlt
                            opacity: root.adapter && root.adapter.state !== BluetoothAdapterState.Blocked ? 1 : 0.5

                            Rectangle {
                                width: 16
                                height: 16
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.adapter && root.adapter.enabled ? parent.width - width - 3 : 3
                                color: root.adapter && root.adapter.enabled ? root.backgroundAlt : root.muted
                            }

                            TapHandler {
                                enabled: root.adapter && root.adapter.state !== BluetoothAdapterState.Blocked
                                onTapped: root.adapter.enabled = !root.adapter.enabled
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.backgroundAlt
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: {
                        if (!root.adapter || !root.adapter.enabled || pairedDevices.values.length === 0) {
                            return 52;
                        }

                        return Math.min(pairedDevices.values.length * 52, 260);
                    }

                    ListView {
                        anchors.fill: parent
                        clip: true
                        spacing: 2
                        model: pairedDevices
                        visible: root.adapter && root.adapter.enabled && pairedDevices.values.length > 0

                        delegate: Rectangle {
                            id: deviceRow

                            required property var modelData

                            width: ListView.view.width
                            height: 50
                            radius: 6
                            color: deviceRowHover.hovered ? root.backgroundAlt : "transparent"

                            HoverHandler {
                                id: deviceRowHover
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 8
                                    rightMargin: 8
                                }
                                spacing: 10

                                Text {
                                    Layout.preferredWidth: 24
                                    text: ""
                                    color: deviceRow.modelData.connected ? root.accent : root.muted
                                    horizontalAlignment: Text.AlignHCenter
                                    font: root.defaultFont
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: deviceRow.modelData.name
                                        color: root.foreground
                                        elide: Text.ElideRight
                                        font {
                                            family: root.defaultFont.family
                                            pixelSize: root.defaultFont.pixelSize - 2
                                            bold: deviceRow.modelData.connected
                                        }
                                    }

                                    Text {
                                        text: {
                                            switch (deviceRow.modelData.state) {
                                            case BluetoothDeviceState.Connecting:
                                                return "Connecting…";
                                            case BluetoothDeviceState.Disconnecting:
                                                return "Disconnecting…";
                                            case BluetoothDeviceState.Connected:
                                                return "Connected";
                                            default:
                                                return "Not connected";
                                            }
                                        }
                                        color: deviceRow.modelData.connected ? root.accent : root.muted
                                        font {
                                            family: root.defaultFont.family
                                            pixelSize: root.defaultFont.pixelSize - 4
                                        }
                                    }
                                }

                                Text {
                                    visible: deviceRow.modelData.batteryAvailable
                                    text: `${Math.round(deviceRow.modelData.battery * 100)}%`
                                    color: root.muted
                                    font {
                                        family: root.defaultFont.family
                                        pixelSize: root.defaultFont.pixelSize - 3
                                    }
                                }

                                Rectangle {
                                    id: deviceToggle

                                    readonly property bool busy: deviceRow.modelData.state === BluetoothDeviceState.Connecting
                                        || deviceRow.modelData.state === BluetoothDeviceState.Disconnecting

                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 22
                                    radius: height / 2
                                    color: deviceRow.modelData.connected ? root.accent : root.backgroundAlt
                                    opacity: busy ? 0.5 : 1

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: width / 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: deviceRow.modelData.connected ? parent.width - width - 3 : 3
                                        color: deviceRow.modelData.connected ? root.backgroundAlt : root.muted
                                    }

                                    TapHandler {
                                        enabled: !deviceToggle.busy
                                        onTapped: {
                                            if (deviceRow.modelData.connected) {
                                                deviceRow.modelData.disconnect();
                                            } else {
                                                deviceRow.modelData.connect();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: !root.adapter || !root.adapter.enabled || pairedDevices.values.length === 0
                        text: {
                            if (!root.adapter) {
                                return "No Bluetooth adapter found";
                            } else if (!root.adapter.enabled) {
                                return "Bluetooth is turned off";
                            } else {
                                return "No paired devices";
                            }
                        }
                        color: root.muted
                        font {
                            family: root.defaultFont.family
                            pixelSize: root.defaultFont.pixelSize - 3
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.backgroundAlt
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 6
                    color: managerHover.hovered ? root.backgroundAlt : "transparent"

                    HoverHandler {
                        id: managerHover
                    }

                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached(["blueman-manager"]);
                            root.closeMenu();
                        }
                    }

                    Text {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            leftMargin: 8
                        }
                        text: "Open Bluetooth Manager…"
                        color: root.foreground
                        font {
                            family: root.defaultFont.family
                            pixelSize: root.defaultFont.pixelSize - 2
                        }
                    }

                    Text {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            right: parent.right
                            rightMargin: 8
                        }
                        text: "›"
                        color: root.muted
                        font: root.defaultFont
                    }
                }
            }
        }
    }

    HyprlandFocusGrab {
        id: menuFocusGrab

        windows: [bluetoothMenu, root.barWindow]
        onCleared: {
            if (bluetoothMenu.visible) {
                root.closeMenu();
            }
        }
    }

}

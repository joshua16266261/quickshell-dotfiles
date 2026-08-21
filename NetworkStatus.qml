import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
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

    readonly property var wifiDevice: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.Wifi) {
                return device;
            }
        }

        return null;
    }
    readonly property var connectedDevice: {
        for (const device of Networking.devices.values) {
            if (device.connected && device.type !== DeviceType.None) {
                return device;
            }
        }

        return null;
    }
    readonly property var activeNetwork: {
        for (const device of Networking.devices.values) {
            if (device.type === DeviceType.None) {
                continue;
            }

            for (const network of device.networks.values) {
                if (network.connected) {
                    return network;
                }
            }
        }

        return null;
    }
    readonly property bool connected: connectedDevice !== null
    readonly property bool connectionLimited: Networking.connectivity === NetworkConnectivity.Limited
        || Networking.connectivity === NetworkConnectivity.Portal
    readonly property bool highlighted: indicatorHover.hovered || networkMenu.visible || escapeHighlight
    property bool escapeHighlight: false
    property var contextNetwork: null
    property var contextAnchor: null
    property bool confirmForget: false
    property bool showConnectionDetails: false

    signal menuOpened

    implicitWidth: Math.max(32, networkIcon.implicitWidth + 16)
    implicitHeight: barHeight
    color: background

    function closeMenu() {
        root.closeNetworkContextMenu();
        if (root.wifiDevice) {
            root.wifiDevice.scannerEnabled = false;
        }
        networkMenu.visible = false;
        menuFocusGrab.active = false;
    }

    function closeNetworkContextMenu() {
        networkContextMenu.visible = false;
        root.confirmForget = false;
        root.showConnectionDetails = false;
        root.contextNetwork = null;
        root.contextAnchor = null;
    }

    function openNetworkContextMenu(network, row) {
        root.contextNetwork = network;
        root.contextAnchor = row;
        root.confirmForget = false;
        root.showConnectionDetails = false;
        networkContextMenu.visible = true;
    }

    function connectionDetails() {
        if (!root.contextNetwork) {
            return "";
        }

        const network = root.contextNetwork;
        const type = network.device.type === DeviceType.Wifi ? "Wi-Fi" : "Ethernet";
        const state = ConnectionState.toString(network.state);
        const profiles = [...network.nmSettings].map(profile => profile.id).join(", ");
        const lines = [
            `Interface: ${network.device.name}`,
            `Type: ${type}`,
            `State: ${state}`,
            `Profiles: ${profiles || "None"}`
        ];

        if (network.device.type === DeviceType.Wifi) {
            lines.splice(2, 0, `Signal: ${Math.round((network.signalStrength || 0) * 100)}%`);
            lines.splice(3, 0, `Security: ${WifiSecurityType.toString(network.security)}`);
        }

        return lines.join("\n");
    }

    function openMenu() {
        root.menuOpened();
        networkMenu.anchor.updateAnchor();
        networkMenu.visible = true;
        if (root.wifiDevice && Networking.wifiEnabled) {
            root.wifiDevice.scannerEnabled = true;
        }
        Qt.callLater(() => {
            if (networkMenu.visible) {
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
        id: savedNetworks

        values: {
            const networks = [];

            for (const device of Networking.devices.values) {
                if (device.type === DeviceType.None) {
                    continue;
                }

                for (const network of device.networks.values) {
                    if (network.connected || network.known) {
                        networks.push(network);
                    }
                }
            }

            return networks.sort((left, right) => {
                if (left.connected !== right.connected) {
                    return left.connected ? -1 : 1;
                }
                if (left.device.type !== right.device.type) {
                    return left.device.type === DeviceType.Wired ? -1 : 1;
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
            if (networkMenu.visible) {
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

    Text {
        id: networkIcon

        anchors.centerIn: parent
        text: root.connectedDevice && root.connectedDevice.type === DeviceType.Wifi ? "" : "󰈀"
        color: {
            if (root.highlighted) {
                return root.backgroundAlt;
            } else if (root.connectionLimited) {
                return root.red;
            } else if (root.connected) {
                return root.accent;
            } else {
                return root.muted;
            }
        }
        font: root.defaultFont
    }

    PopupWindow {
        id: networkMenu

        anchor {
            item: root
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }

        implicitWidth: 360
        implicitHeight: menuColumn.implicitHeight + 24
        color: "transparent"

        Shortcut {
            enabled: networkMenu.visible && !networkContextMenu.visible
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
                    id: wifiRow

                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: 6
                    color: wifiRowHover.hovered ? root.backgroundAlt : "transparent"

                    HoverHandler {
                        id: wifiRowHover
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
                                text: "Network"
                                color: root.foreground
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize
                                    bold: true
                                }
                            }

                            Text {
                                width: parent.width
                                text: {
                                    if (root.activeNetwork) {
                                        return root.activeNetwork.name;
                                    } else if (root.connectedDevice) {
                                        return root.connectedDevice.name;
                                    } else {
                                        return "Not connected";
                                    }
                                }
                                color: root.connected ? root.accent : root.muted
                                elide: Text.ElideRight
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize - 4
                                }
                            }
                        }

                        Column {
                            spacing: 2

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "Wi-Fi"
                                color: root.muted
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize - 5
                                }
                            }

                            Rectangle {
                                implicitWidth: 42
                                implicitHeight: 22
                                radius: height / 2
                                color: Networking.wifiEnabled ? root.accent : root.backgroundAlt
                                opacity: Networking.wifiHardwareEnabled ? 1 : 0.5

                                Rectangle {
                                    width: 16
                                    height: 16
                                    radius: width / 2
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Networking.wifiEnabled ? parent.width - width - 3 : 3
                                    color: Networking.wifiEnabled ? root.backgroundAlt : root.muted
                                }

                                TapHandler {
                                    enabled: Networking.wifiHardwareEnabled
                                    onTapped: Networking.wifiEnabled = !Networking.wifiEnabled
                                }
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
                    Layout.preferredHeight: savedNetworks.values.length === 0
                        ? 52
                        : Math.min(savedNetworks.values.length * 52, 260)

                    ListView {
                        anchors.fill: parent
                        clip: true
                        spacing: 2
                        model: savedNetworks
                        visible: savedNetworks.values.length > 0

                        delegate: Rectangle {
                            id: networkRow

                            required property var modelData

                            width: ListView.view.width
                            height: 50
                            radius: 6
                            color: networkRowHover.hovered
                                || (networkContextMenu.visible && root.contextNetwork === networkRow.modelData)
                                ? root.backgroundAlt
                                : "transparent"

                            HoverHandler {
                                id: networkRowHover
                            }

                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                onTapped: root.openNetworkContextMenu(networkRow.modelData, networkRow)
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
                                    text: networkRow.modelData.device.type === DeviceType.Wifi ? "" : "󰈀"
                                    color: networkRow.modelData.connected ? root.accent : root.muted
                                    horizontalAlignment: Text.AlignHCenter
                                    font: root.defaultFont
                                }

                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    Text {
                                        width: parent.width
                                        text: networkRow.modelData.name
                                        color: root.foreground
                                        elide: Text.ElideRight
                                        font {
                                            family: root.defaultFont.family
                                            pixelSize: root.defaultFont.pixelSize - 2
                                            bold: networkRow.modelData.connected
                                        }
                                    }

                                    Text {
                                        text: {
                                            switch (networkRow.modelData.state) {
                                            case ConnectionState.Connecting:
                                                return "Connecting…";
                                            case ConnectionState.Disconnecting:
                                                return "Disconnecting…";
                                            case ConnectionState.Connected:
                                                return networkRow.modelData.device.type === DeviceType.Wifi
                                                    ? "Connected via Wi-Fi"
                                                    : "Connected via Ethernet";
                                            default:
                                                return "Not connected";
                                            }
                                        }
                                        color: networkRow.modelData.connected ? root.accent : root.muted
                                        font {
                                            family: root.defaultFont.family
                                            pixelSize: root.defaultFont.pixelSize - 4
                                        }
                                    }
                                }

                                Text {
                                    visible: networkRow.modelData.device.type === DeviceType.Wifi
                                    text: `${Math.round((networkRow.modelData.signalStrength || 0) * 100)}%`
                                    color: root.muted
                                    font {
                                        family: root.defaultFont.family
                                        pixelSize: root.defaultFont.pixelSize - 3
                                    }
                                }

                                Rectangle {
                                    id: connectionToggle

                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 22
                                    radius: height / 2
                                    color: networkRow.modelData.connected ? root.accent : root.backgroundAlt
                                    opacity: networkRow.modelData.stateChanging ? 0.5 : 1

                                    Rectangle {
                                        width: 16
                                        height: 16
                                        radius: width / 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: networkRow.modelData.connected ? parent.width - width - 3 : 3
                                        color: networkRow.modelData.connected ? root.backgroundAlt : root.muted
                                    }

                                    TapHandler {
                                        enabled: !networkRow.modelData.stateChanging
                                        onTapped: {
                                            if (networkRow.modelData.connected) {
                                                networkRow.modelData.disconnect();
                                            } else {
                                                networkRow.modelData.connect();
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: savedNetworks.values.length === 0
                        text: "No saved network connections"
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
                    color: settingsHover.hovered ? root.backgroundAlt : "transparent"

                    HoverHandler {
                        id: settingsHover
                    }

                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached([
                                "env",
                                "XDG_CURRENT_DESKTOP=GNOME",
                                "gnome-control-center",
                                "network"
                            ]);
                            root.closeMenu();
                        }
                    }

                    Text {
                        anchors {
                            verticalCenter: parent.verticalCenter
                            left: parent.left
                            leftMargin: 8
                        }
                        text: "Open Network Settings…"
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

    MouseArea {
        parent: networkMenu.contentItem
        anchors.fill: parent
        z: 99
        visible: networkContextMenu.visible
        onClicked: root.closeNetworkContextMenu()
    }

    Rectangle {
        id: networkContextMenu

        parent: networkMenu.contentItem
        implicitWidth: 280
        implicitHeight: networkContextColumn.implicitHeight + 16
        width: implicitWidth
        height: implicitHeight
        x: parent ? parent.width - width - 8 : 0
        y: {
            if (!parent || !root.contextAnchor) {
                return 8;
            }

            const rowPosition = root.contextAnchor.mapToItem(parent, 0, 0);
            return Math.max(8, Math.min(parent.height - height - 8, rowPosition.y));
        }
        z: 100
        visible: false
        color: "transparent"

        onVisibleChanged: {
            if (!visible) {
                root.confirmForget = false;
                root.showConnectionDetails = false;
                root.contextNetwork = null;
                root.contextAnchor = null;
            }
        }

        Shortcut {
            enabled: networkContextMenu.visible
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: root.closeNetworkContextMenu()
        }

        Rectangle {
            anchors.fill: parent
            radius: 7
            color: root.background
            border.width: 1
            border.color: root.backgroundAlt

            ColumnLayout {
                id: networkContextColumn

                anchors {
                    fill: parent
                    margins: 8
                }
                spacing: 2

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 9
                    Layout.rightMargin: 9
                    Layout.preferredHeight: 30
                    text: root.contextNetwork ? root.contextNetwork.name : "Network connection"
                    color: root.muted
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    font {
                        family: root.defaultFont.family
                        pixelSize: root.defaultFont.pixelSize - 3
                        bold: true
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.backgroundAlt
                }

                ContextMenuItem {
                    Layout.fillWidth: true
                    label: root.showConnectionDetails ? "Hide connection details" : "Connection details"
                    defaultFont: root.defaultFont
                    backgroundAlt: root.backgroundAlt
                    foreground: root.foreground
                    muted: root.muted
                    red: root.red
                    onSelected: root.showConnectionDetails = !root.showConnectionDetails
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.showConnectionDetails ? detailsText.implicitHeight + 16 : 0
                    visible: root.showConnectionDetails
                    radius: 5
                    color: root.backgroundAlt

                    Text {
                        id: detailsText

                        anchors {
                            fill: parent
                            margins: 8
                        }
                        text: root.connectionDetails()
                        color: root.muted
                        wrapMode: Text.Wrap
                        font {
                            family: root.defaultFont.family
                            pixelSize: root.defaultFont.pixelSize - 4
                        }
                    }
                }

                ContextMenuItem {
                    Layout.fillWidth: true
                    label: root.confirmForget ? "Confirm forget" : "Forget connection…"
                    dangerous: true
                    defaultFont: root.defaultFont
                    backgroundAlt: root.backgroundAlt
                    foreground: root.foreground
                    muted: root.muted
                    red: root.red
                    onSelected: {
                        if (!root.confirmForget) {
                            root.confirmForget = true;
                        } else if (root.contextNetwork) {
                            const network = root.contextNetwork;
                            root.closeNetworkContextMenu();
                            network.forget();
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.backgroundAlt
                }

                ContextMenuItem {
                    Layout.fillWidth: true
                    label: "Open Network Settings"
                    defaultFont: root.defaultFont
                    backgroundAlt: root.backgroundAlt
                    foreground: root.foreground
                    muted: root.muted
                    red: root.red
                    onSelected: {
                        Quickshell.execDetached([
                            "env",
                            "XDG_CURRENT_DESKTOP=GNOME",
                            "gnome-control-center",
                            "network"
                        ]);
                        root.closeMenu();
                    }
                }
            }
        }
    }

    HyprlandFocusGrab {
        id: menuFocusGrab

        windows: [networkMenu, root.barWindow]
        onCleared: {
            if (networkMenu.visible) {
                root.closeMenu();
            }
        }
    }
}

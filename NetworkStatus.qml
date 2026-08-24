import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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
    required property color secondary
    required property color tertiary

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
    readonly property string targetInterface: connectedDevice ? connectedDevice.name : ""
    property real rxSpeed: 0
    property real txSpeed: 0
    property real menuRxSpeed: 0
    property real menuTxSpeed: 0
    property double _barPrevRx: 0
    property double _barPrevTx: 0
    property double _barPrevTs: 0
    property double _menuPrevRx: 0
    property double _menuPrevTx: 0
    property double _menuPrevTs: 0

    signal menuOpened

    function formatSpeed(bps) {
        const p = formatSpeedParts(bps);
        return `${p.value} ${p.unit}`;
    }

    function formatSpeedParts(bps) {
        const bits = bps * 8;
        const units = ["b/s", "Kb/s", "Mb/s", "Gb/s"];
        const divisors = [1, 1000, 1000000, 1000000000];
        for (let i = 0; i < units.length; i++) {
            const val = bits / divisors[i];
            if (val >= 1000 && i < units.length - 1)
                continue;
            if (val >= 100) {
                return { value: Math.round(val).toString(), unit: units[i] };
            }
            if (val >= 10) {
                continue;
            }
            const v = (Math.round(val * 10) / 10).toFixed(1);
            return { value: v, unit: units[i] };
        }
        const val = bits / divisors[divisors.length - 1];
        if (val >= 100)
            return { value: Math.round(val).toString(), unit: units[units.length - 1] };
        return { value: (Math.round(val * 10) / 10).toFixed(1), unit: units[units.length - 1] };
    }

    function formatSpeedValue(bps) {
        return formatSpeedParts(bps).value;
    }

    function formatSpeedUnit(bps) {
        return formatSpeedParts(bps).unit;
    }

    function updateSpeeds() {
        if (!targetInterface) {
            rxSpeed = 0;
            txSpeed = 0;
            menuRxSpeed = 0;
            menuTxSpeed = 0;
            return;
        }
        const lines = netDevFile.text().split("\n");
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.indexOf(targetInterface + ":") !== -1) {
                const parts = line.split(":")[1].trim().split(/\s+/);
                const rx = parseInt(parts[0], 10);
                const tx = parseInt(parts[8], 10);
                const now = Date.now();
                if (_barPrevTs !== 0) {
                    const dt = (now - _barPrevTs) / 1000;
                    if (dt >= 9) {
                        rxSpeed = rx >= _barPrevRx ? (rx - _barPrevRx) / dt : 0;
                        txSpeed = tx >= _barPrevTx ? (tx - _barPrevTx) / dt : 0;
                        _barPrevRx = rx;
                        _barPrevTx = tx;
                        _barPrevTs = now;
                    }
                } else {
                    _barPrevRx = rx;
                    _barPrevTx = tx;
                    _barPrevTs = now;
                }
                if (_menuPrevTs !== 0) {
                    const dt2 = (now - _menuPrevTs) / 1000;
                    if (dt2 > 0) {
                        menuRxSpeed = rx >= _menuPrevRx ? (rx - _menuPrevRx) / dt2 : 0;
                        menuTxSpeed = tx >= _menuPrevTx ? (tx - _menuPrevTx) / dt2 : 0;
                    }
                }
                _menuPrevRx = rx;
                _menuPrevTx = tx;
                _menuPrevTs = now;
                return;
            }
        }
        rxSpeed = 0;
        txSpeed = 0;
        menuRxSpeed = 0;
        menuTxSpeed = 0;
    }

    onTargetInterfaceChanged: {
        _barPrevTs = 0;
        _barPrevRx = 0;
        _barPrevTx = 0;
        _menuPrevTs = 0;
        _menuPrevRx = 0;
        _menuPrevTx = 0;
        rxSpeed = 0;
        txSpeed = 0;
        menuRxSpeed = 0;
        menuTxSpeed = 0;
    }

    implicitWidth: 200
    implicitHeight: barHeight
    color: background

    function closeMenu() {
        root.closeNetworkContextMenu();
        if (root.wifiDevice) {
            root.wifiDevice.scannerEnabled = false;
        }
        networkMenu.visible = false;
        menuFocusGrab.active = false;
        speedTimer.interval = 10000;
        speedTimer.restart();
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
        root._menuPrevTs = 0;
        root._menuPrevRx = 0;
        root._menuPrevTx = 0;
        speedTimer.interval = 1000;
        speedTimer.restart();
        netDevFile.reload();
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

    FileView {
        id: netDevFile

        path: "/proc/net/dev"
        printErrors: false
        onTextChanged: root.updateSpeeds()
    }

    Timer {
        id: speedTimer

        interval: 10000
        running: true
        repeat: true
        onTriggered: netDevFile.reload()
    }

    Component.onCompleted: netDevFile.reload()

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

    RowLayout {
        id: indicatorRow

        anchors {
            left: parent.left
            right: parent.right
            leftMargin: 8
            rightMargin: 8
            verticalCenter: parent.verticalCenter
        }
        spacing: 4

        Text {
            id: networkIcon

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

        Row {
            visible: root.connected
            spacing: 0

            Text {
                id: downloadText

                width: 28
                horizontalAlignment: Text.AlignRight
                text: root.formatSpeedValue(root.rxSpeed)
                color: root.tertiary
                font {
                    family: root.defaultFont.family
                    pixelSize: root.defaultFont.pixelSize - 3
                    bold: true
                }
            }

            Item { width: 1; height: 1 }

            Text {
                width: 38
                horizontalAlignment: Text.AlignRight
                text: root.formatSpeedUnit(root.rxSpeed)
                color: root.tertiary
                font {
                    family: root.defaultFont.family
                    pixelSize: root.defaultFont.pixelSize - 3
                    bold: true
                }
            }

            Item { width: 8; height: 1 }

            Text {
                text: "↓"
                color: root.tertiary
                font {
                    family: root.defaultFont.family
                    pixelSize: root.defaultFont.pixelSize - 3
                    bold: true
                }
            }
        }

        Item {
            Layout.fillWidth: true
        }

        Row {
            visible: root.connected
            spacing: 0

            Text {
                id: uploadText

                width: 28
                horizontalAlignment: Text.AlignRight
                text: root.formatSpeedValue(root.txSpeed)
                color: root.secondary
                font {
                    family: root.defaultFont.family
                    pixelSize: root.defaultFont.pixelSize - 3
                    bold: true
                }
            }

            Item { width: 1; height: 1 }

            Text {
                width: 38
                horizontalAlignment: Text.AlignRight
                text: root.formatSpeedUnit(root.txSpeed)
                color: root.secondary
                font {
                    family: root.defaultFont.family
                    pixelSize: root.defaultFont.pixelSize - 3
                    bold: true
                }
            }

            Item { width: 8; height: 1 }

            Text {
                text: "↑"
                color: root.secondary
                font {
                    family: root.defaultFont.family
                    pixelSize: root.defaultFont.pixelSize - 3
                    bold: true
                }
            }
        }
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
                    visible: root.connected
                    Layout.fillWidth: true
                    Layout.preferredHeight: visible ? 28 : 0
                    radius: 6
                    color: root.backgroundAlt

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 8
                            rightMargin: 8
                        }
                        spacing: 12

                        Row {
                            Layout.fillWidth: true
                            spacing: 0

                            Text {
                                width: 28
                                horizontalAlignment: Text.AlignRight
                                text: root.formatSpeedValue(root.menuRxSpeed)
                                color: root.tertiary
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize - 3
                                    bold: true
                                }
                            }

                            Item { width: 1; height: 1 }

                            Text {
                                width: 38
                                horizontalAlignment: Text.AlignRight
                                text: root.formatSpeedUnit(root.menuRxSpeed)
                                color: root.tertiary
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize - 3
                                    bold: true
                                }
                            }

                            Item { width: 8; height: 1 }

                            Text {
                                text: "↓"
                                color: root.tertiary
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize - 3
                                    bold: true
                                }
                            }
                        }

                        Row {
                            spacing: 0

                            Text {
                                width: 28
                                horizontalAlignment: Text.AlignRight
                                text: root.formatSpeedValue(root.menuTxSpeed)
                                color: root.secondary
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize - 3
                                    bold: true
                                }
                            }

                            Item { width: 1; height: 1 }

                            Text {
                                width: 38
                                horizontalAlignment: Text.AlignRight
                                text: root.formatSpeedUnit(root.menuTxSpeed)
                                color: root.secondary
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize - 3
                                    bold: true
                                }
                            }

                            Item { width: 8; height: 1 }

                            Text {
                                text: "↑"
                                color: root.secondary
                                font {
                                    family: root.defaultFont.family
                                    pixelSize: root.defaultFont.pixelSize - 3
                                    bold: true
                                }
                            }
                        }

                        Text {
                            text: root.targetInterface
                            color: root.muted
                            font {
                                family: root.defaultFont.family
                                pixelSize: root.defaultFont.pixelSize - 4
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

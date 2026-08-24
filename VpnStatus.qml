import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
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

    property var vpnNames: []
    property string activeVpn: ""
    readonly property bool connected: activeVpn !== ""
    readonly property bool highlighted: indicatorHover.hovered || vpnMenu.visible || escapeHighlight
    property bool escapeHighlight: false
    property bool connecting: false
    property bool disconnecting: false
    property string pendingConnectName: ""
    property int connectDots: 1
    readonly property string dotSuffix: "....".substring(0, connectDots)

    signal menuOpened

    implicitWidth: Math.max(32, indicatorRow.implicitWidth + 16)
    implicitHeight: barHeight
    color: background

    function closeMenu() {
        vpnMenu.visible = false
        menuFocusGrab.active = false
    }

    function openMenu() {
        root.menuOpened()
        vpnMenu.anchor.updateAnchor()
        vpnMenu.visible = true
        refresh()
        Qt.callLater(() => {
            if (vpnMenu.visible) menuFocusGrab.active = true
        })
    }

    function refresh() {
        if (!vpnProc.running) vpnProc.running = true
    }

    function parseOutput(text) {
        const lines = text.trim().split("\n")
        let sep = lines.indexOf("__ACTIVE__")
        if (sep === -1) sep = lines.indexOf("__ACTIVE__\r")
        const all = sep >= 0 ? lines.slice(0, sep) : lines
        const act = sep >= 0 ? lines.slice(sep + 1) : []
        const names = []
        for (let i = 0; i < all.length; i++) {
            const l = all[i].trim()
            if (l === "") continue
            const idx = l.lastIndexOf(":")
            if (idx === -1) continue
            const t = l.slice(idx + 1)
            const n = l.slice(0, idx)
            if (t === "wireguard" && n !== "") names.push(n)
        }
        let active = ""
        for (let i = 0; i < act.length; i++) {
            const l = act[i].trim()
            if (l === "") continue
            const idx = l.lastIndexOf(":")
            if (idx === -1) continue
            const t = l.slice(idx + 1)
            const n = l.slice(0, idx)
            if (t === "wireguard" && n !== "") {
                active = n
                break
            }
        }
        vpnNames = names.sort((a, b) => a.localeCompare(b))
        activeVpn = active
    }

    function switchTo(name) {
        console.log("VpnStatus switchTo " + name + " active=" + activeVpn)
        if (name === activeVpn) return
        root.connecting = true
        root.disconnecting = false
        root.pendingConnectName = name
        root.connectDots = 1
        const nm = "/run/current-system/sw/bin/nmcli"
        if (activeVpn !== "" || root.vpnNames.length > 1) {
            const allDown = root.vpnNames.map(n => "\"" + n.replace(/\"/g, "\\\"") + "\"").join(" ")
            Quickshell.execDetached(["/run/current-system/sw/bin/bash", "-c", nm + " connection down " + allDown + " 2>/dev/null; sleep 0.6; " + nm + " connection up \"" + name.replace(/\"/g, "\\\"") + "\""])
        } else {
            Quickshell.execDetached([nm, "connection", "up", name])
        }
        refreshTimer.interval = 900
        refreshTimer.restart()
        checkTimer.restart()
    }

    function disconnectVpn() {
        console.log("VpnStatus disconnect " + activeVpn)
        if (activeVpn === "" && !root.connecting) return
        root.disconnecting = true
        root.connecting = false
        root.pendingConnectName = ""
        root.connectDots = 1
        const nm = "/run/current-system/sw/bin/nmcli"
        const allDown = root.vpnNames.map(n => "\"" + n.replace(/\"/g, "\\\"") + "\"").join(" ")
        Quickshell.execDetached(["/run/current-system/sw/bin/bash", "-c", nm + " connection down " + allDown])
        refreshTimer.interval = 900
        refreshTimer.restart()
        checkTimer.restart()
    }

    StdioCollector {
        id: vpnCollector
        waitForEnd: true
    }

    Process {
        id: vpnProc
        command: ["/run/current-system/sw/bin/bash", "-c", "/run/current-system/sw/bin/nmcli -t -f NAME,TYPE connection show 2>/dev/null; echo __ACTIVE__; /run/current-system/sw/bin/nmcli -t -f NAME,TYPE connection show --active 2>/dev/null"]
        stdout: vpnCollector
        stderr: StdioCollector { id: vpnErr; waitForEnd: true }
        onExited: (code, stat) => {
            if (code !== 0) console.log("VpnStatus poll failed code=" + code + " err=" + vpnErr.text)
            root.parseOutput(vpnCollector.text)
        }
    }

    Timer {
        id: refreshTimer
        interval: 4000
        running: true
        repeat: true
        onTriggered: {
            if (!vpnProc.running) vpnProc.running = true
        }
    }

    Timer {
        id: escapeHighlightTimer
        interval: 100
        onTriggered: root.escapeHighlight = false
    }

    Timer {
        id: checkTimer
        interval: 900
        repeat: true
        running: false
        property int count: 0
        onTriggered: {
            if (!vpnProc.running) vpnProc.running = true
            count++
            if (count > 5) {
                running = false
                count = 0
                refreshTimer.interval = 4000
                root.connecting = false
                root.disconnecting = false
                root.pendingConnectName = ""
            }
        }
    }

    Timer {
        id: connectAnimTimer
        interval: 350
        repeat: true
        running: root.connecting || root.disconnecting
        onTriggered: root.connectDots = root.connectDots % 4 + 1
    }

    Component.onCompleted: {
        if (!vpnProc.running) vpnProc.running = true
    }

    ScriptModel {
        id: vpnModel
        values: root.vpnNames
    }

    HoverHandler { id: indicatorHover }

    TapHandler {
        onTapped: {
            if (vpnMenu.visible) root.closeMenu()
            else root.openMenu()
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
            id: glyph
            text: "󰖂"
            color: {
                if (root.highlighted) return root.backgroundAlt
                else if (root.connected) return root.accent
                else return root.muted
            }
            font: root.defaultFont
        }
        Text {
            visible: root.connected
            anchors.verticalCenter: parent.verticalCenter
            text: root.activeVpn
            color: glyph.color
            elide: Text.ElideRight
            font {
                family: root.defaultFont.family
                pixelSize: root.defaultFont.pixelSize - 2
                bold: true
            }
        }
    }

    PopupWindow {
        id: vpnMenu
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
            enabled: vpnMenu.visible
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: {
                root.escapeHighlight = true
                escapeHighlightTimer.restart()
                root.closeMenu()
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
                anchors { fill: parent; margins: 12 }
                spacing: 8

                Rectangle {
                    id: headerRow
                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
                    radius: 6
                    color: headerHover.hovered ? root.backgroundAlt : "transparent"
                    HoverHandler { id: headerHover }
                    RowLayout {
                        anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                        Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "VPN"
                                color: root.foreground
                                font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize; bold: true }
                            }
                            Text {
                                text: root.connected ? "Connected to " + root.activeVpn : "Not connected"
                                color: root.connected ? root.accent : root.muted
                                elide: Text.ElideRight
                                font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 4 }
                            }
                        }
                        Rectangle {
                            implicitWidth: 42
                            implicitHeight: 22
                            radius: height / 2
                            color: root.connected ? root.accent : root.backgroundAlt
                            Rectangle {
                                width: 16; height: 16; radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: root.connected ? parent.width - width - 3 : 3
                                color: root.connected ? root.backgroundAlt : root.muted
                            }
                            TapHandler {
                                onTapped: {
                                    if (root.connected) root.disconnectVpn()
                                    else if (root.vpnNames.length > 0) root.switchTo(root.vpnNames[0])
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.backgroundAlt }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: root.vpnNames.length === 0 ? 52 : Math.min(root.vpnNames.length * 52, 260)
                    ListView {
                        anchors.fill: parent
                        clip: true
                        spacing: 2
                        model: vpnModel
                        visible: root.vpnNames.length > 0
                        delegate: Rectangle {
                            id: vpnRow
                            required property var modelData
                            readonly property bool isActive: vpnRow.modelData === root.activeVpn
                            width: ListView.view.width
                            height: 50
                            radius: 6
                            color: vpnRowHover.hovered ? root.backgroundAlt : "transparent"
                            HoverHandler { id: vpnRowHover }
                            TapHandler {
                                onTapped: {
                                    console.log("VpnStatus row tap " + vpnRow.modelData + " isActive=" + vpnRow.isActive)
                                    if (vpnRow.isActive) root.disconnectVpn()
                                    else root.switchTo(vpnRow.modelData)
                                }
                            }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                                spacing: 10
                                Text {
                                    Layout.preferredWidth: 24
                                    text: "󰖂"
                                    color: vpnRow.isActive ? root.accent : root.muted
                                    horizontalAlignment: Text.AlignHCenter
                                    font: root.defaultFont
                                }
                                Column {
                                    Layout.fillWidth: true
                                    spacing: 2
                                    Text {
                                        width: parent.width
                                        text: vpnRow.modelData
                                        color: root.foreground
                                        elide: Text.ElideRight
                                        font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 2; bold: vpnRow.isActive }
                                    }
                                    Text {
                                        text: (root.connecting && vpnRow.modelData === root.pendingConnectName) ? "Connecting" + root.dotSuffix : (root.disconnecting && vpnRow.isActive) ? "Disconnecting" + root.dotSuffix : vpnRow.isActive ? "Connected" : "Not connected"
                                        color: ((root.connecting && vpnRow.modelData === root.pendingConnectName) || (root.disconnecting && vpnRow.isActive)) ? root.muted : vpnRow.isActive ? root.accent : root.muted
                                        font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 4 }
                                    }
                                }
                                Rectangle {
                                    Layout.preferredWidth: 42
                                    Layout.preferredHeight: 22
                                    radius: height / 2
                                    color: vpnRow.isActive ? root.accent : root.backgroundAlt
                                    Rectangle {
                                        width: 16; height: 16; radius: width / 2
                                        anchors.verticalCenter: parent.verticalCenter
                                        x: vpnRow.isActive ? parent.width - width - 3 : 3
                                        color: vpnRow.isActive ? root.backgroundAlt : root.muted
                                    }
                                }
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: root.vpnNames.length === 0
                        text: "No VPN connections (add .conf to /etc/wireguard)"
                        color: root.muted
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                        width: parent.width - 16
                        font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 3 }
                    }
                }

                Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: root.backgroundAlt }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 38
                    radius: 6
                    color: settingsHover.hovered ? root.backgroundAlt : "transparent"
                    HoverHandler { id: settingsHover }
                    TapHandler {
                        onTapped: {
                            Quickshell.execDetached(["env", "XDG_CURRENT_DESKTOP=GNOME", "gnome-control-center", "network"])
                            root.closeMenu()
                        }
                    }
                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8 }
                        text: "Open Network Settings…"
                        color: root.foreground
                        font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 2 }
                    }
                    Text {
                        anchors { verticalCenter: parent.verticalCenter; right: parent.right; rightMargin: 8 }
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
        windows: [vpnMenu, root.barWindow]
        onCleared: { if (vpnMenu.visible) root.closeMenu() }
    }
}

import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
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

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool sinkReady: root.sink && root.sink.audio
    readonly property bool outputMuted: root.sinkReady && root.sink.audio.muted
    readonly property real outputVolume: root.sinkReady ? root.sink.audio.volume : 0
    readonly property var streams: {
        const nodes = Pipewire.nodes ? Pipewire.nodes.values : [];
        return nodes
            .filter(node => node.isStream && node.properties["media.class"] === "Stream/Output/Audio")
            .sort((left, right) => root.streamDisplayName(left).localeCompare(root.streamDisplayName(right)));
    }
    readonly property bool highlighted: indicatorHover.hovered || audioMenu.visible || escapeHighlight
    property bool escapeHighlight: false

    signal menuOpened

    implicitWidth: Math.max(32, indicatorRow.implicitWidth + 16)
    implicitHeight: barHeight
    color: background

    function streamDisplayName(node) {
        if (!node) {
            return "Unknown app";
        }

        return node.properties["application.name"]
            || node.properties["application.process.binary"]
            || node.nickname
            || node.description
            || node.name
            || "Unknown app";
    }

    function closeMenu() {
        audioMenu.visible = false;
        menuFocusGrab.active = false;
    }

    function openMenu() {
        root.menuOpened();
        audioMenu.anchor.updateAnchor();
        audioMenu.visible = true;
        Qt.callLater(() => {
            if (audioMenu.visible) {
                menuFocusGrab.active = true;
            }
        });
    }

    PwObjectTracker {
        objects: [root.sink, ...(Pipewire.nodes ? Pipewire.nodes.values : [])].filter(item => item)
    }

    ScriptModel {
        id: outputStreams

        values: root.streams
    }

    Timer {
        id: escapeHighlightTimer

        interval: 100
        onTriggered: root.escapeHighlight = false
    }

    HoverHandler {
        id: indicatorHover
    }

    TapHandler {
        onTapped: {
            if (audioMenu.visible) {
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
            text: root.outputMuted ? "\uF026" : "\uF028"
            color: {
                if (root.highlighted) {
                    return root.backgroundAlt;
                } else if (!root.sinkReady || root.outputMuted) {
                    return root.muted;
                } else {
                    return root.accent;
                }
            }
            font: root.defaultFont
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.sinkReady
            text: `${Math.round(root.outputVolume * 100)}%`
            color: {
                if (root.highlighted) {
                    return root.backgroundAlt;
                } else if (!root.sinkReady || root.outputMuted) {
                    return root.muted;
                } else {
                    return root.accent;
                }
            }
            font {
                family: root.defaultFont.family
                pixelSize: root.defaultFont.pixelSize - 3
                bold: true
            }
        }
    }

    PopupWindow {
        id: audioMenu

        anchor {
            item: root
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }

        implicitWidth: 320
        implicitHeight: menuColumn.implicitHeight + 24
        color: "transparent"

        Shortcut {
            enabled: audioMenu.visible
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
                    id: deviceRow

                    Layout.fillWidth: true
                    Layout.preferredHeight: 42
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

                        Text {
                            width: parent.width
                            text: {
                                if (!root.sink) {
                                    return "No output device";
                                }

                                const name = root.sink.description || root.sink.name;
                                return root.outputMuted ? `${name} (muted)` : name;
                            }
                            elide: Text.ElideRight
                            color: root.muted
                            font {
                                family: root.defaultFont.family
                                pixelSize: root.defaultFont.pixelSize - 2
                            }
                        }

                        Rectangle {
                            implicitWidth: 42
                            implicitHeight: 22
                            radius: height / 2
                            color: !root.sinkReady || !root.outputMuted ? root.accent : root.backgroundAlt
                            opacity: root.sinkReady ? 1 : 0.5

                            Rectangle {
                                width: 16
                                height: 16
                                radius: width / 2
                                anchors.verticalCenter: parent.verticalCenter
                                x: !root.sinkReady || !root.outputMuted ? parent.width - width - 3 : 3
                                color: !root.sinkReady || !root.outputMuted ? root.backgroundAlt : root.muted
                            }

                            TapHandler {
                                enabled: root.sinkReady
                                onTapped: root.sink.audio.muted = !root.sink.audio.muted
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.backgroundAlt
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    opacity: root.sinkReady ? 1 : 0.45

                    VolumeSlider {
                        id: masterSlider

                        Layout.fillWidth: true
                        enabled: root.sinkReady
                        value: root.outputVolume
                        backgroundAlt: root.backgroundAlt
                        accent: root.accent
                        foreground: root.foreground
                        onMoved: value => {
                            if (root.sinkReady) {
                                root.sink.audio.volume = value;
                            }
                        }
                    }

                    Text {
                        Layout.preferredWidth: 44
                        text: `${Math.round(masterSlider.displayValue * 100)}%`
                        horizontalAlignment: Text.AlignRight
                        color: root.muted
                        font {
                            family: root.defaultFont.family
                            pixelSize: root.defaultFont.pixelSize - 2
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.backgroundAlt
                }

                Text {
                    Layout.fillWidth: true
                    visible: outputStreams.values.length > 0
                    text: "Apps"
                    color: root.muted
                    font {
                        family: root.defaultFont.family
                        pixelSize: root.defaultFont.pixelSize - 4
                        bold: true
                    }
                }

                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.min(outputStreams.values.length * 48, 240)

                    ListView {
                        anchors.fill: parent
                        clip: true
                        spacing: 2
                        model: outputStreams
                        visible: outputStreams.values.length > 0

                        delegate: Rectangle {
                            id: streamRow

                            required property var modelData

                            readonly property var node: streamRow.modelData
                            readonly property bool nodeReady: streamRow.node && streamRow.node.audio

                            width: ListView.view.width
                            height: 46
                            radius: 6
                            color: streamRowHover.hovered ? root.backgroundAlt : "transparent"

                            HoverHandler {
                                id: streamRowHover
                            }

                            RowLayout {
                                anchors {
                                    fill: parent
                                    leftMargin: 8
                                    rightMargin: 8
                                }
                                spacing: 10

                                Rectangle {
                                    id: streamMuteButton

                                    Layout.preferredWidth: 26
                                    Layout.preferredHeight: 26
                                    radius: 6
                                    opacity: streamRow.nodeReady ? 1 : 0.45
                                    color: streamMuteHover.hovered ? root.backgroundAlt : "transparent"

                                    HoverHandler {
                                        id: streamMuteHover
                                    }

                                    Text {
                                        anchors.centerIn: parent
                                        text: streamRow.nodeReady && streamRow.node.audio.muted ? "\uF026" : "\uF028"
                                        color: streamRow.nodeReady && !streamRow.node.audio.muted ? root.accent : root.muted
                                        font: root.defaultFont
                                    }

                                    TapHandler {
                                        enabled: streamRow.nodeReady
                                        onTapped: streamRow.node.audio.muted = !streamRow.node.audio.muted
                                    }
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: root.streamDisplayName(streamRow.node)
                                    color: root.foreground
                                    elide: Text.ElideRight
                                    font {
                                        family: root.defaultFont.family
                                        pixelSize: root.defaultFont.pixelSize - 2
                                        bold: streamRow.nodeReady && !streamRow.node.audio.muted
                                    }
                                }

                                VolumeSlider {
                                    Layout.preferredWidth: 110
                                    enabled: streamRow.nodeReady
                                    value: streamRow.nodeReady ? streamRow.node.audio.volume : 0
                                    backgroundAlt: root.backgroundAlt
                                    accent: root.accent
                                    foreground: root.foreground
                                    onMoved: value => {
                                        if (streamRow.nodeReady) {
                                            streamRow.node.audio.volume = value;
                                        }
                                    }
                                }

                                Text {
                                    Layout.preferredWidth: 40
                                    text: `${Math.round((streamRow.nodeReady ? streamRow.node.audio.volume : 0) * 100)}%`
                                    horizontalAlignment: Text.AlignRight
                                    color: root.muted
                                    font {
                                        family: root.defaultFont.family
                                        pixelSize: root.defaultFont.pixelSize - 3
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    HyprlandFocusGrab {
        id: menuFocusGrab

        windows: [audioMenu, root.barWindow]
        onCleared: {
            if (audioMenu.visible) {
                root.closeMenu();
            }
        }
    }

}

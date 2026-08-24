import Quickshell
import Quickshell.Hyprland
import QtQuick

Row {
    id: root

    required property int barHeight
    required property font defaultFont
    required property color background
    required property color backgroundAlt
    required property color foreground
    required property color accent
    required property color muted
    required property color red

    signal tapped

    spacing: 5

    Repeater {
        model: Hyprland.workspaces

        Rectangle {
            required property var modelData

            implicitWidth: Math.max(24, workspaceLabel.implicitWidth + 1.25 * workspaceLabel.font.pixelSize)
            implicitHeight: root.barHeight
            radius: 6

            color: root.background

            HoverHandler {
                id: workspaceHover
            }

            TapHandler {
                onTapped: {
                    root.onTapped();
                    const workspace = JSON.stringify(modelData.name);
                    Quickshell.execDetached([
                        "hyprctl",
                        "--batch",
                        `eval hl.animation({ leaf = "workspaces", enabled = false });
                        dispatch hl.dsp.focus({ workspace = ${workspace} });
                        reload`
                    ]);
                }
            }

            InnerBackground {
                color: {
                    if (modelData.focused) {
                        return root.accent
                    } else if (workspaceHover.hovered) {
                        return root.muted
                    } else {
                        return root.background
                    }
                }
            }

            Text {
                id: workspaceLabel

                anchors.centerIn: parent

                text: modelData.name
                color: {
                    if (modelData.urgent) {
                        return root.red
                    } else if (modelData.focused || workspaceHover.hovered) {
                        return root.backgroundAlt
                    } else {
                        return root.foreground
                    }
                }

                font {
                    family: defaultFont.family
                    pixelSize: defaultFont.pixelSize
                    bold: modelData.focused
                }
            }
        }
    }
}

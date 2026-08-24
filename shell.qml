import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ShellRoot {
    id: root

    // Palette derived from the current wallpaper via matugen Material You (~/dotfiles/matugen-dotfiles/output/material.json via home-manager).
    // Falls back to the static theme when the state file has not been generated yet.
    function themeColor(value, fallback) {
        if (value === undefined || value === null || value === "") {
            return fallback;
        }

        return value.startsWith("#") ? value : `#${value}`;
    }

    FileView {
        id: walColorsFile

        path: `${Quickshell.env("HOME")}/dotfiles/matugen-dotfiles/output/material.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: walColors

            property JsonObject special: JsonObject {
                property string background: ""
                property string foreground: ""
            }

            property JsonObject colors: JsonObject {
                property string primary: ""
                property string secondary: ""
                property string tertiary: ""
                property string error: ""
                property string surface: ""
                property string surface_container: ""
                property string outline: ""
                property string background: ""
                property string on_background: ""
                property string on_surface: ""
            }
        }
    }

    readonly property color background: {
        const v = walColors.colors.surface || walColors.special.background;
        if (v === "") return "#ee111318";
        const c = v.replace("#", "");
        return c.length === 8 ? `#${c}` : `#ee${c}`;
    }
    readonly property color backgroundAlt: root.themeColor(walColors.colors.surface_container || walColors.colors.background, "#1a1d24")
    readonly property color foreground: root.themeColor(walColors.colors.on_surface || walColors.special.foreground, "#e6e9ef")
    readonly property color muted: root.themeColor(walColors.colors.outline, "#8b93a7")
    readonly property color accent: root.themeColor(walColors.colors.primary, "#62d6e8")
    readonly property color red: root.themeColor(walColors.colors.error, "#ff7a90")
    readonly property color secondary: root.themeColor(walColors.colors.secondary, "#8ec6e6")
    readonly property color tertiary: root.themeColor(walColors.colors.tertiary, "#d4bbff")

    readonly property font defaultFont: Qt.font({
        family: "InconsolataGo NerdFont",
        pixelSize: 18
    })

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    Process {
        id: launcher
        command: ["rofi", "-show", "drun"]
    }

    Notifications {
        defaultFont: root.defaultFont
        background: root.background
        backgroundAlt: root.backgroundAlt
        foreground: root.foreground
        muted: root.muted
        accent: root.accent
        red: root.red
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar

            required property var modelData

            screen: modelData
            implicitHeight: 38
            color: root.background

            anchors {
                top: true
                left: true
                right: true
            }

            Item {
                id: barContent

                anchors.fill: parent

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        audioStatus.closeMenu();
                        bluetoothStatus.closeMenu();
                        networkStatus.closeMenu();
                    }
                }

                Rectangle {
                    id: rofi

                    anchors.left: parent.left

                    implicitWidth: rofiLabel.implicitWidth + 1.25 * rofiLabel.font.pixelSize
                    implicitHeight: bar.implicitHeight

                    color: root.background

                    HoverHandler {
                        id: rofiHover
                    }

                    TapHandler {
                        onTapped: {
                            audioStatus.closeMenu();
                            bluetoothStatus.closeMenu();
                            networkStatus.closeMenu();
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
                            family: defaultFont.family
                            pixelSize: defaultFont.pixelSize
                            bold: true
                        }
                    }
                }

                Row {
                    id: workspaces

                    anchors.centerIn: parent
                    spacing: 5

                    Repeater {
                        model: Hyprland.workspaces

                        Rectangle {
                            required property var modelData

                            implicitWidth: Math.max(24, workspaceLabel.implicitWidth + 1.25 * workspaceLabel.font.pixelSize)
                            implicitHeight: bar.implicitHeight
                            radius: 6

                            color: root.background

                            HoverHandler {
                                id: workspaceHover
                            }

                            TapHandler {
                                onTapped: {
                                    audioStatus.closeMenu();
                                    bluetoothStatus.closeMenu();
                                    networkStatus.closeMenu();
                                    const workspace = JSON.stringify(modelData.name);
                                    Quickshell.execDetached([
                                        "hyprctl",
                                        "--batch",
                                        `eval hl.animation({ leaf = "workspaces", enabled = false });
                                        dispatch hl.dsp.focus({ workspace = ${workspace} });
                                        eval hl.animation({ leaf = "workspaces", enabled = true, speed = 1.8, spring = "snappy", style = "slide" })`
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

                Row {
                    id: time

                    anchors {
                        right: parent.right
                        rightMargin: 20
                    }

                    readonly property color defaultColor: root.foreground
                    readonly property font font: Qt.font({
                        family: root.defaultFont.family,
                        pixelSize: root.defaultFont.pixelSize + 1,
                        bold: false
                    })

                    Rectangle {
                        implicitWidth: dateText.implicitWidth
                        implicitHeight: bar.implicitHeight

                        color: root.background

                        Text {
                            id: dateText

                            anchors.centerIn: parent

                            text: {
                                let locale = Qt.locale("ja_JP")

                                let now = systemClock.date;
                                let dateStr = now.toLocaleDateString(locale, Locale.ShortFormat) // yyyy/mm/dd
                                let dayOfWeek = now.toLocaleDateString(locale, "ddd"); // e.g. 水

                                return `${dateStr} (${dayOfWeek})`
                            }

                            color: time.defaultColor
                            font: time.font
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: " | "
                        color: time.defaultColor
                        font: time.font
                    }

                    Rectangle {
                        implicitWidth: timeText.implicitWidth
                        implicitHeight: bar.implicitHeight

                        color: root.background

                        Text {
                            id: timeText

                            anchors.centerIn: parent

                            text: Qt.formatDateTime(systemClock.date, "HH:mm:ss")

                            font {
                                family: time.font.family
                                pixelSize: time.font.pixelSize
                                bold: systemClock.hours < 5
                            }

                            color: font.bold ? root.red : root.foreground
                        }
                    }
                }

                AudioStatus {
                    id: audioStatus

                    anchors {
                        right: bluetoothStatus.left
                        rightMargin: 2
                        verticalCenter: parent.verticalCenter
                    }

                    barHeight: bar.implicitHeight
                    barWindow: bar
                    defaultFont: root.defaultFont
                    background: root.background
                    backgroundAlt: root.backgroundAlt
                    foreground: root.foreground
                    muted: root.muted
                    accent: root.accent
                    red: root.red

                    onMenuOpened: {
                        bluetoothStatus.closeMenu();
                        networkStatus.closeMenu();
                    }
                }

                BluetoothStatus {
                    id: bluetoothStatus

                    anchors {
                        right: networkStatus.left
                        rightMargin: 2
                        verticalCenter: parent.verticalCenter
                    }

                    barHeight: bar.implicitHeight
                    barWindow: bar
                    defaultFont: root.defaultFont
                    background: root.background
                    backgroundAlt: root.backgroundAlt
                    foreground: root.foreground
                    muted: root.muted
                    accent: root.accent
                    red: root.red

                    onMenuOpened: {
                        audioStatus.closeMenu();
                        networkStatus.closeMenu();
                    }
                }

                NetworkStatus {
                    id: networkStatus

                    anchors {
                        right: time.left
                        rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }

                    barHeight: bar.implicitHeight
                    barWindow: bar
                    defaultFont: root.defaultFont
                    background: root.background
                    backgroundAlt: root.backgroundAlt
                    foreground: root.foreground
                    muted: root.muted
                    accent: root.accent
                    red: root.red
                    secondary: root.secondary
                    tertiary: root.tertiary

                    onMenuOpened: {
                        audioStatus.closeMenu();
                        bluetoothStatus.closeMenu();
                    }
                }
            }
        }
    }
}

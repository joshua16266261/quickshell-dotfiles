import Quickshell
import Quickshell.Io
import QtQuick

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
                        vpnStatus.closeMenu();
                        networkStatus.closeMenu();
                    }
                }

                ///////////////////////
                //// Left -> Right ////
                ///////////////////////
                Rofi {
                    id: rofi

                    anchors {
                        left: parent.left
                        verticalCenter: parent.verticalCenter
                    }

                    barHeight: bar.implicitHeight
                    defaultFont: root.defaultFont
                    background: root.background
                    backgroundAlt: root.backgroundAlt
                    accent: root.accent

                    onTapped: {
                        audioStatus.closeMenu();
                        bluetoothStatus.closeMenu();
                        vpnStatus.closeMenu();
                        networkStatus.closeMenu();
                    }
                }

                Workspaces {
                    id: workspaces

                    anchors {
                        left: rofi.right
                        leftMargin: 5
                        verticalCenter: parent.verticalCenter
                    }

                    barHeight: bar.implicitHeight
                    defaultFont: root.defaultFont
                    background: root.background
                    backgroundAlt: root.backgroundAlt
                    foreground: root.foreground
                    accent: root.accent
                    muted: root.muted
                    red: root.red

                    onTapped: {
                        audioStatus.closeMenu();
                        bluetoothStatus.closeMenu();
                        vpnStatus.closeMenu();
                        networkStatus.closeMenu();
                    }
                }

                ///////////////////////
                //// Right -> Left ////
                ///////////////////////
                Time {
                    id: time

                    anchors {
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                    }

                    barHeight: bar.implicitHeight
                    defaultFont: root.defaultFont
                    background: root.background
                    foreground: root.foreground
                    red: root.red
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
                        vpnStatus.closeMenu();
                    }
                }

                VpnStatus {
                    id: vpnStatus

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
                        bluetoothStatus.closeMenu();
                        networkStatus.closeMenu();
                    }
                }

                BluetoothStatus {
                    id: bluetoothStatus

                    anchors {
                        right: vpnStatus.left
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
                        vpnStatus.closeMenu();
                        networkStatus.closeMenu();
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
                        vpnStatus.closeMenu();
                        networkStatus.closeMenu();
                    }
                }
            }
        }
    }
}

import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Qt.labs.folderlistmodel
import QtQuick

ShellRoot {
    id: root

    readonly property string homeDir: Quickshell.env("HOME")
    readonly property string wallpaperDir: `${root.homeDir}/dotfiles/wallpapers-dotfiles`
    readonly property string scriptPath: `${root.homeDir}/.local/bin/set-wallpaper`
    readonly property string thumbCacheDir: `${root.wallpaperDir}/.cache/200x112`
    readonly property color background: pickerWal.colors.surface || pickerWal.special.background || "#111318"
    readonly property color foreground: pickerWal.colors.on_surface || pickerWal.special.foreground || "#e6e9ef"
    readonly property color accent: pickerWal.colors.primary || pickerWal.colors.color6 || "#62d6e8"

    property string originalWallpaper: ""
    property int hoveredIndex: 0
    property string previewedPath: ""
    property string lastWalPath: ""

    function withAlpha(color, alpha) {
        return `#${alpha}${color.toString().replace("#", "")}`;
    }

    function imageUrl(path) {
        return path === "" ? "" : "file://" + encodeURI(path);
    }

    function thumbUrl(path) {
        if (path === "") {
            return "";
        }
        const fileName = path.split("/").pop();
        const base = fileName.replace(/\.[^.]+$/, "");
        return "file://" + encodeURI(`${root.thumbCacheDir}/${base}.jpg`);
    }

    function candidateAt(index) {
        const count = folderModel.count;
        if (count === 0 || index < 0) {
            return "";
        }

        root.hoveredIndex = Math.max(0, Math.min(index, count - 1));
        return folderModel.get(root.hoveredIndex, "filePath") ?? "";
    }

    function syncPreview() {
        const path = root.candidateAt(root.hoveredIndex);
        if (path === "" || path === root.previewedPath) {
            return;
        }

        root.previewedPath = path;
    }

    function requestWalPreview() {
        const path = root.candidateAt(root.hoveredIndex);
        if (path === "" || path === root.lastWalPath) {
            return;
        }

        root.lastWalPath = path;
        root.runSetWallpaper(["--preview", path]);
    }

    function runSetWallpaper(args) {
        Quickshell.execDetached([root.scriptPath, ...args]);
    }

    function confirmSelection() {
        const path = root.candidateAt(root.hoveredIndex);
        if (path !== "") {
            root.runSetWallpaper([path]);
        }
        Qt.quit();
    }

    function cancelSelection() {
        if (root.originalWallpaper !== "" && root.previewedPath !== root.originalWallpaper) {
            root.runSetWallpaper([root.originalWallpaper]);
        }
        Qt.quit();
    }

    FileView {
        id: stateFile

        path: `${root.homeDir}/dotfiles/matugen-dotfiles/state/current`
        printErrors: false

        onLoaded: {
            root.originalWallpaper = stateFile.text().trim();
            if (root.previewedPath === "") {
                root.previewedPath = root.originalWallpaper;
            }
            if (root.lastWalPath === "") {
                root.lastWalPath = root.originalWallpaper;
            }
        }
    }

    FileView {
        path: `${root.homeDir}/dotfiles/matugen-dotfiles/output/material.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: pickerWal

            property JsonObject special: JsonObject {
                property string background: ""
                property string foreground: ""
            }

            property JsonObject colors: JsonObject {
                property string primary: ""
                property string color6: ""
                property string surface: ""
                property string on_surface: ""
            }
        }
    }

    Process {
        id: applyProcess
    }

    Process {
        id: thumbGenProcess
    }

    Timer {
        id: walDebounce

        interval: 60
        onTriggered: root.requestWalPreview()
    }

    FolderListModel {
        id: folderModel

        folder: "file://" + root.wallpaperDir
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        showDirs: false
        sortField: FolderListModel.Name
    }

    Component.onCompleted: {
        thumbGenProcess.command = [`${root.homeDir}/dotfiles/scripts-dotfiles/generate-thumbs`];
        thumbGenProcess.startDetached();
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: pickerWindow

            required property var modelData

            screen: modelData
            color: "#ee000000"
            exclusiveZone: -1

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            margins {
                top: 38
            }

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            Image {
                id: previewImage

                anchors.fill: parent
                source: root.imageUrl(root.previewedPath)
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                autoTransform: false
                sourceSize.width: pickerWindow.width
                sourceSize.height: pickerWindow.height
            }

            Rectangle {
                id: hintPill

                anchors {
                    horizontalCenter: parent.horizontalCenter
                    top: parent.top
                    topMargin: 16
                }

                implicitWidth: hintText.implicitWidth + 32
                implicitHeight: 36
                radius: 18
                color: root.withAlpha(root.background, "cc")

                Text {
                    id: hintText

                    anchors.centerIn: parent
                    text: folderModel.count === 0
                        ? "No wallpapers found in ~/dotfiles/wallpapers-dotfiles"
                        : "←/→ browse · click thumbnail or press Enter to apply · Esc cancels"
                    color: root.foreground
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 14
                }
            }

            Rectangle {
                id: thumbBar

                anchors.centerIn: parent

                implicitWidth: Math.min(parent.width - 48, thumbList.contentWidth + 24)
                implicitHeight: 150
                radius: 12
                color: root.withAlpha(root.background, "b8")

                ListView {
                    id: thumbList

                    anchors.centerIn: parent
                    width: Math.min(parent.width - 24, contentWidth)
                    height: 126
                    orientation: ListView.Horizontal
                    spacing: 10
                    clip: true
                    cacheBuffer: 800
                    reuseItems: true
                    model: folderModel

                    delegate: Rectangle {
                        id: thumb

                        required property string filePath
                        required property int index

                        readonly property bool active: thumb.index === root.hoveredIndex

                        width: 200
                        height: 112
                        radius: 8
                        color: root.background
                        border.width: active ? 2 : 0
                        border.color: root.accent
                        scale: active ? 1.04 : 1

                        Behavior on scale {
                            enabled: thumb.active
                            NumberAnimation {
                                duration: 100
                            }
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            source: root.thumbUrl(thumb.filePath)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            smooth: false
                            mipmap: false
                            autoTransform: false
                            sourceSize.width: 200
                            sourceSize.height: 112
                            onStatusChanged: {
                                if (status === Image.Error) {
                                    source = root.imageUrl(thumb.filePath);
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor

                            onEntered: {
                                root.hoveredIndex = thumb.index;
                                root.syncPreview();
                                walDebounce.restart();
                            }
                            onClicked: {
                                if (root.hoveredIndex === thumb.index && root.previewedPath !== "") {
                                    root.confirmSelection();
                                } else {
                                    root.hoveredIndex = thumb.index;
                                    root.syncPreview();
                                    root.requestWalPreview();
                                }
                            }
                        }
                    }
                }
            }

            Shortcut {
                sequence: "Escape"
                context: Qt.ApplicationShortcut
                onActivated: root.cancelSelection()
            }

            Shortcut {
                sequence: "Return"
                context: Qt.ApplicationShortcut
                onActivated: root.confirmSelection()
            }

            Shortcut {
                sequence: "Enter"
                context: Qt.ApplicationShortcut
                onActivated: root.confirmSelection()
            }

            Shortcut {
                sequence: "Left"
                context: Qt.ApplicationShortcut
                onActivated: {
                    root.hoveredIndex = Math.max(0, root.hoveredIndex - 1);
                    root.syncPreview();
                    walDebounce.restart();
                }
            }

            Shortcut {
                sequence: "Right"
                context: Qt.ApplicationShortcut
                onActivated: {
                    root.hoveredIndex = Math.min(folderModel.count - 1, root.hoveredIndex + 1);
                    root.syncPreview();
                    walDebounce.restart();
                }
            }
        }
    }
}

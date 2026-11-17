import Quickshell
import Quickshell.Hyprland
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

    function buildKhalAddCommand(text, dateStr) {
        let t = text.trim();
        let start = "";
        let end = "";
        let title = t;
        let m = t.match(/(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})/);
        if (m) {
            const sh = m[1].padStart(2, '0'); const sm = m[2];
            const eh = m[3].padStart(2, '0'); const em = m[4];
            if (parseInt(sh) < 24 && parseInt(eh) < 24 && parseInt(sm) < 60 && parseInt(em) < 60) {
                start = sh + ":" + sm;
                end = eh + ":" + em;
                title = t.replace(m[0], "").trim();
            }
        }
        if (!start) {
            m = t.match(/(\d{1,2}):(\d{2})/);
            if (m && parseInt(m[1]) < 24 && parseInt(m[2]) < 60) {
                start = m[1].padStart(2, '0') + ":" + m[2];
                title = t.replace(m[0], "").trim();
            }
        }
        if (!start) {
            m = t.match(/(\d{1,2})\s*-\s*(\d{1,2})\s*(am|pm)/i);
            if (m) {
                let sh = parseInt(m[1]); let eh = parseInt(m[3]);
                const sAp = m[2].toLowerCase(); const eAp = m[4].toLowerCase();
                if (sAp === 'pm' && sh < 12) sh += 12; if (sAp === 'am' && sh === 12) sh = 0;
                if (eAp === 'pm' && eh < 12) eh += 12; if (eAp === 'am' && eh === 12) eh = 0;
                start = String(sh).padStart(2, '0') + ":00";
                end = String(eh).padStart(2, '0') + ":00";
                title = t.replace(m[0], "").trim();
            } else {
                m = t.match(/(\d{1,2})\s*(am|pm)/i);
                if (m) {
                    let h = parseInt(m[1]); const ap = m[2].toLowerCase();
                    if (ap === 'pm' && h < 12) h += 12; if (ap === 'am' && h === 12) h = 0;
                    start = String(h).padStart(2, '0') + ":00";
                    title = t.replace(m[0], "").trim();
                }
            }
        }
        if (!title) title = "New Event";
        title = title.replace(/^[-–—\s]+/, "").trim();
        if (!title) title = "New Event";
        const safeTitle = title.replace(/'/g, "'\\''");
        if (start && end) return "khal new " + dateStr + " " + start + " " + dateStr + " " + end + " '" + safeTitle + "' 2>&1";
        if (start) return "khal new " + dateStr + " " + start + " '" + safeTitle + "' 2>&1";
        return "khal new " + dateStr + " '" + safeTitle + "' 2>&1";
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
        var c = v.replace("#", "");
        c.length === 8 ? `#${c}` : `#ee${c}`;
        return Qt.rgba(c.r, c.g, c.b, 0.5);
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
                        time.closeMenu();
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
                        time.closeMenu();
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
                        time.closeMenu();
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
                        vpnStatus.closeMenu();
                        time.closeMenu();
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
                        time.closeMenu();
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
                        time.closeMenu();
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
                        time.closeMenu();
                    }
                }
            }
        }

    }

    PanelWindow {
        id: desktopCalendar
        screen: Quickshell.screens[0]
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            left: true
            bottom: true
        }
        margins {
            top: 48
            left: 10
            bottom: 10
        }
        implicitWidth: 400
        implicitHeight: 560
        property var pendingDeleteQueue: []
        property int desktopDeleteCursor: 0
        property var pendingDeleteMap: ({})
        property var pendingAddQueue: []
        property var pendingAddOptimistic: []
        property bool desktopSyncPending: false

        function desktopMakeOptimisticEvent(text, dateStr) {
            let t = text.trim();
            let start = "";
            let end = "";
            let title = t;
            let m = t.match(/(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})/);
            if (m) {
                const sh = m[1].padStart(2, '0'); const sm = m[2];
                const eh = m[3].padStart(2, '0'); const em = m[4];
                if (parseInt(sh) < 24 && parseInt(eh) < 24 && parseInt(sm) < 60 && parseInt(em) < 60) {
                    start = sh + ":" + sm;
                    end = eh + ":" + em;
                    title = t.replace(m[0], "").trim();
                }
            }
            if (!start) {
                m = t.match(/(\d{1,2}):(\d{2})/);
                if (m && parseInt(m[1]) < 24 && parseInt(m[2]) < 60) {
                    start = m[1].padStart(2, '0') + ":" + m[2];
                    title = t.replace(m[0], "").trim();
                }
            }
            if (!start) {
                m = t.match(/(\d{1,2})\s*-\s*(\d{1,2})\s*(am|pm)/i);
                if (m) {
                    let sh = parseInt(m[1]); let eh = parseInt(m[3]);
                    const sAp = m[2].toLowerCase(); const eAp = m[4].toLowerCase();
                    if (sAp === 'pm' && sh < 12) sh += 12; if (sAp === 'am' && sh === 12) sh = 0;
                    if (eAp === 'pm' && eh < 12) eh += 12; if (eAp === 'am' && eh === 12) eh = 0;
                    start = String(sh).padStart(2, '0') + ":00";
                    end = String(eh).padStart(2, '0') + ":00";
                    title = t.replace(m[0], "").trim();
                } else {
                    m = t.match(/(\d{1,2})\s*(am|pm)/i);
                    if (m) {
                        let h = parseInt(m[1]); const ap = m[2].toLowerCase();
                        if (ap === 'pm' && h < 12) h += 12; if (ap === 'am' && h === 12) h = 0;
                        start = String(h).padStart(2, '0') + ":00";
                        title = t.replace(m[0], "").trim();
                    }
                }
            }
            if (!title) title = "New Event";
            title = title.replace(/^[-–—\s]+/, "").trim();
            if (!title) title = "New Event";
            let timeLabel = "";
            if (start && end) timeLabel = start + " – " + end;
            else if (start) timeLabel = start;
            const uid = "pending-" + Date.now() + "-" + Math.random().toString(36).substring(2, 6);
            return { dateKey: dateStr, title: title, timeLabel: timeLabel, uid: uid };
        }

        function desktopQueueSync(silent) {
            if (desktopSyncProc.running) desktopSyncPending = true;
            else {
                if (!silent) desktopWidget.loading = true;
                desktopSyncProc.running = true;
            }
        }

        function desktopHandleKhalOutput(text, isError) {
            if (isError) {
                desktopWidget.events = pendingAddOptimistic.slice();
                pendingDeleteQueue = [];
                pendingDeleteMap = ({});
                desktopDeleteCursor = 0;
                if (pendingAddOptimistic.length === 0) desktopWidget.loading = false;
                return;
            }
            desktopWidget.errorText = "";
            const lines = text.split("\n").filter(l => l.trim() !== "");
            const evts = [];
            for (let i = 0; i < lines.length; i++) {
                if (lines[i].indexOf("|||") === -1) continue;
                const p = lines[i].split("|||");
                if (p.length < 6) continue;
                const dateKey = p[1];
                const startTime = p[2];
                const endTime = p[3];
                const title = p[4];
                const uid = p[5];
                if (!dateKey || !uid) continue;
                let timeLabel = "";
                if (startTime && startTime !== "" && startTime !== "00:00" && endTime && endTime !== "" && endTime !== "00:00") timeLabel = startTime + " – " + endTime;
                else if (startTime && startTime !== "" && startTime !== "00:00") timeLabel = startTime;
                evts.push({ dateKey: dateKey, title: title, timeLabel: timeLabel, uid: uid });
            }
            const stillPending = pendingDeleteQueue.filter(uid => evts.some(e => e.uid === uid));
            const filtered = evts.filter(e => pendingDeleteQueue.indexOf(e.uid) === -1);
            let remainingOptimistic = [];
            for (let i = 0; i < pendingAddOptimistic.length; i++) {
                const opt = pendingAddOptimistic[i];
                const exists = filtered.some(e => e.title === opt.title && e.dateKey === opt.dateKey && e.timeLabel === opt.timeLabel);
                if (!exists) remainingOptimistic.push(opt);
            }
            pendingAddOptimistic = remainingOptimistic.slice();
            const merged = filtered.concat(remainingOptimistic);
            desktopWidget.events = merged;
            if (stillPending.length > 0) {
                pendingDeleteQueue = stillPending.slice();
                let m = Object.assign({}, pendingDeleteMap);
                for (let k in m) if (stillPending.indexOf(k) === -1) delete m[k];
                pendingDeleteMap = m;
                desktopDeleteCursor = 0;
                desktopStartNextDelete();
            } else {
                pendingDeleteQueue = [];
                pendingDeleteMap = ({});
                desktopDeleteCursor = 0;
                if (pendingAddOptimistic.length === 0) desktopWidget.loading = false;
            }
        }

        function desktopStartNextDelete() {
            if (desktopDeleteProc.running) return;
            if (desktopDeleteCursor >= pendingDeleteQueue.length) return;
            const uid = pendingDeleteQueue[desktopDeleteCursor];
            const safeUid = uid.replace(/'/g, "'\\''");
            desktopDeleteProc.command = ["sh", "-c", "find $HOME/.calendars -type f -name '*.ics' -exec grep -F -l 'UID:" + safeUid + "' {} \\; 2>/dev/null | xargs -r rm -f; echo ok 2>&1"];
            desktopDeleteProc.running = true;
            desktopWidget.loading = true;
        }

        function desktopStartNextAdd() {
            if (desktopAddProc.running) return;
            if (pendingAddQueue.length === 0) return;
            const cmd = pendingAddQueue[0];
            desktopAddProc.command = ["sh", "-c", cmd];
            desktopAddProc.running = true;
            desktopWidget.loading = true;
        }

        visible: {
            for (const ws of Hyprland.workspaces.values) {
                if (ws.focused && ws.name === "Desktop") return true;
            }
            return false;
        }

        onVisibleChanged: if (visible) desktopQueueSync()

        StdioCollector { id: desktopKhalCollector; waitForEnd: true }
        StdioCollector { id: desktopKhalErr; waitForEnd: true }
        StdioCollector { id: desktopAddCollector; waitForEnd: true }
        StdioCollector { id: desktopAddErr; waitForEnd: true }
        StdioCollector { id: desktopDelCollector; waitForEnd: true }
        StdioCollector { id: desktopDelErr; waitForEnd: true }
        StdioCollector { id: desktopSyncCollector; waitForEnd: true }
        StdioCollector { id: desktopSyncErr; waitForEnd: true }

        Process {
            id: desktopKhalProc
            command: ["sh", "-c", "khal list --format '{calendar}|||{start-date}|||{start-time}|||{end-time}|||{title}|||{uid}' 2000-01-01 2030-12-31 2>&1 || echo '__KHAL_ERROR__'"]
            stdout: desktopKhalCollector
            stderr: desktopKhalErr
            running: true
            onExited: (code, status) => {
                const text = desktopKhalCollector.text;
                if (text.indexOf("__KHAL_ERROR__") !== -1) {
                    if (text.indexOf("no calendars") !== -1) desktopWidget.errorText = "Setup: vdirsyncer sync && khal configure";
                    else desktopWidget.errorText = text.split("\n").slice(0, 2).join(" ").substring(0, 160);
                    desktopHandleKhalOutput(text, true);
                    return;
                }
                desktopHandleKhalOutput(text, false);
            }
        }

        Process {
            id: desktopAddProc
            stdout: desktopAddCollector
            stderr: desktopAddErr
            onExited: (code, status) => {
                const out = desktopAddCollector.text + desktopAddErr.text;
                if (code !== 0) {
                    desktopWidget.errorText = out.substring(0, 200) || "Failed to add event";
                    if (pendingAddOptimistic.length > 0) {
                        const failedOpt = pendingAddOptimistic[0];
                        desktopWidget.events = desktopWidget.events.filter(e => e.uid !== failedOpt.uid);
                        const ro = pendingAddOptimistic.slice();
                        ro.shift();
                        pendingAddOptimistic = ro;
                    }
                    const failed = pendingAddQueue.slice();
                    if (failed.length > 0) failed.shift();
                    if (failed.length > 0) {
                        pendingAddQueue = failed;
                        desktopStartNextAdd();
                    } else {
                        pendingAddQueue = [];
                        if (pendingAddOptimistic.length === 0) desktopWidget.loading = false;
                        desktopQueueSync();
                    }
                } else {
                    const remaining = pendingAddQueue.slice();
                    if (remaining.length > 0) remaining.shift();
                    if (remaining.length > 0) {
                        pendingAddQueue = remaining;
                        desktopStartNextAdd();
                    } else {
                        pendingAddQueue = [];
                        desktopQueueSync();
                    }
                }
            }
        }

        Process {
            id: desktopDeleteProc
            stdout: desktopDelCollector
            stderr: desktopDelErr
            onExited: (code, status) => {
                const out = desktopDelCollector.text + desktopDelErr.text;
                const curUid = pendingDeleteQueue[desktopDeleteCursor];
                if (code !== 0) {
                    desktopWidget.errorText = out.substring(0, 200) || "Failed to delete";
                    if (curUid && pendingDeleteMap[curUid]) {
                        const ev = pendingDeleteMap[curUid];
                        desktopWidget.events = desktopWidget.events.concat([ev]);
                        let q = pendingDeleteQueue.slice();
                        const idx = q.indexOf(curUid);
                        if (idx !== -1) q.splice(idx, 1);
                        pendingDeleteQueue = q;
                        if (idx !== -1 && idx < desktopDeleteCursor) desktopDeleteCursor--;
                        let m = Object.assign({}, pendingDeleteMap);
                        delete m[curUid];
                        pendingDeleteMap = m;
                        desktopWidget.loading = false;
                    }
                }
                desktopDeleteCursor++;
                if (desktopDeleteCursor < pendingDeleteQueue.length) {
                    desktopStartNextDelete();
                } else {
                    desktopQueueSync(true);
                }
            }
        }

        Process {
            id: desktopSyncProc
            command: ["sh", "-c", "vdirsyncer sync 2>&1; khal list --format '{calendar}|||{start-date}|||{start-time}|||{end-time}|||{title}|||{uid}' 2000-01-01 2030-12-31 2>&1"]
            stdout: desktopSyncCollector
            stderr: desktopSyncErr
            running: false
            onExited: (code, status) => {
                const text = desktopSyncCollector.text + desktopSyncErr.text;
                if (text.indexOf("__KHAL_ERROR__") !== -1) {
                    if (text.indexOf("no calendars") !== -1) desktopWidget.errorText = "Setup: vdirsyncer sync && khal configure";
                    else desktopWidget.errorText = text.split("\n").slice(0, 2).join(" ").substring(0, 160);
                    desktopHandleKhalOutput(text, true);
                } else {
                    desktopHandleKhalOutput(text, false);
                }
                if (desktopSyncPending && !desktopDeleteProc.running && !desktopAddProc.running && pendingDeleteQueue.length === 0) {
                    desktopSyncPending = false;
                    desktopSyncProc.running = true;
                    desktopWidget.loading = true;
                }
            }
        }

        Timer {
            id: desktopRefreshTimer
            interval: 300000
            running: true
            repeat: true
            onTriggered: desktopQueueSync()
        }

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(root.background.r, root.background.g, root.background.b, 0.88)
            radius: 12
            border.width: 1
            border.color: root.backgroundAlt

            CalendarWidget {
                id: desktopWidget
                anchors { fill: parent; margins: 14 }
                defaultFont: root.defaultFont
                background: root.background
                backgroundAlt: root.backgroundAlt
                foreground: root.foreground
                muted: root.muted
                accent: root.accent
                red: root.red
                secondary: root.secondary
                tertiary: root.tertiary
                onRefreshRequested: { desktopCalendar.desktopQueueSync(); }
                onAddEvent: text => {
                    errorText = "";
                    const dateStr = Qt.formatDate(desktopWidget.selectedDate, "yyyy-MM-dd");
                    const cmd = root.buildKhalAddCommand(text, dateStr);
                    const opt = desktopCalendar.desktopMakeOptimisticEvent(text, dateStr);
                    desktopWidget.events = desktopWidget.events.concat([opt]);
                    let ro = desktopCalendar.pendingAddOptimistic.slice();
                    ro.push(opt);
                    desktopCalendar.pendingAddOptimistic = ro;
                    let q = desktopCalendar.pendingAddQueue.slice();
                    q.push(cmd);
                    desktopCalendar.pendingAddQueue = q;
                    if (!desktopAddProc.running) desktopCalendar.desktopStartNextAdd();
                    else loading = true;
                }
                onDeleteEvent: uid => {
                    errorText = "";
                    const toRemove = desktopWidget.events.filter(e => e.uid === uid);
                    for (let i = 0; i < toRemove.length; i++) {
                        let m = Object.assign({}, desktopCalendar.pendingDeleteMap);
                        m[uid] = toRemove[i];
                        desktopCalendar.pendingDeleteMap = m;
                    }
                    desktopWidget.events = desktopWidget.events.filter(e => e.uid !== uid);
                    let q = desktopCalendar.pendingDeleteQueue.slice();
                    if (q.indexOf(uid) === -1) q.push(uid);
                    desktopCalendar.pendingDeleteQueue = q;
                    if (!desktopDeleteProc.running) desktopCalendar.desktopStartNextDelete();
                }
            }
        }
    }
}

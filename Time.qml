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
    required property color secondary
    required property color tertiary

    readonly property font font: Qt.font({
        family: defaultFont.family,
        pixelSize: defaultFont.pixelSize,
        bold: true
    })

    signal menuOpened

    function closeMenu() {
        calendarMenu.visible = false;
        menuFocusGrab.active = false;
        escapeHighlight = false;
    }

    function openMenu() {
        root.menuOpened();
        calendarMenu.anchor.updateAnchor();
        calendarMenu.visible = true;
        queueSync();
        Qt.callLater(() => {
            if (calendarMenu.visible) {
                menuFocusGrab.active = true;
            }
        });
    }

    Timer {
        id: inputFocusTimer
        interval: 60
        repeat: false
        onTriggered: {
            if (calendarMenu.visible) calendarWidget.focusInput();
        }
    }

    function handleKhalOutput(text) {
        if (text.indexOf("__KHAL_ERROR__") !== -1 || text.indexOf("Traceback") !== -1) {
            if (text.trim() === "" || text.indexOf("no calendars") !== -1) {
                calendarWidget.errorText = "No khal calendars. Run: vdirsyncer sync && khal configure";
                calendarWidget.events = pendingAddOptimistic.slice();
            } else {
                calendarWidget.errorText = text.split("\n").slice(0, 3).join(" ").substring(0, 160);
                calendarWidget.events = pendingAddOptimistic.slice();
            }
            pendingDeleteQueue = [];
            pendingDeleteMap = ({});
            deleteCursor = 0;
            if (pendingAddOptimistic.length === 0) calendarWidget.loading = false;
            return;
        }
        calendarWidget.errorText = "";
        const lines = text.split("\n").filter(l => l.trim() !== "");
        const evts = [];
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.indexOf("|||") === -1) continue;
            const parts = line.split("|||");
            if (parts.length < 6) continue;
            const dateKey = parts[1];
            const startTime = parts[2];
            const endTime = parts[3];
            const title = parts[4];
            const uid = parts[5];
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
        calendarWidget.events = merged;
        if (stillPending.length > 0) {
            pendingDeleteQueue = stillPending.slice();
            let m = Object.assign({}, pendingDeleteMap);
            for (let k in m) if (stillPending.indexOf(k) === -1) delete m[k];
            pendingDeleteMap = m;
            deleteCursor = 0;
            startNextDelete();
        } else {
            pendingDeleteQueue = [];
            pendingDeleteMap = ({});
            deleteCursor = 0;
            if (pendingAddOptimistic.length === 0) calendarWidget.loading = false;
        }
    }

    function startNextDelete() {
        if (deleteProc.running) return;
        if (deleteCursor >= pendingDeleteQueue.length) return;
        const uid = pendingDeleteQueue[deleteCursor];
        const safeUid = uid.replace(/'/g, "'\\''");
        deleteProc.command = ["sh", "-c", "find $HOME/.calendars -type f -name '*.ics' -exec grep -F -l 'UID:" + safeUid + "' {} \\; 2>/dev/null | xargs -r rm -f; echo ok 2>&1"];
        deleteProc.running = true;
        calendarWidget.loading = true;
    }

    function startNextAdd() {
        if (addProc.running) return;
        if (pendingAddQueue.length === 0) return;
        const cmd = pendingAddQueue[0];
        addProc.command = ["sh", "-c", cmd];
        addProc.running = true;
        calendarWidget.loading = true;
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

    property bool escapeHighlight: false
    readonly property bool highlighted: dateHover.hovered || calendarMenu.visible || escapeHighlight
    property var pendingDeleteQueue: []
    property int deleteCursor: 0
    property var pendingDeleteMap: ({})
    property var pendingAddQueue: []
    property var pendingAddOptimistic: []
    property bool syncPending: false

    function makeOptimisticEvent(text, dateStr) {
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

    function queueSync(silent) {
        if (syncProc.running) syncPending = true;
        else {
            if (!silent) calendarWidget.loading = true;
            syncProc.running = true;
        }
    }

    implicitWidth: row.implicitWidth
    implicitHeight: barHeight
    color: root.background

    Timer {
        id: escapeHighlightTimer
        interval: 100
        onTriggered: root.escapeHighlight = false
    }

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    readonly property var locale: Qt.locale("ja_JP")
    readonly property date now: systemClock.date

    StdioCollector { id: khalCollector; waitForEnd: true }
    StdioCollector { id: khalErr; waitForEnd: true }
    StdioCollector { id: addCollector; waitForEnd: true }
    StdioCollector { id: addErr; waitForEnd: true }
    StdioCollector { id: delCollector; waitForEnd: true }
    StdioCollector { id: delErr; waitForEnd: true }
    StdioCollector { id: syncCollector; waitForEnd: true }
    StdioCollector { id: syncErr; waitForEnd: true }

    Process {
        id: khalProc
        command: ["sh", "-c", "khal list --format '{calendar}|||{start-date}|||{start-time}|||{end-time}|||{title}|||{uid}' 2000-01-01 2030-12-31 2>&1 || echo '__KHAL_ERROR__'"]
        stdout: khalCollector
        stderr: khalErr
        onExited: (code, status) => {
            handleKhalOutput(khalCollector.text);
        }
    }

    Process {
        id: addProc
        stdout: addCollector
        stderr: addErr
        onExited: (code, status) => {
            const out = addCollector.text + addErr.text;
            if (code !== 0) {
                calendarWidget.errorText = out.substring(0, 200) || "Failed to add event";
                if (pendingAddOptimistic.length > 0) {
                    const failedOpt = pendingAddOptimistic[0];
                    calendarWidget.events = calendarWidget.events.filter(e => e.uid !== failedOpt.uid);
                    const ro = pendingAddOptimistic.slice();
                    ro.shift();
                    pendingAddOptimistic = ro;
                }
                const failed = pendingAddQueue.slice();
                if (failed.length > 0) failed.shift();
                if (failed.length > 0) {
                    pendingAddQueue = failed;
                    startNextAdd();
                } else {
                    pendingAddQueue = [];
                    if (pendingAddOptimistic.length === 0) calendarWidget.loading = false;
                    queueSync();
                }
            } else {
                const remaining = pendingAddQueue.slice();
                if (remaining.length > 0) remaining.shift();
                if (remaining.length > 0) {
                    pendingAddQueue = remaining;
                    startNextAdd();
                } else {
                    pendingAddQueue = [];
                    queueSync();
                }
            }
        }
    }

    Process {
        id: deleteProc
        stdout: delCollector
        stderr: delErr
        onExited: (code, status) => {
            const out = delCollector.text + delErr.text;
            const curUid = pendingDeleteQueue[deleteCursor];
            if (code !== 0) {
                calendarWidget.errorText = out.substring(0, 200) || "Failed to delete event";
                if (curUid && pendingDeleteMap[curUid]) {
                    const ev = pendingDeleteMap[curUid];
                    calendarWidget.events = calendarWidget.events.concat([ev]);
                    let q = pendingDeleteQueue.slice();
                    const idx = q.indexOf(curUid);
                    if (idx !== -1) q.splice(idx, 1);
                    pendingDeleteQueue = q;
                    if (idx !== -1 && idx < deleteCursor) deleteCursor--;
                    let m = Object.assign({}, pendingDeleteMap);
                    delete m[curUid];
                    pendingDeleteMap = m;
                    calendarWidget.loading = false;
                }
            }
            deleteCursor++;
            if (deleteCursor < pendingDeleteQueue.length) {
                startNextDelete();
            } else {
                queueSync(true);
            }
        }
    }

    Process {
        id: syncProc
        command: ["sh", "-c", "vdirsyncer sync 2>&1; khal list --format '{calendar}|||{start-date}|||{start-time}|||{end-time}|||{title}|||{uid}' 2000-01-01 2030-12-31 2>&1"]
        stdout: syncCollector
        stderr: syncErr
        onExited: (code, status) => {
            const text = syncCollector.text + syncErr.text;
            handleKhalOutput(text);
            if (syncPending && !deleteProc.running && !addProc.running && pendingDeleteQueue.length === 0) {
                syncPending = false;
                syncProc.running = true;
                calendarWidget.loading = true;
            }
        }
    }

    Timer {
        id: autoRefresh
        interval: 300000
        running: calendarMenu.visible
        repeat: true
        onTriggered: queueSync()
    }

    Row {
        id: row
        anchors.fill: parent

        Rectangle {
            implicitWidth: dateText.implicitWidth + 12
            implicitHeight: barHeight
            color: root.highlighted ? root.accent : root.background
            Text {
                id: dateText
                anchors.centerIn: parent
                text: Qt.formatDateTime(systemClock.date, "yyyy/MM/dd")
                color: root.highlighted ? root.background : root.foreground
                font: root.font
            }
            HoverHandler { id: dateHover }
            TapHandler {
                onTapped: {
                    if (calendarMenu.visible) root.closeMenu();
                    else root.openMenu();
                }
            }
            InnerBackground { color: root.highlighted ? root.accent : root.background; anchors.leftMargin: 2; anchors.rightMargin: 2 }
        }

        Rectangle {
            implicitWidth: dayOfWeekText.implicitWidth + 6
            implicitHeight: barHeight
            color: root.highlighted ? root.accent : root.background
            Text {
                id: dayOfWeekText
                anchors.centerIn: parent
                text: now.toLocaleDateString(locale, "（ddd）")
                color: root.highlighted ? root.background : root.foreground
                font { family: root.font.family; pixelSize: root.font.pixelSize - 4; bold: true }
            }
            HoverHandler { enabled: false }
            TapHandler { onTapped: { if (calendarMenu.visible) root.closeMenu(); else root.openMenu(); } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "| "
            color: root.foreground
            font: root.font
        }

        Rectangle {
            implicitWidth: timeText.implicitWidth + 20
            implicitHeight: barHeight
            color: root.background
            Text {
                id: timeText
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: Qt.formatDateTime(now, "HH:mm:ss")
                font: root.font
                color: systemClock.hours < 5 ? root.red : root.foreground
            }
        }
    }

    PopupWindow {
        id: calendarMenu
        anchor {
            item: root
            edges: Edges.Bottom | Edges.Right
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }
        implicitWidth: 380
        implicitHeight: Math.min(700, calendarWidget.implicitHeight + 24)
        color: "transparent"
        onVisibleChanged: if (visible) inputFocusTimer.restart()

        Shortcut {
            enabled: calendarMenu.visible
            sequence: "Escape"
            context: Qt.ApplicationShortcut
            onActivated: {
                root.escapeHighlight = true;
                escapeHighlightTimer.restart();
                root.closeMenu();
            }
        }

        Rectangle {
            id: calendarContainer
            anchors.fill: parent
            color: root.background
            radius: 8
            border.width: 1
            border.color: root.backgroundAlt

            CalendarWidget {
                id: calendarWidget
                anchors { fill: parent; margins: 12 }
                defaultFont: root.defaultFont
                background: root.background
                backgroundAlt: root.backgroundAlt
                foreground: root.foreground
                muted: root.muted
                accent: root.accent
                red: root.red
                secondary: root.secondary
                tertiary: root.tertiary
                onRefreshRequested: {
                    queueSync();
                }
                onAddEvent: text => {
                    errorText = "";
                    const dateStr = Qt.formatDate(calendarWidget.selectedDate, "yyyy-MM-dd");
                    const cmd = buildKhalAddCommand(text, dateStr);
                    const opt = makeOptimisticEvent(text, dateStr);
                    calendarWidget.events = calendarWidget.events.concat([opt]);
                    let ro = pendingAddOptimistic.slice();
                    ro.push(opt);
                    pendingAddOptimistic = ro;
                    let q = pendingAddQueue.slice();
                    q.push(cmd);
                    pendingAddQueue = q;
                    if (!addProc.running) startNextAdd();
                    else loading = true;
                }
                onDeleteEvent: uid => {
                    errorText = "";
                    const toRemove = calendarWidget.events.filter(e => e.uid === uid);
                    for (let i = 0; i < toRemove.length; i++) {
                        let m = Object.assign({}, pendingDeleteMap);
                        m[uid] = toRemove[i];
                        pendingDeleteMap = m;
                    }
                    calendarWidget.events = calendarWidget.events.filter(e => e.uid !== uid);
                    let q = pendingDeleteQueue.slice();
                    if (q.indexOf(uid) === -1) q.push(uid);
                    pendingDeleteQueue = q;
                    if (!deleteProc.running) startNextDelete();
                }
            }
        }
    }

    HyprlandFocusGrab {
        id: menuFocusGrab
        windows: [calendarMenu]
        onCleared: { if (calendarMenu.visible) root.closeMenu(); }
        onActiveChanged: {
            if (active && calendarMenu.visible) {
                Qt.callLater(() => calendarWidget.focusInput());
                inputFocusTimer.restart();
            }
        }
    }
}

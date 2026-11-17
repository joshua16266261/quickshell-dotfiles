import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property font defaultFont
    required property color background
    required property color backgroundAlt
    required property color foreground
    required property color muted
    required property color accent
    required property color red
    required property color secondary
    required property color tertiary

    property date currentDate: new Date()
    property date selectedDate: new Date()
    property var events: []
    property bool loading: false
    property string errorText: ""
    property string pendingAddText: ""
    property bool showTimeConfirm: false
    property string timeConfirmMessage: ""

    signal addEvent(string text)
    signal deleteEvent(string uid)
    signal refreshRequested

    function findInvalidTime(text) {
        let m;
        m = text.match(/(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})/);
        if (m) {
            const sh = parseInt(m[1]); const sm = parseInt(m[2]);
            const eh = parseInt(m[3]); const em = parseInt(m[4]);
            if (sh > 23 || sh < 0 || eh > 23 || eh < 0 || sm > 59 || sm < 0 || em > 59 || em < 0) return m[0];
        }
        m = text.match(/(\d{1,2}):(\d{2})\s*(am|pm)/i);
        if (m) {
            const h = parseInt(m[1]); const mi = parseInt(m[2]);
            if (h < 1 || h > 12 || mi > 59 || mi < 0) return m[0];
        }
        m = text.match(/(\d{1,2}):(\d{2})/);
        if (m) {
            const h = parseInt(m[1]); const mi = parseInt(m[2]);
            if (h > 23 || h < 0 || mi > 59 || mi < 0) return m[0];
        }
        m = text.match(/(\d{1,2})\s*-\s*(\d{1,2})\s*(am|pm)/i);
        if (m) {
            const sh = parseInt(m[1]); const eh = parseInt(m[3]);
            if (sh < 1 || sh > 12 || eh < 1 || eh > 12) return m[0];
        }
        m = text.match(/(\d{1,2})\s*(am|pm)/i);
        if (m) {
            const h = parseInt(m[1]);
            if (h < 1 || h > 12) return m[0];
        }
        return "";
    }

    function attemptAdd(rawText) {
        const text = rawText.trim();
        if (text === "") return;
        const invalid = findInvalidTime(text);
        if (invalid !== "") {
            pendingAddText = text;
            timeConfirmMessage = '"' + invalid + '" is not a valid time (hour 00-23, minute 00-59). Create all-day event anyway?';
            showTimeConfirm = true;
            return;
        }
        addEvent(text);
    }

    function confirmAdd() {
        const t = pendingAddText;
        showTimeConfirm = false;
        pendingAddText = "";
        timeConfirmMessage = "";
        if (t !== "") addEvent(t);
    }

    function cancelAdd() {
        showTimeConfirm = false;
        timeConfirmMessage = "";
        pendingAddText = "";
        Qt.callLater(() => focusInput());
    }

    function daysInMonth(y, m) {
        return new Date(y, m + 1, 0).getDate();
    }

    function firstWeekday(y, m) {
        return new Date(y, m, 1).getDay();
    }

    function sameDay(a, b) {
        return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate();
    }

    function formatDay(d) {
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function eventsForDay(d) {
        const key = formatDay(d);
        return root.events.filter(e => e.dateKey === key);
    }

    spacing: 8

    RowLayout {
        Layout.fillWidth: true
        spacing: 8

        Text {
            text: Qt.formatDate(root.currentDate, "MMMM yyyy")
            color: root.foreground
            font {
                family: root.defaultFont.family
                pixelSize: root.defaultFont.pixelSize + 2
                bold: true
            }
            Layout.fillWidth: true
        }

        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 6
            color: prevHover.hovered ? root.backgroundAlt : "transparent"
            Text { anchors.centerIn: parent; text: "‹"; color: root.foreground; font: root.defaultFont }
            HoverHandler { id: prevHover }
            TapHandler {
                onTapped: {
                    const d = new Date(root.currentDate);
                    d.setMonth(d.getMonth() - 1);
                    root.currentDate = d;
                }
            }
        }

        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 6
            color: todayHover.hovered ? root.accent : root.backgroundAlt
            Text { anchors.centerIn: parent; text: "Today"; color: todayHover.hovered ? root.background : root.foreground; font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 4; bold: true } }
            HoverHandler { id: todayHover }
            TapHandler {
                onTapped: {
                    const n = new Date();
                    root.currentDate = new Date(n.getFullYear(), n.getMonth(), 1);
                    root.selectedDate = n;
                }
            }
        }

        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 6
            color: nextHover.hovered ? root.backgroundAlt : "transparent"
            Text { anchors.centerIn: parent; text: "›"; color: root.foreground; font: root.defaultFont }
            HoverHandler { id: nextHover }
            TapHandler {
                onTapped: {
                    const d = new Date(root.currentDate);
                    d.setMonth(d.getMonth() + 1);
                    root.currentDate = d;
                }
            }
        }

        Rectangle {
            implicitWidth: 28
            implicitHeight: 28
            radius: 6
            color: refreshHover.hovered ? root.backgroundAlt : "transparent"
            Text { anchors.centerIn: parent; text: "↻"; color: root.muted; font: root.defaultFont }
            HoverHandler { id: refreshHover }
            TapHandler { onTapped: root.refreshRequested() }
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            Text {
                required property string modelData
                Layout.preferredWidth: 36
                Layout.preferredHeight: 20
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                text: modelData
                color: root.muted
                font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 5; bold: true }
            }
        }

        Repeater {
            id: dayRepeater
            model: 42
            Rectangle {
                required property int index
                readonly property int offset: firstWeekday(root.currentDate.getFullYear(), root.currentDate.getMonth())
                readonly property int dim: daysInMonth(root.currentDate.getFullYear(), root.currentDate.getMonth())
                readonly property int prevDim: daysInMonth(root.currentDate.getFullYear(), root.currentDate.getMonth() - 1)
                readonly property int dayNum: index - offset + 1
                readonly property bool inMonth: dayNum >= 1 && dayNum <= dim
                readonly property int displayDay: inMonth ? dayNum : (dayNum < 1 ? prevDim + dayNum : dayNum - dim)
                readonly property date cellDate: {
                    const y = root.currentDate.getFullYear();
                    const m = root.currentDate.getMonth();
                    if (dayNum < 1) return new Date(y, m - 1, displayDay);
                    if (dayNum > dim) return new Date(y, m + 1, displayDay);
                    return new Date(y, m, displayDay);
                }
                readonly property bool isToday: sameDay(cellDate, new Date())
                readonly property bool isSelected: sameDay(cellDate, root.selectedDate)
                readonly property var dayEvents: eventsForDay(cellDate)
                readonly property bool hasEvents: dayEvents.length > 0

                Layout.preferredWidth: 36
                Layout.preferredHeight: 36
                radius: 6
                color: isSelected ? root.accent : (dayHover.hovered ? root.backgroundAlt : "transparent")
                border.width: isToday && !isSelected ? 1 : 0
                border.color: root.accent
                opacity: inMonth ? 1 : 0.35

                HoverHandler { id: dayHover }
                TapHandler { onTapped: root.selectedDate = cellDate }

                Column {
                    anchors.centerIn: parent
                    spacing: 2
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: displayDay
                        color: isSelected ? root.background : root.foreground
                        font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 2; bold: isSelected || isToday }
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        visible: hasEvents
                        width: 6
                        height: 6
                        radius: 3
                        color: isSelected ? root.background : root.tertiary
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

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Text {
            text: Qt.formatDate(root.selectedDate, "ddd, MMM dd")
            color: root.foreground
            font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 1; bold: true }
            Layout.fillWidth: true
        }
        Text {
            visible: root.loading
            text: "Loading…"
            color: root.muted
            font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 4 }
        }
    }

    Text {
        visible: root.errorText !== ""
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: root.errorText
        color: root.red
        font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 4 }
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(260, agendaList.contentHeight + 4)
        clip: true
        ListView {
            id: agendaList
            anchors.fill: parent
            spacing: 4
            model: eventsForDay(root.selectedDate)
            delegate: Rectangle {
                required property var modelData
                width: agendaList.width
                implicitHeight: eventCol.implicitHeight + 12
                radius: 6
                color: eventHover.hovered ? root.backgroundAlt : Qt.rgba(root.backgroundAlt.r, root.backgroundAlt.g, root.backgroundAlt.b, 0.5)
                HoverHandler { id: eventHover }
                Column {
                    id: eventCol
                    anchors { left: parent.left; right: deleteBtn.left; top: parent.top; margins: 8 }
                    spacing: 2
                    Text {
                        width: parent.width
                        text: modelData.title || "(no title)"
                        color: root.foreground
                        elide: Text.ElideRight
                        font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 2; bold: true }
                    }
                    Text {
                        width: parent.width
                        text: modelData.timeLabel || ""
                        color: root.muted
                        elide: Text.ElideRight
                        font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 4 }
                    }
                }
                Rectangle {
                    id: deleteBtn
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
                    implicitWidth: 32
                    implicitHeight: 24
                    radius: 4
                    color: delHover.hovered ? root.red : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; color: delHover.hovered ? "white" : root.muted; font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 3 } }
                    HoverHandler { id: delHover }
                    TapHandler { onTapped: { if (modelData.uid) root.deleteEvent(modelData.uid); } }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: eventsForDay(root.selectedDate).length === 0 && !root.loading
            text: "No events"
            color: root.muted
            font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 3 }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: root.backgroundAlt
    }

    function focusInput() {
        addInput.forceActiveFocus();
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 6
        Rectangle {
            id: inputBox
            Layout.fillWidth: true
            implicitHeight: 36
            radius: 6
            color: root.backgroundAlt
            TapHandler { onTapped: addInput.forceActiveFocus() }
            TextInput {
                id: addInput
                anchors { fill: parent; margins: 8; leftMargin: 10 }
                verticalAlignment: TextInput.AlignVCenter
                color: root.foreground
                font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 2 }
                clip: true
                activeFocusOnTab: true
                selectByMouse: true
                persistentSelection: true
                onAccepted: {
                    const t = text.trim();
                    if (t === "") return;
                    root.attemptAdd(t);
                    if (!root.showTimeConfirm) text = "";
                }
                Text {
                    anchors { fill: parent; leftMargin: 2 }
                    verticalAlignment: Text.AlignVCenter
                    visible: addInput.text === "" && !addInput.activeFocus
                    text: 'Add: "Dinner" or "15:00-16:00 Meeting" or "3-4 PM Lunch"'
                    color: root.muted
                    font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 3 }
                }
            }
        }
        Rectangle {
            implicitWidth: 54
            implicitHeight: 36
            radius: 6
            color: addHover.hovered ? root.accent : root.backgroundAlt
            Text { anchors.centerIn: parent; text: "Add"; color: addHover.hovered ? root.background : root.foreground; font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 2; bold: true } }
            HoverHandler { id: addHover }
            TapHandler {
                onTapped: {
                    const t = addInput.text.trim();
                    if (t === "") return;
                    root.attemptAdd(t);
                    if (!root.showTimeConfirm) addInput.text = "";
                }
            }
        }
    }

    Rectangle {
        visible: root.showTimeConfirm
        Layout.fillWidth: true
        implicitHeight: visible ? confirmCol.implicitHeight + 16 : 0
        radius: 6
        color: Qt.rgba(root.red.r, root.red.g, root.red.b, 0.12)
        border.width: 1
        border.color: root.red
        ColumnLayout {
            id: confirmCol
            anchors { fill: parent; margins: 8 }
            spacing: 8
            Text {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                text: root.timeConfirmMessage
                color: root.red
                font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 3 }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 6
                    color: cancelHover.hovered ? root.backgroundAlt : "transparent"
                    border.width: 1
                    border.color: root.muted
                    Text { anchors.centerIn: parent; text: "Cancel"; color: root.foreground; font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 2; bold: true } }
                    HoverHandler { id: cancelHover }
                    TapHandler { onTapped: root.cancelAdd() }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 32
                    radius: 6
                    color: confirmHover.hovered ? Qt.rgba(root.red.r, root.red.g, root.red.b, 0.9) : root.red
                    Text { anchors.centerIn: parent; text: "Confirm"; color: "white"; font { family: root.defaultFont.family; pixelSize: root.defaultFont.pixelSize - 2; bold: true } }
                    HoverHandler { id: confirmHover }
                    TapHandler {
                        onTapped: {
                            addInput.text = "";
                            root.confirmAdd();
                        }
                    }
                }
            }
        }
    }
}

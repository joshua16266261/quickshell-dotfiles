import Quickshell
import QtQuick

Row {
    id: root

    required property int barHeight
    required property font defaultFont
    required property color background
    required property color foreground
    required property color red

    readonly property font font: Qt.font({
        family: defaultFont.family,
        pixelSize: defaultFont.pixelSize,
        bold: true
    })

    SystemClock {
        id: systemClock
        precision: SystemClock.Seconds
    }

    readonly property var locale: Qt.locale("ja_JP")
    readonly property date now: systemClock.date

    Rectangle {
        implicitWidth: dateText.implicitWidth
        implicitHeight: barHeight

        color: root.background

        Text {
            id: dateText

            anchors.centerIn: parent

            text: Qt.formatDateTime(systemClock.date, "yyyy/MM/dd")

            color: root.foreground
            font: root.font
        }
    }

    Rectangle {
        implicitWidth: dayOfWeekText.implicitWidth
        implicitHeight: barHeight

        color: root.background

        Text {
            id: dayOfWeekText

            anchors.centerIn: parent

            // e.g.（水）
            // Use the Japanese parentheses instead of the English ones to make sure that the size matches the kanji
            text: now.toLocaleDateString(locale, "（ddd）")

            color: root.foreground
            font {
                family: root.font.family
                pixelSize: root.font.pixelSize - 4
                bold: true
            }
        }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter

        // The day of the week string to the left has a full-width Japanese parenthesis
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

            horizontalAlignment: Text.AlignLeft

            anchors {
                left: parent.left
                verticalCenter: parent.verticalCenter
            }

            text: Qt.formatDateTime(now, "HH:mm:ss")

            font: root.font
            color: systemClock.hours < 5 ? root.red : root.foreground
        }
    }
}

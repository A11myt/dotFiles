import QtQuick
import Quickshell
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.components
import qs.services

// Kalender unter der Uhr: Monat blättern (Pfeile), Wochennummern, heute markiert,
// Punkte an Tagen mit Terminen (Calendars), Klick auf einen Tag zeigt seine Termine
DropPanel {
    id: root
    panel: "calendar"
    alignLeft: true
    panelWidth: 340

    property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    property date selected: new Date()
    onShownChanged: if (shown) { today = new Date(); selected = today; month = today.getMonth(); year = today.getFullYear(); Calendars.refresh(false) }
    readonly property var dayEvents: Calendars.on(selected)
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
    function hm(t) { return Qt.formatTime(new Date(t * 1000), "HH:mm") }
    readonly property var de: Qt.locale("de_DE")
    readonly property int rowH: 32
    function shift(d) { const m = month + d; year += Math.floor(m / 12); month = ((m % 12) + 12) % 12 }

    Text {
        text: root.de.toString(root.today, "dddd, d. MMMM yyyy")
        color: Theme.primary
        font.family: Theme.fontAccent; font.pixelSize: 14
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: root.de.toString(new Date(root.year, root.month, 1), "MMMM yyyy")
            color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; font.bold: true
            Layout.fillWidth: true
        }
        Rectangle {   // neuer Termin (öffnet die große Ansicht mit Formular)
            implicitWidth: 28; implicitHeight: 24; radius: 8
            color: newM.containsMouse ? Theme.primary : "transparent"
            Text { anchors.centerIn: parent; text: "󰐕"; color: newM.containsMouse ? Theme.fgOnPrimary : Theme.primary; font.family: Theme.fontUi; font.pixelSize: 16 }
            MouseArea { id: newM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Panels.close(); Quickshell.execDetached(["qs", "ipc", "call", "calendar", "add"]) } }
        }
        Rectangle {   // große Ansicht
            implicitWidth: 28; implicitHeight: 24; radius: 8
            color: bigM.containsMouse ? Theme.surfaceContainerHighest : "transparent"
            Text { anchors.centerIn: parent; text: "󰊓"; color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 15 }
            MouseArea { id: bigM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Panels.close(); Quickshell.execDetached(["qs", "ipc", "call", "calendar", "toggle"]) } }
        }
        Repeater {
            model: [{ t: "󰅁", d: -1 }, { t: "󰅂", d: 1 }]
            delegate: Rectangle {
                required property var modelData
                implicitWidth: 28; implicitHeight: 24; radius: 8
                color: nav.containsMouse ? Theme.surfaceContainerHighest : "transparent"
                Text { anchors.centerIn: parent; text: modelData.t; color: Theme.fg; font.family: Theme.fontUi }
                MouseArea { id: nav; anchors.fill: parent; hoverEnabled: true; onClicked: root.shift(modelData.d) }
            }
        }
    }
    GridLayout {
        columns: 2
        columnSpacing: 4
        rowSpacing: 2
        Layout.fillWidth: true
        Item { implicitWidth: 1; implicitHeight: 1 }
        DayOfWeekRow {
            locale: Qt.locale("de_DE")
            Layout.fillWidth: true
            delegate: Text { required property string shortName; text: shortName; color: Theme.fgMuted; horizontalAlignment: Text.AlignHCenter; font.family: Theme.fontUi; font.pixelSize: 11 }
        }
        WeekNumberColumn {
            month: root.month; year: root.year
            locale: Qt.locale("de_DE")
            Layout.preferredHeight: root.rowH * 6   // GridLayout gibt sonst kaum Höhe → Zellen 0 px
            delegate: Text { required property int weekNumber; text: weekNumber; color: Theme.outline; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.family: Theme.fontUi; font.pixelSize: 10 }
        }
        MonthGrid {
            id: grid
            month: root.month; year: root.year
            locale: Qt.locale("de_DE")
            Layout.fillWidth: true
            Layout.preferredHeight: root.rowH * 6
            delegate: Rectangle {
                id: cell
                required property var model
                readonly property bool isToday: model.today
                readonly property bool isSel: root.sameDay(model.date, root.selected)
                readonly property var evs: Calendars.events.length ? Calendars.on(model.date) : []
                implicitHeight: 32
                radius: 8
                color: isToday ? Theme.primary : isSel ? Theme.primaryContainer : (dayMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: cell.evs.length ? -3 : 0
                    text: cell.model.day
                    color: cell.isToday ? Theme.fgOnPrimary : (cell.model.month === grid.month ? Theme.fg : Theme.outline)
                    font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
                    font.bold: cell.isToday
                }
                Row {   // bis zu 3 Punkte in Kalenderfarbe
                    anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 4 }
                    spacing: 2
                    Repeater {
                        model: [...new Set(cell.evs.map(e => e.cal))].slice(0, 3)
                        delegate: Rectangle { required property string modelData; width: 4; height: 4; radius: 2; color: cell.isToday ? Theme.fgOnPrimary : Calendars.colorOf(modelData) }
                    }
                }
                MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.selected = cell.model.date }
            }
        }
    }

    // ── Termine des gewählten Tages ──
    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVariant }
    Text {
        text: root.sameDay(root.selected, root.today) ? "Heute" : root.de.toString(root.selected, "dddd, d. MMMM")
        color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; font.bold: true
    }
    Text {
        visible: Calendars.calendars.length === 0
        Layout.fillWidth: true
        text: "Noch kein Kalender verbunden – Einstellungen (SUPER+I) → Kalender"
        color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12; wrapMode: Text.WordWrap
    }
    Text {
        visible: Calendars.calendars.length > 0 && root.dayEvents.length === 0
        text: Calendars.loading ? "Lade Termine …" : "Keine Termine"
        color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12
    }
    Repeater {
        model: root.dayEvents
        delegate: RowLayout {
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            Rectangle { Layout.preferredWidth: 3; Layout.fillHeight: true; Layout.minimumHeight: 30; radius: 2; color: Calendars.colorOf(modelData.cal) }
            ColumnLayout {
                Layout.fillWidth: true; spacing: 0
                Text { Layout.fillWidth: true; text: modelData.title; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; elide: Text.ElideRight }
                Text {
                    Layout.fillWidth: true
                    text: (modelData.allDay ? "ganztägig" : root.hm(modelData.start) + " – " + root.hm(modelData.end)) + (modelData.location ? "  ·  " + modelData.location : "")
                    color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight
                }
            }
        }
    }
}

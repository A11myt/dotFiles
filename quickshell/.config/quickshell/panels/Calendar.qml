import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.components
import qs.services

// Kalender unter der Uhr: Monat blättern (Pfeile), Wochennummern, heute markiert
DropPanel {
    id: root
    panel: "calendar"
    alignLeft: true
    panelWidth: 340

    property date today: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    onShownChanged: if (shown) { today = new Date(); month = today.getMonth(); year = today.getFullYear() }
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
        Repeater {
            model: [{ t: "", d: -1 }, { t: "", d: 1 }]
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
                required property var model
                readonly property bool isToday: model.today
                implicitHeight: 32
                radius: 8
                color: isToday ? Theme.primary : (dayMouse.containsMouse ? Theme.surfaceContainerHighest : "transparent")
                Text {
                    anchors.centerIn: parent
                    text: model.day
                    color: parent.isToday ? Theme.fgOnPrimary : (model.month === grid.month ? Theme.fg : Theme.outline)
                    font.family: Theme.fontUi; font.pixelSize: Theme.fontPx
                    font.bold: parent.isToday
                }
                MouseArea { id: dayMouse; anchors.fill: parent; hoverEnabled: true }
            }
        }
    }
}

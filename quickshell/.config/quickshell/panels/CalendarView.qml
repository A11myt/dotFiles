import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// Große Kalenderansicht (SUPER+Shift+K oder ⤢ im Kalender-Popup):
// Monat mit Terminen in den Tagen, rechts Details zum gewählten Tag.
// ←/→ Monat, T heute, Esc schließt.
PanelWindow {
    id: win
    property bool open: false
    property date today: new Date()
    property date selected: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    readonly property var de: Qt.locale("de_DE")

    visible: open || closing.running
    Timer { id: closing; interval: Theme.anim }
    onOpenChanged: {
        if (open) { today = new Date(); selected = today; month = today.getMonth(); year = today.getFullYear(); Calendars.refresh(false); keys.forceActiveFocus(); Panels.close() }
        else closing.restart()
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-calendar-view"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: 1180
    implicitHeight: 780

    IpcHandler { target: "calendar"; function toggle(): void { win.open = !win.open } }

    function shift(d) { const m = month + d; year += Math.floor(m / 12); month = ((m % 12) + 12) % 12 }
    function sameDay(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
    function hm(t) { return Qt.formatTime(new Date(t * 1000), "HH:mm") }
    // 6 Wochen ab dem Montag vor dem Monatsersten
    readonly property var cells: {
        const first = new Date(year, month, 1)
        const offset = (first.getDay() + 6) % 7
        const out = []
        for (let i = 0; i < 42; i++) out.push(new Date(year, month, 1 - offset + i))
        return out
    }
    readonly property var dayEvents: Calendars.on(selected)

    Rectangle {
        anchors.fill: parent
        radius: 20
        color: Qt.alpha(Theme.surfaceContainer, 0.97)
        border.width: 1
        border.color: Theme.outlineVariant
        opacity: win.open ? 1 : 0
        scale: win.open ? 1 : 0.96
        Behavior on opacity { NumberAnimation { duration: Theme.anim } }
        Behavior on scale { NumberAnimation { duration: Theme.anim; easing.type: Easing.OutCubic } }

        Item {
            id: keys
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape) win.open = false
                else if (e.key === Qt.Key_Left) win.shift(-1)
                else if (e.key === Qt.Key_Right) win.shift(1)
                else if (e.key === Qt.Key_T) { win.today = new Date(); win.selected = win.today; win.month = win.today.getMonth(); win.year = win.today.getFullYear() }
                else return
                e.accepted = true
            }
        }

        RowLayout {
            anchors { fill: parent; margins: 20 }
            spacing: 20

            // ── Monat ──
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Text {
                        text: win.de.toString(new Date(win.year, win.month, 1), "MMMM yyyy")
                        color: Theme.fg; font.family: Theme.fontAccent; font.pixelSize: 26
                        Layout.fillWidth: true
                    }
                    Repeater {
                        model: [{ t: "󰅁", a: -1 }, { t: "Heute", a: 0 }, { t: "󰅂", a: 1 }]
                        delegate: Rectangle {
                            required property var modelData
                            implicitWidth: navTxt.implicitWidth + 22; implicitHeight: 32; radius: 10
                            color: navM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh
                            Text { id: navTxt; anchors.centerIn: parent; text: modelData.t; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx }
                            MouseArea {
                                id: navM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: modelData.a ? win.shift(modelData.a) : (win.selected = win.today, win.month = win.today.getMonth(), win.year = win.today.getFullYear())
                            }
                        }
                    }
                    Text {
                        Layout.leftMargin: 8
                        text: "󰑓"; color: refM.containsMouse ? Theme.primary : Theme.fgMuted
                        font.family: Theme.fontUi; font.pixelSize: 16
                        RotationAnimation on rotation { running: Calendars.loading; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                        MouseArea { id: refM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Calendars.refresh(true) }
                    }
                }

                // Wochentage
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
                        delegate: Text { required property string modelData; Layout.fillWidth: true; Layout.preferredWidth: 1; text: modelData; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter }
                    }
                }

                GridLayout {
                    id: grid
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 6; columnSpacing: 6
                    Repeater {
                        model: win.cells
                        delegate: Rectangle {
                            id: cell
                            required property var modelData
                            readonly property date d: modelData
                            readonly property bool inMonth: d.getMonth() === win.month
                            readonly property bool isToday: win.sameDay(d, win.today)
                            readonly property bool isSel: win.sameDay(d, win.selected)
                            readonly property var evs: Calendars.events.length ? Calendars.on(d) : []
                            readonly property int fits: Math.max(0, Math.floor((height - 30) / 19))
                            Layout.fillWidth: true; Layout.fillHeight: true
                            Layout.preferredWidth: 1; Layout.preferredHeight: 1
                            radius: 10
                            color: isSel ? Qt.alpha(Theme.primary, 0.16) : (cellM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainerHigh)
                            border.width: isSel ? 1 : 0
                            border.color: Theme.primary
                            opacity: inMonth ? 1 : 0.45
                            MouseArea { id: cellM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.selected = cell.d }

                            Rectangle {
                                x: 6; y: 5
                                implicitWidth: Math.max(22, dayNum.implicitWidth + 10); implicitHeight: 22; radius: 11
                                color: cell.isToday ? Theme.primary : "transparent"
                                Text { id: dayNum; anchors.centerIn: parent; text: cell.d.getDate(); color: cell.isToday ? Theme.fgOnPrimary : Theme.fg; font.family: Theme.fontUi; font.pixelSize: 13; font.bold: cell.isToday }
                            }
                            Column {
                                anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 30; leftMargin: 5; rightMargin: 5 }
                                spacing: 2
                                Repeater {
                                    model: cell.evs.slice(0, cell.evs.length > cell.fits ? Math.max(0, cell.fits - 1) : cell.fits)
                                    delegate: Rectangle {
                                        required property var modelData
                                        readonly property color c: Calendars.colorOf(modelData.cal)
                                        width: parent.width; height: 17; radius: 5
                                        color: modelData.allDay ? Qt.alpha(c, 0.35) : "transparent"
                                        Rectangle { visible: !parent.modelData.allDay; width: 3; height: parent.height - 4; anchors.verticalCenter: parent.verticalCenter; radius: 2; color: parent.c }
                                        Text {
                                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 6; rightMargin: 3 }
                                            text: (parent.modelData.allDay ? "" : win.hm(parent.modelData.start) + " ") + parent.modelData.title
                                            color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 11; elide: Text.ElideRight
                                        }
                                    }
                                }
                                Text {
                                    visible: cell.evs.length > cell.fits
                                    text: "+" + (cell.evs.length - Math.max(0, cell.fits - 1)) + " weitere"
                                    color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 10
                                }
                            }
                        }
                    }
                }
            }

            // ── Tag ──
            Rectangle {
                Layout.preferredWidth: 300
                Layout.fillHeight: true
                radius: 14
                color: Theme.surfaceContainerHigh
                ColumnLayout {
                    anchors { fill: parent; margins: 16 }
                    spacing: 10
                    Text { text: win.selected.toLocaleDateString(win.de, "dddd"); color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 13; font.bold: true }
                    Text { text: win.selected.toLocaleDateString(win.de, "d. MMMM yyyy"); color: Theme.fg; font.family: Theme.fontAccent; font.pixelSize: 22 }
                    Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Theme.outlineVariant }
                    Text {
                        visible: Calendars.calendars.length === 0
                        Layout.fillWidth: true; wrapMode: Text.WordWrap
                        text: "Noch kein Kalender verbunden – Einstellungen (SUPER+I) → Kalender"
                        color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12
                    }
                    Text {
                        visible: Calendars.calendars.length > 0 && win.dayEvents.length === 0
                        text: "Keine Termine"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12
                    }
                    Flickable {
                        Layout.fillWidth: true; Layout.fillHeight: true
                        contentHeight: dayCol.implicitHeight; clip: true
                        ColumnLayout {
                            id: dayCol
                            width: parent.width
                            spacing: 10
                            Repeater {
                                model: win.dayEvents
                                delegate: RowLayout {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    spacing: 10
                                    Rectangle { Layout.preferredWidth: 4; Layout.fillHeight: true; Layout.minimumHeight: 36; radius: 2; color: Calendars.colorOf(modelData.cal) }
                                    ColumnLayout {
                                        Layout.fillWidth: true; spacing: 1
                                        Text { Layout.fillWidth: true; text: modelData.title; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 13; font.bold: true; wrapMode: Text.WordWrap }
                                        Text { text: modelData.allDay ? "ganztägig" : win.hm(modelData.start) + " – " + win.hm(modelData.end); color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12 }
                                        Text { visible: !!modelData.location; Layout.fillWidth: true; text: "󰍎 " + (modelData.location ?? ""); color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; wrapMode: Text.WordWrap }
                                        Text { text: modelData.cal; color: Calendars.colorOf(modelData.cal); font.family: Theme.fontUi; font.pixelSize: 10 }
                                    }
                                }
                            }
                        }
                    }
                    Text { text: "←/→ Monat · T heute · Esc schließt"; color: Theme.outline; font.family: Theme.fontUi; font.pixelSize: 10 }
                }
            }
        }
    }
}

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services

// Große Kalenderansicht (SUPER+Shift+K oder ⤢ im Kalender-Popup):
// Monat mit Terminen in den Tagen, rechts Details zum gewählten Tag.
// Neuer Termin: „+ Termin“, Doppelklick auf einen Tag oder N → Notiz in Obsidian/Termine.
// ←/→ Monat, T heute, Esc schließt.
PanelWindow {
    id: win
    property bool open: false
    property date today: new Date()
    property date selected: new Date()
    property int month: today.getMonth()
    property int year: today.getFullYear()
    readonly property var de: Qt.locale("de_DE")
    property bool editing: false
    property string confirmDelete: ""      // Pfad, der beim nächsten Klick gelöscht wird

    visible: open || closing.running
    Timer { id: closing; interval: Theme.anim }
    onOpenChanged: {
        if (open) { today = new Date(); selected = today; month = today.getMonth(); year = today.getFullYear(); Calendars.refresh(false); keys.forceActiveFocus(); Panels.close() }
        else { closing.restart(); editing = false; confirmDelete = "" }
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "qs-calendar-view"
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    color: "transparent"
    implicitWidth: 1180
    implicitHeight: 780

    IpcHandler {
        target: "calendar"
        function toggle(): void { win.open = !win.open }
        function add(): void { win.open = true; win.newEvent(win.selected) }
        // Monat anzeigen, z. B. qs ipc call calendar month 2026 12 („show“ ist bei qs ipc schon belegt)
        function month(y: int, m: int): void { win.open = true; win.year = y; win.month = m - 1; win.selected = new Date(y, m - 1, 1) }
    }

    // ── neuer Termin ──
    function newEvent(d) {
        selected = d
        fTitle.text = ""; fDate.text = Qt.formatDate(d, "dd.MM.yyyy"); fStart.text = ""; fEnd.text = ""; fEndDate.text = ""; fLoc.text = ""; fNote.text = ""
        fAllDay.checked = false; formError = ""
        toGoogle = true; toObsidian = false
        editing = true
        fTitle.forceActiveFocus()
    }
    property string formError: ""
    property bool toGoogle: true          // Google Kalender im Browser vorausgefüllt öffnen
    property bool toObsidian: false       // zusätzlich Notiz in Obsidian/Termine
    // Google-Kalender-Link mit fertig ausgefülltem Termin (dort nur noch „Speichern“)
    function googleUrl(ev) {
        const d = ev.date.replace(/-/g, "")
        let dates
        if (ev.allDay) {
            // Google erwartet als Ende den Tag NACH dem letzten Tag
            const n = new Date((ev.endDate || ev.date) + "T12:00:00"); n.setDate(n.getDate() + 1)
            dates = d + "/" + Qt.formatDate(n, "yyyyMMdd")
        } else {
            const st = new Date(ev.date + "T" + ev.start + ":00")
            const en = ev.end ? new Date(ev.date + "T" + ev.end + ":00") : new Date(st.getTime() + 3600000)
            if (en <= st) en.setDate(en.getDate() + 1)
            dates = Qt.formatDateTime(st, "yyyyMMdd'T'HHmmss") + "/" + Qt.formatDateTime(en, "yyyyMMdd'T'HHmmss")
        }
        return "https://calendar.google.com/calendar/render?action=TEMPLATE"
            + "&text=" + encodeURIComponent(ev.title) + "&dates=" + dates + "&ctz=Europe/Berlin"
            + (ev.location ? "&location=" + encodeURIComponent(ev.location) : "")
            + (ev.note ? "&details=" + encodeURIComponent(ev.note) : "")
    }
    function saveEvent() {
        const t = fTitle.text.trim()
        const dm = fDate.text.trim().match(/^(\d{1,2})\.(\d{1,2})\.(\d{2}|\d{4})$/)
        const tm = v => { const m = v.trim().match(/^(\d{1,2})(?::?(\d{2}))?$/); return m && +m[1] < 24 && +(m[2] ?? 0) < 60 ? String(m[1]).padStart(2, "0") + ":" + (m[2] ?? "00") : null }
        if (!t) { formError = "Titel fehlt"; return }
        if (!dm) { formError = "Datum bitte als TT.MM.JJJJ"; return }
        const y = dm[3].length === 2 ? 2000 + +dm[3] : +dm[3]
        const iso = `${y}-${dm[2].padStart(2, "0")}-${dm[1].padStart(2, "0")}`
        const ev = { title: t, date: iso, allDay: fAllDay.checked, location: fLoc.text.trim(), note: fNote.text }
        // mehrtägig (ganztägig): „Bis“-Datum, TT.MM. reicht (Jahr wie Beginn bzw. nächstes)
        if (fAllDay.checked && fEndDate.text.trim()) {
            const em = fEndDate.text.trim().match(/^(\d{1,2})\.(\d{1,2})\.?(\d{2}|\d{4})?$/)
            if (!em) { formError = "Bis-Datum bitte als TT.MM.JJJJ"; return }
            let ey = em[3] ? (em[3].length === 2 ? 2000 + +em[3] : +em[3]) : y
            let endIso = `${ey}-${em[2].padStart(2, "0")}-${em[1].padStart(2, "0")}`
            if (!em[3] && endIso < iso) endIso = `${y + 1}-${em[2].padStart(2, "0")}-${em[1].padStart(2, "0")}`
            if (endIso < iso) { formError = "Bis-Datum liegt vor dem Beginn"; return }
            if (endIso !== iso) ev.endDate = endIso
        }
        if (!fAllDay.checked) {
            const st = tm(fStart.text), en = fEnd.text.trim() ? tm(fEnd.text) : ""
            if (!st) { formError = "Startzeit bitte als HH:MM (oder ganztägig)"; return }
            if (en === null) { formError = "Endzeit bitte als HH:MM"; return }
            ev.start = st; if (en) ev.end = en
        }
        if (!toGoogle && !toObsidian) { formError = "Bitte Google und/oder Obsidian wählen"; return }
        if (toObsidian) Calendars.addEvent(ev)
        selected = new Date(y, +dm[2] - 1, +dm[1]); month = selected.getMonth(); year = selected.getFullYear()
        editing = false
        if (toGoogle) { Quickshell.execDetached(["xdg-open", googleUrl(ev)]); open = false }   // Browser nach vorn
        else keys.forceActiveFocus()
    }

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

    // mehrtägig = ganztägig über mehr als einen Tag oder mindestens 24 h
    function isMulti(e) { return e.end - e.start > 86400 + 3600 || (e.allDay && e.end - e.start > 90000) }
    function dayIdx(t) {   // Kachel-Index (0–41) des Tages, in dem Zeitpunkt t (s) liegt
        const d = new Date(t * 1000); d.setHours(12, 0, 0, 0)
        const c0 = new Date(cells[0]); c0.setHours(12, 0, 0, 0)
        return Math.round((d - c0) / 86400000)
    }
    // Balkenstücke: { row, c0, c1, lane, first, last, ev } und Spuren pro Woche
    readonly property var barLayout: {
        const multi = Calendars.events.filter(e => isMulti(e)).sort((a, b) => a.start - b.start || b.end - a.end)
        const out = [], lanes = [[], [], [], [], [], []], count = [0, 0, 0, 0, 0, 0]
        for (const ev of multi) {
            const s = dayIdx(ev.start), e = dayIdx(ev.end - 1)
            if (e < 0 || s > 41) continue
            for (let row = Math.max(0, Math.floor(s / 7)); row <= Math.min(5, Math.floor(e / 7)); row++) {
                const c0 = Math.max(s, row * 7) - row * 7, c1 = Math.min(e, row * 7 + 6) - row * 7
                let lane = 0
                while ((lanes[row][lane] ?? []).some(([a, b]) => !(c1 < a || c0 > b))) lane++
                if (!lanes[row][lane]) lanes[row][lane] = []
                lanes[row][lane].push([c0, c1])
                count[row] = Math.max(count[row], lane + 1)
                out.push({ row, c0, c1, lane, first: s >= row * 7, last: e <= row * 7 + 6, ev })
            }
        }
        return { bars: out, lanes: count }
    }
    readonly property var bars: barLayout.bars
    readonly property var lanesPerRow: barLayout.lanes

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
                else if (e.key === Qt.Key_N) win.newEvent(win.selected)
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
                    Rectangle {
                        Layout.leftMargin: 8
                        implicitWidth: addTxt.implicitWidth + 24; implicitHeight: 32; radius: 10
                        color: addM.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary
                        Text { id: addTxt; anchors.centerIn: parent; text: "󰐕  Termin"; color: Theme.fgOnPrimary; font.family: Theme.fontUi; font.pixelSize: Theme.fontPx; font.bold: true }
                        MouseArea { id: addM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.newEvent(win.selected) }
                    }
                    Text {
                        Layout.leftMargin: 8
                        text: "󰑓"; color: refM.containsMouse ? Theme.primary : Theme.fgMuted
                        font.family: Theme.fontUi; font.pixelSize: 16
                        RotationAnimation on rotation { running: Calendars.loading; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                        MouseArea { id: refM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: Calendars.refresh(true) }
                    }
                }

                // Wochentage (Wochenende farbig)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Repeater {
                        model: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]
                        delegate: Text { required property string modelData; required property int index; Layout.fillWidth: true; Layout.preferredWidth: 1; text: modelData; color: index >= 5 ? Theme.tertiary : Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 12; font.bold: index >= 5; horizontalAlignment: Text.AlignHCenter }
                    }
                }

                Item {
                    id: gridArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    readonly property real gap: 6
                    readonly property real cw: (width - 6 * gap) / 7
                    readonly property real ch: (height - 5 * gap) / 6

                    GridLayout {
                        id: grid
                        anchors.fill: parent
                        columns: 7
                        rowSpacing: gridArea.gap; columnSpacing: gridArea.gap
                        Repeater {
                            model: win.cells
                            delegate: Rectangle {
                                id: cell
                                required property var modelData
                                required property int index
                                readonly property date d: modelData
                                readonly property int row: Math.floor(index / 7)
                                readonly property bool inMonth: d.getMonth() === win.month
                                readonly property bool isToday: win.sameDay(d, win.today)
                                readonly property bool isSel: win.sameDay(d, win.selected)
                                readonly property bool weekend: index % 7 >= 5
                                readonly property string holiday: Holidays.name(d)
                                readonly property string special: Holidays.special(d)
                                // mehrtägige Termine liegen als Balken darüber → hier nur die übrigen
                                readonly property var evs: Calendars.events.length ? Calendars.on(d).filter(e => !win.isMulti(e)) : []
                                readonly property int lanes: win.lanesPerRow[row] ?? 0
                                readonly property real listTop: 30 + lanes * 19
                                readonly property int fits: Math.max(0, Math.floor((height - listTop) / 19))
                                readonly property color base: holiday ? Qt.tint(Theme.surfaceContainerHigh, Qt.alpha(Theme.tertiary, 0.20))
                                                            : weekend ? Qt.tint(Theme.surfaceContainerHigh, Qt.alpha(Theme.secondary, 0.09))
                                                            : Theme.surfaceContainerHigh
                                Layout.fillWidth: true; Layout.fillHeight: true
                                Layout.preferredWidth: 1; Layout.preferredHeight: 1
                                radius: 10
                                color: isSel ? Qt.alpha(Theme.primary, 0.16) : (cellM.containsMouse ? Theme.surfaceContainerHighest : base)
                                border.width: isSel ? 1 : 0
                                border.color: Theme.primary
                                opacity: inMonth ? 1 : 0.45
                                MouseArea { id: cellM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.selected = cell.d; win.editing = false } onDoubleClicked: win.newEvent(cell.d) }

                                Rectangle {
                                    id: dayBadge
                                    x: 6; y: 5
                                    implicitWidth: Math.max(22, dayNum.implicitWidth + 10); implicitHeight: 22; radius: 11
                                    color: cell.isToday ? Theme.primary : "transparent"
                                    Text {
                                        id: dayNum; anchors.centerIn: parent; text: cell.d.getDate()
                                        color: cell.isToday ? Theme.fgOnPrimary : (cell.holiday || cell.weekend) ? Theme.tertiary : Theme.fg
                                        font.family: Theme.fontUi; font.pixelSize: 13; font.bold: cell.isToday || cell.holiday !== ""
                                    }
                                }
                                Text {   // Feiertag / Heiligabend / Silvester
                                    visible: text !== ""
                                    anchors { left: dayBadge.right; leftMargin: 4; right: parent.right; rightMargin: 6; verticalCenter: dayBadge.verticalCenter }
                                    text: cell.holiday || cell.special
                                    color: cell.holiday ? Theme.tertiary : Theme.fgMuted
                                    font.family: Theme.fontUi; font.pixelSize: 10; font.italic: !cell.holiday
                                    elide: Text.ElideRight; horizontalAlignment: Text.AlignRight
                                }
                                Column {
                                    anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: cell.listTop; leftMargin: 5; rightMargin: 5 }
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

                    // Mehrtägige Termine als durchgehende Balken über die Kacheln (pro Woche ein Stück)
                    Repeater {
                        model: win.bars
                        delegate: Rectangle {
                            id: bar
                            required property var modelData
                            readonly property color c: Calendars.colorOf(modelData.ev.cal)
                            x: modelData.c0 * (gridArea.cw + gridArea.gap) + 4
                            y: modelData.row * (gridArea.ch + gridArea.gap) + 30 + modelData.lane * 19
                            width: (modelData.c1 - modelData.c0) * (gridArea.cw + gridArea.gap) + gridArea.cw - 8
                            height: 17
                            radius: 5
                            // deckend (getönt), sonst addieren sich die Eck-Flächen sichtbar
                            color: Qt.tint(Theme.surfaceContainerHigh, Qt.alpha(c, barM.containsMouse ? 0.75 : 0.55))
                            // eckig, wo der Balken in die Nachbarwoche weiterläuft
                            Rectangle { visible: !bar.modelData.first; anchors { left: parent.left; top: parent.top; bottom: parent.bottom } width: 6; color: parent.color }
                            Rectangle { visible: !bar.modelData.last; anchors { right: parent.right; top: parent.top; bottom: parent.bottom } width: 6; color: parent.color }
                            Text {
                                anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 7; rightMargin: 5 }
                                text: (bar.modelData.first ? "" : "… ") + bar.modelData.ev.title + (bar.modelData.last && bar.modelData.first ? "" : bar.modelData.last ? "" : "  →")
                                color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 11; font.bold: true; elide: Text.ElideRight
                            }
                            MouseArea { id: barM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.selected = new Date(Math.max(bar.modelData.ev.start * 1000, win.cells[bar.modelData.row * 7].getTime())); win.editing = false } }
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

                // ── Formular: neuer Termin ──
                ColumnLayout {
                    visible: win.editing
                    anchors { fill: parent; margins: 16 }
                    spacing: 10
                    Text { text: "Neuer Termin"; color: Theme.fg; font.family: Theme.fontAccent; font.pixelSize: 20 }
                    Text { text: "Google: öffnet sich ausgefüllt im Browser → dort „Speichern“"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; Layout.fillWidth: true; wrapMode: Text.WordWrap }
                    FormField { id: fTitle; label: "Titel"; placeholder: "z. B. Zahnarzt"; onAccepted: win.saveEvent() }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        FormField { id: fDate; label: fAllDay.checked ? "Von (Datum)" : "Datum"; placeholder: "TT.MM.JJJJ"; onAccepted: win.saveEvent() }
                        FormField { id: fEndDate; visible: fAllDay.checked; label: "Bis (Datum)"; placeholder: "optional"; onAccepted: win.saveEvent() }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Text { text: "Ganztägig"; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; Layout.fillWidth: true }
                        Rectangle {
                            id: fAllDay
                            property bool checked: false
                            implicitWidth: 40; implicitHeight: 22; radius: 11
                            color: checked ? Theme.primary : Theme.surfaceContainerHighest
                            Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; x: parent.checked ? parent.width - width - 3 : 3; color: parent.checked ? Theme.fgOnPrimary : Theme.outline; Behavior on x { NumberAnimation { duration: 120 } } }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: fAllDay.checked = !fAllDay.checked }
                        }
                    }
                    RowLayout {
                        visible: !fAllDay.checked
                        Layout.fillWidth: true
                        spacing: 8
                        FormField { id: fStart; label: "Von"; placeholder: "14:00"; onAccepted: win.saveEvent() }
                        FormField { id: fEnd; label: "Bis"; placeholder: "optional"; onAccepted: win.saveEvent() }
                    }
                    FormField { id: fLoc; label: "Ort"; placeholder: "optional"; onAccepted: win.saveEvent() }
                    Text { text: "Notiz"; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }
                    Rectangle {
                        Layout.fillWidth: true; Layout.fillHeight: true; Layout.minimumHeight: 60
                        radius: 10; color: Theme.surfaceContainer
                        border.width: 1; border.color: fNote.activeFocus ? Theme.primary : Theme.outlineVariant
                        TextEdit {
                            id: fNote
                            anchors { fill: parent; margins: 8 }
                            wrapMode: TextEdit.Wrap
                            color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12
                            Keys.onEscapePressed: { win.editing = false; keys.forceActiveFocus() }
                        }
                    }
                    // Ziele
                    Repeater {
                        model: [{ k: "toGoogle", t: "󰃭  Google Kalender" }, { k: "toObsidian", t: "󱓧  Auch in Obsidian" }]
                        delegate: RowLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            Text { text: modelData.t; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12; Layout.fillWidth: true }
                            Rectangle {
                                readonly property bool on: win[modelData.k]
                                implicitWidth: 40; implicitHeight: 22; radius: 11
                                color: on ? Theme.primary : Theme.surfaceContainerHighest
                                Rectangle { width: 16; height: 16; radius: 8; anchors.verticalCenter: parent.verticalCenter; x: parent.on ? parent.width - width - 3 : 3; color: parent.on ? Theme.fgOnPrimary : Theme.outline; Behavior on x { NumberAnimation { duration: 120 } } }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win[modelData.k] = !win[modelData.k] }
                            }
                        }
                    }
                    Text { visible: win.formError !== ""; text: win.formError; color: Theme.error; font.family: Theme.fontUi; font.pixelSize: 12 }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 34; radius: 10
                            color: cancelM.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
                            Text { anchors.centerIn: parent; text: "Abbrechen"; color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 12 }
                            MouseArea { id: cancelM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { win.editing = false; keys.forceActiveFocus() } }
                        }
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 34; radius: 10
                            color: saveM.containsMouse ? Qt.lighter(Theme.primary, 1.1) : Theme.primary
                            Text { anchors.centerIn: parent; text: "󰄬  Speichern"; color: Theme.fgOnPrimary; font.family: Theme.fontUi; font.pixelSize: 12; font.bold: true }
                            MouseArea { id: saveM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.saveEvent() }
                        }
                    }
                }

                // ── Termine des Tages ──
                ColumnLayout {
                    visible: !win.editing
                    anchors { fill: parent; margins: 16 }
                    spacing: 10
                    Text { text: win.selected.toLocaleDateString(win.de, "dddd"); color: Theme.primary; font.family: Theme.fontUi; font.pixelSize: 13; font.bold: true }
                    Text { text: win.selected.toLocaleDateString(win.de, "d. MMMM yyyy"); color: Theme.fg; font.family: Theme.fontAccent; font.pixelSize: 22 }
                    Text { visible: text !== ""; text: Holidays.name(win.selected) ? "󰃰 " + Holidays.name(win.selected) : Holidays.special(win.selected); color: Theme.tertiary; font.family: Theme.fontUi; font.pixelSize: 12; font.bold: true }
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
                                        // eigene Termine: in Obsidian öffnen / löschen (zweiter Klick bestätigt)
                                        Row {
                                            visible: modelData.cal === "Obsidian" && !!modelData.path
                                            spacing: 12
                                            Text {
                                                text: "󰏌 In Obsidian öffnen"; color: obsM.containsMouse ? Theme.primary : Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11
                                                MouseArea { id: obsM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: { Calendars.openInObsidian(modelData.rel); win.open = false } }
                                            }
                                            Text {
                                                readonly property bool armed: win.confirmDelete === modelData.path
                                                text: armed ? "󰆴 Wirklich löschen?" : "󰆴 Löschen"
                                                color: armed || delM.containsMouse ? Theme.error : Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11; font.bold: armed
                                                MouseArea {
                                                    id: delM; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                                    onClicked: { if (parent.armed) { Calendars.deleteEvent(modelData.path); win.confirmDelete = "" } else win.confirmDelete = modelData.path }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    Text { text: "Doppelklick/N: neuer Termin · ←/→ Monat · T heute · Esc"; color: Theme.outline; font.family: Theme.fontUi; font.pixelSize: 10 }
                }
            }
        }
    }

    // Eingabefeld mit Beschriftung (Esc bricht das Formular ab)
    component FormField: ColumnLayout {
        id: ff
        property alias text: inp.text
        property string label
        property string placeholder
        signal accepted()
        function forceActiveFocus() { inp.forceActiveFocus() }
        Layout.fillWidth: true
        spacing: 3
        Text { text: ff.label; color: Theme.fgMuted; font.family: Theme.fontUi; font.pixelSize: 11 }
        Rectangle {
            Layout.fillWidth: true; implicitHeight: 34; radius: 10
            color: Theme.surfaceContainer
            border.width: 1; border.color: inp.activeFocus ? Theme.primary : Theme.outlineVariant
            TextInput {
                id: inp
                anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                verticalAlignment: TextInput.AlignVCenter
                clip: true
                color: Theme.fg; font.family: Theme.fontUi; font.pixelSize: 13
                onAccepted: ff.accepted()
                Keys.onEscapePressed: { win.editing = false; keys.forceActiveFocus() }
                Text { visible: !inp.text; anchors.verticalCenter: parent.verticalCenter; text: ff.placeholder; color: Theme.outline; font: inp.font }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.IBeamCursor; onClicked: inp.forceActiveFocus() }
        }
    }
}

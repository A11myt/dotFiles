pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Kalender (iCal-Adressen) und Termine. Die Adressen sind geheim → liegen in
// ~/.local/share/quickshell/calendars.json (nicht in den Dotfiles, Rechte 600).
Singleton {
    id: root
    property var calendars: []          // [{ name, url }]
    property var events: []             // aus scripts/calendar.py
    property var errors: []
    property bool loading: proc.running
    readonly property string file: Quickshell.env("HOME") + "/.local/share/quickshell/calendars.json"
    // Farben über den Farbkreis verteilt, ausgehend von der Theme-Farbe → immer unterscheidbar
    function colorOf(cal) {
        const i = Math.max(0, calendars.findIndex(c => c.name === cal))
        const h = (Theme.primary.hslHue + i * 0.38) % 1
        return Qt.hsla(h, Math.max(0.45, Theme.primary.hslSaturation), Theme.isLight ? 0.45 : 0.72, 1)
    }
    function add(name, url) { save(calendars.concat([{ name: name, url: url }])) }
    function remove(i) { save(calendars.filter((_, k) => k !== i)) }
    function save(list) {
        calendars = list
        Quickshell.execDetached(["bash", "-c", 'umask 077; mkdir -p "$(dirname "$1")"; printf "%s" "$2" > "$1"; chmod 600 "$1"', "_", file, JSON.stringify(list)])
        refreshLater.restart()
    }
    function refresh(force) {
        if (proc.running) return
        proc.command = ["python3", "-I", Quickshell.shellDir + "/scripts/ical_events.py", file].concat(force ? ["--refresh"] : [])
        proc.running = true
    }
    // Termine eines Tages (inkl. mehrtägiger Ganztagstermine)
    function on(day) {
        const a = new Date(day.getFullYear(), day.getMonth(), day.getDate()).getTime() / 1000, b = a + 86400
        return events.filter(e => e.start < b && e.end > a && !(e.allDay && e.end === a))
    }

    Timer { id: refreshLater; interval: 600; onTriggered: root.refresh(true) }
    Timer { interval: 15 * 60000; repeat: true; running: root.calendars.length > 0; onTriggered: root.refresh(false) }

    FileView {
        path: root.file
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.calendars = JSON.parse(text()) } catch (e) { root.calendars = [] } root.refresh(false) }
    }
    Process {
        id: proc
        stdout: StdioCollector {
            onStreamFinished: { try { const d = JSON.parse(text); root.events = d.events; root.errors = d.errors } catch (e) {} }
        }
    }
}

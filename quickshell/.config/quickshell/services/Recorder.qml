pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Zustand der Bildschirmaufnahme (scripts/record.sh schreibt $XDG_RUNTIME_DIR/qs-recording)
Singleton {
    id: root
    property bool recording: false
    property int startedAt: 0
    property string file: ""
    property bool hardware: false

    function start(target, audio) { Quickshell.execDetached([Quickshell.shellDir + "/scripts/record.sh", "start", target, audio ? "1" : "0"]) }
    function stop() { Quickshell.execDetached([Quickshell.shellDir + "/scripts/record.sh", "stop"]) }

    FileView {
        path: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-recording"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const p = text().trim().split("\t")
            root.recording = p.length >= 3
            root.startedAt = Number(p[0]) || 0
            root.file = p[2] ?? ""
            root.hardware = p[3] === "hw"
        }
        onLoadFailed: root.recording = false
    }
}

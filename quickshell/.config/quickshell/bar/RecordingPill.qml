import QtQuick
import qs
import qs.components
import qs.services

// Roter Punkt + Laufzeit während einer Bildschirmaufnahme; Klick stoppt
Pill {
    id: p
    want: Recorder.recording
    property int now: Date.now() / 1000
    Timer { interval: 1000; repeat: true; running: Recorder.recording; triggeredOnStart: true; onTriggered: p.now = Date.now() / 1000 }
    readonly property int secs: Math.max(0, now - Recorder.startedAt)
    onClicked: Recorder.stop()
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 10; height: 10; radius: 5
        color: Theme.error
        SequentialAnimation on opacity { running: Recorder.recording; loops: Animation.Infinite; NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } }
    }
    BarText { text: " " + Math.floor(p.secs / 60) + ":" + String(p.secs % 60).padStart(2, "0"); color: Theme.error }
    Tooltip { target: p; show: p.hovered; text: "Aufnahme läuft" + (Recorder.hardware ? " (Hardware-Kodierung)" : "") + " – klicken oder Alt+Druck zum Stoppen" }
}

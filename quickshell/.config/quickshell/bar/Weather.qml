import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components

// gleiches Skript wie bisher (nutzt einen 9-Minuten-Cache), alle 10 Minuten
Pill {
    id: p
    property string txt: "?"
    property string tip: "lädt …"
    BarText { text: p.txt; accent: p.hovered }
    Tooltip { target: p; show: p.hovered; text: p.tip }

    Process {
        id: proc
        command: ["bash", Quickshell.shellDir + "/scripts/weather.sh"]
        stdout: StdioCollector {
            onStreamFinished: { try { const d = JSON.parse(text); p.txt = d.text; p.tip = d.tooltip } catch (e) {} }
        }
    }
    Timer { interval: 600000; running: true; repeat: true; triggeredOnStart: true; onTriggered: proc.running = true }
}

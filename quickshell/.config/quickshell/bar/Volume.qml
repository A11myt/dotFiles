import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.components
import qs.services

Pill {
    id: p
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real vol: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    PwObjectTracker { objects: [p.sink] }
    readonly property bool headphone: { const n = ((sink?.name ?? "") + (sink?.description ?? "")).toLowerCase(); return n.includes("bluez") || n.includes("headphone") || n.includes("headset") }

    onClicked: e => e.button === Qt.RightButton ? (p.sink.audio.muted = !p.muted) : Panels.showPage("audio")
    onScrolled: e => { if (p.sink?.audio) p.sink.audio.volume = Math.max(0, Math.min(1, p.vol + (e.angleDelta.y > 0 ? 0.05 : -0.05))) }
    BarText {
        readonly property int v: Math.round(p.vol * 100)
        text: p.muted ? "󰝟 stumm" : `${p.headphone ? "󰋋" : v > 50 ? "󰕾" : v > 0 ? "󰖀" : "󰕿"} ${v}%`
        accent: p.hovered
    }
    Tooltip { target: p; show: p.hovered; text: (p.sink?.nickname || p.sink?.description || "Kein Ausgabegerät") + "\nKlick: Audio · Rechtsklick: stumm · Scrollen: Lautstärke" }
}

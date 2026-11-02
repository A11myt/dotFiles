import QtQuick
import qs
import qs.components
import qs.services

// Fokus-Timer in der Leiste: Klick = Start/Pause, Rechtsklick = Stopp, Mittelklick = nächste Phase
Pill {
    id: p
    readonly property bool running: Focus.phase !== "idle"
    readonly property color tone: Focus.phase === "work" ? Theme.primary : Theme.tertiary
    onClicked: e => e.button === Qt.RightButton ? Focus.stop() : e.button === Qt.MiddleButton ? Focus.next(false) : Focus.start()

    // kleiner Fortschrittsring
    Canvas {
        id: ring
        visible: p.running
        width: 16; height: 16
        anchors.verticalCenter: parent.verticalCenter
        property real prog: Focus.progress
        property color c: p.tone
        onProgChanged: requestPaint()
        onCChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"); ctx.reset()
            ctx.lineWidth = 2.2
            ctx.strokeStyle = Qt.alpha(c, 0.25); ctx.beginPath(); ctx.arc(8, 8, 6, 0, 2 * Math.PI); ctx.stroke()
            ctx.strokeStyle = c; ctx.beginPath(); ctx.arc(8, 8, 6, -Math.PI / 2, -Math.PI / 2 + 2 * Math.PI * prog); ctx.stroke()
        }
    }
    BarText {
        text: p.running ? " " + (Focus.paused ? "󰏤 " : "") + Focus.label : "󱎫"
        color: p.running ? p.tone : (p.hovered ? Theme.primary : Theme.fg)
    }
    Tooltip {
        target: p; show: p.hovered
        text: p.running ? `${Focus.phaseName} · Runde ${Focus.round}${Focus.paused ? " · pausiert" : ""}\nKlick: ${Focus.paused ? "weiter" : "Pause"} · Rechtsklick: Stopp · Mittelklick: überspringen`
                        : `Fokus-Timer: ${Config.focus.work} min Fokus, ${Config.focus.short} min Pause\nKlick: starten`
    }
}

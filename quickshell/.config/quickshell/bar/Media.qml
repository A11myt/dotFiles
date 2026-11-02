import QtQuick
import Quickshell.Services.Mpris
import qs
import qs.components
import qs.services

Pill {
    id: p
    readonly property var player: Mpris.players.values.find(pl => pl.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property string info: player ? [player.trackArtist, player.trackTitle].filter(Boolean).join(" - ") : ""
    want: info !== ""
    // Klick: Medien-Popup · Mittelklick: Wiedergabe/Pause · Scrollen: nächster/vorheriger Titel
    onClicked: e => e.button === Qt.MiddleButton ? player?.togglePlaying() : Panels.toggle("media")
    onScrolled: e => e.angleDelta.y > 0 ? player?.previous() : player?.next()
    BarText {
        text: (p.player?.isPlaying ? "  " : "  ") + p.info
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 320)
        accent: p.hovered
    }
}

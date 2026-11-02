import QtQuick
import Quickshell.Services.Mpris
import qs
import qs.components

Pill {
    id: p
    readonly property var player: Mpris.players.values.find(pl => pl.isPlaying) ?? Mpris.players.values[0] ?? null
    readonly property string info: player ? [player.trackArtist, player.trackTitle].filter(Boolean).join(" - ") : ""
    visible: info !== ""
    onClicked: player?.togglePlaying()
    BarText {
        text: (p.player?.isPlaying ? "  " : "  ") + p.info
        elide: Text.ElideRight
        width: Math.min(implicitWidth, 320)
        accent: p.hovered
    }
}

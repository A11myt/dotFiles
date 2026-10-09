import { createBinding, createMemo } from "gnim"
import { execAsync } from "ags/process"
import Mpris from "gi://AstalMpris"

const mpris = Mpris.get_default()

export default function Media() {
    const players = createBinding(mpris, "players")

    const player = createMemo(() => {
        const ps = players()
        return (
            ps.find(p => p.playback_status === Mpris.PlaybackStatus.PLAYING) ??
            ps[0] ??
            null
        )
    })

    const label = createMemo(() => {
        const p = player()
        if (!p) return ""
        const isPlaying = p.playback_status === Mpris.PlaybackStatus.PLAYING
        const prefix = isPlaying ? "  " : "  "
        const info = [p.artist, p.title].filter(Boolean).join(" - ")
        return info ? `${prefix}${info}` : ""
    })

    return (
        <button
            class="Media"
            onClick={() => execAsync("playerctl play-pause")}
        >
            <label label={label} maxWidthChars={40} ellipsize={3} />
        </button>
    )
}

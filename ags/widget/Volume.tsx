import { createBinding, createMemo } from "gnim"
import { execAsync } from "ags/process"
import Wp from "gi://AstalWp"
import Astal from "gi://Astal?version=3.0"

const speaker = Wp.get_default().audio.default_speaker

export default function Volume() {
    const vol = createBinding(speaker, "volume")
    const muted = createBinding(speaker, "mute")

    const label = createMemo(() => {
        if (muted()) return "󰝟 muted"
        const v = Math.round(vol() * 100)
        const icon = v > 50 ? "󰕾" : v > 0 ? "󰖀" : "󰕿"
        return `${icon} ${v}%`
    })

    return (
        <button
            class="Volume"
            onClick={(_, e) => {
                if (e.button === Astal.MouseButton.SECONDARY)
                    speaker.mute = !speaker.mute
                else
                    execAsync("pavucontrol")
            }}
            onScroll={(_, e) => {
                const delta = e.delta_y > 0 ? -0.05 : 0.05
                speaker.volume = Math.max(0, Math.min(1, vol() + delta))
            }}
        >
            <label label={label} />
        </button>
    )
}

import { createBinding, createMemo } from "ags"
import { execAsync } from "ags/process"
import Network from "gi://AstalNetwork"

const network = Network.get_default()

export default function NetworkWidget() {
    const ssid = createBinding(network, "wifi", "ssid")
    const strength = createBinding(network, "wifi", "strength")

    const label = createMemo(() => {
        const s = ssid()
        if (!s) return "󰤮"
        const str = strength() ?? 0
        const icon = str > 75 ? "󰤨" : str > 50 ? "󰤥" : str > 25 ? "󰤢" : "󰤟"
        return `${icon} ${s}`
    })

    const tooltip = createMemo(() => {
        const s = ssid()
        if (!s) return "No WiFi"
        return `${s} — ${strength() ?? 0}%`
    })

    return (
        <button
            class="Network"
            tooltipText={tooltip}
            onClick={() => execAsync(["alacritty", "-e", "nmtui"])}
        >
            <label label={label} />
        </button>
    )
}

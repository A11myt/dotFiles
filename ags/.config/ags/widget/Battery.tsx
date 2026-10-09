import { createBinding, createMemo } from "gnim"
import { execAsync } from "ags/process"
import Battery from "gi://AstalBattery"

const battery = Battery.get_default()

const ICONS = ["", "", "", "", ""]

const STATE_LABEL: Partial<Record<number, string>> = {
    [Battery.State.CHARGING]:       "Charging",
    [Battery.State.DISCHARGING]:    "Discharging",
    [Battery.State.FULLY_CHARGED]:  "Full",
    [Battery.State.EMPTY]:          "Empty",
}

export default function BatteryWidget() {
    const pct      = createBinding(battery, "percentage")
    const charging = createBinding(battery, "charging")
    const state    = createBinding(battery, "state")

    const label = createMemo(() => {
        const p    = pct()
        const icon = charging() ? "󱐋" : ICONS[Math.min(Math.floor(p * 5), 4)]
        return `${Math.round(p * 100)}% ${icon}`
    })

    const tooltip = createMemo(() => {
        const s = STATE_LABEL[state() as number] ?? "Unknown"
        return `Battery: ${Math.round(pct() * 100)}% — ${s}`
    })

    const cls = createMemo(() =>
        pct() < 0.2 && !charging() ? "Battery critical" : "Battery",
    )

    return (
        <button
            class={cls}
            tooltipText={tooltip}
            onClick={() => execAsync(["alacritty", "-e", "sh", "-c", "upower -i $(upower -e | grep battery) | less"])}
        >
            <label label={label} />
        </button>
    )
}

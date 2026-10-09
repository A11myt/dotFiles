import { createBinding, createMemo } from "gnim"
import PowerProfiles from "gi://AstalPowerProfiles"

const pp = PowerProfiles.get_default()

const PROFILES = ["power-saver", "balanced", "performance"]

const ICONS: Record<string, string> = {
    performance:  "",
    balanced:     "󰗑",
    "power-saver":"󰌪",
}

export default function PowerProfile() {
    const profile = createBinding(pp, "active_profile")
    const icon    = createMemo(() => ICONS[profile()] ?? "")

    const cycle = () => {
        const i = PROFILES.indexOf(pp.active_profile)
        pp.active_profile = PROFILES[(i + 1) % PROFILES.length]
    }

    return (
        <button
            class="PowerProfile"
            tooltipText={profile}
            onClick={cycle}
        >
            <label label={icon} />
        </button>
    )
}

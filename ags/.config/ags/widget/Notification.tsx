import { createState } from "gnim"
import { execAsync, subprocess } from "ags/process"

// swaync meldet Änderungen selbst (eine JSON-Zeile pro Änderung) → kein Polling
const ICONS: Record<string, string> = {
    "notification":              "󱅫",
    "none":                      "󰂜",
    "dnd-notification":          "󰂠",
    "dnd-none":                  "󰪓",
    "inhibited-notification":    "󱅫",
    "inhibited-none":            "󰂜",
    "dnd-inhibited-notification": "󰂠",
    "dnd-inhibited-none":        "󰪓",
}

const [icon, setIcon] = createState("󰂜")

subprocess(["swaync-client", "-swb"], line => {
    try {
        const { alt } = JSON.parse(line) as { alt: string }
        setIcon(ICONS[alt] ?? "󰂜")
    } catch { /* unvollständige Zeile ignorieren */ }
})

export default function Notification() {
    return (
        <button
            class="Notification"
            onClick={() => execAsync("swaync-client -t -sw")}
        >
            <label label={icon} />
        </button>
    )
}

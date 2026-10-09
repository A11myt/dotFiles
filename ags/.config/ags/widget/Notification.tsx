import { createPoll } from "ags/time"
import { execAsync } from "ags/process"

export default function Notification() {
    // Poll swaync count every 5s to pick the right icon
    const icon = createPoll("󰂜", 5_000, async () => {
        try {
            const count = await execAsync("swaync-client -c")
            const dnd = await execAsync("swaync-client -D")
            const hasDnd = dnd.trim() === "true"
            const hasNotif = parseInt(count.trim()) > 0
            if (hasDnd) return hasNotif ? "󰂠" : "󰪓"
            return hasNotif ? "󱅫" : "󰂜"
        } catch {
            return "󰂜"
        }
    })

    return (
        <button
            class="Notification"
            onClick={() => execAsync("swaync-client -t -sw")}
        >
            <label label={icon} />
        </button>
    )
}

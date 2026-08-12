import { createPoll } from "ags/time"
import { execAsync } from "ags/process"

export default function Updates() {
    const label = createPoll("", 3_600_000, async () => {
        try {
            const out = await execAsync("checkupdates")
            const n = out.trim().split("\n").filter(Boolean).length
            return n > 0 ? `${n} 󰚰` : ""
        } catch {
            // checkupdates exits 2 when no updates — that's normal
            return ""
        }
    })

    return (
        <button
            class="Updates"
            onClick={() =>
                execAsync([
                    "alacritty",
                    "-e",
                    "sh",
                    "-c",
                    "sudo pacman -Syu; pkill -SIGRTMIN+8 waybar",
                ])
            }
        >
            <label label={label} />
        </button>
    )
}

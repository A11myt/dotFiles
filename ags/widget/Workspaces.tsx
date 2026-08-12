import { createBinding, createMemo } from "gnim"
import { execAsync } from "ags/process"
import Hyprland from "gi://AstalHyprland"

const hy = Hyprland.get_default()!

export default function Workspaces() {
    const focused = createBinding(hy, "focused_workspace")

    const scrollWorkspace = (dir: "e+1" | "e-1") =>
        execAsync(["hyprctl", "eval", `hl.dispatch(hl.dsp.focus({ workspace = "${dir}" }))`]).catch(() => {})

    return (
        <eventbox class="Workspaces"
            onScroll={(_, e) => scrollWorkspace(e.delta_y > 0 ? "e-1" : "e+1")}
        >
        <box spacing={4}>
            {[1, 2, 3, 4, 5].map(id => (
                <button
                    class={createMemo(() =>
                        focused()?.id === id ? "Workspace active" : "Workspace",
                    )}
                    onClick={() => execAsync(["hyprctl", "eval", `hl.dispatch(hl.dsp.focus({ workspace = ${id} }))`]).catch(() => {})}
                >
                    <label label={String(id)} />
                </button>
            ))}
        </box>
        </eventbox>
    )
}

import { createBinding, createComputed, createState, For } from "gnim"
import { execAsync } from "ags/process"
import { timeout } from "ags/time"
import { Gtk } from "ags/gtk3"
import Hyprland from "gi://AstalHyprland"
import Apps from "gi://AstalApps"

const hy = Hyprland.get_default()!
const apps = new Apps.Apps()

const BASE = [1, 2, 3, 4, 5]   // immer sichtbar; belegte darüber kommen dazu
const MAX_ICONS = 3

// Fensterklasse → Icon-Name aus der .desktop-Datei (gecacht), sonst Standard-Symbol
const iconCache = new Map<string, string>()
function iconFor(cls: string): string {
    const key = cls.toLowerCase()
    const hit = iconCache.get(key)
    if (hit) return hit
    const app =
        apps.list.find(a => a.wm_class?.toLowerCase() === key) ??
        apps.list.find(a => a.entry?.replace(/\.desktop$/, "").toLowerCase() === key) ??
        apps.exact_query(cls)[0]
    const theme = Gtk.IconTheme.get_default()
    const candidates = [app?.icon_name, key, "application-x-executable"]
    const name = candidates.find(n => n && theme.has_icon(n)) ?? "application-x-executable"
    iconCache.set(key, name)
    return name
}

// Arbeitsfläche → Fensterklassen (ohne Duplikate), neu berechnet bei Fenster-Ereignissen
const [occupied, setOccupied] = createState<Map<number, string[]>>(new Map())
function recompute() {
    const m = new Map<number, string[]>()
    for (const c of hy.clients) {
        const id = c.workspace?.id
        if (!id || id < 1) continue   // Spezial-Arbeitsflächen haben negative IDs
        const cls = c.class || c.initial_class
        const list = m.get(id) ?? []
        if (cls && !list.includes(cls)) list.push(cls)
        m.set(id, list)
    }
    setOccupied(m)
}
recompute()
const WINDOW_EVENTS = /^(openwindow|closewindow|movewindow|movewindowv2|createworkspace|destroyworkspace|moveworkspace)/
// kurz warten: AstalHyprland aktualisiert seine Client-Liste auf dasselbe Ereignis hin
hy.connect("event", (_, name) => { if (WINDOW_EVENTS.test(name)) timeout(60, recompute) })

// für `ags request -i bar workspaces` (Diagnose): {"1":["Alacritty"], …}
export const occupiedJson = () => JSON.stringify(Object.fromEntries(occupied.get()))

const focusWs = (target: string | number) =>
    execAsync(["hyprctl", "eval", `hl.dispatch(hl.dsp.focus({ workspace = ${typeof target === "number" ? target : `"${target}"`} }))`]).catch(() => {})

export default function Workspaces() {
    const focused = createBinding(hy, "focused_workspace")
    const ids = occupied(m => [...new Set([...BASE, ...m.keys()])].sort((a, b) => a - b))

    return (
        <eventbox class="Workspaces" onScroll={(_, e) => focusWs(e.delta_y > 0 ? "e-1" : "e+1")}>
            <box spacing={4}>
                <For each={ids}>
                    {(id: number) => {
                        const classes = occupied(m => m.get(id) ?? [])
                        const cls = createComputed([focused, classes], (f, c) =>
                            ["Workspace", f?.id === id ? "active" : "", c.length ? "occupied" : ""].filter(Boolean).join(" "))
                        return (
                            <button class={cls} onClick={() => focusWs(id)}
                                tooltipText={classes(c => (c.length ? c.join(", ") : "leer"))}>
                                <box spacing={4}>
                                    <label class="num" label={String(id)} />
                                    <For each={classes(c => c.slice(0, MAX_ICONS))}>
                                        {(c: string) => <icon class="appicon" icon={iconFor(c)} />}
                                    </For>
                                    <label class="more" visible={classes(c => c.length > MAX_ICONS)}
                                        label={classes(c => `+${c.length - MAX_ICONS}`)} />
                                </box>
                            </button>
                        )
                    }}
                </For>
            </box>
        </eventbox>
    )
}

// Logout-/Power-Menü in AGS (ersetzt wlogout). Öffnen: CTRL+ALT+ENTF → `ags request -i bar toggle-power`
import app from "ags/gtk3/app"
import { Astal, Gdk } from "ags/gtk3"
import { execAsync } from "ags/process"
import { createState } from "gnim"

export const [powerOpen, setPowerOpen] = createState(false)
export const togglePower = () => setPowerOpen(v => !v)

// Reihenfolge, Taste, Symbol, Text, Befehl – wie zuvor in wlogout/layout.
// Vor Abmelden/Neustart/Ausschalten den Stand der offenen Programme merken (session).
const ACTIONS = [
    { key: "l", icon: "󰌾", label: "Sperren", cmd: "loginctl lock-session" },
    { key: "e", icon: "󰍃", label: "Abmelden", cmd: "~/.local/bin/session save; loginctl terminate-user $USER" },
    { key: "u", icon: "󰤄", label: "Ruhezustand", cmd: "systemctl suspend" },
    { key: "r", icon: "󰜉", label: "Neustart", cmd: "~/.local/bin/session save; systemctl reboot" },
    { key: "s", icon: "󰐥", label: "Ausschalten", cmd: "~/.local/bin/session save; systemctl poweroff" },
]

function run(cmd: string) {
    setPowerOpen(false)
    // kurz warten, bis das Menü weg ist (sonst landet es z. B. im Sperrbildschirm-Screenshot)
    execAsync(["bash", "-c", `sleep 0.15; ${cmd}`]).catch(() => {})
}

export default function PowerMenu() {
    const { TOP, BOTTOM, LEFT, RIGHT } = Astal.WindowAnchor
    return (
        <window
            name="power-menu"
            namespace="ags-power"
            class="PowerMenu"
            anchor={TOP | BOTTOM | LEFT | RIGHT}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.IGNORE}
            keymode={Astal.Keymode.EXCLUSIVE}
            visible={powerOpen}
            application={app}
            onKeyPressEvent={(_, e: Gdk.Event) => {
                const kv = e.get_keyval()[1]
                if (kv === Gdk.KEY_Escape) return setPowerOpen(false)
                const name = Gdk.keyval_name(kv)?.toLowerCase()
                const a = ACTIONS.find(x => x.key === name)
                if (a) run(a.cmd)
            }}
        >
            {/* Klick auf die abgedunkelte Fläche schließt */}
            <eventbox class="backdrop" onClick={() => setPowerOpen(false)}>
                <box halign={3 /* CENTER */} valign={3} spacing={18}>
                    {ACTIONS.map(a => (
                        <button class={`action ${a.key === "s" || a.key === "r" ? "danger" : ""}`} onClick={() => run(a.cmd)}>
                            <box vertical spacing={8}>
                                <label class="icon" label={a.icon} />
                                <label class="text" label={a.label} />
                                <label class="key" label={a.key.toUpperCase()} />
                            </box>
                        </button>
                    ))}
                </box>
            </eventbox>
        </window>
    )
}

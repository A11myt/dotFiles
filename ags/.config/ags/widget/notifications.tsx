// Benachrichtigungen direkt in AGS (ersetzt swaync): gemeinsamer Zustand + Karte
import { createBinding, createState } from "gnim"
import { timeout } from "ags/time"
import { Gtk } from "ags/gtk3"
import Notifd from "gi://AstalNotifd"
import GLib from "gi://GLib"

export const notifd = Notifd.get_default()
export const notifications = createBinding(notifd, "notifications")
export const dnd = createBinding(notifd, "dont_disturb")

// Zentrale: sichtbar/unsichtbar (Glocke, SUPER+A über `ags request toggle-center`)
export const [centerOpen, setCenterOpen] = createState(false)
export const toggleCenter = () => setCenterOpen(v => !v)

// Popups: nur die frisch eingetroffenen, verschwinden nach Ablauf wieder (bleiben aber in der Zentrale)
const POPUP_MS = 5000
export const [popups, setPopups] = createState<Notifd.Notification[]>([])
const dropPopup = (id: number) => setPopups(ps => ps.filter(p => p.id !== id))

notifd.connect("notified", (_, id) => {
    const n = notifd.get_notification(id)
    if (!n) return
    const critical = n.urgency === Notifd.Urgency.CRITICAL
    if (notifd.dont_disturb && !critical) return
    setPopups(ps => [n, ...ps.filter(p => p.id !== id)].slice(0, 4))
    if (!critical) timeout(n.expire_timeout > 0 ? n.expire_timeout : POPUP_MS, () => dropPopup(id))
})
notifd.connect("resolved", (_, id) => dropPopup(id))

const time = (unix: number) => GLib.DateTime.new_from_unix_local(unix).format("%H:%M") ?? ""

export function NotificationCard({ n, popup = false }: { n: Notifd.Notification; popup?: boolean }) {
    const actions = n.actions.filter(a => a.id !== "default")
    const cls = ["Notif", popup ? "popup" : "", n.urgency === Notifd.Urgency.CRITICAL ? "critical" : ""]
        .filter(Boolean).join(" ")

    return (
        <eventbox
            class={cls}
            onClick={() => {
                // Klick auf die Karte = Standardaktion der App (z. B. Chat öffnen), sonst nur schließen
                if (n.actions.some(a => a.id === "default")) n.invoke("default")
                if (popup) dropPopup(n.id)
            }}
        >
            <box vertical spacing={4}>
                <box class="head" spacing={8}>
                    <label class="app" label={n.app_name || "Benachrichtigung"} xalign={0} hexpand truncate />
                    <label class="time" label={time(n.time)} />
                    <button class="close" onClick={() => n.dismiss()} tooltipText="Schließen">
                        <label label="✕" />
                    </button>
                </box>
                <label class="summary" label={n.summary} xalign={0} wrap maxWidthChars={40} />
                {n.body ? <label class="body" label={n.body} xalign={0} wrap maxWidthChars={46} lines={popup ? 3 : 6} ellipsize={3} /> : <box />}
                {actions.length > 0 ? (
                    <box class="actions" spacing={6} homogeneous>
                        {actions.map(a => (
                            <button onClick={() => n.invoke(a.id)}>
                                <label label={a.label} />
                            </button>
                        ))}
                    </box>
                ) : <box />}
            </box>
        </eventbox>
    ) as Gtk.Widget
}

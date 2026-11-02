import { createComputed } from "gnim"
import { dnd, notifications, toggleCenter } from "./notifications"

// Glocke in der Leiste: Zustand direkt aus AstalNotifd, Klick öffnet die Zentrale
export default function Notification() {
    const icon = createComputed([notifications, dnd], (ns, d) => {
        const has = ns.length > 0
        if (d) return has ? "󰂠" : "󰪓"
        return has ? "󱅫" : "󰂜"
    })

    return (
        <button
            class="Notification"
            tooltipText={notifications(ns => ns.length === 0 ? "Keine Benachrichtigungen" : `${ns.length} Benachrichtigungen`)}
            onClick={toggleCenter}
        >
            <label label={icon} />
        </button>
    )
}

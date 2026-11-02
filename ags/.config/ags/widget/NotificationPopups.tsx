import app from "ags/gtk3/app"
import { Astal } from "ags/gtk3"
import { For } from "gnim"
import { NotificationCard, popups } from "./notifications"

// Ohne gdkmonitor legt Hyprland das Fenster auf den fokussierten Monitor
export default function NotificationPopups() {
    const { TOP, RIGHT } = Astal.WindowAnchor
    return (
        <window
            name="notification-popups"
            namespace="ags-notifications"
            class="NotificationPopups"
            anchor={TOP | RIGHT}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            visible={popups(ps => ps.length > 0)}
            application={app}
        >
            <box vertical spacing={8}>
                <For each={popups}>{n => <NotificationCard n={n} popup />}</For>
            </box>
        </window>
    )
}

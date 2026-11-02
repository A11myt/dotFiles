import app from "ags/gtk3/app"
import { Astal, Gdk } from "ags/gtk3"
import { For } from "gnim"
import { centerOpen, dnd, notifd, NotificationCard, notifications, setCenterOpen } from "./notifications"

export default function NotificationCenter() {
    const { TOP, RIGHT, BOTTOM } = Astal.WindowAnchor
    return (
        <window
            name="notification-center"
            namespace="ags-notification-center"
            class="NotificationCenter"
            anchor={TOP | RIGHT | BOTTOM}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            keymode={Astal.Keymode.ON_DEMAND}
            visible={centerOpen}
            application={app}
            onKeyPressEvent={(_, e: Gdk.Event) => {
                if (e.get_keyval()[1] === Gdk.KEY_Escape) setCenterOpen(false)
            }}
        >
            <box class="panel" vertical spacing={10}>
                <box class="top" spacing={8}>
                    <label class="title" label="Benachrichtigungen" xalign={0} hexpand />
                    <label class="dnd-label" label="Nicht stören" />
                    <switch
                        active={dnd}
                        onNotifyActive={self => { notifd.dont_disturb = self.active }}
                    />
                </box>
                <scrollable vexpand hscroll={2 /* NEVER */}>
                    <box vertical spacing={8}>
                        <For each={notifications}>{n => <NotificationCard n={n} />}</For>
                        <label
                            class="empty"
                            label="Keine Benachrichtigungen"
                            visible={notifications(ns => ns.length === 0)}
                        />
                    </box>
                </scrollable>
                <button
                    class="clear"
                    visible={notifications(ns => ns.length > 0)}
                    onClick={() => notifd.notifications.forEach(n => n.dismiss())}
                >
                    <label label="Alle löschen" />
                </button>
            </box>
        </window>
    )
}

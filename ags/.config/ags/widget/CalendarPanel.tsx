// Kalender unter der Uhr (Klick auf die Uhr)
import app from "ags/gtk3/app"
import { Astal, Gdk, Gtk } from "ags/gtk3"
import GLib from "gi://GLib"
import { closePanels, isOpen } from "./panels"

export default function CalendarPanel() {
    const { TOP, LEFT } = Astal.WindowAnchor
    let cal: Gtk.Calendar | null = null
    let today: Astal.Label | null = null
    return (
        <window
            name="calendar"
            namespace="ags-calendar"
            class="CalendarPanel"
            anchor={TOP | LEFT}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            keymode={Astal.Keymode.ON_DEMAND}
            visible={isOpen("calendar")}
            application={app}
            onKeyPressEvent={(_, e: Gdk.Event) => { if (e.get_keyval()[1] === Gdk.KEY_Escape) closePanels() }}
            // beim Öffnen immer auf heute springen
            onShow={() => {
                const now = GLib.DateTime.new_now_local()
                cal?.select_month(now.get_month() - 1, now.get_year())
                cal?.select_day(now.get_day_of_month())
                today?.set_label(now.format("%A, %e. %B %Y") ?? "")
            }}
        >
            <box class="panel" vertical spacing={6}>
                <label class="today" xalign={0} $={(self: Astal.Label) => (today = self)} />
                <Gtk.Calendar $={(self: Gtk.Calendar) => (cal = self)} showWeekNumbers />
            </box>
        </window>
    )
}

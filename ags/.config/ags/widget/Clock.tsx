import { createPoll } from "ags/time"
import GLib from "gi://GLib"
import { togglePanel } from "./panels"

export default function Clock() {
    // im Prozess formatieren statt jede Sekunde `date` zu starten
    const time = createPoll("", 1000, () => GLib.DateTime.new_now_local().format("%I:%M %p")!)
    return (
        <button class="Clock" onClick={() => togglePanel("calendar")}>
            <label label={time} />
        </button>
    )
}

import { createPoll } from "ags/time"
import GLib from "gi://GLib"

export default function Clock() {
    // im Prozess formatieren statt jede Sekunde `date` zu starten
    const time = createPoll("", 1000, () => GLib.DateTime.new_now_local().format("%I:%M %p")!)
    return (
        <button class="Clock">
            <label label={time} />
        </button>
    )
}

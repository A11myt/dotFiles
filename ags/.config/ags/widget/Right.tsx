import { Gtk } from "ags/gtk3"
import Updates from "./Updates"
import Volume from "./Volume"
import BatteryWidget from "./Battery"
import NetworkWidget from "./Network"
import PowerProfile from "./PowerProfile"
import { togglePanel } from "./panels"

export default function Right() {
    return (
        <box class="Right" spacing={8} halign={Gtk.Align.END}>
            <Updates />
            <Volume />
            <BatteryWidget />
            <NetworkWidget />
            <PowerProfile />
            <button class="QuickToggle" onClick={() => togglePanel("quick")} tooltipText="Quick Settings">
                <label label="󰒓" />
            </button>
        </box>
    )
}

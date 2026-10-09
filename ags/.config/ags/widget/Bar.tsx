import app from "ags/gtk3/app"
import { Astal, Gdk } from "ags/gtk3"
import Left from "./Left"
import Center from "./Center"
import Right from "./Right"

export default function Bar(gdkmonitor: Gdk.Monitor) {
    const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

    return (
        <window
            class="Bar"
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            anchor={TOP | LEFT | RIGHT}
            application={app}
        >
            <centerbox>
                <Left $type="start" />
                <Center $type="center" />
                <Right $type="end" />
            </centerbox>
        </window>
    )
}

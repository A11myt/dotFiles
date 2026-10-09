import { execAsync } from "ags/process"
import Clock from "./Clock"
import Weather from "./Weather"
import Workspaces from "./Workspaces"

export default function Left() {
    return (
        <box class="Left" spacing={8}>
            <button class="Launcher" onClick={() => execAsync("rofi -show drun")}>
                <label label="󰣇" />
            </button>
            <Clock />
            <Weather />
            <Workspaces />
        </box>
    )
}

import app from "ags/gtk3/app"
import { monitorFile } from "ags/file"
import { execAsync } from "ags/process"
import style from "./style.scss"
import Bar from "./widget/Bar"
import GLib from "gi://GLib"
import Gio from "gi://Gio"

const HOME = GLib.get_home_dir()

app.start({
    instanceName: "bar",
    css: style,
    main() {
        app.get_monitors().map(Bar)

        // Auto-restart when matugen regenerates colors
        monitorFile(`${HOME}/.config/ags/colors.scss`, (_path, event) => {
            if (event !== Gio.FileMonitorEvent.CHANGES_DONE_HINT) return
            execAsync([
                "bash", "-c",
                `pkill -f "gjs.*ags.js" 2>/dev/null; sleep 0.4 && ags run ${HOME}/.config/ags/app.ts >> ${HOME}/.logs/ags.log 2>&1 &`,
            ]).catch(() => {})
        })
    },
})

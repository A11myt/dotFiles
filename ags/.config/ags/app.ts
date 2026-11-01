import app from "ags/gtk3/app"
import { monitorFile } from "ags/file"
import { execAsync } from "ags/process"
import style from "./style.scss"
import Bar from "./widget/Bar"
import GLib from "gi://GLib"
import Gio from "gi://Gio"

const AGS_DIR = `${GLib.get_home_dir()}/.config/ags`

app.start({
    instanceName: "bar",
    css: style,
    main() {
        app.get_monitors().map(Bar)

        // Matugen schreibt colors.scss → CSS live neu kompilieren und anwenden.
        // Kein Neustart: Update-Check, Wetter und Widget-Zustand bleiben erhalten,
        // die transition in style.scss blendet die Farben weich über.
        monitorFile(`${AGS_DIR}/colors.scss`, (_path, event) => {
            if (event !== Gio.FileMonitorEvent.CHANGES_DONE_HINT) return
            execAsync(["sass", "--no-source-map", `--load-path=${AGS_DIR}`, `${AGS_DIR}/style.scss`])
                .then(css => app.apply_css(css, true))
                .catch(e => printerr(`ags: CSS-Reload fehlgeschlagen: ${e}`))
        })
    },
})

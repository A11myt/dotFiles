import app from "ags/gtk3/app"
import { monitorFile } from "ags/file"
import { execAsync } from "ags/process"
import style from "./style.scss"
import Bar from "./widget/Bar"
import NotificationPopups from "./widget/NotificationPopups"
import NotificationCenter from "./widget/NotificationCenter"
import { toggleCenter } from "./widget/notifications"
import PowerMenu, { togglePower } from "./widget/PowerMenu"
import OSD from "./widget/OSD"
import QuickSettings from "./widget/QuickSettings"
import CalendarPanel from "./widget/CalendarPanel"
import { togglePanel } from "./widget/panels"
import GLib from "gi://GLib"
import Gio from "gi://Gio"

const AGS_DIR = `${GLib.get_home_dir()}/.config/ags`

app.start({
    instanceName: "bar",
    css: style,
    // `ags request -i bar toggle-center` (SUPER+A), `toggle-power` (CTRL+ALT+ENTF)
    requestHandler(argv, res) {
        if (argv[0] === "toggle-center") {
            toggleCenter()
            return res("ok")
        }
        if (argv[0] === "toggle-calendar") {
            togglePanel("calendar")
            return res("ok")
        }
        if (argv[0] === "toggle-quick") {
            togglePanel("quick")
            return res("ok")
        }
        if (argv[0] === "toggle-power") {
            togglePower()
            return res("ok")
        }
        res(`unbekannt: ${argv.join(" ")}`)
    },
    main() {
        app.get_monitors().map(Bar)
        NotificationPopups()
        NotificationCenter()
        PowerMenu()
        OSD()
        QuickSettings()
        CalendarPanel()

        // Matugen schreibt colors.scss, fontgen fonts.scss → CSS live neu kompilieren und anwenden.
        // Kein Neustart: Update-Check, Wetter und Widget-Zustand bleiben erhalten,
        // die transition in style.scss blendet die Farben weich über.
        const reloadCss = (_path: string, event: Gio.FileMonitorEvent) => {
            if (event !== Gio.FileMonitorEvent.CHANGES_DONE_HINT) return
            execAsync(["sass", "--no-source-map", `--load-path=${AGS_DIR}`, `${AGS_DIR}/style.scss`])
                .then(css => app.apply_css(css, true))
                .catch(e => printerr(`ags: CSS-Reload fehlgeschlagen: ${e}`))
        }
        monitorFile(`${AGS_DIR}/colors.scss`, reloadCss)   // Matugen
        monitorFile(`${AGS_DIR}/fonts.scss`, reloadCss)    // fontgen
    },
})

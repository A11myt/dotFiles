// Bildschirmanzeige für Lautstärke und Helligkeit (Medientasten), unten mittig
import app from "ags/gtk3/app"
import { Astal } from "ags/gtk3"
import { timeout } from "ags/time"
import { createState } from "gnim"
import Wp from "gi://AstalWp"
import Brightness from "gi://AstalBrightness"

type Osd = { icon: string; value: number; muted: boolean }
const [osd, setOsd] = createState<Osd>({ icon: "", value: 0, muted: false })
const [shown, setShown] = createState(false)

let hideTimer: ReturnType<typeof timeout> | null = null
// beim Start feuern die Werte einmal – das soll keine Anzeige auslösen
let ready = false
timeout(1500, () => { ready = true })

function show(o: Osd) {
    if (!ready) return
    setOsd(o)
    setShown(true)
    hideTimer?.cancel()
    hideTimer = timeout(1400, () => setShown(false))
}

const volIcon = (v: number, m: boolean) => (m || v === 0 ? "󰝟" : v > 0.5 ? "󰕾" : "󰖀")
const briIcon = (v: number) => (v > 0.66 ? "󰃠" : v > 0.33 ? "󰃟" : "󰃞")

const speaker = Wp.get_default()?.audio.default_speaker
const onVolume = () => speaker && show({ icon: volIcon(speaker.volume, speaker.mute), value: speaker.volume, muted: speaker.mute })
speaker?.connect("notify::volume", onVolume)
speaker?.connect("notify::mute", onVolume)

const screen = Brightness.get_default()?.screen
screen?.connect("notify::brightness", () => show({ icon: briIcon(screen.brightness), value: screen.brightness, muted: false }))

export default function OSD() {
    return (
        <window
            name="osd"
            namespace="ags-osd"
            class="OSD"
            anchor={Astal.WindowAnchor.BOTTOM}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.IGNORE}
            visible={shown}
            application={app}
        >
            <box class={osd(o => (o.muted ? "osd muted" : "osd"))} spacing={12}>
                <label class="icon" label={osd(o => o.icon)} />
                <levelbar class="level" valign={3} widthRequest={180} value={osd(o => Math.min(1, o.value))} />
                <label class="pct" label={osd(o => (o.muted ? "stumm" : `${Math.round(o.value * 100)}%`))} widthChars={5} xalign={1} />
            </box>
        </window>
    )
}

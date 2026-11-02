// Quick Settings: WLAN, Bluetooth, Nicht stören, Energieprofil, Lautstärke, Helligkeit, Medien
import app from "ags/gtk3/app"
import { Astal, Gdk } from "ags/gtk3"
import { execAsync } from "ags/process"
import { createBinding, createComputed, With } from "gnim"
import Network from "gi://AstalNetwork"
import Bluetooth from "gi://AstalBluetooth"
import Wp from "gi://AstalWp"
import Brightness from "gi://AstalBrightness"
import PowerProfiles from "gi://AstalPowerProfiles"
import Mpris from "gi://AstalMpris"
import { notifd } from "./notifications"
import { closePanels, isOpen } from "./panels"
import { togglePower } from "./PowerMenu"

const net = Network.get_default()
const bt = Bluetooth.get_default()
const speaker = Wp.get_default()!.audio.default_speaker
const screen = Brightness.get_default()?.screen
const pp = PowerProfiles.get_default()
const mpris = Mpris.get_default()

const PROFILES = ["power-saver", "balanced", "performance"]
const PROFILE_LABEL: Record<string, string> = { "power-saver": "Sparsam", balanced: "Ausgewogen", performance: "Leistung" }
const PROFILE_ICON: Record<string, string> = { "power-saver": "󰌪", balanced: "󰗑", performance: "" }

// Kachel: Symbol, Titel, Untertitel, an/aus
function Tile(p: { icon: any; title: string; sub: any; on: any; onClick: () => void; onSecondary?: () => void }) {
    return (
        <button
            class={p.on((v: boolean) => (v ? "tile on" : "tile"))}
            hexpand
            onClick={(_, e) => (e.button === Astal.MouseButton.SECONDARY && p.onSecondary ? p.onSecondary() : p.onClick())}
        >
            <box spacing={10}>
                <label class="ticon" label={p.icon} />
                <box vertical valign={3}>
                    <label class="ttitle" label={p.title} xalign={0} />
                    <label class="tsub" label={p.sub} xalign={0} truncate maxWidthChars={14} />
                </box>
            </box>
        </button>
    )
}

function Sliders() {
    const vol = createBinding(speaker, "volume")
    const muted = createBinding(speaker, "mute")
    return (
        <box vertical spacing={6} class="sliders">
            <box spacing={10}>
                <button class="sicon" onClick={() => (speaker.mute = !speaker.mute)} tooltipText="Stumm schalten">
                    <label label={createComputed([vol, muted], (v, m) => (m || v === 0 ? "󰝟" : v > 0.5 ? "󰕾" : "󰖀"))} />
                </button>
                <slider hexpand value={vol} onDragged={self => (speaker.volume = self.value)} />
            </box>
            {screen ? (
                <box spacing={10}>
                    <label class="sicon" label="󰃟" />
                    <slider hexpand min={0.05} value={createBinding(screen, "brightness")} onDragged={self => (screen.brightness = self.value)} />
                </box>
            ) : <box />}
        </box>
    )
}

function MediaCard() {
    const players = createBinding(mpris, "players")
    const player = players(ps => ps.find(p => p.playback_status === Mpris.PlaybackStatus.PLAYING) ?? ps[0] ?? null)
    return (
        <box class="media-wrap" visible={player(p => p !== null)}>
            <With value={player}>
                {(p: Mpris.Player | null) => p ? (
                    <box class="media" spacing={12}>
                        <box
                            class="cover"
                            css={createBinding(p, "cover_art")(c => (c ? `background-image: url("file://${c}");` : ""))}
                        />
                        <box vertical hexpand valign={3} spacing={2}>
                            <label class="mtitle" label={createBinding(p, "title")(t => t || "Unbekannt")} xalign={0} truncate maxWidthChars={22} />
                            <label class="martist" label={createBinding(p, "artist")(a => a || p.identity)} xalign={0} truncate maxWidthChars={26} />
                            <box spacing={6} class="mbtns">
                                <button onClick={() => p.previous()}><label label="󰒮" /></button>
                                <button onClick={() => p.play_pause()}>
                                    <label label={createBinding(p, "playback_status")(s => (s === Mpris.PlaybackStatus.PLAYING ? "󰏤" : "󰐊"))} />
                                </button>
                                <button onClick={() => p.next()}><label label="󰒭" /></button>
                            </box>
                        </box>
                    </box>
                ) : <box />}
            </With>
        </box>
    )
}

export default function QuickSettings() {
    const { TOP, RIGHT } = Astal.WindowAnchor
    const wifi = net.wifi
    const btDevices = createBinding(bt, "devices")
    const btSub = btDevices(ds => ds.find(d => d.connected)?.alias ?? (bt.is_powered ? "An" : "Aus"))
    const profile = createBinding(pp, "active_profile")

    return (
        <window
            name="quick-settings"
            namespace="ags-quick-settings"
            class="QuickSettings"
            anchor={TOP | RIGHT}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            keymode={Astal.Keymode.ON_DEMAND}
            visible={isOpen("quick")}
            application={app}
            onKeyPressEvent={(_, e: Gdk.Event) => { if (e.get_keyval()[1] === Gdk.KEY_Escape) closePanels() }}
        >
            <box class="panel" vertical spacing={12}>
                <box spacing={8} homogeneous>
                    {wifi ? (
                        <Tile
                            icon={createBinding(wifi, "strength")(s => (s > 66 ? "󰤨" : s > 33 ? "󰤥" : "󰤟"))}
                            title="WLAN"
                            sub={createBinding(wifi, "ssid")(s => s || (wifi.enabled ? "Nicht verbunden" : "Aus"))}
                            on={createBinding(wifi, "enabled")}
                            onClick={() => (wifi.enabled = !wifi.enabled)}
                            onSecondary={() => { closePanels(); execAsync(["alacritty", "-e", "nmtui"]).catch(() => {}) }}
                        />
                    ) : <box />}
                    <Tile
                        icon="󰂯"
                        title="Bluetooth"
                        sub={btSub}
                        on={createBinding(bt, "is_powered")}
                        onClick={() => bt.toggle()}
                    />
                </box>
                <box spacing={8} homogeneous>
                    <Tile
                        icon={createBinding(notifd, "dont_disturb")(d => (d ? "󰂛" : "󰂚"))}
                        title="Nicht stören"
                        sub={createBinding(notifd, "dont_disturb")(d => (d ? "An" : "Aus"))}
                        on={createBinding(notifd, "dont_disturb")}
                        onClick={() => (notifd.dont_disturb = !notifd.dont_disturb)}
                    />
                    <Tile
                        icon={profile(p => PROFILE_ICON[p] ?? "")}
                        title="Energie"
                        sub={profile(p => PROFILE_LABEL[p] ?? p)}
                        on={profile(p => p !== "balanced")}
                        onClick={() => {
                            const i = PROFILES.indexOf(pp.active_profile)
                            pp.active_profile = PROFILES[(i + 1) % PROFILES.length]
                        }}
                    />
                </box>
                <Sliders />
                <MediaCard />
                <box spacing={8} class="bottom">
                    <button hexpand onClick={() => { closePanels(); execAsync("pavucontrol").catch(() => {}) }}>
                        <label label="󰓃  Audio" />
                    </button>
                    <button onClick={() => { closePanels(); execAsync("loginctl lock-session").catch(() => {}) }} tooltipText="Sperren">
                        <label label="󰌾" />
                    </button>
                    <button onClick={() => { closePanels(); togglePower() }} tooltipText="Power-Menü">
                        <label label="󰐥" />
                    </button>
                </box>
            </box>
        </window>
    )
}

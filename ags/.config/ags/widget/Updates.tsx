import { createMemo, createState } from "gnim"
import { interval, timeout } from "ags/time"
import { execAsync } from "ags/process"
import Astal from "gi://Astal?version=3.0"
import Gio from "gi://Gio"
import GLib from "gi://GLib"

// ── Konfiguration ──────────────────────────────────────────────────────────
const CHECK_EVERY = 30 * 60_000   // reguläres Intervall
const RETRY_AFTER = 5 * 60_000    // nach Fehler (offline, Mirror down)
const SETTLE_MS   = 4_000         // nach pacman-Aktivität warten, bis Transaktion durch ist
const MANY        = 50            // ab hier Pill in Warnfarbe
const TOOLTIP_MAX = 25

// Pakete, bei denen ein Update besondere Aufmerksamkeit verdient
const IMPORTANT = /^(linux(-lts|-zen)?|linux-firmware.*|hyprland|aquamarine|hyprutils|systemd|glibc|mesa|vulkan-intel|pipewire|wireplumber|greetd.*|gtk4|aylurs-gtk-shell-git|libastal-.*)$/

const PACMAN_LOG = "/var/log/pacman.log"
const PACMAN_LCK = "/var/lib/pacman/db.lck"

type Pkg = { name: string; from: string; to: string; aur: boolean; important: boolean }
type Status = "idle" | "checking" | "ok" | "error"
type State = {
    status: Status
    pkgs: Pkg[]
    reboot: string | null       // "7.1.11 → 7.2.9" wenn Kernel neuer als laufend
    checkedAt: GLib.DateTime | null
    error: string | null
}

// ── Store (einmal pro Prozess, egal wie viele Monitore) ────────────────────
const [state, setState] = createState<State>({
    status: "idle", pkgs: [], reboot: null, checkedAt: null, error: null,
})

let running = false
let nextCheck: GLib.DateTime | null = null
let retryTimer: ReturnType<typeof timeout> | null = null
let settleTimer: ReturnType<typeof timeout> | null = null
// bereits gemeldete wichtige Updates überleben AGS-Neustarts (Matugen startet AGS bei jedem Wallpaper neu)
const NOTIFIED_FILE = `${GLib.get_user_cache_dir()}/ags/updates-notified`
let knownImportant = new Set<string>(
    (() => {
        try {
            const [ok, bytes] = GLib.file_get_contents(NOTIFIED_FILE)
            return ok ? new TextDecoder().decode(bytes).split("\n").filter(Boolean) : []
        } catch { return [] }
    })(),
)

// Befehl ausführen und Exit-Code mitnehmen (execAsync wirft sonst bei != 0)
async function run(cmd: string): Promise<{ out: string; code: number }> {
    const raw = await execAsync(["bash", "-c", `${cmd} 2>/dev/null; printf '\\n__EXIT:%s' $?`])
    const m = raw.match(/__EXIT:(\d+)\s*$/)
    return { out: raw.replace(/\n?__EXIT:\d+\s*$/, ""), code: m ? Number(m[1]) : 1 }
}

function parse(out: string, aur: boolean): Pkg[] {
    return out.split("\n").flatMap(line => {
        const m = line.trim().match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
        return m ? [{ name: m[1], from: m[2], to: m[3], aur, important: IMPORTANT.test(m[1]) }] : []
    })
}

// Laufender vs. installierter Kernel ("7.2.9.arch1-1" → "7.2.9-arch1-1")
async function kernelPending(): Promise<string | null> {
    try {
        const running = GLib.spawn_command_line_sync("uname -r")[1]
        const runningStr = new TextDecoder().decode(running).trim()
        const { out } = await run("pacman -Q linux")
        const installed = out.trim().split(/\s+/)[1]?.replace(/\.(arch\d)/, "-$1")
        if (installed && runningStr && installed !== runningStr)
            return `${runningStr.replace(/-arch.*/, "")} → ${installed.replace(/-arch.*/, "")}`
    } catch { /* ignorieren */ }
    return null
}

function notifyNewImportant(pkgs: Pkg[]) {
    const important = pkgs.filter(p => p.important)
    const fresh = important.filter(p => !knownImportant.has(`${p.name}:${p.to}`))
    knownImportant = new Set(important.map(p => `${p.name}:${p.to}`))
    try {
        GLib.mkdir_with_parents(GLib.path_get_dirname(NOTIFIED_FILE), 0o755)
        GLib.file_set_contents(NOTIFIED_FILE, [...knownImportant].join("\n"))
    } catch { /* ignorieren */ }
    if (fresh.length === 0) return
    const body = fresh.map(p => `${p.name} ${p.to}`).join("\n")
    execAsync(["notify-send", "-a", "Updates", "-i", "system-software-update",
        `${fresh.length} wichtige Updates`, body]).catch(() => {})
}

export async function check() {
    if (running) return
    // pacman läuft gerade → später nochmal
    if (GLib.file_test(PACMAN_LCK, GLib.FileTest.EXISTS)) {
        scheduleSettle()
        return
    }
    running = true
    retryTimer?.cancel()
    setState(s => ({ ...s, status: "checking" }))

    try {
        const [repo, aur, reboot] = await Promise.all([
            run("checkupdates --nocolor"),      // 0 = Updates, 2 = keine, sonst Fehler
            run("yay -Qua --color never"),      // 0 = Updates, 1 = keine (oder Fehler ohne Output)
            kernelPending(),
        ])
        if (repo.code !== 0 && repo.code !== 2)
            throw new Error(`checkupdates exit ${repo.code}`)

        const pkgs = [...parse(repo.out, false), ...parse(aur.out, true)]
            .sort((a, b) => Number(b.important) - Number(a.important) || a.name.localeCompare(b.name))

        notifyNewImportant(pkgs)
        setState({ status: "ok", pkgs, reboot, checkedAt: GLib.DateTime.new_now_local(), error: null })
        nextCheck = GLib.DateTime.new_now_local().add_seconds(CHECK_EVERY / 1000)
    } catch (e) {
        setState(s => ({ ...s, status: "error", error: String(e), checkedAt: GLib.DateTime.new_now_local() }))
        nextCheck = GLib.DateTime.new_now_local().add_seconds(RETRY_AFTER / 1000)
        retryTimer = timeout(RETRY_AFTER, () => check())
    } finally {
        running = false
    }
}

// pacman-Aktivität: entprellen, bis Lock weg ist, dann neu prüfen
function scheduleSettle() {
    settleTimer?.cancel()
    settleTimer = timeout(SETTLE_MS, () => check())
}

// ── Einmaliges Setup ───────────────────────────────────────────────────────
check()
interval(CHECK_EVERY, () => check())

const logMonitor = Gio.File.new_for_path(PACMAN_LOG).monitor_file(Gio.FileMonitorFlags.NONE, null)
logMonitor.connect("changed", (_m, _f, _o, event) => {
    if (event === Gio.FileMonitorEvent.CHANGES_DONE_HINT || event === Gio.FileMonitorEvent.CHANGED)
        scheduleSettle()
})

function runUpgrade() {
    execAsync([
        "alacritty", "--class", "updates-term", "-e", "bash", "-c",
        "yay -Syu; echo; read -rsn1 -p 'Fertig – Taste drücken…'",
    ])
        .catch(() => {})
        .finally(() => check())   // Terminal zu → sofort neu zählen
}

// ── Darstellung ────────────────────────────────────────────────────────────
const fmt = (d: GLib.DateTime | null) => d?.format("%H:%M") ?? "–"

export default function Updates() {
    const label = createMemo(() => {
        const s = state()
        const repo = s.pkgs.filter(p => !p.aur).length
        const aur = s.pkgs.length - repo
        const boot = s.reboot ? "  󰜉" : ""

        if (s.status === "error") return `󰀦${boot}`
        if (s.status === "checking" && s.checkedAt === null) return "󰑓"
        if (s.pkgs.length === 0) return `󰗠${boot}`
        // beide Sorten: "12 · 3" (Repo · AUR), sonst nur Gesamtzahl
        return `󰚰 ${repo && aur ? `${repo} · ${aur}` : s.pkgs.length}${boot}`
    })

    const cls = createMemo(() => {
        const s = state()
        const c = ["Updates"]
        if (s.status === "checking") c.push("checking")
        if (s.status === "error") c.push("error")
        else if (s.pkgs.length === 0) c.push("uptodate")
        else c.push("pending")
        if (s.pkgs.length >= MANY) c.push("many")
        if (s.pkgs.some(p => p.important)) c.push("important")
        if (s.reboot) c.push("reboot")
        return c.join(" ")
    })

    const tooltip = createMemo(() => {
        const s = state()
        const lines: string[] = []
        const repo = s.pkgs.filter(p => !p.aur).length

        if (s.status === "error") lines.push(`Prüfung fehlgeschlagen – neuer Versuch ${fmt(nextCheck)}`, "")
        if (s.reboot) lines.push(`󰜉 Neustart nötig: Kernel ${s.reboot}`, "")

        if (s.pkgs.length === 0 && s.status !== "error") {
            lines.push("System ist aktuell")
        } else if (s.pkgs.length > 0) {
            lines.push(`${s.pkgs.length} Updates  (${repo} Repo · ${s.pkgs.length - repo} AUR)`, "")
            for (const p of s.pkgs.slice(0, TOOLTIP_MAX))
                lines.push(`${p.important ? "! " : "  "}${p.name}${p.aur ? " [AUR]" : ""}  ${p.from} → ${p.to}`)
            if (s.pkgs.length > TOOLTIP_MAX) lines.push(`  … +${s.pkgs.length - TOOLTIP_MAX} weitere`)
        }

        lines.push("", `Geprüft ${fmt(s.checkedAt)} · nächster Check ${fmt(nextCheck)}`)
        lines.push("Links: Update   Rechts: jetzt prüfen")
        return lines.join("\n")
    })

    return (
        <button
            class={cls}
            tooltipText={tooltip}
            onClick={(_, e) => {
                if (e.button === Astal.MouseButton.SECONDARY) check()
                else runUpgrade()
            }}
        >
            <label label={label} />
        </button>
    )
}

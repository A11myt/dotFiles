import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.components

// Update-Anzeige (Repo + AUR), wie zuvor in AGS:
// alle 30 min prüfen, nach Fehler nach 5 min; nach pacman-Läufen neu; wichtige Pakete melden
Pill {
    id: root

    readonly property int checkEvery: 30 * 60 * 1000
    readonly property int retryAfter: 5 * 60 * 1000
    readonly property int many: 50
    readonly property var important: /^(linux(-lts|-zen)?|linux-firmware.*|hyprland|aquamarine|hyprutils|systemd|glibc|mesa|vulkan-intel|pipewire|wireplumber|greetd.*|gtk4|quickshell)$/
    readonly property string notifiedFile: Quickshell.env("HOME") + "/.cache/quickshell/updates-notified"

    property string status: "idle"       // idle | checking | ok | error
    property var pkgs: []                // { name, from, to, aur, important }
    property string reboot: ""           // "7.2.9 → 7.2.11"
    property date checkedAt
    property date nextCheck

    readonly property int repoCount: pkgs.filter(p => !p.aur).length
    readonly property int aurCount: pkgs.length - repoCount
    readonly property bool hasImportant: pkgs.some(p => p.important)

    function check() {
        if (proc.running) return
        status = "checking"
        proc.running = true
    }

    function parse(out) {
        const lines = out.split("\n")
        const result = []
        let section = ""
        let repoCode = 1
        for (const l of lines) {
            if (l.startsWith("__REPO_EXIT:")) { repoCode = Number(l.split(":")[1]); continue }
            if (l === "__REPO__" || l === "__AUR__") { section = l; continue }
            if (l.startsWith("__KERNEL:")) {
                const [run, inst] = l.slice(9).split(" ")
                const norm = (inst ?? "").replace(/\.(arch\d)/, "-$1")
                reboot = (inst && run && norm !== run) ? `${run.replace(/-arch.*/, "")} → ${norm.replace(/-arch.*/, "")}` : ""
                continue
            }
            const m = l.trim().match(/^(\S+)\s+(\S+)\s+->\s+(\S+)/)
            if (m) result.push({ name: m[1], from: m[2], to: m[3], aur: section === "__AUR__", important: important.test(m[1]) })
        }
        // checkupdates: 0 = Updates, 2 = keine, sonst Fehler (offline, Mirror down)
        if (repoCode !== 0 && repoCode !== 2) return null
        return result.sort((a, b) => Number(b.important) - Number(a.important) || a.name.localeCompare(b.name))
    }

    Process {
        id: proc
        command: ["bash", "-c", `
            echo __REPO__; checkupdates --nocolor 2>/dev/null; echo "__REPO_EXIT:$?"
            echo __AUR__;  yay -Qua --color never 2>/dev/null
            echo "__KERNEL:$(uname -r) $(pacman -Q linux 2>/dev/null | cut -d' ' -f2)"`]
        stdout: StdioCollector {
            onStreamFinished: {
                const r = root.parse(text)
                root.checkedAt = new Date()
                if (r === null) {
                    root.status = "error"
                    root.nextCheck = new Date(Date.now() + root.retryAfter)
                    retry.restart()
                } else {
                    root.pkgs = r
                    root.status = "ok"
                    root.nextCheck = new Date(Date.now() + root.checkEvery)
                    root.notifyImportant(r)
                }
            }
        }
    }

    // bereits gemeldete wichtige Updates überleben Neustarts
    FileView { id: notified; path: root.notifiedFile; blockLoading: true; printErrors: false }
    function notifyImportant(list) {
        const imp = list.filter(p => p.important).map(p => `${p.name}:${p.to}`)
        const known = (notified.text() || "").split("\n").filter(Boolean)
        const fresh = imp.filter(k => !known.includes(k))
        Quickshell.execDetached(["bash", "-c", `mkdir -p "$(dirname "$1")" && printf '%s\\n' "\${@:2}" > "$1"`, "_", notifiedFile, ...imp])
        if (fresh.length)
            Quickshell.execDetached(["notify-send", "-a", "Updates", "-i", "system-software-update",
                                     `${fresh.length} wichtige Updates`, fresh.map(k => k.replace(":", " ")).join("\n")])
    }

    Timer { interval: 2000; running: true; onTriggered: root.check() }           // kurz nach dem Start
    Timer { interval: root.checkEvery; running: true; repeat: true; onTriggered: root.check() }
    Timer { id: retry; interval: root.retryAfter; onTriggered: root.check() }

    // pacman-Aktivität: warten, bis die Transaktion durch ist (Lock weg), dann neu prüfen
    FileView {
        path: "/var/log/pacman.log"
        watchChanges: true
        printErrors: false
        onFileChanged: settle.restart()
    }
    Timer {
        id: settle
        interval: 4000
        onTriggered: lockCheck.running = true
    }
    Process {
        id: lockCheck
        command: ["test", "-e", "/var/lib/pacman/db.lck"]
        onExited: code => code === 0 ? settle.restart() : root.check()
    }

    Process {
        id: upgrade
        command: ["alacritty", "--class", "updates-term", "-e", "bash", "-c", "yay -Syu; echo; read -rsn1 -p 'Fertig – Taste drücken…'"]
        onExited: root.check()   // Terminal zu → sofort neu zählen
    }

    onClicked: e => e.button === Qt.RightButton ? check() : (upgrade.running = true)

    color: status === "error" ? Qt.alpha(Theme.error, 0.2)
         : hasImportant ? Qt.alpha(Theme.error, 0.15)
         : pkgs.length >= many ? Qt.alpha(Theme.tertiary, 0.2)
         : (hovered ? hoverColor : Qt.alpha(Theme.surfaceVariant, 0.05))

    BarText {
        readonly property string boot: root.reboot ? "  󰜉" : ""
        text: root.status === "error" ? "󰀦" + boot
            : (root.status === "checking" && root.pkgs.length === 0 && !root.checkedAt.getTime()) ? "󰑓"
            : root.pkgs.length === 0 ? "󰗠" + boot
            : `󰚰 ${root.repoCount && root.aurCount ? root.repoCount + " · " + root.aurCount : root.pkgs.length}` + boot
        color: root.status === "error" || root.hasImportant ? Theme.error
             : root.pkgs.length ? Theme.primary : (root.hovered ? Theme.primary : Theme.fg)
        opacity: root.status === "checking" ? 0.6 : 1
    }

    Tooltip {
        target: root
        show: root.hovered
        text: {
            const fmt = d => (d && d.getTime()) ? Qt.formatTime(d, "hh:mm") : "–"
            const l = []
            if (root.status === "error") l.push(`Prüfung fehlgeschlagen – neuer Versuch ${fmt(root.nextCheck)}`, "")
            if (root.reboot) l.push(`󰜉 Neustart nötig: Kernel ${root.reboot}`, "")
            if (root.pkgs.length === 0 && root.status !== "error") l.push("System ist aktuell")
            else if (root.pkgs.length) {
                l.push(`${root.pkgs.length} Updates  (${root.repoCount} Repo · ${root.aurCount} AUR)`, "")
                for (const p of root.pkgs.slice(0, 25)) l.push(`${p.important ? "! " : "  "}${p.name}${p.aur ? " [AUR]" : ""}  ${p.from} → ${p.to}`)
                if (root.pkgs.length > 25) l.push(`  … +${root.pkgs.length - 25} weitere`)
            }
            l.push("", `Geprüft ${fmt(root.checkedAt)} · nächster Check ${fmt(root.nextCheck)}`, "Links: Update   Rechts: jetzt prüfen")
            return l.join("\n")
        }
    }
}

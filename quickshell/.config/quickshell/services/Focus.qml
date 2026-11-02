pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Fokus-Timer (Pomodoro): Fokus → kurze Pause → … → nach n Runden lange Pause.
// Während Fokus „Nicht stören“ (vorheriger Zustand wird danach wiederhergestellt).
// Zustand in ~/.cache/quickshell/focus.json → überlebt Neustarts der Oberfläche.
Singleton {
    id: root
    property string phase: "idle"      // idle | work | short | long
    property bool paused: false
    property real endsAt: 0            // ms (läuft)
    property real left: 0              // ms (pausiert)
    property int round: 1              // aktuelle Fokus-Runde
    property bool dndBefore: false
    property real now: Date.now()

    readonly property var cfg: Config.focus
    readonly property real remaining: phase === "idle" ? 0 : paused ? left : Math.max(0, endsAt - now)
    readonly property real total: (phase === "work" ? cfg.work : phase === "short" ? cfg.short : cfg.long) * 60000
    readonly property real progress: phase === "idle" ? 0 : 1 - remaining / Math.max(1, total)
    readonly property string label: { const s = Math.ceil(remaining / 1000); return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0") }
    readonly property string phaseName: ({ idle: "Fokus-Timer", work: "Fokus", short: "Pause", long: "Lange Pause" })[phase]

    Timer {
        interval: 1000; repeat: true; running: root.phase !== "idle" && !root.paused; triggeredOnStart: true
        onTriggered: { root.now = Date.now(); if (root.endsAt && root.now >= root.endsAt) root.next(true) }
    }

    function begin(ph) {
        phase = ph
        paused = false
        const min = ph === "work" ? cfg.work : ph === "short" ? cfg.short : cfg.long
        endsAt = Date.now() + min * 60000
        now = Date.now()
        if (ph === "work" && cfg.dnd) { dndBefore = Notifs.dnd; Notifs.dnd = true }
        else if (ph !== "work" && cfg.dnd) Notifs.dnd = dndBefore
        save()
    }
    function start() { if (phase === "idle") { round = 1; begin("work") } else toggle() }
    function toggle() {
        if (phase === "idle") return start()
        if (paused) { endsAt = Date.now() + left; paused = false }
        else { left = Math.max(0, endsAt - Date.now()); paused = true }
        save()
    }
    function next(auto) {
        if (phase === "work") {
            const longNow = round % cfg.rounds === 0
            begin(longNow ? "long" : "short")
            notify(longNow ? "Lange Pause 󰅶" : "Pause 󰅶", `Runde ${round} geschafft – ${longNow ? cfg.long : cfg.short} min Pause`)
        } else if (phase !== "idle") {
            round += 1
            begin("work")
            notify("Weiter geht's 󱎫", `Fokus-Runde ${round}: ${cfg.work} min`)
        }
    }
    function stop() {
        if (phase === "work" && cfg.dnd) Notifs.dnd = dndBefore
        phase = "idle"; paused = false; endsAt = 0; left = 0
        save()
    }
    function notify(title, body) {
        Quickshell.execDetached(["notify-send", "-a", "Fokus", "-u", "critical", "-t", "8000", title, body])
    }

    // ── Speichern / Laden ──
    function save() {
        file.setText(JSON.stringify({ phase, paused, endsAt, left, round, dndBefore }))
    }
    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/quickshell/focus.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text())
                root.phase = d.phase ?? "idle"; root.paused = d.paused ?? false; root.endsAt = d.endsAt ?? 0
                root.left = d.left ?? 0; root.round = d.round ?? 1; root.dndBefore = d.dndBefore ?? false
            } catch (e) {}
        }
    }

    IpcHandler {
        target: "focus"
        function toggle(): void { root.start() }
        function stop(): void { root.stop() }
        function skip(): void { root.next(false) }
    }
}

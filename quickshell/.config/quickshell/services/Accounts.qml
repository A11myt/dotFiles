pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// E-Mail (IMAP, scripts/mail.py) und Twitch (scripts/twitch.py).
// Postfächer: ~/.local/share/quickshell/mail.json (privat, nicht in den Dotfiles),
// Passwörter/Twitch-Zugang: Schlüsselbund (secret-tool). Twitch-Kanäle: config.json.
Singleton {
    id: root
    property var mailAccounts: []
    property var mail: ({ accounts: [], unread: 0 })
    property var twitch: ({ channels: [], source: "" })
    readonly property bool mailLoading: mailProc.running
    readonly property bool twitchLoading: twitchProc.running
    readonly property string mailFile: Quickshell.env("HOME") + "/.local/share/quickshell/mail.json"
    readonly property int liveCount: (twitch.channels ?? []).filter(c => c.live).length

    // ── E-Mail ──
    function saveMail(list) {
        mailAccounts = list
        Quickshell.execDetached(["bash", "-c", 'umask 077; mkdir -p "$(dirname "$1")"; printf "%s" "$2" > "$1"; chmod 600 "$1"', "_", mailFile, JSON.stringify(list)])
        mailLater.restart()
    }
    function addMail(acc) { saveMail(mailAccounts.concat([acc])); askPassword(acc.user) }
    function removeMail(i) { saveMail(mailAccounts.filter((_, k) => k !== i)) }
    // Passwort im Terminal abfragen (geht nur in den Schlüsselbund, nirgends sonst hin)
    function askPassword(user) {
        Quickshell.execDetached(["alacritty", "--class", "floating-term", "-e", "bash", "-c",
            'echo "Passwort für $1 (bei Gmail: App-Passwort, myaccount.google.com/apppasswords)"; echo; ' +
            'secret-tool store --label="Quickshell Mail $1" service qs-mail account "$1" && echo "Gespeichert." || echo "Abgebrochen."; ' +
            'qs ipc call accounts refreshMail >/dev/null 2>&1; sleep 1.5', "_", user])
    }
    function refreshMail(force) {
        if (mailProc.running || mailAccounts.length === 0) return
        mailProc.command = ["python3", "-I", Quickshell.shellDir + "/scripts/mail.py", mailFile].concat(force ? ["--refresh"] : [])
        mailProc.running = true
    }
    Timer { id: mailLater; interval: 800; onTriggered: root.refreshMail(true) }
    Timer { interval: 3 * 60000; repeat: true; running: root.mailAccounts.length > 0; onTriggered: root.refreshMail(false) }
    FileView {
        path: root.mailFile
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.mailAccounts = JSON.parse(text()) } catch (e) { root.mailAccounts = [] } root.refreshMail(false) }
    }
    Process { id: mailProc; stdout: StdioCollector { onStreamFinished: { try { root.mail = JSON.parse(text) } catch (e) {} } } }

    // ── Twitch ──
    function refreshTwitch(force) {
        if (twitchProc.running || Config.twitch.length === 0) return
        twitchProc.command = ["python3", "-I", Quickshell.shellDir + "/scripts/twitch.py", JSON.stringify(Config.twitch)].concat(force ? ["--refresh"] : [])
        twitchProc.running = true
    }
    function setupTwitchApi() {
        Quickshell.execDetached(["alacritty", "--class", "floating-term", "-e", "bash", "-c",
            'echo "Offizielle Twitch-API einrichten (kostenlos, ca. 2 Minuten):"; echo; ' +
            'echo "1. dev.twitch.tv/console/apps → Register Your Application"; ' +
            'echo "   Name: beliebig · OAuth Redirect URL: http://localhost · Kategorie: Application Integration · Client-Typ: Confidential"; ' +
            'echo "2. Client-ID und (neues) Secret hier einfügen:"; echo; ' +
            'secret-tool store --label="Quickshell Twitch Client-ID" service qs-twitch key client_id && ' +
            'secret-tool store --label="Quickshell Twitch Secret" service qs-twitch key client_secret && echo "Gespeichert." || echo "Abgebrochen."; ' +
            'rm -f "$XDG_RUNTIME_DIR/qs-twitch.json" ~/.cache/quickshell/twitch-token.json; sleep 1.5'])
    }
    Process { id: twitchProc; stdout: StdioCollector { onStreamFinished: { try { root.twitch = JSON.parse(text) } catch (e) {} } } }
    Connections { target: Config; function onTwitchChanged() { root.refreshTwitch(false) } }

    IpcHandler {
        target: "accounts"
        function refreshMail(): void { root.refreshMail(true) }
        function refreshTwitch(): void { root.refreshTwitch(true) }
    }
}

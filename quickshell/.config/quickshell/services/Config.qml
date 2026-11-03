pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Einstellungen der Oberfläche in config.json (liegt in den Dotfiles, wird mitversioniert).
// Änderungen aus der Oberfläche: Config.set("schlüssel", wert) → wird sofort gespeichert.
// Von Hand bearbeitet → wird automatisch neu geladen.
Singleton {
    id: root
    readonly property alias widgets: data.widgets
    readonly property alias feeds: data.feeds
    readonly property alias newsCount: data.newsCount
    readonly property alias newsHidden: data.newsHidden
    readonly property alias newsTopic: data.newsTopic
    // Themen der Feeds (Reihenfolge der Reiter), Vorschläge pro Thema
    readonly property var topics: [...new Set(data.feeds.map(f => topicOf(f.name)))]
    readonly property var feedSuggestions: [
        { topic: "Allgemein", name: "tagesschau", url: "https://www.tagesschau.de/index~rss2.xml" },
        { topic: "Allgemein", name: "Spiegel", url: "https://www.spiegel.de/schlagzeilen/index.rss" },
        { topic: "Allgemein", name: "Zeit", url: "https://newsfeed.zeit.de/index" },
        { topic: "Tech", name: "heise", url: "https://www.heise.de/rss/heise-top-atom.xml" },
        { topic: "Tech", name: "golem", url: "https://rss.golem.de/rss.php?feed=ATOM1.0" },
        { topic: "Tech", name: "t3n", url: "https://t3n.de/rss.xml" },
        { topic: "Tech", name: "Arch Linux", url: "https://archlinux.org/feeds/news/" },
        { topic: "Tech", name: "Hacker News", url: "https://hnrss.org/frontpage" },
        { topic: "Gaming", name: "Wowhead", url: "https://www.wowhead.com/news/rss/all" },
        { topic: "Gaming", name: "MeinMMO", url: "https://mein-mmo.de/feed/" },
        { topic: "Gaming", name: "GameStar", url: "https://www.gamestar.de/news/rss/news.rss" },
        { topic: "Gaming", name: "PCGH", url: "https://www.pcgameshardware.de/feed.cfm" },
        { topic: "Gaming", name: "PC Gamer", url: "https://www.pcgamer.com/rss/" },
        { topic: "Gaming", name: "Rock Paper Shotgun", url: "https://www.rockpapershotgun.com/feed" },
        { topic: "Gaming", name: "Eurogamer", url: "https://www.eurogamer.de/feed" },
        { topic: "Gaming", name: "Steam", url: "https://store.steampowered.com/feeds/news/" },
        { topic: "Sport", name: "kicker", url: "https://newsfeed.kicker.de/news/aktuell" }
    ]
    // Thema eines Feeds: eigenes Feld, sonst aus den Vorschlägen, sonst „Allgemein“
    function topicOf(name) {
        const f = data.feeds.find(x => x.name === name)
        return f?.topic || feedSuggestions.find(x => x.name === name)?.topic || "Allgemein"
    }
    readonly property alias bar: data.bar
    readonly property alias focus: data.focus
    readonly property alias twitch: data.twitch
    readonly property alias holidayState: data.holidayState

    // alle bekannten Dashboard-Widgets (Reihenfolge = Vorschlag beim Hinzufügen)
    readonly property var widgetInfo: ({
        weather:   { name: "Wetter",        icon: "󰖐", desc: "Jetzt, nächste Stunden, 6 Tage" },
        news:      { name: "Nachrichten",   icon: "󰎕", desc: "Schlagzeilen aus deinen RSS-Feeds" },
        media:     { name: "Medien",        icon: "󰝚", desc: "Was gerade läuft, mit Steuerung" },
        system:    { name: "System",        icon: "󰻠", desc: "CPU, RAM, Netz mit Verlauf, Speicher" },
        processes: { name: "Prozesse",      icon: "󰓅", desc: "Programme mit der meisten Last" },
        battery:   { name: "Akkus",         icon: "󰁹", desc: "Stand, Gesundheit, Ladegrenze" },
        health:    { name: "System-Gesundheit", icon: "󰓙", desc: "dotdoctor-Ampel, Updates, Arch-News" },
        agenda:    { name: "Termine",       icon: "󰃭", desc: "Die nächsten Tage aus deinen Kalendern" },
        mail:      { name: "E-Mail",        icon: "󰇮", desc: "Ungelesene Mails deiner Postfächer" },
        twitch:    { name: "Twitch",        icon: "󰕃", desc: "Welche Kanäle gerade live sind" }
    })
    // Elemente der Leiste, die sich ausblenden lassen
    readonly property var barInfo: ({
        weather:   "Wetter", media: "Medien (Mitte)", updates: "Updates", privacy: "Mikrofon-Warnung",
        volume:    "Lautstärke", bluetooth: "Bluetooth", battery: "Akku", network: "WLAN",
        powerProfile: "Energieprofil", focus: "Fokus-Timer", mail: "Ungelesene Mails", tray: "Infobereich (Tray)"
    })

    function set(key, value) { data[key] = value }
    function setFocus(key, v) { const f = Object.assign({}, data.focus); f[key] = v; data.focus = f }
    function setBar(key, on) { const b = Object.assign({}, data.bar); b[key] = on; data.bar = b }
    function barOn(key) { return data.bar[key] ?? true }

    FileView {
        id: file
        path: Quickshell.shellDir + "/config.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // gibt es die Datei noch nicht → mit Standardwerten anlegen
        onLoadFailed: err => { if (err === FileViewError.FileNotFound) writeAdapter() }

        JsonAdapter {
            id: data
            property var widgets: ["weather", "news", "system", "processes", "battery"]
            property var feeds: [
                { name: "tagesschau", url: "https://www.tagesschau.de/index~rss2.xml" },
                { name: "heise", url: "https://www.heise.de/rss/heise-top-atom.xml" }
            ]
            property int newsCount: 6
            property var newsHidden: []        // weggeklickte Schlagzeilen (Links)
            property string newsTopic: "Alle"  // gewählter Reiter im Nachrichten-Widget
            property var bar: ({})              // Schlüssel aus barInfo → false = ausgeblendet
            // Fokus-Timer: Minuten, lange Pause nach n Runden, „Nicht stören“ während Fokus
            property var focus: ({ work: 25, short: 5, long: 15, rounds: 4, dnd: true })
            property var twitch: []            // Twitch-Kanäle (Login-Namen)
            property string holidayState: "HE" // Bundesland für Feiertage
        }
    }
}

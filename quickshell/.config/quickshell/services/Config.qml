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
    readonly property alias bar: data.bar

    // alle bekannten Dashboard-Widgets (Reihenfolge = Vorschlag beim Hinzufügen)
    readonly property var widgetInfo: ({
        weather:   { name: "Wetter",        icon: "󰖐", desc: "Jetzt, nächste Stunden, 6 Tage" },
        news:      { name: "Nachrichten",   icon: "󰎕", desc: "Schlagzeilen aus deinen RSS-Feeds" },
        media:     { name: "Medien",        icon: "󰝚", desc: "Was gerade läuft, mit Steuerung" },
        system:    { name: "System",        icon: "󰻠", desc: "CPU, RAM, Netz mit Verlauf, Speicher" },
        processes: { name: "Prozesse",      icon: "󰓅", desc: "Programme mit der meisten Last" },
        battery:   { name: "Akkus",         icon: "󰁹", desc: "Stand, Gesundheit, Ladegrenze" }
    })
    // Elemente der Leiste, die sich ausblenden lassen
    readonly property var barInfo: ({
        weather:   "Wetter", media: "Medien (Mitte)", updates: "Updates", privacy: "Mikrofon-Warnung",
        volume:    "Lautstärke", bluetooth: "Bluetooth", battery: "Akku", network: "WLAN",
        powerProfile: "Energieprofil"
    })

    function set(key, value) { data[key] = value }
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
            property var bar: ({})              // Schlüssel aus barInfo → false = ausgeblendet
        }
    }
}

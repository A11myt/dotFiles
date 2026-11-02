pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Farben (Matugen → colors.json) und Schriften (fontgen → fonts.json), live beobachtet.
// Fallbacks gelten nur, bis die Dateien gelesen sind.
Singleton {
    id: root

    property var c: ({})
    property var f: ({})

    readonly property color primary: c.primary ?? "#b8c3ff"
    readonly property color fgOnPrimary: c.on_primary ?? "#1f2c61"
    readonly property color primaryContainer: c.primary_container ?? "#364479"
    readonly property color secondary: c.secondary ?? "#c3c5dd"
    readonly property color tertiary: c.tertiary ?? "#e4bad9"
    readonly property color error: c.error ?? "#ffb4ab"
    readonly property color fgOnError: c.on_error ?? "#690005"
    readonly property color errorContainer: c.error_container ?? "#93000a"
    readonly property color surface: c.surface ?? "#121318"
    readonly property color surfaceContainerLowest: c.surface_container_lowest ?? "#0d0e13"
    readonly property color surfaceContainerLow: c.surface_container_low ?? "#1b1b21"
    readonly property color surfaceContainer: c.surface_container ?? "#1f1f25"
    readonly property color surfaceContainerHigh: c.surface_container_high ?? "#292a2f"
    readonly property color surfaceContainerHighest: c.surface_container_highest ?? "#34343a"
    readonly property color surfaceVariant: c.surface_variant ?? "#45464f"
    // Achtung: Namen wie "onSurface" hält QML für Signal-Handler → bleiben schwarz. Daher fg*.
    readonly property color fg: c.on_surface ?? "#e3e1e9"
    readonly property color fgMuted: c.on_surface_variant ?? "#c6c5d0"
    readonly property color outline: c.outline ?? "#90909a"
    readonly property color outlineVariant: c.outline_variant ?? "#45464f"
    readonly property color scrim: c.scrim ?? "#000000"
    // helles Theme? (aus der Flächenfarbe, damit es auch ohne Modus-Feld stimmt)
    readonly property bool isLight: surface.hslLightness > 0.5

    readonly property string fontUi: f.ui ?? "sans-serif"
    readonly property string fontMono: f.mono ?? "monospace"
    readonly property string fontAccent: f.accent ?? fontUi
    readonly property int fontPx: f.ui_px ?? 13

    // gemeinsame Maße
    readonly property int radius: 14
    readonly property int pillRadius: 18
    readonly property int gap: 8
    readonly property int anim: 220

    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/colors.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.c = JSON.parse(text()) } catch (e) { console.warn("colors.json:", e) } }
    }
    FileView {
        path: Quickshell.env("HOME") + "/.config/quickshell/fonts.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.f = JSON.parse(text()) } catch (e) { console.warn("fonts.json:", e) } }
    }
}

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.bar
import qs.notifications
import qs.osd
import qs.panels
import qs.overview
import qs.services

ShellRoot {
    // Dienste beim Start ansprechen – sie initialisieren sich erst beim ersten Zugriff
    property var _init: [UPower.displayDevice, PowerProfiles.profile, Mpris.players, Bluetooth.defaultAdapter,
                         Networking.devices, Hyprland.workspaces, Hyprland.toplevels, DesktopEntries.applications,
                         Notifs.dnd]

    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }
    Popups {}
    Center {}
    Osd {}
    QuickSettings {}
    Calendar {}
    Clipboard {}
    PowerMenu {}
    Overview {}
    Launcher {}
    Settings {}
    MediaPanel {}
    Screenshot {}

    // Fernsteuerung für Tastenkombinationen: qs ipc call panels toggle center|quick|calendar|clipboard
    IpcHandler {
        target: "panels"
        function toggle(name: string): void { Panels.toggle(name) }
        // Quick Settings auf Unterseite: qs ipc call panels page wifi|bluetooth|audio
        function page(name: string): void { Panels.showPage(name) }
        function close(): void { Panels.close() }
        function open(): string { return Panels.open }
    }
    IpcHandler {
        target: "power"
        function toggle(): void { Power.toggle() }
    }
}

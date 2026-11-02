import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower
import Quickshell.Services.Mpris
import Quickshell.Networking
import Quickshell.Bluetooth
import qs.bar

ShellRoot {
    // Dienste beim Start ansprechen – sie initialisieren sich erst beim ersten Zugriff
    property var _init: [UPower.displayDevice, PowerProfiles.profile, Mpris.players, Bluetooth.defaultAdapter,
                         Networking.devices, Hyprland.workspaces, Hyprland.toplevels, DesktopEntries.applications]

    Variants {
        model: Quickshell.screens
        delegate: Bar {}
    }
}

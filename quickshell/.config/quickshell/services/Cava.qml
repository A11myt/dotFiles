pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Musik-Visualizer: cava liest PipeWire und liefert Balkenhöhen (0–1).
// Läuft nur, solange ein Visualizer sichtbar ist (users > 0) UND etwas abgespielt wird.
Singleton {
    id: root
    readonly property int bars: 32
    property var values: []
    property int users: 0
    readonly property bool available: avail.code === 0
    readonly property bool playing: Mpris.players.values.some(p => p.isPlaying)
    readonly property bool active: available && users > 0 && playing
    readonly property string conf: Quickshell.env("XDG_RUNTIME_DIR") + "/qs-cava.conf"

    // cava vorhanden?
    Process { id: avail; property int code: -1; command: ["sh", "-c", "command -v cava"]; running: true; onExited: c => code = c }

    // nachträglich installiert? beim nächsten Bedarf erneut prüfen
    onUsersChanged: if (users > 0 && !available && !avail.running) avail.running = true

    onActiveChanged: {
        if (active) { writeConf.running = true }
        else { proc.running = false; values = [] }
    }
    Process {
        id: writeConf
        command: ["sh", "-c", `cat > "$1" <<'EOC'
[general]
bars = ${root.bars}
framerate = 30
autosens = 1
[input]
method = pipewire
source = auto
[output]
method = raw
channels = mono
mono_option = average
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
bar_delimiter = 59
frame_delimiter = 10
[smoothing]
noise_reduction = 60
EOC`, "_", root.conf]
        onExited: if (root.active) proc.running = true
    }
    Process {
        id: proc
        command: ["cava", "-p", root.conf]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";")
                const out = []
                for (let i = 0; i < root.bars; i++) out.push(Math.min(1, (Number(v[i]) || 0) / 100))
                root.values = out
            }
        }
    }
}

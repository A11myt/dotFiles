// Zwischenablage-Verlauf (cliphist): Suchen, Klick = wieder kopieren, Rechtsklick = löschen
import app from "ags/gtk3/app"
import { Astal, Gdk, Gtk } from "ags/gtk3"
import { execAsync } from "ags/process"
import { createComputed, createState, For } from "gnim"
import GLib from "gi://GLib"
import { closePanels, isOpen, openPanel } from "./panels"

type Item = { id: string; line: string; text: string; image: string | null }

const CACHE = `${GLib.get_user_cache_dir()}/ags/clip`
const MAX_SHOWN = 60
const [items, setItems] = createState<Item[]>([])
const [query, setQuery] = createState("")

// cliphist list: "<id>\t<vorschau>"; Bilder: "[[ binary data 33 KiB png 1920x1080 ]]"
const IMG = /^\[\[ binary data .* (png|jpe?g|webp|gif|bmp) (\d+x\d+) \]\]$/

async function load() {
    try {
        const out = await execAsync(["cliphist", "list"])
        GLib.mkdir_with_parents(CACHE, 0o755)
        const list: Item[] = out.split("\n").filter(Boolean).map(line => {
            const [id, ...rest] = line.split("\t")
            const text = rest.join("\t")
            const m = text.match(IMG)
            return { id, line, text: m ? `Bild ${m[2].replace("x", " × ")}` : text, image: m ? `${CACHE}/${id}.${m[1]}` : null }
        })
        setItems(list)
        // Vorschaubilder nur für die obersten Einträge erzeugen (einmal, dann gecacht)
        for (const it of list.slice(0, 20)) {
            if (it.image && !GLib.file_test(it.image, GLib.FileTest.EXISTS)) {
                await execAsync(["bash", "-c", `printf '%s' "$1" | cliphist decode > "$2"`, "_", it.line, it.image]).catch(() => {})
            }
        }
        setItems([...list])   // neu zeichnen, damit die Bilder erscheinen
    } catch {
        setItems([])
    }
}

function copy(it: Item) {
    closePanels()
    execAsync(["bash", "-c", `printf '%s' "$1" | cliphist decode | wl-copy`, "_", it.line]).catch(() => {})
}

function remove(it: Item) {
    execAsync(["bash", "-c", `printf '%s' "$1" | cliphist delete`, "_", it.line])
        .then(load).catch(() => {})
}

const matches = (its: Item[], q: string) => {
    const s = q.trim().toLowerCase()
    return its.filter(it => !s || it.text.toLowerCase().includes(s)).slice(0, MAX_SHOWN)
}
// neu berechnet bei neuen Einträgen UND beim Tippen
const shown = createComputed([items, query], matches)

// beim Öffnen neu laden und Suche leeren
openPanel.subscribe(() => {
    if (openPanel.get() === "clipboard") { setQuery(""); load() }
})

export default function ClipboardPanel() {
    let entry: Gtk.Entry | null = null

    return (
        <window
            name="clipboard"
            namespace="ags-clipboard"
            class="ClipboardPanel"
            anchor={Astal.WindowAnchor.TOP}
            layer={Astal.Layer.OVERLAY}
            exclusivity={Astal.Exclusivity.NORMAL}
            keymode={Astal.Keymode.EXCLUSIVE}
            visible={isOpen("clipboard")}
            application={app}
            onShow={() => entry?.grab_focus()}
            onKeyPressEvent={(_, e: Gdk.Event) => { if (e.get_keyval()[1] === Gdk.KEY_Escape) closePanels() }}
        >
            <box class="panel" vertical spacing={10}>
                <box spacing={8}>
                    <label class="title" label="Zwischenablage" xalign={0} hexpand />
                    <button class="wipe" onClick={() => execAsync(["cliphist", "wipe"]).then(load).catch(() => {})}>
                        <label label="Verlauf leeren" />
                    </button>
                </box>
                <entry
                    class="search"
                    placeholderText="Suchen … (Enter = erster Treffer)"
                    text={query}
                    $={(self: Gtk.Entry) => (entry = self)}
                    onChanged={self => setQuery(self.text)}
                    onActivate={() => { const first = shown.get()[0]; if (first) copy(first) }}
                />
                <scrollable vexpand hscroll={2 /* NEVER */} heightRequest={460}>
                    <box vertical spacing={4}>
                        <For each={shown}>
                            {(it: Item) => (
                                <button
                                    class={it.image ? "clip image" : "clip"}
                                    tooltipText="Klick: kopieren · Rechtsklick: löschen"
                                    onClick={(_, e) => (e.button === Astal.MouseButton.SECONDARY ? remove(it) : copy(it))}
                                >
                                    <box spacing={10}>
                                        {it.image ? <box class="thumb" css={`background-image: url("file://${it.image}");`} /> : <box />}
                                        <label label={it.text.replace(/\s+/g, " ").slice(0, 200)} xalign={0} hexpand truncate maxWidthChars={60} />
                                    </box>
                                </button>
                            )}
                        </For>
                        <label class="empty" visible={shown(s => s.length === 0)}
                            label={items(i => (i.length === 0 ? "Noch nichts kopiert (oder cliphist nicht installiert)" : "Keine Treffer"))} />
                    </box>
                </scrollable>
            </box>
        </window>
    )
}

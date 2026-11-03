# wintheme – Matugen für Windows 11

Färbt **Windows** (Akzentfarbe für Startmenü, Taskleiste, Fensterrahmen; Hell/Dunkel; Wallpaper),
**Windows Terminal** (Schema „Matugen“) und **VS Code** passend zum Wallpaper ein.
Die Farben werden wie bei Matugen berechnet (Material You, Spezifikation 2021) – gleiches Bild und
gleiche Einstellungen ergeben dieselben Farben wie auf dem Laptop.

## Installieren (ohne Administratorrechte)

1. Diesen Ordner `windows/wintheme` auf den PC kopieren (oder das Repo klonen).
2. PowerShell in diesem Ordner öffnen und ausführen:
   ```powershell
   powershell -ExecutionPolicy Bypass -File .\install.ps1
   ```
   Fehlt Python, wird es per `winget` für deinen Benutzer installiert. wintheme bekommt eine eigene
   Python-Umgebung unter `%LOCALAPPDATA%\wintheme` und färbt sofort mit dem aktuellen Wallpaper ein.

## Benutzen

```powershell
wintheme C:\Bilder\wallpaper.jpg          # als Wallpaper setzen und alles einfärben
wintheme --scheme vibrant                  # Schema (wird gemerkt): tonal-spot, vibrant, expressive, fidelity, …
wintheme --mode light                      # hell/dunkel (wird gemerkt)
wintheme --sources                         # die 4 Ausgangsfarben des aktuellen Wallpapers
wintheme --color 2                         # Ausgangsfarbe 2 für dieses Bild (wird pro Bild gemerkt)
wintheme --titlebars on                    # Akzentfarbe auch in Titelleisten
wintheme --dry-run                         # nur anzeigen, nichts ändern
```

- **Rechtsklick auf ein Bild** im Explorer → „Weitere Optionen anzeigen“ → „Als Hintergrund mit Farben (wintheme)“.
- **Automatisch:** Ein Hintergrundprozess (Autostart) erkennt, wenn du das Wallpaper über die Windows-Einstellungen
  wechselst, und färbt neu ein. Ohne: `install.ps1 -NoWatch`.

## Was geändert wird

| Bereich | Wo | Sicherung |
|---|---|---|
| Windows | Registry (Benutzer): Akzentpalette, Akzentfarbe, Hell/Dunkel, „Akzentfarbe automatisch wählen“ aus | – (über die Windows-Einstellungen jederzeit änderbar) |
| Windows Terminal | `settings.json`: Schema „Matugen“, als Standard für alle Profile | `settings.json.wintheme-backup` beim ersten Lauf |
| VS Code | `settings.json`: markierter Block `workbench.colorCustomizations` (nur für das aktive Theme) | Rest der Datei inkl. Kommentare bleibt unverändert |

## Rückgängig machen

Vor jedem Einfärben merkt sich wintheme den bisherigen Zustand (Registry-Werte, Terminal- und
VS-Code-Einstellungen, Wallpaper) – die letzten 20 Stände und einmalig den Zustand vor der ersten Benutzung.

```powershell
wintheme --undo        # letzten Schritt zurück (mehrmals = weiter zurück)
wintheme --original    # wie vor der ersten Benutzung (lässt sich mit --undo wieder zurücknehmen)
wintheme --history     # gespeicherte Stände
```

Entfernen: `install.ps1 -Uninstall` stellt vorher den Originalzustand wieder her
(`-Uninstall -KeepColors` behält die aktuellen Farben). Einstellungen und Stände: `%APPDATA%\wintheme`.

## Pflege (auf dem Laptop)

Die VS-Code-Vorlage ist eine Kopie aus `matugen/.config/matugen/templates/` – nach Änderungen dort:
`./sync-templates.sh`

<#
  wintheme installieren (Windows 11, ohne Administratorrechte)

  .\install.ps1              installieren / aktualisieren
  .\install.ps1 -NoWatch     ohne Autostart (kein automatisches Einfärben beim Wallpaper-Wechsel)
  .\install.ps1 -Uninstall   Originalfarben wiederherstellen und alles entfernen
  .\install.ps1 -Uninstall -KeepColors   entfernen, aktuelle Farben behalten

  Rückgängig ohne Deinstallieren:  wintheme --undo   ·   wintheme --original   ·   wintheme --history

  Danach:  wintheme C:\Pfad\bild.jpg   – oder im Explorer Rechtsklick auf ein Bild
           → „Weitere Optionen anzeigen“ → „Als Hintergrund mit Farben (wintheme)“
#>
param([switch]$NoWatch, [switch]$Uninstall, [switch]$KeepColors)
$ErrorActionPreference = 'Stop'

$Dest    = Join-Path $env:LOCALAPPDATA 'wintheme'
$Shim    = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\wintheme.cmd'   # liegt im PATH
$MenuKey = 'HKCU:\Software\Classes\SystemFileAssociations\image\shell\wintheme'
$Startup = Join-Path ([Environment]::GetFolderPath('Startup')) 'wintheme-watch.lnk'

if ($Uninstall) {
    Get-Process pythonw -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -like "$Dest*" } | Stop-Process -Force
    $vpy = Join-Path $Dest 'venv\Scripts\python.exe'
    if (-not $KeepColors -and (Test-Path $vpy)) {
        Write-Host 'Stelle den Zustand vor der ersten Benutzung wieder her …'
        & $vpy (Join-Path $Dest 'wintheme.py') --original
    }
    Remove-Item -Recurse -Force $Dest, $Shim, $Startup -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $MenuKey -ErrorAction SilentlyContinue
    Write-Host 'wintheme entfernt. Einstellungen bleiben in %APPDATA%\wintheme (bei Bedarf löschen).'
    return
}

# ── Python finden (sonst per winget für diesen Benutzer installieren) ──
function Find-Python {
    # Kandidaten: Python-Launcher „py -3“, sonst „python“ (nicht der Store-Platzhalter in WindowsApps)
    $candidates = @(
        [pscustomobject]@{ Name = 'py';     Args = [string[]]@('-3') },
        [pscustomobject]@{ Name = 'python'; Args = [string[]]@() }
    )
    foreach ($c in $candidates) {
        $exe = Get-Command $c.Name -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $exe -or $exe.Source -like '*\WindowsApps\python*') { continue }
        $pyArgs = $c.Args
        $ok = & $exe.Source @pyArgs -c 'import sys; print(sys.version_info >= (3, 10))' 2>$null
        if ($ok -eq 'True') { return [pscustomobject]@{ Exe = $exe.Source; Args = $pyArgs } }
    }
    return $null
}
$py = Find-Python
if (-not $py) {
    Write-Host 'Python fehlt – wird für diesen Benutzer installiert (winget) …'
    winget install -e --id Python.Python.3.12 --scope user --accept-package-agreements --accept-source-agreements
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'User') + ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $py = Find-Python
    if (-not $py) { throw 'Python nicht gefunden – bitte Terminal neu öffnen und install.ps1 erneut starten.' }
}

# ── Dateien + eigene Python-Umgebung ──
New-Item -ItemType Directory -Force -Path $Dest | Out-Null
Copy-Item -Force (Join-Path $PSScriptRoot 'wintheme.py') $Dest
Copy-Item -Force -Recurse (Join-Path $PSScriptRoot 'templates') $Dest
$venv = Join-Path $Dest 'venv'
if (-not (Test-Path (Join-Path $venv 'Scripts\python.exe'))) {
    $pyArgs = $py.Args
    & $py.Exe @pyArgs -m venv $venv
}
$vpy  = Join-Path $venv 'Scripts\python.exe'
$vpyw = Join-Path $venv 'Scripts\pythonw.exe'
& $vpy -m pip install --quiet --upgrade pip
& $vpy -m pip install --quiet 'materialyoucolor==3.0.4' 'pillow>=10'
$script = Join-Path $Dest 'wintheme.py'

# ── Befehl „wintheme“ ──
Set-Content -Encoding ASCII -Path $Shim -Value "@`"$vpy`" `"$script`" %*"

# ── Rechtsklick-Menü für Bilder ──
New-Item -Force -Path $MenuKey | Out-Null
Set-ItemProperty -Path $MenuKey -Name '(default)' -Value 'Als Hintergrund mit Farben (wintheme)'
New-Item -Force -Path "$MenuKey\command" | Out-Null
Set-ItemProperty -Path "$MenuKey\command" -Name '(default)' -Value "`"$vpyw`" `"$script`" `"%1`""

# ── Autostart: bei Wallpaper-Wechsel automatisch einfärben ──
if ($NoWatch) {
    Remove-Item -Force $Startup -ErrorAction SilentlyContinue
} else {
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($Startup)
    $lnk.TargetPath = $vpyw
    $lnk.Arguments = "`"$script`" --watch"
    $lnk.WorkingDirectory = $Dest
    $lnk.Description = 'wintheme: Farben bei Wallpaper-Wechsel anpassen'
    $lnk.Save()
    Get-Process pythonw -ErrorAction SilentlyContinue | Where-Object { $_.Path -like "$Dest*" } | Stop-Process -Force
    Start-Process -FilePath $vpyw -ArgumentList "`"$script`" --watch" -WindowStyle Hidden
}

Write-Host ''
Write-Host 'wintheme ist installiert. Einmal mit dem aktuellen Wallpaper einfärben …'
& $vpy $script
Write-Host ''
Write-Host 'Fertig. Ausprobieren:  wintheme --help   ·   wintheme C:\Pfad\bild.jpg --scheme vibrant'

#!/usr/bin/env bash
# Bildschirmaufnahme mit wf-recorder (unabhängig von Quickshell, Status in $XDG_RUNTIME_DIR/qs-recording)
#   record.sh start <"x,y BxH" | output:NAME> <ton 0|1>
#   record.sh stop
#   record.sh toggle-hint      (nur Hinweis, wenn wf-recorder fehlt)
# Hardware-Kodierung (VAAPI, intel-media-driver) wenn vorhanden, sonst libx264.
STATE="${XDG_RUNTIME_DIR:-/tmp}/qs-recording"
LOG="$HOME/.logs/record.log"
mkdir -p "$HOME/.logs"

notify() { notify-send -a Bildschirmaufnahme "$@" 2>/dev/null; }

start_rec() {   # $1 Ziel, $2 Ton, $3 hw|sw → PID
    local args=()
    if [[ $1 == output:* ]]; then args+=(-o "${1#output:}"); else args+=(-g "$1"); fi
    if [[ $3 == hw ]]; then args+=(-c h264_vaapi -d /dev/dri/renderD128)
    else args+=(-c libx264 -p preset=veryfast -p crf=23); fi
    [[ $2 == 1 ]] && args+=("--audio=$(pactl get-default-sink).monitor")
    args+=(-f "$out" -y)
    echo "== $(date '+%F %T') wf-recorder ${args[*]}" >>"$LOG"
    setsid wf-recorder "${args[@]}" </dev/null >>"$LOG" 2>&1 &
    echo $!
}

case $1 in
start)
    [[ -s $STATE ]] && exit 0                     # läuft schon
    if ! command -v wf-recorder >/dev/null; then
        notify "Bildschirmaufnahme nicht möglich" "wf-recorder fehlt: sudo pacman -S wf-recorder intel-media-driver"
        exit 1
    fi
    dir="$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")/Bildschirmaufnahmen"
    mkdir -p "$dir"
    out="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"
    mode=sw
    [[ -e /usr/lib/dri/iHD_drv_video.so && -e /dev/dri/renderD128 ]] && mode=hw
    pid=$(start_rec "$2" "${3:-0}" $mode)
    sleep 1
    if ! kill -0 "$pid" 2>/dev/null && [[ $mode == hw ]]; then   # VAAPI klappt nicht → Software
        echo "VAAPI fehlgeschlagen, nehme libx264" >>"$LOG"
        mode=sw; pid=$(start_rec "$2" "${3:-0}" sw); sleep 1
    fi
    if ! kill -0 "$pid" 2>/dev/null; then
        notify "Aufnahme fehlgeschlagen" "Details: ~/.logs/record.log"
        exit 1
    fi
    printf '%s\t%s\t%s\t%s\n' "$(date +%s)" "$pid" "$out" "$mode" >"$STATE"
    ;;
stop)
    [[ -s $STATE ]] || exit 0
    IFS=$'\t' read -r started pid out mode <"$STATE"
    kill -INT "$pid" 2>/dev/null                  # Strg+C: wf-recorder schreibt die Datei sauber zu Ende
    for _ in $(seq 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    kill -0 "$pid" 2>/dev/null && kill "$pid"
    rm -f "$STATE"
    secs=$(( $(date +%s) - started ))
    size=$(du -h "$out" 2>/dev/null | cut -f1)
    (
        act=$(notify-send -a Bildschirmaufnahme -i video-x-generic -A default=Öffnen -A open=Öffnen -A folder=Ordner \
            "Aufnahme gespeichert" "$((secs / 60)):$(printf '%02d' $((secs % 60))) min · ${size:-?} · $(basename "$out")" 2>/dev/null) || true
        case $act in
            default|open) xdg-open "$out" ;;
            folder) nautilus --select "$out" ;;
        esac
    ) </dev/null >/dev/null 2>&1 &
    disown
    ;;
*)
    echo "record.sh start <geometrie|output:NAME> <ton 0|1> | stop" >&2; exit 2 ;;
esac

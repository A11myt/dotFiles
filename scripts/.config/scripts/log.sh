#!/usr/bin/env bash
# Unified logging helper — source this file at the top of any script.
# Override LOG_TOOL before sourcing to set a custom tool name:
#   LOG_TOOL=my-tool source ~/.config/scripts/log.sh

_LOG_ROOT="$HOME/.logs"

if [[ -z "${LOG_TOOL:-}" ]]; then
    _LOG_TOOL="$(basename "${BASH_SOURCE[-1]}" .sh)"
else
    _LOG_TOOL="$LOG_TOOL"
fi

_log() {
    local level="$1"; shift
    local file="$_LOG_ROOT/$_LOG_TOOL/$(date +%Y-%m-%d).log"
    mkdir -p "${file%/*}"
    printf '%s [%-5s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$level" "$*" >> "$file"
}

log_info()  { _log "INFO"  "$@"; }
log_warn()  { _log "WARN"  "$@"; }
log_error() { _log "ERROR" "$@"; }

#!/usr/bin/env bash
# logging.sh — Handles log output and debug echoing

# === Determine REPO_ROOT if not already set ===
if [[ -z "${REPO_ROOT:-}" ]]; then
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

# === Import DebugEcho if available ===
if [[ -f "${REPO_ROOT}/lib/debugecho.sh" ]]; then
  source "${REPO_ROOT}/lib/debugecho.sh"
fi

# === Default LOG_LEVEL ===
LOG_LEVEL="${LOG_LEVEL:-info}"

log() {
  local level="$1"
  shift
  local msg="$*"
  printf "[%s] %s\n" "${level^^}" "${msg}"
}

DebugEcho 📥 BEGIN logging.sh

# Default to info unless set externally
LOG_LEVEL="${LOG_LEVEL:-info}"

log_timestamp() {
  date "+%Y-%m-%d %H:%M:%S"
}

log_debug() {
  [[ "${LOG_LEVEL}" == "debug" ]] && printf "[%s] [debug] %s\n" "$(log_timestamp)" "$*" >&2
}

log_info() {
  printf "[%s] [info]  %s\n" "$(log_timestamp)" "$*" >&2
}

log_warn() {
  printf "[%s] [warn]  %s\n" "$(log_timestamp)" "$*" >&2
}

log_error() {
  printf "[%s] [error] %s\n" "$(log_timestamp)" "$*" >&2
}

# Chatty debug echo for tracing every important step or variable
DebugEcho() {
  [[ "${LOG_LEVEL}" == "debug" ]] && printf "[DEBUG] %s\n" "$*" >&2
}

DebugEcho 📤 END logging.sh
###EOF
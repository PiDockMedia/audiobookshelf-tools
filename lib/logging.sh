#!/usr/bin/env bash
# lib/logging.sh - Centralized logger with support for CLI, container, and test modes

# Prevent multiple sourcing
[[ -n "${_LOGGING_SH_LOADED:-}" ]] && return
readonly _LOGGING_SH_LOADED=1

# === Default Log Level ===
LOG_LEVEL="${LOG_LEVEL:-info}"
LOG_FILE="${LOG_FILE:-}"

# === Log Level Mapping ===
declare -A LOG_LEVELS=(
  [debug]=0
  [info]=1
  [warn]=2
  [error]=3
)

log_ts() {
  date '+%Y-%m-%d %H:%M:%S'
}

log_should_log() {
  local level="$1"
  [[ -z "${LOG_LEVELS[$level]+x}" ]] && return 1
  [[ "${LOG_LEVELS[$level]}" -ge "${LOG_LEVELS[$LOG_LEVEL]:-1}" ]] && return 0
  return 1
}

log() {
  local level="$1"
  shift
  local color=""
  local reset="\033[0m"

  case "$level" in
    debug) color="\033[0;37m" ;;  # Gray
    info)  color="\033[0;36m" ;;  # Cyan
    warn)  color="\033[0;33m" ;;  # Yellow
    error) color="\033[0;31m" ;;  # Red
  esac

  if log_should_log "$level"; then
    local ts
    ts="$(log_ts)"
    local msg="[$ts] [$level] $*"

    if [[ -n "${LOG_FILE}" ]]; then
      echo "${msg}" >> "${LOG_FILE}"
    else
      echo -e "${color}${msg}${reset}"
    fi

    [[ "$level" == "error" ]] && return 1
  fi
}

log_debug() { log debug "$@"; }
log_info()  { log info "$@"; }
log_warn()  { log warn "$@"; }
log_error() { log error "$@"; }

###EOF

#!/usr/bin/env bash
# logging.sh — Provides structured logging and DebugEcho support

# 📥 BEGIN logging.sh

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

# 📤 END logging.sh
###EOF
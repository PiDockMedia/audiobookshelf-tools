# logging.sh
LOG_LEVEL="${LOG_LEVEL:-info}"

function DebugEcho() {
  if [[ "${LOG_LEVEL}" == "debug" ]]; then
    echo "[DEBUG] $*" >&2
  fi
}

function print_divider() {
  [[ "${LOG_LEVEL}" == "debug" ]] && echo "===================================="
}

function log_info() {
  echo "[INFO] $*"
}

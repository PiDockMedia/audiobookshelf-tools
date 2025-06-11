# lib/debugecho.sh - Simple debug echo utility

DebugEcho() {
  if [[ "${LOG_LEVEL:-}" == "debug" ]]; then
    printf '[DEBUG] %s\n' "$*"
  fi
}
###EOF

# === tracking.sh ===
# Track processed audiobook folders using JSON or SQLite
# Called from organize_audiobooks.sh
# Requires: CONFIG_PATH, TRACKING_MODE, TRACKING_DB_PATH
# Depends on: lib/logging.sh

DebugEcho "📦 Entering tracking.sh"

# Load default tracking DB path
function init_tracking_db() {
  DebugEcho "→ init_tracking_db called"
  case "${TRACKING_MODE}" in
    "JSON")
      TRACKING_DB_PATH="${TRACKING_DB_PATH:-${CONFIG_PATH}/tracking.json}"
      mkdir -p "$(dirname "${TRACKING_DB_PATH}")"
      [[ ! -f "${TRACKING_DB_PATH}" ]] && echo "{}" > "${TRACKING_DB_PATH}"
      DebugEcho "✅ Initialized JSON tracking DB at: ${TRACKING_DB_PATH}"
      ;;
    "SQLITE")
      TRACKING_DB_PATH="${TRACKING_DB_PATH:-${CONFIG_PATH}/tracking.sqlite}"
      mkdir -p "$(dirname "${TRACKING_DB_PATH}")"
      if [[ ! -f "${TRACKING_DB_PATH}" ]]; then
        sqlite3 "${TRACKING_DB_PATH}" "CREATE TABLE IF NOT EXISTS processed (path TEXT PRIMARY KEY, timestamp DATETIME DEFAULT CURRENT_TIMESTAMP);"
        DebugEcho "✅ Created SQLite tracking DB schema"
      fi
      DebugEcho "✅ Initialized SQLite tracking DB at: ${TRACKING_DB_PATH}"
      ;;
    "MOVE"|"NONE")
      DebugEcho "⚠️ No tracking required for mode: ${TRACKING_MODE}"
      ;;
    *)
      printf "[FATAL] Unknown TRACKING_MODE: %s\n" "${TRACKING_MODE}" >&2
      exit 1
      ;;
  esac
}

setup_tracking() {
  DebugEcho "📦 setup_tracking() called"
  init_tracking_db
}
function has_been_processed() {
  local folder="$1"
  DebugEcho "🔎 Checking if already processed: ${folder}"
  case "${TRACKING_MODE}" in
    "JSON")
      jq -e --arg f "$folder" '.[$f]?' "${TRACKING_DB_PATH}" >/dev/null 2>&1 && return 0 || return 1
      ;;
    "SQLITE")
      sqlite3 "${TRACKING_DB_PATH}" "SELECT 1 FROM processed WHERE path = '$folder' LIMIT 1;" | grep -q 1
      ;;
    "MOVE"|"NONE")
      return 1
      ;;
  esac
}

function mark_as_processed() {
  local folder="$1"
  DebugEcho "📝 Marking as processed: ${folder}"
  case "${TRACKING_MODE}" in
    "JSON")
      tmpfile=$(mktemp)
      jq --arg f "$folder" '. + {($f): (now | todate)}' "${TRACKING_DB_PATH}" > "${tmpfile}" && mv "${tmpfile}" "${TRACKING_DB_PATH}"
      ;;
    "SQLITE")
      sqlite3 "${TRACKING_DB_PATH}" "INSERT OR IGNORE INTO processed (path) VALUES ('$folder');"
      ;;
    "MOVE"|"NONE")
      # No action needed
      ;;
  esac
}

DebugEcho "✅ Finished loading tracking.sh"
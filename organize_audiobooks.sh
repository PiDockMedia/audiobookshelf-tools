#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# === Set ROOT_DIR to project root ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# === Load .env if present ===
ENV_FILE="${ROOT_DIR}/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# === Core Paths ===
INPUT_PATH="${INPUT_PATH:-${ROOT_DIR}/input}"
OUTPUT_PATH="${OUTPUT_PATH:-${ROOT_DIR}/output}"
CONFIG_PATH="${CONFIG_PATH:-${ROOT_DIR}/config}"

# === Working paths now inside INPUT_PATH ===
TRACKING_DB_PATH="${TRACKING_DB_PATH:-${INPUT_PATH}/.audiobook_tracking.db}"
AI_BUNDLE_PATH="${AI_BUNDLE_PATH:-${INPUT_PATH}/ai_bundles}"
AI_BUNDLE_PENDING="${AI_BUNDLE_PATH}/pending"

# === Optional flags ===
DRY_RUN="${DRY_RUN:-false}"
DEBUG="${DEBUG:-false}"

# === Log Level Defaults ===
LOG_LEVEL="${LOG_LEVEL:-info}"      # debug | info | warn | error
LOG_FILE="${LOG_FILE:-}"            # optional path to log file

# === Level Priorities for filtering ===
declare -A LOG_LEVELS=(
  [debug]=0
  [info]=1
  [warn]=2
  [error]=3
)

# === Internal log formatter ===
function _log_msg() {
  local level="$1"
  shift
  local color prefix timestamp

  timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
  case "$level" in
    debug) color="34"; prefix="DEBUG" ;;  # blue
    info)  color="32"; prefix="INFO"  ;;  # green
    warn)  color="33"; prefix="WARN"  ;;  # yellow
    error) color="31"; prefix="ERROR" ;;  # red
  esac

  printf "[%s] \033[0;%sm%-5s\033[0m %s\n" "$timestamp" "$color" "$prefix" "$*" | tee -a "${LOG_FILE:-/dev/null}"
}

# === Level Check ===
function _should_log() {
  local level="${1:-info}"
  local requested="${LOG_LEVELS[$level]:-${LOG_LEVELS[info]}}"
  local current="${LOG_LEVELS[${LOG_LEVEL:-info}]:-${LOG_LEVELS[info]}}"
  [[ $requested -ge $current ]]
}

# === Public Logging Interfaces ===
function DebugEcho()  { _should_log debug && _log_msg debug "$@"; }
function LogInfo()    { _should_log info  && _log_msg info  "$@"; }
function LogWarn()    { _should_log warn  && _log_msg warn  "$@"; }
function LogError()   { _should_log error && _log_msg error "$@"; }

# === Setup Logging Destination ===
function setup_logging() {
  if [[ -n "${LOG_FILE}" ]]; then
    mkdir -p "$(dirname "${LOG_FILE}")"
    : > "${LOG_FILE}"   # Truncate
  fi
  DebugEcho "📋 Logging initialized. Level: ${LOG_LEVEL} → File: ${LOG_FILE:-stdout}"
}

# === Visual Divider for Logs ===
function print_divider() {
  local width="${COLUMNS:-80}"
  printf '%*s\n' "$width" '' | tr ' ' '='
}

# === Database Initialization ===
function init_db() {
  if [[ "$DRY_RUN" == "true" ]]; then
    DebugEcho "Skipping database initialization in dry-run mode."
    return
  fi
  DebugEcho "Initializing SQLite DB at ${TRACKING_DB_PATH}"
  mkdir -p "$(dirname "${TRACKING_DB_PATH}")"
  sqlite3 "${TRACKING_DB_PATH}" "CREATE TABLE IF NOT EXISTS books (id TEXT PRIMARY KEY, path TEXT, state TEXT, updated_at TEXT);"
}

# === AI Bundle Processing ===
function scan_input_and_prepare_ai_bundles() {
  local entry="$1"
  DebugEcho "📦 scan_input_and_prepare_ai_bundles() started"

  mkdir -p "${AI_BUNDLE_PENDING}"
  AI_JSONL="${AI_BUNDLE_PENDING}/ai_input.jsonl"
  : > "$AI_JSONL"

  [[ -d "$entry" ]] || return

  id="$(echo "$(basename "$entry")" | tr ' ' '_' | tr '/' '_')"
  bundle_dir="${AI_BUNDLE_PENDING}/${id}"

  DebugEcho "📚 Adding ${id} to AI bundle"

  mkdir -p "$bundle_dir"
  tree "$entry" > "$bundle_dir/tree.txt"

  cat > "$bundle_dir/prompt.md" <<EOF
You are helping organize audiobook folders. Here's a folder tree:
(See tree.txt)

Please return JSON metadata like:
{
  "author": "Author Name",
  "title": "Book Title",
  "series": "Optional Series",
  "series_index": 1,
  "narrator": "Optional Narrator"
}
EOF

  # === Use only the folder name, not the full path
  base_name="$(basename "$entry")"
  echo "{\"id\": \"${id}\", \"path\": \"${base_name}\"}" >> "$AI_JSONL"

  DebugEcho "✅ AI bundle created at ${AI_BUNDLE_PENDING}"
}

# === CLI Argument Parsing ===
function parse_cli_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN="true" ;;
      --debug) DEBUG="true"; LOG_LEVEL="debug" ;;
      --input=*) INPUT_PATH="${1#*=}" ;;
      --output=*) OUTPUT_PATH="${1#*=}" ;;
      --ingest) INGEST_MODE="true" ;;
      --ingest-file=*) INGEST_FILE="${1#*=}" ;;
      *) LogError "Unknown option: $1"; exit 1 ;;
    esac
    shift
  done
  DebugEcho "DRY_RUN is set to: $DRY_RUN"
}

# === Main Execution ===
print_divider
DebugEcho "📚 BEGIN organize_audiobooks.sh"

parse_cli_args "$@"
setup_logging
init_db

# === Main scan loop
for entry in "$INPUT_PATH"/*; do
  name="$(basename "$entry")"

  # Skip system/working paths
  [[ "$name" == "ai_bundles" ]] && continue
  [[ "$name" == ".audiobook_tracking.db" ]] && continue

  # Process if it's a directory or a supported audio file
  if [[ -d "$entry" || "$entry" =~ \.(m4b|mp3|flac|ogg|wav)$ ]]; then
    DebugEcho "🔍 Scanning candidate: $name"
    scan_input_and_prepare_ai_bundles "$entry"
  fi
done

if [[ "${INGEST_MODE:-false}" == "true" ]]; then
  ingest_metadata_file "${INGEST_FILE:-}"
fi

DebugEcho "🏁 END organize_audiobooks.sh"

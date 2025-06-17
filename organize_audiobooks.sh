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
PAUSE="${PAUSE:-false}"

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
  DebugEcho "📦 scan_input_and_prepare_ai_bundles() started"

  mkdir -p "${AI_BUNDLE_PENDING}"
  AI_JSONL="${AI_BUNDLE_PENDING}/ai_input.jsonl"
  AI_PROMPT="${AI_BUNDLE_PENDING}/prompt.md"
  : > "$AI_JSONL"

  # Create the comprehensive prompt
  cat > "$AI_PROMPT" <<EOF
You are helping organize audiobook folders. For each book, analyze the folder structure and files to identify:

1. Author name
2. Book title
3. Series name (if part of a series)
4. Series index/order (if part of a series)
5. Narrator (if available)

Please return JSON metadata in this format:
{
  "author": "Author Name",
  "title": "Book Title",
  "series": "Optional Series",
  "series_index": 1,
  "narrator": "Optional Narrator"
}

Consider these naming patterns:
- "Author - Series # - Title"
- "Author - Title"
- "Author - Title (Dramatized)"
- Files like cover.jpg, desc.txt, notes.nfo may contain metadata
- Audio file names may indicate chapter numbers or parts

EOF

  # Process each entry
  for entry in "$INPUT_PATH"/*; do
    name="$(basename "$entry")"
    DebugEcho "Processing entry: $entry"

    # Skip system/working paths
    [[ "$name" == "ai_bundles" ]] && continue
    [[ "$name" == ".audiobook_tracking.db" ]] && continue

    # Process if it's a directory or a supported audio file
    if [[ -d "$entry" || "$entry" =~ \.(m4b|mp3|flac|ogg|wav)$ ]]; then
      DebugEcho "🔍 Scanning candidate: $name"
      
      # Generate a unique ID for the book
      id="$(echo "$name" | tr ' ' '_' | tr '/' '_')"
      
      # Add entry to JSONL file
      echo "{\"id\": \"${id}\", \"path\": \"${name}\"}" >> "$AI_JSONL"
      
      DebugEcho "📚 Added ${id} to AI bundle"
    else
      DebugEcho "Skipping unsupported file: $name"
    fi
  done

  DebugEcho "✅ AI bundle created at ${AI_BUNDLE_PENDING}"
}

# === Pause function ===
function pause() {
  if [[ "$PAUSE" == "true" ]]; then
    DebugEcho "⏸️  Pausing... Press Enter to continue..."
    read -r
  fi
}

# === CLI Argument Parsing ===
function parse_cli_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN="true" ;;
      --debug) DEBUG="true"; LOG_LEVEL="debug" ;;
      --pause) PAUSE="true" ;;
      --input=*) INPUT_PATH="${1#*=}" ;;
      --output=*) OUTPUT_PATH="${1#*=}" ;;
      --ingest) INGEST_MODE="true" ;;
      --ingest-file=*) INGEST_FILE="${1#*=}" ;;
      *) LogError "Unknown option: $1"; exit 1 ;;
    esac
    shift
  done
  DebugEcho "DRY_RUN is set to: $DRY_RUN"
  DebugEcho "PAUSE is set to: $PAUSE"
}

# === Main Execution ===
print_divider
DebugEcho "📚 BEGIN organize_audiobooks.sh"
DebugEcho "Current directory: $(pwd)"
DebugEcho "INPUT_PATH: ${INPUT_PATH}"
DebugEcho "OUTPUT_PATH: ${OUTPUT_PATH}"
DebugEcho "CONFIG_PATH: ${CONFIG_PATH}"

parse_cli_args "$@"
setup_logging

DebugEcho "Initializing database..."
init_db
pause

DebugEcho "Starting main scan loop..."
scan_input_and_prepare_ai_bundles
pause

if [[ "${INGEST_MODE:-false}" == "true" ]]; then
  DebugEcho "Starting metadata ingestion..."
  ingest_metadata_file "${INGEST_FILE:-}"
  pause
fi

DebugEcho "🏁 END organize_audiobooks.sh"

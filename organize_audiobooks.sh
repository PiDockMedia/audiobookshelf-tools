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
You are an expert audiobook metadata analyzer. Your task is to analyze each audiobook entry and determine the most accurate metadata for organizing the collection.

For each book, analyze the following sources of information in order of reliability:

1. Embedded Audio Metadata (highest priority)
   - Check audio_metadata field for:
     * author/artist
     * title
     * series name (from album or series field)
     * series index (from series_index or track field)
     * narrator
     * publisher
     * year

2. Folder Structure and Naming
   - Analyze folder_name for patterns like:
     * "Author - Series # - Title"
     * "Author - Title"
     * "Author - Title (Dramatized)"
   - Check naming_pattern field for detected pattern
   - Look for series indicators (book_number, part_number, volume_number)

3. Supporting Files
   - Check for metadata files:
     * cover.jpg/png (may contain visual metadata)
     * desc.txt/description.txt (may contain book description)
     * notes.nfo (may contain additional metadata)
   - Review description_preview if available
   - Check nfo_content if available

4. Audio File Analysis
   - Review audio_files list for chapter/part indicators
   - Check audio_formats for file types
   - Consider total_duration for book length

Please return JSON metadata in this format:
{
  "author": "Author Name",
  "title": "Book Title",
  "series": "Optional Series",
  "series_index": 1,
  "narrator": "Optional Narrator",
  "confidence": {
    "author": "high|medium|low",
    "title": "high|medium|low",
    "series": "high|medium|low",
    "series_index": "high|medium|low",
    "narrator": "high|medium|low"
  },
  "sources": {
    "author": ["embedded_metadata", "folder_name", "description"],
    "title": ["embedded_metadata", "folder_name", "description"],
    "series": ["embedded_metadata", "folder_name", "description"],
    "series_index": ["embedded_metadata", "folder_name", "description"],
    "narrator": ["embedded_metadata", "folder_name", "description"]
  }
}

Confidence levels should be based on:
- high: Multiple reliable sources agree or strong single source
- medium: Single reliable source or multiple weak sources
- low: Weak or conflicting sources

Sources should list all places where the information was found, in order of reliability.

For each field, prioritize:
1. Embedded audio metadata (most reliable)
2. Folder naming patterns
3. Supporting files (description, NFO)
4. Audio file analysis

If information is missing or conflicting, explain your reasoning in the confidence field.
EOF

  # Function to extract metadata using ffprobe
  extract_audio_metadata() {
    local file="$1"
    local metadata="{}"
    
    if command -v ffprobe &>/dev/null; then
      # Extract common metadata tags
      local tags=(
        "title"
        "artist"
        "author"
        "album"
        "album_artist"
        "composer"
        "narrator"
        "publisher"
        "date"
        "year"
        "track"
        "disc"
        "series"
        "series_index"
        "genre"
        "comment"
      )
      
      for tag in "${tags[@]}"; do
        # Try both format_tags and tags for better compatibility
        value=$(ffprobe -v error -show_entries format_tags="$tag" -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
        if [[ -z "$value" ]]; then
          value=$(ffprobe -v error -show_entries tags="$tag" -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
        fi
        if [[ -n "$value" ]]; then
          metadata=$(echo "$metadata" | jq --arg k "$tag" --arg v "$value" '. + {($k): $v}')
        fi
      done
    fi
    
    echo "$metadata"
  }

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
      
      # Initialize metadata object
      declare -A metadata=(
        ["id"]="$id"
        ["path"]="$name"
        ["folder_name"]="$name"
        ["audio_files"]="[]"
        ["metadata_files"]="[]"
        ["file_count"]="0"
        ["has_cover"]="false"
        ["has_description"]="false"
        ["has_nfo"]="false"
        ["has_metadata"]="false"
        ["audio_formats"]="[]"
        ["total_duration"]="0"
        ["file_sizes"]="{}"
        ["naming_pattern"]="unknown"
        ["audio_metadata"]="{}"
      )

      # If it's a directory, scan its contents
      if [[ -d "$entry" ]]; then
        # Initialize arrays for audio and metadata files
        audio_files=()
        metadata_files=()
        audio_formats=()
        declare -A file_sizes=()
        total_duration=0
        all_audio_metadata="{}"

        # Scan directory contents
        while IFS= read -r file; do
          filename="$(basename "$file")"
          
          # Check for metadata files
          case "$filename" in
            cover.jpg|cover.png|cover.jpeg)
              metadata["has_cover"]="true"
              metadata_files+=("$filename")
              ;;
            desc.txt|description.txt|info.txt)
              metadata["has_description"]="true"
              metadata_files+=("$filename")
              # Read first few lines of description
              if [[ -f "$file" ]]; then
                metadata["description_preview"]="$(head -n 3 "$file" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
              fi
              ;;
            *.nfo)
              metadata["has_nfo"]="true"
              metadata_files+=("$filename")
              # Read NFO content
              if [[ -f "$file" ]]; then
                metadata["nfo_content"]="$(cat "$file" | tr '\n' ' ' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
              fi
              ;;
          esac

          # Check for audio files
          if [[ "$file" =~ \.(m4b|mp3|flac|ogg|wav)$ ]]; then
            audio_files+=("$filename")
            format="${file##*.}"
            audio_formats+=("$format")
            
            # Get file size
            if [[ -f "$file" ]]; then
              size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null)
              file_sizes["$filename"]="$size"
              
              # Try to get duration using ffprobe if available
              if command -v ffprobe &>/dev/null; then
                duration=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file" 2>/dev/null)
                if [[ -n "$duration" ]]; then
                  total_duration=$(echo "$total_duration + $duration" | bc)
                fi
                
                # Extract audio metadata
                file_metadata=$(extract_audio_metadata "$file")
                if [[ "$file_metadata" != "{}" ]]; then
                  metadata["has_metadata"]="true"
                  # Merge metadata, preferring non-empty values
                  all_audio_metadata=$(echo "$all_audio_metadata" "$file_metadata" | jq -s '.[0] * .[1]')
                fi
              fi
            fi
          fi
        done < <(find "$entry" -type f)

        # Update metadata with collected information
        metadata["file_count"]="${#audio_files[@]}"
        metadata["audio_files"]="$(printf '%s\n' "${audio_files[@]}" | jq -R . | jq -s .)"
        metadata["metadata_files"]="$(printf '%s\n' "${metadata_files[@]}" | jq -R . | jq -s .)"
        metadata["audio_formats"]="$(printf '%s\n' "${audio_formats[@]}" | jq -R . | jq -s .)"
        metadata["total_duration"]="$total_duration"
        metadata["file_sizes"]="$(printf '%s\n' "${!file_sizes[@]}" | jq -R . | jq -s .)"
        metadata["audio_metadata"]="$all_audio_metadata"

        # Analyze naming pattern
        if [[ "$name" =~ ^[^-]+-[^-]+-[^-]+$ ]]; then
          metadata["naming_pattern"]="author-series-title"
        elif [[ "$name" =~ ^[^-]+-[^-]+$ ]]; then
          metadata["naming_pattern"]="author-title"
        elif [[ "$name" =~ \(Dramatized\)$ ]]; then
          metadata["naming_pattern"]="author-title-dramatized"
        fi

        # Check for series indicators
        if [[ "$name" =~ [Bb]ook[[:space:]]*[0-9]+ ]]; then
          metadata["series_indicator"]="book_number"
        elif [[ "$name" =~ [Pp]art[[:space:]]*[0-9]+ ]]; then
          metadata["series_indicator"]="part_number"
        elif [[ "$name" =~ [Vv]olume[[:space:]]*[0-9]+ ]]; then
          metadata["series_indicator"]="volume_number"
        fi
      fi

      # Convert metadata to JSON and add to JSONL file
      json="{}"
      for key in "${!metadata[@]}"; do
        value="${metadata[$key]}"
        # Handle arrays and objects specially
        if [[ "$value" == "["* ]] || [[ "$value" == "{"* ]]; then
          json="$(echo "$json" | jq --arg k "$key" --argjson v "$value" '. + {($k): $v}')"
        else
          json="$(echo "$json" | jq --arg k "$key" --arg v "$value" '. + {($k): $v}')"
        fi
      done
      echo "$json" >> "$AI_JSONL"
      
      DebugEcho "📚 Added ${id} to AI bundle with enhanced metadata"
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

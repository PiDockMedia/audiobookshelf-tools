#!/usr/bin/env bash

# === Bash Version Check ===
# Ensure we have bash 4.0+ for associative array support
if [[ "${BASH_VERSINFO[0]}" -lt 4 ]]; then
    echo "ERROR: This script requires bash 4.0 or higher (associative arrays support)"
    echo "Current bash version: $BASH_VERSION"
    echo "Current bash path: $(which bash)"
    echo ""
    echo "The script is running with the system bash instead of Homebrew bash."
    echo "To fix this, either:"
    echo "1. Run the script with: /opt/homebrew/bin/bash organize_audiobooks.sh [options]"
    echo "2. Or update your shell configuration to prioritize Homebrew bash"
    echo "3. Or add /opt/homebrew/bin to the beginning of your PATH"
    echo ""
    echo "Homebrew bash version: $(/opt/homebrew/bin/bash --version | head -1)"
    exit 1
fi

#
# === AI Audiobook Organizer: Full Dataflow & Tracking Logic ===
#
# 1. Book Arrival & Initial Acceptance
#    - When a new book folder or file appears in the INPUT_PATH, it is detected by the script.
#    - The script adds an entry for the book in the tracking database (SQLite or JSON), marking its status as 'accepted'.
#
# 2. Ready for AI Scan
#    - The script extracts all available metadata (embedded, folder, supporting files) and creates a JSONL entry for the book.
#    - The book's status in the DB is updated to 'ready_for_ai'.
#
# 3. AI Scan Returned
#    - When an AI response is available (either simulated or real), the script updates the DB entry to 'ai_returned'.
#    - If the AI cannot determine metadata, the status is set to 'ai_failed', and the book is flagged for manual intervention.
#
# 4. Organization
#    - For books with 'ai_returned' status, the script organizes (copies) them to the OUTPUT_PATH using the AI metadata.
#    - The DB entry is updated to 'organized'.
#
# 5. Book Disappearance
#    - If a book is removed from INPUT_PATH (external to this script), the script detects its absence and removes its entry from the DB.
#
# 6. DB Persistence
#    - The tracking DB lives in the INPUT_PATH and persists across runs, except during test runs with --clean, which removes the input folder and DB.
#
# 7. Test Mode
#    - In test mode, the DB is destroyed with the input folder on --clean.
#
# 7. Manual Intervention Handling
#    - Failed AI entries are moved to manual_intervention.jsonl for manual review and improvement.
#    - Improved entries are resubmitted for AI analysis.
#    - **CRITICAL: All command-line switches must be preserved and functional:**
#      * --pause: Add pause points for manual intervention and debugging
#      * --dry-run: Show what would be done without making changes  
#      * --debug: Enable detailed logging
#      * --input/--output: Specify input and output directories
#
# === End Dataflow & Tracking Logic ===
# Temporarily disable set -e for more resilient error handling
set -uo pipefail
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
declare -A LOG_LEVELS
LOG_LEVELS[debug]=0
LOG_LEVELS[info]=1
LOG_LEVELS[warn]=2
LOG_LEVELS[error]=3

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
  local requested
  local current
  if [[ -n "${LOG_LEVELS[$level]+set}" ]]; then
    requested="${LOG_LEVELS[$level]}"
  else
    requested="${LOG_LEVELS[info]}"
  fi
  if [[ -n "${LOG_LEVELS[${LOG_LEVEL:-info}]+set}" ]]; then
    current="${LOG_LEVELS[${LOG_LEVEL:-info}]}"
  else
    current="${LOG_LEVELS[info]}"
  fi
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

# === Helper Functions ===

# Function to safely get array value (prevents unbound variable errors)
safe_array_get() {
  local array_name="$1"
  local key="$2"
  local -n arr="$array_name"
  if [[ -n "${arr[$key]:-}" ]]; then
    echo "${arr[$key]}"
  else
    echo ""
  fi
}

# Function to check if a directory contains audio files
has_audio_files() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    return 1
  fi
  
  # Check for common audio file extensions
  if find "$dir" -maxdepth 1 -type f \( -iname "*.m4b" -o -iname "*.m4a" -o -iname "*.mp3" -o -iname "*.flac" -o -iname "*.wav" -o -iname "*.ogg" -o -iname "*.aac" \) | head -1 | grep -q .; then
    return 0  # Found audio files
  else
    return 1  # No audio files found
  fi
}

# Function to extract metadata from folder name
extract_metadata_from_folder() {
  local dir="$1"
  local -n metadata_ref="$2"
  local folder_name=$(basename "$dir")
  
  # Extract author from parent directory name (e.g., "Austen, Jane")
  local parent_dir=$(dirname "$dir")
  local author_name=$(basename "$parent_dir")
  if [[ "$author_name" =~ ^([^,]+),\s*([^,]+)$ ]]; then
    metadata_ref["author"]="$author_name"
  elif [[ -n "$author_name" ]]; then
    metadata_ref["author"]="$author_name"
  fi
  
  # Extract year from folder name (e.g., "1813 - Pride and Prejudice")
  if [[ "$folder_name" =~ ([0-9]{4})\ -\ (.+) ]]; then
    metadata_ref["year"]="${BASH_REMATCH[1]}"
    metadata_ref["title"]="${BASH_REMATCH[2]}"
  fi
  
  # Extract narrator from braces (e.g., "Pride and Prejudice {Elizabeth Klett}")
  if [[ "$folder_name" =~ (.+)\ \{([^}]+)\}$ ]]; then
    metadata_ref["title"]="${BASH_REMATCH[1]}"
    metadata_ref["narrator"]="${BASH_REMATCH[2]}"
  fi
}

# Function to extract metadata from supporting files
extract_metadata_from_files() {
  local dir="$1"
  local -n metadata_ref="$2"
  
  # Check for description file
  if [[ -f "$dir/description.txt" ]]; then
    metadata_ref["description"]=$(cat "$dir/description.txt")
  fi
  
  # Check for NFO file
  if [[ -f "$dir/info.nfo" ]]; then
    metadata_ref["nfo"]=$(cat "$dir/info.nfo")
  fi
  
  # Check for cover image
  if [[ -f "$dir/cover.jpg" ]] || [[ -f "$dir/cover.png" ]]; then
    metadata_ref["has_cover"]="true"
  fi
}

# Function to extract metadata from embedded audio files
extract_metadata_from_embedded() {
  local dir="$1"
  local -n metadata_ref="$2"
  
  # Find first audio file and extract metadata
  local audio_file=$(find "$dir" -maxdepth 1 -type f \( -iname "*.m4b" -o -iname "*.m4a" -o -iname "*.mp3" -o -iname "*.flac" \) | head -1)
  
  if [[ -n "$audio_file" ]]; then
    local embedded_metadata=$(extract_audio_metadata "$audio_file")
    
    # Extract common fields from embedded metadata
    if [[ -n "$embedded_metadata" ]]; then
      local title=$(echo "$embedded_metadata" | jq -r '.title // empty')
      local author=$(echo "$embedded_metadata" | jq -r '.author // empty')
      local narrator=$(echo "$embedded_metadata" | jq -r '.narrator // empty')
      local year=$(echo "$embedded_metadata" | jq -r '.year // empty')
      local publisher=$(echo "$embedded_metadata" | jq -r '.publisher // empty')
      local genre=$(echo "$embedded_metadata" | jq -r '.genre // empty')
      
      [[ -n "$title" ]] && metadata_ref["embedded_title"]="$title"
      [[ -n "$author" ]] && metadata_ref["embedded_author"]="$author"
      [[ -n "$narrator" ]] && metadata_ref["embedded_narrator"]="$narrator"
      [[ -n "$year" ]] && metadata_ref["embedded_year"]="$year"
      [[ -n "$publisher" ]] && metadata_ref["embedded_publisher"]="$publisher"
      [[ -n "$genre" ]] && metadata_ref["embedded_genre"]="$genre"
    fi
  fi
}

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
      # Always initialize value to prevent unbound variable errors with "set -u"
      local value=""
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
  "year": 1813,
  "confidence": {
    "author": "high|medium|low",
    "title": "high|medium|low",
    "series": "high|medium|low",
    "series_index": "high|medium|low",
    "narrator": "high|medium|low",
    "year": "high|medium|low"
  },
  "sources": {
    "author": ["embedded_metadata", "folder_name", "description"],
    "title": ["embedded_metadata", "folder_name", "description"],
    "series": ["embedded_metadata", "folder_name", "description"],
    "series_index": ["embedded_metadata", "folder_name", "description"],
    "narrator": ["embedded_metadata", "folder_name", "description"],
    "year": ["embedded_metadata", "folder_name", "description"]
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

  # Use find to recursively get all directories under INPUT_PATH
  while IFS= read -r -d '' entry; do
    # Skip the input directory itself and ai_bundles directory
    if [[ "$entry" == "$INPUT_PATH" ]] || [[ "$entry" == *"/ai_bundles"* ]]; then
      continue
    fi
    
    # Check if this directory contains audio files OR is a multi-disc book folder
    local is_audio_folder=false
    local is_multi_disc_folder=false
    
    if [[ -d "$entry" ]]; then
      if has_audio_files "$entry"; then
        is_audio_folder=true
      else
        # Check if this is a multi-disc book folder (contains disc subfolders)
        while IFS= read -r -d '' subdir; do
          if [[ "$subdir" != "$entry" ]]; then
            local subdir_name=$(basename "$subdir")
            if [[ "$subdir_name" =~ ^(Disc|CD|Part|Volume)\ [0-9]+$ ]] || [[ "$subdir_name" =~ ^[0-9]+$ ]]; then
              if has_audio_files "$subdir"; then
                is_multi_disc_folder=true
                break
              fi
            fi
          fi
        done < <(find "$entry" -maxdepth 1 -type d -print0)
      fi
    fi
    
    if $is_audio_folder || $is_multi_disc_folder; then
      # Skip disc folders - let AI handle multi-disc books from parent folder
      local dir_name=$(basename "$entry")
      if [[ "$dir_name" =~ ^(Disc|CD|Part|Volume)\ [0-9]+$ ]] || [[ "$dir_name" =~ ^[0-9]+$ ]]; then
        DebugEcho "Skipping disc folder: $entry (AI will handle from parent)"
        continue
      fi
      
      local id=$(basename "$entry")
      if $is_multi_disc_folder; then
        DebugEcho "📚 Processing multi-disc book directory: $entry"
      else
        DebugEcho "📚 Processing audiobook directory: $entry"
      fi
      
      # Initialize metadata array
      declare -A metadata
      
      # Extract basic metadata from various sources (light touch)
      extract_metadata_from_folder "$entry" metadata
      extract_metadata_from_files "$entry" metadata
      extract_metadata_from_embedded "$entry" metadata
      
      # Add input_path as the full relative path from INPUT_PATH to the book's folder
      local rel_path="$(realpath --relative-to="$INPUT_PATH" "$entry" 2>/dev/null || python3 -c "import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))" "$entry" "$INPUT_PATH")"
      metadata["input_path"]="$rel_path"

      # Convert metadata to JSON and add to JSONL file
      local json="{}"
      
      # Add input_path
      json="$(echo "$json" | jq --arg path "${metadata[input_path]}" '. + {input_path: $path}')"
      
      # Add title as nested object
      if [[ -n "${metadata[title]}" ]]; then
        json="$(echo "$json" | jq --arg title "${metadata[title]}" '. + {title: {main: $title}}')"
      fi
      
      # Add author as nested object (split if possible)
      if [[ -n "${metadata[author]}" ]]; then
        local author="${metadata[author]}"
        if [[ $author =~ ^([^,]+),\s*([^,]+)$ ]]; then
          local last_name="${BASH_REMATCH[1]}"
          local first_name="${BASH_REMATCH[2]}"
          json="$(echo "$json" | jq --arg last "$last_name" --arg first "$first_name" '. + {author: {last: $last, first: $first}}')"
        else
          # Try to split on spaces and assume last word is last name
          local last_name=$(echo "$author" | rev | cut -d' ' -f1 | rev)
          local first_name=$(echo "$author" | sed "s/$last_name$//" | sed 's/ $//')
          json="$(echo "$json" | jq --arg last "$last_name" --arg first "$first_name" '. + {author: {last: $last, first: $first}}')"
        fi
      fi
      
      # Add other fields
      if [[ -n "${metadata[narrator]}" ]]; then
        json="$(echo "$json" | jq --arg narrator "${metadata[narrator]}" '. + {narrator: $narrator}')"
      fi
      
      if [[ -n "${metadata[year]}" ]]; then
        json="$(echo "$json" | jq --arg year "${metadata[year]}" '. + {year: $year}')"
      fi
      
      # Use embedded fields if available, fall back to regular fields
      local publisher=""
      publisher=$(safe_array_get metadata embedded_publisher)
      if [[ -z "$publisher" ]]; then
        publisher=$(safe_array_get metadata publisher)
      fi
      if [[ -n "$publisher" ]]; then
        json="$(echo "$json" | jq --arg publisher "$publisher" '. + {publisher: $publisher}')"
      fi
      
      local genre=""
      genre=$(safe_array_get metadata embedded_genre)
      if [[ -z "$genre" ]]; then
        genre=$(safe_array_get metadata genre)
      fi
      if [[ -n "$genre" ]]; then
        json="$(echo "$json" | jq --arg genre "$genre" '. + {genre: $genre}')"
      fi
      
      # Add series info if available
      local series=""
      series=$(safe_array_get metadata series)
      if [[ -n "$series" ]]; then
        json="$(echo "$json" | jq --arg series "$series" '. + {series: {name: $series}}')"
        local series_index=""
        series_index=$(safe_array_get metadata series_index)
        if [[ -n "$series_index" ]]; then
          json="$(echo "$json" | jq --arg index "$series_index" '.series.index = $index')"
        fi
      else
        json="$(echo "$json" | jq '. + {series: null}')"
      fi
      
      # Write as single-line JSONL (compact, not pretty-printed)
      echo "$json" | jq -c . >> "$AI_JSONL"
      
      DebugEcho "📚 Added ${id} to AI bundle with enhanced metadata and input_path: $rel_path"

      # After determining rel_path for each book:
      local book_id="$(echo "$rel_path" | md5sum | awk '{print $1}')"
      local current_state="$(db_get_state "$book_id")"
      if [[ -z "$current_state" ]]; then
        db_set_state "$book_id" "$rel_path" "accepted"
      fi
      # When adding to AI input bundle:
      db_set_state "$book_id" "$rel_path" "ready_for_ai"
    else
      DebugEcho "Skipping unsupported file: $entry"
    fi
  done < <(find "$INPUT_PATH" -type d -print0)

  DebugEcho "✅ AI bundle created at ${AI_BUNDLE_PENDING}"
}

# === Pause function ===
function pause() {
    if [ "$PAUSE" = true ]; then
        local msg="$1"
        if [ -z "$msg" ]; then
            msg="Pausing for inspection. Press Enter to continue..."
        fi
        LogInfo "⏸️  PAUSE: $msg"
        read -p ""
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

# === Logging Functions ===
log_info() {
    echo "[INFO] $1"
}
log_error() {
    echo "[ERROR] $1" >&2
}
log_debug() {
    if [ "$LOG_LEVEL" = "debug" ]; then
        echo "[DEBUG] $1"
    fi
}
log_warn() {
    echo "[WARN] $1"
}

# === Organization Functions ===

# Function to format author name in "Last, First" format
format_author_name() {
    local author="$1"
    if [[ $author =~ ^([^,]+),\s*([^,]+)$ ]]; then
        echo "$author"  # Already in "Last, First" format
    else
        # Try to split on spaces and assume last word is last name
        local last_name=$(echo "$author" | rev | cut -d' ' -f1 | rev)
        local first_name=$(echo "$author" | sed "s/$last_name$//" | sed 's/ $//')
        echo "$last_name, $first_name"
    fi
}

# Function to create folder name based on metadata and detail level
create_folder_name() {
    local metadata="$1"
    local detail_level="${AUDIOBOOKSHELF_NAME_DETAIL:-standard}"
    
    # Extract metadata fields
    local year=$(echo "$metadata" | jq -r '.year.value // empty')
    local title=$(echo "$metadata" | jq -r '.title.main // empty')
    local subtitle=$(echo "$metadata" | jq -r '.title.subtitle // empty')
    local narrator=$(echo "$metadata" | jq -r '.narrator.value // empty')
    local series=$(echo "$metadata" | jq -r '.series.name // empty')
    local series_index=$(echo "$metadata" | jq -r '.series.index // empty')
    
    # Build folder name based on detail level
    local folder_name=""
    
    if [ -n "$series" ] && [ -n "$series_index" ]; then
        # Series book
        folder_name="Book $series_index"
        if [ "$detail_level" != "minimal" ]; then
            if [ -n "$year" ]; then
                folder_name="$folder_name - $year"
            fi
            folder_name="$folder_name - $title"
            if [ -n "$subtitle" ]; then
                folder_name="$folder_name - $subtitle"
            fi
            if [ -n "$narrator" ] && [ "$detail_level" = "full" ]; then
                folder_name="$folder_name {$narrator}"
            fi
        else
            folder_name="$folder_name - $title"
        fi
    else
        # Standalone book
        if [ "$detail_level" != "minimal" ]; then
            if [ -n "$year" ]; then
                folder_name="$year - "
            fi
            folder_name="${folder_name}$title"
            if [ -n "$subtitle" ]; then
                folder_name="$folder_name - $subtitle"
            fi
            if [ -n "$narrator" ] && [ "$detail_level" = "full" ]; then
                folder_name="$folder_name {$narrator}"
            fi
        else
            folder_name="$title"
        fi
    fi
    
    echo "$folder_name"
}

# Function to process AI response and organize files
process_ai_response_and_organize() {
    local ai_response_file="$1"
    local source_path="$2"
    local output_path="$3"
    
    # Check if AI response exists
    if [ ! -f "$ai_response_file" ]; then
        log_debug "No AI response found at $ai_response_file"
        return 1
    fi
    
    # Read and validate AI response
    local metadata=$(cat "$ai_response_file")
    if ! echo "$metadata" | jq . >/dev/null 2>&1; then
        log_error "Invalid JSON in AI response: $ai_response_file"
        return 1
    fi
    
    # Robustly validate required fields
    local author_type=$(echo "$metadata" | jq -r 'if (.author | type) == "object" then "object" else empty end')
    local author_last_type=$(echo "$metadata" | jq -r 'if (.author.last | type) == "string" then "string" else empty end')
    local author_first_type=$(echo "$metadata" | jq -r 'if (.author.first | type) == "string" then "string" else empty end')
    local title_type=$(echo "$metadata" | jq -r 'if (.title | type) == "object" then "object" else empty end')
    local title_main_type=$(echo "$metadata" | jq -r 'if (.title.main | type) == "string" then "string" else empty end')
    
    if [ "$author_type" != "object" ] || [ "$author_last_type" != "string" ] || [ "$author_first_type" != "string" ] || [ "$title_type" != "object" ] || [ "$title_main_type" != "string" ]; then
        log_error "Missing or invalid required fields (author/title) in AI response: $ai_response_file"
        return 1
    fi
    
    # Extract required fields
    local author=$(echo "$metadata" | jq -r '.author.last + ", " + .author.first')
    local title=$(echo "$metadata" | jq -r '.title.main')
    
    # Validate required fields (redundant, but extra safe)
    if [ -z "$author" ] || [ "$author" = "null" ] || [ -z "$title" ] || [ "$title" = "null" ]; then
        log_error "Missing required fields (author/title) in AI response: $ai_response_file"
        return 1
    fi
    
    # Format author name
    author=$(format_author_name "$author")
    
    # Create folder name
    local folder_name=$(create_folder_name "$metadata")
    
    # Create output directory structure
    local author_dir="$output_path/$author"
    local book_dir="$author_dir/$folder_name"
    
    # Handle series books
    local series=$(echo "$metadata" | jq -r '.series.name // empty')
    if [ -n "$series" ] && [ "$series" != "null" ]; then
        book_dir="$author_dir/$series/$folder_name"
    fi
    
    # Create directories
    mkdir -p "$book_dir"
    
    # Copy all files from source to destination
    log_debug "Copying files from $source_path to $book_dir"
    cp -R "$source_path"/* "$book_dir/"
    
    # Save metadata
    echo "$metadata" > "$book_dir/metadata.json"
    
    log_debug "Successfully organized book: $author - $folder_name"
    return 0
}

# Function to process all AI responses
process_all_ai_responses() {
    local input_path="$1"
    local output_path="$2"
    local ai_bundles_dir="$input_path/ai_bundles"
    local processed_count=0
    local error_count=0
    local found_any_responses=false
    local manual_intervention_count=0
    
    # Process AI response JSONL file if it exists
    local ai_response_jsonl="$ai_bundles_dir/pending/ai_response.jsonl"
    if [ -f "$ai_response_jsonl" ]; then
        found_any_responses=true
        log_debug "Processing AI response file: $ai_response_jsonl"
        
        # Create manual intervention file if it doesn't exist
        local manual_jsonl="$ai_bundles_dir/pending/manual_intervention.jsonl"
        touch "$manual_jsonl"
        
        while IFS= read -r line; do
            # Skip empty lines
            if [ -z "$line" ]; then
                continue
            fi
            
            # Check if this is a failed AI response that should go to manual intervention
            local status=$(echo "$line" | jq -r '.status // "ai_returned"')
            if [ "$status" = "ai_failed" ]; then
                log_debug "Moving failed AI response to manual intervention: $input_path_val"
                echo "$line" >> "$manual_jsonl"
                db_set_state "$book_id" "$input_path_val" "ai_failed"
                ((manual_intervention_count++))
                continue
            fi
            
            # Check confidence levels for critical fields
            local author_confidence=$(echo "$line" | jq -r '.confidence.author // "high"')
            local title_confidence=$(echo "$line" | jq -r '.confidence.title // "high"')
            local series_confidence=$(echo "$line" | jq -r '.confidence.series // "high"')
            local series_index_confidence=$(echo "$line" | jq -r '.confidence.series_index // "high"')
            
            # If any critical field has low confidence, move to manual intervention
            if [ "$author_confidence" = "low" ] || [ "$title_confidence" = "low" ] || [ "$series_confidence" = "low" ] || [ "$series_index_confidence" = "low" ]; then
                log_debug "Moving low-confidence response to manual intervention: $input_path_val"
                echo "$line" | jq '. + {status: "ai_failed"}' >> "$manual_jsonl"
                db_set_state "$book_id" "$input_path_val" "ai_failed"
                ((manual_intervention_count++))
                continue
            fi
            
            # Create temporary response file for processing
            local temp_response=$(mktemp)
            echo "$line" > "$temp_response"
            
            # Extract source directory from input_path in JSON
            local source_dir=$(echo "$line" | jq -r '.input_path')
            local full_source_dir="$input_path/$source_dir"
            if [ -d "$full_source_dir" ]; then
                if process_ai_response_and_organize "$temp_response" "$full_source_dir" "$output_path"; then
                    db_set_state "$book_id" "$input_path_val" "organized"
                    ((processed_count++))
                else
                    db_set_state "$book_id" "$input_path_val" "ai_returned"
                    ((error_count++))
                fi
            else
                log_error "Source directory not found: $full_source_dir"
                ((error_count++))
            fi
            
            # Clean up temporary file
            rm -f "$temp_response"
        done < "$ai_response_jsonl"
    fi
    
    # Process individual JSON files if they exist (legacy support)
    while IFS= read -r -d '' response_file; do
        found_any_responses=true
        # Get corresponding source directory
        local book_id=$(basename "$(dirname "$response_file")")
        local source_dir="$input_path/$book_id"
        
        if [ -d "$source_dir" ]; then
            if process_ai_response_and_organize "$response_file" "$source_dir" "$output_path"; then
                ((processed_count++))
            else
                ((error_count++))
            fi
        else
            log_error "Source directory not found for book ID: $book_id"
            ((error_count++))
        fi
    done < <(find "$ai_bundles_dir" -name "ai_response.json" -print0)
    
    if [ "$found_any_responses" = false ]; then
        log_info "No AI response files found - skipping organization step"
        return 0
    fi
    
    log_info "Processed $processed_count books successfully"
    if [ $manual_intervention_count -gt 0 ]; then
        log_info "Moved $manual_intervention_count books to manual intervention for review"
    fi
    if [ $error_count -gt 0 ]; then
        log_warn "Encountered $error_count errors during processing"
    fi
    
    return $error_count
}

# === Manual Intervention Handling ===
# Move failed AI entries to manual_intervention.jsonl and resubmit improved entries
handle_manual_intervention() {
  local ai_bundles_dir="$INPUT_PATH/ai_bundles/pending"
  local ai_response_jsonl="$ai_bundles_dir/ai_response.jsonl"
  local manual_jsonl="$ai_bundles_dir/manual_intervention.jsonl"
  local tmp_jsonl

  # Only process if the AI response file exists
  if [ ! -f "$ai_response_jsonl" ]; then
    log_debug "No AI response file found for manual intervention processing"
    return 0
  fi

  # Ensure manual_intervention.jsonl exists
  touch "$manual_jsonl"

  # 1. Move failed entries from AI response JSONL to manual_intervention.jsonl
  tmp_jsonl=$(mktemp)
  : > "$tmp_jsonl"
  while IFS= read -r line; do
    # Skip empty lines
    if [ -z "$line" ]; then
      continue
    fi
    # Only process lines that have the expected status field
    local input_path_val=$(echo "$line" | jq -r '.input_path')
    local book_id=$(echo "$input_path_val" | md5sum | awk '{print $1}')
    if echo "$line" | jq -e '.status == "ai_failed"' >/dev/null 2>&1; then
      echo "$line" >> "$manual_jsonl"
      db_set_state "$book_id" "$input_path_val" "ai_failed"
    else
      echo "$line" >> "$tmp_jsonl"
    fi
  done < "$ai_response_jsonl"
  mv "$tmp_jsonl" "$ai_response_jsonl"

  # 2. Move improved entries (manual_status == "ready") back to AI-ready JSONL
  if [ -s "$manual_jsonl" ]; then
    tmp_jsonl=$(mktemp)
    : > "$tmp_jsonl"
    while IFS= read -r line; do
      # Skip empty lines
      if [ -z "$line" ]; then
        continue
      fi
      # Only process lines that have the expected manual_status field
      local input_path_val=$(echo "$line" | jq -r '.input_path')
      local book_id=$(echo "$input_path_val" | md5sum | awk '{print $1}')
      if echo "$line" | jq -e '.manual_status == "ready"' >/dev/null 2>&1; then
        echo "$line" | jq 'del(.manual_status) | . + {status: "ai_returned"}' >> "$ai_response_jsonl"
        db_set_state "$book_id" "$input_path_val" "ready_for_ai"
      else
        echo "$line" >> "$tmp_jsonl"
      fi
    done < "$manual_jsonl"
    mv "$tmp_jsonl" "$manual_jsonl"
  fi
}

# === Database State Tracking Functions ===
# Insert or update a book's state in the DB
function db_set_state() {
  local id="$1"
  local path="$2"
  local state="$3"
  local now
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  sqlite3 "$TRACKING_DB_PATH" "INSERT INTO books (id, path, state, updated_at) VALUES ('$id', '$path', '$state', '$now') ON CONFLICT(id) DO UPDATE SET state=excluded.state, updated_at=excluded.updated_at;"
}
# Get a book's state from the DB
function db_get_state() {
  local id="$1"
  sqlite3 "$TRACKING_DB_PATH" "SELECT state FROM books WHERE id='$id';"
}
# Remove a book from the DB
function db_remove_book() {
  local id="$1"
  sqlite3 "$TRACKING_DB_PATH" "DELETE FROM books WHERE id='$id';"
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
pause "After database initialization. Inspect DB if needed."

DebugEcho "Starting main scan loop..."
DebugEcho "⏸️  PAUSE: About to scan input directory and create AI input bundle..."
pause "Before scanning input. Inspect input folder if needed."
scan_input_and_prepare_ai_bundles
DebugEcho "⏸️  PAUSE: AI input bundle created. Ready for AI processing..."
pause "After creating AI input bundle. Inspect ai_input.jsonl and prompt.md if needed."

if [[ "${INGEST_MODE:-false}" == "true" ]]; then
  DebugEcho "Starting metadata ingestion..."
  ingest_metadata_file "${INGEST_FILE:-}"
  pause  # Pause after metadata ingestion
fi

# Call handle_manual_intervention at the start of main execution
DebugEcho "⏸️  PAUSE: About to process manual intervention entries..."
pause "Before manual intervention processing. Inspect manual_intervention.jsonl if needed."
handle_manual_intervention
DebugEcho "⏸️  PAUSE: Manual intervention processing complete..."
pause "After manual intervention processing. Inspect manual_intervention.jsonl if needed."

if [ "$DRY_RUN" = false ]; then
    # Process AI responses and organize files
    DebugEcho "⏸️  PAUSE: About to process AI responses and organize files..."
    pause "Before processing AI responses and organizing files. Inspect ai_response.jsonl if needed."
    log_info "Processing AI responses and organizing files..."
    process_all_ai_responses "$INPUT_PATH" "$OUTPUT_PATH"
    DebugEcho "⏸️  PAUSE: File organization complete..."
    pause "After organization step. Inspect output folder and logs if needed."
    log_info "File organization completed successfully"
fi

DebugEcho "🏁 END organize_audiobooks.sh"
exit 0

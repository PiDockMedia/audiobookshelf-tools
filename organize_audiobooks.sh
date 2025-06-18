#!/usr/bin/env bash
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
# === End Dataflow & Tracking Logic ===
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
    
    # Extract required fields
    local author=$(echo "$metadata" | jq -r '.author.last + ", " + .author.first')
    local title=$(echo "$metadata" | jq -r '.title.main')
    
    # Validate required fields
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
    
    # Process JSONL file if it exists
    local jsonl_file="$ai_bundles_dir/pending/ai_input.jsonl"
    if [ -f "$jsonl_file" ]; then
        log_debug "Processing JSONL file: $jsonl_file"
        while IFS= read -r line; do
            # Create temporary response file
            local temp_response=$(mktemp)
            echo "$line" > "$temp_response"
            
            # Extract source directory from input_path in JSON
            local source_dir=$(echo "$line" | jq -r '.input_path')
            if [ -d "$source_dir" ]; then
                if process_ai_response_and_organize "$temp_response" "$source_dir" "$output_path"; then
                    ((processed_count++))
                else
                    ((error_count++))
                fi
            else
                log_error "Source directory not found: $source_dir"
                ((error_count++))
            fi
            
            # Clean up temporary file
            rm -f "$temp_response"
        done < "$jsonl_file"
    fi
    
    # Process individual JSON files if they exist
    while IFS= read -r -d '' response_file; do
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
    
    log_info "Processed $processed_count books successfully"
    if [ $error_count -gt 0 ]; then
        log_warn "Encountered $error_count errors during processing"
    fi
    
    return $error_count
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

if [ "$DRY_RUN" = false ]; then
    # Process AI responses and organize files
    log_info "Processing AI responses and organizing files..."
    if ! process_all_ai_responses "$INPUT_PATH" "$OUTPUT_PATH"; then
        log_error "Errors occurred during file organization"
        exit 1
    fi
    log_info "File organization completed successfully"
fi

DebugEcho "🏁 END organize_audiobooks.sh"

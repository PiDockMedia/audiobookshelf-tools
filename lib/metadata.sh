#!/usr/bin/env bash
# lib/metadata.sh - Extracts basic metadata from folder names and sidecar files
DebugEcho "📥 BEGIN loading metadata.sh"

[[ -n "${_METADATA_SH_LOADED:-}" ]] && return
readonly _METADATA_SH_LOADED=1

source "${LIB_DIR}/logging.sh"

# === Extract metadata from folder name ===
# Pattern: Author - Book Title
extract_from_folder_name() {
  local folder_name="$1"
  local author=""
  local title=""

  if [[ "${folder_name}" =~ ^(.+?)\s+-\s+(.+)$ ]]; then
    author="${BASH_REMATCH[1]}"
    title="${BASH_REMATCH[2]}"
  else
    title="${folder_name}"
  fi

  echo "{{\"author\": \"${author}\", \"title\": \"${title}\"}}"
}

# === Extract from metadata.json if exists ===
extract_from_metadata_json() {
  local folder="$1"
  local file="${folder}/metadata.json"
  [[ ! -f "${file}" ]] && return 1

  jq '{{author, title, series, series_index, narrator}}' "${file}" 2>/dev/null || return 1
}

# === Extract from sidecar text files ===
extract_from_sidecar_texts() {
  local folder="$1"
  local author_file="${folder}/author.txt"
  local title_file="${folder}/title.txt"
  local narrator_file="${folder}/reader.txt"

  local author=""
  local title=""
  local narrator=""

  [[ -f "${author_file}" ]] && author="$(<"${author_file}")"
  [[ -f "${title_file}" ]] && title="$(<"${title_file}")"
  [[ -f "${narrator_file}" ]] && narrator="$(<"${narrator_file}")"

  echo "{{\"author\": \"${author}\", \"title\": \"${title}\", \"narrator\": \"${narrator}\"}}"
}

# === Best effort metadata resolver ===
resolve_metadata() {
  DebugEcho "🔍 resolve_metadata() called with folder: $folder"
  local folder="$1"
  local folder_name
  folder_name="$(basename "$folder")"

  local meta=""

  meta="$(extract_from_metadata_json "$folder")"
  if [[ -n "${meta}" && "${meta}" != "null" ]]; then
    log_debug "Metadata extracted from metadata.json"
    DebugEcho "✅ Metadata resolved from .json: ${meta}"
    echo "${meta}"
    return 0
  fi
  
  meta="$(extract_from_sidecar_texts "$folder")"
  if [[ -n "${meta}" && "${meta}" != "null" ]]; then
    log_debug "Metadata extracted from sidecar text files"
    DebugEcho "📎 Metadata resolved from sidecar files: ${meta}"
    echo "${meta}"
    return 0
  fi
  
  meta="$(extract_from_folder_name "${folder_name}")"
  if [[ -n "${meta}" && "${meta}" != "null" ]]; then
    log_debug "Metadata parsed from folder name"
    DebugEcho "🏷️ Metadata parsed from folder name: ${meta}"
    echo "${meta}"
  return 0
fi

  log_error "Failed to resolve metadata for folder: ${folder}"
  return 1
}
DebugEcho "📤 END loading metadata.sh"
###EOF
###EOF

#!/usr/bin/env bash
# lib/metadata.sh - Extracts basic metadata from folder names and sidecar files

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

  echo "{"author": "${author}", "title": "${title}"}"
}

# === Extract from metadata.json if exists ===
extract_from_metadata_json() {
  local folder="$1"
  local file="${folder}/metadata.json"
  [[ ! -f "${file}" ]] && return 1

  jq '{author, title, series, series_index, narrator}' "${file}" 2>/dev/null || return 1
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

  echo "{"author": "${author}", "title": "${title}", "narrator": "${narrator}"}"
}

# === Best effort metadata resolver ===
resolve_metadata() {
  local folder="$1"
  local folder_name
  folder_name="$(basename "$folder")"

  local meta=""

  meta="$(extract_from_metadata_json "$folder")" && echo "${meta}" && return 0
  meta="$(extract_from_sidecar_texts "$folder")" && echo "${meta}" && return 0
  meta="$(extract_from_folder_name "${folder_name}")" && echo "${meta}" && return 0

  return 1
}

###EOF

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

  echo "{\"author\": \"${author}\", \"title\": \"${title}\"}"
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

  echo "{\"author\": \"${author}\", \"title\": \"${title}\", \"narrator\": \"${narrator}\"}"
}

# === Best effort metadata resolver ===
resolve_metadata() {
  local folder="$1"
  DebugEcho "🔍 resolve_metadata() called with folder: ${folder}"

  local metadata_file
  metadata_file=$(find "${folder}" -maxdepth 1 -type f \( -iname 'metadata.txt' -o -iname 'desc.txt' -o -iname '*.nfo' \) | head -n 1 || true)

  if [[ -n "${metadata_file}" ]]; then
    DebugEcho "📄 Found metadata sidecar: ${metadata_file}"
    local author title narrator
    author=$(grep -i '^author:' "${metadata_file}" | cut -d':' -f2- | xargs)
    title=$(grep -i '^title:' "${metadata_file}" | cut -d':' -f2- | xargs)
    narrator=$(grep -i '^narrator:' "${metadata_file}" | cut -d':' -f2- | xargs)

   if [[ -n "${author}" || -n "${title}" || -n "${narrator}" ]]; then
  if [[ -n "${author}" && -n "${title}" ]]; then
    DebugEcho "📎 Metadata resolved from sidecar files: {\"author\": \"${author}\", \"title\": \"${title}\", \"narrator\": \"${narrator}\"}"
    echo "{\"author\": \"${author}\", \"title\": \"${title}\", \"narrator\": \"${narrator}\"}"
    return 0
  else
    DebugEcho "⚠️ Incomplete sidecar metadata (author/title missing); falling back to folder name"
    author="" title="" narrator=""
  fi
fi
  fi

  DebugEcho "🧠 Attempting to parse metadata from folder name"

  local folder_name
  folder_name="$(basename "${folder}")"

  # Perl one-liner: split on ' - ' and guess at fields
  local author title
  read -r author title < <(
    perl -Mstrict -Mwarnings -e '
      my $name = shift;
      my @parts = split /\s*-\s*/, $name;

      if (@parts == 2) {
        print "$parts[0]\t$parts[1]\n";
      } elsif (@parts >= 3 && $parts[1] =~ /\d/ && $parts[1] !~ /[a-z]/i) {
        # Middle part is likely a number
        print "$parts[0]\t$parts[2]\n";
      } else {
        print "$parts[0]\t" . join(" - ", @parts[1..$#parts]) . "\n";
      }
    ' "${folder_name}"
  )

  DebugEcho "📎 Metadata resolved from folder name: {\"author\": \"${author}\", \"title\": \"${title}\"}"
  echo "{\"author\": \"${author}\", \"title\": \"${title}\", \"narrator\": \"\"}"
}
DebugEcho "📤 END loading metadata.sh"
###EOF
###EOF

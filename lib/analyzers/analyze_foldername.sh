#!/usr/bin/env bash
# Analyzer: foldername.sh
# Purpose: Parse folder or file name for metadata

analyze_foldername() {
  local path="$1"
  local name
  name="$(basename "$path")"

  DebugEcho "📁 analyze_foldername() analyzing: ${name}"

  # === Remove common container markers like (1 of 2), etc.
  name="$(echo "$name" | sed -E 's/\s*\([0-9]+ of [0-9]+\)//g')"

  local author=""
  local title=""
  local series=""
  local series_index=""

  # === Try pattern: Author - Title
  if [[ "$name" =~ ^([^/]+?)\s*-\s*(.+)$ ]]; then
    author="${BASH_REMATCH[1]}"
    title="${BASH_REMATCH[2]}"

  # === Try pattern: Series [##] Title
  elif [[ "$name" =~ ^(.+?)\s*\[([0-9]+)\]\s*(.+)$ ]]; then
    series="${BASH_REMATCH[1]}"
    series_index="${BASH_REMATCH[2]}"
    title="${BASH_REMATCH[3]}"

  # === Try pattern: Title (Series, Book ##)
  elif [[ "$name" =~ ^(.+)\s*\(([^,]+), Book ([0-9]+)\)$ ]]; then
    title="${BASH_REMATCH[1]}"
    series="${BASH_REMATCH[2]}"
    series_index="${BASH_REMATCH[3]}"

  # === Try pattern: Title by Author
  elif [[ "$name" =~ ^(.+)\s+by\s+(.+)$ ]]; then
    title="${BASH_REMATCH[1]}"
    author="${BASH_REMATCH[2]}"
  fi

  # === Normalize whitespace
  author="$(echo "$author" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  title="$(echo "$title" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  series="$(echo "$series" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

  # === Only output if at least author+title OR series+title are found
  if [[ -n "$title" && ( -n "$author" || -n "$series" ) ]]; then
    echo "{\"source\": \"foldername\", \"author\": \"${author}\", \"title\": \"${title}\", \"series\": \"${series}\", \"series_index\": \"${series_index}\", \"narrator\": \"\"}"
    return 0
  fi

  return 1
}

# === Load analyzers ===
source "${LIB_DIR}/analyzers/metadatafiles.sh"
source "${LIB_DIR}/analyzers/foldername.sh"
source "${LIB_DIR}/analyzers/sidetags.sh"
source "${LIB_DIR}/analyzers/openlibrary.sh"

# === Try an analyzer and return if valid ===
try_analyzer() {
  local method="$1"
  local folder="$2"

  DebugEcho "🔍 Trying analyzer: ${method}"

  local result
  result="$("${method}" "${folder}" 2>/dev/null)" || return 1
  DebugEcho "📎 Analyzer result: ${result}"

  local author title
  author=$(echo "${result}" | jq -r '.author')
  title=$(echo "${result}" | jq -r '.title')

  if [[ -n "${author}" && -n "${title}" && "${author}" != "null" && "${title}" != "null" ]]; then
    echo "${result}"
    return 0
  else
    DebugEcho "⚠️ Analyzer '${method}' returned incomplete or invalid data."
    return 1
  fi
}

# === Orchestrate metadata resolution ===
resolve_metadata() {
  local folder="$1"
  DebugEcho "🔍 resolve_metadata() called with folder: ${folder}"

  local result

  # Try analyzers in priority order
  try_analyzer analyze_metadatafiles "${folder}" && return 0
  try_analyzer analyze_foldername "${folder}" && return 0
  try_analyzer analyze_sidetags "${folder}" && return 0
  try_analyzer analyze_openlibrary "${folder}" && return 0

  DebugEcho "❌ All analyzers failed. Returning empty metadata."
  echo '{"author": "", "title": "", "series": "", "series_index": "", "narrator": ""}'
  return 1
}
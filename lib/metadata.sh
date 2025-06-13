# === Dynamically source all analyzers ===
for analyzer in "${LIB_DIR}/analyzers"/analyze_*.sh; do
  [[ -f "${analyzer}" ]] || continue
  DebugEcho "📦 Loading analyzer: ${analyzer}"
  source "${analyzer}"
done

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
# === Validate if it is valid metadata ===
is_valid_metadata() {
  local m="$1"
  DebugEcho "🧪 Validating metadata: $(echo "$m" | jq -c '.')"

  if [[ -n "$(echo "$m" | jq -r '.author // empty')" && -n "$(echo "$m" | jq -r '.title // empty')" ]]; then
    DebugEcho "✅ Metadata is valid"
    return 0
  fi

  DebugEcho "❌ Metadata is invalid: missing author or title"
  return 1
}

# === Orchestrate metadata resolution ===
resolve_metadata() {
  local folder="$1"
  DebugEcho "🔍 resolve_metadata() called with folder: ${folder}"

  local analyzer
  for analyzer in $(declare -F | awk '{print $3}' | grep -E '^analyze_'); do
    try_analyzer "${analyzer}" "${folder}" && return 0
  done

  DebugEcho "❌ All analyzers failed. Returning empty metadata."
  echo '{"author": "", "title": "", "series": "", "series_index": "", "narrator": ""}'
  return 1
}
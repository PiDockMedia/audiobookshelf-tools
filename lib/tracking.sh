#!/usr/bin/env bash
# lib/tracking.sh - Handles audiobook tracking via JSON or SQLite

[[ -n "${_TRACKING_SH_LOADED:-}" ]] && return
readonly _TRACKING_SH_LOADED=1

source "${LIB_DIR}/logging.sh"

TRACKING_MODE="${TRACKING_MODE:-JSON}"
TRACKING_DB_PATH="${TRACKING_DB_PATH:-}"

# === Set default DB path based on mode ===
set_tracking_db_path() {
  if [[ -n "${TRACKING_DB_PATH}" ]]; then
    return 0
  fi

  if [[ "${IS_CONTAINER}" == "true" ]]; then
    TRACKING_DB_PATH="/config/processed.json"
  else
    TRACKING_DB_PATH="${INPUT_PATH}/processed.json"
  fi
}

# === Generate unique ID from structure + metadata ===
get_tracking_id() {
  local folder="$1"
  local metadata_fingerprint="$2"  # Optional: author+title

  # Collect file names and sizes
  local structure_hash
  structure_hash=$(find "$folder" -type f -exec stat -c '%n:%s' {} + | sort | sha256sum | cut -d ' ' -f1)

  if [[ -n "$metadata_fingerprint" ]]; then
    echo "${structure_hash}::${metadata_fingerprint}"
  else
    echo "${structure_hash}"
  fi
}

# === Check if already processed (JSON only for now) ===
tracking_exists() {
  local id="$1"
  [[ ! -f "${TRACKING_DB_PATH}" ]] && return 1
  grep -q "\"id\":\s*\"${id}\"" "${TRACKING_DB_PATH}" && return 0 || return 1
}

# === Mark item as processed ===
mark_as_processed() {
  local id="$1"
  local path="$2"
  local meta="$3"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  local entry
  entry=$(cat <<EOF
{
  "id": "${id}",
  "source_path": "${path}",
  "processed_at": "${timestamp}",
  "metadata": ${meta}
}
EOF
)

  if [[ ! -f "${TRACKING_DB_PATH}" ]]; then
    echo "[${entry}]" > "${TRACKING_DB_PATH}"
  else
    tmp_file="$(mktemp)"
    jq ". += [${entry}]" "${TRACKING_DB_PATH}" > "${tmp_file}" && mv "${tmp_file}" "${TRACKING_DB_PATH}"
  fi
}

# === Prune entries for missing source paths ===
prune_stale_entries() {
  [[ ! -f "${TRACKING_DB_PATH}" ]] && return 0
  tmp_file="$(mktemp)"
  jq '[.[] | select(.source_path | test("^/") and (inputs | index(.))) ]' "${TRACKING_DB_PATH}" <(find "${INPUT_PATH}" -type f) > "${tmp_file}"     && mv "${tmp_file}" "${TRACKING_DB_PATH}"
}

###EOF

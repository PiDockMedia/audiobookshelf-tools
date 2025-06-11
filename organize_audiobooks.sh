#!/usr/bin/env bash
set -euo pipefail

# === Setup ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"

source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/tracking.sh"
source "${LIB_DIR}/metadata.sh"
source "${LIB_DIR}/filesystem.sh"

# === Defaults ===
DRY_RUN="${DRY_RUN:-false}"
THREADS="${THREADS:-1}"
DELETE_ORIGINAL="${DELETE_ORIGINAL:-false}"
MOVE_MODE=false
[[ "${TRACKING_MODE:-}" == "MOVE" ]] && MOVE_MODE=true

# === Ensure tracking DB path ===
set_tracking_db_path

# === Scan source directory ===
find "${INPUT_PATH}" -mindepth 1 -maxdepth 1 -type d | while read -r folder; do
  log_info "→ Processing folder: ${folder}"

  audio_found=$(find "${folder}" -type f | grep -Ei "\.(m4b|mp3|flac|ogg|m4a|wav)$" || true)
  if [[ -z "${audio_found}" ]]; then
    quarantine_failed_folder "${folder}" "No supported audio files found"
    continue
  fi

  metadata_json="$(resolve_metadata "${folder}")"
  if [[ -z "${metadata_json}" || "${metadata_json}" == "null" ]]; then
    quarantine_failed_folder "${folder}" "Unable to extract metadata"
    continue
  fi

  author=$(echo "${metadata_json}" | jq -r '.author // empty')
  title=$(echo "${metadata_json}" | jq -r '.title // empty')

  if [[ -z "${author}" || -z "${title}" ]]; then
    quarantine_failed_folder "${folder}" "Missing author or title metadata"
    continue
  fi

  meta_fingerprint="${author,,}|${title,,}"
  id=$(get_tracking_id "${folder}" "${meta_fingerprint}")

  if tracking_exists "${id}"; then
    log_info "✓ Already processed: ${folder}"
    continue
  fi

  # === Compute destination ===
  safe_author=$(echo "${author}" | tr '/' '_' | tr -s ' ')
  safe_title=$(echo "${title}" | tr '/' '_' | tr -s ' ')
  target_dir="${OUTPUT_PATH}/${safe_author}/${safe_title}"

  if [[ "${DRY_RUN}" == "true" ]]; then
    log_info "[DRY RUN] Would organize: ${folder} → ${target_dir}"
    continue
  fi

  process_folder_copy_or_move "${folder}" "${target_dir}" "${MOVE_MODE}" || {
    quarantine_failed_folder "${folder}" "Failed to copy/move"
    continue
  }

  mark_as_processed "${id}" "${folder}" "${metadata_json}"
done

log_info "✅ All done!"
###EOF

#!/usr/bin/env bash
# lib/filesystem.sh - Handles filesystem operations for organizing audiobooks

[[ -n "${_FILESYSTEM_SH_LOADED:-}" ]] && return
readonly _FILESYSTEM_SH_LOADED=1

source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/config.sh"

SUPPORTED_AUDIO_EXTENSIONS=(.m4b .mp3 .flac .ogg .m4a .wav)

# === Helpers ===

is_audio_file() {
  local file="$1"
  for ext in "${SUPPORTED_AUDIO_EXTENSIONS[@]}"; do
    [[ "${file,,}" == *"${ext}" ]] && return 0
  done
  return 1
}

should_include_file() {
  local file="$1"
  is_audio_file "${file}" && return 0
  [[ "${INCLUDE_EXTRAS:-true}" == "true" ]] && [[ ! "$(basename "${file}")" =~ ^\..* ]] && return 0
  return 1
}

# === Ensure Unique Target Directory (based on DUPLICATE_POLICY) ===

resolve_target_dir() {
  local base="$1"
  local attempt=0
  local max_attempts=5
  local newdir="${base}"

  while [[ -e "${newdir}" && "${DUPLICATE_POLICY:-versioned}" == "versioned" && $attempt -lt $max_attempts ]]; do
    attempt=$((attempt + 1))
    newdir="${base} - copy ${attempt}"
  done

  if [[ -e "${newdir}" ]]; then
    case "${DUPLICATE_POLICY:-versioned}" in
      skip)
        log_warn "Skipping duplicate: ${newdir}"
        return 1
        ;;
      overwrite)
        log_warn "Overwriting existing: ${newdir}"
        ;;
      *)
        log_error "Too many duplicates for: ${base}"
        return 2
        ;;
    esac
  fi

  echo "${newdir}"
  return 0
}

# === Move or Copy Folder ===

process_folder_copy_or_move() {
  local src="$1"
  local dest="$2"
  local move="${3:-false}"

  local target
  target="$(resolve_target_dir "${dest}")" || return 1

  mkdir -p "${target}"
  find "${src}" -type f | while read -r file; do
    if should_include_file "${file}"; then
      dest_path="${target}/$(basename "${file}")"
      if [[ "${move}" == "true" ]]; then
        mv -n "${file}" "${dest_path}"
      else
        cp -n "${file}" "${dest_path}"
      fi
    fi
  done

  log_info "✓ ${move^^} from '${src}' to '${target}'"
}

# === Move Folder to /Unorganized ===

quarantine_failed_folder() {
  local src="$1"
  local reason="$2"
  local unorganized="${OUTPUT_PATH}/Unorganized"
  local target="${unorganized}/$(basename "${src}")"

  mkdir -p "${unorganized}"
  mv -n "${src}" "${target}"
  log_error "Moved to Unorganized: '${src}' → '${target}' — Reason: ${reason}"
}

###EOF

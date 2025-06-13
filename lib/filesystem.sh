# === filesystem.sh ===
# Safe file movement and folder creation
# Depends on: lib/logging.sh

DebugEcho "📁 Entering filesystem.sh"

function ensure_directory_exists() {
  local dir="$1"
  DebugEcho "→ ensure_directory_exists called with: ${dir}"
  if [[ ! -d "${dir}" ]]; then
    DebugEcho "📂 Creating directory: ${dir}"
    mkdir -p "${dir}"
  fi
  DebugEcho "✅ Directory ensured: ${dir}"
}

function safe_copy_folder() {
  local src="$1"
  local dest="$2"
  DebugEcho "→ safe_copy_folder from ${src} to ${dest}"
  ensure_directory_exists "$(dirname "${dest}")"
  cp -a "${src}" "${dest}"
  DebugEcho "✅ Finished copying ${src} to ${dest}"
}

function safe_move_folder() {
  local src="$1"
  local dest="$2"
  DebugEcho "→ safe_move_folder from ${src} to ${dest}"
  ensure_directory_exists "$(dirname "${dest}")"
  mv "${src}" "${dest}"
  DebugEcho "✅ Finished moving ${src} to ${dest}"
}

function generate_safe_output_path() {
  local base="$1"
  local attempt=0
  local newpath="${base}"
  DebugEcho "→ generate_safe_output_path base: ${base}"
  while [[ -e "${newpath}" && ${attempt} -lt 5 ]]; do
    attempt=$((attempt + 1))
    newpath="${base} - copy ${attempt}"
    DebugEcho "⚠️ Attempting newpath due to conflict: ${newpath}"
  done
  echo "${newpath}"
  DebugEcho "✅ Output path resolved: ${newpath}"
}

# === Quarantine Failed Folder ===
# Moves a folder that failed processing into the 'Unorganized' directory for review.
#
# Globals:
#   OUTPUT_PATH
#   DRY_RUN
# Arguments:
#   $1 - Path to the failed input folder
#   $2 - Reason for failure (used in log entry)
# Outputs:
#   Log messages and moves the folder, unless in dry run mode
quarantine_failed_folder() {
  local failed_folder="$1"
  local reason="$2"
  local unorganized_dir="${OUTPUT_PATH}/Unorganized"

  DebugEcho "🚫 BEGIN quarantine_failed_folder"
  DebugEcho "🧪 Input folder: ${failed_folder}"
  DebugEcho "🧪 Reason: ${reason}"
  DebugEcho "🧪 Unorganized dir: ${unorganized_dir}"

  mkdir -p "${unorganized_dir}"

  local base_name
  base_name="$(basename "${failed_folder}")"
  local timestamp
  timestamp="$(date +%Y%m%d_%H%M%S)"
  local target="${unorganized_dir}/${base_name}_${timestamp}"

  if [[ "${DRY_RUN:-false}" == "true" ]]; then
    log_info "[DRY RUN] Would quarantine '${failed_folder}' → '${target}' (reason: ${reason})"
  else
    log_warn "Quarantining '${failed_folder}' → '${target}' (reason: ${reason})"
    mv "${failed_folder}" "${target}" || log_error "Failed to move to quarantine: ${failed_folder}"
  fi

  DebugEcho "✅ END quarantine_failed_folder"
}

DebugEcho "✅ Finished loading filesystem.sh"
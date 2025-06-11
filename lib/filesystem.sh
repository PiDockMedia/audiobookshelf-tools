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

DebugEcho "✅ Finished loading filesystem.sh"
#!/usr/bin/env bash
set -euo pipefail

# === Load libraries ===
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/config.sh"
source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/tracking.sh"
source "${SCRIPT_DIR}/lib/ai_bundle.sh"

print_divider
DebugEcho "📚 BEGIN organize_audiobooks.sh"

parse_cli_args "$@"
load_env_config

setup_logging
init_db

# === Main scan loop
for entry in "$INPUT_PATH"/*; do
  name="$(basename "$entry")"

  # Skip system/working paths
  [[ "$name" == "ai_bundles" ]] && continue
  [[ "$name" == ".audiobook_tracking.db" ]] && continue

  # Process if it's a directory or a supported audio file
  if [[ -d "$entry" || "$entry" =~ \.(m4b|mp3|flac|ogg|wav)$ ]]; then
    DebugEcho "🔍 Scanning candidate: $name"
    scan_input_and_prepare_ai_bundles "$entry"
  fi
done

if [[ "${INGEST_MODE}" == "true" ]]; then
  ingest_metadata_file "${INGEST_FILE}"
fi

DebugEcho "🏁 END organize_audiobooks.sh"

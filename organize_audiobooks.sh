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

scan_input_and_prepare_ai_bundles

if [[ "${INGEST_MODE}" == "true" ]]; then
  ingest_metadata_file "${INGEST_FILE}"
fi

DebugEcho "🏁 END organize_audiobooks.sh"

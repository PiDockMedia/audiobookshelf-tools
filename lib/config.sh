# config.sh
CONFIG_LOADED=true

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env"

INPUT_PATH=""
OUTPUT_PATH=""
AI_BUNDLE_PATH="${ROOT_DIR}/ai_bundles"
DRY_RUN=false
INGEST_MODE=false
INGEST_FILE=""

function parse_cli_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --dry-run) DRY_RUN=true ;;
      --ingest) INGEST_MODE=true; INGEST_FILE="$2"; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
  done
}

function load_env_config() {
  if [[ -f "${ENV_FILE}" ]]; then
    source "${ENV_FILE}"
  fi
  INPUT_PATH="${INPUT_PATH:-${ROOT_DIR}/input}"
  OUTPUT_PATH="${OUTPUT_PATH:-${ROOT_DIR}/output}"
}

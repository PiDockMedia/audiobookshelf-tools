# lib/config.sh - Loads environment variables and sets defaults
DebugEcho "📥 BEGIN loading config.sh"

[[ -n "${_CONFIG_SH_LOADED:-}" ]] && return
readonly _CONFIG_SH_LOADED=1

# Load .env file if it exists and hasn't already been loaded
if [[ -f "${REPO_ROOT}/.env" ]]; then
  DebugEcho "🧪 Sourcing .env from: ${REPO_ROOT}/.env"
  set -o allexport
  # shellcheck disable=SC1090
  source "${REPO_ROOT}/.env"
  set +o allexport
else
  DebugEcho "⚠️ No .env found at ${REPO_ROOT}/.env"
fi

# Set defaults if not already defined
: "${INPUT_PATH:=${REPO_ROOT}/input}"
: "${OUTPUT_PATH:=${REPO_ROOT}/output}"
: "${CONFIG_PATH:=${REPO_ROOT}/config}"
: "${LOG_LEVEL:=info}"
: "${TRACKING_MODE:=JSON}"
: "${INCLUDE_EXTRAS:=true}"
: "${DUPLICATE_POLICY:=versioned}"

DebugEcho "🔧 Config loaded:"
DebugEcho "    INPUT_PATH=${INPUT_PATH}"
DebugEcho "    OUTPUT_PATH=${OUTPUT_PATH}"
DebugEcho "    CONFIG_PATH=${CONFIG_PATH}"
DebugEcho "    LOG_LEVEL=${LOG_LEVEL}"
DebugEcho "    TRACKING_MODE=${TRACKING_MODE}"
DebugEcho "    INCLUDE_EXTRAS=${INCLUDE_EXTRAS}"
DebugEcho "    DUPLICATE_POLICY=${DUPLICATE_POLICY}"

DebugEcho "📤 END loading config.sh"
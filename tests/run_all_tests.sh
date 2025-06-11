#!/usr/bin/env bash
set -euo pipefail

# === Load DebugEcho and logger ===
source "$(dirname "$0")/../lib/debugecho.sh"
source "$(dirname "$0")/../lib/logging.sh"

export LOG_LEVEL=debug
DebugEcho "🐚 BEGIN run_all_tests.sh"

# === Set up paths ===
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
LOG_DIR="${TEST_DIR}/logs"
mkdir -p "${LOG_DIR}"
LOG_FILE="${LOG_DIR}/test_run_$(date +%Y-%m-%d_%H%M).log"

# === Track test start ===
printf "[INFO] Test run started at %s\n" "$(date)" | tee "${LOG_FILE}"

# === Ensure permissions on all scripts ===
printf "[INFO] Ensuring all .sh scripts are readable...\n" | tee -a "${LOG_FILE}"
find "${ROOT_DIR}" -type f -name "*.sh" -exec chmod 755 {} +

# === Load test-env ===
ENV_FILE="${TEST_DIR}/test-env"
if [[ -f "${ENV_FILE}" ]]; then
  printf "[INFO] Loading test environment variables from: %s\n" "${ENV_FILE}" | tee -a "${LOG_FILE}"
  set -o allexport
  source "${ENV_FILE}"
  set +o allexport
else
  printf "[FATAL] Missing test-env file at %s\n" "${ENV_FILE}" | tee -a "${LOG_FILE}"
  exit 1
fi

# === Load config with DebugEcho wrappers ===
DebugEcho "📥 BEGIN loading config.sh"
source "${ROOT_DIR}/lib/config.sh"
DebugEcho "📤 END loading config.sh"

# === Show effective environment ===
DebugEcho "📦 INPUT_PATH=${INPUT_PATH:-unset}"
DebugEcho "📦 OUTPUT_PATH=${OUTPUT_PATH:-unset}"
DebugEcho "📦 CONFIG_PATH=${CONFIG_PATH:-unset}"
DebugEcho "📦 TRACKING_MODE=${TRACKING_MODE:-unset}"
DebugEcho "📦 DUPLICATE_POLICY=${DUPLICATE_POLICY:-unset}"
DebugEcho "📦 INCLUDE_EXTRAS=${INCLUDE_EXTRAS:-unset}"

# === Optional cleanup ===
if [[ "${1:-}" == "--clean" ]]; then
  DebugEcho "🧹 Cleaning test data..."
  "${TEST_DIR}/generate_test_audiobooks.sh" --clean | tee -a "${LOG_FILE}"
fi

# === Step 1: Generate test input ===
DebugEcho "🧪 Step 1: Generating test audiobook files..."
"${TEST_DIR}/generate_test_audiobooks.sh" | tee -a "${LOG_FILE}"
DebugEcho "✅ Finished generating test data"

# === Confirm INPUT_PATH contents ===
printf "[INFO] Contents of INPUT_PATH (%s):\n" "${INPUT_PATH}" | tee -a "${LOG_FILE}"
find "${INPUT_PATH}" -type f | tee -a "${LOG_FILE}" || echo "[WARN] No files found." | tee -a "${LOG_FILE}"

# === Step 2: Run organizer ===
DebugEcho "📚 Step 2: Running organize_audiobooks.sh..."
"${ROOT_DIR}/organize_audiobooks.sh" | tee -a "${LOG_FILE}"
DebugEcho "✅ Finished running organize_audiobooks.sh"

# === Done ===
printf "[INFO] Test run complete.\n" | tee -a "${LOG_FILE}"
DebugEcho "🏁 END run_all_tests.sh"
###EOF
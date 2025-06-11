#!/usr/bin/env bash
set -euo pipefail

#  === Load logging for DebugEcho support ===
source "$(dirname "$0")/../lib/logging.sh"

export LOG_LEVEL=debug
DebugEcho ">>> BEGIN run_all_tests.sh"

# === Test Runner for audiobookshelf-tools ===
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
LOG_DIR="${TEST_DIR}/logs"
mkdir -p "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/test_run_2025-06-11_0008.log"
echo "[INFO] Test run started at $(date)" | tee "${LOG_FILE}"

# === Set .sh permissions ===
echo "[INFO] Ensuring all .sh scripts are readable..." | tee -a "${LOG_FILE}"
find "${ROOT_DIR}" -type f -name "*.sh" -exec chmod 755 {} +

# === Load test-env ===
ENV_FILE="${TEST_DIR}/test-env"
if [[ -f "${ENV_FILE}" ]]; then
  echo "[INFO] Loading test environment variables from: ${ENV_FILE}" | tee -a "${LOG_FILE}"
  set -o allexport
  source "${ENV_FILE}"
  set +o allexport
else
  echo "[FATAL] Missing test-env file at ${ENV_FILE}" | tee -a "${LOG_FILE}"
  exit 1
fi

# === Load config.sh ===
DebugEcho "📥 BEGIN loading config.sh"
source "${ROOT_DIR}/lib/config.sh"
DebugEcho "📤 END loading config.sh"

# === Show ENV values ===
DebugEcho "📦 INPUT_PATH=${INPUT_PATH:-unset}"
DebugEcho "📦 OUTPUT_PATH=${OUTPUT_PATH:-unset}"
DebugEcho "📦 CONFIG_PATH=${CONFIG_PATH:-unset}"
DebugEcho "📦 TRACKING_MODE=${TRACKING_MODE:-unset}"
DebugEcho "📦 DUPLICATE_POLICY=${DUPLICATE_POLICY:-unset}"
DebugEcho "📦 INCLUDE_EXTRAS=${INCLUDE_EXTRAS:-unset}"

# === Run Test Data Generator ===
DebugEcho "Step 1: Generating test audiobook files..."
bash "${TEST_DIR}/generate_test_audiobooks.sh" | tee -a "${LOG_FILE}"
DebugEcho "✅ Finished generating test data"

# === Confirm output structure ===
echo "[INFO] Contents of INPUT_PATH (${INPUT_PATH}):" | tee -a "${LOG_FILE}"
find "${INPUT_PATH}" -type f | tee -a "${LOG_FILE}" || echo "[WARN] No files found."

# === Run the organizer ===
DebugEcho "Step 2: Running organize_audiobooks.sh..."
bash "${ROOT_DIR}/organize_audiobooks.sh" | tee -a "${LOG_FILE}"
DebugEcho "✅ Finished running organize_audiobooks.sh"

echo "[INFO] Test run complete." | tee -a "${LOG_FILE}"
DebugEcho "<<< END run_all_tests.sh"
###EOF

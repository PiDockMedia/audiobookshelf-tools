#!/usr/bin/env bash
set -euo pipefail

# === Test Runner for audiobookshelf-tools ===
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
LOG_DIR="${TEST_DIR}/logs"
mkdir -p "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/test_run_2025-06-11_0008.log"
echo "[INFO] Test run started at $(date)" | tee "${LOG_FILE}"

# === Set .sh permissions ===
echo "[INFO] Ensuring all .sh scripts are readable..." | tee -a "${LOG_FILE}"
find "${ROOT_DIR}" -type f -name "*.sh" -exec chmod 644 {} +

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

# === Show ENV values ===
echo "[DEBUG] INPUT_PATH=${INPUT_PATH:-unset}" | tee -a "${LOG_FILE}"
echo "[DEBUG] OUTPUT_PATH=${OUTPUT_PATH:-unset}" | tee -a "${LOG_FILE}"
echo "[DEBUG] CONFIG_PATH=${CONFIG_PATH:-unset}" | tee -a "${LOG_FILE}"
echo "[DEBUG] TRACKING_MODE=${TRACKING_MODE:-unset}" | tee -a "${LOG_FILE}"
echo "[DEBUG] DUPLICATE_POLICY=${DUPLICATE_POLICY:-unset}" | tee -a "${LOG_FILE}"
echo "[DEBUG] INCLUDE_EXTRAS=${INCLUDE_EXTRAS:-unset}" | tee -a "${LOG_FILE}"

# === Run Test Data Generator ===
echo "[INFO] Step 1: Generating test audiobook files..." | tee -a "${LOG_FILE}"
bash "${TEST_DIR}/generate_test_audiobooks.sh" | tee -a "${LOG_FILE}"

# === Confirm output structure ===
echo "[INFO] Contents of INPUT_PATH (${INPUT_PATH}):" | tee -a "${LOG_FILE}"
find "${INPUT_PATH}" -type f | tee -a "${LOG_FILE}" || echo "[WARN] No files found."

# === Run the organizer ===
echo "[INFO] Step 2: Running organize_audiobooks.sh..." | tee -a "${LOG_FILE}"
bash "${ROOT_DIR}/organize_audiobooks.sh" | tee -a "${LOG_FILE}"

echo "[INFO] Test run complete." | tee -a "${LOG_FILE}"
###EOF

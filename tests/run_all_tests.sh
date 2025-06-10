#!/usr/bin/env bash
set -euo pipefail

# === Test Runner for audiobookshelf-tools ===
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
LOG_DIR="${TEST_DIR}/logs"
mkdir -p "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/test_run_2025-06-10_2338.log"
echo "[INFO] Test run started at $(date)" | tee "${LOG_FILE}"

# === Load .env manually for test ===
ENV_FILE="${TEST_DIR}/test-env"
if [[ -f "${ENV_FILE}" ]]; then
  export $(grep -v '^#' "${ENV_FILE}" | xargs)
else
  echo "[FATAL] Missing test-env file at ${ENV_FILE}" | tee -a "${LOG_FILE}"
  exit 1
fi

# === Include Logging System ===
source "${ROOT_DIR}/lib/logging.sh"
LOG_FILE="${LOG_FILE}"
LOG_LEVEL="debug"

# === Run Test Data Generator ===
log_info "Generating test audiobook files..."
bash "${TEST_DIR}/generate_test_audiobooks.sh" | tee -a "${LOG_FILE}"

# === Run the organizer ===
log_info "Running organize_audiobooks.sh..."
bash "${ROOT_DIR}/organize_audiobooks.sh" | tee -a "${LOG_FILE}"

log_info "Test run complete."
###EOF

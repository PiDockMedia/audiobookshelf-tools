#!/usr/bin/env bash
set -euo pipefail

# === Test Runner for audiobookshelf-tools ===
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
LOG_DIR="${TEST_DIR}/logs"
mkdir -p "${LOG_DIR}"

LOG_FILE="${LOG_DIR}/test_run_2025-06-10_2200.log"
echo "[INFO] Test run started at $(date)" | tee "${LOG_FILE}"

# === Include Logging System ===
source "${ROOT_DIR}/lib/logging.sh"
LOG_FILE="${LOG_FILE}"
LOG_LEVEL="debug"

# === Run Test Data Generator ===
log_info "Generating test audiobook files..."
bash "${TEST_DIR}/generate_test_audiobooks.sh" | tee -a "${LOG_FILE}"

# === Placeholder: Run Organization Tests ===
log_info "Running placeholder organization test..."
# TODO: Add calls to organize_audiobooks.sh with test inputs

log_info "Test run complete."
###EOF

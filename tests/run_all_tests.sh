#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
LOG_DIR="${ROOT_DIR}/tests/logs"
LOG_FILE="${LOG_DIR}/test_run_$(date +%Y-%m-%d_%H%M).log"
TEST_ENV="${ROOT_DIR}/.env"

mkdir -p "${LOG_DIR}"

echo "🧪 BEGIN run_all_tests.sh" | tee "${LOG_FILE}"

# Step 1: Load config
if [[ -f "${TEST_ENV}" ]]; then
  echo "[INFO] Using .env: ${TEST_ENV}" | tee -a "${LOG_FILE}"
else
  echo "[WARN] No .env found, using defaults" | tee -a "${LOG_FILE}"
fi

# Step 2: Run organizer in dry-run + debug mode
LOG_LEVEL=debug   "${ROOT_DIR}/organize_audiobooks.sh" --dry-run 2>&1 | tee -a "${LOG_FILE}"

echo "✅ Test run complete." | tee -a "${LOG_FILE}"

###EOF

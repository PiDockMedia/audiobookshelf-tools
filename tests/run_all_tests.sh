#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
LOG_DIR="${ROOT_DIR}/tests/logs"
LOG_FILE="${LOG_DIR}/test_run_$(date +%Y-%m-%d_%H%M).log"
TEST_ENV="${ROOT_DIR}/.env"

mkdir -p "${LOG_DIR}"

echo "🧪 BEGIN run_all_tests.sh" | tee "${LOG_FILE}"

# === Step 1: Clean previous test data
echo "🔄 Cleaning previous test data..." | tee -a "${LOG_FILE}"
"${ROOT_DIR}/tests/generate_test_audiobooks.sh" --clean | tee -a "${LOG_FILE}"

# === Step 2: Generate new test data
echo "📁 Generating test audiobooks..." | tee -a "${LOG_FILE}"
"${ROOT_DIR}/tests/generate_test_audiobooks.sh" | tee -a "${LOG_FILE}"

# === Step 3: Load .env or fallback
if [[ -f "${TEST_ENV}" ]]; then
  echo "[INFO] Using .env: ${TEST_ENV}" | tee -a "${LOG_FILE}"
else
  echo "[WARN] No .env found, using defaults" | tee -a "${LOG_FILE}"
fi

# === Step 4: Run organizer in debug dry-run mode
echo "🚀 Running organize_audiobooks.sh in --dry-run debug mode..." | tee -a "${LOG_FILE}"
LOG_LEVEL=debug \
  bash "${ROOT_DIR}/organize_audiobooks.sh" --dry-run 2>&1 | tee -a "${LOG_FILE}"

# === Step 5: Final Result
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
  echo "✅ Test run completed successfully." | tee -a "${LOG_FILE}"
else
  echo "❌ Test run FAILED. Check log: ${LOG_FILE}" | tee -a "${LOG_FILE}"
  exit 1
fi

echo "🏁 END run_all_tests.sh" | tee -a "${LOG_FILE}"

###EOF
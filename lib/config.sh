#!/usr/bin/env bash
# config.sh — Load configuration defaults and overrides

set -euo pipefail
IFS=$'\n\t'

# --- Set ROOT_DIR to project root
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# --- Load .env if present
ENV_FILE="${ROOT_DIR}/.env"
[[ -f "$ENV_FILE" ]] && source "$ENV_FILE"

# --- Core Paths
INPUT_PATH="${INPUT_PATH:-${ROOT_DIR}/input}"
OUTPUT_PATH="${OUTPUT_PATH:-${ROOT_DIR}/output}"
CONFIG_PATH="${CONFIG_PATH:-${ROOT_DIR}/config}"
LOG_LEVEL="${LOG_LEVEL:-info}"

# --- Working paths now inside INPUT_PATH
TRACKING_DB_PATH="${TRACKING_DB_PATH:-${INPUT_PATH}/.audiobook_tracking.db}"
AI_BUNDLE_PATH="${AI_BUNDLE_PATH:-${INPUT_PATH}/ai_bundles}"
AI_BUNDLE_PENDING="${AI_BUNDLE_PATH}/pending"

# --- Optional flags
DRY_RUN="${DRY_RUN:-false}"
DEBUG="${DEBUG:-false}"
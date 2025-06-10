#!/usr/bin/env bash
# lib/config.sh - Load global config and environment variables
# This file MUST be sourced before any other module is used.

# Prevent multiple sourcing
[[ -n "${_CONFIG_SH_LOADED:-}" ]] && return
readonly _CONFIG_SH_LOADED=1

# === Detect Mode (Container vs CLI) ===
IS_CONTAINER=false
[[ -f "/.dockerenv" || -d "/config" ]] && IS_CONTAINER=true

# === Default Values ===
ENV_FILE=".env"
CONFIG_PATH=""
INPUT_PATH=""
OUTPUT_PATH=""
LOG_LEVEL="info"
DRY_RUN=false

# === Load .env if present ===
load_env_file() {
  local env_path="${SCRIPT_DIR}/${ENV_FILE}"
  if [[ -f "${env_path}" ]]; then
    # shellcheck disable=SC1090
    source "${env_path}"
  elif [[ "${IS_CONTAINER}" == "true" ]]; then
    echo "[FATAL] Missing required .env file at ${env_path} inside container." >&2
    exit 1
  else
    echo "[INFO] No .env file found. Using CLI-safe defaults."
  fi
}

# === Validate required variables ===
validate_config() {
  local missing=()
  [[ -z "${CONFIG_PATH}" ]] && missing+=("CONFIG_PATH")
  [[ -z "${INPUT_PATH}" ]] && missing+=("INPUT_PATH")
  [[ -z "${OUTPUT_PATH}" ]] && missing+=("OUTPUT_PATH")

  if (( ${#missing[@]} )); then
    echo "[FATAL] Missing required config variables: ${missing[*]}" >&2
    exit 1
  fi
}

# === Initialize ===
load_env_file
validate_config

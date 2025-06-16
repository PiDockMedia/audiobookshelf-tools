#!/usr/bin/env bash
# ai_bundle.sh — Prepare audiobook folder data for AI metadata inference

set -euo pipefail
IFS=$'\n\t'

source "$(dirname "$0")/../lib/config.sh"
source "$(dirname "$0")/../lib/logging.sh"
source "$(dirname "$0")/../lib/filesystem.sh"

setup_logging

DebugEcho "📦 scan_input_and_prepare_ai_bundles() started"

mkdir -p "${AI_BUNDLE_PENDING}"
AI_JSONL="${AI_BUNDLE_PENDING}/ai_input.jsonl"
: > "$AI_JSONL"

for entry in "$INPUT_PATH"/*; do
  [[ -d "$entry" ]] || continue

  id="$(echo "$(basename "$entry")" | tr ' ' '_' | tr '/' '_')"
  bundle_dir="${AI_BUNDLE_PENDING}/${id}"

  DebugEcho "📚 Adding ${id} to AI bundle"

  mkdir -p "$bundle_dir"
  tree "$entry" > "$bundle_dir/tree.txt"

  cat > "$bundle_dir/prompt.md" <<EOF
You are helping organize audiobook folders. Here's a folder tree:
(See tree.txt)

Please return JSON metadata like:
{
  "author": "Author Name",
  "title": "Book Title",
  "series": "Optional Series",
  "series_index": 1,
  "narrator": "Optional Narrator"
}
EOF

  # === Use only the folder name, not the full path
  base_name="$(basename "$entry")"
  echo "{\"id\": \"${id}\", \"path\": \"${base_name}\"}" >> "$AI_JSONL"
done

DebugEcho "✅ AI bundle created at ${AI_BUNDLE_PENDING}"
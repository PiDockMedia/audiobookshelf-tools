# ai_bundle.sh - Responsible for generating AI bundles from new/untracked audiobook folders

function scan_input_and_prepare_ai_bundles() {
  DebugEcho "📦 scan_input_and_prepare_ai_bundles() started"
  mkdir -p "${AI_BUNDLE_PATH}/pending"

  local bundle_file="${AI_BUNDLE_PATH}/pending/ai_input.jsonl"
  local prompt_file="${AI_BUNDLE_PATH}/pending/prompt.md"
  : > "${bundle_file}"  # Truncate if exists

  for entry in "${INPUT_PATH}"/*; do
    [[ -e "${entry}" ]] || continue
    [[ -f "${entry}" || -d "${entry}" ]] || continue

    local id
    id="$(basename "$entry" | tr ' ' '_' | tr -dc '[:alnum:]_')"

    # Check DB: Skip if already processed or tracked
    if sqlite3 "${TRACKING_DB}" "SELECT 1 FROM books WHERE id='${id}' AND state='organized';" | grep -q 1; then
      DebugEcho "⏭️ Skipping already organized: ${id}"
      continue
    fi

    DebugEcho "📚 Adding ${id} to AI bundle"

    local folder_tree metadata_preview files

    folder_tree=$(tree "$entry" 2>/dev/null | sed 's/^/    /')
    metadata_preview=$(find "$entry" -type f \( -iname '*.json' -o -iname '*.nfo' -o -iname '*.txt' -o -iname '*.opf' \) -exec head -n 5 {} + 2>/dev/null | sed 's/^/    /')
    files=$(find "$entry" -type f -exec basename {} \; | sort | uniq | paste -sd ', ' -)

    echo "{\"id\": \"${id}\", \"path\": \"${entry}\", \"filenames\": \"${files}\"}" >> "${bundle_file}"

    sqlite3 "${TRACKING_DB}" <<SQL
INSERT OR REPLACE INTO books (id, path, state, updated_at)
VALUES ('${id}', '${entry}', 'pending_ai', datetime('now'));
SQL
  done

  # Write universal prompt
  cat > "${prompt_file}" <<EOF
You are helping organize audiobook folders for ingestion into Audiobookshelf.
Each line in ai_input.jsonl represents one book entry with basic file info.

Please provide a matching JSON output line per entry like:
{
  "id": "Folder_Or_File_Name",
  "author": "Author Name",
  "title": "Book Title",
  "series": "Optional Series Name",
  "series_index": 1,
  "narrator": "Narrator Name"
}

Do your best using the folder name, filenames, and any nearby .txt, .json, .nfo, .opf files. Be accurate and structured.
EOF

  DebugEcho "✅ AI bundle created at ${AI_BUNDLE_PATH}/pending"
}
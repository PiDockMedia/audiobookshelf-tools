# 🧠 Analyzer Modules for Metadata Extraction

This folder contains modular *analyzer* scripts, each responsible for attempting to extract audiobook metadata (author, title, series, etc.) from a given input folder. These are the heart of the metadata discovery system used by the `organize_audiobooks.sh` process.

---

## 📦 What’s an Analyzer?

Each analyzer is a standalone `.sh` file prefixed with `analyze_`, and must implement a function with the same name as the file (minus `.sh`). For example:

**File:** `analyze_foldername.sh`  
**Function:** `analyze_foldername()`

An analyzer receives the **folder path** as its only argument and must output a valid **JSON object** (preferably compact, all on one line) with at least:

```json
{
  "author": "Author Name",
  "title": "Book Title",
  "series": "Optional Series Name",
  "series_index": "Optional Number",
  "narrator": "Optional Narrator Name"
}
```

If it fails to find meaningful metadata, it should either:
- Return empty fields (as above), or
- Exit with a non-zero status code

---

## 🧪 How They're Used

When `resolve_metadata()` is called in `metadata.sh`, it:

1. Dynamically loads all scripts in this folder starting with `analyze_`
2. Calls each analyzer in turn, stopping at the first that returns valid metadata (as verified by `is_valid_metadata()`)

---

## 🛠️ Writing Your Own Analyzer

1. Create a new file in `lib/analyzers/` named like `analyze_myanalyzer.sh`
2. Write a function called `analyze_myanalyzer()` that:
   - Accepts one argument (the folder path)
   - Analyzes it however it wants (folder name, sidecar files, audio metadata, etc.)
   - Returns a valid JSON object to stdout

### 🧩 Example: analyze_foldername.sh

```bash
analyze_foldername() {
  local folder="$1"
  local name
  name="$(basename "$folder")"

  # Try pattern: "Author - Title"
  if [[ "$name" =~ ^([^/]+?)\s*-\s*(.+)$ ]]; then
    local author="${BASH_REMATCH[1]}"
    local title="${BASH_REMATCH[2]}"
    echo "{\"author\": \"${author}\", \"title\": \"${title}\", \"series\": \"\", \"series_index\": \"\", \"narrator\": \"\"}"
    return 0
  fi

  # Fallback
  return 1
}
```

---

## 🤖 Best Practices

- Keep analyzers small and focused. One task, one file.
- Use `DebugEcho` generously so test logs are helpful.
- Never output multiline or malformed JSON. One line, always.
- Avoid destructive operations (never rename, move, or write files here).

---

## 🚧 Temporary or Experimental Analyzers

Feel free to prefix your experimental scripts with `analyze_wip_*.sh` so they won’t get auto-loaded until they’re renamed.

---

## 📚 Related Files

- `metadata.sh`: loads and orchestrates analyzers
- `resolve_metadata()`: calls analyzers in order
- `is_valid_metadata()`: validates analyzer output

---

## 🧙🏽 Tip

A good analyzer is like a wizard: clever, careful, and always writes clean JSON.
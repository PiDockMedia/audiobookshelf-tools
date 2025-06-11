# 🎧 audiobookshelf-tools

Welcome to **audiobookshelf-tools**, the command-line companion you never knew your audiobooks needed. This project gives your scattered `.m4b`, `.mp3`, `.flac`, and `.ogg` files the Marie Kondo treatment — sorting, organizing, enriching, and gracefully logging every step like a well-read librarian with a bash shell and too much coffee.

## 📦 What It Does

- 📚 Scans folders full of chaos (audiobook files)
- 🧹 Extracts and validates metadata from:
  - Folder/File names
  - `metadata.json`, `.opf`, `.nfo`, `desc.txt`, `reader.txt`
  - Audio tags via `mutagen`
  - (Coming Soon) Online lookups: Open Library, Audible, Google Books
- 🗃️ Organizes your books into `/Author/Book Title/` or `/Author/Series/# Book Title/`
- 🧪 Tracks processed content using JSON or SQLite
- ♻️ Skips duplicates, supports dry-run, and handles extras
- 🐳 Works in a Docker container or natively via CLI

---

## 🚀 Quick Start

### Option 1: Native Bash CLI

```bash
./organize_audiobooks.sh --input /your/input --output /your/output --dry-run
```

You can override most settings using:

- CLI arguments
- A `.env` file
- Environment variables

### Option 2: Docker (Recommended for Unraid or daemonized runs)

```bash
docker run \
  -v /your/input:/input \
  -v /your/output:/output \
  -v /your/config:/config \
  --env-file .env \
  audiobookshelf-tools
```

---

## ⚙️ .env Configuration

Copy `tests/test-env` to `.env` and edit as needed:

| Variable         | Description |
|------------------|-------------|
| `INPUT_PATH`     | Directory containing unorganized audiobooks |
| `OUTPUT_PATH`    | Destination for structured output |
| `CONFIG_PATH`    | Folder to store config & tracking db |
| `LOG_LEVEL`      | Set to `debug` for maximum verbosity |
| `TRACKING_MODE`  | `JSON` (default), `SQLITE`, `NONE`, or `MOVE` |
| `INCLUDE_EXTRAS` | `true` to move extras like cover art, `false` to ignore |
| `DUPLICATE_POLICY` | `skip`, `overwrite`, or `versioned` (default with up to 5 copies) |

---

## 🧪 Running Tests

To validate everything works:

```bash
./tests/run_all_tests.sh
```

This script:

- Generates test audiobook folders with mixed metadata
- Logs everything to `./tests/logs`
- Runs `organize_audiobooks.sh` in debug mode

Want to remove test content?

```bash
./tests/generate_test_audiobooks.sh --clean
```

---

## 🧩 Project Structure

```
.
├── organize_audiobooks.sh       # Main CLI wrapper
├── lib/
│   ├── config.sh                # Load .env, defaults
│   ├── filesystem.sh            # Safe file operations
│   ├── logging.sh               # Pretty log output with emojis
│   ├── metadata.sh              # Metadata extraction and fallback
│   └── tracking.sh              # JSON/SQLite-based state tracking
├── tests/
│   ├── run_all_tests.sh         # Full validation runner
│   ├── generate_test_audiobooks.sh # Generates input chaos
│   ├── logs/                    # Where test logs are stored
│   └── test-env                 # Sample .env config
├── Dockerfile                   # Container support
├── docker-compose.yml          # Optional container orchestration
├── README.md                    # You are here
└── manifest.json                # Features, options, tracking
```

---

## 🧠 Design Philosophy

- **Modular Bash-first**: Clean, portable shell code first, with occasional Perl one-liners or Python helpers when necessary.
- **Debug-friendly**: `DebugEcho` ensures you always know what the script is thinking. It's like telepathy, but bashier.
- **Low-risk behavior**: Dry runs, logging, non-destructive by default.
- **Extensible**: Easily adapted to new file types, metadata sources, or naming conventions.
- **Daemon-capable**: Built to run forever, peacefully ingesting the audiobook chaos of your NAS.

---

## ❓ FAQ

> **Q: What happens to unprocessable books?**  
> A: They go into an `Unorganized` subfolder under `OUTPUT_PATH`, and we log the reason they couldn’t be sorted. Some mysteries aren't meant to be solved.

> **Q: Why not just use bash -x for debugging?**  
> A: Because `DebugEcho` is cuter and far less overwhelming. Plus, we like to know *where* in the script we are, not just *how deep in the call stack we've fallen*.

---

## 🙌 Contributors Welcome

PRs, issues, and clever audiobook test cases are all welcome. We encourage you to add your own bizarre metadata formats for us to tackle!

---

## 📅 Coming Soon

- 🔎 Online metadata lookup via APIs
- 🔁 Container loop mode with schedule support
- 🧼 Cleaner `.env` validation
- 📜 Book title/author/narrator normalization

---

**Happy Listening. Happy Organizing.**  
— *The Bash Whisperer Team*

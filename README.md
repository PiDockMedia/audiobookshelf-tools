# Audiobookshelf Tools

## Quick Start 🚀  
Run this container from Docker Hub:

```sh
docker run --rm \
  -v /your/input:/input:ro \
  -v /your/output:/output \
  -v /your/config:/config \
  --env-file /your/.env \
  pidockmedia/audiobookshelf-tools
```

This containerized toolchain ingests raw audiobook folders from a read-only `/input` directory, gathers structure and optional hints, sends metadata analysis to an AI API (OpenAI or local Ollama), and organizes high-confidence results into `/output` using Audiobookshelf naming conventions. 🤖📂📊

## Features

- 🔒 Zero modification to `/input`
- 📌 Tracker to avoid repeat or low-confidence processing
- 🔁 `.force_process` override per folder
- 🧠 `metadata_hint.txt` to improve AI guesses
- 🧪 Dry-run, debug, and pause modes
- 📁 Follows [linuxserver.io](https://docs.linuxserver.io/general/containerbasics/) best practices using `/config` for state

## Folder Layout

```sh
/config              # Holds tracker.json and any future configs
/input               # Read-only folder where new books appear
/output              # Organized, renamed, copied output
/tests               # Developer test input/output
```

## AI Integration

- 🌐 `AI_ENDPOINT` and `AI_MODEL` are defined via `.env`
- 🤖 Compatible with OpenAI API or [Ollama](https://ollama.com/)

## Supported Controls

- 🛠️ `.force_process` – re-process a folder regardless of confidence or history
- 🧾 `metadata_hint.txt` – user hints to improve AI extraction (author, year, etc)

## Usage

### Build and run

```sh
docker compose up --build
```

Or using Docker CLI directly:

```sh
docker run --rm \
  -v /path/to/input:/input:ro \
  -v /path/to/output:/output \
  -v /path/to/config:/config \
  --env-file /path/to/.env \
  audiobookshelf-tools
```

### Environment (.env file – you must create this manually) 🌍🛠️📄

Create a `.env` file and populate it like so:

```ini
INPUT_PATH=/input
OUTPUT_PATH=/output
CONFIG_PATH=/config
DRY_RUN=false
DEBUG=false
PAUSE=false
AI_ENDPOINT=http://localhost:11434/api
AI_MODEL=mistral:instruct
```

## Requirements

- 🐳 Docker
- 🧠 AI endpoint (OpenAI or local Ollama with compatible models)

## Notes

- 🗂️ All files are scanned and tracked by relative path
- ❗ Books with low AI confidence are marked skipped until manually improved
- 🔒 Processed files remain ignored unless `.force_process` is added or removed

## Roadmap

- 📦 Containerize Ollama support
- 🌐 Add web UI for manual review of skipped/low-confidence items
- 🖼️ Extend AI query to include cover image and series validation
- 📂 Extend the toolset to folder rename an existing audiobookshelf library

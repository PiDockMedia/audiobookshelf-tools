# Audiobook Organizer

This tool scans a directory for audiobooks, sends metadata to an AI API, and organizes them into a structured output folder based on returned metadata.

## Usage

```bash
docker-compose up --build
```

## Environment Variables
- `INPUT_PATH` – path to scan for new audiobooks
- `OUTPUT_PATH` – where to copy organized books
- `AI_ENDPOINT` – AI inference endpoint
- `AI_MODEL` – model name or identifier
- `DEBUG` – enable debug output ("true" or "false")
- `DRY_RUN` – do not copy files, simulate only

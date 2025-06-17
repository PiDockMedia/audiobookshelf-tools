# AI Audiobookshelf Tools

A set of tools tools for organizing, cleaning, and interracting with Audiobookshelf.

## Features

### Organize for import:

- **Multi-source Metadata Extraction**
  - Embedded audio metadata (using ffprobe)
  - Folder structure analysis
  - Supporting files (cover, description, NFO)
  - Audio file analysis

- **Intelligent Organization**
  - AI-powered metadata analysis
  - Confidence scoring for extracted metadata
  - Series detection and ordering
  - Narrator identification

- **Flexible Processing**
  - Support for multiple audio formats (m4b, mp3, flac, ogg, wav)
  - Dry-run mode for testing
  - Debug logging
  - Pause points for verification

## Quick Start

1. **Prerequisites**
   ```bash
   # Required tools
   ffmpeg    # For audio processing and metadata extraction
   ffprobe   # For metadata analysis
   jq        # For JSON processing
   ```

2. **Basic Usage**
   ```bash
   # Organize audiobooks in a directory
   ./organize_audiobooks.sh --input=/path/to/audiobooks

   # Test run without making changes
   ./organize_audiobooks.sh --input=/path/to/audiobooks --dry-run

   # Debug mode with pauses
   ./organize_audiobooks.sh --input=/path/to/audiobooks --debug --pause
   ```

3. **Configuration**
   - Copy `.env.example` to `.env`
   - Adjust settings as needed:
     ```
     INPUT_PATH=/path/to/audiobooks
     OUTPUT_PATH=/path/to/organized
     CONFIG_PATH=/path/to/config
     LOG_LEVEL=debug
     ```

## Architecture

### Core Components

1. **Metadata Extraction**
   - `scan_input_and_prepare_ai_bundles`: Scans input directory and extracts metadata
   - Uses ffprobe for embedded audio metadata
   - Analyzes folder structure and supporting files

2. **AI Analysis**
   - Processes extracted metadata using AI
   - Provides confidence scores for each field
   - Handles conflicting information

3. **Organization**
   - Creates organized directory structure
   - Moves files to appropriate locations
   - Maintains tracking database

### Data Flow

1. Input Directory Scan
   - Extract embedded metadata
   - Analyze folder structure
   - Process supporting files

2. AI Bundle Creation
   - Generate JSONL file with all metadata
   - Create comprehensive prompt
   - Prepare for AI analysis

3. Organization
   - Process AI results
   - Create organized structure
   - Move files to final locations

## Containerization (Planned)

The tool will be containerized to ensure consistent behavior across environments:

```dockerfile
# Base image with required tools
FROM ubuntu:22.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    jq \
    && rm -rf /var/lib/apt/lists/*

# Copy scripts
COPY organize_audiobooks.sh /usr/local/bin/
COPY tests/ /tests/

# Set up environment
WORKDIR /audiobooks
VOLUME ["/audiobooks/input", "/audiobooks/output"]

# Default command
ENTRYPOINT ["/usr/local/bin/organize_audiobooks.sh"]
```

Usage with Docker:
```bash
docker run -v /path/to/audiobooks:/audiobooks/input -v /path/to/output:/audiobooks/output audiobook-organizer
```

## Testing

Run the test suite:
```bash
./tests/run_all_tests.sh
```

Options:
- `--clean`: Remove old test data
- `--with-tts`: Generate test files with text-to-speech
- `--dry-run`: Test without making changes
- `--pause`: Add pause points for verification

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests
5. Submit a pull request

## License

MIT License - see LICENSE file for details

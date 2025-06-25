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

## Example Output Directory Structure (Full Detail)
```
/OrganizedAudiobooks/
  Austen, Jane/
    1813 - Pride and Prejudice {Elizabeth Klett}/
      Pride and Prejudice.m4b
      cover.jpg
      description.txt
  Doyle, Arthur Conan/
    Sherlock Holmes/
      Book 1 - 1892 - The Adventures of Sherlock Holmes {David Clarke}/
        The Adventures of Sherlock Holmes.m4b
        cover.jpg
        description.txt
  Melville, Herman/
    1851 - Moby Dick {Stewart Wills}/
      Disc 1/
        Moby Dick - Disc 1.m4b
      Disc 2/
        Moby Dick - Disc 2.m4b
      description.txt
  Sun, Tzu/
    The Art of War/
      1910 - The Art of War {Lionel Giles}/
        The Art of War.m4b
        The Art of War.mp3
        The Art of War.flac
        description.txt
  Aesop/
    Aesop's Fables/
      Aesop's Fables.m4b
      description.txt
```

## AI Bundle Format Requirements

- The AI bundle (`ai_input.jsonl`) **must** be in valid JSONL format: one single-line JSON object per line.
- Do **not** use pretty-printed or multi-line JSON.
- The `input_path` field should use only the minimal folder path (e.g., `"Austen, Jane/1813 - Pride and Prejudice {Elizabeth Klett}"`), not absolute or test harness paths.

## Troubleshooting AI Bundle Issues

- If you see FFmpeg errors about 'Unable to choose an output format for ... .tmp', ensure the temp file extension preserves the original audio extension (e.g., .tmp.m4b) so FFmpeg can infer the format.
- If you see many jq parse errors or 'Source directory not found' during test runs, ensure the AI bundle (`ai_input.jsonl`) is present, valid, and matches the generated test data. The test harness now auto-generates a simulated bundle after test data generation.
- If `ai_input.jsonl` is overwritten with pretty-printed JSON, check for post-processing steps or scripts that may be modifying the file after test data generation. The file must remain single-line JSONL.

## Automatic Verification Step

After generating the simulated AI bundle, the test harness automatically checks that:
- Every line in `ai_input.jsonl` is valid single-line JSON.
- The number of valid lines matches the number of lines in the file.
- No `input_path` contains absolute or test harness paths.

If any issues are detected, a warning is printed in the test log.

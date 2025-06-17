# 🧪 tests/

If it breaks here, it won't break your actual audiobooks. Test scripts, fake books, and possibly sarcastic logs live here.

# Test Suite Documentation

This directory contains the test suite for the AI Audiobook Organizer. The test suite is designed to verify the functionality of the organizer script using realistic test data.

## Test Data Generation

The test suite generates realistic audiobook test data with the following characteristics:

### Test Books

1. **Series Books**
   - "Ada Palmer - Terra Ignota 1 - Too Like the Lightning"
   - "Ada Palmer - Terra Ignota 1 - Too Like the Lightning (Dramatized)"
   - Both include embedded metadata with series information

2. **Single Books**
   - "Jane Doe - The Haiku Adventure"
   - "John Smith - Jungle Fire"
   - "Loud Author - Loud Book"
   - Each with unique metadata patterns

3. **Unknown Books**
   - "Unknown_0000_Mystery_Title"
   - No metadata, testing fallback behavior

### Metadata Features

Each test book includes:
- Embedded audio metadata (using ffmpeg)
- Various audio formats (m4b, mp3, flac, ogg, wav)
- Supporting files (cover.jpg, description.txt, info.nfo)
- Realistic folder structures

### Metadata Fields

Test data includes these metadata fields:
- Basic Info: title, artist, author, narrator
- Series Info: album, series, series_index
- Additional Info: publisher, year, genre, comment

## Running Tests

### Basic Usage

```bash
# Run all tests
./run_all_tests.sh

# Clean old test data and run
./run_all_tests.sh --clean

# Generate test files with text-to-speech
./run_all_tests.sh --with-tts
```

### Test Options

- `--clean`: Remove old test data before running
- `--with-tts`: Generate test files with text-to-speech content
- `--dry-run`: Test without making changes
- `--pause`: Add pause points for verification

### Test Directory Structure

```
tests/
├── run_all_tests.sh           # Main test runner
├── test-audiobooks/          # Test data directory
│   ├── input/               # Input test data
│   │   ├── ai_bundles/     # AI bundle output
│   │   └── [test books]    # Generated test books
│   └── output/             # Organized output
└── README.md               # This file
```

## Test Data Generation Process

1. **Directory Creation**
   - Creates test book directories
   - Sets up realistic folder structures

2. **Audio File Generation**
   - Generates test audio files
   - Adds embedded metadata
   - Creates multiple formats

3. **Supporting Files**
   - Generates cover images
   - Creates description files
   - Adds NFO files

4. **Metadata Injection**
   - Embeds metadata in audio files
   - Creates realistic naming patterns
   - Tests various metadata combinations

## Adding New Tests

1. **New Test Book**
   ```bash
   # Add to generate_test_data function in run_all_tests.sh
   mkdir -p "$OUTDIR/input/New Author - New Book"
   # Generate files and add metadata
   ```

2. **New Test Case**
   ```bash
   # Add to run_all_tests.sh
   test_new_feature() {
     # Test implementation
   }
   ```

## Test Coverage

The test suite verifies:
- Metadata extraction
- AI bundle creation
- File organization
- Error handling
- Edge cases

## Debugging Tests

1. **Enable Debug Output**
   ```bash
   ./run_all_tests.sh --debug
   ```

2. **Check Test Data**
   ```bash
   # View generated test data
   ls -R ./test-audiobooks/input/
   
   # Check metadata
   ffprobe -v quiet -print_format json -show_format ./test-audiobooks/input/*/*.m4b
   ```

3. **Verify AI Bundles**
   ```bash
   # View generated AI bundles
   cat ./test-audiobooks/input/ai_bundles/pending/ai_input.jsonl
   ```

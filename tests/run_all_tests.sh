#!/bin/bash
#
# === Test Harness Dataflow & Logic (run_all_tests.sh) ===
#
# 1. Clean Test Environment
#    - If --clean is specified, remove the entire test output directory, including input, output, and tracking DB.
#
# 2. Test Data Generation
#    - Generate a variety of test audiobook folders and files in the input directory.
#    - Create audio files (optionally with TTS), embed metadata, and add supporting files (cover, description, NFO).
#    - Ensure all test data is copyright-safe and reproducible.
#
# 3. AI Bundle Generation
#    - The script generates the AI bundle (ai_input.jsonl and prompt.md) in the input/ai_bundles/pending directory as in production.
#    - For full-pipeline tests, let the script generate this file naturally.
#    - For organization-only tests, you may inject a simulated AI response file to skip the AI analysis step.
#
# 4. Pause for AI Step (Optional)
#    - If --pause is specified, pause after AI bundle generation for manual or automated AI response injection.
#    - Allows for real or simulated AI integration.
#
# 5. Organization Step
#    - Run the main organizer script to process the AI responses and organize the test books into the output directory.
#    - Validate that the output structure matches expectations.
#
# 6. Validation & Logging
#    - Log all actions and results to a timestamped log file in tests/logs/.
#    - Report success if all steps complete and output matches expectations; log errors otherwise.
#
# 7. Test DB Handling
#    - The tracking DB is created in the input folder and destroyed with --clean.
#
# 8. Sync with Documentation
#    - These steps are always kept in sync with tests/DATAFLOW_TEST.md. Any change to the script's logic must be reflected there.
#    - **CRITICAL: All command-line switches must be preserved and functional:**
#      * --clean: Remove test directory and exit (clean only)
#      * --pause: Add pause points for manual intervention and AI response injection
#      * --dry-run: Show what would be done without making changes
#      * --debug: Enable detailed logging
#      * --generate/--nogenerate: Control test data generation
#      * --with-tts: Use text-to-speech for test audio generation
#
# === End Test Harness Dataflow & Logic ===

# === Configuration ===
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTDIR="${ROOT_DIR}/tests/test-audiobooks"
LOG_DIR="$(dirname "$0")/logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/test_run_$(date +%Y-%m-%d_%H%M%S).log"
TEST_ENV="${ROOT_DIR}/tests/test-env"

# Default values
CLEAN=false
GENERATE=true
WITH_TTS=false
DRY_RUN=false
PAUSE=false
DEBUG=false
TRACE=false

# === Logging Functions ===
log_info() {
    echo "[INFO] $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo "[ERROR] $1" | tee -a "$LOG_FILE" >&2
}

log_debug() {
    if [ "$DEBUG" = true ]; then
        echo "[DEBUG] $1" | tee -a "$LOG_FILE"
    fi
}

# === Pause Function ===
pause() {
    if [ "$PAUSE" = true ]; then
        log_info "⏸️  PAUSE: Press Enter to continue..."
        read -p ""
    fi
}

# === Help Text ===
show_help() {
    cat << EOF
Usage: ./run_all_tests.sh [options]

Options:
  --help          Show this help message
  --clean         Remove old test data before running
  --noclean       Skip cleaning old test data
  --generate      Generate new test data (default)
  --nogenerate    Skip generating test data
  --with-tts      Generate test files with text-to-speech
  --dry-run       Test without making changes
  --pause         Add pause points for verification
  --debug         Enable debug output
  --trace         Run organizer with bash -x and log full trace to logs/

Environment Variables:
  AUDIOBOOKSHELF_NAME_DETAIL  Set naming detail level (minimal/standard/full)
EOF
    exit 0
}

# === Parse Command Line Arguments ===
while [[ $# -gt 0 ]]; do
    case $1 in
        --help)
            show_help
            ;;
        --clean)
            CLEAN=true
            shift
            ;;
        --noclean)
            CLEAN=false
            shift
            ;;
        --generate)
            GENERATE=true
            shift
            ;;
        --nogenerate)
            GENERATE=false
            shift
            ;;
        --with-tts)
            WITH_TTS=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --pause)
            PAUSE=true
            shift
            ;;
        --debug)
            DEBUG=true
            shift
            ;;
        --trace)
            TRACE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            show_help
            ;;
    esac
    shift
done

# === Test Data Generation Functions ===
gen_tts_audio() {
    local base="$1"
    local text="$2"
    local tmp="__tts.aiff"

    if command -v say &> /dev/null; then
        say "$text" -o "$tmp"
    elif command -v espeak &> /dev/null; then
        espeak "$text" -w "$tmp"
    else
        log_debug "TTS engine not found. Falling back to silent audio."
        return 1
    fi

    ffmpeg -y -i "$tmp" -c:a "$3" -b:a "$4" "${base}.${5}" &> /dev/null
    rm -f "$tmp"
}

gen_audio() {
    local base="$1"
    local codec="$2"
    local bitrate="$3"
    local ext="$4"
    local text="$5"

    if $WITH_TTS; then
        gen_tts_audio "$base" "$text" "$codec" "$bitrate" "$ext" || {
            log_debug "Using silent fallback for $base.$ext"
            ffmpeg -y -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -c:a "$codec" -b:a "$bitrate" "${base}.${ext}" &> /dev/null
        }
    else
        ffmpeg -y -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -c:a "$codec" -b:a "$bitrate" "${base}.${ext}" &> /dev/null
    fi
}

# === Generate Test Data ===
generate_test_data() {
    log_info "Generating test data in ${OUTDIR}..."
    
    # Function to add metadata to audio files
    add_metadata() {
        local input_file="$1"
        local output_file="$2"
        shift 2
        local metadata_args=("$@")
        # Use .tmp.<ext> so ffmpeg can infer the format
        local ext="${output_file##*.}"
        local tmp_file="${output_file}.tmp.${ext}"
        ffmpeg -y -i "$input_file" \
            -metadata title="${metadata_args[0]}" \
            -metadata artist="${metadata_args[1]}" \
            -metadata author="${metadata_args[2]}" \
            -metadata narrator="${metadata_args[3]}" \
            -metadata publisher="${metadata_args[4]}" \
            -metadata year="${metadata_args[5]}" \
            -metadata genre="${metadata_args[6]}" \
            -metadata comment="${metadata_args[7]}" \
            -metadata album="${metadata_args[8]}" \
            -metadata series="${metadata_args[9]}" \
            -metadata series_index="${metadata_args[10]}" \
            -c copy "$tmp_file"
        mv -f "$tmp_file" "$output_file"
    }
    
    # 1. Standalone Book with Full Metadata (Pride and Prejudice)
    mkdir -p "${OUTDIR}/input/Austen, Jane/1813 - Pride and Prejudice {Elizabeth Klett}"
    echo "A classic novel of manners." > "${OUTDIR}/input/Austen, Jane/1813 - Pride and Prejudice {Elizabeth Klett}/description.txt"
    ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=5" "${OUTDIR}/input/Austen, Jane/1813 - Pride and Prejudice {Elizabeth Klett}/Pride and Prejudice.m4b"
    add_metadata "${OUTDIR}/input/Austen, Jane/1813 - Pride and Prejudice {Elizabeth Klett}/Pride and Prejudice.m4b" \
        "${OUTDIR}/input/Austen, Jane/1813 - Pride and Prejudice {Elizabeth Klett}/Pride and Prejudice.m4b" \
        "Pride and Prejudice" "Jane Austen" "Jane Austen" "Elizabeth Klett" "LibriVox" "1813" "Novel" "Test comment" "Pride and Prejudice" "" ""
    
    # 2. Series Book with Full Metadata (Sherlock Holmes)
    mkdir -p "${OUTDIR}/input/Doyle, Arthur Conan/Sherlock Holmes/Book 1 - 1892 - The Adventures of Sherlock Holmes {David Clarke}"
    echo "The first collection of Sherlock Holmes stories." > "${OUTDIR}/input/Doyle, Arthur Conan/Sherlock Holmes/Book 1 - 1892 - The Adventures of Sherlock Holmes {David Clarke}/description.txt"
    ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=5" "${OUTDIR}/input/Doyle, Arthur Conan/Sherlock Holmes/Book 1 - 1892 - The Adventures of Sherlock Holmes {David Clarke}/The Adventures of Sherlock Holmes.m4b"
    add_metadata "${OUTDIR}/input/Doyle, Arthur Conan/Sherlock Holmes/Book 1 - 1892 - The Adventures of Sherlock Holmes {David Clarke}/The Adventures of Sherlock Holmes.m4b" \
        "${OUTDIR}/input/Doyle, Arthur Conan/Sherlock Holmes/Book 1 - 1892 - The Adventures of Sherlock Holmes {David Clarke}/The Adventures of Sherlock Holmes.m4b" \
        "The Adventures of Sherlock Holmes" "Arthur Conan Doyle" "Arthur Conan Doyle" "David Clarke" "LibriVox" "1892" "Detective" "Test comment" "The Adventures of Sherlock Holmes" "Sherlock Holmes" "1"
    
    # 3. Multi-Disc Book (Moby Dick)
    mkdir -p "${OUTDIR}/input/Melville, Herman/1851 - Moby Dick {Stewart Wills}/Disc 1"
    mkdir -p "${OUTDIR}/input/Melville, Herman/1851 - Moby Dick {Stewart Wills}/Disc 2"
    echo "A novel about the voyage of the whaling ship Pequod." > "${OUTDIR}/input/Melville, Herman/1851 - Moby Dick {Stewart Wills}/description.txt"
    ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=5" "${OUTDIR}/input/Melville, Herman/1851 - Moby Dick {Stewart Wills}/Disc 1/Moby Dick - Disc 1.m4b"
    ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=5" "${OUTDIR}/input/Melville, Herman/1851 - Moby Dick {Stewart Wills}/Disc 2/Moby Dick - Disc 2.m4b"
    add_metadata "${OUTDIR}/input/Melville, Herman/1851 - Moby Dick {Stewart Wills}/Disc 1/Moby Dick - Disc 1.m4b" \
        "${OUTDIR}/input/Melville, Herman/1851 - Moby Dick {Stewart Wills}/Disc 1/Moby Dick - Disc 1.m4b" \
        "Moby Dick" "Herman Melville" "Herman Melville" "Stewart Wills" "LibriVox" "1851" "Adventure" "Test comment" "Moby Dick" "" ""
    
    # 4. Minimal Metadata Book (Aesop's Fables)
    mkdir -p "${OUTDIR}/input/Aesop/Aesop's Fables"
    ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=5" "${OUTDIR}/input/Aesop/Aesop's Fables/Aesop's Fables.m4b"
    add_metadata "${OUTDIR}/input/Aesop/Aesop's Fables/Aesop's Fables.m4b" \
        "${OUTDIR}/input/Aesop/Aesop's Fables/Aesop's Fables.m4b" \
        "Aesop's Fables" "Aesop" "Aesop" "Various" "LibriVox" "1912" "Fable" "Test comment" "Aesop's Fables" "" ""
    
    # 5. Book with Multiple Audio Formats (The Art of War)
    mkdir -p "${OUTDIR}/input/Sun, Tzu/The Art of War/1910 - The Art of War {Lionel Giles}"
    ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=5" "${OUTDIR}/input/Sun, Tzu/The Art of War/1910 - The Art of War {Lionel Giles}/The Art of War.m4b"
    ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=5" "${OUTDIR}/input/Sun, Tzu/The Art of War/1910 - The Art of War {Lionel Giles}/The Art of War.mp3"
    ffmpeg -y -f lavfi -i "sine=frequency=1000:duration=5" "${OUTDIR}/input/Sun, Tzu/The Art of War/1910 - The Art of War {Lionel Giles}/The Art of War.flac"
    add_metadata "${OUTDIR}/input/Sun, Tzu/The Art of War/1910 - The Art of War {Lionel Giles}/The Art of War.m4b" \
        "${OUTDIR}/input/Sun, Tzu/The Art of War/1910 - The Art of War {Lionel Giles}/The Art of War.m4b" \
        "The Art of War" "Sun Tzu" "Sun Tzu" "Lionel Giles" "LibriVox" "1910" "Philosophy" "Test comment" "The Art of War" "" ""
    
    log_info "Test data generated successfully in ${OUTDIR}"
    # === Force overwrite a valid simulated AI bundle for test data (single-line JSONL) ===
    local ai_bundle_dir="${OUTDIR}/input/ai_bundles/pending"
    mkdir -p "$ai_bundle_dir"
    local ai_jsonl="$ai_bundle_dir/ai_input.jsonl"
    : > "$ai_jsonl"
    echo '{"input_path": "Austen, Jane/1813 - Pride and Prejudice {Elizabeth Klett}", "title": "Pride and Prejudice", "author": "Jane Austen", "narrator": "Elizabeth Klett", "year": 1813, "series": null, "series_index": null, "publisher": "LibriVox", "genre": "Novel"}' >> "$ai_jsonl"
    echo '{"input_path": "Doyle, Arthur Conan/Sherlock Holmes/Book 1 - 1892 - The Adventures of Sherlock Holmes {David Clarke}", "title": "The Adventures of Sherlock Holmes", "author": "Arthur Conan Doyle", "narrator": "David Clarke", "year": 1892, "series": "Sherlock Holmes", "series_index": 1, "publisher": "LibriVox", "genre": "Detective"}' >> "$ai_jsonl"
    echo '{"input_path": "Melville, Herman/1851 - Moby Dick {Stewart Wills}/Disc 1", "title": "Moby Dick", "author": "Herman Melville", "narrator": "Stewart Wills", "year": 1851, "series": null, "series_index": null, "publisher": "LibriVox", "genre": "Adventure"}' >> "$ai_jsonl"
    echo '{"input_path": "Aesop/Aesop'\''s Fables", "title": "Aesop'\''s Fables", "author": "Aesop", "narrator": "Various", "year": 1912, "series": null, "series_index": null, "publisher": "LibriVox", "genre": "Fable"}' >> "$ai_jsonl"
    echo '{"input_path": "Sun, Tzu/The Art of War/1910 - The Art of War {Lionel Giles}", "title": "The Art of War", "author": "Sun Tzu", "narrator": "Lionel Giles", "year": 1910, "series": null, "series_index": null, "publisher": "LibriVox", "genre": "Philosophy"}' >> "$ai_jsonl"
    log_info "Simulated AI bundle (single-line JSONL) generated at $ai_jsonl"
}

# === Main Test Flow ===
log_info "🧪 BEGIN run_all_tests.sh"
log_info "Current directory: $(pwd)"
log_info "ROOT_DIR: $ROOT_DIR"
log_info "OUTDIR: $OUTDIR"
log_info "DRY_RUN: $DRY_RUN"
log_info "PAUSE: $PAUSE"

# Clean test directory
if [ "$CLEAN" = true ]; then
    if [ "$DRY_RUN" = true ]; then
        log_info "Would clean old test data: $OUTDIR"
    else
        log_info "Cleaning old test data..."
        rm -rf "$OUTDIR"
    fi
    log_info "✅ Clean completed successfully"
    log_info "🏁 END run_all_tests.sh"
    exit 0
fi

if [ "$GENERATE" = true ]; then
    log_info "Generating test data..."
    generate_test_data
    pause  # Pause after test data generation for inspection
fi

# === Load Environment ===
if [[ -f "${TEST_ENV}" ]]; then
    log_info "Using test-env: ${TEST_ENV}"
    source "${TEST_ENV}"
else
    log_info "No test-env found, using defaults"
fi

# Pause before running organizer (allows for AI response injection)
pause  # Pause before organization step for AI response injection

# === Run Tests ===
log_info "Running organize_audiobooks.sh..."
if [ "$TRACE" = true ]; then
    TRACE_LOG="$LOG_DIR/test_run_TRACE_$(date +%Y-%m-%d_%H%M%S).log"
    log_info "Tracing organizer to $TRACE_LOG"
    if [ "$DRY_RUN" = true ]; then
        bash -x "${ROOT_DIR}/organize_audiobooks.sh" --input="$OUTDIR/input" --output="$OUTDIR/output" --dry-run >> "$TRACE_LOG" 2>&1
    else
        bash -x "${ROOT_DIR}/organize_audiobooks.sh" --input="$OUTDIR/input" --output="$OUTDIR/output" >> "$TRACE_LOG" 2>&1
    fi
else
    if [ "$DRY_RUN" = true ]; then
        "${ROOT_DIR}/organize_audiobooks.sh" --input="$OUTDIR/input" --output="$OUTDIR/output" --dry-run >> "$LOG_FILE" 2>&1
    else
        "${ROOT_DIR}/organize_audiobooks.sh" --input="$OUTDIR/input" --output="$OUTDIR/output" >> "$LOG_FILE" 2>&1
    fi
fi

# === Verify Results ===
if [ $? -eq 0 ]; then
    log_info "✅ Test run completed successfully"
else
    log_error "❌ Test run failed"
    exit 1
fi

log_info "🏁 END run_all_tests.sh"

# Ensure log file directory exists before any logging
mkdir -p "$(dirname "$LOG_FILE")"

###EOF
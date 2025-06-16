#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.."
LOG_DIR="${ROOT_DIR}/tests/logs"
LOG_FILE="${LOG_DIR}/test_run_$(date +%Y-%m-%d_%H%M).log"
TEST_ENV="${ROOT_DIR}/.env"
OUTDIR="tests/test-audiobooks"
INDIR="$OUTDIR/input"
OUTTEST="$OUTDIR/output"
USE_TTS=false
GENERATE_ONLY=false
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --with-tts) USE_TTS=true ;;
    --generate) GENERATE_ONLY=true ;;
    --dry-run) DRY_RUN=true ;;
    --clean) 
      echo "🧹 Cleaning old test data..."
      rm -rf "$OUTDIR"
      exit 0
      ;;
    *) echo "Unknown option: $arg"; exit 1 ;;
  esac
done

mkdir -p "${LOG_DIR}"

echo "🧪 BEGIN run_all_tests.sh" | tee "${LOG_FILE}"

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
    echo "⚠️  TTS engine not found. Falling back to silent audio."
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

  if $USE_TTS; then
    gen_tts_audio "$base" "$text" "$codec" "$bitrate" "$ext" || {
      echo "🔇 Using silent fallback for $base.$ext"
      ffmpeg -y -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -c:a "$codec" -b:a "$bitrate" "${base}.${ext}" &> /dev/null
    }
  else
    ffmpeg -y -f lavfi -i anullsrc=r=44100:cl=mono -t 1 -c:a "$codec" -b:a "$bitrate" "${base}.${ext}" &> /dev/null
  fi
}

generate_test_data() {
  echo "📁 Generating test audiobooks in: $INDIR" | tee -a "${LOG_FILE}"
  mkdir -p "$INDIR" "$OUTTEST"
  cd "$INDIR"

  mkdir -p "Jane Doe - The Haiku Adventure"
  gen_audio "Jane Doe - The Haiku Adventure/Chapter" aac 64k m4b "Haiku: Light breeze whispers. Audiobookshelf test file. Metadata waits."

  mkdir -p "Ada Palmer - Terra Ignota 1 - Lightning"
  gen_audio "Ada Palmer - Terra Ignota 1 - Lightning/Book One" libvorbis 64k ogg "Book one in a sci-fi saga. With cover art."
  echo "cover.jpg" > "Ada Palmer - Terra Ignota 1 - Lightning/cover.jpg"

  mkdir -p "John Smith - Jungle Fire"
  for i in {1..3}; do
    gen_audio "John Smith - Jungle Fire/Chapter $(printf '%02d' $i)" libmp3lame 64k mp3 "Chapter $i of Jungle Fire. Jungle sounds ahead."
  done
  echo "<nfo>Jungle metadata</nfo>" > "John Smith - Jungle Fire/notes.nfo"

  mkdir -p "Unknown_0000_Mystery_Title"
  gen_audio "Unknown_0000_Mystery_Title/random_book" flac 64k flac "Unknown title. Unknown author. Still a valid book."

  mkdir -p "Loud Author - Loud Book"
  gen_audio "Loud Author - Loud Book/OnlyChapter" pcm_s16le 128k wav "This book is loud. Turn down the volume."

  mkdir -p "Ada Palmer - Terra Ignota 1 - Too Like the Lightning (Dramatized)"
  gen_audio "Ada Palmer - Terra Ignota 1 - Too Like the Lightning (Dramatized)/Too Like the Lightning [B09G8FTD69]" aac 64k m4b "Dramatized Lightning. Full cast recording."
  echo "cover.jpg" > "Ada Palmer - Terra Ignota 1 - Too Like the Lightning (Dramatized)/cover.jpg"
  echo "Dramatized narration." > "Ada Palmer - Terra Ignota 1 - Too Like the Lightning (Dramatized)/desc.txt"

  echo "✅ Test data ready. Run with '--clean' to remove or '--with-tts' for spoken content." | tee -a "${LOG_FILE}"
}

# === Main Test Flow ===
if [[ "$GENERATE_ONLY" == "true" ]]; then
  generate_test_data
  exit 0
fi

# === Step 1: Clean previous test data
echo "🔄 Cleaning previous test data..." | tee -a "${LOG_FILE}"
rm -rf "$OUTDIR"

# === Step 2: Generate new test data
generate_test_data

# === Step 3: Load .env or fallback
if [[ -f "${TEST_ENV}" ]]; then
  echo "[INFO] Using .env: ${TEST_ENV}" | tee -a "${LOG_FILE}"
else
  echo "[WARN] No .env found, using defaults" | tee -a "${LOG_FILE}"
fi

# === Step 4: Run organizer in debug mode
echo "🚀 Running organize_audiobooks.sh in debug mode..." | tee -a "${LOG_FILE}"
if [[ "$DRY_RUN" == "true" ]]; then
  bash "${ROOT_DIR}/organize_audiobooks.sh" --dry-run 2>&1 | tee -a "${LOG_FILE}"
else
  bash "${ROOT_DIR}/organize_audiobooks.sh" 2>&1 | tee -a "${LOG_FILE}"
fi

# === Step 5: Final Result
if [[ ${PIPESTATUS[0]} -eq 0 ]]; then
  echo "✅ Test run completed successfully." | tee -a "${LOG_FILE}"
else
  echo "❌ Test run FAILED. Check log: ${LOG_FILE}" | tee -a "${LOG_FILE}"
  exit 1
fi

echo "🏁 END run_all_tests.sh" | tee -a "${LOG_FILE}"

###EOF
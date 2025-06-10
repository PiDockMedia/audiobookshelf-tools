#!/usr/bin/env bash
set -eu -o pipefail

# Audiobookshelf Tools - Test Generator
# -------------------------------------
# Generates test audiobooks for metadata pipeline validation.
# Optional TTS support using 'say' (macOS) or 'espeak' (Linux).

OUTDIR="tests/test-audiobooks"
INDIR="$OUTDIR/input"
OUTTEST="$OUTDIR/output"
USE_TTS=false

# Parse optional arguments
for arg in "$@"; do
  if [[ "$arg" == "--with-tts" ]]; then
    USE_TTS=true
  elif [[ "$arg" == "--clean" ]]; then
    echo "🧹 Cleaning old test data..."
    rm -rf "$OUTDIR"
    exit 0
  fi
done

mkdir -p "$INDIR" "$OUTTEST"

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

echo "📁 Generating test audiobooks in: $INDIR"
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

echo "✅ Test data ready. Run with '--clean' to remove or '--with-tts' for spoken content."
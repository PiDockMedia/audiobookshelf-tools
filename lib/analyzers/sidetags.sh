#!/usr/bin/env bash
# Analyzer: sidetags.sh
# Purpose: Extract metadata from audio file tags using mutagen or similar tools
analyze_sidetags() {
  local file="$1"
  # TODO: Call Python helper for audio tag extraction
  echo '{"source": "sidetags", "author": "", "title": "", "series": "", "series_index": "", "narrator": ""}'
}

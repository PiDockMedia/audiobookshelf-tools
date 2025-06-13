#!/usr/bin/env bash
# Analyzer: openlibrary.sh
# Purpose: Use title/author guess to look up OpenLibrary data
analyze_openlibrary() {
  local title="$1"
  local author="$2"
  # TODO: Perform API query and format results
  echo '{"source": "openlibrary", "author": "", "title": "", "series": "", "series_index": "", "narrator": ""}'
}

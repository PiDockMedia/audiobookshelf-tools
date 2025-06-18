# DATAFLOW: AI Audiobook Organizer (Full Logic, always in sync with organize_audiobooks.sh)

1. Book Arrival & Initial Acceptance
   - When a new book folder or file appears in the INPUT_PATH, it is detected by the script.
   - The script adds an entry for the book in the tracking database (SQLite or JSON), marking its status as 'accepted'.

2. Ready for AI Scan
   - The script extracts all available metadata (embedded, folder, supporting files) and creates a JSONL entry for the book.
   - The book's status in the DB is updated to 'ready_for_ai'.

3. AI Scan Returned
   - When an AI response is available (either simulated or real), the script updates the DB entry to 'ai_returned'.
   - If the AI cannot determine metadata, the status is set to 'ai_failed', and the book is flagged for manual intervention.

4. Organization
   - For books with 'ai_returned' status, the script organizes (copies) them to the OUTPUT_PATH using the AI metadata.
   - The DB entry is updated to 'organized'.

5. Book Disappearance
   - If a book is removed from INPUT_PATH (external to this script), the script detects its absence and removes its entry from the DB.

6. DB Persistence
   - The tracking DB lives in the INPUT_PATH and persists across runs, except during test runs with --clean, which removes the input folder and DB.

7. Test Mode
   - In test mode, the DB is destroyed with the input folder on --clean.

---

(These steps are always kept in sync with the comments at the top of organize_audiobooks.sh. Any change to the script's logic must be reflected here.)

# DATAFLOW: AI Audiobook Organizer (Production)

This document describes the dataflow for the `organize_audiobooks.sh` script as used in production to organize audiobook collections using AI-powered metadata extraction and analysis.

---

## 1. Input Directory Structure
- **User provides an input directory** containing unorganized audiobook folders and files. These may include:
  - Audio files (various formats: .m4b, .mp3, .flac, etc.)
  - Cover images, description files, NFOs, etc.
  - Folder names may contain author, title, series, etc.

## 2. Metadata Extraction
- For each audiobook folder:
  - **Extract embedded metadata** from audio files using `ffprobe` (title, author, narrator, year, etc.).
  - **Scan folder and file names** for additional metadata (author, title, series, etc.).
  - **Collect supporting files** (cover images, description.txt, info.nfo, etc.).
  - **Aggregate all discovered metadata** into a structured JSON object for each book.

## 3. AI Bundle Preparation
- All metadata and file structure information is compiled into a single JSONL file (`ai_input.jsonl`).
- A comprehensive prompt (`prompt.md`) is generated to instruct the AI on how to analyze the books and extract the most reliable metadata.

## 4. AI Analysis (External Step)
- The JSONL and prompt are sent to an AI (e.g., ChatGPT) for analysis.
- The AI returns a response for each book, providing structured metadata (author, title, series, series index, narrator, etc.), confidence scores, and sources for each field.
- The AI responses are saved in a JSONL file (or as individual JSON files) in the `ai_bundles/pending` directory.

## 5. Organization Step
- The script reads the AI response(s) and, for each book:
  - **Determines the correct folder structure and naming** based on Audiobookshelf conventions and the AI metadata.
  - **Moves/copies files** into the organized output directory, creating author, series, and book folders as needed. The default is to copy.

## 6. Output Directory Structure
- **Folder Structure** encodes all relevant metadata directly in the directory and file names, following extended Audiobookshelf conventions. No `metadata.json` or other metadata files are created in the output, as Audiobookshelf will generate its own database.
- The output directory contains a fully organized audiobook library:
  - Author folders ("Last, First")
  - Series subfolders (if applicable)
  - Book folders with standardized names, including year, title, subtitle, narrator, and series index as appropriate
  - All audio and supporting files

### Example: Full Detail Output
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

### Example: Basic (Minimal) Output
```
/OrganizedAudiobooks/
  Austen, Jane/
    Pride and Prejudice/
      Pride and Prejudice.m4b
  Doyle, Arthur Conan/
    Sherlock Holmes/
      Book 1 - The Adventures of Sherlock Holmes/
        The Adventures of Sherlock Holmes.m4b
  Melville, Herman/
    Moby Dick/
      Disc 1/
        Moby Dick - Disc 1.m4b
      Disc 2/
        Moby Dick - Disc 2.m4b
  Sun, Tzu/
    The Art of War/
      The Art of War.m4b
      The Art of War.mp3
      The Art of War.flac
  Aesop/
    Aesop's Fables/
      Aesop's Fables.m4b
```

---

## Summary
- Input: Unorganized audiobook folders/files
- Output: Organized, metadata-rich audiobook library, ready for Audiobookshelf or similar platforms
- Key steps: Metadata extraction → AI analysis → File organization
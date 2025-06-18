# DATAFLOW: AI Audiobook Organizer (Full Logic, always in sync with organize_audiobooks.sh)

1. Book Arrival & Initial Acceptance
   - When a new book folder or file appears in the INPUT_PATH, it is detected by the script.
   - The script adds an entry for the book in the tracking database (SQLite or JSON), marking its status as 'accepted'.

2. Ready for AI Scan
   - The script extracts all available metadata (embedded, folder, supporting files) and creates a JSONL entry for the book.
   - The book's status in the DB is updated to 'ready_for_ai'.
   - An AI ready prompt.md file is also created which contains a comprehensive prompt to pass to the AI to process the uploaded JSONL file, analyze the information and gather or confirm additional information from Audiobook resources to identify or confirm existing and additional information to be used to populate the JSONL file that the AI generates.
   - The AI delivers the JSONL with the analyzed data.

3. AI Scan Returned
   - The AI created JSON is dropped in the input/ai_bundles directory to be processed on the next run.
   - When an AI response is available (either simulated or real), the script updates the DB entry to 'ai_returned'.
   - If the AI cannot determine metadata, the status is set to 'ai_failed', and the book is flagged for manual intervention.

4. Organization
   - For books with 'ai_returned' status, the script organizes (copies) them to the OUTPUT_PATH using the AI metadata.
   - The DB entry is updated to 'organized'.

5. Book Disappearance
   - If a book is removed from INPUT_PATH (external to this script), the script detects its absence and removes its entry from the DB.

6. DB Persistence
   - The tracking DB lives in the INPUT_PATH and persists across runs.

---

(These steps are always kept in sync with the comments at the top of organize_audiobooks.sh. Any change to the script's logic must be reflected here.)

## Input Directory Structure
- **User provides an input directory** containing unorganized audiobook folders and files. These may include:
  - Audio files (various formats: .m4b, .mp3, .flac, etc.)
  - Cover images, description files, NFOs, etc.
  - Folder names may contain author, title, series, etc.

## Output Directory Structure
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
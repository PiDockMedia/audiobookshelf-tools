# DATAFLOW: AI Audiobook Organizer (Full Logic, always in sync with organize_audiobooks.sh)

1. Book Arrival & Initial Acceptance
   - When a new book folder or file appears in the INPUT_PATH, it is detected by the script.
   - The script adds an entry for the book in the tracking database (SQLite or JSON), marking its status as 'accepted'.

2. Ready for AI Scan
   - The script extracts all available metadata (embedded, folder, supporting files) and creates a JSONL entry for the book.
   - The book's status in the DB is updated to 'ready_for_ai'.
   - A comprehensive prompt.md file is created containing instructions for the AI to analyze the JSONL file and extract additional metadata from audiobook resources.
   - The JSONL file and prompt.md are placed in the input/ai_bundles/pending directory for manual AI processing.

3. AI Scan Returned
   - The AI processes the JSONL file and prompt.md, then returns a response JSONL file with analyzed metadata.
   - The AI response JSONL is placed in the input/ai_bundles/pending directory (this is an external step).
   - When an AI response is available, the script updates the DB entry to 'ai_returned'.
   - If the AI cannot determine metadata or the confidence in the accuracy is too low, the status is set to 'ai_failed', and the book requires manual intervention.

4. Organization
   - For books with 'ai_returned' status, the script organizes (copies) them to the OUTPUT_PATH using the AI metadata.
   - The DB entry is updated to 'organized'.

5. Handling AI Failures & Manual Intervention
   - For books with 'ai_failed' status, the script moves their AI-analyzed entries from the returned JSONL to a separate manual intervention JSONL in input/ai_bundles/pending/.
   - When the script runs, it checks the manual intervention JSONL for entries that have been improved and marked as ready for rescan.
   - Improved entries are moved back to the AI READY JSONL for a new analysis attempt.

6. Book Disappearance
   - If a book is removed from INPUT_PATH (external to this script), the script detects its absence and removes its entry from the DB.

7. DB Persistence
   - The tracking DB lives in the INPUT_PATH and persists across runs.

---

(These steps are always kept in sync with the comments at the top of organize_audiobooks.sh. Any change to the script's logic must be reflected here.)

## Manual Intervention Flow Example & Diagram

**Example:**
- Book 'Moby Dick' is scanned and sent to AI, but the AI cannot determine the narrator with high confidence.
- The script marks 'Moby Dick' as 'ai_failed' in the DB and moves its entry to manual_intervention.jsonl.
- A user reviews and edits the entry in manual_intervention.jsonl, adding the correct narrator and marking it as ready for rescan.
- On the next run, the script detects the improved entry, moves it back to the AI ready queue, and resubmits it for analysis.

**Diagram:**

```mermaid
graph TD
  A[Book appears in INPUT_PATH] --> B[Extract metadata & create JSONL]
  B --> C[Send to AI (manual or automated)]
  C -->|Success| D[AI response JSONL returned]
  D -->|High confidence| E[Organize & mark as organized]
  D -->|Low confidence or fail| F[Move to manual_intervention.jsonl]
  F --> G[User edits & marks ready for rescan]
  G --> H[Move back to AI ready queue]
  H --> C
  E --> I[Book disappears from INPUT_PATH]
  I --> J[Remove from DB]
```

---

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
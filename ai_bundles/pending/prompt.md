You are helping organize audiobook folders for ingestion into Audiobookshelf.
Each line in ai_input.jsonl represents one book entry with basic file info.

Please provide a matching JSON output line per entry like:
{
  "id": "Folder_Or_File_Name",
  "author": "Author Name",
  "title": "Book Title",
  "series": "Optional Series Name",
  "series_index": 1,
  "narrator": "Narrator Name"
}

Do your best using the folder name, filenames, and any nearby .txt, .json, .nfo, .opf files. Be accurate and structured.

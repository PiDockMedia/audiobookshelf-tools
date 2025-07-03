import os
from typing import Iterator, Dict, List

def is_audio_file(filename: str) -> bool:
    return filename.lower().endswith((
        ".mp3", ".m4a", ".m4b", ".flac", ".ogg", ".aac", ".wav"
    ))

def scan_input_directory(input_dir: str) -> Iterator[Dict[str, object]]:
    """
    Recursively scans for folders that contain audio files and returns structured
    metadata describing each directory and its contents for AI analysis.
    """
    for root, dirs, files in os.walk(input_dir):
        audio_files = [f for f in files if is_audio_file(f)]
        if audio_files:
            all_files = sorted(os.listdir(root))
            yield {
                "relative_path": os.path.relpath(root, input_dir),
                "full_path": root,
                "files": all_files,
                "audio_files": audio_files,
                "parent_folder": os.path.basename(os.path.dirname(root)),
                "current_folder": os.path.basename(root),
                "depth": root[len(input_dir):].count(os.sep),
            }
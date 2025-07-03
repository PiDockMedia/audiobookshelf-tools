import os
from typing import Iterator

def is_audio_file(filename: str) -> bool:
    return filename.lower().endswith((
        ".mp3", ".m4a", ".m4b", ".flac", ".ogg", ".aac", ".wav"
    ))

def has_audio_files(path: str) -> bool:
    return any(is_audio_file(f) for f in os.listdir(path) if os.path.isfile(os.path.join(path, f)))

def scan_input_directory(input_dir: str) -> Iterator[str]:
    for root, dirs, _ in os.walk(input_dir):
        for d in dirs:
            full_path = os.path.join(root, d)
            if has_audio_files(full_path):
                yield full_path
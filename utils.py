import os

def extract_basic_metadata(book_path: str) -> dict:
    folder = os.path.basename(book_path)
    parent = os.path.basename(os.path.dirname(book_path))
    return {
        "folder_name": folder,
        "parent_folder": parent
    }
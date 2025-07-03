import os
import shutil
import json

def organize_book(source_dir: str, metadata: dict, output_base: str) -> None:
    author = metadata.get("author", {}).get("last", "Unknown") + ", " + metadata.get("author", {}).get("first", "")
    title = metadata.get("title", {}).get("main", "Untitled")

    target_dir = os.path.join(output_base, author.strip(), title.strip())
    os.makedirs(target_dir, exist_ok=True)

    for f in os.listdir(source_dir):
        full_src = os.path.join(source_dir, f)
        full_dst = os.path.join(target_dir, f)
        if os.path.isfile(full_src):
            shutil.copy2(full_src, full_dst)

    with open(os.path.join(target_dir, "metadata.json"), "w") as mf:
        json.dump(metadata, mf, indent=2)
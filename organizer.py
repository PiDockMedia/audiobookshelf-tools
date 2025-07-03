import os
import shutil

def sanitize(s: str) -> str:
    return s.replace("/", "-").strip()

def format_title_folder(meta: dict) -> str:
    parts = []
    seq = meta.get("series_sequence")
    year = meta.get("publish_year")
    if seq:
        parts.append(f"Vol {seq}")
    if year:
        parts.append(str(year))
    main = sanitize(meta.get("title", {}).get("main", "Untitled"))
    parts.append(main)
    subtitle = meta.get("title", {}).get("subtitle")
    if subtitle:
        parts.append(sanitize(subtitle))
    narrator = meta.get("narrator")
    if narrator:
        parts[-1] += f" {{{sanitize(narrator)}}}"
    return " - ".join(parts)

def organize_book(source_dir: str, metadata: dict, output_base: str) -> None:
    author = metadata.get("author", {})
    author_folder = sanitize(f"{author.get('last', '')}, {author.get('first', '')}".strip())
    series = metadata.get("series")
    if series:
        series_folder = sanitize(series)
        target = os.path.join(output_base, author_folder, series_folder)
    else:
        target = os.path.join(output_base, author_folder)

    title_folder = format_title_folder(metadata)
    target_dir = os.path.join(target, title_folder)
    os.makedirs(target_dir, exist_ok=True)

    for f in os.listdir(source_dir):
        src = os.path.join(source_dir, f)
        if os.path.isfile(src):
            shutil.copy2(src, os.path.join(target_dir, f))
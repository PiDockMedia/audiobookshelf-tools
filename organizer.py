import os
import shutil


def sanitize(s: str) -> str:
    return s.replace("/", "-").replace(":", "-").strip()


def format_title_folder(meta: dict) -> str:
    parts = []

    # Volume or series index
    series_index = meta.get("series_sequence") or meta.get("series_index")
    if series_index:
        parts.append(f"Vol {series_index}")

    # Year
    year = meta.get("publish_year") or meta.get("year")
    if year:
        parts.append(str(year))

    # Title
    title_main = meta.get("title", {}).get("main") or meta.get("title")
    if title_main:
        parts.append(sanitize(title_main))
    else:
        parts.append("Untitled")

    # Subtitle
    subtitle = meta.get("title", {}).get("subtitle")
    if subtitle:
        parts.append(sanitize(subtitle))

    # Narrator (in final component only)
    narrator = meta.get("narrator")
    if narrator:
        parts[-1] += f" {{{sanitize(narrator)}}}"

    return " - ".join(parts)


def organize_book(source_dir: str, metadata: dict, output_base: str) -> None:
    # Build author folder
    author = metadata.get("author", {})
    if isinstance(author, str):  # fallback if AI returns string
        author_folder = sanitize(author)
    else:
        author_folder = sanitize(f"{author.get('last', '')}, {author.get('first', '')}".strip())

    # Determine series path
    series = metadata.get("series")
    if series:
        series_folder = sanitize(series)
        target = os.path.join(output_base, author_folder, series_folder)
    else:
        target = os.path.join(output_base, author_folder)

    # Final folder name
    title_folder = format_title_folder(metadata)
    target_dir = os.path.join(target, title_folder)
    os.makedirs(target_dir, exist_ok=True)

    # Copy files
    for f in os.listdir(source_dir):
        src = os.path.join(source_dir, f)
        if os.path.isfile(src):
            shutil.copy2(src, os.path.join(target_dir, f))
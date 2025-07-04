import os
import logging
from scanner import scan_input_directory
from ai_client import send_to_ai_and_get_metadata
from organizer import organize_book
from tracker import load_tracker, get_status, mark_status
from config import INPUT_PATH, OUTPUT_PATH, DRY_RUN

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    logger.info("Starting audiobook organizer")
    tracker = load_tracker()

    for book in scan_input_directory(INPUT_PATH):
        relpath = book["relative_path"]
        full_path = book["full_path"]
        force_override = os.path.exists(os.path.join(full_path, ".force_process"))
        status = get_status(tracker, relpath)

        if not force_override and status == "processed":
            logger.info(f"Already processed, skipping: {relpath}")
            continue
        elif not force_override and status == "skipped":
            logger.info(f"Previously skipped, skipping: {relpath}")
            continue

        status = get_status(tracker, relpath)

        logger.info(f"Processing: {relpath}")
        ai_metadata = send_to_ai_and_get_metadata(book)

        if not ai_metadata:
            logger.warning(f"No metadata returned by AI for {relpath}")
            mark_status(tracker, relpath, "skipped", {"reason": "no metadata"})
            continue

        confidence = ai_metadata.get("confidence", {}).get("title", "low")
        if not force_override and confidence not in ("high", "very_high"):
            logger.warning(f"Low confidence for {relpath}, skipping")
            mark_status(tracker, relpath, "skipped", {"ai_confidence": confidence})
            continue
            
        if DRY_RUN:
            logger.info(f"[Dry Run] Would organize: {relpath} -> {ai_metadata}")
        else:
            organize_book(book["full_path"], ai_metadata, OUTPUT_PATH)
            mark_status(tracker, relpath, "processed", {
                "ai_confidence": confidence,
                "output_path": OUTPUT_PATH
            })

    logger.info("Audiobook organizer completed")

if __name__ == "__main__":
    main()
import os
import logging
from scanner import scan_input_directory
from ai_client import send_to_ai_and_get_metadata
from organizer import organize_book
from config import settings

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def main():
    logger.info("Starting audiobook organizer")

    for book in scan_input_directory(settings.INPUT_PATH):
        logger.info(f"Processing: {book['relative_path']}")

        ai_metadata = send_to_ai_and_get_metadata(book)
        if not ai_metadata:
            logger.warning(f"AI returned no metadata for {book['relative_path']}")
            continue

        if settings.DRY_RUN:
            logger.info(f"[Dry Run] Would organize: {book['relative_path']} with metadata: {ai_metadata}")
        else:
            organize_book(book['full_path'], ai_metadata, settings.OUTPUT_PATH)

    logger.info("Audiobook organizer completed")

if __name__ == "__main__":
    main()
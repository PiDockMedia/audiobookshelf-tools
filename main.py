"""Audiobook Organizer Main Script"""
import os
import logging
from config import settings
from scanner import scan_input_directory
from ai_client import send_to_ai_and_get_metadata
from organizer import organize_book

logging.basicConfig(level=logging.DEBUG if settings.DEBUG else logging.INFO)
logger = logging.getLogger(__name__)

def main():
    logger.info("Starting audiobook organizer")

    for book_path in scan_input_directory(settings.INPUT_PATH):
        logger.info(f"Found candidate: {book_path}")
        metadata = send_to_ai_and_get_metadata(book_path)
        if metadata and metadata.get("confidence", {}).get("title") == "high":
            organize_book(book_path, metadata, settings.OUTPUT_PATH)
        else:
            logger.warning(f"Metadata confidence too low for: {book_path}")

    logger.info("Audiobook organizer completed")

if __name__ == "__main__":
    main()
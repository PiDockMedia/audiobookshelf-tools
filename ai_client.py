from utils import extract_basic_metadata

def send_to_ai_and_get_metadata(book_path: str) -> dict:
    # Simulate metadata returned from AI
    basic = extract_basic_metadata(book_path)

    return {
        "author": {"first": "Jane", "last": "Austen"},
        "title": {"main": "Pride and Prejudice"},
        "confidence": {"title": "high"},
        **basic
    }
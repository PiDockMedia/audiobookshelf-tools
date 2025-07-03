from utils import extract_basic_metadata

def send_to_ai_and_get_metadata(book_path: str) -> dict:
    basic = extract_basic_metadata(book_path)

    # Simulated AI-enriched metadata
    return {
        "author": {"first": "Jane", "last": "Austen"},
        "title": {
            "main": "Pride and Prejudice",
            "subtitle": "A Classic Romance"
        },
        "series": "Regency Collection",
        "series_sequence": 1,
        "publish_year": 1813,
        "narrator": "Elizabeth Klett",
        "confidence": {"title": "high"},
        **basic
    }
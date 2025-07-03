import json
import requests
from config import settings
from utils import extract_basic_metadata

def send_to_ai_and_get_metadata(book_path: str) -> dict:
    metadata = extract_basic_metadata(book_path)

    prompt = {
        "prompt": "Analyze this audiobook and return structured metadata.",
        "input": metadata,
        "model": settings.AI_MODEL
    }

    try:
        response = requests.post(settings.AI_ENDPOINT, json=prompt, timeout=30)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"[ERROR] AI request failed for {book_path}: {e}")
        return {}
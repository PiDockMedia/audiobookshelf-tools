import os
import requests
import logging
from config import AI_ENDPOINT, AI_MODEL

def send_to_ai_and_get_metadata(scan_data: dict) -> dict:
    """
    Sends scan data and optional hints to AI for metadata extraction.
    """
    hint_path = os.path.join(scan_data["full_path"], "metadata_hint.txt")
    hint_text = ""
    if os.path.exists(hint_path):
        with open(hint_path, "r", encoding="utf-8") as f:
            hint_text = f.read().strip()

    hint_section = f"\nHint:\n{hint_text}" if hint_text else ""
    prompt = f"""
You are a metadata extraction agent. Given folder and file names, extract:
- Title
- Author (first and last)
- Narrator
- Series and number
- Year

Raw structure:
{scan_data['relative_path']}
Files:
{scan_data['files']}
{hint_section}

Respond in JSON.
"""

    is_openai = "openai.com" in AI_ENDPOINT
    headers = {"Content-Type": "application/json"}
    payload = {}

    if is_openai:
        headers["Authorization"] = f"Bearer {os.getenv('OPENAI_API_KEY', '')}"
        payload = {
            "model": AI_MODEL,
            "messages": [
                {"role": "system", "content": "You are a helpful metadata extraction assistant."},
                {"role": "user", "content": prompt}
            ]
        }
    else:
        payload = {"model": AI_MODEL, "prompt": prompt, "stream": False}

    try:
        response = requests.post(AI_ENDPOINT, headers=headers, json=payload, timeout=30)
        response.raise_for_status()
        if is_openai:
            text = response.json()["choices"][0]["message"]["content"]
        else:
            text = response.json().get("response") or response.text
        return eval(text) if "{" in text else {}
    except Exception as e:
        logging.warning(f"AI request failed: {e}")
        return {}
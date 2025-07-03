import os
import json
from datetime import datetime
from config import settings

TRACKER_FILE = os.path.join(settings.CONFIG_PATH, "tracker.json")

def load_tracker() -> dict:
    if not os.path.exists(TRACKER_FILE):
        return {}
    with open(TRACKER_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

def save_tracker(tracker: dict) -> None:
    os.makedirs(settings.CONFIG_PATH, exist_ok=True)
    with open(TRACKER_FILE, "w", encoding="utf-8") as f:
        json.dump(tracker, f, indent=2)

def get_status(tracker: dict, relpath: str) -> str:
    return tracker.get(relpath, {}).get("status")

def mark_status(tracker: dict, relpath: str, status: str, metadata: dict = None) -> None:
    tracker[relpath] = {
        "status": status,
        "timestamp": datetime.utcnow().isoformat() + "Z",
        **(metadata or {})
    }
    save_tracker(tracker)
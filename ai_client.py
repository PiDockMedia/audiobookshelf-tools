def send_to_ai_and_get_metadata(scan_data: dict) -> dict:
    """
    Accepts structured scan info and simulates AI enrichment.
    """
    # Just for test: if the folder looks like Discworld, add mock series metadata
    if "Discworld" in scan_data["current_folder"] or any("Discworld" in f for f in scan_data["files"]):
        return {
            "author": {"first": "Terry", "last": "Pratchett"},
            "title": {"main": scan_data["current_folder"]},
            "series": "Discworld",
            "series_sequence": 24,
            "publish_year": 1998,
            "narrator": "Stephen Briggs",
            "confidence": {"title": "high"}
        }

    # Otherwise, return a generic standalone book metadata
    return {
        "author": {"first": "Unknown", "last": "Author"},
        "title": {"main": scan_data["current_folder"]},
        "publish_year": 2024,
        "narrator": "Unknown Narrator",
        "confidence": {"title": "low"}
    }
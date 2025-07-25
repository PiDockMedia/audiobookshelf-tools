import os

INPUT_PATH = os.getenv("INPUT_PATH", "/data/input")
OUTPUT_PATH = os.getenv("OUTPUT_PATH", "/data/output")
CONFIG_PATH = os.getenv("CONFIG_PATH", "/config")
DEBUG = os.getenv("DEBUG", "false").lower() == "true"
DRY_RUN = os.getenv("DRY_RUN", "false").lower() == "true"
AI_ENDPOINT = os.getenv("AI_ENDPOINT", "http://localhost:11434/api")
AI_MODEL = os.getenv("AI_MODEL", "mixtral")
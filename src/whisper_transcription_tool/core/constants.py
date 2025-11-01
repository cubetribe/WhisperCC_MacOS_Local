"""Konstanten für das Whisper Transkriptionstool."""

# URL für Whisper.cpp-Modelle
WHISPER_CPP_MODELS_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main"

# Standardverzeichnisse
DEFAULT_MODEL_DIR = "~/whisper_models"
DEFAULT_OUTPUT_DIR = "~/transcriptions"
DEFAULT_TEMP_DIR = "~/transcriptions/temp"

# Unterstützte Audioformate
SUPPORTED_AUDIO_FORMATS = [".wav", ".mp3", ".ogg", ".flac", ".opus"]

# Unterstützte Videoformate (für Audioextraktion)
SUPPORTED_VIDEO_FORMATS = [".mp4", ".avi", ".mov", ".mkv", ".webm"]

# Unterstützte Ausgabeformate
SUPPORTED_OUTPUT_FORMATS = ["txt", "srt", "vtt", "json"]

# Konfigurationsdateiname
CONFIG_FILENAME = ".whisper_tool.json"

# Log-Dateiname
LOG_FILENAME = "whisper_tool.log"

# Version des Tools
VERSION = "0.9.6"

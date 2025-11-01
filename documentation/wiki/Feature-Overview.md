# Funktionsübersicht

WhisperCC MacOS Local kombiniert leistungsfähige Transkriptionspipelines mit einem modularen Erweiterungssystem. Dieses Dokument fasst die wichtigsten Features und geplanten Erweiterungen zusammen.

## Kernfunktionen
### 1. Transkription
- Whisper.cpp (large-v3-turbo) mit Metal-Unterstützung für Apple Silicon
- Batch-Uploads, Fortschrittsanzeige, Echtzeit-WebSocket-Updates
- Unterstützte Formate: MP3, WAV, FLAC, OGG, M4A, OPUS sowie MP4, MOV, WebM, AVI, MKV
- Automatische Audioextraktion aus Videodateien

### 2. Textkorrektur (Modul 5)
- Lokale LLM-Korrektur mit LeoLM 13B (Q4_K_M)
- Korrekturstufen: Light, Standard, Strict + Dialekt-Normalisierung
- Chunking mit Token- & Satzgrenzen, Rückfallebene bei Fehlern
- Output: Original und korrigierte Version (TXT, JSON mit Metadaten)

### 3. Weboberfläche
- Responsive UI mit Bootstrap
- Zweiphasiger Fortschrittsbalken (Transcription + Correction)
- Datei-Download, Log-Terminal und Debug-Dashboard

## Unterstützende Komponenten
- **ResourceManager:** Modell-Swap (Whisper ↔ LeoLM), RAM-Checks, Monitoring
- **BatchProcessor:** Tokenizer-Integration (SentencePiece, NLTK), Chunk-Reassembly
- **Prompt-System:** Deutsch optimierte Prompts für LeoLM, Dialektoptionen
- **Konfiguration:** `~/.whisper_tool.json`, CLI-Flags, API-Einstellungen
- **Logging & Telemetrie:** `text_correction` Logger, optionale Metriken

## Roadmap
- Textkorrektur-Finetuning für zusätzliche Sprachen
- Erweiterte Vergleichsansicht Original vs. Korrektur
- Modellverwaltung im UI (Download, Versionierung)
- Automatisierte Regressionstests für macOS-App

Weitere Details siehe [Architektur](Architecture.md) und [Release-Management](Release-Management.md).

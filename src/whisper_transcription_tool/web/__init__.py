"""
Web interface for the Whisper Transcription Tool.
"""

import logging
import os
import json  # Für WebSocket-Kommunikation
import asyncio  # Für WebSocket-Kommunikation
import difflib  # Für Textvergleich
import re  # Für SRT-Parsing
from datetime import datetime, timedelta
from pathlib import Path
from typing import Dict, List, Optional, Tuple, Union

import uvicorn
from fastapi import FastAPI, File, Form, Request, UploadFile, WebSocket, WebSocketDisconnect, BackgroundTasks, HTTPException
from fastapi.responses import HTMLResponse, JSONResponse, RedirectResponse, FileResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pydantic import BaseModel, Field

from ..core.config import load_config, save_config
from ..core.constants import VERSION
from ..core.model_manager import get_downloaded_models
from ..core.models import OutputFormat, WhisperModel
from ..core.logging_setup import get_logger
from ..core.events import EventType, Event, subscribe, unsubscribe
from ..core.utils import ensure_directory_exists

logger = get_logger(__name__)

# Pydantic models for request/response bodies if needed
from pydantic import BaseModel, Field

# Create FastAPI app
app = FastAPI(title="Whisper Transcription Tool")


def format_duration(seconds: Optional[float]) -> Optional[str]:
    """Convert seconds into a human readable string."""
    if seconds is None:
        return None
    try:
        seconds = float(seconds)
    except (TypeError, ValueError):
        return None

    if seconds < 0:
        return None
    if seconds < 0.001:
        return "<1 ms"
    if seconds < 1:
        return f"{seconds * 1000:.0f} ms"
    if seconds < 60:
        return f"{seconds:.2f} s"

    minutes, rem_seconds = divmod(seconds, 60)
    if minutes < 60:
        return f"{int(minutes)}m {rem_seconds:.1f}s"

    hours, rem_minutes = divmod(minutes, 60)
    return f"{int(hours)}h {int(rem_minutes)}m {rem_seconds:.1f}s"

# Get the directory of this file
current_dir = Path(__file__).parent

# Set up templates and static files
templates = Jinja2Templates(directory=str(current_dir / "templates"))
app.mount("/static", StaticFiles(directory=str(current_dir / "static")), name="static")

# Global configuration
config = load_config()

# --- Pydantic Models ---
class SetDirectoryPayload(BaseModel):
    directory: str = Field(..., description="The new directory path for storing models.")

# WebSocket-Verbindungen
active_connections = {}

# Set to store active WebSocket connections specifically for progress updates
progress_websockets = set()  # Explizite Deklaration ohne Typ-Annotation

# Debug-Variable zum Verfolgen der letzten gesendeten Fortschrittsdaten
last_progress_data = None

async def progress_event_handler(event: Event):
    """Handles progress events and sends them to relevant clients."""
    global last_progress_data, progress_websockets

    try:
        if event.event_type == EventType.PROGRESS_UPDATE:
            # Log the received event
            status = event.data.get('status', '')
            progress = event.data.get('progress', 0)
            task = event.data.get('task', 'unknown')

            logger.info(f"PROGRESS_HANDLER: {task} event - Status: {status}, Progress: {progress}%")

            # Don't require specific fields - just pass the event data through
            # The frontend will handle different event types appropriately

            # Speichere die letzte Fortschrittsmeldung für neu verbundene Clients
            last_progress_data = event.data.copy()

            # Direkter Zugriff auf progress_websockets mit Kopie der Menge
            current_sockets = list(progress_websockets)
            socket_count = len(current_sockets)

            # Überprüfe, ob es aktive WebSockets gibt
            if socket_count == 0:
                logger.warning("PROGRESS_HANDLER: No active websockets, skipping broadcast.")
                return

            logger.info(f"PROGRESS_HANDLER: Broadcasting to {socket_count} active websockets")

            # Erstelle die Nachricht einmal für alle Clients
            message = json.dumps(event.data)

            # Sende an alle aktiven Verbindungen
            for ws in current_sockets:
                try:
                    await ws.send_text(message)
                    logger.debug(f"Successfully sent: {message[:100]}...")
                except Exception as e:
                    logger.error(f"Failed to send progress to WebSocket: {e}")
                    try:
                        progress_websockets.discard(ws)
                        logger.info(f"Removed faulty websocket. Remaining: {len(progress_websockets)}")
                    except Exception as e2:
                        logger.error(f"Error removing websocket: {e2}")
        elif event.event_type == EventType.CUSTOM:
            # Handle custom events including correction workflow events
            event_subtype = event.data.get('type', '')

            # Log correction events
            if event_subtype in ['correction_started', 'correction_completed', 'correction_error']:
                logger.info(f"PROGRESS_HANDLER: Correction event - {event_subtype}")

            # Store last event for new clients
            last_progress_data = event.data.copy()

            # Send to WebSocket clients
            current_sockets = list(progress_websockets)
            if current_sockets:
                message = json.dumps(event.data)
                for ws in current_sockets:
                    try:
                        await ws.send_text(message)
                    except Exception as e:
                        logger.error(f"Failed to send custom event to WebSocket: {e}")
                        try:
                            progress_websockets.discard(ws)
                        except Exception:
                            pass
        else:
            logger.warning(f"Received event with unexpected type: {event.event_type}")

    except AttributeError as e:
        logger.error(f"PROGRESS_HANDLER: AttributeError caught! Details: {e}", exc_info=True)
    except Exception as e:
        logger.error(f"PROGRESS_HANDLER: Unexpected error in handler! Details: {e}", exc_info=True)

# Event-Handler für Fortschrittsanzeigen und benutzerdefinierte Events registrieren
subscribe(EventType.PROGRESS_UPDATE, progress_event_handler)
subscribe(EventType.CUSTOM, progress_event_handler)

@app.websocket("/ws/progress")
async def progress_websocket(websocket: WebSocket):
    global progress_websockets
    
    try:
        await websocket.accept()
        logger.info("New WebSocket connection accepted for progress updates")
        
        # Füge die Verbindung zur globalen Set hinzu
        progress_websockets.add(websocket)
        logger.info(f"Added WebSocket connection. Total: {len(progress_websockets)}")
        
        # Sende letzte Fortschrittsmeldung, falls vorhanden
        if last_progress_data:
            await websocket.send_json(last_progress_data)
            logger.info("Sent last progress data to new connection")
        
        # Warte auf Verbindungsabbau
        while True:
            data = await websocket.receive_text()
            if data.lower() == "ping":
                await websocket.send_text("pong")
                logger.debug("Received ping, sent pong")
            
    except WebSocketDisconnect:
        logger.info("WebSocket disconnected")
    except Exception as e:
        logger.error(f"WebSocket error: {e}")
    finally:
        try:
            progress_websockets.discard(websocket)
            logger.info(f"Removed WebSocket connection. Remaining: {len(progress_websockets)}")
        except Exception as e:
            logger.error(f"Error removing WebSocket: {e}")

@app.websocket("/ws/{user_id}")
async def websocket_endpoint(websocket: WebSocket, user_id: str):
    """
    WebSocket-Endpunkt für Fortschrittsanzeigen.
    
    Args:
        websocket: WebSocket-Verbindung
        user_id: Eindeutige Benutzer-ID zur Identifikation der Verbindung
    """
    await websocket.accept()
    
    # Verbindung zur Liste der aktiven Verbindungen hinzufügen
    if user_id not in active_connections:
        active_connections[user_id] = []
    active_connections[user_id].append(websocket)
    
    try:
        while True:
            # Auf Nachrichten vom Client warten (z.B. für Ping/Pong)
            await websocket.receive_text()
    except WebSocketDisconnect:
        # Verbindung aus der Liste der aktiven Verbindungen entfernen
        if user_id in active_connections:
            active_connections[user_id].remove(websocket)
            if not active_connections[user_id]:
                del active_connections[user_id]


@app.get("/", response_class=HTMLResponse)
async def index(request: Request):
    """Render the index page."""
    return templates.TemplateResponse(
        "index.html", 
        {"request": request, "title": "Whisper Transcription Tool", "app_version": VERSION}
    )

@app.get("/transcribe", response_class=HTMLResponse)
async def transcribe_page(request: Request):
    """Render the transcription page."""
    return templates.TemplateResponse(
        "transcribe.html", 
        {
            "request": request, 
            "models": [model.value for model in WhisperModel],
            "languages": ["auto", "en", "de", "fr", "es", "it", "ja", "zh", "nl", "pt", "ru"],
            "output_formats": [format.value for format in OutputFormat],
            "default_output_dir": config["output"]["default_directory"],
            "default_model": "large-v3-turbo",  # Setze large-v3-turbo als Standardmodell
            "app_version": VERSION
        }
    )


@app.get("/api/download")
async def download_file(file: str):
    """
    API endpoint for downloading a file.

    Args:
        file: Path to the file to download

    Returns:
        FileResponse with the file
    """
    try:
        # Sicherheitscheck: Stelle sicher, dass die Datei im erlaubten Bereich liegt
        if not os.path.exists(file) or not os.path.isfile(file):
            logger.error(f"Download requested for non-existent file: {file}")
            return JSONResponse({"error": "Datei existiert nicht"}, status_code=404)

        # Bestimme den Content-Type basierend auf der Dateiendung
        content_type = "application/octet-stream"
        if file.lower().endswith('.txt'):
            content_type = "text/plain; charset=utf-8"
        elif file.lower().endswith('.srt'):
            content_type = "text/plain; charset=utf-8"
        elif file.lower().endswith('.vtt'):
            content_type = "text/vtt; charset=utf-8"
        elif file.lower().endswith('.json'):
            content_type = "application/json; charset=utf-8"

        filename = os.path.basename(file)
        logger.info(f"Serving download for file: {filename}")

        return FileResponse(
            path=file,
            filename=filename,
            media_type=content_type,
            headers={"Content-Disposition": f"attachment; filename={filename}"}
        )
    except Exception as e:
        logger.error(f"Error serving file download: {e}")
        return JSONResponse({"error": f"Fehler beim Herunterladen: {str(e)}"}, status_code=500)


@app.get("/api/browse-directories")
async def browse_directories(path: Optional[str] = None):
    """
    API endpoint for browsing directories.
    
    Args:
        path: Path to list subdirectories (None for root)
    
    Returns:
        JSON response with list of subdirectories
    """
    try:
        # Wenn kein Pfad angegeben ist, zeige Standardverzeichnisse an
        if not path:
            # Standardverzeichnisse: Home und Ausgabeverzeichnis
            home_dir = str(Path.home())
            output_dir = config["output"]["default_directory"]
            
            # Verschiedene Standardverzeichnisse auflisten - plattformunabhängig
            directories = [
                {"path": home_dir, "name": "Home"},
                {"path": output_dir, "name": "Standard-Ausgabeverzeichnis"}
            ]
            
            # Plattformspezifische Verzeichnisse hinzufügen
            if platform.system() == "Darwin":  # macOS
                if os.path.exists("/Users"):
                    directories.append({"path": "/Users", "name": "Benutzerverzeichnisse"})
                if os.path.exists("/Volumes"):
                    directories.append({"path": "/Volumes", "name": "Volumes (externe Laufwerke)"})
            elif platform.system() == "Windows":
                # Windows-Benutzerverzeichnis
                users_dir = os.path.join(os.environ.get("SystemDrive", "C:\\"), "Users")
                if os.path.exists(users_dir):
                    directories.append({"path": users_dir, "name": "Benutzerverzeichnisse"})
                # Laufwerke auflisten
                import string
                available_drives = [f"{d}:\\" for d in string.ascii_uppercase if os.path.exists(f"{d}:\\")] 
                if available_drives:
                    for drive in available_drives:
                        directories.append({"path": drive, "name": f"Laufwerk {drive[0]}:"})
            elif platform.system() == "Linux":
                if os.path.exists("/home"):
                    directories.append({"path": "/home", "name": "Benutzerverzeichnisse"})
                if os.path.exists("/media"):
                    directories.append({"path": "/media", "name": "Externe Laufwerke"})
                if os.path.exists("/mnt"):
                    directories.append({"path": "/mnt", "name": "Einhängepunkte"})

        else:
            # Prüfe, ob der angegebene Pfad existiert und ein Verzeichnis ist
            if not os.path.exists(path) or not os.path.isdir(path):
                return JSONResponse(
                    {"error": f"Pfad existiert nicht oder ist kein Verzeichnis: {path}"}, 
                    status_code=400
                )
            
            # Liste alle Unterverzeichnisse des angegebenen Pfads auf
            directories = []
            for item in os.listdir(path):
                item_path = os.path.join(path, item)
                if os.path.isdir(item_path):
                    directories.append({"path": item_path, "name": item})
            
            # Sortiere nach Namen
            directories.sort(key=lambda x: x["name"])
        
        return JSONResponse({
            "success": True, 
            "current_path": path, 
            "directories": directories
        })
    
    except Exception as e:
        logger.error(f"Error browsing directories: {e}")
        return JSONResponse(
            {"success": False, "error": str(e)},
            status_code=500
        )


@app.post("/api/transcribe")
async def transcribe_audio_api(
    audio_file: Optional[UploadFile] = File(None),
    pre_extracted_audio: Optional[str] = Form(None),
    model: str = Form(WhisperModel.LARGE_V3_TURBO.value),
    language: Optional[str] = Form(None),
    output_format: str = Form(OutputFormat.TXT.value),
    output_path: Optional[str] = Form(None),
    srt_max_chars: Optional[str] = Form(None),  # Als String akzeptieren
    srt_max_duration: Optional[str] = Form(None),  # Als String akzeptieren
    srt_linebreaks: Optional[str] = Form("true"),  # Checkbox: "true" oder "false"
    # New correction parameters
    enable_correction: bool = Form(False),
    correction_level: str = Form("standard"),
    dialect_normalization: bool = Form(False)
):
    try:
        # Import here to avoid circular imports
        from ..module1_transcribe import transcribe_audio
        
        # Bestimme die zu transkribierende Audiodatei
        if audio_file is None and pre_extracted_audio is None:
            return JSONResponse(
                {"success": False, "error": "Es wurde keine Audiodatei angegeben"}, 
                status_code=400
            )
        
        if pre_extracted_audio:
            # Benutze den Pfad zur vorher extrahierten Audiodatei
            audio_path = pre_extracted_audio
            logger.info(f"Verwende vorher extrahierte Audiodatei: {audio_path}")
        else:
            # Speichere die hochgeladene Datei an einem temporären Ort
            temp_dir = Path(config["output"]["default_directory"]) / "temp"
            os.makedirs(temp_dir, exist_ok=True)
            
            temp_file = temp_dir / audio_file.filename
            with open(temp_file, "wb") as f:
                f.write(await audio_file.read())
            
            audio_path = str(temp_file)
            logger.info(f"Hochgeladene Audiodatei gespeichert unter: {audio_path}")
        
        # Bestimme den Ausgabepfad (wenn angegeben)
        custom_output_dir = None
        if output_path and output_path.strip():
            if os.path.isdir(output_path):
                custom_output_dir = output_path
                logger.info(f"Benutze benutzerdefinierten Ausgabepfad: {custom_output_dir}")
            else:
                logger.warning(f"Angegebener Ausgabepfad existiert nicht: {output_path}")
        
        # Konvertiere SRT-Parameter zu den richtigen Typen
        # Verwende niedrigere Standardwerte für kürzere Segmente
        if srt_max_chars and srt_max_chars.strip():
            try:
                srt_max_chars_int = int(srt_max_chars)
                # Stelle sicher, dass der Wert sinnvoll ist
                srt_max_chars_int = min(max(20, srt_max_chars_int), 120)
            except:
                srt_max_chars_int = 40  # Standardwert für kurze Untertitel
        else:
            srt_max_chars_int = 40  # Standardwert für kurze Untertitel
            
        if srt_max_duration and srt_max_duration.strip():
            try:
                srt_max_duration_float = float(srt_max_duration)
                # Stelle sicher, dass der Wert sinnvoll ist
                srt_max_duration_float = min(max(1.0, srt_max_duration_float), 10.0)
            except:
                srt_max_duration_float = 1.5  # Standardwert für kurze Segmente
        else:
            srt_max_duration_float = 1.5  # Standardwert für kurze Segmente
            
        # Checkboxwert "true"/"false" zu bool konvertieren
        srt_linebreaks_bool = (str(srt_linebreaks).lower() == "true")
        # Transkribiere die Audiodatei
        result = transcribe_audio(
            audio_path=audio_path,
            output_format=output_format,
            language=language,
            model=model,
            srt_max_chars=srt_max_chars_int,
            srt_max_duration=srt_max_duration_float,
            srt_linebreaks=srt_linebreaks_bool,
            config=config,
            output_dir=custom_output_dir
        )
        
        # Log SRT-Parameter
        if output_format.lower() == 'srt':
            logger.info(f"SRT-Parameter: max_chars={srt_max_chars_int}, max_duration={srt_max_duration_float}")

            # Für SRT-Format lesen wir direkt aus der Datei, um Zeitstempel zu erhalten
            if result.success and result.output_file and os.path.exists(result.output_file):
                try:
                    with open(result.output_file, 'r', encoding='utf-8') as f:
                        srt_content = f.read()
                    # Aktualisiere den Text in der Antwort
                    result.text = srt_content
                    logger.info(f"SRT-Inhalt für Anzeige gelesen, Länge: {len(srt_content)} Zeichen")
                except Exception as e:
                    logger.error(f"Fehler beim Lesen der SRT-Datei: {e}")

        # Run text correction if enabled and transcription was successful
        correction_result = None
        if enable_correction and result.success and result.output_file:
            try:
                # Validate correction parameters
                valid_levels = ["minimal", "standard", "enhanced"]
                if correction_level not in valid_levels:
                    correction_level = "standard"
                    logger.warning(f"Invalid correction level, using 'standard'")

                logger.info(f"Running text correction with level: {correction_level}, dialect_normalization: {dialect_normalization}")

                # Import correction module
                from ..module5_text_correction import correct_transcription

                # Generate a user ID for progress tracking
                import uuid
                user_id = str(uuid.uuid4())[:8]

                # Run correction
                correction_result = await correct_transcription(
                    transcription_file=result.output_file,
                    enable_correction=True,
                    correction_level=correction_level,
                    dialect_normalization=dialect_normalization,
                    config=config,
                    user_id=user_id
                )

                if correction_result.get("success", False):
                    logger.info(f"Text correction completed successfully")
                    # Update result with corrected information
                    result_dict = result.to_dict()
                    correction_payload = correction_result.get("correction_result", {})
                    corrections_made = correction_payload.get("corrections_made", [])
                    if isinstance(corrections_made, list):
                        corrections_count = len(corrections_made)
                    else:
                        # Fallback: some implementations may return an int directly
                        corrections_count = corrections_made or 0
                    processing_seconds = correction_payload.get("processing_time_seconds")
                    model_info = correction_payload.get("model_info", {}) or {}
                    model_path = model_info.get("model_path")
                    model_name = model_info.get("model_name") or (Path(model_path).name if model_path else None)
                    llm_level = correction_payload.get("llm_level")
                    formatted_duration = format_duration(processing_seconds)
                    result_dict["correction"] = {
                        "enabled": True,
                        "success": True,
                        "corrected_file": correction_result.get("corrected_file"),
                        "metadata_file": correction_result.get("metadata_file"),
                        "improvement_score": correction_payload.get("improvement_score", 0),
                        "method": correction_payload.get("method"),
                        "corrections_made": corrections_made,
                        "correction_level": correction_level,
                        "processing_time_seconds": processing_seconds,
                        "model_info": model_info,
                        "llm_level": llm_level
                    }

                    # If correction was successful, update the main result with corrected text for display
                    corrected_file = correction_result.get("corrected_file")
                    if corrected_file and os.path.exists(corrected_file):
                        try:
                            with open(corrected_file, 'r', encoding='utf-8') as f:
                                corrected_text = f.read()
                            result_dict["corrected_text"] = corrected_text
                            logger.info(f"Added corrected text to result for display")
                        except Exception as e:
                            logger.error(f"Error reading corrected file: {e}")

                    # Provide top-level convenience fields for the frontend
                    result_dict.update({
                        "correction_enabled": True,
                        "correction_success": True,
                        "correction_level": correction_level,
                        "correction_method": correction_payload.get("method"),
                        "correction_changes": corrections_count,
                        "correction_improvement_score": correction_payload.get("improvement_score"),
                        "correction_metadata_file": correction_result.get("metadata_file"),
                        "corrected_output_file": correction_result.get("corrected_file"),
                        "correction_time_seconds": processing_seconds,
                        "correction_time": formatted_duration,
                        "correction_model": model_name,
                        "correction_model_path": model_path,
                        "correction_llm_level": llm_level
                    })

                    return JSONResponse(result_dict)
                else:
                    logger.error(f"Text correction failed: {correction_result.get('error', 'Unknown error')}")
                    # Continue with original result but add correction error info
                    result_dict = result.to_dict()
                    result_dict["correction"] = {
                        "enabled": True,
                        "success": False,
                        "error": correction_result.get("error", "Unknown correction error")
                    }
                    result_dict.update({
                        "correction_enabled": True,
                        "correction_success": False,
                        "correction_error": correction_result.get("error", "Unknown correction error")
                    })
                    return JSONResponse(result_dict)

            except Exception as e:
                logger.error(f"Error during text correction: {e}")
                # Continue with original result but add correction error
                result_dict = result.to_dict()
                result_dict["correction"] = {
                    "enabled": True,
                    "success": False,
                    "error": f"Correction failed: {str(e)}"
                }
                result_dict.update({
                    "correction_enabled": True,
                    "correction_success": False,
                    "correction_error": f"Correction failed: {str(e)}"
                })
                return JSONResponse(result_dict)
        else:
            # No correction requested or transcription failed
            result_dict = result.to_dict()
            if enable_correction:
                result_dict["correction"] = {
                    "enabled": True,
                    "success": False,
                    "error": "Transcription failed, correction skipped" if not result.success else "Correction not available"
                }
                result_dict.update({
                    "correction_enabled": True,
                    "correction_success": False,
                    "correction_error": result_dict["correction"]["error"]
                })
            else:
                result_dict["correction"] = {"enabled": False}
                result_dict["correction_enabled"] = False
            return JSONResponse(result_dict)

        # Fallback return (should not reach here)
        return JSONResponse(result.to_dict())
    
    except Exception as e:
        logger.error(f"Error transcribing audio: {e}")
        return JSONResponse(
            {"success": False, "error": str(e)},
            status_code=500
        )


@app.get("/api/models/validate")
async def validate_model_api(model_path: str = None):
    """
    API endpoint to validate a specific model file.

    Args:
        model_path: Path to the model file to validate (optional)

    Returns:
        JSON response with validation results
    """
    try:
        import os
        from pathlib import Path

        # Use provided path or default
        if model_path:
            path = Path(model_path)
        else:
            # Use default LeoLM path
            path = Path("/Users/denniswestermann/.lmstudio/models/mradermacher/LeoLM-hesseianai-13b-chat-GGUF/LeoLM-hesseianai-13b-chat.Q4_K_M.gguf")

        validation_result = {
            "path": str(path),
            "exists": path.exists(),
            "is_file": path.is_file() if path.exists() else False,
            "readable": os.access(str(path), os.R_OK) if path.exists() else False,
            "size_gb": path.stat().st_size / (1024**3) if path.exists() and path.is_file() else 0,
            "format_valid": False,
            "format_details": None,
            "recommendation": None
        }

        # Check file format if it exists
        if validation_result["exists"] and validation_result["is_file"]:
            try:
                with open(path, 'rb') as f:
                    header = f.read(4)
                    if header == b'GGUF':
                        validation_result["format_valid"] = True
                        validation_result["format_details"] = "Valid GGUF format detected"
                        validation_result["recommendation"] = "Model file appears valid for use"
                    else:
                        validation_result["format_details"] = f"Invalid header: {header.hex()}"
                        validation_result["recommendation"] = "File is not in GGUF format. Download a GGUF model."
            except Exception as e:
                validation_result["format_details"] = f"Could not read file: {str(e)}"
                validation_result["recommendation"] = "Unable to validate file format"
        else:
            validation_result["recommendation"] = "Model file not found. Please download the LeoLM model."

        return JSONResponse({
            "success": True,
            **validation_result
        })

    except Exception as e:
        logger.error(f"Error validating model: {e}")
        return JSONResponse({
            "success": False,
            "error": str(e)
        }, status_code=500)


@app.get("/api/models/available")
async def list_available_models_api():
    """
    API endpoint to list available models in common directories.

    Returns:
        JSON response with list of found models
    """
    try:
        from pathlib import Path

        # Common model directories to search
        search_paths = [
            Path.home() / ".lmstudio" / "models",
            Path.home() / "Models",
            Path("/Users/denniswestermann/Desktop/Coding Projekte/whisper_clean/models"),
            Path("/opt/models"),
            Path("/usr/local/models")
        ]

        found_models = []

        for base_path in search_paths:
            if not base_path.exists():
                continue

            # Search for GGUF files
            for gguf_file in base_path.rglob("*.gguf"):
                try:
                    model_info = {
                        "path": str(gguf_file),
                        "name": gguf_file.name,
                        "size_gb": gguf_file.stat().st_size / (1024**3),
                        "parent_dir": gguf_file.parent.name,
                        "quantization": None
                    }

                    # Try to extract quantization from filename
                    name_lower = gguf_file.name.lower()
                    for quant in ["q2_k", "q3_k", "q4_k", "q4_k_m", "q5_k", "q5_k_m", "q6_k", "q8_0"]:
                        if quant in name_lower:
                            model_info["quantization"] = quant.upper()
                            break

                    found_models.append(model_info)
                except Exception as e:
                    logger.warning(f"Error processing model file {gguf_file}: {e}")

        # Sort by size
        found_models.sort(key=lambda x: x["size_gb"])

        return JSONResponse({
            "success": True,
            "models": found_models,
            "count": len(found_models),
            "search_paths": [str(p) for p in search_paths if p.exists()]
        })

    except Exception as e:
        logger.error(f"Error listing models: {e}")
        return JSONResponse({
            "success": False,
            "error": str(e),
            "models": []
        }, status_code=500)


@app.get("/api/correction-status")
async def correction_status_api():
    """
    API endpoint to check text correction status and availability.

    Returns:
        JSON response with correction availability, model info, and requirements
    """
    try:
        from ..module5_text_correction import check_correction_availability

        status = check_correction_availability()

        # Add additional system information
        import psutil
        cpu_count = psutil.cpu_count()
        cpu_percent = psutil.cpu_percent(interval=1)

        status["system_info"] = {
            "cpu_count": cpu_count,
            "cpu_percent": cpu_percent,
            "platform": "macOS" if os.name == "posix" else "Windows" if os.name == "nt" else "Linux"
        }

        # Add available correction levels based on resources
        available_ram_gb = status.get("available_ram_gb", 0)
        status["available_levels"] = []

        if available_ram_gb >= 2.0:
            status["available_levels"].append({
                "level": "minimal",
                "name": "Minimal Correction",
                "description": "Basic grammar and punctuation fixes",
                "ram_required_gb": 2.0
            })

        if available_ram_gb >= 4.0:
            status["available_levels"].append({
                "level": "standard",
                "name": "Standard Correction",
                "description": "Grammar, punctuation, and style improvements",
                "ram_required_gb": 4.0
            })

        if available_ram_gb >= 8.0:
            status["available_levels"].append({
                "level": "enhanced",
                "name": "Enhanced Correction",
                "description": "Full AI-powered text enhancement with context awareness",
                "ram_required_gb": 8.0
            })

        return JSONResponse({
            "success": True,
            **status
        })

    except Exception as e:
        logger.error(f"Error checking correction status: {e}")
        return JSONResponse(
            {
                "success": False,
                "available": False,
                "status": "error",
                "error": str(e)
            },
            status_code=500
        )


@app.get("/extract", response_class=HTMLResponse)
async def extract_page(request: Request):
    """Render the extraction page."""
    return templates.TemplateResponse(
        "extract.html",
        {"request": request, "title": "Video-Audioextraktion", "app_version": VERSION}
    )


@app.post("/api/extract")
async def extract_audio_api(
    video_file: UploadFile = File(...)
):
    """
    API endpoint for extracting audio from video.
    
    Args:
        video_file: Video file to extract audio from
    
    Returns:
        JSON response with extraction result
    """
    try:
        # Import here to avoid circular imports
        from ..module2_extract import extract_audio
        
        # Save uploaded file to temporary location
        temp_dir = Path(config["output"]["default_directory"]) / "temp"
        os.makedirs(temp_dir, exist_ok=True)
        
        temp_file = temp_dir / video_file.filename
        with open(temp_file, "wb") as f:
            f.write(await video_file.read())
        
        # Extract audio
        result = extract_audio(
            str(temp_file),
            config=config
        )
        
        # Return result
        return JSONResponse(result.to_dict())
    
    except Exception as e:
        logger.error(f"Error extracting audio: {e}")
        return JSONResponse(
            {"success": False, "error": str(e)},
            status_code=500
        )


@app.get("/api/models")
async def get_models_api():
    """
    API endpoint for getting available models with detailed information.
    
    Returns:
        JSON response with available models and their details (size, description, etc.)
    """
    try:
        # Import here to avoid circular imports
        from ..module1_transcribe import list_models
        from ..core.model_manager import get_recommended_models, get_downloaded_models, get_model_info
        
        # Get available models
        all_models = list_models(config)
        
        # Get downloaded models
        model_dir = config.get("whisper", {}).get("model_path", "~/.whisper-models")
        downloaded = get_downloaded_models(model_dir)
        
        # Get recommended models with detailed information
        recommended_models = get_recommended_models()
        
        # Mark which models are downloaded
        for model in recommended_models:
            model["is_downloaded"] = model["name"] in downloaded
            
        # Include legacy models that might be downloaded but not in our recommendations
        legacy_models = []
        for model_name in all_models:
            if model_name not in [m["name"] for m in recommended_models]:
                model_info = get_model_info(model_name)
                model_info["is_downloaded"] = model_name in downloaded
                model_info["is_legacy"] = True  # Mark as legacy model
                legacy_models.append(model_info)
        
        # Return result
        return JSONResponse({
            "success": True, 
            "recommended_models": recommended_models,
            "legacy_models": legacy_models,
            "downloaded_models": downloaded
        })
    
    except Exception as e:
        logger.error(f"Error getting models: {e}")
        return JSONResponse(
            {"success": False, "error": str(e)},
            status_code=500
        )


@app.post("/api/models/delete/{model_name}")
async def delete_model_api(model_name: str):
    """
    API endpoint for deleting a model.
    
    Args:
        model_name: Name of the model to delete
        
    Returns:
        JSON response indicating success or failure
    """
    try:
        # Import here to avoid circular imports
        from pathlib import Path
        import os
        
        # Get model directory from config
        model_dir = config.get("whisper", {}).get("model_path", "~/.whisper-models")
        model_dir_path = Path(model_dir).expanduser().resolve()
        
        # Construct model filename (ggml-<model_name>.bin)
        model_filename = f"ggml-{model_name}.bin"
        model_file_path = model_dir_path / model_filename
        
        logger.info(f"Attempting to delete model: {model_file_path}")
        
        # Check if file exists
        if not model_file_path.exists():
            return JSONResponse({
                "success": False, 
                "error": f"Model file {model_filename} not found in {model_dir}"
            }, status_code=404)
        
        # Delete the file
        try:
            os.remove(model_file_path)
            logger.info(f"Successfully deleted model: {model_file_path}")
            return JSONResponse({
                "success": True, 
                "message": f"Model {model_name} deleted successfully"
            })
        except OSError as e:
            logger.error(f"Error deleting model file {model_file_path}: {e}")
            return JSONResponse({
                "success": False, 
                "error": f"Could not delete model file: {str(e)}"
            }, status_code=500)
    
    except Exception as e:
        logger.error(f"Error in delete_model_api: {e}")
        return JSONResponse({
            "success": False, 
            "error": str(e)
        }, status_code=500)


@app.get("/models", response_class=HTMLResponse)
async def models_page(request: Request):
    """Render the model management page."""
    model_directory = config["whisper"]["model_path"]
    downloaded_models = get_downloaded_models(model_directory)
    return templates.TemplateResponse(
        "models.html",
        {
            "request": request,
            "title": "Modellverwaltung",
            "app_version": VERSION,
            "available_models": [model.value for model in WhisperModel],
            "model_directory": config["whisper"]["model_path"],
            "downloaded_models": downloaded_models
        }
    )


# --- API Endpoints for Model Management ---
@app.post("/api/models/download/{model_name}")
async def download_model_api(model_name: str, background_tasks: BackgroundTasks):
    """API endpoint to trigger the download of a specific model."""
    logger.info(f"Received request to download model: {model_name}")
    
    # Basic validation if model_name is known
    if model_name not in [m.value for m in WhisperModel]:
        raise HTTPException(status_code=404, detail=f"Model '{model_name}' not found or invalid.")
    
    # --- Run download in background --- 
    # This is better UX as it doesn't block the API response.
    # The actual download status/progress should be sent via WebSocket.
    from ..core.model_manager import download_model # Import here or globally
    background_tasks.add_task(download_model, model_name, config["whisper"]["model_path"])
    
    # Immediately return success, indicating the download *started*
    return {"status": "success", "message": f"Download für {model_name} im Hintergrund gestartet."}


@app.post("/api/models/set-directory", status_code=200)
async def set_model_directory_api(payload: SetDirectoryPayload):
    """API endpoint to set the directory where models are stored."""
    new_directory_str = payload.directory
    logger.info(f"Received request to set model directory to: {new_directory_str}")
 
    try:
        # Expand ~ and resolve to an absolute path
        new_directory_path = Path(new_directory_str).expanduser()
 
        # Try to create the directory if it doesn't exist, ensuring it's valid
        if not ensure_directory_exists(new_directory_path):
             # ensure_directory_exists logs the error
            raise HTTPException(status_code=400, detail=f"Konnte Verzeichnis nicht erstellen oder darauf zugreifen: {new_directory_path}")
 
        # Check write permissions (basic check)
        test_file = new_directory_path / ".cascade_write_test"
        try:
            test_file.touch()
            test_file.unlink()
        except OSError as e:
            logger.error(f"Schreibberechtigungstest fehlgeschlagen für {new_directory_path}: {e}")
            raise HTTPException(status_code=400, detail=f"Keine Schreibberechtigung im Verzeichnis: {new_directory_path}")
 
        # Update the config dictionary
        # Make sure the nested structure exists
        if "whisper" not in config:
            config["whisper"] = {}
        config["whisper"]["model_path"] = str(new_directory_path.resolve()) # Store absolute path
 
        # Save the updated config back to the file
        if not save_config(config):
            # save_config logs the error
             raise HTTPException(status_code=500, detail="Fehler beim Speichern der Konfigurationsdatei.")
 
        logger.info(f"Model directory successfully updated to: {config['whisper']['model_path']}")
        return {"status": "success", "message": f"Modellverzeichnis erfolgreich auf '{config['whisper']['model_path']}' gesetzt.", "new_path": config['whisper']['model_path']}
 
    except HTTPException as http_exc:
        raise http_exc # Re-raise FastAPI HTTP exceptions
    except Exception as e:
        logger.exception(f"Unerwarteter Fehler beim Setzen des Modellverzeichnisses auf '{new_directory_str}': {e}")
        raise HTTPException(status_code=500, detail=f"Ein unerwarteter Fehler ist aufgetreten: {e}")


# --- WebSocket Endpoint for Model Download Progress Updates ---
# REMOVED: Duplicate WebSocket endpoint - using the one at line 132 instead


# --- API Endpoints for Disk Management ---
@app.get("/api/disk/status")
async def disk_status_api():
    """API endpoint für die Überwachung des Festplattenspeichers."""
    from ..core.file_manager import FileManager
    file_manager = FileManager()
    return file_manager.monitor_disk_space()

@app.post("/api/disk/cleanup")
async def disk_cleanup_api(age_hours: int = 24):
    """API endpoint für die manuelle Bereinigung temporärer Dateien."""
    from ..core.file_manager import FileManager
    file_manager = FileManager()
    return file_manager.cleanup_temp_directory(age_threshold_hours=age_hours)

@app.post("/api/disk/emergency-cleanup")
async def disk_emergency_cleanup_api():
    """API endpoint für die Notfallbereinigung bei kritisch niedrigem Speicherplatz."""
    from ..core.file_manager import FileManager
    file_manager = FileManager()
    return file_manager.emergency_cleanup()

@app.get("/disk", response_class=HTMLResponse)
async def disk_page(request: Request):
    """Render disk management page."""
    from ..core.file_manager import FileManager
    from ..core.config import load_config
    
    # Lade Konfiguration und erstelle FileManager
    config = load_config()
    file_manager = FileManager(config)
    
    # Disk-Statistiken und Konfiguration
    disk_stats = file_manager.monitor_disk_space()
    disk_config = config.get("disk_management", {})
    
    return templates.TemplateResponse(
        "disk.html",
        {
            "request": request,
            "disk_stats": disk_stats,
            "disk_config": disk_config,
            "title": "Speicherverwaltung",
            "current_year": datetime.now().year,
            "app_version": VERSION
        }
    )


# --- Transcript Comparison Page and API ---
@app.get("/compare", response_class=HTMLResponse)
async def compare_page(request: Request):
    """Render the transcript comparison page."""
    return templates.TemplateResponse(
        "compare.html",
        {
            "request": request,
            "title": "Transkript-Prüfung (SRT vs JSON)",
            "current_year": datetime.now().year,
            "app_version": VERSION
        }
    )


@app.post("/api/compare-transcripts", response_class=JSONResponse)
async def compare_transcripts_api(
    srtFile: UploadFile = File(...),
    jsonFile: UploadFile = File(...)
):
    """
    API-Endpunkt zum Vergleichen von SRT- und JSON-Transkriptionsdateien.
    
    Args:
        srtFile: SRT-Datei zum Vergleichen
        jsonFile: JSON-Kontrolldatei zum Vergleichen
        
    Returns:
        JSONResponse mit Vergleichsergebnissen
    """
    from .compare_utils import parse_srt_file, compare_segments
    
    logger.info(f"Vergleiche Dateien: {srtFile.filename} und {jsonFile.filename}")
    
    try:
        # SRT-Datei einlesen und parsen
        srt_content = await srtFile.read()
        srt_content = srt_content.decode("utf-8")
        srt_segments = parse_srt_file(srt_content)
        
        # JSON-Datei einlesen und parsen
        json_content = await jsonFile.read()
        json_content = json_content.decode("utf-8")
        json_segments = json.loads(json_content)
        
        # Vergleich durchführen mit Standardtoleranz von 300ms
        comparison_results = compare_segments(srt_segments, json_segments, time_tolerance=300)
        
        # Ergebnisse zurückgeben
        return {
            "success": True,
            "message": f"Vergleich von {len(comparison_results)} Segmenten abgeschlossen",
            "segments": comparison_results
        }
    
    except Exception as e:
        logger.error(f"Fehler beim Vergleich der Transkriptionsdateien: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"Fehler beim Vergleich der Dateien: {str(e)}"
        )

# API-Endpunkt für die Speicherkonfiguration
@app.post("/api/disk/config")
async def update_disk_config(request: Request):
    """API für die Aktualisierung der Speicherkonfiguration."""
    from ..core.config import load_config, save_config
    
    # Lade aktuelle Konfiguration
    config = load_config()
    
    # Lese Formularwerte aus dem Request
    form_data = await request.form()
    
    # Aktualisiere Konfiguration
    if "disk_management" not in config:
        config["disk_management"] = {}
    
    try:
        # Speicherverwaltungseinstellungen aktualisieren
        config["disk_management"]["max_disk_usage_percent"] = int(form_data.get("max_disk_usage_percent", "90"))
        config["disk_management"]["min_required_space_gb"] = float(form_data.get("min_required_space_gb", "2.0"))
        config["disk_management"]["batch_warning_threshold_gb"] = float(form_data.get("batch_warning_threshold_gb", "5.0"))
        config["disk_management"]["enable_auto_cleanup"] = "enable_auto_cleanup" in form_data
        config["disk_management"]["cleanup_age_hours"] = int(form_data.get("cleanup_age_hours", "24"))
        
        # Speichere Konfiguration
        save_config(config, None)  # None verwendet den Standardpfad
        
        # Erfolgreiche Antwort
        return JSONResponse({
            "success": True,
            "message": "Speicherverwaltungs-Einstellungen wurden erfolgreich aktualisiert."
        })
    except Exception as e:
        logger.error(f"Fehler beim Aktualisieren der Speicherkonfiguration: {e}")
        
        # Fehlerantwort
        return JSONResponse({
            "success": False,
            "error": str(e)
        }, status_code=500)
        
    # Nach der Aktualisierung zur Disk-Seite umleiten
    return RedirectResponse(url_path="/disk")


# Warnungsprüfung für Stapelverarbeitung
@app.get("/api/disk/check-batch-processing")
async def check_batch_processing_space():
    """Prüft, ob genügend Speicherplatz für Stapelverarbeitung verfügbar ist."""
    from ..core.file_manager import FileManager
    from ..core.config import load_config
    
    try:
        # Lade Konfiguration und prüfe Speicherplatz
        config = load_config()
        file_manager = FileManager(config)
        disk_stats = file_manager.monitor_disk_space()
        
        # Prüfe, ob genügend Speicherplatz für Stapelverarbeitung verfügbar ist
        batch_threshold = config.get("disk_management", {}).get("batch_warning_threshold_gb", 5.0)
        has_enough_space = disk_stats["free_gb"] >= batch_threshold
        
        return jsonify({
            "has_enough_space": has_enough_space,
            "free_space_gb": disk_stats["free_gb"],
            "required_space_gb": batch_threshold,
            "message": f"Hinweis: Für die Stapelverarbeitung werden mindestens {batch_threshold} GB freier Speicherplatz empfohlen. "
                       f"Aktuell sind {disk_stats['free_gb']:.1f} GB frei. "
                       f"Bei zu wenig Speicherplatz könnte die Verarbeitung abbrechen."
        })
    except Exception as e:
        logger.error(f"Fehler bei der Speicherprüfung für Stapelverarbeitung: {e}")
        return jsonify({
            "has_enough_space": False,
            "error": str(e)
        }), 500

# Startup-Event für Hintergrundaufgaben wie Festplattenbereinigung
@app.on_event("startup")
async def startup_event():
    """Start background tasks when the server starts."""
    # Import disk management module
    from ..core.file_manager import FileManager
    
    # Create background task for disk monitoring
    asyncio.create_task(monitor_disk_space_task())
    
    # Perform initial disk space check and cleanup if needed
    file_manager = FileManager()
    space_info = file_manager.monitor_disk_space()
    logger.info(f"Initial disk space check: {space_info['free_gb']} GB free")
    
    # Clean old temporary files at startup
    if space_info['status'] == 'warning':
        logger.warning(f"Low disk space detected. Running cleanup at startup.")
        cleanup_result = file_manager.cleanup_temp_directory(age_threshold_hours=24)
        logger.info(f"Startup cleanup result: {cleanup_result}")

# Disk space monitoring background task
async def monitor_disk_space_task():
    """Background task to monitor disk space periodically."""
    try:
        from ..core.file_manager import FileManager
        file_manager = FileManager()
        while True:
            # Check disk space every 5 minutes
            space_stats = file_manager.monitor_disk_space()
            
            # If disk space is critically low, perform emergency cleanup
            if space_stats.get("status") == "warning" and space_stats.get("free_gb", 0) < 1.0:
                logger.warning("Critical disk space detected, performing emergency cleanup")
                cleanup_result = file_manager.emergency_cleanup()
                logger.info(f"Emergency cleanup result: {cleanup_result}")
            
            # Wait for 5 minutes
            await asyncio.sleep(300)
    except Exception as e:
        logger.error(f"Error in disk space monitoring task: {e}")

def start_web_server(host: str = "0.0.0.0", port: int = 8000, config_path: Optional[str] = None) -> None:
    """Startet den FastAPI Webserver."""
    global config
    config = load_config(config_path)
 
    # Event-Handler für Fortschrittsanzeigen registrieren
    subscribe(EventType.PROGRESS_UPDATE, progress_event_handler)

    logger.info(f"Starting web server on {host}:{port}")
    uvicorn.run(app, host=host, port=port)

# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Whisper Transcription Tool - a modular Python application for audio/video transcription using Whisper.cpp, optimized for Apple Silicon. The tool runs locally without API dependencies for transcription.

## ⚡ Quick Start (IMPORTANT - READ FIRST)

### Fastest Way to Start the Application
```bash
# From project root directory:
source venv_new/bin/activate  # Use venv_new, NOT venv
python -m src.whisper_transcription_tool.main web --port 8090
```

Then open http://localhost:8090 in your browser.

### Common Issues & Solutions

1. **Permission Denied Error for whisper-cli:**
   ```bash
   chmod +x deps/whisper.cpp/build/bin/whisper-cli
   ```

2. **Wrong paths in config:**
   The config file `~/.whisper_tool.json` should point to:
   - whisper binary: `[project_root]/deps/whisper.cpp/build/bin/whisper-cli`
   - models: `[project_root]/models`
   - transcriptions: `[project_root]/transcriptions`

3. **Virtual Environment:**
   - Primary: `venv_new` (preferred)
   - Fallback: `venv`
   - The start_server.sh script now checks for both

## Key Commands

### Development Setup
```bash
# Create and activate virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Install in development mode with all features
pip install -e ".[full]"

# Setup Whisper.cpp and FFmpeg
bash install.sh
```

### Running the Application
```bash
# Start web server (preferred method)
bash start_server.sh

# Or directly via Python
python -m src.whisper_transcription_tool.main web --port 8090

# Command-line transcription
whisper-tool transcribe path/to/audio.mp3 --model large-v3-turbo

# Extract audio from video
whisper-tool extract path/to/video.mp4
```

### Code Quality
```bash
# Format code
black src/

# Sort imports
isort src/

# Run linting
flake8 src/

# Type checking
mypy src/

# Run tests
pytest
```

## Architecture

The application follows a modular architecture with these main components:

1. **Core Module** (`src/whisper_transcription_tool/core/`)
   - Config management, logging, model management
   - Event system for WebSocket communication
   - File management and utilities

2. **Module 1: Transcription** (`module1_transcribe/`)
   - Whisper.cpp wrapper for local transcription
   - Output formatting (TXT, SRT, VTT)
   - Model management with automatic downloads

3. **Module 2: Video Extraction** (`module2_extract/`)
   - FFmpeg wrapper for audio extraction from videos
   - Supports MP4, MOV, AVI formats

4. **Module 5: Text Correction** (`module5_text_correction/`)
   - Local LLM-based text correction with LeoLM
   - Post-processing for transcription quality improvement
   - Configurable correction levels

5. **Web Interface** (`web/`)
   - FastAPI-based web server
   - WebSocket support for real-time progress
   - Static files and Jinja2 templates

## Key Technical Details

- **Models**: Default model is `large-v3-turbo`, stored in `models/` directory
- **Outputs**: Transcriptions saved to `transcriptions/` directory
- **Temp files**: Located in `transcriptions/temp/`
- **Config**: User config at `~/.whisper_tool.json`
- **Dynamic library paths**: Handled via DYLD_LIBRARY_PATH for Whisper.cpp dependencies

## Important Notes

- The application uses Whisper.cpp binaries located in `deps/whisper.cpp/build/bin/`
- FFmpeg is required for video processing (auto-installed via install.sh)
- WebSocket events are used for real-time progress updates during transcription
- The start_server.sh script handles port conflicts and manages running instances

## Path Migration Notes

All paths have been migrated from cloud storage to local:
- OLD: `~/Library/CloudStorage/GoogleDrive-[email]/...`
- NEW: `/path/to/whisper_clean/...`

Files that were updated:
1. `~/.whisper_tool.json` - Configuration file with all paths
2. `src/whisper_transcription_tool/module1_transcribe/__init__.py` - Removed old symlink workaround
3. `start_server.sh` - Updated to use local paths and check for venv_new
4. `Whisper Transkriptionstool.command` - Updated path
5. `Whisper Transkriptionstool.applescript` - Updated path
6. `restore_backup.sh` - Updated backup paths
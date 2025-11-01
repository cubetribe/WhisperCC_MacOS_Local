# Technology Stack

## Core Technologies

- **Python 3.11+** - Primary development language
- **Whisper.cpp** - Local audio transcription engine (Apple Silicon optimized)
- **FFmpeg** - Video-to-audio extraction and processing
- **FastAPI** - Web framework for REST API and web interface
- **WebSockets** - Real-time communication for progress updates
- **Uvicorn** - ASGI server for web application

## Key Dependencies

### Core Libraries
- `numpy` - Numerical computing
- `tqdm` - Progress bars
- `pyyaml` - Configuration file parsing
- `psutil` - System resource monitoring

### Web Framework
- `fastapi>=0.116.0` - Web API framework
- `uvicorn>=0.35.0` - ASGI server
- `jinja2>=3.1.0` - Template engine
- `websockets>=15.0.0` - WebSocket support
- `python-multipart` - File upload handling

### Audio/Video Processing
- `srt>=3.5.0` - SRT subtitle format handling
- `sounddevice>=0.4.6` - Audio recording capabilities

### Optional Features
- `chromadb` - Vector database for chatbot
- `faiss-cpu` - Similarity search
- `sentence-transformers` - Text embeddings
- `gradio` - Alternative web interface

## Build System

### Package Management
- Uses `setuptools` with `setup.py`
- Supports editable installation: `pip install -e .`
- Multiple install extras: `[web]`, `[chatbot]`, `[dev]`, `[full]`

### Virtual Environment
- Primary: `venv_new/` (recommended)
- Fallback: `venv/`

## Common Commands

### Development Setup
```bash
# Create and activate virtual environment
python3 -m venv venv_new
source venv_new/bin/activate

# Install in development mode
pip install -e ".[web]"

# Install all dependencies
pip install -r requirements.txt
```

### Running the Application
```bash
# Start web server (recommended)
python -m src.whisper_transcription_tool.main web --port 8090

# CLI transcription
python -m src.whisper_transcription_tool.main transcribe audio.mp3

# Extract audio from video
python -m src.whisper_transcription_tool.main extract video.mp4
```

### Binary Dependencies
```bash
# Make Whisper binary executable
chmod +x deps/whisper.cpp/build/bin/whisper-cli

# Install FFmpeg (macOS)
brew install ffmpeg

# Install BlackHole for live recording
brew install --cask blackhole-2ch
```

### Testing
```bash
# Run tests
pytest

# Code formatting
black src/
isort src/

# Type checking
mypy src/
```

## Configuration

- **Format**: JSON or YAML
- **Locations**: `~/.whisper_tool.json`, `~/.config/whisper_tool/config.json`
- **Dynamic path resolution** for cross-platform compatibility
- **Environment-specific settings** for model paths, output directories
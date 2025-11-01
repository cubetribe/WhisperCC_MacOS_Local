# Project Structure

## Directory Organization

```
whisper_clean/
├── src/                          # Main source code
│   └── whisper_transcription_tool/
│       ├── core/                 # Shared functionality
│       ├── module1_transcribe/   # Audio transcription
│       ├── module2_extract/      # Video-to-audio extraction
│       ├── module3_phone/        # Phone call processing
│       ├── module4_chatbot/      # Transcript analysis
│       ├── web/                  # Web interface
│       └── main.py              # CLI entry point
├── deps/                         # External dependencies
│   └── whisper.cpp/             # Whisper.cpp submodule
├── models/                       # Whisper model files
├── transcriptions/               # Output directory
│   └── temp/                    # Temporary files
├── recordings/                   # Input audio/video files
├── scripts/                      # Launch and utility scripts
├── documentation/                # Project documentation
└── venv_new/                    # Virtual environment
```

## Module Architecture

### Core Module (`src/whisper_transcription_tool/core/`)
- `config.py` - Configuration management with dynamic path resolution
- `models.py` - Data models and enums (WhisperModel, OutputFormat)
- `exceptions.py` - Custom exception classes
- `logging_setup.py` - Centralized logging configuration
- `utils.py` - Shared utility functions
- `constants.py` - Application constants
- `events.py` - Event system for module communication

### Module 1: Transcription (`module1_transcribe/`)
- `whisper_wrapper.py` - Whisper.cpp integration
- `model_manager.py` - Model download and management
- `output_formatter.py` - Format conversion (TXT, SRT, VTT)

### Module 2: Extraction (`module2_extract/`)
- `ffmpeg_wrapper.py` - FFmpeg integration
- `video_utils.py` - Video processing utilities

### Module 3: Phone Processing (`module3_phone/`)
- `recorder.py` - Audio recording with BlackHole
- `audio_processing.py` - Dual-track audio handling
- `transcript_processing.py` - Dialog formatting
- `cli.py` - Phone-specific CLI interface

### Module 4: Chatbot (`module4_chatbot/`)
- `llm_manager.py` - Local LLM integration
- `vector_db.py` - Vector database for semantic search

### Web Interface (`web/`)
- `templates/` - Jinja2 HTML templates
- `static/` - CSS, JavaScript, assets
- `phone_routes.py` - Phone-specific web routes
- `compare_utils.py` - Transcript comparison utilities

## File Naming Conventions

- **Python modules**: `snake_case.py`
- **Classes**: `PascalCase`
- **Functions/variables**: `snake_case`
- **Constants**: `UPPER_SNAKE_CASE`
- **Configuration files**: `.json` or `.yaml`
- **Scripts**: `.sh`, `.command`, `.py`

## Import Structure

- **Relative imports** within modules: `from .core import config`
- **Absolute imports** for cross-module: `from whisper_transcription_tool.core import config`
- **Entry point**: `python -m src.whisper_transcription_tool.main`

## Configuration Hierarchy

1. **Default config** in `core/config.py`
2. **User config** at `~/.whisper_tool.json`
3. **Project config** (if specified via `--config`)
4. **Command-line arguments** (highest priority)

## Output Organization

- **Transcriptions**: `transcriptions/` directory
- **Temporary files**: `transcriptions/temp/`
- **Models**: `models/` directory
- **Logs**: Configured via logging setup
- **Backups**: `Backups/` directory (version-specific)

## Development Patterns

- **Modular design**: Each module is self-contained
- **Configuration-driven**: Behavior controlled via config files
- **Error handling**: Custom exceptions with detailed messages
- **Logging**: Centralized logging with configurable levels
- **Type hints**: Used throughout for better IDE support
- **Async/await**: Used in web interface for non-blocking operations
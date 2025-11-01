# Whisper Transcription Tool

🎙️ **A powerful, modular Python tool for audio/video transcription using Whisper.cpp**

[![Version](https://img.shields.io/badge/version-0.9.6-blue.svg)](https://github.com/cubetribe/WhisperCC_MacOS_Local)
[![Python](https://img.shields.io/badge/python-3.11%2B-green.svg)](https://www.python.org/)
[![License](https://img.shields.io/badge/license-Personal%20Use%20%7C%20Commercial%20on%20Request-orange.svg)](LICENSE)
[![Website](https://img.shields.io/badge/website-goaiex.com-orange.svg)](https://www.goaiex.com)

## 📋 Aktueller Status - Version 0.9.6

**✅ STABLE RELEASE - CODEBASE CLEANUP**

Diese Version fokussiert auf die Kernfunktionalität: Transkription mit Whisper.cpp und optionale LLM-Textkorrektur. Phone Recording und Chatbot-Module wurden entfernt für eine schlankere, wartbarere Codebasis.

### ✅ Was funktioniert
- ✅ Whisper-Transkription mit large-v3-turbo (optimiert für Apple Silicon)
- ✅ Video-Extraktion mit FFmpeg
- ✅ LLM-Textkorrektur mit LeoLM (optional)
- ✅ Web-Interface mit Echtzeit-Updates
- ✅ Alle Ausgabeformate (TXT, SRT, VTT, JSON)
- ✅ Stabile Verarbeitung von Dateien beliebiger Länge (v0.9.7.5 Fix integriert)

### 🧹 Änderungen in v0.9.6
- Entfernt: Phone Recording (Module 3)
- Entfernt: Chatbot-Integration (Module 4)
- Fokus: Saubere, fokussierte Transkriptions-App mit Web-GUI

**Status: STABLE - READY FOR PRODUCTION USE**

## ✨ Features

- 🚀 **Local transcription** with Whisper.cpp (no API needed)
- 🍎 **Optimized for Apple Silicon** Macs
- 🌐 **Web interface** with real-time progress updates
- 📁 **Batch processing** for multiple files
- 🎬 **Video support** with automatic audio extraction
- 🖥️ **Refined GUI** with clearer workflows and status feedback
- 📄 **Multiple output formats** (TXT, SRT, VTT, JSON)
- 🧹 **Automatic cleanup** of temporary files
- 🎵 **Opus support** for WhatsApp voice messages
- ✍️ **LLM text correction** with LeoLM for German text improvement
- 🧠 **Local AI processing** - no cloud dependencies
- ⚡ **Stable processing** of large audio files (>30 min)

> ℹ️ Hinweis: Das Repository heißt jetzt `WhisperCC_MacOS_Local` (zuvor `Whisper-Transcription-Tool`). Bitte aktualisiere lokale Git-Remotes entsprechend.

## 🚀 Quick Start

### Fastest Way to Start
```bash
# Clone the repository
git clone https://github.com/cubetribe/WhisperCC_MacOS_Local.git
cd WhisperCC_MacOS_Local

# Activate virtual environment
source venv_new/bin/activate  # Use venv_new, NOT venv

# Start the web server
python -m src.whisper_transcription_tool.main web --port 8090
```

Then open http://localhost:8090 in your browser.

### Alternative: Using Start Script
```bash
./start_server.sh
```

## 🔧 Installation

### Prerequisites
- Python 3.8+
- macOS (optimized for Apple Silicon)
- FFmpeg (auto-installed via install.sh)

### Full Setup
```bash
# 1. Clone repository
git clone https://github.com/cubetribe/WhisperCC_MacOS_Local.git
cd WhisperCC_MacOS_Local

# 2. Create virtual environment
python3 -m venv venv_new
source venv_new/bin/activate

# 3. Install dependencies
pip install -r requirements.txt
pip install -e ".[full]"

# 4. Setup Whisper.cpp and FFmpeg
bash install.sh

# 5. Make whisper binary executable
chmod +x deps/whisper.cpp/build/bin/whisper-cli
```

## 📁 Project Structure

```
whisper_clean/
├── src/                              # Main source code
│   └── whisper_transcription_tool/
│       ├── core/                     # Core functionality
│       ├── module1_transcribe/       # Transcription module
│       ├── module2_extract/          # Video extraction
│       ├── module5_text_correction/  # LLM text correction
│       └── web/                      # Web interface
├── models/                           # Whisper models
├── transcriptions/                   # Output directory
├── deps/                            # Dependencies (Whisper.cpp)
├── scripts/                         # Utility scripts
└── start_server.sh                  # Server start script
```

## 💻 Usage

### Web Interface (Recommended)
```bash
# Start server
./start_server.sh
# Open http://localhost:8090
```

### Command Line
```bash
# Transcribe audio/video
whisper-tool transcribe path/to/audio.mp3 --model large-v3-turbo

# Extract audio from video
whisper-tool extract path/to/video.mp4
```

## 🎯 Available Models

- `tiny` - Fastest, least accurate (39 MB)
- `base` - Fast, good accuracy (74 MB)
- `small` - Balanced speed/accuracy (244 MB)
- `medium` - Slower, better accuracy (769 MB)
- `large-v3` - Best accuracy (1550 MB)
- **`large-v3-turbo`** - Best balance (recommended, 809 MB)

## 🔧 Textkorrektur mit LeoLM

### ✨ Features
- 🎯 **Automatische Rechtschreibkorrektur** deutscher Texte
- 🧮 **Grammatik-Verbesserung** mit intelligenter Satzstruktur-Optimierung
- 🎨 **Drei Korrekturstufen**: Basic, Advanced, Formal
- 💾 **Lokale Verarbeitung** mit LeoLM-13B (Hessian.AI)
- ⚡ **Metal-optimiert** für Apple Silicon Macs
- 🧩 **Intelligente Textaufteilung** für große Dokumente

### 📋 Requirements
- **Memory**: 6GB RAM minimum (für LeoLM-13B)
- **OS**: macOS mit Apple Silicon (Metal acceleration)
- **Python**: 3.8+
- **Model**: LeoLM-13B-Chat Q4_K_M (~7.5GB)

### 🚀 Setup

1. **Model Download**:
   ```bash
   # Install LM Studio (recommended)
   # Download: LeoLM-hesseianai-13b-chat-GGUF (Q4_K_M variant)
   # Default path: ~/.lmstudio/models/mradermacher/...
   ```

2. **Dependencies**:
   ```bash
   pip install llama-cpp-python
   # Metal support is included by default on macOS
   ```

3. **Configuration**:
   ```bash
   # Edit ~/.whisper_tool.json
   {
     "text_correction": {
       "enabled": true,
       "model_path": "/path/to/LeoLM-hesseianai-13b-chat.Q4_K_M.gguf",
       "context_length": 2048,
       "correction_level": "standard",
       "temperature": 0.3
     }
   }
   ```

### 💻 Usage

**Web Interface** (recommended):
```bash
./start_server.sh
# Navigate to Transcribe page
# Enable "Text Correction" checkbox
# Select correction level
```

**Command Line**:
```bash
# Quick correction
whisper-tool correct "Dein text mit fehlern."

# Advanced correction
whisper-tool correct --level advanced --input file.txt --output corrected.txt
```

**Python API**:
```python
from whisper_transcription_tool.module5_text_correction import LLMCorrector

with LLMCorrector() as corrector:
    corrected = corrector.correct_text(
        "Dein text mit fehlern.",
        correction_level="advanced"
    )
```

### 🎯 Correction Levels

- **Basic**: Rechtschreibung, Grammatik, Zeichensetzung
- **Advanced**: + Stil-Optimierung, bessere Lesbarkeit
- **Formal**: + Professionelle Sprache, formeller Ton

### ⚠️ Important Notes

- **First run**: Model loading takes 30-60 seconds
- **Memory**: Keep 6GB+ RAM free during correction
- **Performance**: ~50-100 tokens/second on Apple Silicon
- **Language**: Optimized for German text (English prompts available)

## 🗺️ Roadmap & Next Steps

- ✅ GUI-Überarbeitung ist in Version 0.9.7 live.
- ✅ LLM-Textkorrektur mit LeoLM implementiert.
- ⏸️ Telefonaufzeichnung bleibt vorerst im Code, aber wird erst nach Stabilitätsverbesserungen wieder aktiviert.
- 🔄 Nächster Schwerpunkt: Performance-Optimierung und erweiterte Korrekturfunktionen.

## 🛠️ Troubleshooting

### Permission Denied Error
```bash
chmod +x deps/whisper.cpp/build/bin/whisper-cli
```

### Port Already in Use
```bash
# The start script handles this automatically
# Or manually change port:
python -m src.whisper_transcription_tool.main web --port 8091
```

### Virtual Environment Issues
- Primary: Use `venv_new`
- Fallback: `venv`
- The start_server.sh script checks for both

## 📖 Documentation

- [Full Documentation](documentation/README.md)
- [Text Correction Guide](documentation/TEXTKORREKTUR.md)
- [Configuration Examples](documentation/CONFIG_EXAMPLES.md)
- [Troubleshooting Guide](documentation/TROUBLESHOOTING.md)
- [Frequently Asked Questions](documentation/FAQ.md)
- [Installation Guide](documentation/INSTALLATION.md)
- [Claude Code Instructions](CLAUDE.md)
- [Changelog](CHANGELOG.md)

## 🔐 License

**PERSONAL USE LICENSE**  
Copyright © 2025 Dennis Westermann - aiEX Academy  
Website: [www.goaiex.com](https://www.goaiex.com)

### 📋 License Terms

#### ✅ Free for Personal Use:
- Personal projects and learning
- Educational and academic research
- Non-profit personal use

#### 💼 Commercial & Enterprise Use:
**Available upon request!** We offer flexible licensing options for:
- Commercial products and services
- Business and enterprise deployment
- Professional services and consulting
- Revenue-generating activities

### 📧 Get a Commercial License

For commercial or enterprise licensing, please contact:
- **Email**: mail@goaiex.com
- **Website**: [www.goaiex.com](https://www.goaiex.com)

We're happy to discuss your needs and provide appropriate licensing terms.

See the [LICENSE](LICENSE) file for full terms and conditions.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

- **GitHub Issues**: [Report bugs or request features](https://github.com/cubetribe/WhisperCC_MacOS_Local/issues)
- **Website**: [www.goaiex.com](https://www.goaiex.com)
- **Documentation**: See the `documentation/` directory

---

**Version:** 0.9.7.3 | **Status:** Debug-Build ⚠️ (LLM-Korrektur ohne Wirkung)

Made with ❤️ by aiEX Academy for the transcription community

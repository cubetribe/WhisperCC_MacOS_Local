"""
Main application module for the Whisper Transcription Tool.
"""

import argparse
import logging
import sys
from pathlib import Path
from typing import Dict, Optional

from .core.config import load_config, save_config
from .core.logging_setup import setup_logging
from .core.models import OutputFormat, WhisperModel

logger = logging.getLogger(__name__)


def parse_args():
    """Parse command line arguments."""
    parser = argparse.ArgumentParser(
        description="Whisper Transcription Tool - A modular Python tool for audio transcription"
    )
    
    # Global options
    parser.add_argument(
        "--config", 
        help="Path to configuration file"
    )
    parser.add_argument(
        "--log-level", 
        choices=["DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"],
        default="INFO",
        help="Logging level"
    )
    
    # Subcommands
    subparsers = parser.add_subparsers(dest="command", help="Command to run")
    
    # Transcribe command
    transcribe_parser = subparsers.add_parser("transcribe", help="Transcribe audio file")
    transcribe_parser.add_argument(
        "audio_file", 
        help="Path to audio file"
    )
    transcribe_parser.add_argument(
        "--model", 
        choices=[m.value for m in WhisperModel],
        default=WhisperModel.LARGE_V3_TURBO.value,
        help="Whisper model to use"
    )
    transcribe_parser.add_argument(
        "--language", 
        help="Language code (leave empty for auto-detection)"
    )
    transcribe_parser.add_argument(
        "--output-format", 
        choices=[f.value for f in OutputFormat],
        default=OutputFormat.TXT.value,
        help="Output format"
    )
    transcribe_parser.add_argument(
        "--output", 
        help="Output file path"
    )
    transcribe_parser.add_argument(
        "--srt-max-chars",
        type=int,
        default=None,
        help="Max chars per subtitle segment for SRT"
    )
    transcribe_parser.add_argument(
        "--srt-max-duration",
        type=float,
        default=None,
        help="Max duration per subtitle segment in seconds"
    )
    transcribe_parser.add_argument(
        "--enable-correction",
        action="store_true",
        help="Enable text correction using LeoLM model"
    )
    transcribe_parser.add_argument(
        "--correction-level",
        choices=["light", "standard", "strict"],
        default="standard",
        help="Text correction level (default: standard)"
    )
    transcribe_parser.add_argument(
        "--dialect-normalization",
        action="store_true",
        help="Enable dialect normalization during text correction"
    )
    
    # Extract command
    extract_parser = subparsers.add_parser("extract", help="Extract audio from video")
    extract_parser.add_argument(
        "video_file", 
        help="Path to video file"
    )
    extract_parser.add_argument(
        "--output",
        help="Output audio file path"
    )

    # Web command
    web_parser = subparsers.add_parser("web", help="Start web interface")
    web_parser.add_argument(
        "--host",
        default="0.0.0.0",
        help="Host to bind to"
    )
    web_parser.add_argument(
        "--port",
        type=int,
        default=8000,
        help="Port to bind to"
    )

    # Status command
    status_parser = subparsers.add_parser("status", help="Check system and text correction status")
    status_parser.add_argument(
        "--correction",
        action="store_true",
        help="Show only text correction status"
    )
    
    return parser.parse_args()


def main():
    """Main entry point for the application."""
    args = parse_args()
    
    # Load configuration
    config = load_config(args.config)
    
    # Setup logging
    setup_logging(log_level=args.log_level, config=config)
    
    logger.info("Starting Whisper Transcription Tool")
    
    # Handle commands
    if args.command == "transcribe":
        from .module1_transcribe import transcribe_audio
        
        # Update config with CLI overrides for text correction
        if args.enable_correction:
            config.setdefault("text_correction", {})["enabled"] = True
        if hasattr(args, 'correction_level') and args.correction_level:
            config.setdefault("text_correction", {})["correction_level"] = args.correction_level
        if args.dialect_normalization:
            config.setdefault("text_correction", {})["dialect_normalization"] = True

        result = transcribe_audio(
            audio_path=args.audio_file,
            output_format=args.output_format,
            language=args.language,
            model=args.model,
            output_path=args.output,
            srt_max_chars=args.srt_max_chars,
            srt_max_duration=args.srt_max_duration,
            config=config
        )
        
        if result.success:
            logger.info(f"Transcription completed: {result.output_file}")
            if result.text:
                print(result.text)
        else:
            logger.error(f"Transcription failed: {result.error}")
            return 1
    
    elif args.command == "extract":
        from .module2_extract import extract_audio
        
        result = extract_audio(
            args.video_file,
            output_path=args.output,
            config=config
        )
        
        if result.success:
            logger.info(f"Audio extraction completed: {result.audio_path}")
        else:
            logger.error(f"Audio extraction failed: {result.error}")
            return 1

    elif args.command == "web":
        try:
            from .web import start_web_server
            
            start_web_server(
                host=args.host,
                port=args.port,
                config_path=args.config
            )
        except ImportError:
            logger.error("Web dependencies not installed. Install with pip install 'whisper_transcription_tool[web]'")
            return 1

    elif args.command == "status":
        from .core.config import print_correction_status, is_correction_available

        if args.correction:
            # Show only text correction status
            print_correction_status(config)
        else:
            # Show general system status
            print(f"Whisper Transcription Tool - System Status")
            print(f"Config loaded: {'✅' if config else '❌'}")
            print(f"Project root: {config.get('whisper', {}).get('model_path', 'Unknown')}")

            # Check text correction
            correction_status = is_correction_available(config)
            correction_enabled = config.get("text_correction", {}).get("enabled", False)

            print(f"Text correction: {'✅ Enabled' if correction_enabled else '❌ Disabled'}")
            print(f"Text correction available: {'✅ Yes' if correction_status['available'] else '❌ No'}")

            if not correction_status['available']:
                print(f"  Reason: {correction_status['reason']}")

            print("\nUse --correction flag to see detailed text correction status")

    else:
        logger.error("No command specified")
        return 1
    
    return 0


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""
Model Download Helper for Whisper Transcription Tool

This script helps download and validate LLM models for text correction.
It specifically targets LeoLM models optimized for German text.
"""

import os
import sys
import json
import hashlib
import argparse
import subprocess
from pathlib import Path
from urllib.parse import urlparse
from typing import Optional, Dict, Any

# Add project root to path
PROJECT_ROOT = Path(__file__).parent.parent
sys.path.insert(0, str(PROJECT_ROOT))


# Known model configurations
KNOWN_MODELS = {
    "leolm-13b-q4": {
        "name": "LeoLM 13B Chat (Q4_K_M)",
        "url": "https://huggingface.co/mradermacher/LeoLM-hesseianai-13b-chat-GGUF/resolve/main/LeoLM-hesseianai-13b-chat.Q4_K_M.gguf",
        "size_gb": 7.5,
        "filename": "LeoLM-hesseianai-13b-chat.Q4_K_M.gguf",
        "description": "Optimized German LLM, 4-bit quantization, best balance",
        "ram_required_gb": 8
    },
    "leolm-13b-q3": {
        "name": "LeoLM 13B Chat (Q3_K_M)",
        "url": "https://huggingface.co/mradermacher/LeoLM-hesseianai-13b-chat-GGUF/resolve/main/LeoLM-hesseianai-13b-chat.Q3_K_M.gguf",
        "size_gb": 6.0,
        "filename": "LeoLM-hesseianai-13b-chat.Q3_K_M.gguf",
        "description": "Smaller quantization, lower quality but uses less RAM",
        "ram_required_gb": 6
    },
    "leolm-7b-q4": {
        "name": "LeoLM 7B Chat (Q4_K_M)",
        "url": "https://huggingface.co/LeoLM/leo-hessianai-7b-chat-gguf/resolve/main/leo-hessianai-7b-chat-q4_k_m.gguf",
        "size_gb": 4.0,
        "filename": "leo-hessianai-7b-chat-q4_k_m.gguf",
        "description": "Smaller 7B model, faster but less capable",
        "ram_required_gb": 5
    }
}


def get_default_model_dir() -> Path:
    """Get the default model directory."""
    # Check for LM Studio directory first
    lmstudio_dir = Path.home() / ".lmstudio" / "models"
    if lmstudio_dir.exists():
        return lmstudio_dir

    # Fallback to project models directory
    return PROJECT_ROOT / "models" / "llm"


def check_disk_space(path: Path, required_gb: float) -> bool:
    """Check if there's enough disk space."""
    import shutil
    stat = shutil.disk_usage(path)
    available_gb = stat.free / (1024**3)
    return available_gb >= required_gb


def download_with_wget(url: str, output_path: Path) -> bool:
    """Download file using wget with progress bar."""
    try:
        cmd = ["wget", "-c", "-O", str(output_path), url]
        result = subprocess.run(cmd, check=True)
        return result.returncode == 0
    except subprocess.CalledProcessError as e:
        print(f"Error downloading with wget: {e}")
        return False
    except FileNotFoundError:
        print("wget not found. Install with: brew install wget")
        return False


def download_with_curl(url: str, output_path: Path) -> bool:
    """Download file using curl with progress bar."""
    try:
        cmd = ["curl", "-L", "-C", "-", "-o", str(output_path), url]
        result = subprocess.run(cmd, check=True)
        return result.returncode == 0
    except subprocess.CalledProcessError as e:
        print(f"Error downloading with curl: {e}")
        return False


def validate_gguf_file(file_path: Path) -> Dict[str, Any]:
    """Validate that a file is a valid GGUF model."""
    result = {
        "valid": False,
        "error": None,
        "size_gb": 0
    }

    if not file_path.exists():
        result["error"] = "File does not exist"
        return result

    # Check file size
    result["size_gb"] = file_path.stat().st_size / (1024**3)

    # Check GGUF header
    try:
        with open(file_path, 'rb') as f:
            header = f.read(4)
            if header == b'GGUF':
                result["valid"] = True
            else:
                result["error"] = f"Invalid header: {header.hex()}"
    except Exception as e:
        result["error"] = f"Could not read file: {e}"

    return result


def list_models():
    """List all available models for download."""
    print("\n🤖 Available Models for Download:\n")
    print("-" * 60)

    for key, model in KNOWN_MODELS.items():
        print(f"\n📦 {key}:")
        print(f"   Name: {model['name']}")
        print(f"   Size: {model['size_gb']:.1f} GB")
        print(f"   RAM Required: {model['ram_required_gb']} GB")
        print(f"   Description: {model['description']}")

    print("\n" + "-" * 60)


def download_model(model_key: str, output_dir: Optional[Path] = None) -> bool:
    """Download a specific model."""
    if model_key not in KNOWN_MODELS:
        print(f"❌ Unknown model: {model_key}")
        print("Available models:", ", ".join(KNOWN_MODELS.keys()))
        return False

    model = KNOWN_MODELS[model_key]

    # Determine output directory
    if output_dir is None:
        output_dir = get_default_model_dir()

    # Create directory structure similar to LM Studio
    model_dir = output_dir / "mradermacher" / "LeoLM-hesseianai-13b-chat-GGUF"
    model_dir.mkdir(parents=True, exist_ok=True)

    output_path = model_dir / model["filename"]

    print(f"\n📥 Downloading {model['name']}...")
    print(f"   URL: {model['url']}")
    print(f"   Destination: {output_path}")
    print(f"   Size: {model['size_gb']:.1f} GB")

    # Check if file already exists
    if output_path.exists():
        print("\n⚠️  File already exists. Validating...")
        validation = validate_gguf_file(output_path)
        if validation["valid"]:
            print(f"✅ Existing file is valid ({validation['size_gb']:.1f} GB)")
            return True
        else:
            print(f"❌ Existing file is invalid: {validation['error']}")
            print("   Removing and re-downloading...")
            output_path.unlink()

    # Check disk space
    if not check_disk_space(output_path.parent, model["size_gb"] * 1.2):
        print(f"❌ Not enough disk space. Need at least {model['size_gb'] * 1.2:.1f} GB")
        return False

    # Try downloading with wget first, then curl
    print("\n⏳ Starting download (this may take a while)...")
    success = download_with_wget(model["url"], output_path)
    if not success:
        print("Trying with curl...")
        success = download_with_curl(model["url"], output_path)

    if not success:
        print("❌ Download failed")
        return False

    # Validate downloaded file
    print("\n🔍 Validating downloaded file...")
    validation = validate_gguf_file(output_path)

    if validation["valid"]:
        print(f"✅ Model downloaded successfully ({validation['size_gb']:.1f} GB)")

        # Update config
        update_config(output_path)
        return True
    else:
        print(f"❌ Downloaded file is invalid: {validation['error']}")
        return False


def update_config(model_path: Path):
    """Update the Whisper tool configuration with the new model path."""
    config_path = Path.home() / ".whisper_tool.json"

    try:
        # Load existing config
        if config_path.exists():
            with open(config_path, 'r') as f:
                config = json.load(f)
        else:
            config = {}

        # Update text_correction section
        if "text_correction" not in config:
            config["text_correction"] = {}

        config["text_correction"]["model_path"] = str(model_path)
        config["text_correction"]["enabled"] = True

        # Save updated config
        with open(config_path, 'w') as f:
            json.dump(config, f, indent=2)

        print(f"\n✅ Configuration updated: {config_path}")
        print(f"   Model path: {model_path}")

    except Exception as e:
        print(f"\n⚠️  Could not update config: {e}")
        print(f"   Please manually update {config_path}")
        print(f"   Set text_correction.model_path to: {model_path}")


def main():
    """Main entry point."""
    parser = argparse.ArgumentParser(
        description="Download and manage LLM models for text correction"
    )

    subparsers = parser.add_subparsers(dest="command", help="Commands")

    # List command
    list_parser = subparsers.add_parser("list", help="List available models")

    # Download command
    download_parser = subparsers.add_parser("download", help="Download a model")
    download_parser.add_argument(
        "model",
        choices=list(KNOWN_MODELS.keys()),
        help="Model to download"
    )
    download_parser.add_argument(
        "--output-dir",
        type=Path,
        help="Output directory (default: auto-detect)"
    )

    # Validate command
    validate_parser = subparsers.add_parser("validate", help="Validate a model file")
    validate_parser.add_argument(
        "path",
        type=Path,
        help="Path to model file"
    )

    args = parser.parse_args()

    if args.command == "list" or args.command is None:
        list_models()
        print("\n💡 To download a model, run:")
        print("   python download_models.py download leolm-13b-q4")

    elif args.command == "download":
        success = download_model(args.model, args.output_dir)
        sys.exit(0 if success else 1)

    elif args.command == "validate":
        validation = validate_gguf_file(args.path)
        if validation["valid"]:
            print(f"✅ Valid GGUF file ({validation['size_gb']:.1f} GB)")
        else:
            print(f"❌ Invalid: {validation['error']}")
        sys.exit(0 if validation["valid"] else 1)


if __name__ == "__main__":
    main()
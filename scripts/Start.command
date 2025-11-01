#!/bin/bash

#########################################
# Whisper Transcription Tool
# Start Script for macOS
# Version: 0.9.6
# Copyright © 2025 Dennis Westermann
#########################################

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory of this script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to project directory
cd "$PROJECT_ROOT"

clear
echo "╔══════════════════════════════════════════════════════════╗"
echo "║      WHISPER TRANSCRIPTION TOOL - STARTING...           ║"
echo "║                    Version 0.9.6                         ║"
echo "║           Copyright © 2025 Dennis Westermann            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# Function to print status
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

# Function to kill existing server on port
kill_existing_server() {
    local PORT=$1
    local PID=$(lsof -ti:$PORT)
    
    if [ ! -z "$PID" ]; then
        print_warning "Found existing process on port $PORT (PID: $PID)"
        print_status "Stopping existing server..."
        kill -9 $PID 2>/dev/null
        sleep 2
        print_success "Existing server stopped"
    fi
}

# Check if virtual environment exists
if [ -d "venv_new" ]; then
    VENV_PATH="venv_new"
elif [ -d "venv" ]; then
    VENV_PATH="venv"
else
    print_error "No virtual environment found!"
    echo ""
    echo "Please run the installation script first:"
    echo "  Double-click on 'Install.command'"
    echo ""
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

# Activate virtual environment
print_status "Activating virtual environment..."
source "$VENV_PATH/bin/activate"
print_success "Virtual environment activated"

# Check if the package is installed
if ! python -c "import src.whisper_transcription_tool" 2>/dev/null; then
    print_error "Whisper Transcription Tool is not installed!"
    echo ""
    echo "Please run the installation script first:"
    echo "  Double-click on 'Install.command'"
    echo ""
    echo "Press any key to exit..."
    read -n 1
    exit 1
fi

# Set default port
PORT=8090

# Check for port argument
if [ ! -z "$1" ]; then
    PORT=$1
fi

# Kill any existing server on the port
kill_existing_server $PORT

# Set library path for Whisper.cpp
export DYLD_LIBRARY_PATH="$PROJECT_ROOT/deps/whisper.cpp/build:$DYLD_LIBRARY_PATH"

# Function to open browser
open_browser() {
    sleep 3
    if command -v open &> /dev/null; then
        open "http://localhost:$PORT"
    fi
}

# Start browser opening in background
print_status "Opening browser..."
open_browser &

# Start the server
print_status "Starting Whisper Transcription Tool on port $PORT..."
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  Web interface available at: http://localhost:$PORT"
echo "  Press Ctrl+C to stop the server"
echo "════════════════════════════════════════════════════════════"
echo ""

# Run the server
python -m src.whisper_transcription_tool.main web --port $PORT

# Server stopped
echo ""
print_status "Server stopped"
echo "Press any key to exit..."
read -n 1

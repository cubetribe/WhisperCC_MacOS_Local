#!/bin/bash

# Einfacher Weg: Xcode öffnen und neues Projekt erstellen lassen

echo "🚀 WhisperLocal Xcode Projekt Setup"
echo "=================================="
echo ""

echo "1. Xcode öffnen..."
open /Applications/Xcode.app

echo ""
echo "2. Warte 10 Sekunden bis Xcode geladen ist..."
sleep 10

echo ""
echo "3. In Xcode:"
echo "   - File → New → Project wählen"
echo "   - macOS → App wählen"
echo "   - Product Name: WhisperLocalMacOs"
echo "   - Interface: SwiftUI"
echo "   - Language: Swift"
echo "   - Use Core Data: No"
echo "   - Bundle Identifier: com.github.cubetribe.whisper-transcription-tool"
echo "   - Location: $(pwd)"

echo ""
echo "4. Nach dem Erstellen:"
echo "   - Projekt wird automatisch geöffnet"
echo "   - Drücke ⌘+R zum Bauen und Starten"

echo ""
echo "✅ Xcode sollte jetzt offen sein!"
echo "Folge den Schritten oben um das Projekt zu erstellen."
# Whisper Transcription Tool (v0.9.7.5)

Ein modulares Python-Tool zur Transkription und Auswertung von Audio- und Videodaten mit Whisper.cpp, vollständig portabel und plattformunabhängig mit automatischer Audioextraktion.

## 🆕 Version 0.9.7.5 - Critical Stability Update (2025-11-01)

**Critical Fix**: Resolved subprocess PIPE deadlock causing crashes with audio files >30 minutes
- ✅ Thread-based PIPE drainage prevents deadlocks
- ✅ Configurable timeout mechanism (1 hour default)
- ✅ Automatic cleanup of temp files on errors
- ✅ 3.2 GB disk space recovered from orphaned files
- ✅ Full backward compatibility maintained

See [UPDATE_LOG.md](UPDATE_LOG.md) for complete details.

---

## 🚀 Schnellstart

### Option 1: Verwendung der neuen virtuellen Umgebung (empfohlen)
```bash
cd "/Users/denniswestermann/Desktop/Coding Projekte/whisper_clean"
source venv_new/bin/activate
python -m src.whisper_transcription_tool.main web --port 8090
```

### Option 2: Verwendung des Start-Skripts
```bash
cd "/Users/denniswestermann/Desktop/Coding Projekte/whisper_clean"
./start_server.sh
```

### Option 3: Doppelklick auf Launcher
- **QuickLauncher.command** - Startet die Anwendung mit automatischer Pfaderkennung
- **Whisper Transkriptionstool.command** - Alternative Startmethode

## ⚠️ Wichtige Hinweise

- **Projektpfad:** `/Users/denniswestermann/Desktop/Coding Projekte/whisper_clean`
- **Virtuelle Umgebung:** Verwendet `venv_new` (oder `venv` als Fallback)
- **Konfiguration:** Liegt in `~/.whisper_tool.json`
- **Whisper Binary:** `deps/whisper.cpp/build/bin/whisper-cli` (muss ausführbar sein: `chmod +x`)
- **Modelle:** Werden im Verzeichnis `models/` gespeichert
- **Transkriptionen:** Werden in `transcriptions/` gespeichert

## Übersicht

---

## SRT-Optionen: Zeilenumbruch-Steuerung

Ab Version 0.8.1.2 kannst du im SRT-Export folgende Optionen nutzen:

- **Maximale Zeichen pro Zeile:** Über einen Slider einstellbar (20–120).
- **Zeilenumbruch für Untertitel aktivieren:** Checkbox, standardmäßig aktiviert. Ist sie aktiviert, werden Untertitel in maximal zwei Zeilen (nach Zeichenlänge) umgebrochen. Ist sie deaktiviert, wird jeder Untertitel einzeilig ausgegeben (kein Zeilenumbruch, auch bei langen Sätzen).

**Hinweis:**
- Die Einstellung wirkt sich direkt auf die erzeugte SRT-Datei aus.
- Die Option ist sowohl für Einzel- als auch Batch-Transkriptionen verfügbar.
- Zeilenumbrüche in SRT werden jetzt immer als \r\n gespeichert (maximale Kompatibilität mit Playern und Editoren).

---

Dieses Projekt bietet eine modulare Lösung zur Transkription von Audiodaten mit Whisper.cpp, optimiert für Apple Silicon (M4-Chip). Die gesamte Lösung läuft lokal auf Ihrem Mac - ohne API-Abhängigkeiten bei der Transkription, was maximale Datenschutzkontrolle und Unabhängigkeit gewährleistet.

### Hauptmerkmale

- **Lokale Transkription** mit Whisper.cpp, optimiert für Apple Silicon
- **Direkte Videotranskription** mit automatischer Audioextraktion
- **Modulare Architektur** für einfache Erweiterbarkeit und Wartung
- **Volle Portabilität** mit dynamischen Pfaden und plattformunabhängiger Konfiguration
- **Einfacher Start** mit dem neuen QuickLauncher.command
- **Standard-Modell** 'large-v3-turbo' für optimale Ergebnisse
- **Verarbeitung von Telefonaufnahmen** mit zwei separaten Spuren
- **Chatbot-Schnittstelle** zur Analyse von Transkripten
- **Zentrale Konfiguration** mit allen Daten im Projektverzeichnis

## Modulare Architektur und Portabilität

Das Projekt ist in vier Hauptmodule unterteilt und unterstützt dank der dynamischen Pfadfindung nun verschiedene Betriebssysteme und Verzeichnisstrukturen:

1. **Modul 1: Lokale Audio-Transkription**
   - Transkription lokaler .mp3- und .wav-Dateien mit Whisper.cpp
   - Unterstützung für verschiedene Modellgrößen und Sprachen
   - Ausgabe in verschiedenen Formaten (.txt, .srt, .vtt)
   - Standardkonforme SRT-Untertitel mit präzisen Zeitangaben
   - Flexible Steuerung der Zeilenumbrüche in SRT-Untertiteln (einzeilig/zweizeilig)

2. **Modul 2: Video-Audioextraktion**
   - Extraktion des Tons aus Videos (.mp4, .mov) mit FFmpeg
   - Konvertierung in optimiertes Format für Whisper
   - Nahtlose Integration mit dem Transkriptionsmodul

3. **Modul 3: Telefonaufnahme-Verarbeitung**
   - Import von zwei separaten Audiospuren (Teilnehmer A und B)
   - Separate Transkription beider Spuren
   - Zusammenführung in ein dialogartiges Transkript

4. **Modul 4: Chatbot zur Transkriptanalyse**
   - Lokale Vektordatenbank für Transkripte
   - Semantische Suche in Transkripten
   - CLI- und Web-Schnittstelle (Gradio)

5. **Modul 5: Live-Telefonat mit Echtzeit-Aufzeichnung** (in Entwicklung)
   - Aufzeichnung von VoIP-Telefongesprächen
   - Automatische Trennung und Kennzeichnung der Gesprächsteilnehmer
   - Direkte Transkription mit Sprechererkennung
   - Nahtlose Integration mit dem Chatbot-Modul zur Gesprächsanalyse

## Architekturübersicht

![Systemarchitektur](docs/architecture_v0.6.png)
*Aktualisierte Architektur mit Video-Extraktionsmodul*

## Unterstützte Formate
| Video | Audio |
|-------|-------|
| MP4   | WAV   |
| MOV   | MP3   |
| AVI   | FLAC  |

## Aktueller Status & Ausblick (Version 0.9)

- **Version:** 0.9 (Stand: 2025-05-24)
- **Kernfunktionalität:** FFmpeg-basierte Video-Audioextraktion, Batch-Audio-Transkription, BlackHole-Audio-Aufnahme, standardkonforme SRT-Dateierzeugung
- **Letzte Aktualisierung:** 2025-05-11

### Neue Funktionen in Version 0.9:

- **WebSocket-Implementierung**
  - Verbesserte Event-Übertragung zwischen Server und Client
  - Echtzeit-Fortschrittsanzeige während der Transkription
  - Reaktivere Benutzeroberfläche für lange Verarbeitungsprozesse

- **Erweiterte Videokonvertierung**
  - Fortschrittsanzeige während der Videokonvertierung
  - Detaillierte Statusmeldungen während der Verarbeitung
  - Verbesserte Fehlerbehandlung bei der Audioextraktion

- **Automatisierte FFmpeg-Integration**
  - Automatische Installation von FFmpeg im Setup-Skript
  - Plattformunabhängige Konfiguration und Erkennung
  - Verbesserte Kompatibilität mit verschiedenen Systemen

- **Erweiterte Dateihandhabung**
  - Verbesserter Datei-Download aus benutzerdefinierten Verzeichnissen
  - Optimierte Pfadverarbeitung für Ausgabedateien
  - Konsistentes Verhalten bei relativen und absoluten Pfaden

### Kommende Verbesserungen:

- **Anpassbares Ausgabeverzeichnis**
  - Wiederherstellung der Funktionalität zur freien Wahl des Ausgabeverzeichnisses
  - Verbesserte Download-Links für generierte Dateien

### Neue Funktionen in Version 0.6.1:

- **Verbesserte Dokumentation**
  - Aktualisierte Projektdokumentation für alle Module
  - Optimierte README mit aktuellen Funktionen und Status
  - Erweiterte Fehlerbehandlungsdokumentation

- **Stabilere Modellverwaltung**
  - Verbesserungen im Download-System für Modelle
  - Robustere Fehlerbehandlung bei der Modellverarbeitung

### Neue Funktionen in Version 0.6:

- **Erweiterte Modellverwaltung**
  - Detaillierte Modellinformationen (Größe, Beschreibung, Anwendungsempfehlungen)
  - Automatische Abbildung von vereinfachten Modellnamen auf aktuelle Whisper.cpp-Versionen
  - Verbesserte Benutzeroberfläche mit Tab-Navigation zwischen empfohlenen und allen Modellen
  - Optimierte Fehlerbehandlung beim Modell-Download

- **Verbesserte Video-Extraktion**
  - Integration von FFmpeg zur Extraktion von Audio aus verschiedenen Videoformaten
  - Automatische Erkennung und optimale Konvertierung verschiedener Videoformate
  - Nahtlose Weiterleitung zur Transkription nach erfolgreicher Extraktion

- **Ausstehende Verbesserungen:**
  - Explizite UI-Unterstützung für Videoformate
  - Automatische FFmpeg-Installation im Setup-Skript
  - Fortschrittsanzeige und Feedback während Videokonvertierung
  - Erweiterte Fehlerbehandlung für problematische Videodateien

## Installation

### Voraussetzungen

- macOS mit Apple Silicon (M1, M2, M3, M4)
- Python 3.11 oder höher
- FFmpeg (für Videoextraktion)
- Whisper.cpp (bereits im Projekt enthalten)

### Schnellinstallation für bestehende Installation

```bash
# 1. Zum Projektverzeichnis wechseln
cd "/Users/denniswestermann/Desktop/Coding Projekte/whisper_clean"

# 2. Neue virtuelle Umgebung erstellen (falls nicht vorhanden)
python3 -m venv venv_new

# 3. Virtuelle Umgebung aktivieren
source venv_new/bin/activate

# 4. Abhängigkeiten installieren
pip install -r requirements.txt

# 5. App im Entwicklungsmodus installieren
pip install -e .

# 6. Whisper-CLI ausführbar machen
chmod +x deps/whisper.cpp/build/bin/whisper-cli

# 7. Server starten
python -m src.whisper_transcription_tool.main web --port 8090
```

### Vollständige Neuinstallation

```bash
# Repository klonen (falls noch nicht vorhanden)
git clone https://github.com/yourusername/whisper_transcription_tool.git
cd whisper_transcription_tool

# Installation über das Setup-Skript
bash install.sh
```

### Zusätzliche Abhängigkeiten

Für die Chatbot-Funktionalität:

```bash
pip install "whisper-transcription-tool[chatbot]"
```

Für die Web-Schnittstelle:

```bash
pip install "whisper-transcription-tool[web]"
```

Für standardkonforme SRT-Untertiteldateien:

```bash
pip install pysrt
```

Für Entwickler:

```bash
pip install "whisper-transcription-tool[dev]"
```

## Verwendung

### Web-Interface (empfohlen)

Nach dem Start ist die Web-Oberfläche unter http://localhost:8090 verfügbar.

### Kommandozeile

#### Transkription einer Audiodatei

```bash
whisper-tool transcribe path/to/audio.mp3 --model large-v3-turbo
```

### Extraktion und Transkription eines Videos

```bash
whisper-tool extract path/to/video.mp4
whisper-tool transcribe path/to/video.wav
```

### Verarbeitung von Telefonaufnahmen

```bash
whisper-tool phone path/to/caller_a.mp3 path/to/caller_b.mp3
```

### Starten des Chatbots

```bash
whisper-tool chatbot --transcript path/to/transcript.txt
```

Oder mit Web-Schnittstelle:

```bash
whisper-tool chatbot --transcript path/to/transcript.txt --mode web
```

## Konfiguration

Die Standardkonfiguration kann über eine JSON- oder YAML-Datei angepasst werden. Legen Sie eine Datei unter einem der folgenden Pfade an:

- `~/.whisper_tool.json`
- `~/.whisper_tool.yaml`
- `~/.config/whisper_tool/config.json`

Beispielkonfiguration:

```json
{
  "whisper": {
    "model_path": "/path/to/models",
    "default_model": "medium",
    "threads": 4
  },
  "ffmpeg": {
    "binary_path": "/usr/local/bin/ffmpeg",
    "audio_format": "wav",
    "sample_rate": 16000
  },
  "output": {
    "default_directory": "~/transcriptions",
    "default_format": "txt"
  },
  "chatbot": {
    "mode": "local",
    "model": "mistral-7b"
  }
}
```

## Entwicklung

### Projektstruktur

```
whisper_transcription_tool/
├── src/
│   └── whisper_transcription_tool/
│       ├── core/                  # Gemeinsame Funktionalität
│       ├── module1_transcribe/    # Transkriptionsmodul
│       ├── module2_extract/       # Videoextraktionsmodul
│       ├── module3_phone/         # Telefonaufnahme-Modul
│       └── module4_chatbot/       # Chatbot-Modul
├── tests/                         # Testfälle
├── docs/                          # Dokumentation
├── examples/                      # Beispiele
└── .github/                       # GitHub-Workflows
```

### Entwicklungsumgebung einrichten

```bash
# Repository klonen
git clone https://github.com/yourusername/whisper_transcription_tool.git
cd whisper_transcription_tool

# Entwicklungsabhängigkeiten installieren
pip install -e ".[dev]"

# Pre-commit-Hooks einrichten
pre-commit install
```

### Tests ausführen

```bash
pytest
```

## Mitwirken

Wir freuen uns über Beiträge! Bitte lesen Sie [CONTRIBUTING.md](CONTRIBUTING.md) für Details zum Prozess für Pull Requests.

## Lizenz

Dieses Projekt steht unter der MIT-Lizenz - siehe [LICENSE](LICENSE) für Details.

## Roadmap

- [ ] Integration von Sprecheridentifikation
- [ ] Unterstützung für weitere Sprachen
- [ ] Batch-Verarbeitung für große Mengen von Dateien
- [ ] Verbesserung der Chatbot-Funktionalität mit lokalen LLMs
- [ ] GUI-Anwendung für macOS

## Häufig gestellte Fragen

### Welche Whisper-Modelle werden unterstützt?

Alle Modelle von Whisper.cpp werden unterstützt: tiny, base, small, medium und large.

### Wie viel Speicher benötigen die Modelle?

- tiny: ~75MB
- base: ~150MB
- small: ~500MB
- medium: ~1.5GB
- large: ~3GB

### Funktioniert das Tool auch auf Intel Macs?

Ja, das Tool funktioniert auch auf Intel Macs, ist aber für Apple Silicon optimiert.

### Kann ich das Tool mit OpenAI's Whisper API verwenden?

Nein, dieses Tool ist speziell für die lokale Verarbeitung mit Whisper.cpp konzipiert. Für API-basierte Lösungen gibt es andere Tools.

## Kontakt

Bei Fragen oder Problemen erstellen Sie bitte ein [GitHub Issue](https://github.com/yourusername/whisper_transcription_tool/issues).

---

*Zuletzt aktualisiert: 2025-04-20*

## Web-Oberfläche

*   Starten mit `python -m src.whisper_transcription_tool.main web`.
*   Ermöglicht das Hochladen von Audio-/Videodateien (Video wird automatisch extrahiert).
*   Auswahl von Whisper-Modell, Sprache (optional) und Ausgabeformat.
*   Unterstützt Batch-Verarbeitung mehrerer Dateien.
*   **NEU:** Bietet eine eigene Seite zur **Modellverwaltung** (`/models`):
    *   Zeigt verfügbare Whisper-Modelle und deren Download-Status an.
    *   Ermöglicht das **Herunterladen** von Modellen direkt über die Oberfläche.
    *   Zeigt einen detaillierten **Fortschrittsdialog** während des Downloads an (Größe, Geschwindigkeit, verbleibende Zeit).
    *   Ermöglicht das **Ändern des Verzeichnisses**, in dem die Modelle gespeichert werden.
*   Zeigt Transkriptionsfortschritt in Echtzeit über WebSockets an.
*   Stellt Ergebnisse tabellarisch dar mit Download-Links für jedes Format.

## Bekannte Einschränkungen

- Die Fortschrittsanzeige bei Modell-Downloads zeigt nur an, dass ein Download läuft, aber keine Live-Updates
- WebSocket-Kommunikation für Echtzeit-Updates wird in Version 0.6.0 neu implementiert
- Download-Geschwindigkeit ist aktuell langsam (wird in zukünftiger Version optimiert)

## Bekannte Probleme

Siehe [PROBLEMS.md](PROBLEMS.md) für eine Liste bekannter technischer Herausforderungen und deren Lösungen.

## Roadmap

- Version 0.5.0: Video-Audioextraktion (aktuell in Entwicklung)
- Version 0.6.0: Überarbeitete WebSocket-Implementierung

### Geplante Features

| Modul | Beschreibung | Status |
|-------|--------------|-------------|
| System Audio Capture | Parallele Aufnahme von Mikrofon und Systemaudio | ✅ Implementiert (v0.5.0) |

## Aufnahme von Kommunikationsanwendungen

Das Tool unterstützt die Aufnahme von Gesprächen aus verschiedenen Kommunikationsanwendungen mit getrennten Audiospuren:

### Voraussetzungen

- [BlackHole](https://github.com/ExistentialAudio/BlackHole) Audio-Treiber (installierbar über `brew install --cask blackhole-2ch`)
- Unterstützte Anwendungen: Microsoft Teams, Discord, Zoom, Skype, WebEx, Google Meet, etc.

### Installation der Aufnahmefunktion

Die Aufnahmefunktion erfordert zusätzliche Abhängigkeiten. Folgen Sie diesen Schritten:

```bash
# BlackHole Virtual Audio Driver installieren
brew install --cask blackhole-2ch

# Nach der Installation einen Neustart durchführen oder Audio-Dienste neustarten

# Audio-Abhängigkeiten installieren (in der Projektumgebung)
cd /Pfad/zu/whisper_clean
source venv/bin/activate  # Falls noch nicht aktiviert
pip install -e ".[web]"   # Installiert im Entwicklungsmodus mit allen Web-Komponenten
```

> **Hinweis:** Bei Abhängigkeitsproblemen stellen Sie sicher, dass neue Pakete sowohl in `requirements.txt` als auch in den entsprechenden `extras_require`-Abschnitten in `setup.py` registriert sind.

### Aufnahmeprozess

1. Unter dem "Telefon"-Tab den Bereich "Live-Aufnahme" auswählen
2. Eigenes Mikrofon als Eingabegerät wählen
3. BlackHole als Ausgabegerät wählen
4. Audio-Routing in den Systemeinstellungen konfigurieren:
   - Öffnen Sie Systemeinstellungen → Ton
   - Setzen Sie BlackHole als Ausgabegerät
   - In Ihrer Kommunikationsanwendung: Normales Mikrofon als Eingabe wählen
5. Aufnahme starten und Gespräch beginnen

Das Tool zeichnet zwei getrennte Audiospuren auf:
- Ihre Stimme (Mikrofoneingang)
- Die Stimme Ihres Gesprächspartners (Systemton)

Beide Spuren können separat oder kombiniert transkribiert werden.

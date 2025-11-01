# Requirements Document

## IMPLEMENTIERUNGSRICHTLINIEN FÜR CLAUDE

**WICHTIG: Diese Spezifikation muss vollständig und production-ready implementiert werden.**

### Implementierungsregeln:
- **Keine Abkürzungen**: Alle Requirements müssen vollständig implementiert werden
- **Keine Mocks**: Verwende echte Implementierungen, keine Mock-Daten oder Dummy-Code
- **Keine Tests überspringen**: Alle Tests müssen implementiert und funktionsfähig sein
- **Production-Ready**: Code muss produktionstauglich sein, nicht nur "funktionierend"
- **Vollständige Fehlerbehandlung**: Alle Error-Cases müssen behandelt werden
- **Echte Integration**: Keine Stubs oder Placeholder - vollständige Integration erforderlich

### Qualitätsstandards:
- Vollständige Implementierung aller Acceptance Criteria
- Robuste Fehlerbehandlung für alle Szenarien
- Comprehensive Testing (Unit, Integration, Error Cases)
- Production-grade Logging und Monitoring
- Sichere und performante Implementierung

## Introduction

Diese Spezifikation beschreibt die Implementierung einer automatischen Text-Korrektur-Funktionalität (module5_text_correction) für das Whisper Transcription Tool. Nach der Whisper-Transkription wird optional eine lokale LLM-basierte Korrektur via llama-cpp-python mit dem LeoLM-13B-Modell angeboten, mit Fokus auf deutsche Texte. Die Funktionalität ist modular und deaktivierbar, speichert sowohl Original- als auch korrigierte Versionen.

## Glossar

- **text_correction**: Modulname und Konfigurationsbereich für die LLM-Textkorrektur
- **LeoLM-13B**: Deutsches Large Language Model von Hessian.AI für Textkorrektur
- **Chunking**: Aufteilung langer Texte in verarbeitbare Segmente basierend auf Kontextlänge
- **Resource Manager**: Zentrale Komponente für Modell-Laden/Entladen und Speicherverwaltung

## Requirements

### Requirement 1: LLM-Integration und Modellverwaltung

**User Story:** Als Benutzer möchte ich nach der Transkription eine automatische Textkorrektur durchführen lassen, damit meine Transkripte grammatikalisch und orthographisch korrekt sind.

#### Acceptance Criteria

1. WHEN die Textkorrektur aktiviert ist THEN das System SHALL das LeoLM-13B-Modell über llama-cpp-python laden
2. WHEN das LLM-Modell geladen wird THEN das System SHALL Whisper-Ressourcen freigeben um Speicher zu optimieren
3. WHEN die Korrektur abgeschlossen ist THEN das System SHALL das LLM-Modell entladen und optional Whisper reaktivieren
4. IF das LLM-Modell nicht verfügbar ist THEN das System SHALL die Korrektur überspringen und nur die Original-Transkription bereitstellen
5. WHEN Modelle gewechselt werden THEN das System SHALL thread-safe Ressourcenverwaltung gewährleisten

### Requirement 2: Konfigurierbare Korrekturstufen

**User Story:** Als Benutzer möchte ich verschiedene Korrekturstufen wählen können, damit ich die Balance zwischen Genauigkeit und Originalität der Transkription kontrollieren kann.

#### Acceptance Criteria

1. WHEN die Korrektur konfiguriert wird THEN das System SHALL drei Stufen anbieten: light, standard, strict
2. WHEN "light" gewählt wird THEN das System SHALL nur offensichtliche Rechtschreibfehler korrigieren
3. WHEN "standard" gewählt wird THEN das System SHALL Rechtschreibung, Grammatik und Interpunktion korrigieren
4. WHEN "strict" gewählt wird THEN das System SHALL zusätzlich Stil und Formulierungen optimieren
5. WHEN Dialektkorrektur aktiviert ist THEN das System SHALL regionale Ausdrücke in Hochdeutsch umwandeln

### Requirement 3: Batch-Verarbeitung und Chunking

**User Story:** Als Benutzer möchte ich auch lange Transkripte korrigieren lassen können, damit die Textkorrektur unabhängig von der Textlänge funktioniert.

#### Acceptance Criteria

1. WHEN ein Text die Kontextlänge überschreitet THEN das System SHALL den Text in sinnvolle Chunks aufteilen
2. WHEN Chunks erstellt werden THEN das System SHALL Satzgrenzen respektieren und Token-Limits beachten
3. WHEN Chunks verarbeitet werden THEN das System SHALL sie in der korrekten Reihenfolge zusammenfügen
4. WHEN Batch-Verarbeitung läuft THEN das System SHALL Fortschritt pro Chunk und Datei melden
5. WHEN ein Chunk fehlschlägt THEN das System SHALL mit den verbleibenden Chunks fortfahren
6. WHEN Chunking-Prozess fehlschlägt THEN das System SHALL detaillierte Fehlermeldung mit Chunk-Position und Ursache zurückgeben

### Requirement 4: Ressourcen-Management

**User Story:** Als Benutzer möchte ich dass die Anwendung effizient mit Systemressourcen umgeht, damit sie auch auf Systemen mit begrenztem RAM funktioniert.

#### Acceptance Criteria

1. WHEN Ressourcen-Management aktiviert wird THEN das System SHALL verfügbaren RAM vor Modell-Laden prüfen
2. WHEN unzureichender RAM erkannt wird THEN das System SHALL eine Warnung anzeigen und Korrektur überspringen
3. WHEN Modelle gewechselt werden THEN das System SHALL Garbage Collection durchführen und Speicher freigeben
4. WHEN mehrere Jobs parallel laufen THEN das System SHALL die Anzahl basierend auf verfügbaren Ressourcen begrenzen
5. WHEN Speicher-Monitoring aktiv ist THEN das System SHALL kontinuierlich RAM-Nutzung überwachen

### Requirement 5: Frontend-Integration

**User Story:** Als Benutzer möchte ich die Textkorrektur einfach über die Benutzeroberfläche aktivieren und konfigurieren können, damit ich die Funktionalität intuitiv nutzen kann.

#### Acceptance Criteria

1. WHEN die UI geladen wird THEN das System SHALL eine Checkbox für "Textkorrektur aktivieren" anzeigen
2. WHEN die Textkorrektur aktiviert wird THEN das System SHALL ein Dropdown für Korrekturstufen einblenden
3. WHEN das LLM-Modell nicht verfügbar ist THEN das System SHALL die Option deaktivieren und Tooltip mit Status anzeigen
4. WHEN die Korrektur läuft THEN das System SHALL einen zweiphasigen Fortschrittsbalken anzeigen ("Phase 1: Transkription", "Phase 2: Korrektur")
5. WHEN Phase 1 ohne Phase 2 endet THEN das System SHALL klaren Status anzeigen ("Korrektur übersprungen - siehe Logs")
6. WHEN die Korrektur abgeschlossen ist THEN das System SHALL Download-Links für beide Versionen bereitstellen

### Requirement 6: API-Erweiterungen

**User Story:** Als Entwickler möchte ich die Textkorrektur über API-Endpoints steuern können, damit die Funktionalität programmatisch nutzbar ist.

#### Acceptance Criteria

1. WHEN /api/transcribe aufgerufen wird THEN das System SHALL enable_correction und correction_level Parameter akzeptieren
2. WHEN /api/correction-status aufgerufen wird THEN das System SHALL Modellverfügbarkeit und RAM-Anforderungen zurückgeben
3. WHEN WebSocket-Events gesendet werden THEN das System SHALL correction_started, correction_progress und correction_completed Events unterstützen
4. WHEN Korrektur-Fehler auftreten THEN das System SHALL correction_error Events mit detaillierter Fehlermeldung senden
5. WHEN API-Validierung fehlschlägt THEN das System SHALL aussagekräftige HTTP-Fehlercodes und Meldungen zurückgeben
6. WHEN CLI-Interface verwendet wird THEN das System SHALL --enable-correction und --correction-level Flags parallel zu API-Parametern unterstützen

### Requirement 7: Konfigurationsverwaltung

**User Story:** Als Administrator möchte ich die Textkorrektur-Funktionalität über Konfigurationsdateien steuern können, damit ich sie systemweit anpassen kann.

#### Acceptance Criteria

1. WHEN die Konfiguration geladen wird THEN das System SHALL text_correction Sektion mit allen relevanten Parametern unterstützen
2. WHEN model_path konfiguriert wird THEN das System SHALL Pfadauflösung mit Tilde-Expansion unterstützen
3. WHEN Plattform-spezifische Einstellungen benötigt werden THEN das System SHALL Metal/GPU vs CPU Konfiguration ermöglichen
4. WHEN Konfiguration ungültig ist THEN das System SHALL auf sichere Standardwerte zurückfallen
5. WHEN README-Dokumentation erstellt wird THEN das System SHALL text_correction Konfigurationsabschnitt mit Beispielen bereitstellen

### Requirement 8: Datei-Output und Versionierung

**User Story:** Als Benutzer möchte ich sowohl die originale als auch die korrigierte Version meiner Transkripte erhalten, damit ich beide Versionen vergleichen und nutzen kann.

#### Acceptance Criteria

1. WHEN Korrektur abgeschlossen ist THEN das System SHALL sowohl *_original.txt als auch *_corrected.txt Dateien erstellen
2. WHEN mehrere Ausgabeformate gewählt wurden THEN das System SHALL korrigierte Versionen für TXT-Format bereitstellen
3. WHEN Dateinamen-Konflikte auftreten THEN das System SHALL Zeitstempel-Suffixe zur Eindeutigkeit hinzufügen
4. WHEN keep_original konfiguriert ist THEN das System SHALL beide Versionen entsprechend der Einstellung speichern
5. WHEN Batch-Verarbeitung läuft THEN das System SHALL konsistente Dateinamen-Konventionen für alle Dateien anwenden

### Requirement 9: Fehlerbehandlung und Monitoring

**User Story:** Als Benutzer möchte ich klare Fehlermeldungen und Diagnose-Informationen erhalten, damit ich Probleme mit der Textkorrektur verstehen und beheben kann.

#### Acceptance Criteria

1. WHEN das LLM-Modell nicht gefunden wird THEN das System SHALL eine spezifische Fehlermeldung mit Lösungsvorschlag anzeigen
2. WHEN RAM-Mangel erkannt wird THEN das System SHALL eine Warnung ausgeben und Korrektur überspringen
3. WHEN llama-cpp Exceptions auftreten THEN das System SHALL Fehler loggen und mit Original-Transkription fortfahren
4. WHEN Logging aktiviert ist THEN das System SHALL detaillierte Einträge in separater text_correction Kategorie erstellen
5. WHEN Monitoring aktiviert ist THEN das System SHALL optional Metriken wie correction_duration_seconds nur bei gesetztem monitoring_enabled Flag erfassen

### Requirement 10: Installation und Setup

**User Story:** Als Benutzer möchte ich die Textkorrektur-Funktionalität einfach installieren und konfigurieren können, damit ich sie ohne technische Hürden nutzen kann.

#### Acceptance Criteria

1. WHEN Dependencies installiert werden THEN das System SHALL llama-cpp-python mit plattformspezifischen Optimierungen unterstützen
2. WHEN das LeoLM-Modell benötigt wird THEN das System SHALL klare Download- und Setup-Anweisungen bereitstellen
3. WHEN Hardware-Anforderungen geprüft werden THEN das System SHALL mindestens 6GB RAM für LeoLM-13B empfehlen
4. WHEN Lizenz-Compliance erforderlich ist THEN das System SHALL LeoLM und Hessian.AI Lizenzhinweise anzeigen
5. WHEN Setup-Probleme auftreten THEN das System SHALL Troubleshooting-Guidance in der Dokumentation bereitstellen
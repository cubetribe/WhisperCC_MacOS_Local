# WhisperLocal macOS App - User Acceptance Testing Checklist

**Version:** 1.0.0  
**Date:** $(date '+%Y-%m-%d')  
**Tester:** _________________  
**macOS Version:** _________________  
**Hardware:** _________________  

## Pre-Test Setup

- [ ] **Fresh macOS Installation**: Test on clean macOS system (Monterey 12.0+, Ventura 13.0+, or Sonoma 14.0+)
- [ ] **Download WhisperLocal DMG**: Obtain latest release from GitHub releases
- [ ] **Test Files Ready**: Prepare sample audio/video files for testing:
  - [ ] Small audio file (< 5MB, < 5 minutes): `test_small.mp3`
  - [ ] Medium audio file (10-50MB, 10-30 minutes): `test_medium.wav`
  - [ ] Large audio file (> 100MB, > 60 minutes): `test_large.flac`
  - [ ] Video file with audio (MP4, MOV, or AVI): `test_video.mp4`
  - [ ] Unsupported file format for error testing: `test_invalid.txt`

---

## 1. Installation and First Launch

### 1.1 DMG Installation Process
- [ ] **Download DMG**: DMG downloads without corruption
- [ ] **Mount DMG**: DMG mounts successfully when double-clicked
- [ ] **DMG Contents**: DMG contains WhisperLocalMacOs.app and Applications shortcut
- [ ] **Drag to Applications**: App drags to Applications folder successfully
- [ ] **DMG Eject**: DMG unmounts cleanly after installation

**Notes:**
```
Installation time: _______ seconds
DMG size: _______ MB
Any issues: ________________________
```

### 1.2 First Application Launch
- [ ] **Gatekeeper Prompt**: macOS shows security dialog on first launch (expected)
- [ ] **Right-click Open**: App opens successfully when right-clicking and selecting "Open"
- [ ] **Launch Time**: App launches within 5 seconds of clicking
- [ ] **Main Window**: App displays main interface with sidebar navigation
- [ ] **No Crash**: App doesn't crash during first 30 seconds of operation

**Security Dialog Screenshots:**
- [ ] Gatekeeper security warning captured
- [ ] Right-click context menu captured
- [ ] Successful app launch captured

**Notes:**
```
Launch time: _______ seconds
Security prompts encountered: ________________________
```

### 1.3 First-Run Experience
- [ ] **Setup Wizard**: App shows helpful first-run guidance (if implemented)
- [ ] **Default Model**: App prompts or automatically downloads default model
- [ ] **Permissions**: App requests necessary permissions (microphone, file access) when needed
- [ ] **UI Responsiveness**: Interface responds immediately to clicks and navigation
- [ ] **Help Access**: Help menu and documentation are accessible

**Notes:**
```
First-time user experience rating (1-10): _______
Suggestions for improvement: ________________________
```

---

## 2. Core Functionality Testing

### 2.1 Single File Transcription
- [ ] **Audio File Selection**: File picker works with drag-and-drop and browse button
- [ ] **File Format Support**: Accepts MP3, WAV, FLAC, M4A files
- [ ] **File Info Display**: Shows selected file name, size, duration, format
- [ ] **Model Selection**: Model dropdown shows available models
- [ ] **Language Selection**: Language options include Auto, English, Spanish, French, etc.
- [ ] **Output Format Selection**: Can select TXT, SRT, VTT output formats
- [ ] **Output Directory**: Can select custom output directory

**Test Small Audio File (< 5 minutes):**
- [ ] **Start Transcription**: Transcription begins when Start button clicked
- [ ] **Progress Updates**: Progress bar updates during transcription
- [ ] **Time Estimation**: Shows estimated time remaining
- [ ] **Completion**: Transcription completes successfully
- [ ] **Output Files**: Generated files appear in specified location
- [ ] **File Content**: Transcription content is accurate and properly formatted
- [ ] **Reveal in Finder**: "Reveal in Finder" button opens file location

**Performance Metrics:**
```
File size: _______ MB
Duration: _______ minutes
Transcription time: _______ seconds
Speed ratio: _______ (duration/transcription_time)
Output quality (1-10): _______
```

### 2.2 Video File Processing
- [ ] **Video File Selection**: Accepts MP4, MOV, AVI files
- [ ] **Audio Extraction**: Automatically extracts audio from video
- [ ] **Two-Phase Progress**: Shows progress for both extraction and transcription
- [ ] **Extracted Audio Info**: Displays information about extracted audio file
- [ ] **Final Transcription**: Produces accurate transcription from video audio

**Notes:**
```
Video format tested: _________________
Extraction time: _______ seconds
Total processing time: _______ seconds
```

### 2.3 Batch Processing
- [ ] **Multiple File Selection**: Can select multiple files at once
- [ ] **Queue Management**: Files appear in processing queue
- [ ] **Queue Controls**: Can add, remove, reorder files in queue
- [ ] **Batch Start**: Can start processing entire batch
- [ ] **Individual Progress**: Shows progress for each file individually
- [ ] **Error Isolation**: If one file fails, others continue processing
- [ ] **Batch Summary**: Shows completion statistics and summary

**Test Batch (3-5 files):**
- [ ] **Mixed Formats**: Include different audio/video formats in batch
- [ ] **Processing Order**: Files process in expected order
- [ ] **Pause/Resume**: Can pause and resume batch processing
- [ ] **Cancel**: Can cancel batch processing
- [ ] **Results Export**: Can export batch results to CSV/JSON

**Performance Metrics:**
```
Batch size: _______ files
Total processing time: _______ minutes
Average speed: _______ ratio
Success rate: _______% 
```

---

## 3. Model Management

### 3.1 Model Manager Interface
- [ ] **Model Manager Access**: Can open Model Manager from toolbar
- [ ] **Model List**: Shows available Whisper models with details
- [ ] **Model Information**: Displays size, accuracy, speed for each model
- [ ] **System Recommendations**: Shows recommended models for current hardware
- [ ] **Download Status**: Clearly indicates which models are downloaded

### 3.2 Model Download
- [ ] **Download Initiation**: Can start model download with one click
- [ ] **Download Progress**: Shows download progress with speed and ETA
- [ ] **Multiple Downloads**: Supports downloading multiple models concurrently
- [ ] **Download Verification**: Verifies model integrity after download
- [ ] **Download Cancel**: Can cancel ongoing downloads

**Test Model Downloads:**
- [ ] **Small Model**: Download tiny.en model (< 100MB)
- [ ] **Large Model**: Download large-v3-turbo model (> 1GB)

**Performance Metrics:**
```
Small model download time: _______ seconds
Large model download time: _______ minutes
Download speed: _______ MB/s
Verification successful: _______
```

### 3.3 Model Usage
- [ ] **Model Switching**: Can switch between downloaded models
- [ ] **Performance Difference**: Different models show expected performance characteristics
- [ ] **Quality Comparison**: Larger models provide better transcription quality
- [ ] **Memory Usage**: Model selection affects app memory usage appropriately

---

## 4. Advanced Features

### 4.1 Chatbot Integration (if available)
- [ ] **Chatbot Access**: Can access chatbot from sidebar
- [ ] **Transcript Search**: Can search through previous transcriptions
- [ ] **Natural Language**: Responds to natural language queries
- [ ] **Result Relevance**: Search results are relevant and useful
- [ ] **Chat History**: Maintains conversation history across sessions

### 4.2 Error Handling
- [ ] **Invalid Files**: Gracefully handles unsupported file formats
- [ ] **Corrupted Files**: Provides helpful error messages for corrupted files
- [ ] **Network Issues**: Handles network connectivity problems during model downloads
- [ ] **Insufficient Space**: Warns about insufficient disk space
- [ ] **Recovery Options**: Provides actionable recovery suggestions

**Test Error Scenarios:**
- [ ] **Unsupported Format**: Try to transcribe .txt file
- [ ] **Corrupted File**: Use intentionally corrupted audio file
- [ ] **No Internet**: Attempt model download without internet connection
- [ ] **Full Disk**: Test behavior when disk space is very low

---

## 5. Performance and Reliability

### 5.1 Performance Requirements
- [ ] **Startup Time**: App launches within 5 seconds (cold start)
- [ ] **UI Responsiveness**: No UI freezing during operations
- [ ] **Memory Usage**: Reasonable memory consumption (< 1GB for typical use)
- [ ] **CPU Usage**: Efficient CPU usage during transcription
- [ ] **Thermal Management**: No excessive heat generation during batch processing

**Performance Monitoring:**
```
Startup time: _______ seconds
Memory usage (idle): _______ MB
Memory usage (transcribing): _______ MB
CPU usage during transcription: _______%
```

### 5.2 Stress Testing
- [ ] **Large File**: Successfully processes file > 100MB, > 60 minutes
- [ ] **Multiple Instances**: Can run multiple transcriptions simultaneously
- [ ] **Extended Usage**: Runs for 2+ hours without issues
- [ ] **Window Resize**: Handles window resizing and full-screen mode
- [ ] **System Sleep**: Recovers properly after system sleep/wake

### 5.3 Reliability
- [ ] **No Crashes**: No unexpected app terminations during testing
- [ ] **Data Integrity**: All output files are complete and uncorrupted
- [ ] **State Persistence**: Remembers settings and preferences between sessions
- [ ] **Graceful Shutdown**: App quits cleanly when requested
- [ ] **Error Recovery**: Recovers gracefully from temporary errors

---

## 6. Native macOS Integration

### 6.1 System Integration
- [ ] **File Associations**: Audio/video files can be opened with WhisperLocal
- [ ] **Spotlight**: App appears in Spotlight search
- [ ] **Dock Integration**: Shows progress indicator in Dock during processing
- [ ] **Notifications**: Sends completion notifications (if enabled)
- [ ] **Dark/Light Mode**: Respects system appearance settings

### 6.2 Accessibility
- [ ] **VoiceOver**: Basic VoiceOver support for main UI elements
- [ ] **Keyboard Navigation**: Can navigate interface with keyboard
- [ ] **High Contrast**: Works with high contrast display settings
- [ ] **Text Size**: Respects system text size preferences

### 6.3 System Compatibility
- [ ] **Apple Silicon**: Runs natively on Apple Silicon Macs
- [ ] **Intel Macs**: Runs properly on Intel Macs (if supported)
- [ ] **Multiple macOS Versions**: Works on Monterey, Ventura, Sonoma
- [ ] **System Updates**: Continues working after macOS updates

---

## 7. User Experience Evaluation

### 7.1 Interface Design
- [ ] **Intuitive Navigation**: Interface is easy to understand and navigate
- [ ] **Clear Labels**: All buttons and controls are clearly labeled
- [ ] **Consistent Design**: Design follows macOS Human Interface Guidelines
- [ ] **Appropriate Icons**: Icons are meaningful and consistent
- [ ] **Color Usage**: Color coding is helpful and accessible

**UI Rating (1-10):** _______

### 7.2 Workflow Efficiency
- [ ] **Quick Start**: New users can start transcribing within 2 minutes
- [ ] **Common Tasks**: Frequent tasks can be completed quickly
- [ ] **Keyboard Shortcuts**: Important actions have keyboard shortcuts
- [ ] **Drag-and-Drop**: Drag-and-drop works throughout the interface
- [ ] **Context Menus**: Right-click provides relevant options

**Workflow Rating (1-10):** _______

### 7.3 Documentation and Help
- [ ] **Built-in Help**: Help menu provides useful information
- [ ] **Tooltips**: Important controls have helpful tooltips
- [ ] **Error Messages**: Error messages are clear and actionable
- [ ] **Status Information**: User always knows what the app is doing

---

## 8. Final Assessment

### 8.1 Overall Quality
- [ ] **Feature Completeness**: All advertised features work as expected
- [ ] **Stability**: App is stable and reliable for daily use
- [ ] **Performance**: Performance meets or exceeds expectations
- [ ] **User Experience**: App provides excellent user experience
- [ ] **Native Feel**: Feels like a native macOS application

### 8.2 Release Readiness
- [ ] **Ready for Public**: App is ready for general public use
- [ ] **Documentation Complete**: User documentation is adequate
- [ ] **Known Issues**: All known issues are documented and acceptable
- [ ] **Support Ready**: Support processes are in place for user issues

**Overall Rating (1-10):** _______

**Release Recommendation:**
- [ ] ✅ **APPROVE FOR RELEASE** - Ready for public distribution
- [ ] ⚠️ **CONDITIONAL APPROVAL** - Minor fixes needed (list below)
- [ ] ❌ **REJECT** - Major issues must be resolved (list below)

### 8.3 Issues Found
**Critical Issues (must fix before release):**
```
1. ________________________________
2. ________________________________
3. ________________________________
```

**Minor Issues (can be fixed in future update):**
```
1. ________________________________
2. ________________________________
3. ________________________________
```

### 8.4 Recommendations
**Short-term improvements:**
```
1. ________________________________
2. ________________________________
3. ________________________________
```

**Long-term enhancements:**
```
1. ________________________________
2. ________________________________
3. ________________________________
```

---

## Testing Summary

**Tester Information:**
- **Name:** _________________
- **Date:** _________________
- **Duration:** _______ hours
- **System:** _________________

**Test Environment:**
- **macOS Version:** _________________
- **Hardware:** _________________
- **Available Memory:** _______ GB
- **Available Storage:** _______ GB

**Final Signature:** _________________

---

**Testing Complete - Thank you for your thorough evaluation!**

*This checklist ensures comprehensive validation of WhisperLocal before public release. Please complete all sections and provide detailed feedback for any issues encountered.*
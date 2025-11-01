import XCTest
@testable import WhisperLocalMacOs

final class ModelTests: XCTestCase {
    
    // MARK: - OutputFormat Tests
    
    func testOutputFormatProperties() {
        // Test TXT format
        let txt = OutputFormat.txt
        XCTAssertEqual(txt.displayName, "Plain Text")
        XCTAssertEqual(txt.fileExtension, "txt")
        XCTAssertEqual(txt.mimeType, "text/plain")
        XCTAssertFalse(txt.supportsTimestamps)
        
        // Test SRT format
        let srt = OutputFormat.srt
        XCTAssertEqual(srt.displayName, "SubRip Subtitle")
        XCTAssertEqual(srt.fileExtension, "srt")
        XCTAssertEqual(srt.mimeType, "application/x-subrip")
        XCTAssertTrue(srt.supportsTimestamps)
        
        // Test VTT format
        let vtt = OutputFormat.vtt
        XCTAssertEqual(vtt.displayName, "WebVTT Subtitle")
        XCTAssertEqual(vtt.fileExtension, "vtt")
        XCTAssertEqual(vtt.mimeType, "text/vtt")
        XCTAssertTrue(vtt.supportsTimestamps)
    }
    
    func testOutputFormatCodable() throws {
        let formats: [OutputFormat] = [.txt, .srt, .vtt]
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(formats)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedFormats = try decoder.decode([OutputFormat].self, from: data)
        
        XCTAssertEqual(formats, decodedFormats)
    }
    
    // MARK: - TaskStatus Tests
    
    func testTaskStatusProperties() {
        // Test all status types
        XCTAssertEqual(TaskStatus.pending.displayName, "Pending")
        XCTAssertEqual(TaskStatus.processing.displayName, "Processing")
        XCTAssertEqual(TaskStatus.completed.displayName, "Completed")
        XCTAssertEqual(TaskStatus.failed.displayName, "Failed")
        XCTAssertEqual(TaskStatus.cancelled.displayName, "Cancelled")
        
        // Test terminal states
        XCTAssertFalse(TaskStatus.pending.isTerminal)
        XCTAssertFalse(TaskStatus.processing.isTerminal)
        XCTAssertTrue(TaskStatus.completed.isTerminal)
        XCTAssertTrue(TaskStatus.failed.isTerminal)
        XCTAssertTrue(TaskStatus.cancelled.isTerminal)
        
        // Test success states
        XCTAssertFalse(TaskStatus.pending.isSuccess)
        XCTAssertFalse(TaskStatus.processing.isSuccess)
        XCTAssertTrue(TaskStatus.completed.isSuccess)
        XCTAssertFalse(TaskStatus.failed.isSuccess)
        XCTAssertFalse(TaskStatus.cancelled.isSuccess)
    }
    
    // MARK: - TranscriptionTask Tests
    
    func testTranscriptionTaskCreation() {
        let inputURL = URL(fileURLWithPath: "/test/audio.mp3")
        let outputDirectory = URL(fileURLWithPath: "/test/output")
        
        let task = TranscriptionTask(
            inputURL: inputURL,
            outputDirectory: outputDirectory,
            model: "tiny",
            formats: [.txt, .srt],
            language: "en"
        )
        
        XCTAssertEqual(task.inputURL, inputURL)
        XCTAssertEqual(task.outputDirectory, outputDirectory)
        XCTAssertEqual(task.model, "tiny")
        XCTAssertEqual(task.formats, [.txt, .srt])
        XCTAssertEqual(task.language, "en")
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(task.progress, 0.0)
        XCTAssertNil(task.error)
        XCTAssertNil(task.startTime)
        XCTAssertNil(task.completionTime)
        XCTAssertTrue(task.outputFiles.isEmpty)
    }
    
    func testTranscriptionTaskFileProperties() {
        let task = TranscriptionTask(
            inputURL: URL(fileURLWithPath: "/test/my-audio.mp3")
        )
        
        XCTAssertEqual(task.inputFileName, "my-audio")
        XCTAssertEqual(task.inputFileExtension, "mp3")
        XCTAssertFalse(task.requiresAudioExtraction)
        
        let videoTask = TranscriptionTask(
            inputURL: URL(fileURLWithPath: "/test/video.mp4")
        )
        
        XCTAssertEqual(videoTask.inputFileExtension, "mp4")
        XCTAssertTrue(videoTask.requiresAudioExtraction)
    }
    
    func testTranscriptionTaskStateTransitions() {
        var task = TranscriptionTask(
            inputURL: URL(fileURLWithPath: "/test/audio.mp3")
        )
        
        // Test starting
        task.markStarted()
        XCTAssertEqual(task.status, .processing)
        XCTAssertNotNil(task.startTime)
        XCTAssertEqual(task.progress, 0.0)
        
        // Test progress update
        task.updateProgress(0.5)
        XCTAssertEqual(task.progress, 0.5)
        
        // Test completion
        let outputFiles = [URL(fileURLWithPath: "/test/output.txt")]
        task.markCompleted(outputFiles: outputFiles)
        XCTAssertEqual(task.status, .completed)
        XCTAssertNotNil(task.completionTime)
        XCTAssertEqual(task.progress, 1.0)
        XCTAssertEqual(task.outputFiles, outputFiles)
        XCTAssertNil(task.error)
        
        // Test reset
        task.reset()
        XCTAssertEqual(task.status, .pending)
        XCTAssertEqual(task.progress, 0.0)
        XCTAssertNil(task.error)
        XCTAssertNil(task.startTime)
        XCTAssertNil(task.completionTime)
        XCTAssertTrue(task.outputFiles.isEmpty)
    }
    
    func testTranscriptionTaskFailure() {
        var task = TranscriptionTask(
            inputURL: URL(fileURLWithPath: "/test/audio.mp3")
        )
        
        task.markStarted()
        task.markFailed(error: "Test error")
        
        XCTAssertEqual(task.status, .failed)
        XCTAssertNotNil(task.completionTime)
        XCTAssertEqual(task.error, "Test error")
    }
    
    func testTranscriptionTaskCodable() throws {
        let task = TranscriptionTask(
            inputURL: URL(fileURLWithPath: "/test/audio.mp3"),
            outputDirectory: URL(fileURLWithPath: "/test/output"),
            model: "tiny",
            formats: [.txt, .srt],
            language: "en"
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        let data = try encoder.encode(task)
        
        // Test decoding
        let decoder = JSONDecoder()
        let decodedTask = try decoder.decode(TranscriptionTask.self, from: data)
        
        XCTAssertEqual(task.inputURL, decodedTask.inputURL)
        XCTAssertEqual(task.outputDirectory, decodedTask.outputDirectory)
        XCTAssertEqual(task.model, decodedTask.model)
        XCTAssertEqual(task.formats, decodedTask.formats)
        XCTAssertEqual(task.language, decodedTask.language)
        XCTAssertEqual(task.status, decodedTask.status)
        XCTAssertEqual(task.progress, decodedTask.progress)
    }
    
    // MARK: - WhisperModel Tests
    
    func testWhisperModelProperties() {
        let performance = ModelPerformance(
            speedMultiplier: 32,
            accuracy: "Fair",
            memoryUsage: "Very Low",
            languages: 99
        )
        
        let model = WhisperModel(
            name: "tiny",
            sizeMB: 39,
            description: "Fastest model",
            performance: performance,
            downloadURL: "https://example.com/tiny.bin",
            sha256: "abc123"
        )
        
        XCTAssertEqual(model.name, "tiny")
        XCTAssertEqual(model.sizeMB, 39)
        XCTAssertEqual(model.sizeBytes, 39 * 1024 * 1024)
        XCTAssertEqual(model.description, "Fastest model")
        XCTAssertEqual(model.downloadURL, "https://example.com/tiny.bin")
        XCTAssertEqual(model.sha256, "abc123")
        XCTAssertFalse(model.isDownloaded)
        XCTAssertFalse(model.isEnglishOnly)
        XCTAssertEqual(model.baseName, "tiny")
        XCTAssertEqual(model.sizeCategory, .tiny)
    }
    
    func testWhisperModelEnglishOnly() {
        let model = WhisperModel(
            name: "tiny.en",
            sizeMB: 39,
            description: "English only",
            performance: ModelPerformance(speedMultiplier: 32, accuracy: "Fair", memoryUsage: "Low", languages: 1),
            downloadURL: "https://example.com/tiny.en.bin"
        )
        
        XCTAssertTrue(model.isEnglishOnly)
        XCTAssertEqual(model.baseName, "tiny")
    }
    
    func testWhisperModelDownloadState() {
        var model = WhisperModel(
            name: "tiny",
            sizeMB: 39,
            description: "Test model",
            performance: ModelPerformance(speedMultiplier: 32, accuracy: "Fair", memoryUsage: "Low", languages: 99),
            downloadURL: "https://example.com/tiny.bin"
        )
        
        // Test initial state
        XCTAssertFalse(model.isDownloaded)
        XCTAssertFalse(model.isDownloading)
        XCTAssertEqual(model.downloadProgress, 0.0)
        
        // Test download progress
        model.updateDownloadProgress(0.5)
        XCTAssertTrue(model.isDownloading)
        XCTAssertEqual(model.downloadProgress, 0.5)
        
        // Test download completion
        let filePath = URL(fileURLWithPath: "/models/tiny.bin")
        model.markDownloaded(at: filePath)
        XCTAssertTrue(model.isDownloaded)
        XCTAssertFalse(model.isDownloading)
        XCTAssertEqual(model.downloadProgress, 1.0)
        XCTAssertEqual(model.localFilePath, filePath)
        
        // Test reset
        model.resetDownloadState()
        XCTAssertFalse(model.isDownloaded)
        XCTAssertFalse(model.isDownloading)
        XCTAssertEqual(model.downloadProgress, 0.0)
        XCTAssertNil(model.localFilePath)
    }
    
    func testModelPerformance() {
        let performance = ModelPerformance(
            speedMultiplier: 16,
            accuracy: "Good",
            memoryUsage: "Medium",
            languages: 99
        )
        
        XCTAssertEqual(performance.accuracyPercentage, 80)
        XCTAssertEqual(performance.memoryCategory, .medium)
        XCTAssertEqual(performance.memoryCategory.estimatedRAMUsage, 2.0)
    }
    
    func testWhisperModelComparable() {
        let smallModel = WhisperModel(
            name: "tiny",
            sizeMB: 39,
            description: "Small",
            performance: ModelPerformance(speedMultiplier: 32, accuracy: "Fair", memoryUsage: "Low", languages: 99),
            downloadURL: "https://example.com/tiny.bin"
        )
        
        let largeModel = WhisperModel(
            name: "large",
            sizeMB: 1550,
            description: "Large",
            performance: ModelPerformance(speedMultiplier: 1, accuracy: "Excellent", memoryUsage: "High", languages: 99),
            downloadURL: "https://example.com/large.bin"
        )
        
        XCTAssertTrue(smallModel < largeModel)
        XCTAssertFalse(largeModel < smallModel)
    }
    
    func testAvailableModels() {
        let models = WhisperModel.availableModels
        
        XCTAssertFalse(models.isEmpty)
        XCTAssertTrue(models.contains { $0.name == "tiny" })
        XCTAssertTrue(models.contains { $0.name == "large-v3-turbo" })
        
        let defaultModel = WhisperModel.defaultModel
        XCTAssertEqual(defaultModel.name, "large-v3-turbo")
        
        let fastestModel = WhisperModel.fastestModel
        XCTAssertEqual(fastestModel.name, "tiny")
    }
    
    // MARK: - TranscriptionResult Tests
    
    func testTranscriptionResultSuccess() {
        let result = TranscriptionResult(
            inputFile: "/test/audio.mp3",
            outputFiles: ["/test/audio.txt", "/test/audio.srt"],
            processingTime: 10.5,
            modelUsed: "tiny",
            language: "en"
        )
        
        XCTAssertTrue(result.success)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.inputFile, "/test/audio.mp3")
        XCTAssertEqual(result.outputFiles.count, 2)
        XCTAssertEqual(result.processingTime, 10.5)
        XCTAssertEqual(result.modelUsed, "tiny")
        XCTAssertEqual(result.language, "en")
    }
    
    func testTranscriptionResultFailure() {
        let result = TranscriptionResult(
            inputFile: "/test/audio.mp3",
            error: "File not found",
            processingTime: 0,
            modelUsed: "tiny"
        )
        
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.error, "File not found")
        XCTAssertTrue(result.outputFiles.isEmpty)
        XCTAssertEqual(result.processingTime, 0)
        XCTAssertNil(result.language)
    }
    
    func testTranscriptionMetadata() {
        let metadata = TranscriptionMetadata(
            confidence: 0.85,
            segmentCount: 10,
            averageSegmentDuration: 5.0,
            audioDuration: 50.0,
            languageConfidence: 0.9,
            detectedLanguage: "en",
            vadUsed: true,
            peakMemoryUsage: 1024000,
            customProperties: ["key": "value"]
        )
        
        XCTAssertEqual(metadata.qualityAssessment, .good)
        XCTAssertEqual(metadata.confidence, 0.85)
        XCTAssertEqual(metadata.segmentCount, 10)
        XCTAssertEqual(metadata.customProperties?["key"], "value")
    }
    
    func testTranscriptionResultArrayExtensions() {
        let results: [TranscriptionResult] = [
            TranscriptionResult(inputFile: "1.mp3", outputFiles: ["1.txt"], processingTime: 5, modelUsed: "tiny"),
            TranscriptionResult(inputFile: "2.mp3", error: "Failed", processingTime: 0, modelUsed: "tiny"),
            TranscriptionResult(inputFile: "3.mp3", outputFiles: ["3.txt"], processingTime: 10, modelUsed: "small")
        ]
        
        XCTAssertEqual(results.successful.count, 2)
        XCTAssertEqual(results.failed.count, 1)
        XCTAssertEqual(results.successRate, 2.0/3.0, accuracy: 0.01)
        XCTAssertEqual(results.totalProcessingTime, 15)
        XCTAssertEqual(results.averageProcessingTime, 5, accuracy: 0.01)
        XCTAssertEqual(results.mostUsedModel, "tiny")
    }
    
    func testTranscriptionResultCodable() throws {
        let result = TranscriptionResult(
            inputFile: "/test/audio.mp3",
            outputFiles: ["/test/audio.txt"],
            processingTime: 10.0,
            modelUsed: "tiny",
            language: "en"
        )
        
        // Test encoding
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(result)
        
        // Test decoding
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decodedResult = try decoder.decode(TranscriptionResult.self, from: data)
        
        XCTAssertEqual(result.inputFile, decodedResult.inputFile)
        XCTAssertEqual(result.outputFiles, decodedResult.outputFiles)
        XCTAssertEqual(result.processingTime, decodedResult.processingTime)
        XCTAssertEqual(result.modelUsed, decodedResult.modelUsed)
        XCTAssertEqual(result.language, decodedResult.language)
        XCTAssertEqual(result.success, decodedResult.success)
    }
}
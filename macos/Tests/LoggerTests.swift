import XCTest
@testable import WhisperLocalMacOs

final class LoggerTests: XCTestCase {
    
    var logger: Logger!
    var tempDirectory: URL!
    
    override func setUpWithError() throws {
        // Create temporary directory for test logs
        tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        
        // Use shared logger instance (since it's a singleton)
        logger = Logger.shared
    }
    
    override func tearDownWithError() throws {
        // Clean up temporary directory
        if let tempDirectory = tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
    }
    
    // MARK: - Basic Logging Tests
    
    func testBasicLogging() {
        let testMessage = "Test log message"
        logger.info(testMessage, category: .general)
        
        // Give some time for async processing
        let expectation = XCTestExpectation(description: "Log processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Check that the message appears in recent logs
        let recentLogs = logger.recentLogs
        XCTAssertTrue(recentLogs.contains { $0.message == testMessage })
    }
    
    func testLogLevels() {
        let testMessages = [
            ("Debug message", LogLevel.debug),
            ("Info message", LogLevel.info),
            ("Warning message", LogLevel.warning),
            ("Error message", LogLevel.error),
            ("Critical message", LogLevel.critical)
        ]
        
        for (message, level) in testMessages {
            logger.log(level, message, category: .general)
        }
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "All logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify all levels were logged
        let recentLogs = logger.recentLogs
        for (message, level) in testMessages {
            XCTAssertTrue(recentLogs.contains { $0.message == message && $0.level == level })
        }
    }
    
    func testLogCategories() {
        let testCategories = LogCategory.allCases
        
        for category in testCategories {
            logger.info("Test message for \(category.rawValue)", category: category)
        }
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Category logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Verify all categories were logged
        let recentLogs = logger.recentLogs
        for category in testCategories {
            XCTAssertTrue(recentLogs.contains { $0.category == category })
        }
    }
    
    // MARK: - Convenience Method Tests
    
    func testConvenienceMethods() {
        let testMessage = "Convenience test"
        
        logger.debug(testMessage)
        logger.info(testMessage)
        logger.warning(testMessage)
        logger.error(testMessage)
        logger.critical(testMessage)
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Convenience logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let recentLogs = logger.recentLogs
        let testLogs = recentLogs.filter { $0.message == testMessage }
        
        XCTAssertEqual(testLogs.count, 5)
        XCTAssertTrue(testLogs.contains { $0.level == .debug })
        XCTAssertTrue(testLogs.contains { $0.level == .info })
        XCTAssertTrue(testLogs.contains { $0.level == .warning })
        XCTAssertTrue(testLogs.contains { $0.level == .error })
        XCTAssertTrue(testLogs.contains { $0.level == .critical })
    }
    
    // MARK: - Structured Logging Tests
    
    func testTranscriptionLogging() {
        let task = TranscriptionTask(
            inputURL: URL(fileURLWithPath: "/test/audio.mp3"),
            model: "tiny",
            formats: [.txt]
        )
        
        logger.logTranscriptionStart(task)
        logger.logTranscriptionComplete(task, processingTime: 10.5)
        logger.logTranscriptionError(task, error: AppError.fileProcessing(.fileNotFound("/test/audio.mp3")))
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Transcription logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let transcriptionLogs = logger.getLogs(category: .transcription)
        XCTAssertGreaterThanOrEqual(transcriptionLogs.count, 3)
        
        // Check that logs contain relevant information
        XCTAssertTrue(transcriptionLogs.contains { $0.message.contains("audio.mp3") })
        XCTAssertTrue(transcriptionLogs.contains { $0.message.contains("10.5") })
    }
    
    func testModelManagementLogging() {
        let model = WhisperModel(
            name: "tiny",
            sizeMB: 39,
            description: "Test model",
            performance: ModelPerformance(speedMultiplier: 32, accuracy: "Fair", memoryUsage: "Low", languages: 99),
            downloadURL: "https://example.com/tiny.bin"
        )
        
        logger.logModelDownloadStart(model)
        logger.logModelDownloadComplete(model)
        logger.logModelDownloadError(model, error: AppError.modelManagement(.downloadFailed("tiny", reason: "Network error")))
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Model logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let modelLogs = logger.getLogs(category: .modelManagement)
        XCTAssertGreaterThanOrEqual(modelLogs.count, 3)
        
        // Check that logs contain model information
        XCTAssertTrue(modelLogs.contains { $0.message.contains("tiny") })
    }
    
    func testBatchProcessingLogging() {
        let results = [
            TranscriptionResult(
                inputFile: "/test/file1.mp3",
                outputFiles: ["/test/file1.txt"],
                processingTime: 5.0,
                modelUsed: "tiny"
            ),
            TranscriptionResult(
                inputFile: "/test/file2.mp3",
                error: "Test error",
                modelUsed: "tiny"
            )
        ]
        
        logger.logBatchProcessingStart(2)
        logger.logBatchProcessingComplete(results)
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Batch logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let batchLogs = logger.getLogs(category: .batchProcessing)
        XCTAssertGreaterThanOrEqual(batchLogs.count, 2)
        
        // Check that logs contain batch information
        XCTAssertTrue(batchLogs.contains { $0.message.contains("2 files") })
        XCTAssertTrue(batchLogs.contains { $0.message.contains("1/2 successful") })
    }
    
    func testSystemResourceLogging() {
        logger.logSystemResource("CPU", value: 0.75)
        logger.logSystemResource("Memory", value: 0.6)
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "System logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let systemLogs = logger.getLogs(category: .system)
        XCTAssertTrue(systemLogs.contains { $0.message.contains("CPU") && $0.message.contains("75") })
        XCTAssertTrue(systemLogs.contains { $0.message.contains("Memory") && $0.message.contains("60") })
    }
    
    func testPythonBridgeLogging() {
        logger.logPythonBridgeCommand("list_models")
        logger.logPythonBridgeResponse(true, duration: 0.5)
        logger.logPythonBridgeResponse(false, duration: 2.0)
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Bridge logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let bridgeLogs = logger.getLogs(category: .pythonBridge)
        XCTAssertTrue(bridgeLogs.contains { $0.message.contains("list_models") })
        XCTAssertTrue(bridgeLogs.contains { $0.message.contains("success=true") })
        XCTAssertTrue(bridgeLogs.contains { $0.message.contains("success=false") })
    }
    
    // MARK: - Log Filtering Tests
    
    func testLogFiltering() {
        // Add logs with different levels and categories
        logger.debug("Debug message", category: .general)
        logger.info("Info message", category: .transcription)
        logger.warning("Warning message", category: .modelManagement)
        logger.error("Error message", category: .system)
        logger.critical("Critical message", category: .pythonBridge)
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Filter logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Test level filtering
        let errorAndAbove = logger.getLogs(level: .error)
        XCTAssertEqual(errorAndAbove.filter { $0.message.contains("Error message") || $0.message.contains("Critical message") }.count, 2)
        
        // Test category filtering
        let transcriptionLogs = logger.getLogs(category: .transcription)
        XCTAssertTrue(transcriptionLogs.contains { $0.message.contains("Info message") })
        
        // Test date filtering
        let now = Date()
        let recent = logger.getLogs(since: now.addingTimeInterval(-1))
        XCTAssertGreaterThanOrEqual(recent.count, 5)
        
        // Test limit
        let limited = logger.getLogs(limit: 3)
        XCTAssertLessThanOrEqual(limited.count, 3)
    }
    
    // MARK: - Log Export Tests
    
    func testLogExport() {
        // Add some test logs
        logger.info("Export test message 1")
        logger.error("Export test message 2")
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Export logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        // Export logs
        guard let exportURL = logger.exportLogs() else {
            XCTFail("Log export should succeed")
            return
        }
        
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
        
        // Verify export content
        if let exportContent = try? String(contentsOf: exportURL) {
            XCTAssertTrue(exportContent.contains("WhisperLocalMacOs Log Export"))
            XCTAssertTrue(exportContent.contains("Export test message 1"))
            XCTAssertTrue(exportContent.contains("Export test message 2"))
        } else {
            XCTFail("Should be able to read export file")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: exportURL)
    }
    
    // MARK: - Crash Report Tests
    
    func testCrashReport() {
        // Add some critical and error logs
        logger.critical("Critical error 1")
        logger.error("Regular error 1")
        logger.critical("Critical error 2")
        logger.info("Info message") // Should not appear in crash report
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Crash report logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let crashReport = logger.getCrashReport()
        
        XCTAssertTrue(crashReport.contains("WhisperLocalMacOs Crash Report"))
        XCTAssertTrue(crashReport.contains("Critical error 1"))
        XCTAssertTrue(crashReport.contains("Critical error 2"))
        XCTAssertTrue(crashReport.contains("Regular error 1"))
        XCTAssertFalse(crashReport.contains("Info message"))
    }
    
    // MARK: - Log Entry Tests
    
    func testLogEntry() {
        let testError = NSError(domain: "test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Test error"])
        let entry = LogEntry(
            level: .error,
            message: "Test message",
            category: .general,
            timestamp: Date(),
            file: "TestFile.swift",
            function: "testFunction",
            line: 123,
            error: testError
        )
        
        // Test formatted output
        let formatted = entry.formatted
        XCTAssertTrue(formatted.contains("ERROR"))
        XCTAssertTrue(formatted.contains("Test message"))
        XCTAssertTrue(formatted.contains("general"))
        
        // Test file formatted output
        let fileFormatted = entry.formattedForFile
        XCTAssertTrue(fileFormatted.contains("TestFile.swift:123"))
        XCTAssertTrue(fileFormatted.contains("testFunction"))
        XCTAssertTrue(fileFormatted.contains("Test error"))
        
        // Test export formatted output
        let exportFormatted = entry.formattedForExport
        XCTAssertTrue(exportFormatted.contains("Error Details: Test error"))
        XCTAssertTrue(exportFormatted.contains("Location: TestFile.swift:123"))
    }
    
    // MARK: - Log Level Tests
    
    func testLogLevelSeverity() {
        XCTAssertEqual(LogLevel.debug.severity, 0)
        XCTAssertEqual(LogLevel.info.severity, 1)
        XCTAssertEqual(LogLevel.warning.severity, 2)
        XCTAssertEqual(LogLevel.error.severity, 3)
        XCTAssertEqual(LogLevel.critical.severity, 4)
    }
    
    func testLogLevelProperties() {
        let levels = LogLevel.allCases
        
        for level in levels {
            XCTAssertFalse(level.icon.isEmpty)
            XCTAssertFalse(level.color.isEmpty)
        }
    }
    
    // MARK: - Log Category Tests
    
    func testLogCategoryProperties() {
        let categories = LogCategory.allCases
        
        for category in categories {
            XCTAssertFalse(category.displayName.isEmpty)
            XCTAssertFalse(category.icon.isEmpty)
        }
    }
    
    // MARK: - Global Function Tests
    
    func testGlobalLoggingFunctions() {
        let testMessage = "Global function test"
        
        logDebug(testMessage)
        logInfo(testMessage)
        logWarning(testMessage)
        logError(testMessage)
        logCritical(testMessage)
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Global logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        let recentLogs = logger.recentLogs
        let testLogs = recentLogs.filter { $0.message == testMessage }
        
        XCTAssertEqual(testLogs.count, 5)
    }
    
    // MARK: - Memory Management Tests
    
    func testMaxLogLimit() {
        let initialCount = logger.recentLogs.count
        
        // Add more logs than the max limit (assuming it's 1000)
        for i in 0..<1200 {
            logger.info("Test log \(i)")
        }
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Bulk logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)
        
        let finalCount = logger.recentLogs.count
        
        // Should not exceed max limit significantly
        XCTAssertLessThanOrEqual(finalCount, 1000 + 100) // Some buffer for race conditions
    }
    
    // MARK: - Threading Tests
    
    func testConcurrentLogging() {
        let expectation = XCTestExpectation(description: "Concurrent logging completed")
        expectation.expectedFulfillmentCount = 10
        
        for i in 0..<10 {
            DispatchQueue.global(qos: .background).async {
                for j in 0..<100 {
                    self.logger.info("Concurrent log \(i)-\(j)")
                }
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 5.0)
        
        // Should handle concurrent logging without crashes
        let concurrentLogs = logger.recentLogs.filter { $0.message.starts(with: "Concurrent log") }
        XCTAssertEqual(concurrentLogs.count, 1000)
    }
    
    // MARK: - Performance Tests
    
    func testLoggingPerformance() {
        measure {
            for i in 0..<1000 {
                logger.info("Performance test log \(i)")
            }
        }
    }
    
    func testFilteringPerformance() {
        // Add a bunch of logs first
        for i in 0..<1000 {
            logger.log(LogLevel.allCases.randomElement()!, 
                      "Performance log \(i)", 
                      category: LogCategory.allCases.randomElement()!)
        }
        
        // Wait for processing
        let expectation = XCTestExpectation(description: "Performance logs processed")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1.0)
        
        measure {
            _ = logger.getLogs(level: .warning, category: .transcription, limit: 50)
        }
    }
}
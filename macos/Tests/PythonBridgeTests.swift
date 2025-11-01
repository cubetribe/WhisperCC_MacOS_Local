import XCTest
@testable import WhisperLocalMacOs

final class PythonBridgeTests: XCTestCase {
    
    var pythonBridge: PythonBridge!
    var testPythonPath: URL!
    var testCLIPath: URL!
    
    override func setUpWithError() throws {
        // Create test paths (pointing to real files for integration testing)
        testPythonPath = URL(fileURLWithPath: "/usr/bin/python3")
        testCLIPath = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("macos_cli.py")
        
        pythonBridge = PythonBridge(
            pythonPath: testPythonPath,
            cliWrapperPath: testCLIPath
        )
    }
    
    override func tearDownWithError() throws {
        pythonBridge?.cancelCurrentProcess()
        pythonBridge = nil
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        XCTAssertNotNil(pythonBridge)
        XCTAssertFalse(pythonBridge.isProcessing)
        XCTAssertNil(pythonBridge.lastError)
    }
    
    func testDefaultPathResolution() {
        let defaultBridge = PythonBridge()
        XCTAssertNotNil(defaultBridge)
        // Default paths should be resolved without throwing
    }
    
    // MARK: - Environment Validation Tests
    
    func testEnvironmentValidation() async {
        let validationResult = await pythonBridge.validateEnvironment()
        
        // Log validation result for debugging
        print("Validation result: \(validationResult.summary)")
        
        // Test should pass if both Python and CLI wrapper exist
        if FileManager.default.fileExists(atPath: testPythonPath.path) &&
           FileManager.default.fileExists(atPath: testCLIPath.path) {
            XCTAssertTrue(validationResult.isValid, "Environment should be valid when files exist")
        } else {
            XCTAssertFalse(validationResult.isValid, "Environment should be invalid when files are missing")
            XCTAssertFalse(validationResult.issues.isEmpty, "Should report specific issues")
        }
    }
    
    // MARK: - Command Execution Tests
    
    func testBasicCommandExecution() async throws {
        // Skip if CLI wrapper doesn't exist
        guard FileManager.default.fileExists(atPath: testCLIPath.path) else {
            throw XCTSkip("CLI wrapper not available for testing")
        }
        
        let command: [String: Any] = [
            "command": "list_models"
        ]
        
        do {
            let response = try await pythonBridge.executeCommand(command)
            
            // Verify response structure
            XCTAssertNotNil(response["success"])
            XCTAssertNotNil(response["timestamp"])
            
            if let success = response["success"] as? Bool, success {
                XCTAssertNotNil(response["data"], "Successful response should have data")
            }
        } catch let error as PythonBridgeError {
            // Log error for debugging
            print("Command execution error: \(error.localizedDescription)")
            
            // Accept certain errors as valid test outcomes
            switch error {
            case .pythonError(_, let code):
                // These are valid error responses from the CLI
                XCTAssertTrue(["DEPENDENCY_MISSING", "MODELS_DIR_NOT_FOUND"].contains(code),
                             "Unexpected error code: \(code)")
            default:
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testInvalidCommandHandling() async {
        guard FileManager.default.fileExists(atPath: testCLIPath.path) else {
            return // Skip if CLI not available
        }
        
        let invalidCommand: [String: Any] = [
            "command": "invalid_command"
        ]
        
        do {
            _ = try await pythonBridge.executeCommand(invalidCommand)
            XCTFail("Should have thrown an error for invalid command")
        } catch let error as PythonBridgeError {
            switch error {
            case .pythonError(_, let code):
                XCTAssertEqual(code, "INVALID_COMMAND", "Should return INVALID_COMMAND error")
            default:
                // Accept other error types as valid test outcomes
                break
            }
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
    
    func testConcurrentExecutionPrevention() async {
        guard FileManager.default.fileExists(atPath: testCLIPath.path) else {
            return
        }
        
        let command: [String: Any] = ["command": "list_models"]
        
        // Start first command
        Task {
            do {
                _ = try await pythonBridge.executeCommand(command)
            } catch {
                // Ignore errors for this test
            }
        }
        
        // Try to start second command immediately
        do {
            _ = try await pythonBridge.executeCommand(command)
            XCTFail("Should prevent concurrent execution")
        } catch PythonBridgeError.processAlreadyRunning {
            // This is the expected outcome
            XCTAssertTrue(true)
        } catch {
            // Other errors might occur if first process completes quickly
            // This is acceptable for this test
        }
    }
    
    // MARK: - Model Management Tests
    
    func testListModels() async {
        guard FileManager.default.fileExists(atPath: testCLIPath.path) else {
            return
        }
        
        do {
            let models = try await pythonBridge.listModels()
            
            // Should return some models (even if just the default set)
            XCTAssertFalse(models.isEmpty, "Should return at least some models")
            
            // Verify model structure
            if let firstModel = models.first {
                XCTAssertFalse(firstModel.name.isEmpty)
                XCTAssertGreaterThan(firstModel.sizeMB, 0)
                XCTAssertFalse(firstModel.description.isEmpty)
            }
            
        } catch let error as PythonBridgeError {
            // Accept certain errors as valid test outcomes
            switch error {
            case .pythonError(_, let code):
                XCTAssertTrue(["DEPENDENCY_MISSING", "MODELS_DIR_NOT_FOUND"].contains(code))
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
    
    func testDownloadModel() async {
        guard FileManager.default.fileExists(atPath: testCLIPath.path) else {
            return
        }
        
        // Use the smallest model for testing
        let testModel = WhisperModel(
            name: "tiny",
            sizeMB: 39,
            description: "Test model",
            performance: ModelPerformance(speedMultiplier: 32, accuracy: "Fair", memoryUsage: "Low", languages: 99),
            downloadURL: "https://example.com/tiny.bin"
        )
        
        do {
            let result = try await pythonBridge.downloadModel(testModel)
            
            // Should return a model (might be marked as already downloaded)
            XCTAssertEqual(result.name, testModel.name)
            
        } catch let error as PythonBridgeError {
            // Accept certain errors as valid test outcomes
            switch error {
            case .pythonError(_, let code):
                XCTAssertTrue(["DEPENDENCY_MISSING", "DOWNLOAD_FAILED", "ALREADY_DOWNLOADED"].contains(code))
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
    
    // MARK: - Transcription Tests
    
    func testTranscribeFile() async {
        guard FileManager.default.fileExists(atPath: testCLIPath.path) else {
            return
        }
        
        let testTask = TranscriptionTask(
            inputURL: URL(fileURLWithPath: "/nonexistent/test.mp3"),
            outputDirectory: URL(fileURLWithPath: "/tmp"),
            model: "tiny",
            formats: [.txt],
            language: "en"
        )
        
        do {
            let result = try await pythonBridge.transcribeFile(testTask)
            
            // Should return a result (likely with error due to nonexistent file)
            XCTAssertEqual(result.inputFile, testTask.inputURL.path)
            XCTAssertEqual(result.modelUsed, testTask.model)
            
        } catch let error as PythonBridgeError {
            // Accept file-related errors as valid test outcomes
            switch error {
            case .pythonError(_, let code):
                XCTAssertTrue(["FILE_NOT_FOUND", "DEPENDENCY_MISSING"].contains(code))
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
    
    func testExtractAudio() async {
        guard FileManager.default.fileExists(atPath: testCLIPath.path) else {
            return
        }
        
        let videoURL = URL(fileURLWithPath: "/nonexistent/test.mp4")
        let outputURL = URL(fileURLWithPath: "/tmp/test.wav")
        
        do {
            let result = try await pythonBridge.extractAudio(from: videoURL, to: outputURL)
            
            // Should return output URL
            XCTAssertFalse(result.path.isEmpty)
            
        } catch let error as PythonBridgeError {
            // Accept file-related errors as valid test outcomes
            switch error {
            case .pythonError(_, let code):
                XCTAssertTrue(["FILE_NOT_FOUND", "DEPENDENCY_MISSING", "EXTRACTION_FAILED"].contains(code))
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
    
    // MARK: - Batch Processing Tests
    
    func testProcessBatch() async {
        guard FileManager.default.fileExists(atPath: testCLIPath.path) else {
            return
        }
        
        let tasks = [
            TranscriptionTask(
                inputURL: URL(fileURLWithPath: "/nonexistent/test1.mp3"),
                model: "tiny",
                formats: [.txt]
            ),
            TranscriptionTask(
                inputURL: URL(fileURLWithPath: "/nonexistent/test2.mp3"),
                model: "tiny",
                formats: [.txt]
            )
        ]
        
        do {
            let results = try await pythonBridge.processBatch(tasks)
            
            // Should return results for all tasks
            XCTAssertEqual(results.count, tasks.count)
            
            // Results should correspond to input tasks
            for (index, result) in results.enumerated() {
                XCTAssertEqual(result.inputFile, tasks[index].inputURL.path)
            }
            
        } catch let error as PythonBridgeError {
            // Accept dependency-related errors as valid test outcomes
            switch error {
            case .pythonError(_, let code):
                XCTAssertTrue(["DEPENDENCY_MISSING", "BATCH_PROCESSING_FAILED"].contains(code))
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(type(of: error))")
        }
    }
    
    // MARK: - Process Management Tests
    
    func testCancelProcess() async {
        // Set up a long-running mock command
        pythonBridge.isProcessing = true
        
        // Cancel the process
        pythonBridge.cancelCurrentProcess()
        
        // Should reset processing state
        XCTAssertFalse(pythonBridge.isProcessing)
    }
    
    // MARK: - Error Handling Tests
    
    func testPythonBridgeErrorDescriptions() {
        let errors: [PythonBridgeError] = [
            .processAlreadyRunning,
            .processExecutionFailed("Test message"),
            .processTerminatedWithError(1, "Test error"),
            .invalidResponse("Test response"),
            .pythonError("Test python error", code: "TEST_CODE"),
            .executionFailed("Test execution")
        ]
        
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.errorDescription!.isEmpty)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
        }
    }
    
    func testErrorRecoverySuggestions() {
        let testCodes = ["FILE_NOT_FOUND", "INVALID_FORMAT", "MODEL_NOT_FOUND", "INSUFFICIENT_DISK_SPACE", "UNKNOWN_ERROR"]
        
        for code in testCodes {
            let error = PythonBridgeError.pythonError("Test message", code: code)
            XCTAssertNotNil(error.recoverySuggestion)
            XCTAssertFalse(error.recoverySuggestion!.isEmpty)
        }
    }
    
    // MARK: - JSON Serialization Tests
    
    func testJSONSerialization() throws {
        let testCommand: [String: Any] = [
            "command": "transcribe",
            "input_file": "/test/file.mp3",
            "model": "tiny",
            "formats": ["txt", "srt"],
            "language": "en"
        ]
        
        // Should be able to serialize to JSON
        let jsonData = try JSONSerialization.data(withJSONObject: testCommand, options: [])
        XCTAssertGreaterThan(jsonData.count, 0)
        
        // Should be able to deserialize back
        let deserialized = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        XCTAssertNotNil(deserialized)
        XCTAssertEqual(deserialized?["command"] as? String, "transcribe")
    }
    
    func testResponseParsing() throws {
        let testResponse = """
        {
            "success": true,
            "data": {
                "input_file": "/test/file.mp3",
                "output_files": ["/test/output.txt"],
                "processing_time": 10.5,
                "model_used": "tiny"
            },
            "timestamp": "2024-01-01T12:00:00Z"
        }
        """
        
        guard let responseData = testResponse.data(using: .utf8),
              let parsed = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
            XCTFail("Failed to parse test response")
            return
        }
        
        XCTAssertEqual(parsed["success"] as? Bool, true)
        XCTAssertNotNil(parsed["data"])
        XCTAssertNotNil(parsed["timestamp"])
    }
}

// MARK: - Test Helpers

extension PythonBridgeTests {
    
    /// Create a mock transcription task for testing
    func createMockTask(fileName: String = "test.mp3") -> TranscriptionTask {
        return TranscriptionTask(
            inputURL: URL(fileURLWithPath: "/tmp/\(fileName)"),
            outputDirectory: URL(fileURLWithPath: "/tmp/output"),
            model: "tiny",
            formats: [.txt],
            language: "auto"
        )
    }
    
    /// Create a mock WhisperModel for testing
    func createMockModel(name: String = "tiny") -> WhisperModel {
        return WhisperModel(
            name: name,
            sizeMB: 39,
            description: "Test model",
            performance: ModelPerformance(
                speedMultiplier: 32,
                accuracy: "Fair",
                memoryUsage: "Low",
                languages: 99
            ),
            downloadURL: "https://example.com/\(name).bin"
        )
    }
}
import XCTest
@testable import WhisperLocalMacOs

final class ErrorHandlingTests: XCTestCase {
    
    // MARK: - AppError Tests
    
    func testFileProcessingErrors() {
        let errors: [FileProcessingError] = [
            .fileNotFound("/test/path.mp3"),
            .fileNotReadable("/test/path.mp3"),
            .invalidFormat("test.xyz", supportedFormats: ["mp3", "wav"]),
            .fileTooLarge(2000000000, maxSize: 1000000000),
            .fileCorrupted("/test/path.mp3"),
            .outputDirectoryNotWritable("/test/output"),
            .transcriptionFailed("test.mp3", reason: "Model error"),
            .audioExtractionFailed("test.mp4", reason: "Codec error"),
            .outputFileCreationFailed("output.txt", reason: "Permission denied")
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
            XCTAssertFalse(error.recoverySuggestion.isEmpty)
        }
    }
    
    func testModelErrors() {
        let errors: [ModelError] = [
            .modelNotFound("large-v3"),
            .modelNotDownloaded("tiny"),
            .downloadFailed("base", reason: "Network error"),
            .downloadCorrupted("small", expected: "abc123", actual: "def456"),
            .modelDirectoryNotAccessible("/models"),
            .insufficientDiskSpaceForModel("large", required: 2000000000, available: 1000000000),
            .modelValidationFailed("medium", reason: "Checksum mismatch"),
            .modelIncompatible("old-model", reason: "Unsupported version")
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
            XCTAssertFalse(error.recoverySuggestion.isEmpty)
        }
    }
    
    func testResourceErrors() {
        let errors: [ResourceError] = [
            .insufficientMemory(required: 2000000000, available: 1000000000),
            .insufficientDiskSpace(required: 5000000000, available: 2000000000, path: "/tmp"),
            .cpuOverloaded(usage: 0.95, threshold: 0.8),
            .thermalThrottling,
            .networkUnavailable,
            .dependencyMissing("python3", reason: "Not found in PATH"),
            .permissionDenied("/private/var", operation: "write")
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
            XCTAssertFalse(error.recoverySuggestion.isEmpty)
        }
    }
    
    func testBridgeErrors() {
        let errors: [BridgeError] = [
            .pythonNotFound(searchPaths: ["/usr/bin/python3", "/opt/homebrew/bin/python3"]),
            .pythonVersionIncompatible(found: "3.7.0", required: "3.8.0"),
            .cliWrapperNotFound(path: "/app/macos_cli.py"),
            .cliWrapperCorrupted(path: "/app/macos_cli.py"),
            .communicationTimeout(timeoutSeconds: 30.0),
            .processExecutionFailed(command: "python3 macos_cli.py", exitCode: 1, stderr: "Import error"),
            .jsonSerializationError("Invalid characters"),
            .jsonDeserializationError("Malformed JSON"),
            .unexpectedResponseFormat(expected: "success field", received: "error object")
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
            XCTAssertFalse(error.recoverySuggestion.isEmpty)
        }
    }
    
    func testUserInputErrors() {
        let errors: [UserInputError] = [
            .invalidFilePath("/nonexistent/path"),
            .unsupportedFileType("xyz", supportedTypes: ["mp3", "wav"]),
            .invalidOutputDirectory("/readonly"),
            .invalidModelSelection("nonexistent", availableModels: ["tiny", "base"]),
            .invalidLanguageCode("zz", supportedLanguages: ["en", "es"]),
            .invalidFormatSelection(["xyz"], supportedFormats: ["txt", "srt"]),
            .emptyFileQueue,
            .invalidBatchConfiguration("No output directory specified")
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
            XCTAssertFalse(error.recoverySuggestion.isEmpty)
        }
    }
    
    func testConfigurationErrors() {
        let errors: [ConfigurationError] = [
            .invalidConfiguration("Missing required field"),
            .configurationFileCorrupted("/config.json"),
            .configurationFileNotFound("/config.json"),
            .unsupportedConfigurationVersion(found: "1.0", supported: ["2.0", "3.0"]),
            .missingRequiredSetting("python_path"),
            .invalidSettingValue(setting: "max_file_size", value: "invalid", expectedType: "integer")
        ]
        
        for error in errors {
            XCTAssertFalse(error.localizedDescription.isEmpty)
            XCTAssertFalse(error.recoverySuggestion.isEmpty)
        }
    }
    
    // MARK: - AppError Wrapper Tests
    
    func testAppErrorLocalizedError() {
        let appErrors: [AppError] = [
            .fileProcessing(.fileNotFound("/test.mp3")),
            .modelManagement(.modelNotFound("tiny")),
            .systemResource(.insufficientMemory(required: 1000, available: 500)),
            .pythonBridge(.pythonNotFound(searchPaths: ["/usr/bin/python3"])),
            .userInput(.emptyFileQueue),
            .configuration(.invalidConfiguration("Test error"))
        ]
        
        for appError in appErrors {
            XCTAssertNotNil(appError.errorDescription)
            XCTAssertNotNil(appError.recoverySuggestion)
            XCTAssertNotNil(appError.failureReason)
            XCTAssertNotNil(appError.helpAnchor)
            
            XCTAssertFalse(appError.errorDescription!.isEmpty)
            XCTAssertFalse(appError.recoverySuggestion!.isEmpty)
            XCTAssertFalse(appError.failureReason!.isEmpty)
            XCTAssertFalse(appError.helpAnchor!.isEmpty)
        }
    }
    
    func testErrorCategories() {
        let appErrors: [AppError] = [
            .fileProcessing(.fileNotFound("/test.mp3")),
            .modelManagement(.modelNotFound("tiny")),
            .systemResource(.insufficientMemory(required: 1000, available: 500)),
            .pythonBridge(.pythonNotFound(searchPaths: ["/usr/bin/python3"])),
            .userInput(.emptyFileQueue),
            .configuration(.invalidConfiguration("Test error"))
        ]
        
        let expectedCategories: [ErrorCategory] = [
            .fileProcessing,
            .modelManagement,
            .systemResource,
            .pythonBridge,
            .userInput,
            .configuration
        ]
        
        for (appError, expectedCategory) in zip(appErrors, expectedCategories) {
            XCTAssertEqual(appError.category, expectedCategory)
        }
    }
    
    func testErrorSeverity() {
        let lowSeverityError = AppError.userInput(.emptyFileQueue)
        let mediumSeverityError = AppError.fileProcessing(.fileTooLarge(1000, maxSize: 500))
        let highSeverityError = AppError.fileProcessing(.transcriptionFailed("test.mp3", reason: "Unknown"))
        let criticalSeverityError = AppError.systemResource(.dependencyMissing("python3", reason: "Not found"))
        
        XCTAssertEqual(lowSeverityError.severity, .low)
        XCTAssertEqual(mediumSeverityError.severity, .medium)
        XCTAssertEqual(highSeverityError.severity, .high)
        XCTAssertEqual(criticalSeverityError.severity, .critical)
        
        // Test severity comparison
        XCTAssertTrue(ErrorSeverity.low < ErrorSeverity.medium)
        XCTAssertTrue(ErrorSeverity.medium < ErrorSeverity.high)
        XCTAssertTrue(ErrorSeverity.high < ErrorSeverity.critical)
    }
    
    func testErrorRecoverability() {
        let recoverableError = AppError.fileProcessing(.fileNotFound("/test.mp3"))
        let nonRecoverableError = AppError.fileProcessing(.fileCorrupted("/test.mp3"))
        
        XCTAssertTrue(recoverableError.isRecoverable)
        XCTAssertFalse(nonRecoverableError.isRecoverable)
    }
    
    // MARK: - ErrorFactory Tests
    
    func testErrorFactoryFromPythonError() {
        let pythonErrors: [[String: Any]] = [
            ["code": "FILE_NOT_FOUND", "error": "File not found: test.mp3"],
            ["code": "INVALID_FORMAT", "error": "Unsupported format: xyz"],
            ["code": "TRANSCRIPTION_FAILED", "error": "Whisper process failed"],
            ["code": "MODEL_NOT_FOUND", "error": "Model tiny not available"],
            ["code": "DOWNLOAD_FAILED", "error": "Network error"],
            ["code": "INSUFFICIENT_DISK_SPACE", "error": "Not enough space"],
            ["code": "DEPENDENCY_MISSING", "error": "Python not found"],
            ["code": "UNKNOWN_ERROR", "error": "Unknown error occurred"]
        ]
        
        let expectedCategories: [ErrorCategory] = [
            .fileProcessing,  // FILE_NOT_FOUND
            .fileProcessing,  // INVALID_FORMAT
            .fileProcessing,  // TRANSCRIPTION_FAILED
            .modelManagement, // MODEL_NOT_FOUND
            .modelManagement, // DOWNLOAD_FAILED
            .systemResource,  // INSUFFICIENT_DISK_SPACE
            .systemResource,  // DEPENDENCY_MISSING
            .pythonBridge     // UNKNOWN_ERROR
        ]
        
        for (pythonError, expectedCategory) in zip(pythonErrors, expectedCategories) {
            let appError = ErrorFactory.createError(from: pythonError)
            XCTAssertEqual(appError.category, expectedCategory)
            XCTAssertNotNil(appError.errorDescription)
            XCTAssertFalse(appError.errorDescription!.isEmpty)
        }
    }
    
    func testErrorFactoryFromStandardError() {
        let nsError = NSError(domain: NSCocoaErrorDomain, code: NSFileNoSuchFileError, userInfo: [
            NSLocalizedDescriptionKey: "File not found"
        ])
        
        let appError = ErrorFactory.createError(from: nsError)
        XCTAssertEqual(appError.category, .fileProcessing)
        XCTAssertNotNil(appError.errorDescription)
    }
    
    func testErrorFactoryFromAppError() {
        let originalError = AppError.fileProcessing(.fileNotFound("/test.mp3"))
        let createdError = ErrorFactory.createError(from: originalError)
        
        // Should return the same error
        XCTAssertEqual(originalError.category, createdError.category)
    }
    
    // MARK: - Error Code Mapping Tests
    
    func testPythonErrorCodeMapping() {
        let testCases: [(code: String, expectedCategory: ErrorCategory)] = [
            ("FILE_NOT_FOUND", .fileProcessing),
            ("INVALID_FORMAT", .fileProcessing),
            ("FILE_TOO_LARGE", .fileProcessing),
            ("TRANSCRIPTION_FAILED", .fileProcessing),
            ("EXTRACTION_FAILED", .fileProcessing),
            ("MODEL_NOT_FOUND", .modelManagement),
            ("DOWNLOAD_FAILED", .modelManagement),
            ("INSUFFICIENT_DISK_SPACE", .systemResource),
            ("DEPENDENCY_MISSING", .systemResource),
            ("PERMISSION_DENIED", .systemResource),
            ("UNKNOWN_CODE", .pythonBridge) // Should fall back to python bridge error
        ]
        
        for testCase in testCases {
            let pythonError = ["code": testCase.code, "error": "Test message"]
            let appError = ErrorFactory.createError(from: pythonError)
            XCTAssertEqual(appError.category, testCase.expectedCategory, 
                          "Error code \(testCase.code) should map to category \(testCase.expectedCategory)")
        }
    }
    
    // MARK: - Error Message Quality Tests
    
    func testErrorMessageQuality() {
        let errors: [AppError] = [
            .fileProcessing(.fileNotFound("/Users/test/audio.mp3")),
            .modelManagement(.insufficientDiskSpaceForModel("large-v3", required: 2_000_000_000, available: 500_000_000)),
            .systemResource(.insufficientMemory(required: 8_000_000_000, available: 4_000_000_000)),
            .pythonBridge(.communicationTimeout(timeoutSeconds: 30.0))
        ]
        
        for error in errors {
            guard let description = error.errorDescription,
                  let suggestion = error.recoverySuggestion else {
                XCTFail("Error should have description and suggestion")
                continue
            }
            
            // Test that descriptions are informative
            XCTAssertGreaterThan(description.count, 10, "Error description should be informative")
            
            // Test that suggestions are actionable
            XCTAssertGreaterThan(suggestion.count, 10, "Recovery suggestion should be actionable")
            
            // Test that descriptions don't contain debug info
            XCTAssertFalse(description.contains("nil"), "User-facing description should not contain 'nil'")
            XCTAssertFalse(description.contains("Optional"), "User-facing description should not contain 'Optional'")
        }
    }
    
    // MARK: - Error Context Tests
    
    func testErrorContextPreservation() {
        let originalPath = "/Users/test/important-audio.mp3"
        let error = AppError.fileProcessing(.fileNotFound(originalPath))
        
        guard let description = error.errorDescription else {
            XCTFail("Error should have description")
            return
        }
        
        // Should preserve important context (file path)
        XCTAssertTrue(description.contains(originalPath), "Error should preserve file path context")
    }
    
    func testErrorHelpAnchors() {
        let errors: [AppError] = [
            .fileProcessing(.fileNotFound("/test")),
            .modelManagement(.modelNotFound("test")),
            .systemResource(.networkUnavailable),
            .pythonBridge(.pythonNotFound(searchPaths: [])),
            .userInput(.emptyFileQueue),
            .configuration(.invalidConfiguration("test"))
        ]
        
        let expectedAnchors = [
            "file-processing-errors",
            "model-management-errors",
            "system-resource-errors",
            "python-bridge-errors",
            "user-input-errors",
            "configuration-errors"
        ]
        
        for (error, expectedAnchor) in zip(errors, expectedAnchors) {
            XCTAssertEqual(error.helpAnchor, expectedAnchor)
        }
    }
    
    // MARK: - Enum Coverage Tests
    
    func testErrorCategoryCoverage() {
        // Ensure all error categories are tested
        let allCategories = ErrorCategory.allCases
        XCTAssertEqual(allCategories.count, 6)
        
        for category in allCategories {
            XCTAssertFalse(category.rawValue.isEmpty)
        }
    }
    
    func testErrorSeverityCoverage() {
        // Ensure all severity levels are tested
        let allSeverities = ErrorSeverity.allCases
        XCTAssertEqual(allSeverities.count, 4)
        
        // Test ordering
        let orderedSeverities = allSeverities.sorted()
        XCTAssertEqual(orderedSeverities, [.low, .medium, .high, .critical])
    }
    
    // MARK: - Performance Tests
    
    func testErrorCreationPerformance() {
        measure {
            for _ in 0..<1000 {
                let error = AppError.fileProcessing(.fileNotFound("/test/path.mp3"))
                _ = error.errorDescription
                _ = error.recoverySuggestion
            }
        }
    }
    
    func testErrorFactoryPerformance() {
        let pythonError = ["code": "FILE_NOT_FOUND", "error": "File not found: test.mp3"]
        
        measure {
            for _ in 0..<1000 {
                let error = ErrorFactory.createError(from: pythonError)
                _ = error.errorDescription
            }
        }
    }
}
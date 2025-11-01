import Foundation
import Combine
import AppKit
import UserNotifications

/// Bridge for communication with Python CLI wrapper
@MainActor
class PythonBridge: ObservableObject {
    
    // MARK: - Published Properties
    @Published var isProcessing = false
    @Published var lastError: String?
    @Published var currentProgress: Double = 0.0
    @Published var progressDescription: String = ""
    
    // MARK: - Private Properties
    private let pythonPath: URL
    private let cliWrapperPath: URL
    private var currentProcess: Process?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    // MARK: - Initialization
    
    /// Initialize PythonBridge with paths to Python and CLI wrapper
    init(pythonPath: URL? = nil, cliWrapperPath: URL? = nil) {
        // Use provided paths, embedded dependencies, or system fallbacks
        self.pythonPath = pythonPath ?? Self.resolvePythonPath()
        self.cliWrapperPath = cliWrapperPath ?? Self.resolveCLIWrapperPath()
        
        // Configure JSON encoder/decoder for consistent formatting
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        decoder.dateDecodingStrategy = .iso8601
        
        // Setup environment for embedded dependencies
        setupEmbeddedEnvironment()
    }
    
    // MARK: - Public Methods
    
    /// Execute a JSON command and return the response
    func executeCommand(_ command: [String: Any]) async throws -> [String: Any] {
        guard !isProcessing else {
            throw PythonBridgeError.processAlreadyRunning
        }
        
        isProcessing = true
        lastError = nil
        
        defer {
            isProcessing = false
        }
        
        do {
            // Serialize command to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: command, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8) ?? "{}"
            
            // Execute Python process
            let result = try await executeProcess(with: jsonString)
            
            // Parse response
            guard let responseData = result.data(using: .utf8),
                  let response = try JSONSerialization.jsonObject(with: responseData) as? [String: Any] else {
                throw PythonBridgeError.invalidResponse("Failed to parse JSON response")
            }
            
            // Check for error in response
            if let success = response["success"] as? Bool, !success {
                let errorMessage = response["error"] as? String ?? "Unknown error"
                let errorCode = response["code"] as? String ?? "UNKNOWN_ERROR"
                throw PythonBridgeError.pythonError(errorMessage, code: errorCode)
            }
            
            return response
            
        } catch let error as PythonBridgeError {
            lastError = error.localizedDescription
            throw error
        } catch {
            let bridgeError = PythonBridgeError.executionFailed(error.localizedDescription)
            lastError = bridgeError.localizedDescription
            throw bridgeError
        }
    }
    
    /// Transcribe a file using the specified task configuration
    func transcribeFile(_ task: TranscriptionTask) async throws -> TranscriptionResult {
        let command: [String: Any] = [
            "command": "transcribe",
            "input_file": task.inputURL.path,
            "output_dir": task.outputDirectory.path,
            "model": task.model,
            "formats": task.formats.map { $0.rawValue },
            "language": task.language == "auto" ? nil : task.language
        ].compactMapValues { $0 }
        
        let response = try await executeCommand(command)
        
        // Extract data from response
        guard let data = response["data"] as? [String: Any] else {
            throw PythonBridgeError.invalidResponse("Missing data in transcription response")
        }
        
        return try parseTranscriptionResult(from: data, for: task)
    }
    
    /// Extract audio from video file
    func extractAudio(from videoURL: URL, to outputURL: URL) async throws -> URL {
        let command: [String: Any] = [
            "command": "extract",
            "input_file": videoURL.path,
            "output_file": outputURL.path
        ]
        
        let response = try await executeCommand(command)
        
        guard let data = response["data"] as? [String: Any],
              let outputPath = data["output_file"] as? String else {
            throw PythonBridgeError.invalidResponse("Missing output file in extraction response")
        }
        
        return URL(fileURLWithPath: outputPath)
    }
    
    /// List available Whisper models
    func listModels() async throws -> [WhisperModel] {
        let command: [String: Any] = [
            "command": "list_models"
        ]
        
        let response = try await executeCommand(command)
        
        guard let data = response["data"] as? [String: Any],
              let modelsData = data["models"] as? [[String: Any]] else {
            throw PythonBridgeError.invalidResponse("Missing models data in response")
        }
        
        return try parseModelList(from: modelsData)
    }
    
    /// Download a Whisper model with progress tracking
    func downloadModel(_ model: WhisperModel, progressHandler: @escaping (Double) -> Void = { _ in }) async throws -> WhisperModel {
        let command: [String: Any] = [
            "command": "download_model",
            "model_name": model.name
        ]
        
        // This would need progress monitoring implementation
        // For now, we'll execute the command and return the result
        let response = try await executeCommand(command)
        
        guard let data = response["data"] as? [String: Any] else {
            throw PythonBridgeError.invalidResponse("Missing data in download response")
        }
        
        // Return updated model with download status
        var updatedModel = model
        if let downloaded = data["downloaded"] as? Bool, downloaded {
            if let localPath = data["local_path"] as? String {
                updatedModel.markDownloaded(at: URL(fileURLWithPath: localPath))
            }
        }
        
        return updatedModel
    }
    
    /// Process a batch of files
    func processBatch(_ tasks: [TranscriptionTask], progressHandler: @escaping (Double, Int, Int) -> Void = { _, _, _ in }) async throws -> [TranscriptionResult] {
        let files = tasks.map { task in
            [
                "input_file": task.inputURL.path,
                "output_dir": task.outputDirectory.path,
                "model": task.model,
                "formats": task.formats.map { $0.rawValue },
                "language": task.language == "auto" ? nil : task.language
            ].compactMapValues { $0 }
        }
        
        let command: [String: Any] = [
            "command": "process_batch",
            "files": files,
            "continue_on_error": true
        ]
        
        let response = try await executeCommand(command)
        
        guard let data = response["data"] as? [String: Any],
              let resultsData = data["results"] as? [[String: Any]] else {
            throw PythonBridgeError.invalidResponse("Missing results data in batch response")
        }
        
        return try parseBatchResults(from: resultsData, for: tasks)
    }
    
    /// Cancel any running process
    func cancelCurrentProcess() {
        currentProcess?.terminate()
        currentProcess = nil
        isProcessing = false
    }
    
    // MARK: - Private Methods
    
    /// Execute Python process with JSON input
    private func executeProcess(with jsonInput: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let process = Process()
                    process.executableURL = self.pythonPath
                    process.arguments = [self.cliWrapperPath.path]
                    
                    let inputPipe = Pipe()
                    let outputPipe = Pipe()
                    let errorPipe = Pipe()
                    
                    process.standardInput = inputPipe
                    process.standardOutput = outputPipe
                    process.standardError = errorPipe
                    
                    try process.run()
                    self.currentProcess = process
                    
                    // Send JSON input
                    if let inputData = jsonInput.data(using: .utf8) {
                        inputPipe.fileHandleForWriting.write(inputData)
                    }
                    inputPipe.fileHandleForWriting.closeFile()
                    
                    // Wait for completion
                    process.waitUntilExit()
                    
                    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                    
                    if process.terminationStatus != 0 {
                        let errorMessage = String(data: errorData, encoding: .utf8) ?? "Process failed with exit code \(process.terminationStatus)"
                        continuation.resume(throwing: PythonBridgeError.processTerminatedWithError(process.terminationStatus, errorMessage))
                        return
                    }
                    
                    let output = String(data: outputData, encoding: .utf8) ?? ""
                    continuation.resume(returning: output)
                    
                } catch {
                    continuation.resume(throwing: PythonBridgeError.processExecutionFailed(error.localizedDescription))
                }
            }
        }
    }
    
    /// Parse transcription result from response data
    private func parseTranscriptionResult(from data: [String: Any], for task: TranscriptionTask) throws -> TranscriptionResult {
        guard let inputFile = data["input_file"] as? String else {
            throw PythonBridgeError.invalidResponse("Missing input_file in transcription result")
        }
        
        let processingTime = data["processing_time"] as? Double ?? 0.0
        let modelUsed = data["model_used"] as? String ?? task.model
        let language = data["language"] as? String
        
        // Check if transcription was successful
        if let error = data["error"] as? String {
            return TranscriptionResult(
                inputFile: inputFile,
                error: error,
                processingTime: processingTime,
                modelUsed: modelUsed
            )
        } else {
            let outputFiles = data["output_files"] as? [String] ?? []
            
            // Parse metadata if available
            var metadata: TranscriptionMetadata?
            if let metadataDict = data["metadata"] as? [String: Any] {
                metadata = try parseMetadata(from: metadataDict)
            }
            
            return TranscriptionResult(
                inputFile: inputFile,
                outputFiles: outputFiles,
                processingTime: processingTime,
                modelUsed: modelUsed,
                language: language,
                metadata: metadata
            )
        }
    }
    
    /// Parse metadata from response data
    private func parseMetadata(from data: [String: Any]) throws -> TranscriptionMetadata {
        return TranscriptionMetadata(
            confidence: data["confidence"] as? Double,
            segmentCount: data["segment_count"] as? Int,
            averageSegmentDuration: data["average_segment_duration"] as? Double,
            audioDuration: data["audio_duration"] as? Double,
            languageConfidence: data["language_confidence"] as? Double,
            detectedLanguage: data["detected_language"] as? String,
            vadUsed: data["vad_used"] as? Bool,
            peakMemoryUsage: data["peak_memory_usage"] as? Int64,
            customProperties: data["custom_properties"] as? [String: String]
        )
    }
    
    /// Parse model list from response data
    private func parseModelList(from data: [[String: Any]]) throws -> [WhisperModel] {
        return try data.map { modelData in
            guard let name = modelData["name"] as? String,
                  let sizeMB = modelData["size_mb"] as? Double,
                  let description = modelData["description"] as? String else {
                throw PythonBridgeError.invalidResponse("Missing required model fields")
            }
            
            // Parse performance data
            var performance: ModelPerformance
            if let perfData = modelData["performance"] as? [String: Any],
               let speedMultiplier = perfData["speed_multiplier"] as? Double,
               let accuracy = perfData["accuracy"] as? String,
               let memoryUsage = perfData["memory_usage"] as? String,
               let languages = perfData["languages"] as? Int {
                performance = ModelPerformance(
                    speedMultiplier: speedMultiplier,
                    accuracy: accuracy,
                    memoryUsage: memoryUsage,
                    languages: languages
                )
            } else {
                // Fallback to default performance
                performance = ModelPerformance(
                    speedMultiplier: 1.0,
                    accuracy: "Unknown",
                    memoryUsage: "Medium",
                    languages: 99
                )
            }
            
            let downloadURL = modelData["download_url"] as? String ?? ""
            let sha256 = modelData["sha256"] as? String
            let isDownloaded = modelData["is_downloaded"] as? Bool ?? false
            let localFilePath = modelData["local_file_path"] as? String
            
            var model = WhisperModel(
                name: name,
                sizeMB: sizeMB,
                description: description,
                performance: performance,
                downloadURL: downloadURL,
                sha256: sha256,
                isDownloaded: isDownloaded,
                localFilePath: localFilePath != nil ? URL(fileURLWithPath: localFilePath!) : nil
            )
            
            if let progress = modelData["download_progress"] as? Double {
                model.updateDownloadProgress(progress)
            }
            
            return model
        }
    }
    
    /// Parse batch processing results
    private func parseBatchResults(from data: [[String: Any]], for tasks: [TranscriptionTask]) throws -> [TranscriptionResult] {
        return try data.enumerated().map { index, resultData in
            let task = index < tasks.count ? tasks[index] : TranscriptionTask(inputURL: URL(fileURLWithPath: "/unknown"))
            return try parseTranscriptionResult(from: resultData, for: task)
        }
    }
    
    // MARK: - Static Methods
    
    /// Resolve Python executable path using DependencyManager
    private static func resolvePythonPath() -> URL {
        let dependencyManager = DependencyManager.shared
        let embeddedPath = dependencyManager.pythonExecutablePath
        
        // Check if embedded Python exists and is valid
        if FileManager.default.fileExists(atPath: embeddedPath.path) &&
           FileManager.default.isExecutableFile(atPath: embeddedPath.path) {
            return embeddedPath
        }
        
        // Fallback to system Python
        return URL(fileURLWithPath: "/usr/bin/python3")
    }
    
    /// Resolve CLI wrapper path using DependencyManager
    private static func resolveCLIWrapperPath() -> URL {
        let dependencyManager = DependencyManager.shared
        let embeddedPath = dependencyManager.cliWrapperPath
        
        // Check if embedded CLI wrapper exists
        if FileManager.default.fileExists(atPath: embeddedPath.path) {
            return embeddedPath
        }
        
        // Fallback to project path (for development)
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("macos_cli.py")
    }
    
    /// Setup environment for embedded dependencies
    private func setupEmbeddedEnvironment() {
        DependencyManager.shared.setupEnvironment()
    }
    
    // MARK: - Native macOS Integration
    
    /// Update dock progress indicator
    func updateDockProgress(_ progress: Double, description: String = "") {
        DispatchQueue.main.async { [weak self] in
            self?.currentProgress = progress
            self?.progressDescription = description
            
            if progress > 0.0 && progress < 1.0 {
                NSApp.dockTile.badgeLabel = "\(Int(progress * 100))%"
                NSApp.dockTile.display()
            } else {
                NSApp.dockTile.badgeLabel = nil
                NSApp.dockTile.display()
            }
        }
    }
    
    /// Show dock progress for batch operations
    func updateBatchDockProgress(completedTasks: Int, totalTasks: Int) {
        let progress = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0.0
        let description = "Processing \(completedTasks)/\(totalTasks) files"
        updateDockProgress(progress, description: description)
    }
    
    /// Clear dock progress indicator
    func clearDockProgress() {
        DispatchQueue.main.async {
            NSApp.dockTile.badgeLabel = nil
            NSApp.dockTile.display()
        }
    }
    
    /// Request notification permissions
    func requestNotificationPermissions() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                Logger.shared.info("Notification permissions granted", category: .system)
            } else if let error = error {
                Logger.shared.error("Failed to get notification permissions: \(error)", category: .system)
            }
        }
    }
    
    /// Show completion notification
    func showCompletionNotification(title: String, body: String, isSuccess: Bool = true) {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = isSuccess ? .default : .defaultCritical
        
        // Add custom actions based on success/failure
        if isSuccess {
            let openAction = UNNotificationAction(
                identifier: "OPEN_RESULTS",
                title: "Open Results",
                options: .foreground
            )
            let category = UNNotificationCategory(
                identifier: "TRANSCRIPTION_COMPLETE",
                actions: [openAction],
                intentIdentifiers: [],
                options: []
            )
            center.setNotificationCategories([category])
            content.categoryIdentifier = "TRANSCRIPTION_COMPLETE"
        }
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        center.add(request) { error in
            if let error = error {
                Logger.shared.error("Failed to show notification: \(error)", category: .system)
            }
        }
    }
    
    /// Show batch completion notification
    func showBatchCompletionNotification(successful: Int, failed: Int, total: Int) {
        let title = failed == 0 ? "Batch Processing Complete" : "Batch Processing Finished with Errors"
        let body = failed == 0 
            ? "Successfully processed \(successful) files"
            : "Processed \(successful) files successfully, \(failed) failed"
        
        showCompletionNotification(title: title, body: body, isSuccess: failed == 0)
    }
}

// MARK: - Error Types

enum PythonBridgeError: LocalizedError {
    case processAlreadyRunning
    case processExecutionFailed(String)
    case processTerminatedWithError(Int32, String)
    case invalidResponse(String)
    case pythonError(String, code: String)
    case executionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .processAlreadyRunning:
            return "A Python process is already running"
        case .processExecutionFailed(let message):
            return "Failed to execute Python process: \(message)"
        case .processTerminatedWithError(let code, let message):
            return "Python process terminated with error code \(code): \(message)"
        case .invalidResponse(let message):
            return "Invalid response from Python process: \(message)"
        case .pythonError(let message, let code):
            return "Python error (\(code)): \(message)"
        case .executionFailed(let message):
            return "Execution failed: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .processAlreadyRunning:
            return "Wait for the current process to complete or cancel it before starting a new one."
        case .processExecutionFailed, .processTerminatedWithError:
            return "Check that Python is installed and the CLI wrapper is accessible."
        case .invalidResponse:
            return "Verify that the CLI wrapper is returning valid JSON responses."
        case .pythonError(_, let code):
            return errorRecoverySuggestion(for: code)
        case .executionFailed:
            return "Check the logs for more detailed error information."
        }
    }
    
    /// Get recovery suggestion for specific error codes
    private func errorRecoverySuggestion(for code: String) -> String {
        switch code {
        case "FILE_NOT_FOUND":
            return "Check that the input file exists and is accessible."
        case "INVALID_FORMAT":
            return "Ensure the file is a supported audio or video format."
        case "MODEL_NOT_FOUND":
            return "Download the required model or select a different one."
        case "INSUFFICIENT_DISK_SPACE":
            return "Free up disk space before attempting transcription."
        case "TRANSCRIPTION_FAILED":
            return "Try using a smaller model or check the input file quality."
        default:
            return "Review the error message and check the application logs."
        }
    }
}

// MARK: - Convenience Extensions

extension PythonBridge {
    
    /// Check if Python and CLI wrapper are available
    func validateEnvironment() async -> ValidationResult {
        var issues: [String] = []
        
        // Check Python executable
        if !FileManager.default.fileExists(atPath: pythonPath.path) {
            issues.append("Python executable not found at \(pythonPath.path)")
        }
        
        // Check CLI wrapper
        if !FileManager.default.fileExists(atPath: cliWrapperPath.path) {
            issues.append("CLI wrapper not found at \(cliWrapperPath.path)")
        }
        
        // Test basic communication if files exist
        if issues.isEmpty {
            do {
                let testCommand: [String: Any] = ["command": "list_models"]
                _ = try await executeCommand(testCommand)
            } catch {
                issues.append("Communication test failed: \(error.localizedDescription)")
            }
        }
        
        return ValidationResult(isValid: issues.isEmpty, issues: issues)
    }
    
    // MARK: - Chatbot Integration
    
    /// Execute chatbot command through Python CLI using JSON command structure
    func executeChatbotCommand(_ args: [String]) async throws -> String {
        guard !isProcessing else {
            throw PythonBridgeError.processAlreadyRunning
        }
        
        isProcessing = true
        lastError = nil
        defer { isProcessing = false }
        
        // Convert command line args to JSON structure
        var commandData: [String: Any] = ["command": "chatbot"]
        
        // Parse command line args
        if args.count >= 1 {
            commandData["subcommand"] = args[0]
            
            // Parse additional parameters
            var i = 1
            while i < args.count - 1 {
                let arg = args[i]
                let value = args[i + 1]
                
                switch arg {
                case "--query":
                    commandData["query"] = value
                case "--threshold":
                    commandData["threshold"] = Double(value) ?? 0.3
                case "--limit":
                    commandData["limit"] = Int(value) ?? 10
                case "--file":
                    commandData["file_path"] = value
                case "--content":
                    commandData["content"] = value
                case "--start-date":
                    commandData["start_date"] = Double(value)
                case "--end-date":
                    commandData["end_date"] = Double(value)
                case "--format":
                    if value == "json" {
                        // JSON format is default
                    }
                default:
                    break
                }
                i += 2
            }
        }
        
        // Convert to JSON
        guard let jsonData = try? JSONSerialization.data(withJSONObject: commandData),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw PythonBridgeError.invalidResponse("Failed to serialize chatbot command")
        }
        
        // Execute command using existing JSON command infrastructure
        let result = try await executeCommand(commandData)
        
        // Extract results data from JSON response
        if let data = result["data"] as? [String: Any],
           let results = data["results"] as? [[String: Any]] {
            // Convert back to JSON string for compatibility
            let resultsData = try JSONSerialization.data(withJSONObject: results)
            return String(data: resultsData, encoding: .utf8) ?? "[]"
        } else if let data = result["data"] as? [String: Any] {
            // Return full data object for other commands (status, index)
            let dataJsonData = try JSONSerialization.data(withJSONObject: data)
            return String(data: dataJsonData, encoding: .utf8) ?? "{}"
        }
        
        return "{}"
    }
    
    /// Index a transcription for semantic search
    func indexTranscription(file: URL, transcriptionContent: String) async throws {
        let args = [
            "index",
            "--file", file.path,
            "--content", transcriptionContent
        ]
        
        _ = try await executeChatbotCommand(args)
        Logger.shared.info("Indexed transcription: \(file.lastPathComponent)", category: .chatbot)
    }
    
    /// Check if chatbot functionality is available
    func isChatbotAvailable() async -> Bool {
        do {
            _ = try await executeChatbotCommand(["status"])
            return true
        } catch {
            Logger.shared.warning("Chatbot not available: \(error)", category: .chatbot)
            return false
        }
    }
}

struct ValidationResult {
    let isValid: Bool
    let issues: [String]
    
    var summary: String {
        if isValid {
            return "Python bridge environment is valid"
        } else {
            return "Validation issues found: \(issues.joined(separator: ", "))"
        }
    }
}
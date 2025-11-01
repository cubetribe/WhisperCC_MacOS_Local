import Foundation
import os.log

/// Centralized logging service for the WhisperLocalMacOs application
final class Logger: ObservableObject {
    
    static let shared = Logger()
    
    // MARK: - Published Properties
    @Published private(set) var recentLogs: [LogEntry] = []
    
    // MARK: - Private Properties
    private let osLog = OSLog(subsystem: "com.github.cubetribe.whisper-transcription-tool", category: "general")
    private let logQueue = DispatchQueue(label: "logger.queue", qos: .utility)
    private let maxRecentLogs = 1000
    private let logFileURL: URL
    
    // MARK: - Log File Configuration
    private var logDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                in: .userDomainMask).first!
        return appSupport.appendingPathComponent("WhisperLocalMacOs/Logs")
    }
    
    // MARK: - Initialization
    
    private init() {
        // Create logs directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logDirectory, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
        
        // Set up log file with date-based naming
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        logFileURL = logDirectory.appendingPathComponent("whisper-\(today).log")
        
        // Clean up old log files on startup
        cleanupOldLogs()
        
        // Log startup
        log(.info, "Logger initialized", category: .system)
    }
    
    // MARK: - Main Logging Method
    
    /// Log a message with specified level and category
    func log(_ level: LogLevel, 
             _ message: String, 
             category: LogCategory = .general,
             file: String = #file,
             function: String = #function,
             line: Int = #line,
             error: Error? = nil) {
        
        let entry = LogEntry(
            level: level,
            message: message,
            category: category,
            timestamp: Date(),
            file: URL(fileURLWithPath: file).lastPathComponent,
            function: function,
            line: line,
            error: error
        )
        
        logQueue.async { [weak self] in
            self?.processLogEntry(entry)
        }
    }
    
    // MARK: - Convenience Methods
    
    func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, category: category, file: file, function: function, line: line)
    }
    
    func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, category: category, file: file, function: function, line: line)
    }
    
    func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, category: category, file: file, function: function, line: line)
    }
    
    func error(_ message: String, category: LogCategory = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, category: category, file: file, function: function, line: line, error: error)
    }
    
    func critical(_ message: String, category: LogCategory = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, message, category: category, file: file, function: function, line: line, error: error)
    }
    
    // MARK: - Structured Logging for Operations
    
    func logTranscriptionStart(_ task: TranscriptionTask) {
        info("Transcription started: \(task.inputURL.lastPathComponent) -> \(task.formats.map { $0.rawValue }.joined(separator: ", "))", 
             category: .transcription)
    }
    
    func logTranscriptionComplete(_ task: TranscriptionTask, processingTime: TimeInterval) {
        info("Transcription completed: \(task.inputURL.lastPathComponent) in \(String(format: "%.2f", processingTime))s", 
             category: .transcription)
    }
    
    func logTranscriptionError(_ task: TranscriptionTask, error: Error) {
        self.error("Transcription failed: \(task.inputURL.lastPathComponent)", 
                  category: .transcription, 
                  error: error)
    }
    
    func logModelDownloadStart(_ model: WhisperModel) {
        info("Model download started: \(model.name) (\(model.sizeFormatted))", 
             category: .modelManagement)
    }
    
    func logModelDownloadComplete(_ model: WhisperModel) {
        info("Model download completed: \(model.name)", 
             category: .modelManagement)
    }
    
    func logModelDownloadError(_ model: WhisperModel, error: Error) {
        self.error("Model download failed: \(model.name)", 
                  category: .modelManagement, 
                  error: error)
    }
    
    func logBatchProcessingStart(_ taskCount: Int) {
        info("Batch processing started: \(taskCount) files", 
             category: .batchProcessing)
    }
    
    func logBatchProcessingComplete(_ results: [TranscriptionResult]) {
        let successCount = results.filter { $0.success }.count
        let totalCount = results.count
        info("Batch processing completed: \(successCount)/\(totalCount) successful", 
             category: .batchProcessing)
    }
    
    func logSystemResource(_ usage: String, value: Double) {
        debug("System resource usage - \(usage): \(String(format: "%.1f", value * 100))%", 
              category: .system)
    }
    
    func logPythonBridgeCommand(_ command: String) {
        debug("Python bridge command: \(command)", 
              category: .pythonBridge)
    }
    
    func logPythonBridgeResponse(_ success: Bool, duration: TimeInterval) {
        debug("Python bridge response: success=\(success), duration=\(String(format: "%.3f", duration))s", 
              category: .pythonBridge)
    }
    
    // MARK: - Log Management
    
    /// Export logs to a file for bug reports
    func exportLogs() -> URL? {
        let exportURL = logDirectory.appendingPathComponent("whisper-logs-export.txt")
        
        do {
            var exportContent = "WhisperLocalMacOs Log Export\n"
            exportContent += "Generated: \(Date())\n"
            exportContent += String(repeating: "=", count: 50) + "\n\n"
            
            // Add recent in-memory logs
            let sortedLogs = recentLogs.sorted { $0.timestamp < $1.timestamp }
            for entry in sortedLogs {
                exportContent += entry.formattedForExport + "\n"
            }
            
            // Add current log file content if available
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                exportContent += "\n" + String(repeating: "=", count: 50) + "\n"
                exportContent += "Current Log File Content:\n"
                exportContent += String(repeating: "=", count: 50) + "\n"
                
                if let logFileContent = try? String(contentsOf: logFileURL) {
                    exportContent += logFileContent
                }
            }
            
            try exportContent.write(to: exportURL, atomically: true, encoding: .utf8)
            return exportURL
            
        } catch {
            self.error("Failed to export logs", error: error, category: .system)
            return nil
        }
    }
    
    /// Clear old logs to free up disk space
    func clearOldLogs() {
        do {
            let fileManager = FileManager.default
            let logFiles = try fileManager.contentsOfDirectory(at: logDirectory, 
                                                             includingPropertiesForKeys: [.creationDateKey], 
                                                             options: [])
            
            let calendar = Calendar.current
            let cutoffDate = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
            
            var deletedCount = 0
            for logFile in logFiles {
                if let creationDate = try? logFile.resourceValues(forKeys: [.creationDateKey]).creationDate,
                   creationDate < cutoffDate {
                    try fileManager.removeItem(at: logFile)
                    deletedCount += 1
                }
            }
            
            if deletedCount > 0 {
                info("Cleaned up \(deletedCount) old log files", category: .system)
            }
            
        } catch {
            self.error("Failed to clean up old logs", error: error, category: .system)
        }
    }
    
    /// Get logs filtered by criteria
    func getLogs(level: LogLevel? = nil, 
                category: LogCategory? = nil, 
                since: Date? = nil,
                limit: Int? = nil) -> [LogEntry] {
        
        var filteredLogs = recentLogs
        
        if let level = level {
            filteredLogs = filteredLogs.filter { $0.level.severity >= level.severity }
        }
        
        if let category = category {
            filteredLogs = filteredLogs.filter { $0.category == category }
        }
        
        if let since = since {
            filteredLogs = filteredLogs.filter { $0.timestamp >= since }
        }
        
        let sortedLogs = filteredLogs.sorted { $0.timestamp > $1.timestamp }
        
        if let limit = limit {
            return Array(sortedLogs.prefix(limit))
        }
        
        return sortedLogs
    }
    
    /// Get crash report data
    func getCrashReport() -> String {
        let criticalLogs = getLogs(level: .critical, limit: 50)
        let errorLogs = getLogs(level: .error, limit: 100)
        
        var report = "WhisperLocalMacOs Crash Report\n"
        report += "Generated: \(Date())\n"
        report += String(repeating: "=", count: 50) + "\n\n"
        
        report += "Critical Errors (\(criticalLogs.count)):\n"
        report += String(repeating: "-", count: 30) + "\n"
        for entry in criticalLogs {
            report += entry.formattedForExport + "\n"
        }
        
        report += "\nRecent Errors (\(errorLogs.count)):\n"
        report += String(repeating: "-", count: 30) + "\n"
        for entry in errorLogs {
            report += entry.formattedForExport + "\n"
        }
        
        return report
    }
    
    // MARK: - Private Methods
    
    private func processLogEntry(_ entry: LogEntry) {
        // Write to system log
        writeToSystemLog(entry)
        
        // Write to file
        writeToFile(entry)
        
        // Update in-memory logs
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.recentLogs.append(entry)
            
            // Trim to max size
            if self.recentLogs.count > self.maxRecentLogs {
                self.recentLogs.removeFirst(self.recentLogs.count - self.maxRecentLogs)
            }
        }
    }
    
    private func writeToSystemLog(_ entry: LogEntry) {
        let osLogType: OSLogType = switch entry.level {
        case .debug: .debug
        case .info: .info
        case .warning, .error: .error
        case .critical: .fault
        }
        
        os_log("%{public}@", log: osLog, type: osLogType, entry.formatted)
    }
    
    private func writeToFile(_ entry: LogEntry) {
        do {
            let logLine = entry.formattedForFile + "\n"
            
            if FileManager.default.fileExists(atPath: logFileURL.path) {
                let fileHandle = try FileHandle(forWritingTo: logFileURL)
                fileHandle.seekToEndOfFile()
                fileHandle.write(logLine.data(using: .utf8) ?? Data())
                fileHandle.closeFile()
            } else {
                try logLine.write(to: logFileURL, atomically: true, encoding: .utf8)
            }
            
        } catch {
            // Fallback to console if file writing fails
            print("Logger: Failed to write to file - \(entry.formatted)")
        }
    }
    
    private func cleanupOldLogs() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.clearOldLogs()
        }
    }
}

// MARK: - Log Entry

struct LogEntry: Identifiable, Codable {
    let id = UUID()
    let level: LogLevel
    let message: String
    let category: LogCategory
    let timestamp: Date
    let file: String
    let function: String
    let line: Int
    let error: String? // Serialized error information
    
    init(level: LogLevel, message: String, category: LogCategory, timestamp: Date, 
         file: String, function: String, line: Int, error: Error? = nil) {
        self.level = level
        self.message = message
        self.category = category
        self.timestamp = timestamp
        self.file = file
        self.function = function
        self.line = line
        self.error = error?.localizedDescription
    }
    
    /// Formatted string for display in UI
    var formatted: String {
        let timeString = DateFormatter.timeFormatter.string(from: timestamp)
        return "[\(timeString)] [\(level.rawValue.uppercased())] [\(category.rawValue)] \(message)"
    }
    
    /// Formatted string for file logging
    var formattedForFile: String {
        let timeString = DateFormatter.fileFormatter.string(from: timestamp)
        var result = "\(timeString) [\(level.rawValue.uppercased())] [\(category.rawValue)] \(file):\(line) \(function) - \(message)"
        
        if let error = error {
            result += " | Error: \(error)"
        }
        
        return result
    }
    
    /// Formatted string for export/bug reports
    var formattedForExport: String {
        let timeString = DateFormatter.exportFormatter.string(from: timestamp)
        var result = "\(timeString) [\(level.rawValue.uppercased())] [\(category.rawValue)] \(message)"
        
        if let error = error {
            result += "\n    Error Details: \(error)"
        }
        
        result += "\n    Location: \(file):\(line) in \(function)"
        
        return result
    }
}

// MARK: - Log Level

enum LogLevel: String, CaseIterable, Codable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
    
    var severity: Int {
        switch self {
        case .debug: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        case .critical: return 4
        }
    }
    
    var icon: String {
        switch self {
        case .debug: return "🔧"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "💥"
        }
    }
    
    var color: String {
        switch self {
        case .debug: return "systemGray"
        case .info: return "systemBlue"
        case .warning: return "systemOrange"
        case .error: return "systemRed"
        case .critical: return "systemPurple"
        }
    }
}

// MARK: - Log Category

enum LogCategory: String, CaseIterable, Codable {
    case general = "general"
    case transcription = "transcription"
    case modelManagement = "model_management"
    case batchProcessing = "batch_processing"
    case pythonBridge = "python_bridge"
    case chatbot = "chatbot"
    case system = "system"
    case ui = "ui"
    case network = "network"
    case fileSystem = "file_system"
    
    var displayName: String {
        switch self {
        case .general: return "General"
        case .transcription: return "Transcription"
        case .modelManagement: return "Model Management"
        case .batchProcessing: return "Batch Processing"
        case .pythonBridge: return "Python Bridge"
        case .chatbot: return "Chatbot"
        case .system: return "System"
        case .ui: return "User Interface"
        case .network: return "Network"
        case .fileSystem: return "File System"
        }
    }
    
    var icon: String {
        switch self {
        case .general: return "gear"
        case .transcription: return "waveform"
        case .modelManagement: return "cube.box"
        case .batchProcessing: return "list.bullet"
        case .pythonBridge: return "link"
        case .chatbot: return "bubble.left.and.bubble.right"
        case .system: return "cpu"
        case .ui: return "paintbrush"
        case .network: return "network"
        case .fileSystem: return "folder"
        }
    }
}

// MARK: - DateFormatter Extensions

private extension DateFormatter {
    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
    
    static let fileFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    static let exportFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()
}

// MARK: - Global Convenience Functions

/// Global logging convenience functions
func logDebug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.debug(message, category: category, file: file, function: function, line: line)
}

func logInfo(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.info(message, category: category, file: file, function: function, line: line)
}

func logWarning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.warning(message, category: category, file: file, function: function, line: line)
}

func logError(_ message: String, category: LogCategory = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.error(message, category: category, error: error, file: file, function: function, line: line)
}

func logCritical(_ message: String, category: LogCategory = .general, error: Error? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Logger.shared.critical(message, category: category, error: error, file: file, function: function, line: line)
}
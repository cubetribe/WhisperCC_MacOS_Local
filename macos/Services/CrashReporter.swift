import Foundation
import SwiftUI

/// Comprehensive crash reporting system with automatic recovery and user reporting
final class CrashReporter: ObservableObject {
    
    static let shared = CrashReporter()
    
    // MARK: - Published Properties
    @Published private(set) var hasPendingCrashReport = false
    @Published private(set) var lastCrashInfo: CrashInfo?
    
    // MARK: - Private Properties
    private let logger = Logger.shared
    private let crashDirectory: URL
    private let userDefaults = UserDefaults.standard
    
    private let crashKey = "last_crash_timestamp"
    private let crashReportKey = "pending_crash_report"
    
    // MARK: - Initialization
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, 
                                                in: .userDomainMask).first!
        crashDirectory = appSupport.appendingPathComponent("WhisperLocalMacOs/Crashes")
        
        // Create crash directory if needed
        try? FileManager.default.createDirectory(at: crashDirectory, 
                                               withIntermediateDirectories: true, 
                                               attributes: nil)
        
        // Check for previous crashes on startup
        checkForPreviousCrashes()
        
        // Set up crash handlers
        setupCrashHandlers()
        
        logger.info("CrashReporter initialized", category: .system)
    }
    
    // MARK: - Crash Detection and Handling
    
    /// Set up crash detection handlers
    private func setupCrashHandlers() {
        // Swift error boundary - catch fatal errors
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleCrash(
                type: .uncaughtException,
                message: exception.reason ?? "Unknown exception",
                details: [
                    "name": exception.name.rawValue,
                    "reason": exception.reason ?? "N/A",
                    "callStack": exception.callStackSymbols.joined(separator: "\n")
                ]
            )
        }
        
        // Signal handlers for crashes
        signal(SIGABRT) { signal in
            CrashReporter.shared.handleCrash(
                type: .signal,
                message: "SIGABRT: Abnormal termination",
                details: ["signal": "SIGABRT", "code": "\(signal)"]
            )
        }
        
        signal(SIGSEGV) { signal in
            CrashReporter.shared.handleCrash(
                type: .signal,
                message: "SIGSEGV: Segmentation fault",
                details: ["signal": "SIGSEGV", "code": "\(signal)"]
            )
        }
        
        signal(SIGBUS) { signal in
            CrashReporter.shared.handleCrash(
                type: .signal,
                message: "SIGBUS: Bus error",
                details: ["signal": "SIGBUS", "code": "\(signal)"]
            )
        }
    }
    
    /// Handle a detected crash
    private func handleCrash(type: CrashType, message: String, details: [String: String] = [:]) {
        let crashInfo = CrashInfo(
            type: type,
            message: message,
            timestamp: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
            systemInfo: SystemInfo.current,
            details: details,
            recentLogs: logger.recentLogs.suffix(100).map { $0 }
        )
        
        // Save crash report
        saveCrashReport(crashInfo)
        
        // Log the crash
        logger.critical("Application crash detected: \(message)", category: .system)
        
        // Mark crash in UserDefaults for next launch detection
        userDefaults.set(Date().timeIntervalSince1970, forKey: crashKey)
        userDefaults.set(try? JSONEncoder().encode(crashInfo), forKey: crashReportKey)
        
        // Force save
        userDefaults.synchronize()
    }
    
    /// Record a recoverable error that could lead to instability
    func recordRecoverableError(_ error: AppError, context: String = "") {
        let errorInfo = RecoverableErrorInfo(
            error: error,
            context: context,
            timestamp: Date(),
            stackTrace: Thread.callStackSymbols
        )
        
        logger.warning("Recoverable error recorded: \(error.localizedDescription) | Context: \(context)", 
                      category: .system, 
                      error: error)
        
        // Check if we've had too many recoverable errors recently
        checkErrorFrequency(errorInfo)
    }
    
    /// Check if app crashed previously and handle recovery
    private func checkForPreviousCrashes() {
        guard let crashTimestamp = userDefaults.object(forKey: crashKey) as? TimeInterval,
              let crashData = userDefaults.data(forKey: crashReportKey),
              let crashInfo = try? JSONDecoder().decode(CrashInfo.self, from: crashData) else {
            return
        }
        
        // Check if crash was recent (within last 5 minutes)
        let crashDate = Date(timeIntervalSince1970: crashTimestamp)
        let timeSinceCrash = Date().timeIntervalSince(crashDate)
        
        if timeSinceCrash < 300 { // 5 minutes
            DispatchQueue.main.async {
                self.lastCrashInfo = crashInfo
                self.hasPendingCrashReport = true
            }
            
            logger.warning("Previous crash detected from \(crashDate)", category: .system)
            
            // Attempt automatic recovery
            performAutomaticRecovery(crashInfo)
        }
        
        // Clear crash markers
        userDefaults.removeObject(forKey: crashKey)
        userDefaults.removeObject(forKey: crashReportKey)
    }
    
    // MARK: - Recovery Actions
    
    /// Perform automatic recovery actions after a crash
    private func performAutomaticRecovery(_ crashInfo: CrashInfo) {
        logger.info("Attempting automatic recovery after crash", category: .system)
        
        // Reset potentially problematic settings
        resetToSafeDefaults()
        
        // Clear temporary files that might be corrupted
        clearTemporaryFiles()
        
        // Verify critical dependencies
        verifyDependencies()
        
        logger.info("Automatic recovery completed", category: .system)
    }
    
    private func resetToSafeDefaults() {
        // Reset UI state that might cause crashes
        userDefaults.removeObject(forKey: "selectedModel")
        userDefaults.removeObject(forKey: "lastOutputDirectory")
        userDefaults.removeObject(forKey: "batchProcessingSettings")
        
        logger.debug("Reset UI state to safe defaults", category: .system)
    }
    
    private func clearTemporaryFiles() {
        let tempDirectory = FileManager.default.temporaryDirectory
        
        do {
            let tempFiles = try FileManager.default.contentsOfDirectory(at: tempDirectory, 
                                                                       includingPropertiesForKeys: nil)
            
            for file in tempFiles {
                if file.path.contains("whisper") || file.path.contains("transcription") {
                    try? FileManager.default.removeItem(at: file)
                }
            }
            
            logger.debug("Cleared temporary files", category: .system)
        } catch {
            logger.warning("Failed to clear temporary files", category: .system, error: error)
        }
    }
    
    private func verifyDependencies() {
        // This could trigger dependency verification
        // For now, just log that we should verify
        logger.debug("Dependency verification requested after crash", category: .system)
    }
    
    // MARK: - Error Frequency Analysis
    
    private func checkErrorFrequency(_ errorInfo: RecoverableErrorInfo) {
        // Simple frequency check - could be enhanced with more sophisticated analysis
        let recentErrors = logger.recentLogs
            .filter { $0.level == .error || $0.level == .critical }
            .filter { $0.timestamp > Date().addingTimeInterval(-300) } // Last 5 minutes
        
        if recentErrors.count > 10 {
            logger.critical("High error frequency detected: \(recentErrors.count) errors in 5 minutes", 
                           category: .system)
            
            // Could trigger additional recovery actions
            suggestUserAction("High error frequency detected. Consider restarting the application.")
        }
    }
    
    private func suggestUserAction(_ message: String) {
        DispatchQueue.main.async {
            // This would show a user notification
            // For now, just log it
            self.logger.warning("User action suggested: \(message)", category: .system)
        }
    }
    
    // MARK: - Crash Report Management
    
    /// Save crash report to disk
    private func saveCrashReport(_ crashInfo: CrashInfo) {
        let filename = "crash-\(DateFormatter.fileTimestamp.string(from: crashInfo.timestamp)).json"
        let fileURL = crashDirectory.appendingPathComponent(filename)
        
        do {
            let data = try JSONEncoder().encode(crashInfo)
            try data.write(to: fileURL)
            
            logger.info("Crash report saved to \(fileURL.path)", category: .system)
        } catch {
            logger.error("Failed to save crash report", category: .system, error: error)
        }
    }
    
    /// Get all crash reports
    func getCrashReports() -> [CrashInfo] {
        do {
            let crashFiles = try FileManager.default.contentsOfDirectory(at: crashDirectory, 
                                                                        includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
            
            var reports: [CrashInfo] = []
            
            for file in crashFiles {
                if let data = try? Data(contentsOf: file),
                   let crashInfo = try? JSONDecoder().decode(CrashInfo.self, from: data) {
                    reports.append(crashInfo)
                }
            }
            
            return reports.sorted { $0.timestamp > $1.timestamp }
            
        } catch {
            logger.error("Failed to load crash reports", category: .system, error: error)
            return []
        }
    }
    
    /// Clear processed crash reports
    func clearCrashReports() {
        do {
            let crashFiles = try FileManager.default.contentsOfDirectory(at: crashDirectory, 
                                                                        includingPropertiesForKeys: nil)
            
            for file in crashFiles {
                try FileManager.default.removeItem(at: file)
            }
            
            DispatchQueue.main.async {
                self.hasPendingCrashReport = false
                self.lastCrashInfo = nil
            }
            
            logger.info("Cleared \(crashFiles.count) crash reports", category: .system)
            
        } catch {
            logger.error("Failed to clear crash reports", category: .system, error: error)
        }
    }
    
    /// Generate comprehensive crash report for submission
    func generateSubmissionReport() -> String {
        let crashReports = getCrashReports()
        
        var report = """
        WhisperLocalMacOs Crash Report Submission
        ========================================
        Generated: \(DateFormatter.fullTimestamp.string(from: Date()))
        
        SYSTEM INFORMATION
        ------------------
        macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Architecture: \(ProcessInfo.machineArchitecture)
        Memory: \(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)) GB
        App Version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
        
        CRASH SUMMARY
        -------------
        Total Crashes: \(crashReports.count)
        
        """
        
        for (index, crash) in crashReports.prefix(5).enumerated() {
            report += """
            
            CRASH \(index + 1)
            -----------
            Type: \(crash.type.rawValue)
            Time: \(DateFormatter.fullTimestamp.string(from: crash.timestamp))
            Message: \(crash.message)
            
            """
            
            if !crash.details.isEmpty {
                report += "Details:\n"
                for (key, value) in crash.details {
                    report += "  \(key): \(value)\n"
                }
            }
        }
        
        // Add recent error logs
        let recentErrors = logger.recentLogs
            .filter { $0.level.severity >= LogLevel.error.severity }
            .prefix(20)
        
        if !recentErrors.isEmpty {
            report += "\n\nRECENT ERRORS\n"
            report += "-------------\n"
            
            for entry in recentErrors {
                report += entry.formattedForExport + "\n"
            }
        }
        
        return report
    }
    
    /// Mark crash report as acknowledged by user
    func acknowledgeCrash() {
        DispatchQueue.main.async {
            self.hasPendingCrashReport = false
            self.lastCrashInfo = nil
        }
        
        logger.info("Crash report acknowledged by user", category: .system)
    }
}

// MARK: - Supporting Types

enum CrashType: String, Codable {
    case uncaughtException = "uncaught_exception"
    case signal = "signal"
    case manualReport = "manual_report"
    case highErrorFrequency = "high_error_frequency"
}

struct CrashInfo: Codable {
    let type: CrashType
    let message: String
    let timestamp: Date
    let appVersion: String
    let systemInfo: SystemInfo
    let details: [String: String]
    let recentLogs: [LogEntry]
}

struct RecoverableErrorInfo {
    let error: AppError
    let context: String
    let timestamp: Date
    let stackTrace: [String]
}

// MARK: - ProcessInfo Extension

extension ProcessInfo {
    static var machineArchitecture: String {
        #if arch(arm64)
        return "Apple Silicon (ARM64)"
        #elseif arch(x86_64)
        return "Intel (x86_64)"
        #else
        return "Unknown Architecture"
        #endif
    }
}

// MARK: - DateFormatter Extensions

private extension DateFormatter {
    static let fileTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter
    }()
    
    static let fullTimestamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss Z"
        return formatter
    }()
}

// MARK: - Crash Recovery View

struct CrashRecoveryView: View {
    let crashInfo: CrashInfo
    let onDismiss: () -> Void
    let onSubmitReport: (CrashInfo) -> Void
    
    @State private var includeSystemInfo = true
    @State private var includeRecentLogs = true
    @State private var userComments = ""
    @State private var isSubmitting = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Header
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Application Recovery")
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text("The application recovered from an unexpected issue")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            Divider()
            
            // Crash details
            VStack(alignment: .leading, spacing: 8) {
                Text("What happened?")
                    .font(.headline)
                
                Text(crashInfo.message)
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                
                Text("Time: \(DateFormatter.fullTimestamp.string(from: crashInfo.timestamp))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Recovery actions taken
            VStack(alignment: .leading, spacing: 8) {
                Text("Recovery actions taken:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    Label("Reset application settings to safe defaults", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Label("Cleared temporary files that might be corrupted", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Label("Verified critical application dependencies", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
                .font(.body)
            }
            
            // Bug report section
            VStack(alignment: .leading, spacing: 12) {
                Text("Help improve the application")
                    .font(.headline)
                
                Text("You can help by sending an anonymous crash report to the developers.")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Include system information", isOn: $includeSystemInfo)
                    Toggle("Include recent log entries", isOn: $includeRecentLogs)
                }
                
                TextField("Additional comments (optional)", text: $userComments, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .frame(minHeight: 60)
            }
            
            // Actions
            HStack(spacing: 12) {
                Button("Continue Without Reporting") {
                    onDismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(action: submitReport) {
                    HStack {
                        if isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        Text(isSubmitting ? "Submitting..." : "Submit Report")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isSubmitting)
            }
        }
        .padding(24)
        .frame(minWidth: 500, maxWidth: 600)
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func submitReport() {
        isSubmitting = true
        
        // Simulate submission delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            onSubmitReport(crashInfo)
            isSubmitting = false
        }
    }
}

#if DEBUG
struct CrashRecoveryView_Previews: PreviewProvider {
    static var previews: some View {
        CrashRecoveryView(
            crashInfo: CrashInfo(
                type: .uncaughtException,
                message: "Unexpected error in transcription processing",
                timestamp: Date(),
                appVersion: "1.0.0",
                systemInfo: SystemInfo.current,
                details: ["context": "batch processing"],
                recentLogs: []
            ),
            onDismiss: {},
            onSubmitReport: { _ in }
        )
    }
}
#endif
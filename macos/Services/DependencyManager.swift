import Foundation
import os.log

/// Manages embedded dependencies within the app bundle for portable deployment
@MainActor
class DependencyManager: ObservableObject {
    
    static let shared = DependencyManager()
    
    // MARK: - Published Properties
    
    @Published var dependencyStatus: DependencyStatus = .unknown
    @Published var isValidating: Bool = false
    @Published var lastValidation: Date?
    
    // MARK: - Private Properties
    
    private let logger = Logger.shared
    private let fileManager = FileManager.default
    
    // MARK: - Bundle Structure
    
    /// Main app bundle
    private var appBundle: Bundle {
        return Bundle.main
    }
    
    /// Embedded dependencies directory within the app bundle
    private var dependenciesDirectory: URL {
        guard let bundleURL = appBundle.bundleURL else {
            fatalError("Could not determine app bundle URL")
        }
        return bundleURL.appendingPathComponent("Contents/Resources/Dependencies")
    }
    
    // MARK: - Computed Dependency Paths
    
    /// Path to embedded Python executable
    var pythonExecutablePath: URL {
        let architecture = ProcessInfo.processInfo.machineArchitecture
        let pythonDir = dependenciesDirectory.appendingPathComponent("python-\(architecture)")
        return pythonDir.appendingPathComponent("bin/python3")
    }
    
    /// Path to embedded Whisper.cpp binary
    var whisperBinaryPath: URL {
        let architecture = ProcessInfo.processInfo.machineArchitecture
        let whisperDir = dependenciesDirectory.appendingPathComponent("whisper.cpp-\(architecture)")
        return whisperDir.appendingPathComponent("bin/whisper-cli")
    }
    
    /// Path to embedded FFmpeg binary
    var ffmpegBinaryPath: URL {
        let architecture = ProcessInfo.processInfo.machineArchitecture
        let ffmpegDir = dependenciesDirectory.appendingPathComponent("ffmpeg-\(architecture)")
        return ffmpegDir.appendingPathComponent("bin/ffmpeg")
    }
    
    /// Path to embedded Python packages
    var pythonPackagesPath: URL {
        let architecture = ProcessInfo.processInfo.machineArchitecture
        let pythonDir = dependenciesDirectory.appendingPathComponent("python-\(architecture)")
        return pythonDir.appendingPathComponent("lib/python3.11/site-packages")
    }
    
    /// Path to embedded models directory
    var modelsDirectory: URL {
        return dependenciesDirectory.appendingPathComponent("models")
    }
    
    /// Path to embedded CLI wrapper
    var cliWrapperPath: URL {
        return dependenciesDirectory.appendingPathComponent("macos_cli.py")
    }
    
    // MARK: - Initialization
    
    private init() {
        validateDependenciesOnStartup()
    }
    
    // MARK: - Dependency Validation
    
    func validateDependencies() async -> DependencyStatus {
        isValidating = true
        defer { isValidating = false }
        
        logger.log("Starting dependency validation", level: .info, category: .system)
        
        var issues: [DependencyIssue] = []
        var warnings: [String] = []
        
        // Check bundle structure
        if !fileManager.fileExists(atPath: dependenciesDirectory.path) {
            issues.append(.missingDependencyDirectory)
            dependencyStatus = .missing(issues: issues, warnings: warnings)
            return dependencyStatus
        }
        
        // Validate Python
        let pythonStatus = await validatePython()
        if case .invalid(let issue) = pythonStatus {
            issues.append(issue)
        } else if case .warning(let warning) = pythonStatus {
            warnings.append(warning)
        }
        
        // Validate Whisper.cpp
        let whisperStatus = await validateWhisperBinary()
        if case .invalid(let issue) = whisperStatus {
            issues.append(issue)
        } else if case .warning(let warning) = whisperStatus {
            warnings.append(warning)
        }
        
        // Validate FFmpeg
        let ffmpegStatus = await validateFFmpegBinary()
        if case .invalid(let issue) = ffmpegStatus {
            issues.append(issue)
        } else if case .warning(let warning) = ffmpegStatus {
            warnings.append(warning)
        }
        
        // Validate CLI wrapper
        let cliStatus = await validateCLIWrapper()
        if case .invalid(let issue) = cliStatus {
            issues.append(issue)
        } else if case .warning(let warning) = cliStatus {
            warnings.append(warning)
        }
        
        // Determine overall status
        if issues.isEmpty {
            if warnings.isEmpty {
                dependencyStatus = .valid
            } else {
                dependencyStatus = .validWithWarnings(warnings: warnings)
            }
        } else {
            dependencyStatus = .invalid(issues: issues, warnings: warnings)
        }
        
        lastValidation = Date()
        logger.log("Dependency validation completed: \(dependencyStatus.description)", 
                  level: dependencyStatus.isValid ? .info : .error, 
                  category: .system)
        
        return dependencyStatus
    }
    
    private func validateDependenciesOnStartup() {
        Task {
            await validateDependencies()
        }
    }
    
    // MARK: - Individual Component Validation
    
    private func validatePython() async -> ComponentValidationResult {
        let pythonPath = pythonExecutablePath
        
        guard fileManager.fileExists(atPath: pythonPath.path) else {
            return .invalid(.missingPython)
        }
        
        guard fileManager.isExecutableFile(atPath: pythonPath.path) else {
            return .invalid(.pythonNotExecutable)
        }
        
        // Test Python execution
        do {
            let process = Process()
            process.executableURL = pythonPath
            process.arguments = ["--version"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if output.contains("Python 3.") {
                    logger.log("Python validation successful: \(output.trimmingCharacters(in: .whitespacesAndNewlines))", 
                              level: .info, category: .system)
                    return .valid
                } else {
                    return .invalid(.pythonVersionIncompatible)
                }
            } else {
                return .invalid(.pythonExecutionFailed)
            }
        } catch {
            return .invalid(.pythonExecutionFailed)
        }
    }
    
    private func validateWhisperBinary() async -> ComponentValidationResult {
        let whisperPath = whisperBinaryPath
        
        guard fileManager.fileExists(atPath: whisperPath.path) else {
            return .invalid(.missingWhisperBinary)
        }
        
        guard fileManager.isExecutableFile(atPath: whisperPath.path) else {
            return .invalid(.whisperBinaryNotExecutable)
        }
        
        // Test Whisper binary execution
        do {
            let process = Process()
            process.executableURL = whisperPath
            process.arguments = ["--help"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                logger.log("Whisper binary validation successful", level: .info, category: .system)
                return .valid
            } else {
                return .invalid(.whisperBinaryExecutionFailed)
            }
        } catch {
            return .invalid(.whisperBinaryExecutionFailed)
        }
    }
    
    private func validateFFmpegBinary() async -> ComponentValidationResult {
        let ffmpegPath = ffmpegBinaryPath
        
        guard fileManager.fileExists(atPath: ffmpegPath.path) else {
            return .invalid(.missingFFmpegBinary)
        }
        
        guard fileManager.isExecutableFile(atPath: ffmpegPath.path) else {
            return .invalid(.ffmpegBinaryNotExecutable)
        }
        
        // Test FFmpeg binary execution
        do {
            let process = Process()
            process.executableURL = ffmpegPath
            process.arguments = ["-version"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            try process.run()
            process.waitUntilExit()
            
            if process.terminationStatus == 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                if output.contains("ffmpeg version") {
                    logger.log("FFmpeg validation successful", level: .info, category: .system)
                    return .valid
                } else {
                    return .warning("FFmpeg version output unexpected")
                }
            } else {
                return .invalid(.ffmpegBinaryExecutionFailed)
            }
        } catch {
            return .invalid(.ffmpegBinaryExecutionFailed)
        }
    }
    
    private func validateCLIWrapper() async -> ComponentValidationResult {
        let cliPath = cliWrapperPath
        
        guard fileManager.fileExists(atPath: cliPath.path) else {
            return .invalid(.missingCLIWrapper)
        }
        
        // Validate file is readable Python script
        do {
            let content = try String(contentsOf: cliPath, encoding: .utf8)
            if content.contains("#!/usr/bin/env python") && content.contains("MacOSCLIWrapper") {
                return .valid
            } else {
                return .invalid(.cliWrapperCorrupted)
            }
        } catch {
            return .invalid(.cliWrapperNotReadable)
        }
    }
    
    // MARK: - Environment Setup
    
    func setupEnvironment() {
        let pythonPath = pythonExecutablePath.deletingLastPathComponent().path
        let packagesPath = pythonPackagesPath.path
        
        // Set up Python path
        var pythonPathEnv = ProcessInfo.processInfo.environment["PYTHONPATH"] ?? ""
        if !pythonPathEnv.isEmpty {
            pythonPathEnv += ":"
        }
        pythonPathEnv += packagesPath
        setenv("PYTHONPATH", pythonPathEnv, 1)
        
        // Set up PATH
        var pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        if !pathEnv.isEmpty {
            pathEnv = "\(pythonPath):\(pathEnv)"
        } else {
            pathEnv = pythonPath
        }
        setenv("PATH", pathEnv, 1)
        
        // Set up library path for dynamic libraries
        let libPath = pythonExecutablePath.deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("lib").path
        setenv("DYLD_LIBRARY_PATH", libPath, 1)
        
        logger.log("Environment variables configured for embedded dependencies", 
                  level: .info, category: .system)
    }
    
    // MARK: - Dependency Repair
    
    func attemptRepair() async -> Bool {
        logger.log("Attempting dependency repair", level: .info, category: .system)
        
        // For embedded dependencies, repair typically means re-extracting or re-downloading
        // This is a placeholder for future implementation
        
        // Re-validate after repair attempt
        let status = await validateDependencies()
        return status.isValid
    }
    
    // MARK: - Bundle Information
    
    var bundleInfo: BundleInfo {
        return BundleInfo(
            bundlePath: appBundle.bundlePath,
            dependenciesPath: dependenciesDirectory.path,
            architecture: ProcessInfo.processInfo.machineArchitecture,
            bundleSize: calculateBundleSize(),
            dependencyCount: countEmbeddedDependencies()
        )
    }
    
    private func calculateBundleSize() -> Int64 {
        guard let enumerator = fileManager.enumerator(at: dependenciesDirectory, 
                                                     includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }
        
        var totalSize: Int64 = 0
        for case let url as URL in enumerator {
            if let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey]),
               let fileSize = resourceValues.fileSize {
                totalSize += Int64(fileSize)
            }
        }
        return totalSize
    }
    
    private func countEmbeddedDependencies() -> Int {
        guard let contents = try? fileManager.contentsOfDirectory(atPath: dependenciesDirectory.path) else {
            return 0
        }
        return contents.count
    }
}

// MARK: - Supporting Data Types

enum DependencyStatus {
    case unknown
    case validating
    case valid
    case validWithWarnings(warnings: [String])
    case invalid(issues: [DependencyIssue], warnings: [String])
    case missing(issues: [DependencyIssue], warnings: [String])
    
    var isValid: Bool {
        switch self {
        case .valid, .validWithWarnings:
            return true
        default:
            return false
        }
    }
    
    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .validating:
            return "Validating..."
        case .valid:
            return "All dependencies valid"
        case .validWithWarnings(let warnings):
            return "Valid with \(warnings.count) warning(s)"
        case .invalid(let issues, _):
            return "Invalid: \(issues.count) issue(s)"
        case .missing(let issues, _):
            return "Missing: \(issues.count) dependency(ies)"
        }
    }
    
    var color: NSColor {
        switch self {
        case .unknown, .validating:
            return .systemGray
        case .valid:
            return .systemGreen
        case .validWithWarnings:
            return .systemOrange
        case .invalid, .missing:
            return .systemRed
        }
    }
}

enum DependencyIssue: LocalizedError, Equatable {
    case missingDependencyDirectory
    case missingPython
    case pythonNotExecutable
    case pythonVersionIncompatible
    case pythonExecutionFailed
    case missingWhisperBinary
    case whisperBinaryNotExecutable
    case whisperBinaryExecutionFailed
    case missingFFmpegBinary
    case ffmpegBinaryNotExecutable
    case ffmpegBinaryExecutionFailed
    case missingCLIWrapper
    case cliWrapperNotReadable
    case cliWrapperCorrupted
    case checksumMismatch(component: String)
    case architectureMismatch(expected: String, found: String)
    
    var errorDescription: String? {
        switch self {
        case .missingDependencyDirectory:
            return "Dependencies directory not found in app bundle"
        case .missingPython:
            return "Python runtime not found"
        case .pythonNotExecutable:
            return "Python runtime is not executable"
        case .pythonVersionIncompatible:
            return "Python version is incompatible (requires Python 3.11+)"
        case .pythonExecutionFailed:
            return "Python runtime failed to execute"
        case .missingWhisperBinary:
            return "Whisper.cpp binary not found"
        case .whisperBinaryNotExecutable:
            return "Whisper.cpp binary is not executable"
        case .whisperBinaryExecutionFailed:
            return "Whisper.cpp binary failed to execute"
        case .missingFFmpegBinary:
            return "FFmpeg binary not found"
        case .ffmpegBinaryNotExecutable:
            return "FFmpeg binary is not executable"
        case .ffmpegBinaryExecutionFailed:
            return "FFmpeg binary failed to execute"
        case .missingCLIWrapper:
            return "CLI wrapper script not found"
        case .cliWrapperNotReadable:
            return "CLI wrapper script is not readable"
        case .cliWrapperCorrupted:
            return "CLI wrapper script appears to be corrupted"
        case .checksumMismatch(let component):
            return "Checksum mismatch for \(component)"
        case .architectureMismatch(let expected, let found):
            return "Architecture mismatch: expected \(expected), found \(found)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .missingDependencyDirectory, .missingPython, .missingWhisperBinary, .missingFFmpegBinary, .missingCLIWrapper:
            return "Try reinstalling the application or download the latest version."
        case .pythonNotExecutable, .whisperBinaryNotExecutable, .ffmpegBinaryNotExecutable:
            return "Check file permissions or reinstall the application."
        case .pythonVersionIncompatible:
            return "Update to a newer version of the application with Python 3.11+ support."
        case .pythonExecutionFailed, .whisperBinaryExecutionFailed, .ffmpegBinaryExecutionFailed:
            return "Check system compatibility or try restarting the application."
        case .cliWrapperNotReadable, .cliWrapperCorrupted:
            return "The CLI wrapper may be corrupted. Try reinstalling the application."
        case .checksumMismatch:
            return "Some files may be corrupted. Try reinstalling the application."
        case .architectureMismatch:
            return "This application version may not be compatible with your system architecture."
        }
    }
}

enum ComponentValidationResult {
    case valid
    case warning(String)
    case invalid(DependencyIssue)
}

struct BundleInfo {
    let bundlePath: String
    let dependenciesPath: String
    let architecture: String
    let bundleSize: Int64
    let dependencyCount: Int
    
    var bundleSizeFormatted: String {
        return ByteCountFormatter.string(fromByteCount: bundleSize, countStyle: .file)
    }
}

// MARK: - ProcessInfo Extension

extension ProcessInfo {
    var machineArchitecture: String {
        #if arch(arm64)
        return "arm64"
        #elseif arch(x86_64)
        return "x86_64"
        #else
        return "unknown"
        #endif
    }
}

// MARK: - NSColor Extension

extension NSColor {
    static var systemGray: NSColor {
        return .systemGray
    }
    
    static var systemGreen: NSColor {
        return .systemGreen
    }
    
    static var systemOrange: NSColor {
        return .systemOrange
    }
    
    static var systemRed: NSColor {
        return .systemRed
    }
}
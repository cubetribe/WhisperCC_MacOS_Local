import Foundation
import AppKit
import UniformTypeIdentifiers

@MainActor
class FileAssociationManager: ObservableObject {
    static let shared = FileAssociationManager()
    
    @Published var supportedAudioTypes: [UTType] = []
    @Published var supportedVideoTypes: [UTType] = []
    @Published var isRegisteredAsDefaultHandler: Bool = false
    
    private let supportedAudioExtensions = ["mp3", "wav", "aiff", "m4a", "flac", "ogg", "wma"]
    private let supportedVideoExtensions = ["mp4", "mov", "avi", "mkv", "webm", "m4v", "3gp"]
    
    private init() {
        setupSupportedTypes()
        checkDefaultHandlerStatus()
    }
    
    // MARK: - File Association Setup
    
    private func setupSupportedTypes() {
        // Audio types
        supportedAudioTypes = supportedAudioExtensions.compactMap { ext in
            UTType(filenameExtension: ext)
        }
        
        // Add common audio UTTypes
        supportedAudioTypes.append(contentsOf: [
            .mp3, .wav, .aiff, .m4a,
            UTType("public.flac") ?? .audio,
            UTType("org.xiph.ogg-audio") ?? .audio
        ])
        
        // Video types
        supportedVideoTypes = supportedVideoExtensions.compactMap { ext in
            UTType(filenameExtension: ext)
        }
        
        // Add common video UTTypes
        supportedVideoTypes.append(contentsOf: [
            .mpeg4Movie, .quickTimeMovie, .avi,
            UTType("org.matroska.mkv") ?? .movie,
            UTType("public.webm") ?? .movie
        ])
        
        Logger.shared.info("File associations initialized: \(supportedAudioTypes.count) audio, \(supportedVideoTypes.count) video types", category: .system)
    }
    
    private func checkDefaultHandlerStatus() {
        // Check if we're registered as default handler for any supported types
        let workspace = NSWorkspace.shared
        
        for audioType in supportedAudioTypes {
            if let bundleID = workspace.urlForApplication(toOpen: URL(fileURLWithPath: "/tmp/test.\(audioType.preferredFilenameExtension ?? "mp3")"))?.bundleIdentifier {
                if bundleID == Bundle.main.bundleIdentifier {
                    isRegisteredAsDefaultHandler = true
                    break
                }
            }
        }
        
        Logger.shared.info("Default handler status: \(isRegisteredAsDefaultHandler)", category: .system)
    }
    
    // MARK: - File Type Registration
    
    func registerFileAssociations() {
        let workspace = NSWorkspace.shared
        
        // Register for audio files
        for audioType in supportedAudioTypes {
            registerType(audioType, workspace: workspace, category: "Audio")
        }
        
        // Register for video files
        for videoType in supportedVideoTypes {
            registerType(videoType, workspace: workspace, category: "Video")
        }
        
        // Refresh workspace
        workspace.noteFileSystemChanged()
        
        checkDefaultHandlerStatus()
        
        Logger.shared.info("File associations registration completed", category: .system)
    }
    
    private func registerType(_ type: UTType, workspace: NSWorkspace, category: String) {
        guard let bundleID = Bundle.main.bundleIdentifier,
              let extension = type.preferredFilenameExtension else {
            return
        }
        
        // Create a temporary file to test association
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.\(extension)")
        
        do {
            try "test".write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Attempt to set as default handler
            try workspace.setDefaultApplication(at: Bundle.main.bundleURL, toOpenContentType: type)
            
            Logger.shared.info("Registered as handler for .\(extension) (\(category))", category: .system)
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
        } catch {
            Logger.shared.warning("Failed to register handler for .\(extension): \(error)", category: .system)
        }
    }
    
    // MARK: - File Opening
    
    func canHandleFile(_ url: URL) -> Bool {
        let fileExtension = url.pathExtension.lowercased()
        return supportedAudioExtensions.contains(fileExtension) || supportedVideoExtensions.contains(fileExtension)
    }
    
    func handleFileOpen(_ url: URL) {
        guard canHandleFile(url) else {
            Logger.shared.warning("Cannot handle file type: \(url.pathExtension)", category: .fileSystem)
            showUnsupportedFileAlert(url)
            return
        }
        
        Logger.shared.info("Handling file open: \(url.path)", category: .fileSystem)
        
        // Determine if it's audio or video
        let isAudio = supportedAudioExtensions.contains(url.pathExtension.lowercased())
        let isVideo = supportedVideoExtensions.contains(url.pathExtension.lowercased())
        
        if isVideo {
            // For video files, show extraction option
            showVideoHandlingOptions(url)
        } else if isAudio {
            // For audio files, go directly to transcription
            openTranscriptionWorkflow(url)
        }
    }
    
    private func showVideoHandlingOptions(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = "Video File Detected"
        alert.informativeText = "WhisperLocal can extract audio from \(url.lastPathComponent) and then transcribe it. Would you like to proceed?"
        alert.alertStyle = .informational
        
        alert.addButton(withTitle: "Extract & Transcribe")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openVideoExtractionWorkflow(url)
        }
    }
    
    private func openTranscriptionWorkflow(_ url: URL) {
        // Activate the app and show transcription view
        NSApp.activate(ignoringOtherApps: true)
        
        // Post notification to open transcription workflow
        NotificationCenter.default.post(
            name: .openTranscriptionWorkflow,
            object: nil,
            userInfo: ["fileURL": url]
        )
        
        Logger.shared.info("Opening transcription workflow for: \(url.lastPathComponent)", category: .workflow)
    }
    
    private func openVideoExtractionWorkflow(_ url: URL) {
        // Activate the app and show video extraction view
        NSApp.activate(ignoringOtherApps: true)
        
        // Post notification to open video extraction workflow
        NotificationCenter.default.post(
            name: .openVideoExtractionWorkflow,
            object: nil,
            userInfo: ["fileURL": url]
        )
        
        Logger.shared.info("Opening video extraction workflow for: \(url.lastPathComponent)", category: .workflow)
    }
    
    private func showUnsupportedFileAlert(_ url: URL) {
        let alert = NSAlert()
        alert.messageText = "Unsupported File Type"
        alert.informativeText = "WhisperLocal cannot process .\(url.pathExtension) files. Supported formats are: \(getSupportedFormatsString())"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func getSupportedFormatsString() -> String {
        let allExtensions = supportedAudioExtensions + supportedVideoExtensions
        return allExtensions.map { ".\($0)" }.joined(separator: ", ")
    }
    
    // MARK: - Context Menu Integration
    
    func addContextMenuSupport() {
        // Register for Finder context menu integration
        let workspace = NSWorkspace.shared
        
        // This would typically be done via Info.plist configuration
        // but we can also register dynamically for supported file types
        for type in supportedAudioTypes + supportedVideoTypes {
            if let extension = type.preferredFilenameExtension {
                Logger.shared.debug("Context menu support added for .\(extension)", category: .system)
            }
        }
    }
    
    // MARK: - Spotlight Integration Support
    
    func getSupportedUTTypes() -> [UTType] {
        return supportedAudioTypes + supportedVideoTypes
    }
    
    func getFileTypeCategories() -> [String: [String]] {
        return [
            "Audio": supportedAudioExtensions,
            "Video": supportedVideoExtensions
        ]
    }
}

// MARK: - Notification Extensions

extension NSNotification.Name {
    static let openTranscriptionWorkflow = NSNotification.Name("OpenTranscriptionWorkflow")
    static let openVideoExtractionWorkflow = NSNotification.Name("OpenVideoExtractionWorkflow")
}

// MARK: - App Delegate Integration

extension FileAssociationManager {
    
    func setupAppDelegateIntegration() {
        // Register for application events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidFinishLaunching),
            name: NSApplication.didFinishLaunchingNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidFinishLaunching() {
        // Setup file associations when app launches
        registerFileAssociations()
        addContextMenuSupport()
        
        Logger.shared.info("File association manager setup completed", category: .system)
    }
    
    func handleApplicationOpenFiles(_ urls: [URL]) {
        Logger.shared.info("Application opened with \(urls.count) files", category: .fileSystem)
        
        for url in urls {
            handleFileOpen(url)
        }
    }
}

// MARK: - Info.plist Helper

extension FileAssociationManager {
    
    func generateInfoPlistDocumentTypes() -> [[String: Any]] {
        var documentTypes: [[String: Any]] = []
        
        // Audio document type
        let audioType: [String: Any] = [
            "CFBundleTypeName": "Audio File",
            "CFBundleTypeRole": "Editor",
            "CFBundleTypeIconFile": "AudioFileIcon",
            "LSHandlerRank": "Default",
            "CFBundleTypeExtensions": supportedAudioExtensions,
            "UTTypeConformsTo": ["public.audio"]
        ]
        documentTypes.append(audioType)
        
        // Video document type
        let videoType: [String: Any] = [
            "CFBundleTypeName": "Video File",
            "CFBundleTypeRole": "Editor", 
            "CFBundleTypeIconFile": "VideoFileIcon",
            "LSHandlerRank": "Default",
            "CFBundleTypeExtensions": supportedVideoExtensions,
            "UTTypeConformsTo": ["public.movie"]
        ]
        documentTypes.append(videoType)
        
        Logger.shared.debug("Generated Info.plist document types: \(documentTypes.count) types", category: .system)
        
        return documentTypes
    }
    
    func logCurrentFileAssociations() {
        Logger.shared.info("=== Current File Associations ===", category: .system)
        Logger.shared.info("Supported Audio: \(supportedAudioExtensions.joined(separator: ", "))", category: .system)
        Logger.shared.info("Supported Video: \(supportedVideoExtensions.joined(separator: ", "))", category: .system)
        Logger.shared.info("Registered as default handler: \(isRegisteredAsDefaultHandler)", category: .system)
        Logger.shared.info("================================", category: .system)
    }
}
import Foundation
import AppKit
import Quartz

@MainActor
class QuickLookManager: NSObject, ObservableObject {
    static let shared = QuickLookManager()
    
    @Published var isQuickLookSupported: Bool = false
    
    private override init() {
        super.init()
        setupQuickLookSupport()
    }
    
    // MARK: - Quick Look Setup
    
    private func setupQuickLookSupport() {
        // Check if QuickLook is available
        isQuickLookSupported = QLPreviewPanel.sharedPreviewPanelExists()
        
        // Register for Quick Look notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(quickLookPanelWillOpen),
            name: NSNotification.Name("QLPreviewPanelWillOpenNotification"),
            object: nil
        )
        
        Logger.shared.info("Quick Look support initialized: \(isQuickLookSupported)", category: .system)
    }
    
    @objc private func quickLookPanelWillOpen() {
        Logger.shared.info("Quick Look panel opening", category: .ui)
    }
    
    // MARK: - Quick Look Preview
    
    func showQuickLookPreview(for urls: [URL], from sourceView: NSView) {
        guard !urls.isEmpty else {
            Logger.shared.warning("No URLs provided for Quick Look preview", category: .ui)
            return
        }
        
        // Filter for supported transcription files
        let supportedURLs = urls.filter { isTranscriptionFile($0) }
        
        guard !supportedURLs.isEmpty else {
            Logger.shared.warning("No supported transcription files for Quick Look", category: .ui)
            return
        }
        
        let panel = QLPreviewPanel.shared()
        
        // Set up the preview panel
        panel?.delegate = self
        panel?.dataSource = QuickLookDataSource(urls: supportedURLs)
        
        // Show the panel
        if let panel = panel {
            panel.makeKeyAndOrderFront(nil)
            Logger.shared.info("Quick Look panel opened with \(supportedURLs.count) files", category: .ui)
        }
    }
    
    func canPreviewFile(_ url: URL) -> Bool {
        return isTranscriptionFile(url) && FileManager.default.fileExists(atPath: url.path)
    }
    
    private func isTranscriptionFile(_ url: URL) -> Bool {
        let supportedExtensions = ["txt", "srt", "vtt", "json"]
        return supportedExtensions.contains(url.pathExtension.lowercased())
    }
    
    // MARK: - Transcription Content Enhancement
    
    func enhanceTranscriptionForQuickLook(_ url: URL) throws -> URL {
        guard isTranscriptionFile(url) else {
            throw QuickLookError.unsupportedFileType
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        let enhancedContent = createEnhancedTranscriptionContent(content, originalURL: url)
        
        // Create temporary enhanced file for Quick Look
        let tempDirectory = FileManager.default.temporaryDirectory
        let enhancedURL = tempDirectory.appendingPathComponent("quicklook_\(url.lastPathComponent)")
        
        try enhancedContent.write(to: enhancedURL, atomically: true, encoding: .utf8)
        
        Logger.shared.info("Enhanced transcription file created for Quick Look: \(enhancedURL.path)", category: .system)
        
        return enhancedURL
    }
    
    private func createEnhancedTranscriptionContent(_ content: String, originalURL: URL) -> String {
        var enhanced = """
        # Transcription: \(originalURL.lastPathComponent)
        
        **File**: \(originalURL.path)
        **Generated**: \(Date().formatted())
        **Type**: \(originalURL.pathExtension.uppercased()) Transcription
        
        ---
        
        """
        
        switch originalURL.pathExtension.lowercased() {
        case "srt":
            enhanced += formatSRTForQuickLook(content)
        case "vtt":
            enhanced += formatVTTForQuickLook(content)
        case "json":
            enhanced += formatJSONForQuickLook(content)
        default:
            enhanced += content
        }
        
        return enhanced
    }
    
    private func formatSRTForQuickLook(_ content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        var formatted = "## SRT Subtitle File\n\n"
        
        var currentSubtitle: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if trimmed.isEmpty {
                if !currentSubtitle.isEmpty {
                    formatted += formatSRTSubtitle(currentSubtitle)
                    currentSubtitle.removeAll()
                }
            } else {
                currentSubtitle.append(trimmed)
            }
        }
        
        // Handle last subtitle if file doesn't end with newline
        if !currentSubtitle.isEmpty {
            formatted += formatSRTSubtitle(currentSubtitle)
        }
        
        return formatted
    }
    
    private func formatSRTSubtitle(_ subtitle: [String]) -> String {
        guard subtitle.count >= 3 else { return "" }
        
        let index = subtitle[0]
        let timestamp = subtitle[1]
        let text = subtitle[2...].joined(separator: " ")
        
        return """
        **\(index)** | `\(timestamp)`
        \(text)
        
        
        """
    }
    
    private func formatVTTForQuickLook(_ content: String) -> String {
        return "## WebVTT Subtitle File\n\n```\n\(content)\n```"
    }
    
    private func formatJSONForQuickLook(_ content: String) -> String {
        // Try to pretty-print JSON
        if let data = content.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            return "## JSON Transcription Data\n\n```json\n\(prettyString)\n```"
        }
        
        return "## JSON Transcription Data\n\n```json\n\(content)\n```"
    }
}

// MARK: - Quick Look Panel Delegate

extension QuickLookManager: QLPreviewPanelDelegate {
    
    func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
        // Handle keyboard shortcuts in Quick Look
        if event.type == .keyDown {
            switch event.keyCode {
            case 53: // Escape key
                panel.orderOut(nil)
                return true
            default:
                break
            }
        }
        return false
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: QLPreviewItem!) -> NSRect {
        // Return the frame for animation
        return NSRect.zero
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, transitionImageFor item: QLPreviewItem!, contentRect: UnsafeMutablePointer<NSRect>!) -> Any! {
        // Return transition image for smooth animation
        return nil
    }
}

// MARK: - Quick Look Data Source

class QuickLookDataSource: NSObject, QLPreviewPanelDataSource {
    private let urls: [URL]
    private var enhancedURLs: [URL] = []
    
    init(urls: [URL]) {
        self.urls = urls
        super.init()
        prepareEnhancedURLs()
    }
    
    private func prepareEnhancedURLs() {
        let manager = QuickLookManager.shared
        enhancedURLs = urls.compactMap { url in
            do {
                return try manager.enhanceTranscriptionForQuickLook(url)
            } catch {
                Logger.shared.error("Failed to enhance file for Quick Look: \(error)", category: .system)
                return url // Fallback to original URL
            }
        }
    }
    
    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        return enhancedURLs.count
    }
    
    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
        guard index >= 0 && index < enhancedURLs.count else { return nil }
        return enhancedURLs[index] as QLPreviewItem
    }
}

// MARK: - Quick Look Error Types

enum QuickLookError: LocalizedError {
    case unsupportedFileType
    case fileNotFound
    case enhancementFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unsupportedFileType:
            return "File type not supported for Quick Look preview"
        case .fileNotFound:
            return "File not found for Quick Look preview"
        case .enhancementFailed(let message):
            return "Failed to enhance file for Quick Look: \(message)"
        }
    }
}
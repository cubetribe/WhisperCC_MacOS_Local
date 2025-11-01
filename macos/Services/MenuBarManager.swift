import Foundation
import AppKit
import SwiftUI

@MainActor
class MenuBarManager: ObservableObject {
    static let shared = MenuBarManager()
    
    @Published var isMenuBarItemVisible: Bool = true
    @Published var currentStatus: MenuBarStatus = .idle
    @Published var quickTranscriptionEnabled: Bool = false
    
    private var statusItem: NSStatusItem?
    private var performanceManager = PerformanceManager.shared
    private var pythonBridge: PythonBridge?
    
    enum MenuBarStatus {
        case idle
        case transcribing(progress: Double)
        case batchProcessing(completed: Int, total: Int)
        case error(String)
        
        var title: String {
            switch self {
            case .idle:
                return "WL"
            case .transcribing(let progress):
                return "\(Int(progress * 100))%"
            case .batchProcessing(let completed, let total):
                return "\(completed)/\(total)"
            case .error:
                return "!"
            }
        }
        
        var tooltip: String {
            switch self {
            case .idle:
                return "WhisperLocal - Ready"
            case .transcribing(let progress):
                return "Transcribing... \(Int(progress * 100))%"
            case .batchProcessing(let completed, let total):
                return "Batch Processing: \(completed) of \(total) files"
            case .error(let message):
                return "Error: \(message)"
            }
        }
    }
    
    private init() {
        setupMenuBarItem()
        observePerformanceChanges()
    }
    
    deinit {
        removeMenuBarItem()
    }
    
    // MARK: - Menu Bar Setup
    
    private func setupMenuBarItem() {
        guard statusItem == nil else { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.title = currentStatus.title
            button.toolTip = currentStatus.tooltip
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        
        updateMenuBarMenu()
    }
    
    private func removeMenuBarItem() {
        if let statusItem = statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }
    
    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }
        
        if event.type == .rightMouseUp {
            // Right click - show context menu
            showContextMenu()
        } else {
            // Left click - show main window or quick actions
            if NSEvent.modifierFlags.contains(.option) {
                showQuickTranscriptionDialog()
            } else {
                showMainWindow()
            }
        }
    }
    
    private func updateMenuBarMenu() {
        let menu = NSMenu()
        
        // Status section
        let statusMenuItem = NSMenuItem(title: currentStatus.tooltip, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(NSMenuItem.separator())
        
        // Quick actions
        if quickTranscriptionEnabled {
            let quickTranscribeItem = NSMenuItem(
                title: "Quick Transcribe...",
                action: #selector(showQuickTranscriptionDialog),
                keyEquivalent: "t"
            )
            quickTranscribeItem.target = self
            menu.addItem(quickTranscribeItem)
            menu.addItem(NSMenuItem.separator())
        }
        
        // Performance info
        let performanceItem = NSMenuItem(title: "System Performance", action: nil, keyEquivalent: "")
        let performanceSubmenu = NSMenu()
        
        let cpuItem = NSMenuItem(
            title: "CPU Usage: \(performanceManager.cpuUsage, specifier: "%.1f")%",
            action: nil,
            keyEquivalent: ""
        )
        cpuItem.isEnabled = false
        performanceSubmenu.addItem(cpuItem)
        
        let memoryItem = NSMenuItem(
            title: "Memory Usage: \(performanceManager.memoryUsage, specifier: "%.1f")%",
            action: nil,
            keyEquivalent: ""
        )
        memoryItem.isEnabled = false
        performanceSubmenu.addItem(memoryItem)
        
        let thermalItem = NSMenuItem(
            title: "Thermal State: \(performanceManager.thermalState.rawValue)",
            action: nil,
            keyEquivalent: ""
        )
        thermalItem.isEnabled = false
        performanceSubmenu.addItem(thermalItem)
        
        performanceItem.submenu = performanceSubmenu
        menu.addItem(performanceItem)
        menu.addItem(NSMenuItem.separator())
        
        // Main actions
        let showMainWindowItem = NSMenuItem(
            title: "Show Main Window",
            action: #selector(showMainWindow),
            keyEquivalent: "m"
        )
        showMainWindowItem.target = self
        menu.addItem(showMainWindowItem)
        
        let preferencesItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(showPreferences),
            keyEquivalent: ","
        )
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(
            title: "Quit WhisperLocal",
            action: #selector(quitApplication),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Status Updates
    
    func updateStatus(_ status: MenuBarStatus) {
        currentStatus = status
        
        if let button = statusItem?.button {
            button.title = status.title
            button.toolTip = status.tooltip
            
            // Update appearance based on status
            switch status {
            case .idle:
                button.appearsDisabled = false
            case .transcribing, .batchProcessing:
                button.appearsDisabled = false
            case .error:
                button.appearsDisabled = true
            }
        }
        
        updateMenuBarMenu()
    }
    
    func updateTranscriptionProgress(_ progress: Double) {
        updateStatus(.transcribing(progress: progress))
    }
    
    func updateBatchProgress(completed: Int, total: Int) {
        updateStatus(.batchProcessing(completed: completed, total: total))
    }
    
    func showError(_ message: String) {
        updateStatus(.error(message))
        
        // Auto-clear error after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            if case .error = self?.currentStatus {
                self?.updateStatus(.idle)
            }
        }
    }
    
    func clearStatus() {
        updateStatus(.idle)
    }
    
    // MARK: - Performance Monitoring
    
    private func observePerformanceChanges() {
        // Observe performance manager changes
        performanceManager.$thermalState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] thermalState in
                self?.updateMenuBarMenu()
                
                // Show warning for serious thermal states
                if thermalState.shouldThrottle {
                    self?.showThermalWarning(thermalState)
                }
            }
            .store(in: &cancellables)
        
        performanceManager.$cpuUsage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarMenu()
            }
            .store(in: &cancellables)
        
        performanceManager.$memoryUsage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMenuBarMenu()
            }
            .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    private func showThermalWarning(_ thermalState: PerformanceManager.ThermalState) {
        let notification = NSUserNotification()
        notification.title = "System Running Hot"
        notification.informativeText = thermalState.description + ". Performance may be automatically reduced."
        notification.soundName = NSUserNotificationDefaultSoundName
        
        NSUserNotificationCenter.default.deliver(notification)
    }
    
    // MARK: - Menu Actions
    
    @objc private func showMainWindow() {
        // Activate the app and show main window
        NSApp.activate(ignoringOtherApps: true)
        
        // Find and show the main window
        if let mainWindow = NSApp.windows.first(where: { $0.title.contains("WhisperLocal") || $0.isMainWindow }) {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            // Create new window if none exists
            Logger.shared.info("Creating new main window from menu bar", category: .ui)
        }
    }
    
    @objc private func showPreferences() {
        // Show preferences window
        NSApp.activate(ignoringOtherApps: true)
        Logger.shared.info("Opening preferences from menu bar", category: .ui)
    }
    
    @objc private func showQuickTranscriptionDialog() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .movie]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.title = "Quick Transcribe Audio/Video File"
        panel.message = "Select an audio or video file to transcribe with default settings"
        
        panel.begin { [weak self] response in
            if response == .OK, let url = panel.url {
                self?.performQuickTranscription(url: url)
            }
        }
    }
    
    private func performQuickTranscription(url: URL) {
        guard let pythonBridge = pythonBridge else {
            showError("Python bridge not available")
            return
        }
        
        Task {
            do {
                updateStatus(.transcribing(progress: 0.0))
                
                // Create a quick transcription task with default settings
                let task = TranscriptionTask(
                    inputURL: url,
                    outputDirectory: FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? url.deletingLastPathComponent(),
                    model: "large-v3-turbo",
                    formats: [.txt, .srt]
                )
                
                let result = try await pythonBridge.transcribeFile(task)
                
                clearStatus()
                
                // Show completion notification
                pythonBridge.showCompletionNotification(
                    title: "Quick Transcription Complete",
                    body: "File: \(url.lastPathComponent)",
                    isSuccess: result.isSuccess
                )
                
                // Open results folder
                if result.isSuccess, let outputURL = result.outputFiles.first {
                    NSWorkspace.shared.selectFile(outputURL.path, inFileViewerRootedAtPath: outputURL.deletingLastPathComponent().path)
                }
                
            } catch {
                showError("Transcription failed")
                Logger.shared.error("Quick transcription failed: \(error)", category: .transcription)
            }
        }
    }
    
    private func showContextMenu() {
        updateMenuBarMenu()
    }
    
    @objc private func quitApplication() {
        NSApp.terminate(nil)
    }
    
    // MARK: - Configuration
    
    func configurePythonBridge(_ bridge: PythonBridge) {
        self.pythonBridge = bridge
        
        // Observe bridge status changes
        bridge.$isProcessing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isProcessing in
                if !isProcessing {
                    self?.clearStatus()
                }
            }
            .store(in: &cancellables)
        
        bridge.$currentProgress
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                if progress > 0.0 && progress < 1.0 {
                    self?.updateTranscriptionProgress(progress)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Visibility Control
    
    func setMenuBarItemVisible(_ visible: Bool) {
        isMenuBarItemVisible = visible
        
        if visible && statusItem == nil {
            setupMenuBarItem()
        } else if !visible && statusItem != nil {
            removeMenuBarItem()
        }
    }
    
    func setQuickTranscriptionEnabled(_ enabled: Bool) {
        quickTranscriptionEnabled = enabled
        updateMenuBarMenu()
    }
}

import Combine
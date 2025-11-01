import Foundation
import SwiftUI
import IOKit.ps

@MainActor
class ResourceMonitor: ObservableObject {
    static let shared = ResourceMonitor()
    
    @Published var memoryUsage: Double = 0.0
    @Published var diskSpaceAvailable: Int64 = 0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var resourceStatus: ResourceStatus = .optimal
    @Published var activeWarnings: [ResourceWarning] = []
    
    private var monitoringTimer: Timer?
    private var warningTimer: Timer?
    
    // Resource thresholds
    private let memoryWarningThreshold: Double = 80.0  // 80% memory usage
    private let memoryCriticalThreshold: Double = 90.0 // 90% memory usage
    private let diskSpaceMinimumGB: Int64 = 2          // Minimum 2GB free space
    private let diskSpaceWarningGB: Int64 = 5          // Warning at 5GB free space
    
    enum ResourceStatus: String, CaseIterable {
        case optimal = "Optimal"
        case warning = "Warning"
        case critical = "Critical"
        
        var color: String {
            switch self {
            case .optimal: return "green"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
        
        var description: String {
            switch self {
            case .optimal: return "System resources are optimal for transcription"
            case .warning: return "System resources are under pressure - consider reducing workload"
            case .critical: return "System resources critically low - transcription may fail"
            }
        }
    }
    
    private init() {
        startMonitoring()
        Logger.shared.info("Resource monitor initialized", category: .performance)
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Resource Monitoring
    
    func startMonitoring() {
        // Update resource metrics every 5 seconds
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateResourceMetrics()
            }
        }
        
        // Check for warnings every 10 seconds
        warningTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkResourceWarnings()
            }
        }
        
        // Initial update
        updateResourceMetrics()
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        warningTimer?.invalidate()
        monitoringTimer = nil
        warningTimer = nil
    }
    
    private func updateResourceMetrics() {
        // Update memory usage
        memoryUsage = getMemoryUsage()
        
        // Update disk space
        diskSpaceAvailable = getDiskSpaceAvailable()
        
        // Update thermal state
        thermalState = ProcessInfo.processInfo.thermalState
        
        // Determine overall resource status
        resourceStatus = calculateResourceStatus()
        
        Logger.shared.debug("Resource update - Memory: \(memoryUsage)%, Disk: \(diskSpaceAvailable)GB, Thermal: \(thermalState)", category: .performance)
    }
    
    private func calculateResourceStatus() -> ResourceStatus {
        // Critical conditions
        if memoryUsage >= memoryCriticalThreshold ||
           diskSpaceAvailable < diskSpaceMinimumGB * 1024 * 1024 * 1024 ||
           thermalState == .critical {
            return .critical
        }
        
        // Warning conditions
        if memoryUsage >= memoryWarningThreshold ||
           diskSpaceAvailable < diskSpaceWarningGB * 1024 * 1024 * 1024 ||
           thermalState == .serious {
            return .warning
        }
        
        return .optimal
    }
    
    // MARK: - System Metrics
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let totalMemory = ProcessInfo.processInfo.physicalMemory
            let usedMemory = UInt64(info.resident_size)
            return Double(usedMemory) / Double(totalMemory) * 100.0
        }
        
        return 0.0
    }
    
    private func getDiskSpaceAvailable() -> Int64 {
        do {
            let homeURL = FileManager.default.homeDirectoryForCurrentUser
            let resourceValues = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            
            if let availableCapacity = resourceValues.volumeAvailableCapacityForImportantUsage {
                return availableCapacity
            }
        } catch {
            Logger.shared.error("Failed to get disk space: \(error)", category: .performance)
        }
        
        return 0
    }
    
    // MARK: - Resource Checking
    
    func checkResourcesBeforeProcessing(_ fileSize: Int64) -> ResourceCheckResult {
        let requiredDiskSpace = fileSize * 2 // Require 2x file size free space
        let availableDiskSpace = getDiskSpaceAvailable()
        let currentMemoryUsage = getMemoryUsage()
        let currentThermalState = ProcessInfo.processInfo.thermalState
        
        var issues: [String] = []
        var warnings: [String] = []
        
        // Check disk space
        if availableDiskSpace < requiredDiskSpace {
            let requiredGB = Double(requiredDiskSpace) / (1024 * 1024 * 1024)
            let availableGB = Double(availableDiskSpace) / (1024 * 1024 * 1024)
            issues.append("Insufficient disk space. Required: \(String(format: "%.1f", requiredGB))GB, Available: \(String(format: "%.1f", availableGB))GB")
        } else if availableDiskSpace < diskSpaceWarningGB * 1024 * 1024 * 1024 {
            let availableGB = Double(availableDiskSpace) / (1024 * 1024 * 1024)
            warnings.append("Low disk space: \(String(format: "%.1f", availableGB))GB available")
        }
        
        // Check memory usage
        if currentMemoryUsage >= memoryCriticalThreshold {
            issues.append("Critical memory usage: \(String(format: "%.1f", currentMemoryUsage))%")
        } else if currentMemoryUsage >= memoryWarningThreshold {
            warnings.append("High memory usage: \(String(format: "%.1f", currentMemoryUsage))%")
        }
        
        // Check thermal state
        switch currentThermalState {
        case .critical:
            issues.append("System critically hot - processing may fail")
        case .serious:
            warnings.append("System running hot - performance may be reduced")
        case .fair:
            warnings.append("System under thermal pressure")
        case .nominal:
            break
        @unknown default:
            break
        }
        
        let canProceed = issues.isEmpty
        let shouldProceedWithCaution = !canProceed && warnings.isEmpty
        
        return ResourceCheckResult(
            canProceed: canProceed,
            shouldProceedWithCaution: shouldProceedWithCaution,
            issues: issues,
            warnings: warnings,
            estimatedDiskUsage: requiredDiskSpace,
            availableDiskSpace: availableDiskSpace
        )
    }
    
    func checkResourcesForBatchProcessing(_ totalFileSize: Int64, fileCount: Int) -> ResourceCheckResult {
        // For batch processing, be more conservative
        let requiredDiskSpace = totalFileSize * 3 // Require 3x total file size
        let baseResult = checkResourcesBeforeProcessing(requiredDiskSpace)
        
        var enhancedWarnings = baseResult.warnings
        var enhancedIssues = baseResult.issues
        
        // Additional batch-specific checks
        if fileCount > 5 && memoryUsage > 70.0 {
            enhancedWarnings.append("Batch processing \(fileCount) files with high memory usage may be slow")
        }
        
        if fileCount > 10 && thermalState != .nominal {
            enhancedWarnings.append("Large batch (\(fileCount) files) with thermal pressure detected")
        }
        
        return ResourceCheckResult(
            canProceed: enhancedIssues.isEmpty,
            shouldProceedWithCaution: !enhancedIssues.isEmpty && enhancedWarnings.isEmpty,
            issues: enhancedIssues,
            warnings: enhancedWarnings,
            estimatedDiskUsage: requiredDiskSpace,
            availableDiskSpace: diskSpaceAvailable
        )
    }
    
    // MARK: - Warning Management
    
    private func checkResourceWarnings() {
        var newWarnings: [ResourceWarning] = []
        
        // Memory warnings
        if memoryUsage >= memoryCriticalThreshold {
            newWarnings.append(ResourceWarning(
                type: .memory,
                severity: .critical,
                message: "Critical memory usage: \(String(format: "%.1f", memoryUsage))%",
                recommendation: "Close other applications or restart the system"
            ))
        } else if memoryUsage >= memoryWarningThreshold {
            newWarnings.append(ResourceWarning(
                type: .memory,
                severity: .warning,
                message: "High memory usage: \(String(format: "%.1f", memoryUsage))%",
                recommendation: "Consider processing fewer files simultaneously"
            ))
        }
        
        // Disk space warnings
        let diskSpaceGB = Double(diskSpaceAvailable) / (1024 * 1024 * 1024)
        if diskSpaceAvailable < diskSpaceMinimumGB * 1024 * 1024 * 1024 {
            newWarnings.append(ResourceWarning(
                type: .diskSpace,
                severity: .critical,
                message: "Critically low disk space: \(String(format: "%.1f", diskSpaceGB))GB",
                recommendation: "Free up disk space before continuing"
            ))
        } else if diskSpaceAvailable < diskSpaceWarningGB * 1024 * 1024 * 1024 {
            newWarnings.append(ResourceWarning(
                type: .diskSpace,
                severity: .warning,
                message: "Low disk space: \(String(format: "%.1f", diskSpaceGB))GB",
                recommendation: "Monitor disk space during transcription"
            ))
        }
        
        // Thermal warnings
        switch thermalState {
        case .critical:
            newWarnings.append(ResourceWarning(
                type: .thermal,
                severity: .critical,
                message: "System critically hot",
                recommendation: "Stop processing and let system cool down"
            ))
        case .serious:
            newWarnings.append(ResourceWarning(
                type: .thermal,
                severity: .warning,
                message: "System running hot",
                recommendation: "Reduce processing intensity or take breaks"
            ))
        case .fair:
            newWarnings.append(ResourceWarning(
                type: .thermal,
                severity: .info,
                message: "System under thermal pressure",
                recommendation: "Monitor system temperature"
            ))
        default:
            break
        }
        
        // Update warnings and show notifications for new critical warnings
        let previousCriticalCount = activeWarnings.filter { $0.severity == .critical }.count
        activeWarnings = newWarnings
        let currentCriticalCount = newWarnings.filter { $0.severity == .critical }.count
        
        if currentCriticalCount > previousCriticalCount {
            showResourceWarningNotification(newWarnings.filter { $0.severity == .critical })
        }
    }
    
    private func showResourceWarningNotification(_ criticalWarnings: [ResourceWarning]) {
        guard !criticalWarnings.isEmpty else { return }
        
        let message = criticalWarnings.map { $0.message }.joined(separator: ", ")
        
        let pythonBridge = PythonBridge()
        pythonBridge.showCompletionNotification(
            title: "System Resource Warning",
            body: message,
            isSuccess: false
        )
        
        Logger.shared.warning("Critical resource warnings: \(message)", category: .performance)
    }
    
    // MARK: - Resource Statistics
    
    func getResourceStatistics() -> ResourceStatistics {
        let totalMemoryGB = Double(ProcessInfo.processInfo.physicalMemory) / (1024 * 1024 * 1024)
        let usedMemoryGB = totalMemoryGB * (memoryUsage / 100.0)
        let diskSpaceGB = Double(diskSpaceAvailable) / (1024 * 1024 * 1024)
        
        return ResourceStatistics(
            memoryUsagePercentage: memoryUsage,
            totalMemoryGB: totalMemoryGB,
            usedMemoryGB: usedMemoryGB,
            availableDiskSpaceGB: diskSpaceGB,
            thermalState: thermalState,
            resourceStatus: resourceStatus,
            activeWarnings: activeWarnings.count,
            canProcessLargeFiles: resourceStatus != .critical && diskSpaceGB > 5.0
        )
    }
    
    func getOptimalBatchSizeRecommendation() -> Int {
        switch resourceStatus {
        case .optimal:
            return memoryUsage < 50 ? 5 : 3
        case .warning:
            return 2
        case .critical:
            return 1
        }
    }
}

// MARK: - Supporting Types

struct ResourceCheckResult {
    let canProceed: Bool
    let shouldProceedWithCaution: Bool
    let issues: [String]
    let warnings: [String]
    let estimatedDiskUsage: Int64
    let availableDiskSpace: Int64
    
    var summary: String {
        if !canProceed {
            return "Cannot proceed: \(issues.joined(separator: ", "))"
        } else if !warnings.isEmpty {
            return "Proceed with caution: \(warnings.joined(separator: ", "))"
        } else {
            return "Resources available for processing"
        }
    }
    
    var diskSpaceAfterProcessing: Int64 {
        return availableDiskSpace - estimatedDiskUsage
    }
    
    var diskSpaceAfterProcessingGB: Double {
        return Double(diskSpaceAfterProcessing) / (1024 * 1024 * 1024)
    }
}

struct ResourceWarning: Identifiable, Equatable {
    let id = UUID()
    let type: WarningType
    let severity: WarningSeverity
    let message: String
    let recommendation: String
    let timestamp: Date = Date()
    
    enum WarningType {
        case memory, diskSpace, thermal
    }
    
    enum WarningSeverity {
        case info, warning, critical
        
        var color: String {
            switch self {
            case .info: return "blue"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
    }
    
    static func == (lhs: ResourceWarning, rhs: ResourceWarning) -> Bool {
        return lhs.type == rhs.type && lhs.severity == rhs.severity && lhs.message == rhs.message
    }
}

struct ResourceStatistics {
    let memoryUsagePercentage: Double
    let totalMemoryGB: Double
    let usedMemoryGB: Double
    let availableDiskSpaceGB: Double
    let thermalState: ProcessInfo.ThermalState
    let resourceStatus: ResourceMonitor.ResourceStatus
    let activeWarnings: Int
    let canProcessLargeFiles: Bool
    
    var formattedMemoryUsage: String {
        return "\(String(format: "%.1f", usedMemoryGB)) / \(String(format: "%.1f", totalMemoryGB)) GB (\(String(format: "%.1f", memoryUsagePercentage))%)"
    }
    
    var formattedDiskSpace: String {
        return "\(String(format: "%.1f", availableDiskSpaceGB)) GB available"
    }
    
    var thermalStateDescription: String {
        switch thermalState {
        case .nominal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        case .critical: return "Critical"
        @unknown default: return "Unknown"
        }
    }
}
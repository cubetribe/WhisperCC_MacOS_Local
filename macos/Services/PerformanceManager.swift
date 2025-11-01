import Foundation
import MetalPerformanceShaders
import Metal
import IOKit.ps

@MainActor
class PerformanceManager: ObservableObject {
    static let shared = PerformanceManager()
    
    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsage: Double = 0.0
    @Published var thermalState: ThermalState = .nominal
    @Published var isAppleSilicon: Bool = false
    @Published var metalDevice: MTLDevice?
    @Published var isMetalSupported: Bool = false
    
    private var performanceTimer: Timer?
    private var thermalTimer: Timer?
    
    enum ThermalState: String, CaseIterable {
        case nominal = "Nominal"
        case fair = "Fair"
        case serious = "Serious"
        case critical = "Critical"
        
        var systemValue: Int {
            switch self {
            case .nominal: return 0
            case .fair: return 1
            case .serious: return 2
            case .critical: return 3
            }
        }
        
        var description: String {
            switch self {
            case .nominal: return "System running normally"
            case .fair: return "System under moderate thermal pressure"
            case .serious: return "System under high thermal pressure"
            case .critical: return "System critically hot - performance reduced"
            }
        }
        
        var shouldThrottle: Bool {
            return self == .serious || self == .critical
        }
    }
    
    private init() {
        detectHardwareCapabilities()
        startPerformanceMonitoring()
    }
    
    deinit {
        stopPerformanceMonitoring()
    }
    
    // MARK: - Hardware Detection
    
    private func detectHardwareCapabilities() {
        // Check for Apple Silicon
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        
        if let machine = machine {
            isAppleSilicon = machine.contains("arm64") || machine.contains("arm")
            Logger.shared.info("Hardware detected: \(machine), Apple Silicon: \(isAppleSilicon)", category: .performance)
        }
        
        // Initialize Metal
        setupMetal()
    }
    
    private func setupMetal() {
        metalDevice = MTLCreateSystemDefaultDevice()
        isMetalSupported = metalDevice != nil
        
        if let device = metalDevice {
            Logger.shared.info("Metal device available: \(device.name)", category: .performance)
            Logger.shared.info("Metal supports unified memory: \(device.hasUnifiedMemory)", category: .performance)
            Logger.shared.info("Metal max buffer length: \(device.maxBufferLength / 1024 / 1024) MB", category: .performance)
        } else {
            Logger.shared.warning("Metal not available on this system", category: .performance)
        }
    }
    
    // MARK: - Performance Monitoring
    
    func startPerformanceMonitoring() {
        performanceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
        
        thermalTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateThermalState()
            }
        }
    }
    
    func stopPerformanceMonitoring() {
        performanceTimer?.invalidate()
        thermalTimer?.invalidate()
        performanceTimer = nil
        thermalTimer = nil
    }
    
    private func updatePerformanceMetrics() {
        cpuUsage = getCPUUsage()
        memoryUsage = getMemoryUsage()
    }
    
    private func updateThermalState() {
        thermalState = getCurrentThermalState()
    }
    
    // MARK: - System Metrics
    
    private func getCPUUsage() -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)
        
        guard result == KERN_SUCCESS else {
            return 0.0
        }
        
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(numCpuInfo * MemoryLayout<integer_t>.size))
        }
        
        var totalUser: UInt32 = 0
        var totalSystem: UInt32 = 0
        var totalIdle: UInt32 = 0
        
        for i in 0..<Int(numCpus) {
            let cpuInfo = info.advanced(by: i * Int(CPU_STATE_MAX)).pointee
            totalUser += cpuInfo.0
            totalSystem += cpuInfo.1
            totalIdle += cpuInfo.2
        }
        
        let total = totalUser + totalSystem + totalIdle
        guard total > 0 else { return 0.0 }
        
        return Double(totalUser + totalSystem) / Double(total) * 100.0
    }
    
    private func getMemoryUsage() -> Double {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else {
            return 0.0
        }
        
        let pageSize = vm_kernel_page_size
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let usedMemory = UInt64(info.internal_page_count + info.wire_count) * UInt64(pageSize)
        
        return Double(usedMemory) / Double(totalMemory) * 100.0
    }
    
    private func getCurrentThermalState() -> ThermalState {
        let thermalState = ProcessInfo.processInfo.thermalState
        
        switch thermalState {
        case .nominal:
            return .nominal
        case .fair:
            return .fair
        case .serious:
            return .serious
        case .critical:
            return .critical
        @unknown default:
            return .nominal
        }
    }
    
    // MARK: - Optimization Recommendations
    
    func getOptimizationRecommendations() -> [OptimizationRecommendation] {
        var recommendations: [OptimizationRecommendation] = []
        
        // Thermal throttling recommendation
        if thermalState.shouldThrottle {
            recommendations.append(OptimizationRecommendation(
                title: "Thermal Throttling Active",
                description: "System is running hot. Consider reducing batch size or taking breaks between transcriptions.",
                severity: .warning,
                action: .reduceBatchSize
            ))
        }
        
        // High CPU usage recommendation
        if cpuUsage > 80.0 {
            recommendations.append(OptimizationRecommendation(
                title: "High CPU Usage",
                description: "CPU usage is high. Consider closing other applications or using a smaller Whisper model.",
                severity: .info,
                action: .useSmallerModel
            ))
        }
        
        // Memory pressure recommendation
        if memoryUsage > 85.0 {
            recommendations.append(OptimizationRecommendation(
                title: "High Memory Usage",
                description: "Memory pressure detected. Consider processing files individually instead of in batches.",
                severity: .warning,
                action: .processIndividually
            ))
        }
        
        // Apple Silicon optimizations
        if isAppleSilicon && isMetalSupported {
            recommendations.append(OptimizationRecommendation(
                title: "Apple Silicon Optimization Available",
                description: "Your system supports hardware-accelerated transcription. Ensure you're using optimized models.",
                severity: .info,
                action: .useOptimizedModel
            ))
        }
        
        return recommendations
    }
    
    func getOptimalBatchSize() -> Int {
        // Base batch size
        var batchSize = 5
        
        // Reduce batch size based on thermal state
        if thermalState == .critical {
            batchSize = 1
        } else if thermalState == .serious {
            batchSize = 2
        } else if thermalState == .fair {
            batchSize = 3
        }
        
        // Adjust based on memory
        if memoryUsage > 85.0 {
            batchSize = min(batchSize, 2)
        } else if memoryUsage > 70.0 {
            batchSize = min(batchSize, 3)
        }
        
        // Adjust based on CPU usage
        if cpuUsage > 90.0 {
            batchSize = 1
        } else if cpuUsage > 75.0 {
            batchSize = min(batchSize, 2)
        }
        
        return max(1, batchSize)
    }
    
    func getRecommendedModel() -> String {
        let totalMemory = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024) // GB
        
        // Recommendations based on available memory and thermal state
        if thermalState.shouldThrottle || totalMemory < 8 {
            return "base"
        } else if totalMemory < 16 {
            return "small"
        } else if memoryUsage > 70.0 {
            return "medium"
        } else if isAppleSilicon {
            return "large-v3-turbo" // Optimized for Apple Silicon
        } else {
            return "large-v3"
        }
    }
    
    // MARK: - Metal Performance Shaders Integration
    
    func createMetalBuffer(size: Int) -> MTLBuffer? {
        guard let device = metalDevice else {
            Logger.shared.warning("Metal device not available for buffer creation", category: .performance)
            return nil
        }
        
        return device.makeBuffer(length: size, options: .storageModeShared)
    }
    
    func isMetalOptimalForTask(dataSize: Int) -> Bool {
        guard isMetalSupported, let device = metalDevice else {
            return false
        }
        
        // Metal is beneficial for large data processing on Apple Silicon
        return isAppleSilicon && dataSize > 1024 * 1024 && device.hasUnifiedMemory
    }
    
    // MARK: - System Information
    
    func getSystemInfo() -> SystemInfo {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let processorCount = ProcessInfo.processInfo.processorCount
        
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        
        return SystemInfo(
            architecture: machine,
            processorCount: processorCount,
            totalMemory: totalMemory,
            isAppleSilicon: isAppleSilicon,
            metalDeviceName: metalDevice?.name,
            supportsUnifiedMemory: metalDevice?.hasUnifiedMemory ?? false,
            thermalState: thermalState,
            currentCPUUsage: cpuUsage,
            currentMemoryUsage: memoryUsage
        )
    }
}

// MARK: - Supporting Types

struct OptimizationRecommendation {
    let title: String
    let description: String
    let severity: Severity
    let action: RecommendedAction
    
    enum Severity {
        case info, warning, critical
        
        var color: String {
            switch self {
            case .info: return "blue"
            case .warning: return "orange"
            case .critical: return "red"
            }
        }
    }
    
    enum RecommendedAction {
        case reduceBatchSize
        case useSmallerModel
        case processIndividually
        case useOptimizedModel
        case takeBreak
    }
}

struct SystemInfo {
    let architecture: String
    let processorCount: Int
    let totalMemory: UInt64
    let isAppleSilicon: Bool
    let metalDeviceName: String?
    let supportsUnifiedMemory: Bool
    let thermalState: PerformanceManager.ThermalState
    let currentCPUUsage: Double
    let currentMemoryUsage: Double
    
    var totalMemoryGB: String {
        return "\(totalMemory / (1024 * 1024 * 1024)) GB"
    }
    
    var formattedCPUUsage: String {
        return String(format: "%.1f%%", currentCPUUsage)
    }
    
    var formattedMemoryUsage: String {
        return String(format: "%.1f%%", currentMemoryUsage)
    }
}

extension ProcessInfo {
    var machineArchitecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return machine ?? "Unknown"
    }
}
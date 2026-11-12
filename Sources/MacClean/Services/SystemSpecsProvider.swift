import Foundation
import IOKit
import IOKit.ps
import MacCleanKit

public struct SystemHardwareSpecs: Sendable {
    public let modelName: String
    public let chipName: String
    public let osVersion: String
    public let cpuCores: Int
    public let memoryTotal: UInt64
    public let memoryUsed: UInt64
    public let diskTotal: UInt64
    public let diskFree: UInt64
    public let diskPurgeable: UInt64
    public let diskName: String
    public let diskFormat: String
    public let batteryLevel: Int?
    public let isCharging: Bool
    public let uptime: TimeInterval

    public var memoryUsedFraction: Double {
        memoryTotal > 0 ? Double(memoryUsed) / Double(memoryTotal) : 0
    }

    public var diskUsedFraction: Double {
        diskTotal > 0 && diskTotal >= diskFree ? Double(diskTotal - diskFree) / Double(diskTotal) : 0
    }

    public var isLowDiskSpace: Bool {
        diskTotal > 0 && (Double(diskFree) / Double(diskTotal)) < 0.10
    }

    public var diskUsedFormatted: String {
        FileSizeFormatter.format(diskTotal > diskFree ? (diskTotal - diskFree) : 0)
    }

    public var diskPurgeableFormatted: String {
        FileSizeFormatter.format(diskPurgeable)
    }

    public var memoryUsedFormatted: String {
        FileSizeFormatter.format(memoryUsed)
    }

    public var memoryTotalFormatted: String {
        FileSizeFormatter.format(memoryTotal)
    }

    public var diskFreeFormatted: String {
        FileSizeFormatter.format(diskFree)
    }

    public var diskTotalFormatted: String {
        FileSizeFormatter.format(diskTotal)
    }
}

public enum SystemSpecsProvider {
    public static func current() -> SystemHardwareSpecs {
        let model = readModelName()
        let chip = readChipName()
        let os = readOSVersion()
        let cores = ProcessInfo.processInfo.activeProcessorCount
        let totalMem = ProcessInfo.processInfo.physicalMemory
        let usedMem = readUsedMemory()
        let disk = readDiskDetails()
        let battery = readBattery()
        let uptime = ProcessInfo.processInfo.systemUptime

        return SystemHardwareSpecs(
            modelName: model,
            chipName: chip,
            osVersion: os,
            cpuCores: cores,
            memoryTotal: totalMem,
            memoryUsed: usedMem,
            diskTotal: disk.total,
            diskFree: disk.free,
            diskPurgeable: disk.purgeable,
            diskName: disk.name,
            diskFormat: disk.format,
            batteryLevel: battery.level,
            isCharging: battery.isCharging,
            uptime: uptime
        )
    }

    private static func readModelName() -> String {
        let entry = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/product")
        if entry != 0 {
            defer { IOObjectRelease(entry) }
            if let prop = IORegistryEntryCreateCFProperty(entry, "product-name" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Data,
               let name = String(data: prop, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters),
               !name.isEmpty {
                return name
            }
        }

        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname("hw.model", &buffer, &size, nil, 0)
            let raw = buffer.withUnsafeBufferPointer { ptr -> String in
                guard let base = ptr.baseAddress else { return "" }
                return String(cString: base)
            }.trimmingCharacters(in: .whitespacesAndNewlines)
            if !raw.isEmpty { return raw }
        }
        return "Mac"
    }

    private static func readChipName() -> String {
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        if size > 0 {
            var buffer = [CChar](repeating: 0, count: size)
            sysctlbyname("machdep.cpu.brand_string", &buffer, &size, nil, 0)
            let brand = buffer.withUnsafeBufferPointer { ptr -> String in
                guard let base = ptr.baseAddress else { return "" }
                return String(cString: base)
            }.trimmingCharacters(in: .whitespacesAndNewlines)
            if !brand.isEmpty { return brand }
        }
        return "Apple Silicon"
    }

    private static func readOSVersion() -> String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "macOS \(version.majorVersion).\(version.minorVersion)"
    }

    private static func readUsedMemory() -> UInt64 {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return ProcessInfo.processInfo.physicalMemory / 2
        }
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)
        let pages = UInt64(stats.active_count) + UInt64(stats.wire_count) + UInt64(stats.compressor_page_count)
        return pages * UInt64(pageSize)
    }

    private static func readDiskDetails() -> (total: UInt64, free: UInt64, purgeable: UInt64, name: String, format: String) {
        let url = URL(fileURLWithPath: "/")
        let values = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeNameKey,
            .volumeLocalizedFormatDescriptionKey
        ])

        var fs = statfs()
        let statfsSuccess = statfs("/", &fs) == 0
        let statfsTotal = statfsSuccess ? UInt64(fs.f_blocks) * UInt64(fs.f_bsize) : 0
        let statfsFree = statfsSuccess ? UInt64(fs.f_bavail) * UInt64(fs.f_bsize) : 0

        let total = (values?.volumeTotalCapacity).map(UInt64.init) ?? statfsTotal
        let free = (values?.volumeAvailableCapacity).map(UInt64.init) ?? statfsFree
        let important = (values?.volumeAvailableCapacityForImportantUsage).map(UInt64.init) ?? free
        let purgeable = important > free ? (important - free) : 0

        let name = values?.volumeName ?? "Macintosh HD"
        let format = values?.volumeLocalizedFormatDescription ?? "APFS"

        return (total, free, purgeable, name, format)
    }

    private static func readBattery() -> (level: Int?, isCharging: Bool) {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [Any],
              let source = sources.first,
              let desc = IOPSGetPowerSourceDescription(snapshot, source as CFTypeRef)?.takeUnretainedValue() as? [String: Any]
        else {
            return (nil, false)
        }
        let level = desc[kIOPSCurrentCapacityKey] as? Int
        let charging = desc[kIOPSIsChargingKey] as? Bool ?? false
        return (level, charging)
    }
}

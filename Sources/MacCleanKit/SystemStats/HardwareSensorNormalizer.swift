import Foundation

public enum HardwareSensorNormalizer {
    public static let gpuUtilizationKeys = [
        "Device Utilization %",
        "GPU Activity(%)",
        "Renderer Utilization %",
    ]

    public static let batteryTemperatureKeys = [
        "Temperature",
        "VirtualTemperature",
    ]

    public static func gpuUsageFraction(from samples: [[String: NSNumber]]) -> Double? {
        var maximumPercent: Double?

        for sample in samples {
            for key in gpuUtilizationKeys {
                guard let number = sample[key] else { continue }
                let percent = number.doubleValue
                guard percent.isFinite else { continue }
                maximumPercent = max(maximumPercent ?? 0, min(max(percent, 0), 100))
            }
        }

        return maximumPercent.map { $0 / 100 }
    }

    public static let batteryTemperatureServiceClasses = [
        "AppleSmartBattery",
        "AppleSmartBatteryPack",
    ]

    public static func readBatteryTemperature(
        loadProperties: (String) -> [[String: Any]]
    ) -> Double? {
        for serviceClass in batteryTemperatureServiceClasses {
            for properties in loadProperties(serviceClass) {
                let directValues = properties.compactMapValues { $0 as? NSNumber }
                if let temperature = batteryTemperatureCelsius(from: directValues) {
                    return temperature
                }
                if let batteryData = properties["BatteryData"] as? [String: Any],
                   let temperature = batteryDataTemperatureCelsius(from: batteryData) {
                    return temperature
                }
            }
        }
        return nil
    }

    private static func batteryDataTemperatureCelsius(from batteryData: [String: Any]) -> Double? {
        for key in batteryTemperatureKeys {
            guard let hundredthsOfDegree = batteryData[key] as? NSNumber else { continue }
            let temperature = hundredthsOfDegree.doubleValue / 100
            if temperature.isFinite, temperature > 0, temperature <= 120 {
                return temperature
            }
        }
        return nil
    }

    public static func batteryTemperatureCelsius(
        from properties: [String: NSNumber]
    ) -> Double? {
        for key in batteryTemperatureKeys {
            guard let rawValue = properties[key],
                  let temperature = batteryTemperatureCelsius(fromRawValue: rawValue) else {
                continue
            }
            return temperature
        }
        return nil
    }

    public static func batteryTemperatureCelsius(fromRawValue rawValue: NSNumber) -> Double? {
        let raw = rawValue.doubleValue
        guard raw.isFinite else { return nil }

        let celsius: Double
        if raw >= 1_000 {
            celsius = raw / 100
        } else if raw > 120 {
            celsius = raw / 10
        } else {
            celsius = raw
        }

        guard celsius > 0, celsius <= 120 else { return nil }
        return celsius
    }
}

import SwiftUI
import AppKit
import MacCleanKit

struct MenuContentView: View {
    let stats: SystemStatsCollector.SystemStats?
    let networkSpeed: NetworkSpeedMonitor.NetworkSpeed?
    let devices: ConnectedDevices?
    let protection: SharedAppState.ProtectionStatus?
    let tips: [TipsEngine.Tip]
    let onDismissTip: (String) -> Void

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                if let stats {
                    statGrid(stats)
                    networkCard(stats)
                    if !tips.isEmpty { recommendationsCard }
                    if let d = devices, d.hasAny { devicesCard(d) }
                } else {
                    ProgressView().controlSize(.small).tint(.white)
                        .frame(height: 100)
                }
                footer
            }
            .padding(14)
        }
        .frame(width: 340)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: VacuumAsset.image)
                .resizable().interpolation(.high)
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(MCConstants.appName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(MenuPalette.textPrimary)
                Text("Live system stats")
                    .font(.system(size: 10))
                    .foregroundStyle(MenuPalette.textSecondary)
            }
            Spacer()
        }
    }

    private func statGrid(_ s: SystemStatsCollector.SystemStats) -> some View {
        let diskUsed = s.diskTotal > 0 ? Double(s.diskTotal - s.diskFree) / Double(s.diskTotal) : 0
        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ringCard(icon: "cpu", label: "CPU",
                     value: s.cpuUsage, center: "\(Int((s.cpuUsage*100).rounded()))%",
                     sub: nil)
            ringCard(icon: "memorychip", label: "Memory",
                     value: s.memoryPressure, center: "\(Int((s.memoryPressure*100).rounded()))%",
                     sub: FileSizeFormatter.format(s.memoryUsed))
            ringCard(icon: "internaldrive", label: "Disk",
                     value: diskUsed, center: "\(Int((diskUsed*100).rounded()))%",
                     sub: "\(FileSizeFormatter.format(s.diskFree)) free")
            if let level = s.batteryLevel {
                ringCard(icon: s.batteryIsCharging ? "battery.100.bolt" : "battery.75",
                         label: s.batteryIsCharging ? "Charging" : "Battery",
                         value: level, center: "\(Int((level*100).rounded()))%",
                         sub: nil, forceColor: level > 0.2 ? MenuPalette.teal : Color(red:0.98,green:0.42,blue:0.45))
            } else {
                uptimeCard(s)
            }
        }
    }

    private func ringCard(icon: String, label: String, value: Double, center: String, sub: String?, forceColor: Color? = nil) -> some View {
        let color = forceColor ?? MenuPalette.barColor(value)
        return VStack(spacing: 12) {
            statHeader(icon: icon, label: label, tint: color)
            RingGauge(value: value, color: color, center: center)
                .frame(width: 58, height: 58)

            Text(sub ?? " ")
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(MenuPalette.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(16)
        .glassCard()
    }

    private func uptimeCard(_ s: SystemStatsCollector.SystemStats) -> some View {
        VStack(spacing: 12) {
            statHeader(icon: "clock", label: "Uptime", tint: MenuPalette.teal)
            Text(formatUptime(s.uptime))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .frame(height: 58)
            Text(" ").font(.system(size: 10, design: .monospaced))
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(16)
        .glassCard()
    }

    private func statHeader(icon: String, label: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(MenuPalette.textPrimary)
        }
    }

    private func networkCard(_ s: SystemStatsCollector.SystemStats) -> some View {
        HStack(spacing: 0) {
            if let net = networkSpeed {
                netCell(icon: "arrow.down", color: MenuPalette.teal, value: net.formattedIn)
                divider
                netCell(icon: "arrow.up", color: MenuPalette.yellow, value: net.formattedOut)
                divider
            }
            netCell(icon: "clock", color: MenuPalette.textSecondary, value: formatUptime(s.uptime))
            if s.swapUsed > 0 {
                divider
                netCell(icon: "arrow.triangle.swap", color: MenuPalette.textSecondary, value: FileSizeFormatter.format(s.swapUsed))
            }
        }
        .padding(.vertical, 9)
        .glassCard()
    }

    private func netCell(icon: String, color: Color, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 9, weight: .bold)).foregroundStyle(color)
            Text(value).font(.system(size: 10, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.10)).frame(width: 1, height: 18)
    }

    private var recommendationsCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionHeader(icon: "sparkles", title: "Recommendations", tint: MenuPalette.yellow)
            ForEach(tips.prefix(3)) { tip in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: tip.symbol).font(.system(size: 12)).foregroundStyle(MenuPalette.teal).frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tip.title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
                            Text(tip.body).font(.system(size: 10)).foregroundStyle(MenuPalette.textSecondary).lineLimit(2)
                        }
                        Spacer(minLength: 2)
                        Button { onDismissTip(tip.id) } label: {
                            Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                                .foregroundStyle(MenuPalette.textSecondary).padding(4)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }.buttonStyle(.plain).help("Dismiss for 30 days")
                    }
                    Button { TipAction.open(moduleID: MenuTipRouting.moduleID(forTipID: tip.id)) } label: {
                        Text(tip.callToAction).font(.system(size: 11, weight: .bold)).foregroundStyle(Color(red:0.16,green:0.10,blue:0.30))
                            .frame(maxWidth: .infinity).padding(.vertical, 6)
                            .background(MenuPalette.yellow, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    }.buttonStyle(.plain)
                }
            }
        }
        .padding(11)
        .glassCard()
    }

    private func devicesCard(_ d: ConnectedDevices) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "externaldrive.connected.to.line.below", title: "Connected", tint: MenuPalette.teal)
            ForEach(d.externalVolumes) { v in
                HStack(spacing: 7) {
                    Image(systemName: "externaldrive.fill").font(.system(size: 10)).foregroundStyle(MenuPalette.teal.opacity(0.8))
                    Text(v.name).font(.system(size: 11)).foregroundStyle(.white).lineLimit(1)
                    Spacer(minLength: 6)
                    Text("\(FileSizeFormatter.format(v.freeBytes)) free").font(.system(size: 10, design: .monospaced)).foregroundStyle(MenuPalette.textSecondary)
                }
            }
            if d.externalDisplays > 0 {
                HStack(spacing: 7) {
                    Image(systemName: "display").font(.system(size: 10)).foregroundStyle(MenuPalette.teal.opacity(0.8))
                    Text("\(d.externalDisplays) external display\(d.externalDisplays == 1 ? "" : "s")").font(.system(size: 11)).foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .padding(11).glassCard()
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                MenuBarKeepAlive.setUserQuit(true, defaults: SharedAppState.defaults)
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power").font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
                    .frame(width: 34, height: 32)
                    .background(MenuPalette.red, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }.buttonStyle(.plain).help("Quit Monitor")

            Button { TipAction.open() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "leaf.fill").font(.system(size: 11, weight: .bold))
                    Text("Open \(MCConstants.appName)").font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(MenuPalette.green, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            }.buttonStyle(.plain)
        }
    }

    private func sectionHeader(icon: String, title: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(tint)
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
            Spacer()
        }
    }

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600, m = (Int(seconds) % 3600) / 60
        if h > 24 { return "\(h/24)d \(h%24)h" }
        return "\(h)h \(m)m"
    }
}

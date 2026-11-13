import SwiftUI
import AppKit
import MacCleanKit

struct SmartScanView: View {
    private var controller: SmartScanController { appState.smartScanController }
    @Environment(AppState.self) private var appState
    @State private var showCleanConfirm: Bool = false
    @AppStorage("hasWarnedAIConversationsCleanup") private var hasWarnedAIConversationsCleanup: Bool = false
    @State private var showAIWarningAlert: Bool = false

    var body: some View {
        Group {
            switch controller.scanState {
            case .idle:
                idleView
            case .scanning(let phase, let progress, let filesFound, let sizeFound):
                scanningView(phase: phase, progress: progress, filesFound: filesFound, sizeFound: sizeFound)
            case .results(_, _, _, let totalSize, _):
                resultsView(totalSize: totalSize)
            case .empty:
                emptyView
            case .cleaning(let progress):
                cleaningView(progress: progress)
            case .done(let freedSize, let breakdown):
                doneView(freedSize: freedSize, breakdown: breakdown)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .respondsToModuleShortcuts(
            onScan: { controller.startScan() },
            onClean: { promptClean() },
            canScan: {
                switch controller.scanState {
                case .idle, .empty, .done, .results: true
                case .scanning, .cleaning: false
                }
            }(),
            canClean: {
                if case .results = controller.scanState { return (controller.review?.selectedCount ?? 0) > 0 }
                return false
            }()
        )
    }

    private var idleView: some View {
        HomeDashboardView(onStartScan: { mode in
            controller.startScan(mode: mode)
        })
    }

    private func scanningView(phase: String, progress: Double, filesFound: Int, sizeFound: UInt64) -> some View {
        let activeModules = SmartScanModules.modules(for: controller.scanMode)
        let isPreparing = progress >= 1.0 || phase == "Preparing results..."

        return ScrollView {
            VStack(spacing: 18) {

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: controller.scanMode.icon)
                        Text(controller.scanMode.title)
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(controller.scanMode == .deep ? Color(nsColor: .systemOrange) : Color(nsColor: .systemIndigo))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3.5)
                    .background((controller.scanMode == .deep ? Color(nsColor: .systemOrange) : Color(nsColor: .systemIndigo)).opacity(0.12))
                    .clipShape(Capsule())

                    Text(isPreparing ? "Preparing Review…" : "Scanning your Mac…")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)

                    if isPreparing {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.mini)
                            Text("Analyzing findings for \(filesFound.formatted()) items…")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        HStack(spacing: 6) {
                            let cleanPhase = phase.replacingOccurrences(of: "...", with: "").replacingOccurrences(of: "…", with: "")
                            Text(cleanPhase.isEmpty ? "Checking system files…" : "\("Scanning") \(cleanPhase)…")
                                .font(.system(size: 12.5))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.top, 4)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.primary.opacity(0.08))
                            .frame(height: 8)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: controller.scanMode == .deep
                                        ? [Color.orange, Color.red.opacity(0.85)]
                                        : [Color(nsColor: .systemBlue), Color(nsColor: .systemIndigo)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(0, min(geo.size.width, geo.size.width * progress)), height: 8)
                            .animation(.smooth(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)

                HStack(spacing: 12) {
                    statCard(
                        title: "Progress",
                        value: isPreparing ? "100%" : "\(Int(progress * 100))%",
                        icon: "gauge.with.dots.needle.50percent",
                        color: Color(nsColor: .systemBlue)
                    )

                    statCard(
                        title: "Files Found",
                        value: filesFound.formatted(),
                        icon: "doc.on.doc.fill",
                        color: Color(nsColor: .systemPurple)
                    )

                    statCard(
                        title: "Size Found",
                        value: FileSizeFormatter.format(sizeFound),
                        icon: "arrow.down.circle.fill",
                        color: Color(nsColor: .systemGreen)
                    )
                }

                VStack(spacing: 0) {
                    HStack {
                        Label("Scan Areas", systemImage: "checklist")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(controller.completedModules.count) / \(activeModules.count)")
                            .font(.system(size: 11.5, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Divider()

                    VStack(spacing: 1) {
                        ForEach(Array(activeModules.enumerated()), id: \.offset) { index, module in
                            moduleRow(module: module, currentPhase: phase)
                            if index < activeModules.count - 1 {
                                Divider()
                                    .padding(.leading, 42)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor).opacity(0.25), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.02), radius: 6, x: 0, y: 2)

                if !isPreparing {
                    Button(role: .cancel) {
                        controller.cancelScan()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                            Text("Stop Scan")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .frame(minWidth: 130, minHeight: 32)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .keyboardShortcut(.cancelAction)
                    .padding(.top, 4)
                } else {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Loading review…")
                            .font(.system(size: 12.5, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .frame(height: 32)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: 720)
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 28)
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.12))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .animation(.smooth(duration: 0.2), value: value)
                    .lineLimit(1)

                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.2), lineWidth: 0.5)
        )
    }

    private func moduleRow(module: SmartScanModuleInfo, currentPhase: String) -> some View {
        let completed = controller.completedModules.contains { $0.name == module.name }
        let isActive = (controller.currentModuleName == module.name || currentPhase == module.name || currentPhase.hasPrefix(module.name)) && !completed
        let completedInfo = controller.completedModules.first { $0.name == module.name }

        return HStack(spacing: 12) {
            ZStack {
                if isActive {
                    ProgressView()
                        .controlSize(.small)
                } else if completed {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color(nsColor: .systemGreen))
                } else {
                    Image(systemName: "circle")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.secondary.opacity(0.25))
                }
            }
            .frame(width: 20)

            Image(systemName: module.icon)
                .font(.system(size: 14))
                .foregroundStyle(isActive ? Color.primary : Color.secondary.opacity(completed ? 0.8 : 0.4))
                .frame(width: 20)

            Text(module.name)
                .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                .foregroundStyle(isActive ? Color.primary : (completed ? Color.primary : Color.secondary))

            Spacer()

            if let info = completedInfo, info.fileCount > 0 {
                HStack(spacing: 6) {
                    Text("\(info.fileCount) items")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                    Text(FileSizeFormatter.format(info.size))
                        .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                }
            } else if completedInfo != nil {
                Text("Clean")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color(nsColor: .systemGreen))
            } else if isActive {
                Text("Scanning…")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Color(nsColor: .systemBlue))
            }

            Text(module.group)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2.5)
                .background(Color.primary.opacity(0.06))
                .clipShape(Capsule())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isActive ? Color.accentColor.opacity(0.08) : Color.clear)
    }

    @ViewBuilder
    private func resultsView(totalSize: UInt64) -> some View {
        let selectedCount = controller.review?.selectedCount ?? 0
        Group {
            if controller.showingReview, let review = controller.review {
                ReviewBrowserView(
                    data: review.data,
                    selection: review,
                    initialSectionID: controller.reviewSectionID,
                    onDone: { controller.showingReview = false },
                    onReset: { controller.resetScan() },
                    onClean: { promptClean() }
                )
            } else {
                resultsSummary(totalSize: totalSize)
            }
        }
        .alert("Clean \(selectedCount) item\(selectedCount == 1 ? "" : "s")?", isPresented: $showCleanConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Clean", role: .destructive) {
                controller.showingReview = false
                controller.runCleanup()
            }
        } message: {
            Text("Selected items move to the Trash. Items already in the Trash are deleted for good.")
        }
        .alert("Delete AI Conversations?", isPresented: $showAIWarningAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Conversations", role: .destructive) {
                hasWarnedAIConversationsCleanup = true
                controller.showingReview = false
                controller.runCleanup()
            }
        } message: {
            Text("Deep Clean includes conversation histories, sessions, and project data from Gemini, Codex, and Claude. This data cannot be recovered once deleted.")
        }
    }

    private func resultsSummary(totalSize: UInt64) -> some View {
        let selectedCount = controller.review?.selectedCount ?? 0
        let selectedSize = controller.review?.selectedSize ?? 0
        return VStack(spacing: 16) {

            HStack(spacing: 12) {
                Button {
                    controller.resetScan()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Dashboard")
                            .font(.system(size: 13, weight: .medium))
                    }
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color(nsColor: .systemBlue))
                .help("Return to Home Dashboard")

                Spacer()

                Button {
                    controller.startScan()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Rescan")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Run scan again")
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)

            SizeDisplay(size: totalSize, label: "of junk found")
                .foregroundStyle(.primary)
                .padding(.top, 4)

            HStack(spacing: 6) {
                Image(systemName: controller.scanMode.icon)
                    .foregroundStyle(controller.scanMode == .deep ? Color(nsColor: .systemOrange) : Color(nsColor: .systemIndigo))
                Text(
                    controller.scanMode == .deep
                    ? "Deep Clean Active — Project build outputs & developer caches auto-selected for maximum space recovery."
                    : "Safe Clean Active — Only safe system caches selected. Code & project builds preserved."
                )
                .font(.system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background((controller.scanMode == .deep ? Color(nsColor: .systemOrange) : Color(nsColor: .systemIndigo)).opacity(0.1))
            .clipShape(Capsule())

            HStack(spacing: 24) {
                if case .results(let cleanup, _, _, _, _) = controller.scanState {
                    resultPill(icon: "trash.circle.fill", label: "Cleanup", value: FileSizeFormatter.format(cleanup))
                }
                if case .results(_, _, let perf, _, _) = controller.scanState {
                    resultPill(icon: "gauge.with.dots.needle.67percent", label: "Speed", value: "\(perf) items")
                }
            }

            if let review = controller.review {
                HStack(spacing: 8) {
                    Button("Select All") {
                        review.applyToAll(.all)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Smart") {
                        review.applyToAll(.smart)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Deselect All") {
                        review.applyToAll(.none)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 200, maximum: 250), spacing: 14)],
                        spacing: 14
                    ) {
                        ForEach(review.data.sections) { section in
                            sectionCard(section, selection: review)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 4)
                }
                .frame(maxWidth: 820, maxHeight: .infinity)
            } else {
                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    controller.resetScan()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "house.fill")
                            .font(.system(size: 11.5))
                        Text("Dashboard")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Return to Home Dashboard")

                Button {
                    controller.startScan()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11.5, weight: .semibold))
                        Text("Rescan")
                            .font(.system(size: 12.5, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Run scan again")

                Spacer()

                Text("\(selectedCount.formatted()) \(selectedCount == 1 ? "item selected" : "items selected") · \(FileSizeFormatter.format(selectedSize))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    controller.reviewSectionID = nil
                    controller.showingReview = true
                } label: {
                    Label("Review Details", systemImage: "list.bullet.rectangle")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(controller.review == nil)

                Button { promptClean() } label: {
                    Text("Clean · \(FileSizeFormatter.format(selectedSize))")
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: .systemBlue))
                .controlSize(.large)
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .padding(.horizontal, 20)
    }

    private func promptClean() {
        if let review: ReviewSelection = controller.review,
           review.hasSelectedAIConversations(),
           !hasWarnedAIConversationsCleanup {
            showAIWarningAlert = true
        } else if controller.scanMode == .deep && hasWarnedAIConversationsCleanup {
            controller.showingReview = false
            controller.runCleanup()
        } else {
            showCleanConfirm = true
        }
    }

    private func sectionCard(_ section: ReviewSection, selection: ReviewSelection) -> some View {
        let selected = selection.selectedSize(ofSection: section)
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                ReviewCheckbox(state: selection.state(ofSection: section)) {
                    selection.toggleSection(section)
                }
                Image(systemName: ReviewSectionInfo.icon(for: section.id))
                    .font(.system(size: 18))
                    .foregroundStyle(Color(nsColor: .systemBlue))
                Spacer()
                Button {
                    controller.reviewSectionID = section.id
                    controller.showingReview = true
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            Button {
                controller.reviewSectionID = section.id
                controller.showingReview = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(section.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(FileSizeFormatter.format(section.size))
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("\(FileSizeFormatter.format(selected)) selected")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.975), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .help("Review Details")
    }

    private var emptyView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(.primary.opacity(0.9))
            Text("Your Mac is clean!")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            Text("No junk, threats, or performance issues found")
                .font(.system(size: 14))
                .foregroundStyle(.primary.opacity(0.6))
            Button("Done") { controller.resetScan() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
            Spacer()
        }
    }

    private func cleaningView(progress: Double) -> some View {
        VStack(spacing: 20) {
            Spacer()
            ScanProgressRing(progress: progress, phase: "Cleaning your Mac...", theme: .smartScan)

            Button("Cancel") { controller.cancelCleaning() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
            Spacer()
        }
    }

    private func doneView(freedSize: UInt64, breakdown: [SmartScanCleanup.RecentlyCleanedRow]) -> some View {
        FitOrScroll { doneContent(freedSize: freedSize, breakdown: breakdown) }
    }

    private func doneContent(freedSize: UInt64, breakdown: [SmartScanCleanup.RecentlyCleanedRow]) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.primary)
            Text("Cleanup Complete")
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.primary)
            SizeDisplay(size: freedSize, label: "moved to Trash")
                .foregroundStyle(.primary)

            if !breakdown.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recently cleaned")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.55))
                        .textCase(.uppercase)
                    ForEach(breakdown, id: \.moduleID) { row in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.green)
                            Text(row.moduleName)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer(minLength: 8)
                            Text(recentlyCleanedDetail(row))
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.primary.opacity(0.7))
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: 420)
                .background(.primary.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text("Your selected items are in the Trash. Empty it to free the space.")
                .font(.system(size: 13))
                .foregroundStyle(.primary.opacity(0.65))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            if controller.askForSupport { SupportCard() }
            Button("Done") { controller.resetScan() }
                .buttonStyle(.bordered)
                .tint(.primary)
                .controlSize(.large)
            Spacer()
        }
        .padding(.horizontal, 40)
    }

    private func recentlyCleanedDetail(_ row: SmartScanCleanup.RecentlyCleanedRow) -> String {
        let size = FileSizeFormatter.format(row.size)
        if row.itemCount <= 1 {
            return size
        }
        return "\(size) (\(row.itemCount) items)"
    }

    private func resultPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 22))
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .opacity(0.7)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.primary)
        .frame(width: 110, height: 90)
        .background(.primary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

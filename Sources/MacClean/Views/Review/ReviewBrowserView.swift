import SwiftUI
import AppKit
import MacCleanKit

struct ReviewBrowserView: View {
    let data: ReviewData
    let selection: ReviewSelection
    var doneTitle: String = "Done"
    var doneDisabled: Bool = false
    let onDone: () -> Void
    var onReset: (() -> Void)? = nil
    var onClean: (() -> Void)? = nil

    @State private var controller: ReviewBrowserController

    private static let maxRows = 1_000

    init(
        data: ReviewData,
        selection: ReviewSelection,
        initialSectionID: String? = nil,
        doneTitle: String = "Done",
        doneDisabled: Bool = false,
        onDone: @escaping () -> Void,
        onReset: (() -> Void)? = nil,
        onClean: (() -> Void)? = nil
    ) {
        self.data = data
        self.selection = selection
        self.doneTitle = doneTitle
        self.doneDisabled = doneDisabled
        self.onDone = onDone
        self.onReset = onReset
        self.onClean = onClean
        _controller = State(initialValue: ReviewBrowserController(data: data, initialSectionID: initialSectionID))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                categoriesMasterList
                    .frame(width: 320)
                    .background(Color(white: 0.985))

                Divider()

                detailPane
                    .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
            }

            Divider()

            bottomBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private var categoriesMasterList: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Text("Categories")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Button("All") {
                        selection.applyToAll(.all)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("Smart") {
                        selection.applyToAll(.smart)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("None") {
                        selection.applyToAll(.none)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            ScrollView {
                let nonEmptySections = controller.nonEmptySections
                if nonEmptySections.count > 1 {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(nonEmptySections) { section in
                            sectionGroup(section)
                        }
                    }
                    .padding(.vertical, 8)
                } else if let singleSection = nonEmptySections.first {
                    LazyVStack(spacing: 2) {
                        ForEach(controller.nonEmptyCategoryIDs(in: singleSection), id: \.self) { id in
                            categoryRow(data.categories[id])
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                } else {
                    LazyVStack(spacing: 2) {
                        ForEach(controller.nonEmptyCategoriesBySize) { category in
                            categoryRow(category)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    @ViewBuilder
    private func sectionGroup(_ section: ReviewSection) -> some View {
        let sectionSize = selection.selectedSize(ofSection: section)
        let nonEmptyCatIDs = controller.nonEmptyCategoryIDs(in: section)
        if !nonEmptyCatIDs.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: ReviewSectionInfo.icon(for: section.id))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(nsColor: .systemBlue))

                    Text(section.name)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    Spacer()

                    if sectionSize > 0 {
                        Text(FileSizeFormatter.format(sectionSize))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color(nsColor: .systemBlue))
                    }

                    ReviewCheckbox(state: selection.state(ofSection: section)) {
                        selection.toggleSection(section)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 4)
                .padding(.bottom, 2)

                VStack(spacing: 2) {
                    ForEach(nonEmptyCatIDs, id: \.self) { id in
                        categoryRow(data.categories[id])
                    }
                }
                .padding(.horizontal, 8)
            }
        }
    }

    private func categoryRow(_ category: ReviewCategory) -> some View {
        let isSelected = category.id == controller.categoryID
        let selectedSize = selection.selectedSize(ofCategory: category.id)
        let isEmpty = category.size == 0
        return HStack(spacing: 8) {
            ReviewCheckbox(state: selection.state(ofCategory: category.id)) {
                selection.toggleCategory(category.id)
            }
            .disabled(isEmpty)
            .opacity(isEmpty ? 0.35 : 1)

            Button {
                controller.select(category)
            } label: {
                HStack(spacing: 8) {
                    ReviewCategoryIcon(category: category.category, isEmpty: isEmpty)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(category.category.displayName)
                            .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(isEmpty ? Color.secondary : Color.primary)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(FileSizeFormatter.format(category.size))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                            if !isEmpty {
                                SafetyBadge(level: category.category.safetyLevel)
                            }
                        }
                    }

                    Spacer(minLength: 4)

                    if selectedSize > 0 {
                        Text(FileSizeFormatter.format(selectedSize))
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundStyle(Color(nsColor: .systemBlue))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .systemBlue).opacity(0.12), in: Capsule())
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            isSelected ? Color(nsColor: .systemBlue).opacity(0.12) : Color.clear,
            in: RoundedRectangle(cornerRadius: 6, style: .continuous)
        )
        .help(category.category.tooltip)
    }

    @ViewBuilder
    private var detailPane: some View {
        if let category = controller.currentCategory {
            VStack(alignment: .leading, spacing: 0) {
                detailHeader(category)

                Divider()

                if controller.isDrilled {
                    breadcrumb(category)
                    Divider()
                }

                nodeList(category)
            }
        } else {
            VStack {
                Spacer()
                Text("Select a category to view details")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func detailHeader(_ category: ReviewCategory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(category.category.displayName)
                            .font(.system(size: 18, weight: .bold))

                        Text(FileSizeFormatter.format(category.size))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)

                        SafetyBadge(level: category.category.safetyLevel)
                    }

                    Text(ReviewCategoryInfo.description(for: category.category))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }

            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                        .font(.system(size: 11))

                    TextField("Search items...", text: $controller.searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))

                    if !controller.searchText.isEmpty {
                        Button {
                            controller.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                                .font(.system(size: 11))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(white: 0.97), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
                )
                .frame(maxWidth: 220)

                Spacer()

                if !category.groups.isEmpty {
                    HStack(spacing: 6) {
                        Button("Select All") {
                            selection.apply(.all, toCategory: category.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .keyboardShortcut("a", modifiers: .command)

                        Button("Smart") {
                            selection.apply(.smart, toCategory: category.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        if category.category == .projectJunk {
                            Button("Select > 1 GB") {
                                selection.selectOver1GB(inCategory: category.id)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }

                        Button("Deselect") {
                            selection.apply(.none, toCategory: category.id)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Toggle(isOn: $controller.onlyLargeFiles) {
                            Text(controller.largeFileFilterLabel(for: category))
                                .font(.system(size: 11, weight: .medium))
                        }
                        .toggleStyle(.button)
                        .controlSize(.small)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private func breadcrumb(_ category: ReviewCategory) -> some View {
        HStack(spacing: 6) {
            Button {
                controller.goBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text(controller.drillPath.count > 1 ? controller.drillPath[controller.drillPath.count - 2].name : category.category.displayName)
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color(nsColor: .systemBlue))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text("›")
                .foregroundStyle(.tertiary)

            Text(controller.drillPath.last?.name ?? "")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(white: 0.985))
    }

    @ViewBuilder
    private func nodeList(_ category: ReviewCategory) -> some View {
        let baseNodes = controller.baseNodes(in: category)
        let filteredNodes = controller.filteredNodes(in: category)

        if category.groups.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("Nothing to clean in this category")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if controller.isLoadingChildren {
            VStack {
                Spacer()
                ProgressView().controlSize(.small)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if baseNodes.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "folder")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("This folder is empty")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if filteredNodes.isEmpty {
            VStack(spacing: 8) {
                Spacer()
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28))
                    .foregroundStyle(.secondary)
                Text("No items match your filter")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredNodes.prefix(Self.maxRows)) { node in
                        nodeRow(node, category: category)
                        Divider()
                            .padding(.leading, 44)
                    }
                    if filteredNodes.count > Self.maxRows {
                        Text("Showing the largest \(Self.maxRows) of \(filteredNodes.count) items")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 10)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
            .id(controller.drillPath.last?.id ?? "category-\(category.id)")
        }
    }

    private func nodeRow(_ node: ReviewNode, category: ReviewCategory) -> some View {
        let state = selection.state(of: node.range)
        let showChevron = !node.isLeaf && category.category != .systemLogs && category.category != .userLogs || controller.isDrilled && !node.isLeaf
        return HStack(spacing: 10) {
            ReviewCheckbox(state: state) {
                selection.toggle(node, category: category.id)
            }
            ReviewFileIcon(path: node.iconPath)
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                if category.category == .projectJunk {
                    let info = projectJunkInfo(for: node)
                    HStack(alignment: .center, spacing: 6) {
                        Text(info.junkName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if !info.projectName.isEmpty {
                            Text(info.projectName)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(nsColor: .systemBlue))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1.5)
                                .background(Color(nsColor: .systemBlue).opacity(0.12), in: Capsule())
                                .lineLimit(1)
                        }
                    }
                } else {
                    Text(node.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    if !node.basePath.isEmpty && node.basePath != node.name {
                        Text((node.basePath as NSString).abbreviatingWithTildeInPath)
                            .font(.system(size: 10.5))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                if node.appIsRunning || node.isSensitive || node.isAIConversation || node.isOldVersion {
                    HStack(spacing: 8) {
                        if node.appIsRunning {
                            Label(
                                "App is open",
                                systemImage: "lock.fill"
                            )
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.orange)
                        }
                        if node.isSensitive {
                            Label(
                                "Sensitive path",
                                systemImage: "exclamationmark.shield.fill"
                            )
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.red)
                        }
                        if node.isAIConversation {
                            Label(
                                "AI History",
                                systemImage: "bubble.left.and.bubble.right.fill"
                            )
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.purple)
                        }
                        if node.isOldVersion {
                            Label(
                                "Old Version",
                                systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                            )
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            Text(FileSizeFormatter.format(node.size))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 76, alignment: .trailing)
            if showChevron {
                Button {
                    controller.drill(into: node)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 20)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture {
            selection.toggle(node, category: category.id)
        }
        .help(node.basePath)
        .contextMenu {
            Button("Quick Look") {
                QuickLookPresenter.shared.preview(path: node.basePath)
            }
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([URL(filePath: node.basePath)])
            }
            if !node.isLeaf {
                Button("Show Contents") { controller.drill(into: node) }
            }
        }
    }

    private func projectJunkInfo(for node: ReviewNode) -> (junkName: String, projectName: String) {
        if let openParen = node.name.range(of: " (", options: .backwards),
           node.name.hasSuffix(")") {
            let junk = String(node.name[..<openParen.lowerBound])
            let project = String(node.name[openParen.upperBound..<node.name.index(before: node.name.endIndex)])
            if !project.isEmpty {
                return (junkName: junk, projectName: project)
            }
        }
        let junkName = (node.basePath as NSString).lastPathComponent
        let parentDir = (node.basePath as NSString).deletingLastPathComponent
        let projectName = (parentDir as NSString).lastPathComponent
        return (junkName: junkName.isEmpty ? node.name : junkName,
                projectName: projectName.isEmpty ? "" : projectName)
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if let locked = selection.lockedSummary {
                HStack(spacing: 5) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.orange)
                    Text("\(locked.appCount) open app\(locked.appCount == 1 ? "" : "s") skipped (\(FileSizeFormatter.format(locked.bytes)))")
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 16)
            } else {
                Spacer()
                    .frame(width: 16)
            }

            Spacer()

            HStack(spacing: 6) {
                Text("\(selection.selectedCount.formatted()) Items Selected")
                    .font(.system(size: 12.5, weight: .medium))
                Text("·")
                    .foregroundStyle(.tertiary)
                Text(FileSizeFormatter.format(selection.selectedSize))
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundStyle(Color(nsColor: .systemBlue))
                    .monospacedDigit()
            }

            HStack(spacing: 8) {
                if let onReset {
                    Button {
                        onReset()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "house.fill")
                                .font(.system(size: 11))
                            Text("Dashboard")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .help("Return to Home Dashboard")
                }

                if let onClean {
                    Button("Back", action: onDone)
                        .buttonStyle(.bordered)
                        .controlSize(.regular)

                    Button("Clean (\(FileSizeFormatter.format(selection.selectedSize)))", action: onClean)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(nsColor: .systemBlue))
                        .controlSize(.regular)
                        .disabled(selection.selectedCount == 0)
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button(doneTitle, action: onDone)
                        .buttonStyle(.borderedProminent)
                        .tint(Color(nsColor: .systemBlue))
                        .controlSize(.regular)
                        .disabled(doneDisabled)
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.trailing, 16)
        }
        .frame(height: 50)
        .background(Color.white)
    }
}

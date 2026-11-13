import Foundation
import Observation
import MacCleanKit

@MainActor @Observable
final class ReviewBrowserController {
    let data: ReviewData
    private(set) var categoryID: Int?
    private(set) var drillPath: [ReviewNode] = []
    private var childCache: [String: [ReviewNode]] = [:]
    private var loadingNodeID: String?
    var searchText = ""
    var onlyLargeFiles = false

    init(data: ReviewData, initialSectionID: String?) {
        self.data = data
        let sections = nonEmptySections
        let initialSection = sections.first { $0.id == initialSectionID } ?? sections.first ?? data.sections.first
        categoryID = initialSection.flatMap { nonEmptyCategoryIDs(in: $0).first ?? $0.categoryIDs.first }
            ?? data.categories.first { $0.size > 0 }?.id
            ?? data.categories.first?.id
    }

    var currentCategory: ReviewCategory? {
        categoryID.map { data.categories[$0] }
    }

    var nonEmptySections: [ReviewSection] {
        data.sections.filter { $0.size > 0 && !nonEmptyCategoryIDs(in: $0).isEmpty }
    }

    var nonEmptyCategoriesBySize: [ReviewCategory] {
        data.categories.filter { $0.size > 0 }.sorted { $0.size > $1.size }
    }

    var isDrilled: Bool {
        !drillPath.isEmpty
    }

    var isLoadingChildren: Bool {
        guard let parent = drillPath.last else { return false }
        return childCache[parent.id] == nil || loadingNodeID == parent.id
    }

    func nonEmptyCategoryIDs(in section: ReviewSection) -> [Int] {
        section.categoryIDs.filter { data.categories[$0].size > 0 }
    }

    func baseNodes(in category: ReviewCategory) -> [ReviewNode] {
        drillPath.last.flatMap { childCache[$0.id] } ?? category.groups
    }

    func filteredNodes(in category: ReviewCategory) -> [ReviewNode] {
        let threshold = largeFileFilter(for: category).threshold
        return baseNodes(in: category).filter { node in
            let matchesSearch = searchText.isEmpty || node.name.localizedCaseInsensitiveContains(searchText)
            let matchesSize = !onlyLargeFiles || node.size >= threshold
            return matchesSearch && matchesSize
        }
    }

    func largeFileFilterLabel(for category: ReviewCategory) -> String {
        largeFileFilter(for: category).label
    }

    func select(_ category: ReviewCategory) {
        categoryID = category.id
        drillPath = []
    }

    func goBack() {
        drillPath.removeLast()
    }

    func drill(into node: ReviewNode) {
        guard !node.isLeaf else { return }
        searchText = ""
        onlyLargeFiles = false
        drillPath.append(node)
        guard childCache[node.id] == nil else { return }
        loadingNodeID = node.id
        let data = data
        Task {
            let children = await Task.detached(priority: .userInitiated) {
                data.children(of: node)
            }.value
            childCache[node.id] = children
            if loadingNodeID == node.id { loadingNodeID = nil }
        }
    }

    private func largeFileFilter(for category: ReviewCategory) -> (threshold: UInt64, label: String) {
        if isDrilled { return (50 * 1024 * 1024, "> 50 MB") }
        if category.category == .projectJunk { return (1_000_000_000, "> 1 GB") }
        return (100 * 1024 * 1024, "> 100 MB")
    }
}

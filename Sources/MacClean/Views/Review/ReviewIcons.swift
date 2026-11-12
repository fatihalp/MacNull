import SwiftUI
import AppKit
import MacCleanKit

struct ReviewCheckbox: View {
    let state: ReviewCheckState
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(state == .off ? Color.white : Color(nsColor: .systemBlue))
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .strokeBorder(state == .off ? Color.secondary.opacity(0.45) : Color(nsColor: .systemBlue), lineWidth: 1)
                switch state {
                case .on:
                    Image(systemName: "checkmark")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                case .mixed:
                    Image(systemName: "minus")
                        .font(.system(size: 9.5, weight: .bold))
                        .foregroundStyle(.white)
                case .off:
                    EmptyView()
                }
            }
            .frame(width: 15, height: 15)
            .padding(2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Select")
        .accessibilityValue(state == .on ? "1" : state == .mixed ? "0.5" : "0")
    }
}

struct ReviewCategoryIcon: View {
    let category: ScanCategory
    var isEmpty: Bool = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(isEmpty ? Color.secondary.opacity(0.1) : Color(nsColor: .systemBlue).opacity(0.12))
            .overlay(
                Image(systemName: mainSymbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isEmpty ? Color.secondary : Color(nsColor: .systemBlue))
            )
            .frame(width: 26, height: 26)
    }

    private var mainSymbol: String {
        switch category {
        case .userCaches, .systemCaches: "clock.fill"
        case .xcodeJunk: "hammer.fill"
        case .universalBinaries: "circle.lefthalf.filled"
        case .userLogs, .systemLogs: "doc.text.fill"
        case .languageFiles: "bubble.left.fill"
        case .documentVersions: "checkmark.circle.fill"
        case .brokenLoginItems: "person.slash.fill"
        case .iosDeviceBackups: "arrow.clockwise.circle.fill"
        case .deletedUsers: "person.crop.rectangle.fill"
        case .brokenPreferences: "gearshape.fill"
        case .browserPrivacy: "globe"
        default: category.systemImage
        }
    }
}

struct ReviewFileIcon: View {
    let path: String

    var body: some View {
        Image(nsImage: ReviewIconCache.icon(for: path))
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
    }
}

@MainActor
enum ReviewIconCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func icon(for path: String) -> NSImage {
        if let cached = cache.object(forKey: path as NSString) { return cached }
        let image: NSImage
        if FileManager.default.fileExists(atPath: path) {
            image = NSWorkspace.shared.icon(forFile: path)
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: path) {
            image = NSWorkspace.shared.icon(forFile: appURL.path(percentEncoded: false))
        } else {
            image = NSWorkspace.shared.icon(forFile: path)
        }
        cache.setObject(image, forKey: path as NSString)
        return image
    }
}

import Foundation

public enum Localization {
    public static let currentLocale = Locale(identifier: "en")

    public static func string(_ key: String) -> String {
        guard let bundle = englishBundle else { return key }
        let result = bundle.localizedString(forKey: key, value: "\u{1}", table: nil)
        return result == "\u{1}" ? key : result
    }

    private static let englishBundle: Bundle? = {
        if let path = Bundle.main.path(forResource: "en", ofType: "lproj") {
            return Bundle(path: path)
        }
        guard let resources = Bundle.main.resourceURL else { return nil }
        return Bundle(url: resources.appendingPathComponent("en.lproj"))
            ?? Bundle(url: resources.appendingPathComponent("MacClean_MacCleanKit.bundle/en.lproj"))
    }()
}

extension String {
    public init(localized key: String) {
        self = Localization.string(key)
    }
}

import Foundation

public enum LanguagePreferences {

    public static let alwaysKept: Set<String> = MCConstants.preservedLanguages

    nonisolated(unsafe) public static var systemPreferredLanguages: () -> [String] = { Locale.preferredLanguages }

    public static func systemLanguageFolders(for identifiers: [String]) -> Set<String> {
        var folders: Set<String> = []
        for identifier in identifiers {
            let parts = identifier
                .split(whereSeparator: { $0 == "-" || $0 == "_" })
                .map(String.init)
            guard let language = parts.first, !language.isEmpty else { continue }
            var codes: Set<String> = [language]
            for subtag in parts.dropFirst() {
                codes.insert("\(language)-\(subtag)")
                codes.insert("\(language)_\(subtag)")
            }
            if parts.count > 2 {
                codes.insert(parts.joined(separator: "-"))
                codes.insert(parts.joined(separator: "_"))
            }
            folders.formUnion(codes.map { "\($0).lproj" })
            if let name = Locale(identifier: "en").localizedString(forLanguageCode: language) {
                folders.insert("\(name).lproj")
            }
        }
        return folders
    }

    public static var systemKept: Set<String> {
        systemLanguageFolders(for: systemPreferredLanguages())
    }

    private static let discoveredKey = "discoveredLanguages"

    public static var discoveredLproj: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: discoveredKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: discoveredKey) }
    }

    public static func displayName(
        forLproj lproj: String,
        locale: Locale = Localization.currentLocale
    ) -> String {
        let code = lproj.hasSuffix(".lproj") ? String(lproj.dropLast(6)) : lproj

        return locale.localizedString(forIdentifier: code)
            ?? locale.localizedString(forLanguageCode: code)
            ?? code
    }

    public static func selectableLanguages(
        locale: Locale = Localization.currentLocale
    ) -> [(name: String, lprojs: [String])] {
        let candidates = discoveredLproj.subtracting(alwaysKept).subtracting(systemKept)
        return Dictionary(grouping: candidates) { displayName(forLproj: $0, locale: locale) }
            .map { (name: $0.key, lprojs: $0.value.sorted()) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static let userKeptKey = "keptLanguages"

    public static var userKept: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: userKeptKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: userKeptKey) }
    }

    public static func effectivePreserved(userKept extra: Set<String>? = nil) -> Set<String> {
        alwaysKept.union(systemKept).union(extra ?? userKept)
    }
}

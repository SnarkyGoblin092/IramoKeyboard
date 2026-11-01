import Foundation

/// The language the Iramo app is shown in: the one picked at the bottom of its main screen
/// (`SettingKey.appLanguage`), or with "system" the phone's first language the app has, else English. Any of the
/// keyboard's typing languages can be picked. The texts are in `App/Localization/<code>.lproj/AppStrings.strings`,
/// keyed by the English text, so a text without a translation shows in English. (The keyboard extension has no
/// translations of its own and stays in English.)
enum AppLanguage {
    /// The setting's value that follows the phone's language.
    static let system = "system"

    /// The language for a setting value ("system" or a `Language` code).
    static func language(for setting: String) -> Language {
        if setting != system, let language = Language(rawValue: setting) { return language }
        return systemLanguage
    }

    /// The phone's first preferred language the app has (Norwegian Bokmål and Nynorsk as Norwegian, Chinese as
    /// Mandarin and Cantonese as Cantonese), else English.
    static var systemLanguage: Language {
        for identifier in Locale.preferredLanguages {
            let code = identifier.lowercased()
            let base = String(code.split(separator: "-").first ?? Substring(code))
            switch base {
            case "nb", "nn", "no": return .norwegian
            case "yue": return .cantonese
            case "zh": return .mandarin
            case "iw": return .hebrew
            case "in": return .indonesian
            default:
                if let language = Language(rawValue: base) { return language }
            }
        }
        return .english
    }

    static var stored: String {
        return SharedStore.defaults.string(forKey: SettingKey.appLanguage) ?? SettingDefault.appLanguage
    }

    /// The app's language now.
    static var current: Language { return resolved().language }

    /// Its locale, for language names, lists and the environment.
    static var locale: Locale { return Locale(identifier: current.localeIdentifier) }

    /// Arabic, Hebrew and Persian read right to left.
    static var isRightToLeft: Bool { return [.arabic, .hebrew, .persian].contains(current) }

    // MARK: Lookup

    private static var cache: (setting: String, language: Language, bundle: Bundle?)?

    /// The current language and its strings' bundle (nil for English, whose texts are the keys), re-read when the
    /// setting changes.
    private static func resolved() -> (language: Language, bundle: Bundle?) {
        let setting = stored
        if let cache = cache, cache.setting == setting { return (cache.language, cache.bundle) }
        let language = language(for: setting)
        var bundle: Bundle? = nil
        if language != .english, let path = Bundle.main.path(forResource: language.stringsFolder, ofType: "lproj") {
            bundle = Bundle(path: path)
        }
        cache = (setting, language, bundle)
        return (language, bundle)
    }

    /// The text for an English key in the app's language (the key itself when it has no translation).
    static func text(_ key: String) -> String {
        guard let bundle = resolved().bundle else { return key }
        return bundle.localizedString(forKey: key, value: key, table: "AppStrings")
    }
}

/// An English text of the app in the app's language (AppLanguage).
func tr(_ key: String) -> String {
    return AppLanguage.text(key)
}

/// A text with values in it: `format` holds %@ (or %1$@, %2$@... where there are several) for each argument.
func tr(_ format: String, _ arguments: CVarArg...) -> String {
    return String(format: AppLanguage.text(format), locale: AppLanguage.locale, arguments: arguments)
}

extension Language {
    /// The folder of the app's translations in this language.
    var stringsFolder: String {
        switch self {
        case .mandarin: return "zh-Hans"
        case .cantonese: return "yue-Hant"
        case .norwegian: return "nb"
        default: return rawValue
        }
    }

    /// The locale the app uses while shown in this language.
    var localeIdentifier: String {
        switch self {
        case .mandarin: return "zh-Hans"
        case .cantonese: return "yue-Hant"
        case .norwegian: return "nb"
        default: return rawValue
        }
    }

    /// The language's name in the app's language ("Hungarian" in English, "Ungarisch" in German), for the app's
    /// lists. The keyboard's space bar keeps `displayName`, the language's own name.
    var localizedName: String {
        let locale = AppLanguage.locale
        let name: String?
        switch self {
        case .mandarin: name = tr("Mandarin")
        case .cantonese: name = tr("Cantonese")
        default: name = locale.localizedString(forLanguageCode: rawValue)
        }
        guard let text = name, !text.isEmpty else { return displayName }
        // Some languages write language names in lower case ("magyar"); a list item starts with a capital.
        return text.prefix(1).uppercased(with: locale) + text.dropFirst()
    }
}

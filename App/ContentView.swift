import SwiftUI
import UIKit

/// The keyboard's settings, grouped like the system Settings app: what the keyboard does, how typing behaves, how
/// it looks and feels, and the data it keeps. Every section is its own small view, so changing one control only
/// redraws that section; rows that open a screen show what it is set to.
struct ContentView: View {
    /// The screens opened from the main list (ScreenRow pushes onto it).
    @State private var path: [Screen] = []
    @AppStorage(SettingKey.appLanguage, store: SharedStore.defaults) private var appLanguage = SettingDefault.appLanguage
    @AppStorage(SettingKey.appearance, store: SharedStore.defaults) private var appearance = SettingDefault.appearance
    /// The app language was just changed: the main list, built again from the top, goes back to its row.
    @State private var returnToLanguageRow = false
    /// The first-run welcome page (Welcome.swift); the About section's button shows it again by clearing this.
    @AppStorage(SettingKey.welcomeSeen, store: SharedStore.defaults) private var welcomeSeen = false

    /// The window's full size (the keyboard showing doesn't change it): wide enough, it shows two columns.
    @State private var windowSize: CGSize = .zero
    /// What is typed in the main list's search field.
    @State private var query = 

    /// Landscape on an iPhone or iPad: the main list on the left and the open screen beside it.
    private static func isWide(_ size: CGSize) -> Bool {
        return size.width > size.height && size.width >= 640
    }

    var body: some View {
        Group {
            if ContentView.isWide(windowSize) {
                landscape
            } else {
                NavigationStack(path: $path) {
                    mainList
                        .navigationDestination(for: Screen.self) { $0.scopedView }
                }
                .environment(\.openScreen, { screen in
                    returnToLanguageRow = false
                    path.append(screen)
                })
            }
        }
        .background(GeometryReader { geometry in
            Color.clear
                .onAppear { windowSize = geometry.size }
                .onChange(of: geometry.size) { windowSize = $0 }
        }.ignoresSafeArea())
        .toggleStyle(GlassSwitchStyle())   // every switch in the app is a piece of Liquid Glass
        // Everything is built again in the new language when it changes (tr reads it as the views are drawn).
        .id(appLanguage)
        .environment(\.locale, AppLanguage.locale)
        .environment(\.layoutDirection, AppLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
        .onChange(of: appLanguage) { _ in returnToLanguageRow = true }
        .modifier(AccentTint())
        .roundedType()
        // The Themes screen's light / dark switch sets the mode of the whole app ("auto": the system's).
        .preferredColorScheme(appearance == "light" ? .light : (appearance == "dark" ? .dark : nil))
        .fullScreenCover(isPresented: Binding(get: { !welcomeSeen }, set: { welcomeSeen = !$0 })) {
            WelcomeView { welcomeSeen = true }
                .environment(\.locale, AppLanguage.locale)
                .environment(\.layoutDirection, AppLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
                .modifier(AccentTint())
                .roundedType()
        }
        .onAppear {
            Feedback.prepare()
            // The enabled languages' data is unpacked now, so the keyboard finds it ready.
            LanguageData.prepareInBackground(enabled: Settings.shared.enabledLanguages)
        }
    }

    /// The main list of settings: the whole screen upright, the left column in landscape. Its search field finds any
    /// setting and takes the user to it.
    private var mainList: some View {
        ScrollViewReader { proxy in
            Group {
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    // Liquid Glass: glass cards on the tinted backdrop (Glass.swift).
                    GlassList {
                        HeaderSection()
                        TestFieldSection().glassRows()
                        // From what the keyboard offers, through how it types and feels, to the data and the app itself.
                        KeyboardSection().glassRows()
                        TypingSection().glassRows()
                        TouchSection().glassRows()
                        LookSection().glassRows()
                        DataSection().glassRows()
                        AppLanguageSection().glassRows()
                        AboutSection().glassRows()
                    }
                    .glassScreen()
                } else {
                    SettingsSearchResults(query: query) { entry in open(entry) }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: tr("Search settings"))
            .autocorrectionDisabled()
            .navigationTitle(tr("Iramo"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                guard returnToLanguageRow else { return }
                DispatchQueue.main.async { proxy.scrollTo(AppLanguageSection.rowID, anchor: .center) }
            }
        }
    }

    /// A setting picked in the search: its screen opens (in landscape, beside the list) and its row lights up.
    private func open(_ entry: SearchEntry) {
        if let anchor = entry.anchor {
            SearchFocus.shared.request = SearchFocus.Request(screen: entry.screen, anchor: anchor)
        }
        query = ""
        returnToLanguageRow = false
        guard let screen = entry.screen else { return }
        path = [screen]
    }

    /// Landscape: the main list as a column on the left; a row tapped there opens its screen on the right, where
    /// the screens it opens in turn are pushed. The same `path` as upright, so turning the device keeps the place.
    private var landscape: some View {
        HStack(spacing: 0) {
            NavigationStack { mainList }
                .frame(width: min(400, max(300, windowSize.width * 0.38)))
                .environment(\.openScreen, { screen in
                    returnToLanguageRow = false
                    path = [screen]
                })
                .environment(\.shownScreen, path.first)
            Divider().ignoresSafeArea()
            NavigationStack(path: Binding(get: { Array(path.dropFirst()) },
                                          set: { path = Array(path.prefix(1)) + $0 })) {
                Group {
                    if let screen = path.first {
                        screen.scopedView
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "keyboard")
                                .font(.system(size: 44, weight: .light))
                            Text(tr("Pick a setting on the left."))
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .glassScreen()
                    }
                }
                .navigationDestination(for: Screen.self) { $0.scopedView }
            }
            // Another screen picked on the left starts afresh.
            .id(path.first)
            .environment(\.openScreen, { screen in path.append(screen) })
        }
    }
}

// MARK: - Sections

/// The app icon, name and motto, and (only while something still needs doing) a note on setting it up.
private struct HeaderSection: View {
    @State private var status = KeyboardStatus.read()
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL

    var body: some View {
        Section {
            VStack(spacing: 10) {
                // The app icon (AppLogo is a small copy of it, written by scripts/make_icon.py), with the home
                // screen's corner shape.
                Image("AppLogo")
                    .resizable()
                    .frame(width: 78, height: 78)
                    .clipShape(RoundedRectangle(cornerRadius: 17.5, style: .continuous))
                    .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 5)
                    .background(
                        Circle().fill(.tint.opacity(0.45)).frame(width: 96, height: 96).blur(radius: 26))
                    .accessibilityHidden(true)
                Text(tr("Iramo")).font(.system(size: 36, weight: .heavy)).tracking(1.5)
                Text(tr("Your words, your keyboard"))
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .glassOutsideCard()

            // Only what still needs setting up is shown.
            if !status.isReady {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        IconTile(symbol: SharedStore.isShared ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath",
                                 color: SharedStore.isShared ? .orange : .red)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title).font(.headline)
                            Text(hint)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(.vertical, 6)
                .listRowBackground(GlassRowFill())
                if SharedStore.isShared, let url = URL(string: UIApplication.openSettingsURLString) {
                    // The app's own page in Settings lists Keyboards > Iramo and Allow Full Access.
                    Button {
                        Feedback.tap()
                        openURL(url)
                    } label: {
                        Text(tr("Open Settings"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .foregroundColor(.white)
                            .glassTile(Capsule(), isOn: true)
                    }
                    .buttonStyle(PressableStyle())
                    .glassOutsideCard()
                }
            }
        }
        // Read when the screen opens or the app comes back to the front - no polling.
        .onAppear { status = KeyboardStatus.read() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { status = KeyboardStatus.read() }
        }
    }

    private var title: String {
        if !SharedStore.isShared { return tr("Settings can't reach the keyboard") }
        return status.seen ? tr("Allow Full Access") : tr("Add the keyboard")
    }

    private var hint: String {
        if !SharedStore.isShared {
            return tr("This install can't share settings with the keyboard (no App Group). Install the IPA with iloader.")
        }
        if !status.seen {
            return tr("In Settings, open Keyboards, switch on Iramo and Allow Full Access, then open the keyboard once.")
        }
        return tr("Without it there is no vibration, and the keyboard can't save recent emoji or learned words.")
    }
}

private struct TestFieldSection: View {
    @State private var text = ""

    var body: some View {
        Section {
            HStack(spacing: 12) {
                IconTile(symbol: "keyboard", color: .gray)
                TextField(tr("Tap here and type to try it"), text: $text)
            }
            .searchAnchor("main.test")
        } header: {
            SectionHeader(tr("Try it"), symbol: "text.cursor", color: .gray)
        }
    }
}

/// What the keyboard offers: its languages, and the words, shortcuts, emoji and tools that come with them.
private struct KeyboardSection: View {
    // (A list can't be an @AppStorage value: read on appear, like the shortcuts.)
    @State private var languages = Settings.shared.enabledLanguages
    @State private var shortcutCount = Settings.shared.shortcuts.count
    @State private var learnedCount = 0

    private var languageSummary: String {
        let names = Language.list(from: languages).map { $0.localizedName }
        if names.count <= 2 { return names.joined(separator: ", ") }
        return "\(names[0]) +\(names.count - 1)"
    }

    var body: some View {
        Section {
            ScreenRow(.languages) {
                SettingsRow(title: tr("Languages"), symbol: "globe", color: .blue, value: languageSummary)
            }
            ScreenRow(.learnedWords) {
                SettingsRow(title: tr("Learned words"), symbol: "character.book.closed", color: .brown,
                            value: learnedCount > 0 ? "\(learnedCount)" : nil)
            }
            ScreenRow(.shortcuts) {
                SettingsRow(title: tr("Text shortcuts"), symbol: "bolt.fill", color: .orange,
                            value: shortcutCount > 0 ? "\(shortcutCount)" : nil)
            }
            ScreenRow(.functions) {
                SettingsRow(title: tr("Functions panel"), symbol: "square.grid.2x2.fill", color: .pink)
            }
        } header: {
            SectionHeader(tr("Keyboard"), symbol: "keyboard", color: .blue)
        } footer: {
            Text(tr("Swipe the space bar left or right to switch languages."))
        }
        .onAppear {
            languages = Settings.shared.enabledLanguages
            shortcutCount = Settings.shared.shortcuts.count
            learnedCount = Settings.shared.learnedWordList().count
        }
    }
}

/// The gestures on the keys.
private struct TouchSection: View {
    @State private var languages = Settings.shared.enabledLanguages
    @AppStorage(SettingKey.swipe, store: SharedStore.defaults) private var swipe = SettingDefault.swipe

    var body: some View {
        Section {
            ScreenRow(.gestures) {
                SettingsRow(title: tr("Gestures"), symbol: "hand.draw.fill", color: .teal,
                            value: swipe && !Language.lacking(.swipe, among: Language.list(from: languages)).all ? tr("Swipe on") : tr("Swipe off"))
            }
        } header: {
            SectionHeader(tr("Touch & gestures"), symbol: "hand.tap.fill", color: .teal)
        }
        .onAppear { languages = Settings.shared.enabledLanguages }
    }
}

/// How typing behaves: the corrections and capitals, and the suggestion bar.
private struct TypingSection: View {
    @AppStorage(SettingKey.suggestions, store: SharedStore.defaults) private var suggestions = SettingDefault.suggestions
    @AppStorage(SettingKey.suggestionFit, store: SharedStore.defaults) private var fit = SettingDefault.suggestionFit
    @AppStorage(SettingKey.suggestionScroll, store: SharedStore.defaults) private var scroll = SettingDefault.suggestionScroll
    @AppStorage(SettingKey.inlineMath, store: SharedStore.defaults) private var inlineMath = SettingDefault.inlineMath
    @AppStorage(SettingKey.unitConversion, store: SharedStore.defaults) private var units = SettingDefault.unitConversion

    private var smartSummary: String {
        switch (inlineMath, units) {
        case (true, true): return tr("On")
        case (false, false): return tr("Off")
        default: return tr("%@ on", "1")
        }
    }

    private var barSummary: String {
        if !suggestions { return tr("Off") }
        return scroll ? tr("Scrolling") : (fit ? tr("Fit to words") : tr("Three words"))
    }

    var body: some View {
        Section {
            ScreenRow(.suggestions) {
                SettingsRow(title: tr("Suggestion bar"), symbol: "text.line.first.and.arrowtriangle.forward", color: .indigo,
                            value: barSummary)
            }
            SettingToggle(tr("Auto-correction"), key: SettingKey.autoCorrect, defaultValue: SettingDefault.autoCorrect,
                          subtitle: tr("Fixes typos, accents and missing spaces on space"),
                          symbol: "checkmark.seal.fill", color: .green, feature: .autoCorrect)
                .searchAnchor("main.autocorrect")
            SettingToggle(tr("Auto-capitalization"), key: SettingKey.autoCapitalize, defaultValue: SettingDefault.autoCapitalize,
                          subtitle: tr("A capital at the start of each sentence"),
                          symbol: "textformat", color: .blue, feature: .capitals)
                .searchAnchor("main.autocap")
            SettingToggle(tr("\u{201C}.\u{201D} shortcut"), key: SettingKey.doubleSpacePeriod, defaultValue: SettingDefault.doubleSpacePeriod,
                          subtitle: tr("Tap the space bar twice to end a sentence"),
                          symbol: "circle.fill", color: .gray, feature: .sentencePeriod)
                .searchAnchor("main.period")
            SettingToggle(tr("Smart quotes"), key: SettingKey.smartQuotes, defaultValue: SettingDefault.smartQuotes,
                          subtitle: tr("Curly quotes and apostrophes in your language's style"),
                          symbol: "quote.opening", color: .teal)
                .searchAnchor("main.smartQuotes")
            SettingToggle(tr("Space after punctuation"), key: SettingKey.spaceAfterPunctuation,
                          defaultValue: SettingDefault.spaceAfterPunctuation,
                          subtitle: tr("A space goes after . , ! ? ; : by itself"),
                          symbol: "space", color: .mint)
                .searchAnchor("main.spaceAfter")
            ScreenRow(.smartTyping) {
                SettingsRow(title: tr("Calculator & units"), symbol: "function", color: .orange, value: smartSummary)
            }
        } header: {
            SectionHeader(tr("Typing"), symbol: "character.cursor.ibeam", color: .green)
        }
    }
}

/// The theme (its preview is on the Themes screen), the keys (with the number row and key pop-ups), effects,
/// haptics and the accent colour.
private struct LookSection: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.vibration, store: SharedStore.defaults) private var vibration = SettingDefault.vibration
    @AppStorage(SettingKey.hapticSharpness, store: SharedStore.defaults) private var sharpness = SettingDefault.hapticSharpness

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }
    private var theme: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    @AppStorage(SettingKey.effects, store: SharedStore.defaults) private var effectsJSON = SettingDefault.effects

    private var effectsSummary: String {
        let on = EffectsConfig.decode(effectsJSON).activeCount
        return on == 0 ? tr("Off") : tr("%@ on", "\(on)")
    }

    private var hapticSummary: String {
        if vibration < 0.01 { return tr("Off") }
        return [tr("Soft"), tr("Light"), tr("Medium"), tr("Firm"), tr("Crisp")][min(4, max(0, Int(sharpness * 5)))]
    }

    var body: some View {
        Section {
            ScreenRow(.themes) {
                SettingsRow(title: tr("Themes"), symbol: "paintbrush.fill", color: .purple, value: theme.name)
            }
            ScreenRow(.keys) {
                SettingsRow(title: tr("Keys"), symbol: "square.grid.3x2.fill", color: .blue, value: "\(Int(keyHeight.rounded())) pt")
            }
            ScreenRow(.effects) {
                SettingsRow(title: tr("Effects"), symbol: "sparkles", color: .indigo, value: effectsSummary)
            }
            ScreenRow(.haptics) {
                SettingsRow(title: tr("Haptics"), symbol: "iphone.radiowaves.left.and.right", color: .pink, value: hapticSummary)
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    IconTile(symbol: "drop.fill", color: accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tr("Accent colour"))
                        Text(tr("Return key and highlights of the themes."))
                            .font(.footnote).foregroundColor(.secondary)
                    }
                }
                AccentPicker()
            }
            .padding(.vertical, 2)
            .searchAnchor("main.accent")
        } header: {
            SectionHeader(tr("Look & feel"), symbol: "paintpalette.fill", color: .purple)
        }
    }
}

private struct DataSection: View {
    private enum Action: String {
        case learned, reset

        var title: String {
            switch self {
            case .learned: return tr("Forget learned words?")
            case .reset: return tr("Reset all settings?")
            }
        }

        var message: String {
            switch self {
            case .learned: return tr("Words the keyboard picked up while you type will be removed.")
            case .reset: return tr("Your shortcuts, recent emoji and learned words are kept.")
            }
        }

        var button: String {
            switch self {
            case .learned: return tr("Forget")
            case .reset: return tr("Reset")
            }
        }
    }

    @State private var pending: Action?
    @State private var note: String?

    var body: some View {
        Section {
            ScreenRow(.stats) {
                SettingsRow(title: tr("Typing stats"), symbol: "chart.bar.fill", color: .green)
            }
            // Orange: they remove things (each asks first), short of red Reset, which undoes every setting.
            row(.learned, tr("Forget learned words"), symbol: "text.book.closed", color: .orange)
                .searchAnchor("main.forget")
            row(.reset, tr("Reset all settings"), symbol: "arrow.counterclockwise", color: .red, role: .destructive)
                .searchAnchor("main.reset")
            if let note = note {
                Text(note).font(.footnote).foregroundColor(.secondary)
            }
        } header: {
            SectionHeader(tr("Privacy & data"), symbol: "hand.raised.fill", color: .gray)
        } footer: {
            Text(tr("Everything the keyboard learns stays on this device."))
        }
    }

    /// One option with its own confirmation, so the dialog's arrow points at the option that was tapped.
    private func row(_ action: Action, _ title: String, symbol: String, color: Color, role: ButtonRole? = nil) -> some View {
        Button(role: role) {
            // Resetting everything warns with a long, strong buzz before the question; the others a soft tap.
            if action == .reset { Feedback.danger() } else { Feedback.tap() }
            pending = action
        } label: {
            HStack(spacing: 12) {
                IconTile(symbol: symbol, color: color)
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundColor(role == .destructive ? .red : color)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())   // the whole row takes the tap, not only the text
        }
            .confirmationDialog(action.title,
                                isPresented: Binding(get: { pending == action }, set: { if !$0 { pending = nil } }),
                                titleVisibility: .visible) {
                Button(action.button, role: .destructive) { perform(action) }
                Button(tr("Cancel"), role: .cancel) {}
            } message: {
                Text(action.message)
            }
    }

    private func perform(_ action: Action) {
        switch action {
        case .learned:
            Settings.shared.clearLearnedWords()
            note = tr("Learned words forgotten.")
        case .reset:
            Settings.shared.resetPreferences()
            NotificationCenter.default.post(name: .hunKeysSettingsReset, object: nil)
            note = tr("Settings reset to defaults.")
        }
        if action == .reset { Feedback.warning() } else { Feedback.delete() }
    }
}

/// Credits and licences for the word data, emoji data and icons the app ships (LicensesView).
private struct AboutSection: View {
    @AppStorage(SettingKey.welcomeSeen, store: SharedStore.defaults) private var welcomeSeen = false

    var body: some View {
        Section {
            Button {
                Feedback.tap()
                welcomeSeen = false
            } label: {
                SettingsRow(title: tr("Replay welcome"), symbol: "play.circle.fill", color: .blue)
                    .foregroundColor(.primary)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .searchAnchor("main.welcome")
            ScreenRow(.licences) {
                SettingsRow(title: tr("Licences"), symbol: "doc.text.fill", color: .gray)
            }
        } header: {
            SectionHeader(tr("About"), symbol: "info.circle", color: .gray)
        } footer: {
            Text(tr("Iramo. Copyright \u{00A9} 2026 Ors\u{00F3}s Emil."))
        }
    }
}

/// The app's own language, last on the main screen: a row showing the chosen one, opening the list to pick it from.
private struct AppLanguageSection: View {
    @AppStorage(SettingKey.appLanguage, store: SharedStore.defaults) private var appLanguage = SettingDefault.appLanguage

    /// The row's place in the main list, scrolled back to after the app is built again in a new language.
    static let rowID = "appLanguageRow"

    private var chosenName: String {
        guard appLanguage != AppLanguage.system, let language = Language(rawValue: appLanguage) else {
            return tr("System")
        }
        return language.localizedName
    }

    var body: some View {
        Section {
            ScreenRow(.appLanguage) {
                SettingsRow(title: tr("App language"), symbol: "globe", color: .blue, value: chosenName)
            }
            .id(AppLanguageSection.rowID)   // on the row itself, so a List finds it too
        } header: {
            SectionHeader(tr("Language"), symbol: "character.bubble.fill", color: .blue)
        } footer: {
            Text(tr("The language of this app. The keyboard's typing languages are set under Languages."))
        }
    }
}

/// Picks the app's language: the phone's or any of the keyboard's languages, each named in the app's current
/// language (with its own name beside it, to find one's way back). Choosing one builds the app again in it; the
/// list then opens again where it was, at the chosen language.
struct AppLanguageView: View {
    @AppStorage(SettingKey.appLanguage, store: SharedStore.defaults) private var appLanguage = SettingDefault.appLanguage

    private func name(_ language: Language) -> String {
        let name = language.localizedName
        return name == language.displayName ? name : "\(name) (\(language.displayName))"
    }

    private func row(_ code: String, _ title: String) -> some View {
        Button {
            guard code != appLanguage else { return }
            Feedback.choose()
            appLanguage = code
        } label: {
            HStack {
                Text(title).foregroundColor(.primary)
                Spacer()
                if code == appLanguage {
                    Image(systemName: "checkmark").font(.body.weight(.semibold))
                }
            }
            .contentShape(Rectangle())
        }
        .id(code)
    }

    var body: some View {
        ScrollViewReader { proxy in
            GlassList {
                Section {
                    row(AppLanguage.system, tr("System (%@)", "\(AppLanguage.systemLanguage.localizedName)"))
                    ForEach(Language.byName(Language.allCases), id: \.rawValue) { language in
                        row(language.rawValue, name(language))
                    }
                } footer: {
                    Text(tr("The language of this app. The keyboard's typing languages are set under Languages."))
                }
                .glassRows()
            }
            .glassScreen()
            .onAppear {
                // At the chosen language (also when the screen is built again after a change).
                DispatchQueue.main.async { proxy.scrollTo(appLanguage, anchor: .center) }
            }
        }
        .navigationTitle(tr("App language"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Screens

/// The screens the main list opens.
enum Screen: Hashable {
    case languages, appLanguage, suggestions, gestures, shortcuts, functions, themes, themeEditor, keys, effects, haptics, learnedWords, licences
    case smartTyping, stats, longPress
    /// The letter layout of one language (its code).
    case languageLayout(String)

    /// The screen, marked as itself for the settings search (SearchFocus).
    var scopedView: some View {
        return view.environment(\.searchScope, self)
    }

    @ViewBuilder var view: some View {
        switch self {
        case .smartTyping: SmartTypingView()
        case .stats: StatsView()
        case .longPress: LongPressCharactersView()
        case .languageLayout(let code): LanguageLayoutView(language: Language(rawValue: code) ?? .english)
        case .languages: LanguagesView()
        case .appLanguage: AppLanguageView()
        case .suggestions: SuggestionsView()
        case .gestures: GesturesView()
        case .shortcuts: ShortcutsView()
        case .functions: FunctionsView()
        case .themes: ThemesView()
        case .themeEditor: ThemeEditorView()
        case .keys: KeysView()
        case .effects: EffectsView()
        case .haptics: HapticsView()
        case .learnedWords: LearnedWordsView()
        case .licences: LicensesView()
        }
    }
}

private struct OpenScreenKey: EnvironmentKey {
    static let defaultValue: (Screen) -> Void = { _ in }
}

private struct ShownScreenKey: EnvironmentKey {
    static let defaultValue: Screen? = nil
}

extension EnvironmentValues {
    /// The screen open beside the main list in landscape (its row is marked).
    var shownScreen: Screen? {
        get { return self[ShownScreenKey.self] }
        set { self[ShownScreenKey.self] = newValue }
    }

    /// Opens a screen of the main list (set by ContentView).
    var openScreen: (Screen) -> Void {
        get { return self[OpenScreenKey.self] }
        set { self[OpenScreenKey.self] = newValue }
    }
}

/// A row that opens a screen: the whole row is one button (a soft tap, then the screen), with the disclosure arrow
/// on the right. A plain button rather than a NavigationLink with an extra tap gesture, which in a list could take
/// the tap and leave the screen unopened.
struct ScreenRow<Label: View>: View {
    let screen: Screen
    @ViewBuilder let label: () -> Label
    @Environment(\.openScreen) private var openScreen
    @Environment(\.shownScreen) private var shownScreen

    init(_ screen: Screen, @ViewBuilder label: @escaping () -> Label) {
        self.screen = screen
        self.label = label
    }

    var body: some View {
        Button {
            Feedback.tap()
            openScreen(screen)
        } label: {
            HStack(spacing: 8) {
                label()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(shownScreen == screen ? .accentColor : Color(.tertiaryLabel))
            }
            .foregroundColor(.primary)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Status

struct KeyboardStatus {
    var seen: Bool
    var fullAccess: Bool

    static func read() -> KeyboardStatus {
        let store = SharedStore.defaults
        return KeyboardStatus(seen: store.double(forKey: SettingKey.lastSeen) > 0,
                              fullAccess: store.bool(forKey: SettingKey.fullAccess))
    }

    /// Nothing left to set up: the header then shows no chips or hint.
    var isReady: Bool { return seen && fullAccess && SharedStore.isShared }
}

// MARK: - Shortcuts

struct ShortcutsView: View {
    @State private var items: [TextShortcut] = Settings.shared.shortcuts
    @State private var trigger = ""
    @State private var phrase = ""
    @AppStorage(SettingKey.dateFormat, store: SharedStore.defaults) private var dateFormat = SettingDefault.dateFormat
    @AppStorage(SettingKey.customDateFormat, store: SharedStore.defaults) private var customDate = SettingDefault.customDateFormat
    @AppStorage(SettingKey.timeFormat, store: SharedStore.defaults) private var timeFormat = SettingDefault.timeFormat
    @AppStorage(SettingKey.timeSeconds, store: SharedStore.defaults) private var timeSeconds = SettingDefault.timeSeconds

    private let dateStyles = ["short", "medium", "long", "full", "iso", "custom"]
    private let timeStyles = ["system", "24h", "12h"]

    /// Dates are written in the words of the language the keyboard opens in.
    private var locale: Locale {
        return Locale(identifier: LiveKeyboardView.openingLanguage(code: Settings.shared.languageCode).localeIdentifier)
    }

    /// The phrase as typing its trigger writes it today ({cursor} shown as a thin bar).
    private var filledPhrase: String {
        let written = phrase.trimmingCharacters(in: .whitespaces)
        guard ShortcutTemplate.hasPlaceholders(written) else { return written }
        Settings.shared.refresh()   // the formats just picked, not the half-second-old copy
        let expanded = ShortcutTemplate.expand(written, locale: locale) { tr("copied text") }
        return expanded.replacingOccurrences(of: String(ShortcutTemplate.cursorMark), with: "\u{258F}")
    }

    private func dateExample(_ style: String) -> String {
        return ShortcutTemplate.dateText(Date(), locale: locale, style: style, custom: customDate)
    }

    private var canAdd: Bool {
        return !trigger.trimmingCharacters(in: .whitespaces).isEmpty
            && !phrase.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // A Liquid Glass list like the main screen's (the shortcuts swipe to delete); the example of the shortcut being
    // typed stays pinned above it (PinnedPreview).
    var body: some View {
        PinnedPreview(height: 110) {
            ShortcutPreview(trigger: trigger, phrase: filledPhrase)
        } content: {
        GlassList {
            Section {
                TextField(tr("Trigger (e.g. omw)"), text: $trigger)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                TextField(tr("Phrase (e.g. On my way!)"), text: $phrase)
            } header: {
                Text(tr("New shortcut"))
            }
            .glassRows()

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(ShortcutTemplate.placeholders, id: \.token) { item in
                            Button {
                                Feedback.tick()
                                phrase += (phrase.isEmpty || phrase.hasSuffix(" ") ? "" : " ") + item.token
                            } label: {
                                VStack(spacing: 2) {
                                    Text(item.token).font(.subheadline.monospaced().weight(.semibold))
                                    Text(tr(item.note)).font(.caption2).foregroundColor(.secondary)
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .glassShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .searchAnchor("shortcuts.placeholders")
            } header: {
                Text(tr("Placeholders"))
            } footer: {
                Text(tr("Tap one to add it to the phrase. They are filled in when you type the shortcut: \u{201C}Sent {date}\u{201D} writes today's date."))
            }
            .glassRows()

            Section {
                Button(action: add) {
                    Text(tr("Add shortcut"))
                        .font(.body.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .glassTile(Capsule(), isOn: true)
                        .contentShape(Capsule())
                }
                .buttonStyle(PressableStyle())
                .disabled(!canAdd)
                .opacity(canAdd ? 1 : 0.45)
                .glassOutsideCard()
            }
            .glassRows()

            Section {
                if items.isEmpty {
                    Text(tr("None yet")).foregroundColor(.secondary)
                } else {
                    ForEach(items, id: \.id) { item in
                        VStack(alignment: .leading) {
                            Text(item.trigger).font(.headline)
                            Text(item.phrase).font(.subheadline).foregroundColor(.secondary)
                        }
                        .padding(.vertical, 2)
                        .swipeToDelete { remove(item) }
                    }
                }
            } header: {
                Text(tr("Your shortcuts"))
            } footer: {
                if !items.isEmpty { Text(tr("Swipe a shortcut left to remove it.")) }
            }
            .glassRows()

            Section {
                GlassChoiceLink(title: tr("Date format"), symbol: "calendar",
                                options: dateStyles.map { (value: $0, name: $0 == "custom" ? tr("Custom") : dateExample($0)) },
                                selected: dateFormat) { dateFormat = $0 }
                    .searchAnchor("shortcuts.date")
                if dateFormat == "custom" {
                    HStack {
                        Text(tr("Pattern"))
                        Spacer()
                        TextField("yyyy-MM-dd", text: $customDate)
                            .multilineTextAlignment(.trailing)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .font(.body.monospaced())
                    }
                    Text(dateExample("custom")).font(.footnote).foregroundColor(.secondary)
                }
                SegmentedChoice(title: tr("Time format"), names: [tr("System"), tr("24-hour"), tr("12-hour")],
                                selected: timeStyles.firstIndex(of: timeFormat)) { timeFormat = timeStyles[$0] }
                    .searchAnchor("shortcuts.time")
                GlassToggle(title: tr("Seconds"), subtitle: ShortcutTemplate.timeText(Date(), locale: locale, style: timeFormat, seconds: timeSeconds),
                            isOn: $timeSeconds)
            } header: {
                Text(tr("Date and time"))
            } footer: {
                Text(dateFormat == "custom"
                     ? tr("Letters stand for parts of the date: yyyy year, MM month, MMMM month's name, dd day, EEEE weekday.")
                     : tr("How {date}, {time} and {datetime} are written, in the words of your keyboard's language."))
            }
            .glassRows()
        }
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(tr("Text shortcuts"))
        .navigationBarTitleDisplayMode(.inline)
        // Read again on every visit: the screen is built once with the parent, so the starting value above is
        // from when the app opened.
        .onAppear { items = Settings.shared.shortcuts }
    }

    private func add() {
        let key = trigger.trimmingCharacters(in: .whitespaces)
        let text = phrase.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty, !text.isEmpty else { return }
        items.removeAll { $0.trigger.lowercased() == key.lowercased() }
        items.append(TextShortcut(trigger: key, phrase: text))
        save()
        Feedback.success()
        trigger = ""
        phrase = ""
    }

    private func remove(_ item: TextShortcut) {
        Feedback.delete()
        withAnimation(.easeOut(duration: 0.2)) { items.removeAll { $0.id == item.id } }
        save()
    }

    private func save() {
        Settings.shared.shortcuts = items
    }
}

// MARK: - Languages

/// The enabled languages only; more are added from a separate list. A Liquid Glass list like the main screen's;
/// a language swipes left to delete, the Delete button inside its row.
struct LanguagesView: View {
    @State private var enabled: [String] = Settings.shared.enabledLanguages
    /// The layout picked for each language (read again on every visit, as the languages are).
    @State private var layouts: [String: String] = Settings.shared.letterLayouts

    /// In alphabetical order (a list saved here is stored in that order too).
    private var languages: [Language] { return Language.byName(enabled.compactMap { Language(rawValue: $0) }) }

    var body: some View {
        GlassList {
            Section {
                ForEach(languages, id: \.rawValue) { language in
                    LanguageRow(language: language, layouts: layouts)
                        .swipeToDelete(enabled: languages.count > 1) { remove(language) }
                }
                .searchAnchor("languages.list")
            } footer: {
                Text(tr("Swipe the space bar left or right to switch. Tap a language to change its keyboard layout; swipe it left to remove it."))
            }
            .glassRows()

            if enabled.count < Language.allCases.count {
                Section {
                    NavigationLink {
                        AddLanguageView(enabled: enabled) { language in
                            save(enabled + [language.rawValue])
                        }
                    } label: {
                        HStack {
                            Label(tr("Add a language"), systemImage: "plus")
                            Spacer()
                            DisclosureChevron()
                        }
                        .contentShape(Rectangle())
                    }
                }
                .glassRows()
            }
        }
        .glassScreen()
        .navigationTitle(tr("Languages"))
        .navigationBarTitleDisplayMode(.inline)
        // Read again on every visit: the screen is built once with the parent, so the starting value above is
        // from when the app opened (reopening it showed the languages of that moment).
        .onAppear {
            enabled = Settings.shared.enabledLanguages
            layouts = Settings.shared.letterLayouts
        }
    }

    private func remove(_ language: Language) {
        guard enabled.count > 1 else { return }
        save(enabled.filter { $0 != language.rawValue })
    }

    private func save(_ list: [String]) {
        let ordered = Language.byName(Language.allCases.filter { list.contains($0.rawValue) }).map { $0.rawValue }
        guard !ordered.isEmpty, ordered != enabled else { return }
        if ordered.count > enabled.count { Feedback.success() } else { Feedback.delete() }
        withAnimation(.easeOut(duration: 0.2)) { enabled = ordered }
        Settings.shared.enabledLanguages = ordered
        LanguageData.prepareInBackground(enabled: ordered)
    }
}

/// A language in the Languages list: its name and its letter layout, opening the layout screen (languages that are
/// not written with a-z keep their own layout and open nothing).
private struct LanguageRow: View {
    let language: Language
    let layouts: [String: String]

    var body: some View {
        if language.supportsOtherLayouts {
            ScreenRow(.languageLayout(language.rawValue)) {
                HStack {
                    Text(language.localizedName)
                    Spacer(minLength: 8)
                    Text(tr(LetterLayout.stored(in: layouts, for: language.rawValue).displayName))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        } else {
            Text(language.localizedName)
        }
    }
}

/// The languages that are not enabled yet; picking one adds it and goes back.
private struct AddLanguageView: View {
    let enabled: [String]
    let add: (Language) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GlassList {
            ForEach(Language.byName(Language.allCases.filter { !enabled.contains($0.rawValue) }), id: \.rawValue) { language in
                Button {
                    add(language)
                    dismiss()
                } label: {
                    Text(language.localizedName)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
            }
            .glassRows()
        }
        .glassScreen()
        .navigationTitle(tr("Add a language"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Learned words

/// Words the keyboard learned (ones no dictionary has, used at least twice), one list for every language, with a
/// search field and swipe to remove.
struct LearnedWordsView: View {
    /// The stored (lower-case) word, and how it is written.
    @State private var words: [(word: String, shown: String)] = []
    @State private var query = ""

    /// The words that match the search.
    private var matches: [(word: String, shown: String)] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return words }
        return words.filter { $0.shown.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive]) != nil }
    }

    // A Liquid Glass list like the main screen's; a word swipes left to delete.
    var body: some View {
        GlassList {
            Section {
                if words.isEmpty {
                    Text(tr("No learned words yet")).foregroundColor(.secondary)
                } else if matches.isEmpty {
                    Text(tr("No matching words")).foregroundColor(.secondary)
                } else {
                    ForEach(matches, id: \.word) { entry in
                        Text(entry.shown)
                            .swipeToDelete { remove(entry.word) }
                    }
                }
            } footer: {
                if words.isEmpty {
                    Text(tr("A word that isn't in the dictionary is learned once you have typed it twice, or when you tap it in the suggestion bar. Learned words work in every language."))
                } else if !matches.isEmpty {
                    Text(tr("Learned words work in every language. Swipe a word left to remove it."))
                }
            }
            .glassRows()
        }
        .glassScreen()
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: tr("Search learned words"))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
        .navigationTitle(tr("Learned words"))
        .navigationBarTitleDisplayMode(.inline)
        // Reloaded on every visit: a NavigationLink builds this view's initial state only once.
        .onAppear { words = Settings.shared.learnedWordEntries() }
    }

    private func remove(_ word: String) {
        Settings.shared.removeLearnedWord(word)
        Feedback.delete()
        withAnimation(.easeOut(duration: 0.2)) { words.removeAll { $0.word == word } }
    }
}

/// What a shortcut does, as the suggestion bar shows it: the trigger typed (on a key of the theme), then the phrase
/// space will write (on the theme's accent pill).
private struct ShortcutPreview: View {
    let trigger: String
    let phrase: String

    var body: some View {
        let typed = trigger.trimmingCharacters(in: .whitespaces)
        let written = phrase.trimmingCharacters(in: .whitespaces)
        PreviewCard(caption: tr("Type the trigger and press space: the phrase takes its place.")) {
            CurrentThemeLook { look in
                HStack(spacing: 10) {
                    Text(typed.isEmpty ? "omw" : typed)
                        .font(.system(size: 15, design: .monospaced))
                        .foregroundColor(look.textColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(look.keyShape(.letter, radius: 8))
                    Image(systemName: "arrow.right")
                        .foregroundColor(look.stripText.opacity(0.6))
                    Text(written.isEmpty ? tr("On my way!") : written)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .foregroundColor(look.onAccent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(look.pill(radius: 15))
                }
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .opacity(typed.isEmpty && written.isEmpty ? 0.6 : 1)
            }
        }
    }
}

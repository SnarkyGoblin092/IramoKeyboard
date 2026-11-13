import SwiftUI
import UIKit

// MARK: - The tabs' lists
//
// Each tab opens with one short list: the rows that open its screens (each showing what it is set to) and the few
// settings used often enough to sit there themselves. Every section is its own small view, so changing one control
// only redraws that section.

// MARK: Typing

/// What the keyboard writes: a place to try it, its languages and the helpers that come with them, and the
/// corrections it makes while typing.
struct TypingTab: View {
    var body: some View {
        GlassList(eager: true) {
            TryFieldSection().glassRows()
            KeyboardSection().glassRows()
            CorrectionsSection().glassRows()
        }
        .tabScreen()
        .scrollDismissesKeyboard(.interactively)
        .environment(\.searchScope, AppTab.typing.scope)
        .navigationTitle(AppTab.typing.title)
        .navigationBarTitleDisplayMode(.inline)
        .quietNavBar()
    }
}

/// A field to type in: the keyboard is one tap away from the moment the app opens.
private struct TryFieldSection: View {
    @State private var text = ""

    var body: some View {
        Section {
            tryField
                .searchAnchor("main.test")
        }
    }

    private var tryField: some View {
        HStack(spacing: 10) {
            Image(systemName: "character.cursor.ibeam")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            TextField(tr("Tap here and type to try it"), text: $text, axis: .vertical)
                .lineLimit(1...4)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(tr("Clear"))
            }
        }
    }
}

/// The app's mark and slogan on a glass card, whether the keyboard is ready, and while something still needs
/// setting up, what it is and the way to Settings.
private struct BrandSection: View {
    @State private var status = KeyboardStatus.read()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section {
            brand
            if !status.isReady {
                setup
            }
        }
        // Read when the screen opens or the app comes back to the front - no polling.
        .onAppear { status = KeyboardStatus.read() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { status = KeyboardStatus.read() }
        }
    }

    private var brand: some View {
        HStack(spacing: 14) {
            // The app icon (AppLogo is a small copy of it, written by scripts/make_icon.py), with the home
            // screen's corner shape.
            Image("AppLogo")
                .resizable()
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(tr("Iramo")).font(.title3.weight(.bold))
                Text(tr("Your words, your keyboard"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if status.isReady {
                    StatusChip(text: tr("Ready to type"), symbol: "checkmark.circle.fill", color: .green)
                } else {
                    // A tap goes to the app's page in Settings, where the keyboard and Full Access are switched on.
                    Button {
                        Feedback.tap()
                        KeyboardStatus.openSettings()
                    } label: {
                        StatusChip(text: title, symbol: "exclamationmark.triangle.fill",
                                   color: SharedStore.isShared ? .orange : .red)
                    }
                    .buttonStyle(.plain)
                    .disabled(!SharedStore.isShared)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }

    /// What is still to do, and the way there.
    private var setup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(hint)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private var title: String {
        if !SharedStore.isShared { return tr("Settings can't reach the keyboard") }
        return status.seen ? tr("Full Access is off") : tr("Keyboard not enabled")
    }

    private var hint: String {
        if !SharedStore.isShared {
            return tr("This install can't share settings with the keyboard (no App Group). Install the IPA with iloader.")
        }
        if !status.seen {
            return tr("In Settings, open Keyboards, switch on Iramo and Allow Full Access, then open the keyboard once.")
        }
        return tr("Switch on Allow Full Access in Settings, then open the keyboard once to confirm. Without it there is no vibration, and the keyboard can't save recent emoji or learned words.")
    }
}

/// The keyboard's languages (their codes on keycaps), and the words, shortcuts and sums that come with them.
private struct KeyboardSection: View {
    // (A list can't be an @AppStorage value: read on appear, like the shortcuts.)
    @State private var languages = Settings.shared.enabledLanguages
    @State private var shortcutCount = Settings.shared.shortcuts.count
    @State private var learnedCount = 0
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

    /// The first few languages' codes, each on a keycap, and how many more there are.
    private var languageCaps: some View {
        let list = Language.list(from: languages)
        let shown = Array(list.prefix(3))
        return HStack(spacing: 5) {
            ForEach(shown, id: \.rawValue) { language in
                KeycapLabel(text: language.rawValue.uppercased(), size: 28)
            }
            if list.count > shown.count {
                Text("+\(list.count - shown.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(list.map { $0.localizedName }.joined(separator: ", "))
    }

    var body: some View {
        Section {
            ScreenRow(.languages) {
                HStack(spacing: 12) {
                    IconTile(symbol: "globe", color: .blue)
                    Text(tr("Languages"))
                    Spacer(minLength: 8)
                    languageCaps
                }
                .padding(.vertical, 2)
            }
            ScreenRow(.suggestions) {
                SettingsRow(title: tr("Suggestion bar"), symbol: "text.line.first.and.arrowtriangle.forward", color: .indigo, value: barSummary)
            }
            ScreenRow(.shortcuts) {
                SettingsRow(title: tr("Text shortcuts"), symbol: "bolt.fill", color: .orange,
                            value: shortcutCount > 0 ? "\(shortcutCount)" : tr("None"))
            }
            ScreenRow(.smartTyping) {
                SettingsRow(title: tr("Calculator & units"), symbol: "function", color: .cyan, value: smartSummary)
            }
            ScreenRow(.emoji) {
                SettingsRow(title: tr("Emoji"), symbol: "face.smiling.fill", color: .yellow)
            }
            ScreenRow(.learnedWords) {
                SettingsRow(title: tr("Learned words"), symbol: "character.book.closed", color: .brown,
                            value: learnedCount > 0 ? "\(learnedCount)" : nil)
            }
        } header: {
            SectionHeader(tr("Keyboard"), symbol: "keyboard", color: .blue)
        }
        .onAppear {
            languages = Settings.shared.enabledLanguages
            shortcutCount = Settings.shared.shortcuts.count
            // Counted without putting them in order (this runs every time the tab is shown).
            learnedCount = Settings.shared.learnedWords().filter { $0.value >= 2 }.count
        }
    }
}

/// What the keyboard puts right by itself while typing.
private struct CorrectionsSection: View {
    var body: some View {
        Section {
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
            SettingToggle(tr("Space after suggestions"), key: SettingKey.spaceAfterSuggestion,
                          defaultValue: SettingDefault.spaceAfterSuggestion,
                          subtitle: tr("A space goes after a word picked in the suggestion bar"),
                          symbol: "space", color: .cyan)
                .searchAnchor("main.spaceAfterSuggestion")
        } header: {
            SectionHeader(tr("Typing"), symbol: "character.cursor.ibeam", color: .green)
        }
    }
}

// MARK: Look

/// How the keyboard looks: its theme (drawn as it is now), its keys, the effects and the accent colour.
struct LookTab: View {
    var body: some View {
        GlassList(eager: true) {
            ThemeSection().glassRows()
            KeysAndEffectsSection().glassRows()
            AccentSection().glassRows()
        }
        .tabScreen()
        .environment(\.searchScope, AppTab.look.scope)
        .navigationTitle(AppTab.look.title)
        .navigationBarTitleDisplayMode(.inline)
        .quietNavBar()
    }
}

/// The chosen theme, drawn as the keyboard has it: a tap on it or on the row under it opens the themes; the last
/// row, the theme's editor.
private struct ThemeSection: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.systemEdits, store: SharedStore.defaults) private var systemEdits = SettingDefault.systemEdits
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @Environment(\.openScreen) private var openScreen

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }

    /// The theme with its edits (read again when they change).
    private var theme: ThemeDefinition {
        _ = systemEdits
        return ThemeCatalog.theme(id: themeID)
    }

    var body: some View {
        let shown = theme
        Section {
            // The keyboard as the theme draws it, standing on the backdrop: the Liquid Glass theme's keys are real
            // glass here too, as on the keyboard. A new accent fades in on it.
            Button {
                Feedback.tap()
                openScreen(.themes)
            } label: {
                ZStack {
                    ThemePreview(theme: shown, accent: accent, showsStrip: false, cornerRadius: 20)
                        .aspectRatio(ThemePreview.aspectKeysOnly, contentMode: .fit)
                        .animation(AccentTint.fade, value: accentName + accentHex)
                        .allowsHitTesting(false)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .accessibilityLabel(tr("Themes"))
            .glassOutsideCard()
            AppearanceSwitch()
            ScreenRow(.themes) {
                SettingsRow(title: tr("Themes"), symbol: "paintbrush.fill", color: .purple, value: shown.name)
            }
            ScreenRow(.themeEditor) {
                SettingsRow(title: tr("Customize %@", "\(shown.name)"), symbol: "slider.horizontal.3", color: .pink)
            }
        }
    }
}

/// The light / dark switch (Auto follows the phone), under the keyboard preview. Changing the mode sends the same
/// wave across the window as the Themes screen's switch, spreading out from where the finger touched.
private struct AppearanceSwitch: View {
    @AppStorage(SettingKey.appearance, store: SharedStore.defaults) private var mode = SettingDefault.appearance
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @Environment(\.colorScheme) private var colorScheme
    /// The mode just picked while its wave is setting off: the switch shows it at once.
    @State private var pending: String?
    @State private var running = false
    @State private var touches = TouchPoint()

    private var scheme: ColorScheme {
        return mode == "light" ? .light : (mode == "dark" ? .dark : colorScheme)
    }

    var body: some View {
        let shown = pending ?? mode
        SegmentedChoice(names: [tr("Auto"), tr("Light"), tr("Dark")],
                        selected: shown == "light" ? 1 : (shown == "dark" ? 2 : 0)) {
            switchMode(["auto", "light", "dark"][$0])
        }
        .background(TouchRecorder(touches: touches))
    }

    private func switchMode(_ new: String) {
        guard !running, pending == nil, new != mode else { return }
        // Auto follows the system's mode (the screen's traits, which the app's own override does not touch).
        let dark = new == "auto" ? UIScreen.main.traitCollection.userInterfaceStyle == .dark : new == "dark"
        guard (scheme == .dark) != dark, let window = WindowWave.window, !UIAccessibility.isReduceMotionEnabled else {
            mode = new
            return
        }
        pending = new
        let source = touches.point ?? CGPoint(x: window.bounds.midX, y: window.bounds.midY)
        let oldScheme = scheme
        let theme = themeID
        // Once the switch has played its little slide to the new choice.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            ModeWave.count += 1
            let id = ModeWave.count
            let frame = window.bounds
            let wave = ModeWave(id: id, oldScheme: oldScheme, newScheme: dark ? .dark : .light, oldTheme: theme,
                                newTheme: theme, source: source, minX: frame.minX, minY: frame.minY,
                                width: frame.width, height: frame.height, started: CACurrentMediaTime(), startedDate: Date())
            running = true
            WindowWave.start(for: wave)
            ModeWave.running.append(wave)
            mode = new
            pending = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(wave.lifetime * 1_000_000_000))
                ModeWave.running.removeAll { $0.id == id }
                running = false
            }
        }
    }
}

private struct KeysAndEffectsSection: View {
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.effects, store: SharedStore.defaults) private var effectsJSON = SettingDefault.effects

    private var effectsSummary: String {
        let on = EffectsConfig.decode(effectsJSON).activeCount
        return on == 0 ? tr("Off") : tr("%@ on", "\(on)")
    }

    var body: some View {
        Section {
            ScreenRow(.keys) {
                SettingsRow(title: tr("Keys"), symbol: "square.grid.3x2.fill", color: .blue, value: "\(Int(keyHeight.rounded())) pt")
            }
            ScreenRow(.effects) {
                SettingsRow(title: tr("Effects"), symbol: "sparkles", color: .orange, value: effectsSummary)
            }
        }
    }
}

/// The accent colour: the return key and highlights of the themes, and the colour the app itself wears.
private struct AccentSection: View {
    var body: some View {
        Section {
            AccentPicker()
                .searchAnchor("main.accent")
        } header: {
            SectionHeader(tr("Accent colour"), symbol: "drop.fill")
        } footer: {
            Text(tr("Return key and highlights of the themes."))
        }
    }
}

// MARK: Touch

/// How the keyboard answers the fingers: the gestures, how they feel and sound, and what the keys and the
/// functions panel offer when held or opened.
struct TouchTab: View {
    var body: some View {
        GlassList(eager: true) {
            GesturesSection().glassRows()
            HoldsSection().glassRows()
        }
        .tabScreen()
        .environment(\.searchScope, AppTab.touch.scope)
        .navigationTitle(AppTab.touch.title)
        .navigationBarTitleDisplayMode(.inline)
        .quietNavBar()
    }
}

/// The gestures on the keys, and how they feel.
private struct GesturesSection: View {
    @State private var languages = Settings.shared.enabledLanguages
    @AppStorage(SettingKey.swipe, store: SharedStore.defaults) private var swipe = SettingDefault.swipe
    @AppStorage(SettingKey.vibration, store: SharedStore.defaults) private var vibration = SettingDefault.vibration
    @AppStorage(SettingKey.hapticSharpness, store: SharedStore.defaults) private var sharpness = SettingDefault.hapticSharpness
    @AppStorage(SettingKey.tapAdaptive, store: SharedStore.defaults) private var adaptive = SettingDefault.tapAdaptive

    private var hapticSummary: String {
        if vibration < 0.01 { return tr("Off") }
        return [tr("Soft"), tr("Light"), tr("Medium"), tr("Firm"), tr("Crisp")][min(4, max(0, Int(sharpness * 5)))]
    }

    private var swipeSummary: String {
        let cannot = Language.lacking(.swipe, among: Language.list(from: languages)).all
        return swipe && !cannot ? tr("Swipe on") : tr("Swipe off")
    }

    var body: some View {
        Section {
            ScreenRow(.gestures) {
                SettingsRow(title: tr("Gestures"), symbol: "hand.draw.fill", color: .teal, value: swipeSummary)
            }
            ScreenRow(.haptics) {
                SettingsRow(title: tr("Haptics & sound"), symbol: "iphone.radiowaves.left.and.right", color: .pink, value: hapticSummary)
            }
            ScreenRow(.tapAccuracy) {
                SettingsRow(title: tr("Tap accuracy"), symbol: "scope", color: .orange, value: adaptive ? tr("Adaptive") : tr("Off"))
            }
        } header: {
            SectionHeader(tr("Touch & gestures"), symbol: "hand.tap.fill", color: .teal)
        }
        .onAppear { languages = Settings.shared.enabledLanguages }
    }
}

/// The characters of the user's own on the keys' holds, and the tools on the functions panel.
private struct HoldsSection: View {
    /// How many keys have characters of the user's own, and how many tools the panel shows (read on every visit).
    @State private var holdCount = Settings.shared.customHolds.count
    @State private var toolCount = 0

    var body: some View {
        Section {
            ScreenRow(.longPress) {
                SettingsRow(title: tr("Long-press characters"), symbol: "hand.point.up.left.fill", color: .purple,
                            value: holdCount == 0 ? tr("None") : "\(holdCount)")
            }
            ScreenRow(.functions) {
                SettingsRow(title: tr("Functions panel"), symbol: "square.grid.2x2.fill", color: .indigo, value: "\(toolCount)")
            }
        } header: {
            SectionHeader(tr("Keyboard"), symbol: "keyboard", color: .blue)
        } footer: {
            Text(tr("Add characters of your own to any letter or digit: touch and hold the key to type them."))
        }
        .onAppear {
            holdCount = Settings.shared.customHolds.count
            toolCount = KeyboardTool.list(from: SharedStore.defaults.stringArray(forKey: SettingKey.keyboardTools)
                                          ?? SettingDefault.keyboardTools).count
        }
    }
}

// MARK: More

/// The rest: what the keyboard counted, the app's own language, the data it keeps, and the app itself.
struct MoreTab: View {
    var body: some View {
        GlassList(eager: true) {
            BrandSection().glassRows()
            StatsSection().glassRows()
            AppLanguageSection().glassRows()
            DataSection().glassRows()
            AboutSection().glassRows()
        }
        .tabScreen()
        .environment(\.searchScope, AppTab.more.scope)
        .navigationTitle(AppTab.more.title)
        .navigationBarTitleDisplayMode(.inline)
        .quietNavBar()
    }
}

private struct StatsSection: View {
    @State private var words = 0

    private var wordsText: String? {
        guard words > 0 else { return nil }
        let formatter = NumberFormatter()
        formatter.locale = AppLanguage.locale
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: words))
    }

    var body: some View {
        Section {
            ScreenRow(.stats) {
                SettingsRow(title: tr("Typing stats"), symbol: "chart.bar.fill", color: .green, value: wordsText)
            }
        }
        .onAppear {
            Settings.shared.refresh()
            words = TypingStatsData.decode(Settings.shared.typingStatsJSON).words
        }
    }
}

/// The app's own language: a row showing the chosen one, opening the list to pick it from.
private struct AppLanguageSection: View {
    @AppStorage(SettingKey.appLanguage, store: SharedStore.defaults) private var appLanguage = SettingDefault.appLanguage

    private var chosenName: String {
        guard appLanguage != AppLanguage.system, let language = Language(rawValue: appLanguage) else {
            return tr("System")
        }
        return language.localizedName
    }

    var body: some View {
        Section {
            ScreenRow(.appLanguage) {
                SettingsRow(title: tr("App language"), symbol: "character.bubble.fill", color: .blue, value: chosenName)
            }
        } footer: {
            Text(tr("The language of this app. The keyboard's typing languages are set under Languages."))
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
            // Orange: it removes things (and asks first), short of red Reset, which undoes every setting.
            row(.learned, tr("Forget learned words"), symbol: "text.book.closed", color: .orange)
                .searchAnchor("main.forget")
            row(.reset, tr("Reset all settings"), symbol: "arrow.counterclockwise", color: .red, role: .destructive)
                .searchAnchor("main.reset")
            if let note = note {
                Label(note, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundColor(.secondary)
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
                    .foregroundColor(color)
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

/// The welcome page again, and credits and licences for the word data, emoji data and icons the app ships.
private struct AboutSection: View {
    @AppStorage(SettingKey.welcomeSeen, store: SharedStore.defaults) private var welcomeSeen = false

    private let version = "v0.1-TestFlight"

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
            .searchAnchor("main.welcome")
            ScreenRow(.licences) {
                SettingsRow(title: tr("Licences"), symbol: "doc.text.fill", color: .gray)
            }
        } header: {
            SectionHeader(tr("About"), symbol: "info.circle", color: .gray)
        } footer: {
            Text(tr("Iramo. Copyright \u{00A9} 2026 Ors\u{00F3}s Emil.") + "  \u{00B7}  " + version)
        }
    }
}

// MARK: - App language

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
                    Image(systemName: "checkmark").font(.body.weight(.semibold)).foregroundStyle(.tint)
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

import SwiftUI
import UIKit

/// The keyboard's settings. Every section is its own small view, so changing one control only redraws that section.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                HeaderSection()
                TestFieldSection()
                TypingSection()
                LanguagesSection()
                GesturesSection()
                FeedbackSection()
                AppearanceSection()
                ShortcutsSection()
                DataSection()
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
        }
        .modifier(AccentTint())
        .onAppear {
            Feedback.prepare()
            Settings.shared.removeTouchModel()
        }
    }
}

// MARK: - Sections

/// App name, a few status chips and a hint about what to do next.
private struct HeaderSection: View {
    @State private var status = KeyboardStatus.read()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 14) {
                    Image(systemName: "keyboard.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LinearGradient(colors: [accent, accent.opacity(0.65)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing)))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Tempo").font(.title2.weight(.bold))
                        Text("Your keyboard, your way")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8, alignment: .leading)],
                          alignment: .leading, spacing: 8) {
                    StatusChip(text: status.seen ? "Keyboard added" : "Not set up yet",
                               symbol: status.seen ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                               color: status.seen ? .green : .orange)
                    if status.seen {
                        StatusChip(text: status.fullAccess ? "Full Access on" : "Full Access off",
                                   symbol: status.fullAccess ? "lock.open.fill" : "lock.fill",
                                   color: status.fullAccess ? .green : .orange)
                    }
                    if !SharedStore.isShared {
                        StatusChip(text: "Not synced", symbol: "arrow.triangle.2.circlepath", color: .red)
                    }
                }

                Text(hint)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 6)
        }
        // Read when the screen opens or the app comes back to the front - no polling.
        .onAppear { status = KeyboardStatus.read() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { status = KeyboardStatus.read() }
        }
    }

    private var hint: String {
        if !SharedStore.isShared {
            return "This install can't share settings with the keyboard (no App Group). Install the IPA with iloader."
        }
        if !status.seen {
            return "Add Tempo in Settings > General > Keyboard > Keyboards, turn on Allow Full Access, then open the keyboard once."
        }
        if !status.fullAccess {
            return "Allow Full Access is off: no vibration, and the keyboard can't save recent emoji or learned words."
        }
        return "Last used \(status.lastSeenText). \(status.emojiText)."
    }
}

private struct TestFieldSection: View {
    @State private var text = ""

    var body: some View {
        Section {
            TextField("Tap here and type to try it", text: $text)
        } header: {
            SectionHeader("Try the keyboard", symbol: "text.cursor", color: .gray)
        }
    }
}

private struct TypingSection: View {
    var body: some View {
        Section {
            SettingToggle("Word suggestions", key: SettingKey.suggestions, defaultValue: SettingDefault.suggestions,
                          subtitle: "Predictions above the keys as you type")
            SettingToggle("Auto-correction", key: SettingKey.autoCorrect, defaultValue: SettingDefault.autoCorrect,
                          subtitle: "Fixes typos, missing accents and missing spaces when you press space")
            SettingToggle("Emoji suggestions", key: SettingKey.emojiSuggestions, defaultValue: SettingDefault.emojiSuggestions,
                          subtitle: "Offers an emoji that matches the word you typed")
            SettingToggle("Swipe typing", key: SettingKey.swipe, defaultValue: SettingDefault.swipe,
                          subtitle: "Slide across the letters to type a word")
            SettingToggle("Auto-capitalization", key: SettingKey.autoCapitalize, defaultValue: SettingDefault.autoCapitalize,
                          subtitle: "Starts each sentence with a capital letter")
            SettingToggle("\u{201C}.\u{201D} shortcut", key: SettingKey.doubleSpacePeriod, defaultValue: SettingDefault.doubleSpacePeriod,
                          subtitle: "Tap the space bar twice to end a sentence")
        } header: {
            SectionHeader("Typing", symbol: "keyboard", color: .blue)
        }
    }
}

private struct GesturesSection: View {
    var body: some View {
        Section {
            SettingToggle("Move the cursor", key: SettingKey.cursorControl, defaultValue: SettingDefault.cursorControl,
                          subtitle: "Hold the space bar and slide")
            SettingToggle("Delete whole words", key: SettingKey.deleteSwipe, defaultValue: SettingDefault.deleteSwipe,
                          subtitle: "Slide left from the delete key")
            SettingSlider("Hold delay",
                          key: SettingKey.holdDelay,
                          defaultValue: SettingDefault.holdDelay,
                          range: Settings.holdDelayRange,
                          step: 0.05,
                          subtitle: "How long to hold a key before its accents appear") { String(format: "%.2f s", $0) }
        } header: {
            SectionHeader("Gestures", symbol: "hand.draw.fill", color: .teal)
        }
    }
}

private struct FeedbackSection: View {
    var body: some View {
        Section {
            SettingSlider("Vibration",
                          key: SettingKey.vibration,
                          defaultValue: SettingDefault.vibration,
                          range: 0...1,
                          step: 0.05,
                          showsTest: true,
                          subtitle: "Needs Full Access") { $0 < 0.01 ? "Off" : "\(Int(($0 * 100).rounded()))%" }
            SettingToggle("Key clicks", key: SettingKey.clickSound, defaultValue: SettingDefault.clickSound,
                          subtitle: "Muted by the silent switch")
            SettingToggle("Key pop-ups", key: SettingKey.keyPopups, defaultValue: SettingDefault.keyPopups,
                          subtitle: "Shows the letter above your finger")
        } header: {
            SectionHeader("Sound & haptics", symbol: "speaker.wave.2.fill", color: .pink)
        }
    }
}

private struct LanguagesSection: View {
    @State private var summary = LanguagesSection.currentSummary()

    var body: some View {
        Section {
            NavigationLink {
                LanguagesView()
                    .onDisappear { summary = LanguagesSection.currentSummary() }
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    InfoRow("Languages", summary)
                    Text("Swipe the space bar left or right to switch")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
        } header: {
            SectionHeader("Languages", symbol: "globe", color: .green)
        }
    }

    private static func currentSummary() -> String {
        return Settings.shared.enabledLanguages
            .compactMap { Language(rawValue: $0)?.shortCode }
            .joined(separator: ", ")
    }
}

private struct AppearanceSection: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }
    private var theme: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    var body: some View {
        Section {
            NavigationLink {
                ThemesView()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    ThemePreview(theme: theme, accent: accent, cornerRadius: 12)
                        .aspectRatio(1.7, contentMode: .fit)
                    HStack {
                        Text("Theme")
                        Spacer()
                        Text(theme.name).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Accent colour")
                Text("The return key and highlights. Gradient themes use their own.")
                    .font(.footnote).foregroundColor(.secondary)
                AccentPicker()
            }
            .padding(.vertical, 2)
            AccentCustomRow()

            SettingSlider("Keyboard height",
                          key: SettingKey.keyboardHeight,
                          defaultValue: SettingDefault.keyboardHeight,
                          range: Settings.heightScaleRange,
                          step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
            RoundnessSlider()
            SettingToggle("Key borders", key: SettingKey.keyBorders, defaultValue: SettingDefault.keyBorders,
                          subtitle: "A thin outline around keys on translucent themes")
            SettingToggle("Number row", key: SettingKey.numberRow, defaultValue: SettingDefault.numberRow,
                          subtitle: "Numbers above the letters")
            SettingToggle("Accent hints", key: SettingKey.keyHints, defaultValue: SettingDefault.keyHints,
                          subtitle: "Shows a key's first accent in its corner")
        } header: {
            SectionHeader("Appearance", symbol: "paintpalette.fill", color: .purple)
        }
    }
}

private struct ShortcutsSection: View {
    var body: some View {
        Section {
            NavigationLink {
                ShortcutsView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Text shortcuts")
                    Text("Type a trigger and press space to expand it")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
        } header: {
            SectionHeader("Shortcuts", symbol: "bolt.fill", color: .orange)
        }
    }
}

private struct DataSection: View {
    private enum Action: String {
        case recents, learned, reset

        var title: String {
            switch self {
            case .recents: return "Clear recent emoji?"
            case .learned: return "Forget learned words?"
            case .reset: return "Reset all settings?"
            }
        }

        var message: String {
            switch self {
            case .recents: return "The Recently Used emoji tab will be empty."
            case .learned: return "Words the keyboard picked up while you type will be removed."
            case .reset: return "Your shortcuts, recent emoji and learned words are kept."
            }
        }

        var button: String {
            switch self {
            case .recents: return "Clear"
            case .learned: return "Forget"
            case .reset: return "Reset"
            }
        }
    }

    @State private var pending: Action?
    @State private var note: String?

    var body: some View {
        Section {
            Button { pending = .recents } label: { Label("Clear recent emoji", systemImage: "clock.arrow.circlepath") }
            Button { pending = .learned } label: { Label("Forget learned words", systemImage: "text.book.closed") }
            Button(role: .destructive) { pending = .reset } label: { Label("Reset all settings", systemImage: "arrow.counterclockwise") }
            if let note = note {
                Text(note).font(.footnote).foregroundColor(.secondary)
            }
        } header: {
            SectionHeader("Privacy & data", symbol: "hand.raised.fill", color: .gray)
        } footer: {
            Text("Everything the keyboard learns stays on this device.")
        }
        .confirmationDialog(pending?.title ?? "",
                            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
                            titleVisibility: .visible,
                            presenting: pending) { action in
            Button(action.button, role: .destructive) { perform(action) }
            Button("Cancel", role: .cancel) {}
        } message: { action in
            Text(action.message)
        }
    }

    private func perform(_ action: Action) {
        switch action {
        case .recents:
            Settings.shared.clearRecentEmoji()
            note = "Recent emoji cleared."
        case .learned:
            Settings.shared.clearLearnedWords()
            note = "Learned words forgotten."
        case .reset:
            Settings.shared.resetPreferences()
            NotificationCenter.default.post(name: .hunKeysSettingsReset, object: nil)
            note = "Settings reset to defaults."
        }
        Feedback.tick()
    }
}

// MARK: - Status

struct KeyboardStatus {
    var seen: Bool
    var lastSeen: Date
    var fullAccess: Bool
    var emojiVersion: String
    var emojiTotal: Int
    var emojiShown: Int

    static func read() -> KeyboardStatus {
        let store = SharedStore.defaults
        let stamp = store.double(forKey: SettingKey.lastSeen)
        return KeyboardStatus(seen: stamp > 0,
                              lastSeen: Date(timeIntervalSince1970: stamp),
                              fullAccess: store.bool(forKey: SettingKey.fullAccess),
                              emojiVersion: store.string(forKey: SettingKey.emojiVersion) ?? "",
                              emojiTotal: store.integer(forKey: SettingKey.emojiTotal),
                              emojiShown: store.integer(forKey: SettingKey.emojiShown))
    }

    var lastSeenText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastSeen, relativeTo: Date())
    }

    var emojiText: String {
        guard emojiTotal > 0 else { return "Opens with the keyboard" }
        let version = emojiVersion.isEmpty ? "" : "Unicode \(emojiVersion): "
        if emojiShown < emojiTotal {
            return "\(version)\(emojiShown) of \(emojiTotal) shown"
        }
        return "\(version)all \(emojiTotal) shown"
    }
}

// MARK: - Shortcuts

struct ShortcutsView: View {
    @State private var items: [TextShortcut] = Settings.shared.shortcuts
    @State private var trigger = ""
    @State private var phrase = ""

    var body: some View {
        Form {
            Section("New shortcut") {
                TextField("Trigger (e.g. omw)", text: $trigger)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                TextField("Phrase (e.g. On my way!)", text: $phrase)
                Button("Add") {
                    let key = trigger.trimmingCharacters(in: .whitespaces)
                    let text = phrase.trimmingCharacters(in: .whitespaces)
                    guard !key.isEmpty, !text.isEmpty else { return }
                    items.removeAll { $0.trigger.lowercased() == key.lowercased() }
                    items.append(TextShortcut(trigger: key, phrase: text))
                    save()
                    trigger = ""
                    phrase = ""
                }
                .disabled(trigger.trimmingCharacters(in: .whitespaces).isEmpty
                          || phrase.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Section("Your shortcuts") {
                if items.isEmpty {
                    Text("None yet").foregroundColor(.secondary)
                }
                ForEach(items) { item in
                    VStack(alignment: .leading) {
                        Text(item.trigger).font(.headline)
                        Text(item.phrase).font(.subheadline).foregroundColor(.secondary)
                    }
                }
                .onDelete { offsets in
                    items.remove(atOffsets: offsets)
                    save()
                }
            }
        }
        .navigationTitle("Text shortcuts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func save() {
        Settings.shared.shortcuts = items
    }
}

// MARK: - Languages

struct LanguagesView: View {
    @State private var enabled: [String] = Settings.shared.enabledLanguages

    var body: some View {
        List {
            Section {
                ForEach(Language.allCases, id: \.rawValue) { language in
                    Toggle(language.displayName, isOn: binding(for: language))
                }
            } footer: {
                Text("At least one language stays on. Swipe left or right on the space bar to switch between the enabled languages.")
            }
        }
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func binding(for language: Language) -> Binding<Bool> {
        return Binding(
            get: { enabled.contains(language.rawValue) },
            set: { on in
                var list = enabled
                if on {
                    if !list.contains(language.rawValue) { list.append(language.rawValue) }
                } else if list.count > 1 {
                    list.removeAll { $0 == language.rawValue }
                }
                let ordered = Language.allCases.map { $0.rawValue }.filter { list.contains($0) }
                guard ordered != enabled else { return }
                Feedback.tick()
                enabled = ordered
                Settings.shared.enabledLanguages = ordered
            }
        )
    }
}

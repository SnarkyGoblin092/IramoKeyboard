import SwiftUI
import UIKit

/// The keyboard's settings. Every section is its own small view, so changing one control only redraws that section.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                StatusSection()
                FeelSection()
                TypingSection()
                LanguagesSection()
                AppearanceSection()
                Section {
                    NavigationLink("Text shortcuts") { ShortcutsView() }
                } footer: {
                    Text("Type a short trigger, press space, and it expands to the full phrase.")
                }
                DataSection()
                TestFieldSection()
            }
            .navigationTitle("HunKeys")
            .navigationBarTitleDisplayMode(.large)
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear { Feedback.prepare() }
    }
}

// MARK: - Sections

private struct StatusSection: View {
    @State private var status = KeyboardStatus.read()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Section("Status") {
            InfoRow("Keyboard", status.seen ? "Used \(status.lastSeenText)" : "Not seen yet")
            InfoRow("Full Access", status.seen ? (status.fullAccess ? "On" : "Off") : "-")
            InfoRow("Emoji", status.emojiText)
            if !SharedStore.isShared {
                Text("This install can't share settings with the keyboard (no App Group). Install the IPA with iloader.")
                    .font(.footnote).foregroundColor(.orange)
            } else if !status.seen {
                Text("Add HunKeys in Settings > General > Keyboard > Keyboards, turn on Allow Full Access, then open the keyboard once.")
                    .font(.footnote).foregroundColor(.secondary)
            } else if !status.fullAccess {
                Text("Allow Full Access is off: no vibration, and the keyboard can't save recent emoji or learned words.")
                    .font(.footnote).foregroundColor(.orange)
            }
        }
        // Read when the screen opens or the app comes back to the front - no polling.
        .onAppear { status = KeyboardStatus.read() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { status = KeyboardStatus.read() }
        }
    }
}

private struct FeelSection: View {
    var body: some View {
        Section("Feel") {
            SettingSlider("Hold delay",
                          key: SettingKey.holdDelay,
                          defaultValue: SettingDefault.holdDelay,
                          range: Settings.holdDelayRange,
                          step: 0.05) { String(format: "%.2f s", $0) }
            SettingSlider("Vibration strength",
                          key: SettingKey.vibration,
                          defaultValue: SettingDefault.vibration,
                          range: 0...1,
                          step: 0.05,
                          showsTest: true) { $0 < 0.01 ? "Off" : "\(Int(($0 * 100).rounded()))%" }
            SettingToggle("Key click sound", key: SettingKey.clickSound, defaultValue: SettingDefault.clickSound)
            SettingToggle("Key pop-ups", key: SettingKey.keyPopups, defaultValue: SettingDefault.keyPopups)
        }
    }
}

private struct TypingSection: View {
    var body: some View {
        Section {
            SettingToggle("Swipe typing", key: SettingKey.swipe, defaultValue: SettingDefault.swipe)
            SettingToggle("Word suggestions", key: SettingKey.suggestions, defaultValue: SettingDefault.suggestions)
            SettingToggle("Emoji suggestions", key: SettingKey.emojiSuggestions, defaultValue: SettingDefault.emojiSuggestions)
            SettingToggle("Auto-capitalize", key: SettingKey.autoCapitalize, defaultValue: SettingDefault.autoCapitalize)
            SettingToggle("Double space for period", key: SettingKey.doubleSpacePeriod, defaultValue: SettingDefault.doubleSpacePeriod)
            SettingToggle("Space-bar cursor control", key: SettingKey.cursorControl, defaultValue: SettingDefault.cursorControl)
            SettingToggle("Slide on delete to remove words", key: SettingKey.deleteSwipe, defaultValue: SettingDefault.deleteSwipe)
        } header: {
            Text("Typing")
        } footer: {
            Text("Hold the space bar and slide to move the cursor. Slide left from the delete key to delete word by word.")
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
                InfoRow("Languages", summary)
            }
        } footer: {
            Text("Swipe left or right on the space bar to switch between the enabled languages.")
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

    private var accent: AccentChoice { return AccentChoice(rawValue: accentName) ?? .blue }
    private var theme: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    var body: some View {
        Section("Appearance") {
            NavigationLink {
                ThemesView()
            } label: {
                VStack(alignment: .leading, spacing: 10) {
                    ThemePreview(theme: theme, accent: accent)
                        .aspectRatio(1.7, contentMode: .fit)
                    HStack {
                        Text("Theme")
                        Spacer()
                        Text(theme.name).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Accent colour")
                HStack(spacing: 14) {
                    ForEach(AccentChoice.allCases, id: \.rawValue) { choice in
                        Button {
                            guard accentName != choice.rawValue else { return }
                            Feedback.tick()
                            accentName = choice.rawValue
                        } label: {
                            Circle()
                                .fill(Color(accent: choice))
                                .frame(width: 32, height: 32)
                                .overlay(Circle()
                                    .stroke(Color.primary, lineWidth: accentName == choice.rawValue ? 3 : 0)
                                    .padding(-4))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(choice.displayName)
                    }
                }
                if theme.kind == .gradient {
                    Text("Gradient themes use their own accent colour.")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)

            SettingSlider("Keyboard height",
                          key: SettingKey.keyboardHeight,
                          defaultValue: SettingDefault.keyboardHeight,
                          range: Settings.heightScaleRange,
                          step: 0.05) { "\(Int(($0 * 100).rounded()))%" }
            SettingToggle("Number row", key: SettingKey.numberRow, defaultValue: SettingDefault.numberRow)
            SettingToggle("Long-press hints on keys", key: SettingKey.keyHints, defaultValue: SettingDefault.keyHints)
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
            case .reset: return "Your shortcuts, recent emoji and learned words are kept. Reopen this screen to see the defaults."
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
            Button("Clear recent emoji") { pending = .recents }
            Button("Forget learned words") { pending = .learned }
            Button("Reset all settings", role: .destructive) { pending = .reset }
            if let note = note {
                Text(note).font(.footnote).foregroundColor(.secondary)
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Everything stays on this iPhone.")
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
            note = "Settings reset."
        }
        Feedback.tick()
    }
}

private struct TestFieldSection: View {
    @State private var text = ""

    var body: some View {
        Section("Test field") {
            TextField("Type here to test the keyboard", text: $text)
        }
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
                    .autocapitalization(.none)
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

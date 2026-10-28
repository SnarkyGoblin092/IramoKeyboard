import SwiftUI
import UIKit

/// The keyboard's settings. (No tutorial - just options.)
struct ContentView: View {
    @AppStorage(SettingKey.holdDelay, store: SharedStore.defaults) private var holdDelay = SettingDefault.holdDelay
    @AppStorage(SettingKey.vibration, store: SharedStore.defaults) private var vibration = SettingDefault.vibration
    @AppStorage(SettingKey.clickSound, store: SharedStore.defaults) private var clickSound = SettingDefault.clickSound
    @AppStorage(SettingKey.keyPopups, store: SharedStore.defaults) private var keyPopups = SettingDefault.keyPopups

    @AppStorage(SettingKey.swipe, store: SharedStore.defaults) private var swipe = SettingDefault.swipe
    @AppStorage(SettingKey.suggestions, store: SharedStore.defaults) private var suggestions = SettingDefault.suggestions
    @AppStorage(SettingKey.emojiSuggestions, store: SharedStore.defaults) private var emojiSuggestions = SettingDefault.emojiSuggestions
    @AppStorage(SettingKey.autoCapitalize, store: SharedStore.defaults) private var autoCapitalize = SettingDefault.autoCapitalize
    @AppStorage(SettingKey.doubleSpacePeriod, store: SharedStore.defaults) private var doubleSpacePeriod = SettingDefault.doubleSpacePeriod
    @AppStorage(SettingKey.cursorControl, store: SharedStore.defaults) private var cursorControl = SettingDefault.cursorControl
    @AppStorage(SettingKey.deleteSwipe, store: SharedStore.defaults) private var deleteSwipe = SettingDefault.deleteSwipe

    @AppStorage(SettingKey.numberRow, store: SharedStore.defaults) private var numberRow = SettingDefault.numberRow
    @AppStorage(SettingKey.keyHints, store: SharedStore.defaults) private var keyHints = SettingDefault.keyHints
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var theme = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accent = SettingDefault.accent
    @AppStorage(SettingKey.keyboardHeight, store: SharedStore.defaults) private var keyboardHeight = SettingDefault.keyboardHeight
    @AppStorage(SettingKey.oneHanded, store: SharedStore.defaults) private var oneHanded = SettingDefault.oneHanded

    @State private var status = KeyboardStatus.read()
    @State private var confirm: Confirmation?
    @State private var testText = ""
    @State private var cleared: String?
    @Environment(\.scenePhase) private var scenePhase

    private enum Confirmation: String, Identifiable {
        case recents, learned, reset
        var id: String { rawValue }
    }

    var body: some View {
        NavigationView {
            Form {
                statusSection
                feelSection
                typingSection
                appearanceSection
                Section {
                    NavigationLink("Languages") { LanguagesView() }
                } footer: {
                    Text("Choose which languages the keyboard offers. Hold the space bar to switch between them.")
                }
                Section {
                    NavigationLink("Text shortcuts") { ShortcutsView() }
                } footer: {
                    Text("Type a short trigger, press space, and it expands to the full phrase.")
                }
                dataSection
                trySection
            }
            .navigationTitle("HunKeys")
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationViewStyle(.stack)
        .onAppear { status = KeyboardStatus.read() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { status = KeyboardStatus.read() }
        }
        .alert(item: $confirm) { item in
            switch item {
            case .recents:
                return Alert(title: Text("Clear recent emoji?"),
                             primaryButton: .destructive(Text("Clear")) {
                                 Settings.shared.clearRecentEmoji()
                                 cleared = "Recent emoji cleared."
                             },
                             secondaryButton: .cancel())
            case .learned:
                return Alert(title: Text("Forget learned words?"),
                             message: Text("Words the keyboard picked up while you type will be removed."),
                             primaryButton: .destructive(Text("Forget")) {
                                 Settings.shared.clearLearnedWords()
                                 cleared = "Learned words forgotten."
                             },
                             secondaryButton: .cancel())
            case .reset:
                return Alert(title: Text("Reset all settings?"),
                             message: Text("Your shortcuts, recent emoji and learned words are kept."),
                             primaryButton: .destructive(Text("Reset")) {
                                 Settings.shared.resetPreferences()
                                 cleared = "Settings reset - reopen this screen to see the defaults."
                             },
                             secondaryButton: .cancel())
            }
        }
    }

    // MARK: Sections

    private var statusSection: some View {
        Section {
            row("Keyboard", status.seen ? "Used \(status.lastSeenText)" : "Not seen yet")
            row("Full Access", status.seen ? (status.fullAccess ? "On" : "Off") : "-")
            row("Emoji", status.emojiText)
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
        } header: {
            Text("Status")
        }
    }

    private var feelSection: some View {
        Section("Feel") {
            VStack(alignment: .leading) {
                HStack {
                    Text("Hold delay")
                    Spacer()
                    Text(String(format: "%.2f s", holdDelay)).foregroundColor(.secondary)
                }
                Slider(value: $holdDelay, in: Settings.holdDelayRange, step: 0.05)
            }
            VStack(alignment: .leading) {
                HStack {
                    Text("Vibration strength")
                    Spacer()
                    Text(vibration < 0.01 ? "Off" : "\(Int((vibration * 100).rounded()))%").foregroundColor(.secondary)
                    Button("Test") {
                        guard vibration > 0.01 else { return }
                        let generator = UIImpactFeedbackGenerator(style: .rigid)
                        generator.prepare()
                        generator.impactOccurred(intensity: CGFloat(vibration))
                    }
                    .buttonStyle(.bordered)
                }
                Slider(value: $vibration, in: 0...1, step: 0.05)
            }
            Toggle("Key click sound", isOn: $clickSound)
            Toggle("Key pop-ups", isOn: $keyPopups)
        }
    }

    private var typingSection: some View {
        Section {
            Toggle("Swipe typing", isOn: $swipe)
            Toggle("Word suggestions", isOn: $suggestions)
            Toggle("Emoji suggestions", isOn: $emojiSuggestions)
            Toggle("Auto-capitalize", isOn: $autoCapitalize)
            Toggle("Double space for period", isOn: $doubleSpacePeriod)
            Toggle("Space-bar cursor control", isOn: $cursorControl)
            Toggle("Slide on delete to remove words", isOn: $deleteSwipe)
        } header: {
            Text("Typing")
        } footer: {
            Text("Hold the space bar and slide left or right to move the cursor. Slide left from the delete key to delete word by word.")
        }
    }

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $theme) {
                Text("Native").tag("native")
                Text("Transparent").tag("transparent")
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                Text("Accent colour")
                HStack(spacing: 14) {
                    ForEach(AccentChoice.allCases, id: \.rawValue) { choice in
                        Circle()
                            .fill(Color(red: choice.rgb.red, green: choice.rgb.green, blue: choice.rgb.blue))
                            .frame(width: 32, height: 32)
                            .overlay(Circle().stroke(Color.primary, lineWidth: accent == choice.rawValue ? 3 : 0).padding(-4))
                            .onTapGesture { accent = choice.rawValue }
                            .accessibilityLabel(choice.displayName)
                    }
                }
            }
            .padding(.vertical, 4)

            VStack(alignment: .leading) {
                HStack {
                    Text("Keyboard height")
                    Spacer()
                    Text("\(Int((keyboardHeight * 100).rounded()))%").foregroundColor(.secondary)
                }
                Slider(value: $keyboardHeight, in: Settings.heightScaleRange, step: 0.05)
            }
            Picker("One-handed mode", selection: $oneHanded) {
                Text("Off").tag("off")
                Text("Right").tag("right")
                Text("Left").tag("left")
            }
            Toggle("Number row", isOn: $numberRow)
            Toggle("Long-press hints on keys", isOn: $keyHints)
        }
    }

    private var dataSection: some View {
        Section {
            Button("Clear recent emoji") { confirm = .recents }
            Button("Forget learned words") { confirm = .learned }
            Button("Reset all settings", role: .destructive) { confirm = .reset }
            if let cleared = cleared {
                Text(cleared).font(.footnote).foregroundColor(.secondary)
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Everything stays on this iPhone.")
        }
    }

    private var trySection: some View {
        Section {
            TextField("Type here to test the keyboard", text: $testText)
        } header: {
            Text("Test field")
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).foregroundColor(.secondary).multilineTextAlignment(.trailing)
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
        Form {
            Section {
                ForEach(Language.allCases, id: \.rawValue) { language in
                    Toggle(language.displayName, isOn: binding(for: language))
                }
            } footer: {
                Text("At least one language stays on. Words, accents and layouts follow the active language.")
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
                // Keep the same order as the list above.
                let ordered = Language.allCases.map { $0.rawValue }.filter { list.contains($0) }
                enabled = ordered
                Settings.shared.enabledLanguages = ordered
            }
        )
    }
}

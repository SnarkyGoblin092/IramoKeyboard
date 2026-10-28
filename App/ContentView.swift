import SwiftUI
import UIKit
import Combine

/// The keyboard's settings. (No tutorial - just options.)
struct ContentView: View {
    private let store = SharedStore.defaults

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
    @AppStorage(SettingKey.glassKeys, store: SharedStore.defaults) private var glassKeys = SettingDefault.glassKeys
    @AppStorage(SettingKey.glassStyle, store: SharedStore.defaults) private var glassStyle = SettingDefault.glassStyle
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accent = SettingDefault.accent
    @AppStorage(SettingKey.keyboardHeight, store: SharedStore.defaults) private var keyboardHeight = SettingDefault.keyboardHeight
    @AppStorage(SettingKey.oneHanded, store: SharedStore.defaults) private var oneHanded = SettingDefault.oneHanded

    @State private var status = KeyboardStatus.read()
    @State private var confirm: Confirmation?
    @State private var testText = ""
    @State private var cleared: String?
    @State private var testNonce: String?
    @State private var syncResult: String?
    @State private var copied = false
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
        .onAppear {
            status = KeyboardStatus.read()
            SharedStore.publishPreferences()
        }
        .onChange(of: scenePhase) { phase in
            SharedStore.publishPreferences()
            if phase == .active { refreshStatus() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .debounce(for: .seconds(0.4), scheduler: DispatchQueue.main)) { _ in
            SharedStore.publishPreferences()
        }
        .onReceive(Timer.publish(every: 2, on: .main, in: .common).autoconnect()) { _ in
            if testNonce != nil { refreshStatus() }
        }
        .alert(item: $confirm) { item in
            switch item {
            case .recents:
                return Alert(title: Text("Clear recent emoji?"),
                             primaryButton: .destructive(Text("Clear")) {
                                 Settings.shared.requestClearRecentEmoji()
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
            row("Sync channel", SharedStore.transportLabel)
            row("Emoji", status.emojiText)

            Text(diagnosis.text)
                .font(.footnote)
                .foregroundColor(diagnosis.ok ? .secondary : .orange)

            DisclosureGroup("Sync details") {
                ForEach(Array(syncDetails.enumerated()), id: \.offset) { _, line in
                    Text(line).font(.caption).foregroundColor(.secondary)
                }
            }

            Button("Test sync") { startSyncTest() }
            if let result = syncResult {
                Text(result).font(.footnote).foregroundColor(.secondary)
            }
            Button(copied ? "Copied - now open a text field with HunKeys" : "Send settings to keyboard") {
                UIPasteboard.general.string = SharedStore.exportString()
                copied = true
            }
        } header: {
            Text("Status")
        } footer: {
            Text("Without shared storage: tap Send after changing settings, then open any text field and switch to HunKeys. If it doesn't import by itself (it needs Allow Full Access), tap the arrow at the left of the suggestion bar and then the clipboard icon.")
        }
    }

    private var syncDetails: [String] {
        _ = SharedStore.keychainGroup      // make sure both checks have run
        var lines = SharedStore.groupDiagnostics
        lines.append("Keychain: " + (SharedStore.keychainDiagnosis.isEmpty ? "not tried" : SharedStore.keychainDiagnosis))
        lines.append("Active: " + SharedStore.transportLabel)
        return lines
    }

    private var diagnosis: (text: String, ok: Bool) {
        if !SharedStore.isShared {
            return (SharedStore.syncExplanation, false)
        }
        if !status.seen {
            return ("Add HunKeys in Settings > General > Keyboard > Keyboards, then open the keyboard in any text field once. Also turn on Allow Full Access (needed for vibration, paste and saving recents).", false)
        }
        if !status.fullAccess {
            return ("Allow Full Access is off. Per Apple, a keyboard without it can only read the shared storage, not write to it - so it can't save recents, learned words or status, and has no vibration or paste. Turn it on in Settings > General > Keyboard > Keyboards > HunKeys.", false)
        }
        return ("Sync channel available. Tap Test sync to confirm the keyboard really receives changes.", true)
    }

    private func refreshStatus() {
        status = KeyboardStatus.read()
        if let nonce = testNonce, status.echoNonce == nonce {
            syncResult = "Sync works: the keyboard saw test code \(nonce)."
            testNonce = nil
        }
    }

    private func startSyncTest() {
        let nonce = String(Int(Date().timeIntervalSince1970) % 100000) + String(Int.random(in: 10...99))
        SharedStore.defaults.set(nonce, forKey: SyncKey.nonce)
        SharedStore.publishPreferences()
        testNonce = nonce
        syncResult = "Test code \(nonce) sent. Now open a text field with HunKeys, then come back here."
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
            Picker("Glass style", selection: $glassStyle) {
                Text("Regular").tag("regular")
                Text("Clear").tag("clear")
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
            Toggle("Glass keys (experimental)", isOn: $glassKeys)
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
    var echoNonce: String

    static func read() -> KeyboardStatus {
        let values = SharedStore.readStatus()
        let stamp = values[SettingKey.lastSeen] as? Double ?? 0
        return KeyboardStatus(seen: stamp > 0,
                              lastSeen: Date(timeIntervalSince1970: stamp),
                              fullAccess: values[SettingKey.fullAccess] as? Bool ?? false,
                              emojiVersion: values[SettingKey.emojiVersion] as? String ?? "",
                              emojiTotal: values[SettingKey.emojiTotal] as? Int ?? 0,
                              emojiShown: values[SettingKey.emojiShown] as? Int ?? 0,
                              echoNonce: values[SyncKey.echoNonce] as? String ?? "")
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

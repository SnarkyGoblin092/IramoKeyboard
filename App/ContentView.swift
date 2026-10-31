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
                CreditsSection()
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
    var body: some View {
        Section {
            NavigationLink {
                LanguagesView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Languages")
                    Text("Swipe the space bar left or right to switch")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
        } header: {
            SectionHeader("Languages", symbol: "globe", color: .green)
        }
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
                        .aspectRatio(ThemePreview.aspectWithStrip, contentMode: .fit)
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
                Text("The return key and highlights. Colour themes keep their own until you pick one.")
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
            row(.recents, "Clear recent emoji", symbol: "clock.arrow.circlepath")
            row(.learned, "Forget learned words", symbol: "text.book.closed")
            row(.reset, "Reset all settings", symbol: "arrow.counterclockwise", role: .destructive)
            if let note = note {
                Text(note).font(.footnote).foregroundColor(.secondary)
            }
        } header: {
            SectionHeader("Privacy & data", symbol: "hand.raised.fill", color: .gray)
        } footer: {
            Text("Everything the keyboard learns stays on this device.")
        }
    }

    /// One option with its own confirmation, so the dialog's arrow points at the option that was tapped.
    private func row(_ action: Action, _ title: String, symbol: String, role: ButtonRole? = nil) -> some View {
        Button(role: role) { pending = action } label: { Label(title, systemImage: symbol) }
            .confirmationDialog(action.title,
                                isPresented: Binding(get: { pending == action }, set: { if !$0 { pending = nil } }),
                                titleVisibility: .visible) {
                Button(action.button, role: .destructive) { perform(action) }
                Button("Cancel", role: .cancel) {}
            } message: {
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

/// Credits and licences for the word data, emoji data and icons the app ships (LicensesView).
private struct CreditsSection: View {
    var body: some View {
        Section {
            NavigationLink {
                LicensesView()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Licences")
                    Text("The app's licence, and the word lists, emoji data and icons it uses")
                        .font(.footnote).foregroundColor(.secondary)
                }
            }
        } header: {
            SectionHeader("Acknowledgements", symbol: "info.circle.fill", color: .gray)
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

/// The enabled languages only; more are added from a separate list. Drawn as its own grouped card (not a List)
/// so the swipe-to-delete button sits inside the row and the card keeps its corners while swiping.
struct LanguagesView: View {
    @State private var enabled: [String] = Settings.shared.enabledLanguages

    private var languages: [Language] { return enabled.compactMap { Language(rawValue: $0) } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                VStack(spacing: 0) {
                    ForEach(Array(languages.enumerated()), id: \.element.rawValue) { index, language in
                        SwipeToDeleteRow(canDelete: languages.count > 1) {
                            remove(language)
                        } content: {
                            Text(language.displayName)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .frame(minHeight: 48)
                        }
                        if index < languages.count - 1 {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
                .groupedCard()

                Text("Swipe the space bar left or right to switch. Swipe a language left to remove it.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                if enabled.count < Language.allCases.count {
                    NavigationLink {
                        AddLanguageView(enabled: enabled) { language in
                            save(enabled + [language.rawValue])
                        }
                    } label: {
                        HStack {
                            Label("Add a language", systemImage: "plus")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(Color(.tertiaryLabel))
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                    }
                    .groupedCard()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Languages")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func remove(_ language: Language) {
        guard enabled.count > 1 else { return }
        save(enabled.filter { $0 != language.rawValue })
    }

    private func save(_ list: [String]) {
        let ordered = Language.allCases.map { $0.rawValue }.filter { list.contains($0) }
        guard !ordered.isEmpty, ordered != enabled else { return }
        Feedback.tick()
        withAnimation(.easeOut(duration: 0.2)) { enabled = ordered }
        Settings.shared.enabledLanguages = ordered
    }
}

private extension View {
    /// The white (dark: grey) rounded card of a grouped list.
    func groupedCard() -> some View {
        let radius: CGFloat
        if #available(iOS 26, *) { radius = 26 } else { radius = 10 }
        return self
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }
}

/// A row that slides left to show a red Delete button inside the row itself; a long swipe deletes at once.
private struct SwipeToDeleteRow<Content: View>: View {
    let canDelete: Bool
    let onDelete: () -> Void
    @ViewBuilder let content: () -> Content

    @State private var offset: CGFloat = 0
    @State private var settled: CGFloat = 0
    private let buttonWidth: CGFloat = 84
    /// How far the Delete button may grow: a long swipe that reaches it deletes at once.
    private let maxReveal: CGFloat = 200

    var body: some View {
        // The row stays put (the name never slides off screen); the Delete button grows in from the right edge.
        content()
            .background(Color(.secondarySystemGroupedBackground))
            .onTapGesture { close() }
            .overlay(alignment: .trailing) {
                if offset < 0 {
                    Button(action: delete) {
                        Text("Delete")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .fixedSize()
                            .frame(width: -offset)
                            .frame(maxHeight: .infinity)
                            .background(Color.red)
                            .clipped()
                    }
                    .buttonStyle(.plain)
                }
            }
        .gesture(drag, including: canDelete ? .all : .subviews)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                // At most up to a short distance from the name, so it always stays readable.
                offset = max(-maxReveal, min(0, settled + value.translation.width))
            }
            .onEnded { value in
                let end = min(0, settled + value.translation.width)
                if end <= -maxReveal {
                    delete()
                } else {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        offset = end < -buttonWidth / 2 ? -buttonWidth : 0
                    }
                    settled = offset
                }
            }
    }

    private func close() {
        guard offset != 0 else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
        settled = 0
    }

    private func delete() {
        offset = 0
        settled = 0
        onDelete()
    }
}

/// The languages that are not enabled yet; picking one adds it and goes back.
private struct AddLanguageView: View {
    let enabled: [String]
    let add: (Language) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            ForEach(Language.allCases.filter { !enabled.contains($0.rawValue) }, id: \.rawValue) { language in
                Button {
                    add(language)
                    dismiss()
                } label: {
                    Text(language.displayName).foregroundColor(.primary)
                }
            }
        }
        .navigationTitle("Add a language")
        .navigationBarTitleDisplayMode(.inline)
    }
}

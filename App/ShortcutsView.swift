import SwiftUI

// MARK: - Text shortcuts

/// The shortcuts the user made ("omw" -> "On my way!"), and how the dates and times in them are written. The list
/// is the screen: a tap on a shortcut opens it to change it, a swipe removes it, and New shortcut opens the same
/// sheet empty (ShortcutComposer), where the shortcut is tried as it is typed.
struct ShortcutsView: View {
    @State private var items: [TextShortcut] = Settings.shared.shortcuts
    /// The shortcut being written or changed (the sheet is open while it is set).
    @State private var composing: ShortcutDraft?
    /// What the sheet decided (save or delete), carried out once it has closed: the list under an open sheet is
    /// never changed.
    @State private var pending: PendingChange?

    private enum PendingChange {
        case save(ShortcutDraft, trigger: String, phrase: String)
        case remove(TextShortcut)
    }
    @AppStorage(SettingKey.dateFormat, store: SharedStore.defaults) private var dateFormat = SettingDefault.dateFormat
    @AppStorage(SettingKey.customDateFormat, store: SharedStore.defaults) private var customDate = SettingDefault.customDateFormat
    @AppStorage(SettingKey.timeFormat, store: SharedStore.defaults) private var timeFormat = SettingDefault.timeFormat
    @AppStorage(SettingKey.timeSeconds, store: SharedStore.defaults) private var timeSeconds = SettingDefault.timeSeconds

    private let dateStyles = ["short", "medium", "long", "full", "iso", "custom"]
    private let timeStyles = ["system", "24h", "12h"]
    /// Shortcuts to start from while there are none.
    private let examples: [(trigger: String, phrase: String)] = [("omw", tr("On my way!")), ("dt", "{date} {time}")]

    /// Dates are written in the words of the language the keyboard opens in.
    private var locale: Locale {
        return Locale(identifier: LiveKeyboardView.openingLanguage(code: Settings.shared.languageCode).localeIdentifier)
    }

    private var sorted: [TextShortcut] {
        return items.sorted { $0.trigger.localizedStandardCompare($1.trigger) == .orderedAscending }
    }

    private func dateExample(_ style: String) -> String {
        return ShortcutTemplate.dateText(Date(), locale: locale, style: style, custom: customDate)
    }

    var body: some View {
        GlassList {
            Section {
                Button {
                    Feedback.tap()
                    composing = ShortcutDraft(original: nil, trigger: "", phrase: "")
                } label: {
                    Label(tr("New shortcut"), systemImage: "plus")
                }
                .buttonStyle(ActionButtonStyle())
                .searchAnchor("shortcuts.new")
                .glassOutsideCard()
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
                GlassToggle(title: tr("Seconds"),
                            subtitle: ShortcutTemplate.timeText(Date(), locale: locale, style: timeFormat, seconds: timeSeconds),
                            isOn: $timeSeconds)
            } header: {
                SectionHeader(tr("Date and time"), symbol: "calendar", color: .red)
            } footer: {
                Text(dateFormat == "custom"
                     ? tr("Letters stand for parts of the date: yyyy year, MM month, MMMM month's name, dd day, EEEE weekday.")
                     : tr("How {date}, {time} and {datetime} are written, in the words of your keyboard's language."))
            }
            .glassRows()

            Section {
                if items.isEmpty {
                    emptyState
                } else {
                    ForEach(sorted, id: \.id) { item in
                        Button {
                            Feedback.tap()
                            composing = ShortcutDraft(original: item, trigger: item.trigger, phrase: item.phrase)
                        } label: {
                            ShortcutRow(item: item)
                        }
                        .buttonStyle(NoPressStyle())   // the row slides to delete: nothing lights up under the finger
                        .swipeToDelete { remove(item) }
                    }
                }
            } header: {
                SectionHeader(tr("Your shortcuts"), symbol: "bolt.fill", color: .orange)
            } footer: {
                if !items.isEmpty { Text(tr("Tap a shortcut to change it; swipe it left to remove it.")) }
            }
            .glassRows()
        }
        .glassScreen()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(tr("Text shortcuts"))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $composing, onDismiss: applyPending) { draft in
            ShortcutComposer(draft: draft, locale: locale, others: items.filter { $0.id != draft.original?.id },
                             save: { trigger, phrase in pending = .save(draft, trigger: trigger, phrase: phrase) },
                             delete: deletion(of: draft.original))
        }
        // Read again on every visit: the screen is built once with the parent, so the starting value above is
        // from when the app opened.
        .onAppear { items = Settings.shared.shortcuts }
    }

    /// No shortcuts yet: what one is, and two to start from.
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Type the trigger and press space: the phrase takes its place."))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                ForEach(examples, id: \.trigger) { example in
                    Button {
                        Feedback.tap()
                        composing = ShortcutDraft(original: nil, trigger: example.trigger, phrase: example.phrase)
                    } label: {
                        HStack(spacing: 6) {
                            Text(example.trigger).font(.subheadline.monospaced().weight(.semibold))
                            Image(systemName: "arrow.right").font(.caption2.weight(.bold)).foregroundColor(.secondary)
                            Text(example.phrase).font(.subheadline).lineLimit(1)
                        }
                        .foregroundColor(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.accentColor.opacity(0.18)))
                        .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func save(_ draft: ShortcutDraft, trigger: String, phrase: String) {
        var list = items
        // One shortcut for a trigger: the one being changed, and any other with the same trigger, give way.
        list.removeAll { $0.id == draft.original?.id || $0.trigger.lowercased() == trigger.lowercased() }
        list.append(TextShortcut(trigger: trigger, phrase: phrase))
        Feedback.success()
        items = list
        Settings.shared.shortcuts = list
    }

    /// Removes a shortcut. The list changes at once, without an animation: an animated removal takes the row (and,
    /// for the first row, its whole card) out while it is still being drawn.
    private func remove(_ item: TextShortcut) {
        guard items.contains(where: { $0.id == item.id }) else { return }
        // A sheet open on the shortcut that is going closes with it.
        if composing?.original?.id == item.id { composing = nil }
        Feedback.delete()
        var list = items
        list.removeAll { $0.id == item.id }
        items = list
        Settings.shared.shortcuts = list
    }

    /// What the sheet's Delete does: the shortcut being changed is removed once the sheet has closed (a new one has
    /// nothing to delete).
    private func deletion(of original: TextShortcut?) -> (() -> Void)? {
        guard let original = original else { return nil }
        return { pending = .remove(original) }
    }

    /// The sheet has closed: what it decided is done now.
    private func applyPending() {
        guard let change = pending else { return }
        pending = nil
        switch change {
        case .save(let draft, let trigger, let phrase): save(draft, trigger: trigger, phrase: phrase)
        case .remove(let item): remove(item)
        }
    }
}

/// The shortcut the sheet is open on: a new one (`original` nil), or one being changed.
struct ShortcutDraft: Identifiable {
    let id = UUID()
    let original: TextShortcut?
    let trigger: String
    let phrase: String
}

/// A shortcut in the list: its trigger as it is typed, and the phrase it writes.
private struct ShortcutRow: View {
    let item: TextShortcut
    @Environment(\.swipeFade) private var swipeFade

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.trigger)
                    .font(.subheadline.monospaced().weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.accentColor.opacity(0.2)))
                Text(item.phrase)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 8)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundColor(Color(.tertiaryLabel))
                .opacity(swipeFade)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

// MARK: - Writing a shortcut

/// The sheet a shortcut is written or changed on: what typing it will do (shown as the suggestion bar shows it),
/// its trigger and phrase, and the placeholders to drop into the phrase.
private struct ShortcutComposer: View {
    let draft: ShortcutDraft
    let locale: Locale
    /// The other shortcuts (one with the same trigger is replaced: the sheet says so).
    let others: [TextShortcut]
    let save: (String, String) -> Void
    /// Removes the shortcut being changed (nil for a new one).
    let delete: (() -> Void)?

    private enum Field { case trigger, phrase }

    @State private var trigger: String
    @State private var phrase: String
    @FocusState private var focus: Field?
    @Environment(\.dismiss) private var dismiss
    /// The placeholders and their notes, worked out once when the sheet opens: the sheet is drawn again on every
    /// key typed, and each note takes several date formatters.
    @State private var tokens: [(token: String, note: String)] = []

    init(draft: ShortcutDraft, locale: Locale, others: [TextShortcut], save: @escaping (String, String) -> Void,
         delete: (() -> Void)?) {
        self.draft = draft
        self.locale = locale
        self.others = others
        self.save = save
        self.delete = delete
        _trigger = State(initialValue: draft.trigger)
        _phrase = State(initialValue: draft.phrase)
    }

    private var cleanTrigger: String { return trigger.trimmingCharacters(in: .whitespaces) }
    private var cleanPhrase: String { return phrase.trimmingCharacters(in: .whitespaces) }
    private var canSave: Bool { return !cleanTrigger.isEmpty && !cleanPhrase.isEmpty }

    /// Another shortcut already answers to this trigger.
    private var replaces: Bool {
        let key = cleanTrigger.lowercased()
        return !key.isEmpty && others.contains { $0.trigger.lowercased() == key }
    }

    /// The phrase as typing its trigger writes it today ({cursor} shown as a thin bar).
    private var filledPhrase: String {
        let written = cleanPhrase
        guard ShortcutTemplate.hasPlaceholders(written) else { return written }
        let expanded = ShortcutTemplate.expand(written, locale: locale) { tr("copied text") }
        return expanded.replacingOccurrences(of: String(ShortcutTemplate.cursorMark), with: "\u{258F}")
    }

    /// The placeholders with what each is, then the days, months and times ahead with what they write today. The
    /// names of the days and months, and the dates and times, are in the app's language (the language these notes
    /// are read in) and in the date and time formats set.
    private func makeTokens() -> [(token: String, note: String)] {
        let shown = AppLanguage.locale
        let plain = ShortcutTemplate.placeholders.map { item -> (token: String, note: String) in
            return (token: item.token, note: note(for: item.token, described: tr(item.note), locale: shown))
        }
        let ahead = ShortcutTemplate.offsetExamples.map { token -> (token: String, note: String) in
            return (token: token, note: ShortcutTemplate.expand(token, locale: shown) { nil })
        }
        return plain + ahead
    }

    /// A placeholder's note: what it is, and (for the ones that write a date, a time or a name) what that is today.
    private func note(for token: String, described: String, locale: Locale) -> String {
        if token == "{clipboard}" || token == "{cursor}" { return described }
        let value = ShortcutTemplate.expand(token, locale: locale) { nil }
        return value.isEmpty || value == token ? described : described + ": " + value
    }

    var body: some View {
        NavigationStack {
            GlassList(eager: true) {
                Section {
                    ShortcutPreview(trigger: trigger, phrase: filledPhrase)
                        .glassOutsideCard()
                }
                .glassRows()

                Section {
                    TextField(tr("Trigger (e.g. omw)"), text: $trigger)
                        .focused($focus, equals: .trigger)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.body.monospaced())
                        .submitLabel(.next)
                        .onSubmit { focus = .phrase }
                    TextField(tr("Phrase (e.g. On my way!)"), text: $phrase, axis: .vertical)
                        .focused($focus, equals: .phrase)
                        .lineLimit(1...6)
                } footer: {
                    if replaces {
                        Label(tr("Replaces the shortcut you already have for this trigger."),
                              systemImage: "arrow.triangle.2.circlepath")
                            .foregroundColor(.orange)
                    }
                }
                .glassRows()

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8, alignment: .top)], spacing: 8) {
                        ForEach(tokens, id: \.token) { item in
                            Button {
                                Feedback.tick()
                                phrase += (phrase.isEmpty || phrase.hasSuffix(" ") ? "" : " ") + item.token
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.token)
                                        .font(.subheadline.monospaced().weight(.semibold))
                                        .foregroundColor(.primary)
                                    Text(item.note)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.primary.opacity(0.06)))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    SectionHeader(tr("Placeholders"), symbol: "curlybraces", color: .orange)
                } footer: {
                    Text(tr("Tap one to add it to the phrase. They are filled in when you type the shortcut: \u{201C}Sent {date}\u{201D} writes today's date."))
                }
                .glassRows()

                if let delete = delete {
                    Section {
                        Button(role: .destructive) {
                            delete()
                            dismiss()
                        } label: {
                            Label(tr("Delete"), systemImage: "trash")
                        }
                        .buttonStyle(ActionButtonStyle())
                        .glassOutsideCard()
                    }
                    .glassRows()
                }
            }
            .glassScreen()
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(draft.original == nil ? tr("New shortcut") : tr("Edit shortcut"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("Save")) {
                        save(cleanTrigger, cleanPhrase)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .onAppear {
            Settings.shared.refresh()   // the formats just picked, not the half-second-old copy
            if tokens.isEmpty { tokens = makeTokens() }
            // A new shortcut starts in its trigger; one being changed is read first.
            if draft.original == nil && draft.trigger.isEmpty { focus = .trigger }
        }
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
                        .font(.system(size: 15, design: .rounded))
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

import SwiftUI
import UIKit

// MARK: - Entering characters for a key's hold
//
// The characters a hold offers are edited in one way everywhere (the long-press characters of a key, the holds of
// the comma and the full stop): they stand in a row of cells in the order the hold offers them, and a field under
// them takes new ones. The field never holds text of its own: every character typed or pasted becomes a cell at
// once, or is turned away (a space, one that is there already, one more than fit), so what is in the cells is always
// exactly what the keyboard will offer.

/// A text field that hands over what is typed into it and stays empty. Characters go to `insert` as they are typed
/// or pasted; delete on the empty field calls `deleteBackward`. A composition still being written (an input method
/// offering candidates) is left in the field until it is settled, then handed over like the rest.
struct CharacterEntryField: UIViewRepresentable {
    let placeholder: String
    let tint: Color
    let insert: (String) -> Void
    let deleteBackward: () -> Void

    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }

    func makeUIView(context: Context) -> EntryTextField {
        let field = EntryTextField()
        let coordinator = context.coordinator
        field.delegate = coordinator
        field.addTarget(coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.onDeleteWhenEmpty = { [weak coordinator] in coordinator?.parent.deleteBackward() }
        // Nothing may change what is typed: these are single symbols, not prose.
        field.autocorrectionType = .no
        field.autocapitalizationType = .none
        field.spellCheckingType = .no
        field.smartQuotesType = .no
        field.smartDashesType = .no
        field.smartInsertDeleteType = .no
        field.returnKeyType = .done
        field.clearButtonMode = .never
        // The app's rounded type, at the body size.
        let base = UIFont.preferredFont(forTextStyle: .body)
        if let descriptor = base.fontDescriptor.withDesign(.rounded) {
            field.font = UIFont(descriptor: descriptor, size: base.pointSize)
        } else {
            field.font = base
        }
        // As wide as the row lets it be.
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateUIView(_ field: EntryTextField, context: Context) {
        context.coordinator.parent = self
        if field.placeholder != placeholder { field.placeholder = placeholder }
        field.tintColor = UIColor(tint)
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: CharacterEntryField

        init(_ parent: CharacterEntryField) {
            self.parent = parent
        }

        @objc func changed(_ field: UITextField) {
            // While an input method is composing, its marked text stays in the field.
            guard field.markedTextRange == nil, let text = field.text, !text.isEmpty else { return }
            field.text = ""
            parent.insert(text)
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}

/// The field itself: it reports delete pressed while it is empty (UITextField tells nobody about that).
final class EntryTextField: UITextField {
    var onDeleteWhenEmpty: (() -> Void)?

    override func deleteBackward() {
        if (text ?? "").isEmpty { onDeleteWhenEmpty?() }
        super.deleteBackward()
    }
}

/// The characters of one hold, and the field that adds to them. `fixed` are the ones the key offers anyway (a
/// language's accents): shown first and dimmed, they cannot be changed. The user's own follow in the accent: a tap
/// on one moves or removes it. No more than `limit` fit; the count beside the field shows how many there are.
struct HoldEditor: View {
    var fixed: [String] = []
    /// A character that is never added (the key's own letter).
    var excluded: String? = nil
    let characters: [String]
    var limit: Int = Settings.holdSymbolsLimit
    /// Said in place of the cells while there are none.
    let emptyNote: String
    let change: ([String]) -> Void
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex

    private var isFull: Bool { return characters.count >= limit }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if fixed.isEmpty && characters.isEmpty {
                Text(emptyNote)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                cells
            }
            entry
        }
        .padding(.vertical, 4)
    }

    private var cells: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44), spacing: 8)], spacing: 8) {
            ForEach(fixed, id: \.self) { character in
                HoldCell(character: character, own: false)
                    .accessibilityLabel(tr("%@, from your language", character))
            }
            ForEach(characters, id: \.self) { character in
                let index = characters.firstIndex(of: character) ?? 0
                Menu {
                    Button {
                        move(character, by: -1)
                    } label: {
                        Label(tr("Move earlier"), systemImage: "arrow.left")
                    }
                    .disabled(index == 0)
                    Button {
                        move(character, by: 1)
                    } label: {
                        Label(tr("Move later"), systemImage: "arrow.right")
                    }
                    .disabled(index >= characters.count - 1)
                    Button(role: .destructive) {
                        remove(character)
                    } label: {
                        Label(tr("Remove"), systemImage: "trash")
                    }
                } label: {
                    HoldCell(character: character, own: true)
                }
                .buttonStyle(.plain)
            }
        }
        // A hold is laid out left to right, as on the keyboard.
        .environment(\.layoutDirection, .leftToRight)
    }

    /// The field, and how many of the places are taken.
    private var entry: some View {
        HStack(spacing: 10) {
            Image(systemName: isFull ? "checkmark.circle.fill" : "plus.circle.fill")
                .foregroundColor(isFull ? .secondary : .accentColor)
                .accessibilityHidden(true)
            CharacterEntryField(placeholder: isFull ? tr("Full. Remove one to add another.") : tr("Type or paste characters"),
                                tint: Color.currentAccent(name: accentName, hex: accentHex),
                                insert: { text in add(text) },
                                deleteBackward: { removeLast() })
                .frame(height: 30)
            Text("\(characters.count)/\(limit)")
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundColor(isFull ? .orange : .secondary)
                .accessibilityLabel(tr("%@ of %@", "\(characters.count)", "\(limit)"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.06)))
    }

    /// Adds the characters of `text` that may be added, in order, until the hold is full. Spaces, the key's own
    /// letter and characters the hold already offers are left out.
    private func add(_ text: String) {
        var list = characters
        var turnedAway = false
        for character in text where !character.isWhitespace && !character.isNewline {
            let symbol = String(character)
            if symbol == excluded || list.contains(symbol) || fixed.contains(symbol) {
                turnedAway = true
                continue
            }
            if list.count >= limit {
                turnedAway = true
                break
            }
            list.append(symbol)
        }
        if list.count > characters.count {
            Feedback.choose()
            change(list)
        } else if turnedAway {
            // Nothing new fitted: a knock says so (the field stays empty).
            Feedback.threshold()
        }
    }

    private func removeLast() {
        guard !characters.isEmpty else { return }
        Feedback.delete()
        change(Array(characters.dropLast()))
    }

    private func remove(_ character: String) {
        Feedback.delete()
        change(characters.filter { $0 != character })
    }

    private func move(_ character: String, by step: Int) {
        var list = characters
        guard let from = list.firstIndex(of: character) else { return }
        let to = from + step
        guard list.indices.contains(to) else { return }
        list.swapAt(from, to)
        Feedback.tick()
        change(list)
    }
}

/// One character of a hold: the user's own on the accent, the language's dimmed.
struct HoldCell: View {
    let character: String
    let own: Bool

    var body: some View {
        Text(character)
            .font(.system(size: 21, weight: .medium))
            .foregroundColor(own ? .primary : .secondary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(own ? Color.accentColor.opacity(0.24) : Color.primary.opacity(0.06)))
            .contentShape(Rectangle())
    }
}

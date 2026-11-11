import SwiftUI

// MARK: - Taking the user to a setting

/// A setting picked in the main list's search: the screen it is on (nil: the main list) and the row to show. The list
/// of that screen scrolls to the row and lights it up for a moment (GlassList, searchAnchor).
final class SearchFocus: ObservableObject {
    static let shared = SearchFocus()

    struct Request {
        let screen: Screen?
        let anchor: String
    }

    /// Waiting for its screen's list to appear.
    var request: Request?
    /// The row lit up right now.
    @Published var highlighted: String?

    /// The list of `screen` appeared: if a setting on it was asked for, it is scrolled to and lit up.
    func consume(in screen: Screen?, proxy: ScrollViewProxy) {
        guard let request = request, request.screen == screen else { return }
        self.request = nil
        let anchor = request.anchor
        // After the screen's push animation, so the row is laid out where it ends up.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo(anchor, anchor: .center) }
            withAnimation(.easeIn(duration: 0.2)) { self.highlighted = anchor }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                if self.highlighted == anchor {
                    withAnimation(.easeOut(duration: 0.5)) { self.highlighted = nil }
                }
            }
        }
    }
}

private struct SearchScopeKey: EnvironmentKey {
    static let defaultValue: Screen? = nil
}

extension EnvironmentValues {
    /// The screen a list belongs to (nil: the main list), so a search lands on the right one.
    var searchScope: Screen? {
        get { return self[SearchScopeKey.self] }
        set { self[SearchScopeKey.self] = newValue }
    }
}

/// Marks a row the search can take the user to: the list scrolls to it and it glows in the accent for a moment.
private struct SearchAnchor: ViewModifier {
    let id: String
    @ObservedObject private var focus = SearchFocus.shared

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(focus.highlighted == id ? 0.25 : 0))
                    .padding(.horizontal, -8)
                    .padding(.vertical, -4)
                    .allowsHitTesting(false))
            .id(id)
    }
}

extension View {
    func searchAnchor(_ id: String) -> some View {
        return modifier(SearchAnchor(id: id))
    }
}

// MARK: - The index

/// One setting the search finds: what it is called, where it is (shown under it), more words it is found by, and the
/// screen and row it opens.
struct SearchEntry: Identifiable {
    let id: String
    let title: String
    let place: String
    let keywords: [String]
    let symbol: String
    let color: Color
    let screen: Screen?
    /// The row on the screen (nil: the screen's top).
    let anchor: String?
}

enum SettingsIndex {
    /// Every setting, in the app's language (English words are always found too).
    static var entries: [SearchEntry] {
        let keyboard = tr("Keyboard")
        let typing = tr("Typing")
        let look = tr("Look & feel")
        let data = tr("Privacy & data")
        func at(_ screen: String, _ section: String) -> String { return screen + " \u{203A} " + section }
        let gestures = tr("Gestures")
        let keys = tr("Keys")
        let bar = tr("Suggestion bar")
        let smart = tr("Calculator & units")
        let shortcuts = tr("Text shortcuts")
        let haptics = tr("Haptics")
        return [
            SearchEntry(id: "test", title: tr("Try it"), place: tr("Main list"), keywords: ["test", "type"],
                        symbol: "keyboard", color: .gray, screen: nil, anchor: "main.test"),
            SearchEntry(id: "languages", title: tr("Languages"), place: keyboard, keywords: ["language", "add", "remove", "switch"],
                        symbol: "globe", color: .blue, screen: .languages, anchor: nil),
            SearchEntry(id: "layout", title: tr("Keyboard layout"), place: at(tr("Languages"), tr("Tap a language")),
                        keywords: ["layout", "qwerty", "qwertz", "azerty", "dvorak", "colemak", "workman"],
                        symbol: "keyboard.badge.ellipsis", color: .blue, screen: .languages, anchor: "languages.list"),
            SearchEntry(id: "learned", title: tr("Learned words"), place: keyboard, keywords: ["dictionary", "words", "learned"],
                        symbol: "character.book.closed", color: .brown, screen: .learnedWords, anchor: nil),
            SearchEntry(id: "shortcuts", title: shortcuts, place: keyboard, keywords: ["shortcut", "replacement", "expand", "abbreviation"],
                        symbol: "bolt.fill", color: .orange, screen: .shortcuts, anchor: nil),
            SearchEntry(id: "placeholders", title: tr("Placeholders"), place: shortcuts,
                        keywords: ["placeholder", "date", "time", "clipboard", "cursor", "{date}"],
                        symbol: "curlybraces", color: .orange, screen: .shortcuts, anchor: "shortcuts.placeholders"),
            SearchEntry(id: "dateFormat", title: tr("Date format"), place: shortcuts, keywords: ["date", "format", "day", "month"],
                        symbol: "calendar", color: .orange, screen: .shortcuts, anchor: "shortcuts.date"),
            SearchEntry(id: "timeFormat", title: tr("Time format"), place: shortcuts, keywords: ["time", "clock", "24", "12", "seconds"],
                        symbol: "clock", color: .orange, screen: .shortcuts, anchor: "shortcuts.time"),
            SearchEntry(id: "functions", title: tr("Functions panel"), place: keyboard, keywords: ["tools", "functions", "panel"],
                        symbol: "square.grid.2x2.fill", color: .pink, screen: .functions, anchor: nil),

            SearchEntry(id: "bar", title: bar, place: typing, keywords: ["suggestions", "bar", "predictions"],
                        symbol: "text.line.first.and.arrowtriangle.forward", color: .indigo, screen: .suggestions, anchor: nil),
            SearchEntry(id: "wordSuggestions", title: tr("Word suggestions"), place: bar, keywords: ["predictions", "suggestions"],
                        symbol: "text.bubble", color: .indigo, screen: .suggestions, anchor: "suggestions.words"),
            SearchEntry(id: "emojiSuggestions", title: tr("Emoji suggestions"), place: bar, keywords: ["emoji", "smiley"],
                        symbol: "face.smiling", color: .indigo, screen: .suggestions, anchor: "suggestions.words"),
            SearchEntry(id: "wordsShown", title: tr("Words shown"), place: bar, keywords: ["three", "scrolling", "fit"],
                        symbol: "text.line.first.and.arrowtriangle.forward", color: .indigo, screen: .suggestions, anchor: "suggestions.count"),
            SearchEntry(id: "barLook", title: tr("Bar height"), place: at(bar, tr("Look")), keywords: ["height", "lines", "tiles", "separator"],
                        symbol: "arrow.up.and.down", color: .indigo, screen: .suggestions, anchor: "suggestions.look"),
            SearchEntry(id: "switching", title: tr("Switching"), place: bar, keywords: ["animation", "fade", "slide", "transition"],
                        symbol: "arrow.left.arrow.right", color: .indigo, screen: .suggestions, anchor: "suggestions.switching"),
            SearchEntry(id: "updateSpeed", title: tr("Update speed"), place: bar, keywords: ["speed", "delay", "battery"],
                        symbol: "speedometer", color: .indigo, screen: .suggestions, anchor: "suggestions.speed"),
            SearchEntry(id: "autocorrect", title: tr("Auto-correction"), place: typing, keywords: ["autocorrect", "typo", "correct", "spelling"],
                        symbol: "checkmark.seal.fill", color: .green, screen: nil, anchor: "main.autocorrect"),
            SearchEntry(id: "autocap", title: tr("Auto-capitalization"), place: typing, keywords: ["capital", "uppercase", "sentence"],
                        symbol: "textformat", color: .blue, screen: nil, anchor: "main.autocap"),
            SearchEntry(id: "period", title: tr("\u{201C}.\u{201D} shortcut"), place: typing, keywords: ["period", "full stop", "double space"],
                        symbol: "circle.fill", color: .gray, screen: nil, anchor: "main.period"),
            SearchEntry(id: "smartQuotes", title: tr("Smart quotes"), place: typing, keywords: ["quotes", "curly", "apostrophe", "quotation"],
                        symbol: "quote.opening", color: .teal, screen: nil, anchor: "main.smartQuotes"),
            SearchEntry(id: "spaceAfter", title: tr("Space after punctuation"), place: typing, keywords: ["space", "punctuation", "comma", "period"],
                        symbol: "space", color: .mint, screen: nil, anchor: "main.spaceAfter"),
            SearchEntry(id: "smart", title: smart, place: typing, keywords: ["calculator", "math", "units", "convert"],
                        symbol: "function", color: .orange, screen: .smartTyping, anchor: nil),
            SearchEntry(id: "math", title: tr("Calculator"), place: smart, keywords: ["math", "calculate", "sum", "equals", "="],
                        symbol: "plus.forwardslash.minus", color: .orange, screen: .smartTyping, anchor: "smart.math"),
            SearchEntry(id: "units", title: tr("Unit conversion"), place: smart,
                        keywords: ["units", "convert", "metric", "imperial", "km", "miles", "celsius", "fahrenheit"],
                        symbol: "ruler", color: .orange, screen: .smartTyping, anchor: "smart.units"),
            SearchEntry(id: "decimals", title: tr("Decimal places"), place: smart, keywords: ["decimals", "rounding", "digits"],
                        symbol: "number", color: .orange, screen: .smartTyping, anchor: "smart.decimals"),

            SearchEntry(id: "gestures", title: gestures, place: tr("Touch & gestures"), keywords: ["gesture", "swipe", "touch"],
                        symbol: "hand.draw.fill", color: .teal, screen: .gestures, anchor: nil),
            SearchEntry(id: "swipe", title: tr("Swipe typing"), place: gestures, keywords: ["swipe", "glide", "slide", "thumb", "phrase"],
                        symbol: "scribble.variable", color: .teal, screen: .gestures, anchor: "gestures.swipe"),
            SearchEntry(id: "trail", title: tr("Swipe trail"), place: gestures,
                        keywords: ["trail", "line", "colour", "color", "width", "rainbow", "dotted", "opacity", "length"],
                        symbol: "scribble", color: .teal, screen: .gestures, anchor: "gestures.trail"),
            SearchEntry(id: "holdDelay", title: tr("Hold delay"), place: at(gestures, tr("Accents and capitals")),
                        keywords: ["hold", "long press", "accents", "delay"],
                        symbol: "hand.tap", color: .teal, screen: .gestures, anchor: "gestures.accents"),
            SearchEntry(id: "flicks", title: tr("Flick up for a capital"), place: at(gestures, tr("Accents and capitals")),
                        keywords: ["flick", "capital", "accent", "down"],
                        symbol: "arrow.up", color: .teal, screen: .gestures, anchor: "gestures.accents"),
            SearchEntry(id: "hide", title: tr("Swipe down to hide"), place: gestures, keywords: ["hide", "dismiss", "close"],
                        symbol: "keyboard.chevron.compact.down", color: .teal, screen: .gestures, anchor: "gestures.hide"),
            SearchEntry(id: "cursor", title: tr("Move the cursor"), place: at(gestures, tr("Space bar")), keywords: ["cursor", "trackpad", "space"],
                        symbol: "cursorarrow.motionlines", color: .teal, screen: .gestures, anchor: "gestures.space"),
            SearchEntry(id: "select", title: tr("Select text"), place: at(gestures, tr("Space bar")),
                        keywords: ["select", "selection", "copy", "cut", "paste", "highlight"],
                        symbol: "selection.pin.in.out", color: .teal, screen: .gestures, anchor: "gestures.space"),
            SearchEntry(id: "cursorSpeed", title: tr("Cursor speed"), place: at(gestures, tr("Space bar")), keywords: ["cursor", "speed", "sensitivity"],
                        symbol: "speedometer", color: .teal, screen: .gestures, anchor: "gestures.cursorSpeed"),
            SearchEntry(id: "deleteWords", title: tr("Delete whole words"), place: at(gestures, tr("Delete key")), keywords: ["delete", "backspace", "words"],
                        symbol: "delete.left.fill", color: .red, screen: .gestures, anchor: "gestures.delete"),
            SearchEntry(id: "repeatDelay", title: tr("Repeat delay"), place: at(gestures, tr("Delete key")), keywords: ["delete", "backspace", "hold", "repeat"],
                        symbol: "timer", color: .red, screen: .gestures, anchor: "gestures.delete"),
            SearchEntry(id: "repeatSpeed", title: tr("Repeat speed"), place: at(gestures, tr("Delete key")), keywords: ["delete", "backspace", "speed", "repeat"],
                        symbol: "hare", color: .red, screen: .gestures, anchor: "gestures.repeatSpeed"),

            SearchEntry(id: "themes", title: tr("Themes"), place: look, keywords: ["theme", "dark", "light", "colour", "color", "appearance"],
                        symbol: "paintbrush.fill", color: .purple, screen: .themes, anchor: nil),
            SearchEntry(id: "keys", title: keys, place: look, keywords: ["keys", "size", "height"],
                        symbol: "square.grid.3x2.fill", color: .blue, screen: .keys, anchor: nil),
            SearchEntry(id: "keySize", title: tr("Key height"), place: at(keys, tr("Size")), keywords: ["height", "size", "width", "landscape"],
                        symbol: "arrow.up.and.down", color: .blue, screen: .keys, anchor: "keys.size"),
            SearchEntry(id: "numberRow", title: tr("Number row"), place: at(keys, tr("Layout")), keywords: ["numbers", "digits", "row"],
                        symbol: "number", color: .blue, screen: .keys, anchor: "keys.layout"),
            SearchEntry(id: "popups", title: tr("Key pop-ups"), place: at(keys, tr("Letters")), keywords: ["popup", "preview", "magnify"],
                        symbol: "rectangle.portrait.on.rectangle.portrait", color: .blue, screen: .keys, anchor: "keys.popups"),
            SearchEntry(id: "split", title: tr("Split keyboard"), place: at(keys, tr("Layout")), keywords: ["split", "ipad", "thumbs"],
                        symbol: "rectangle.split.2x1", color: .blue, screen: .keys, anchor: "keys.layout"),
            SearchEntry(id: "oneHanded", title: tr("One-handed"), place: at(keys, tr("Layout")), keywords: ["one hand", "narrow", "left", "right"],
                        symbol: "hand.raised", color: .blue, screen: .keys, anchor: "keys.layout"),
            SearchEntry(id: "spacing", title: tr("Spacing"), place: keys, keywords: ["gap", "spacing", "between keys", "rows"],
                        symbol: "square.split.2x2", color: .blue, screen: .keys, anchor: "keys.spacing"),
            SearchEntry(id: "font", title: tr("Font"), place: at(keys, tr("Letters")), keywords: ["font", "typeface", "letter size", "capitals"],
                        symbol: "textformat.alt", color: .blue, screen: .keys, anchor: "keys.letters"),
            SearchEntry(id: "hints", title: tr("Accent hints"), place: keys, keywords: ["hint", "accent", "corner"],
                        symbol: "textformat.abc.dottedunderline", color: .blue, screen: .keys, anchor: "keys.hints"),
            SearchEntry(id: "holds", title: tr("Long-press characters"), place: keys,
                        keywords: ["long press", "hold", "characters", "symbols", "custom", "accents"],
                        symbol: "hand.point.up.left", color: .blue, screen: .keys, anchor: "keys.holds"),
            SearchEntry(id: "spaceBar", title: tr("Space bar"), place: keys, keywords: ["space", "language name", "code"],
                        symbol: "space", color: .blue, screen: .keys, anchor: "keys.space"),
            SearchEntry(id: "symbolKeys", title: tr("Symbol keys"), place: keys, keywords: ["symbol", "@", "extra keys"],
                        symbol: "at", color: .blue, screen: .keys, anchor: "keys.symbols"),
            SearchEntry(id: "bottomRow", title: tr("Bottom row"), place: keys, keywords: ["emoji key", "comma", "full stop", "period"],
                        symbol: "keyboard.chevron.compact.down", color: .blue, screen: .keys, anchor: "keys.bottom"),
            SearchEntry(id: "effects", title: tr("Effects"), place: look, keywords: ["effects", "glow", "ripple", "animation", "sparkle"],
                        symbol: "sparkles", color: .indigo, screen: .effects, anchor: nil),
            SearchEntry(id: "haptics", title: haptics, place: look, keywords: ["vibration", "haptic", "feel"],
                        symbol: "iphone.radiowaves.left.and.right", color: .pink, screen: .haptics, anchor: nil),
            SearchEntry(id: "vibration", title: tr("Vibration"), place: haptics, keywords: ["vibrate", "strength", "sharpness"],
                        symbol: "waveform", color: .pink, screen: .haptics, anchor: "haptics.vibration"),
            SearchEntry(id: "cursorTicks", title: tr("Cursor ticks"), place: haptics, keywords: ["cursor", "tick", "vibration"],
                        symbol: "cursorarrow.rays", color: .pink, screen: .haptics, anchor: "haptics.cursor"),
            SearchEntry(id: "sound", title: tr("Key clicks"), place: at(haptics, tr("Sound")), keywords: ["sound", "click", "audio"],
                        symbol: "speaker.wave.2.fill", color: .pink, screen: .haptics, anchor: "haptics.sound"),
            SearchEntry(id: "accent", title: tr("Accent colour"), place: look, keywords: ["accent", "colour", "color", "tint"],
                        symbol: "drop.fill", color: .blue, screen: nil, anchor: "main.accent"),

            SearchEntry(id: "stats", title: tr("Typing stats"), place: data, keywords: ["stats", "statistics", "speed", "wpm", "words"],
                        symbol: "chart.bar.fill", color: .green, screen: .stats, anchor: nil),
            SearchEntry(id: "forget", title: tr("Forget learned words"), place: data, keywords: ["forget", "clear", "learned"],
                        symbol: "text.book.closed", color: .orange, screen: nil, anchor: "main.forget"),
            SearchEntry(id: "reset", title: tr("Reset all settings"), place: data, keywords: ["reset", "default", "restore"],
                        symbol: "arrow.counterclockwise", color: .red, screen: nil, anchor: "main.reset"),
            SearchEntry(id: "appLanguage", title: tr("App language"), place: tr("Language"), keywords: ["app language", "translation"],
                        symbol: "character.bubble.fill", color: .blue, screen: .appLanguage, anchor: nil),
            SearchEntry(id: "welcome", title: tr("Replay welcome"), place: tr("About"), keywords: ["welcome", "tutorial", "intro", "help"],
                        symbol: "play.circle.fill", color: .blue, screen: nil, anchor: "main.welcome"),
            SearchEntry(id: "licences", title: tr("Licences"), place: tr("About"), keywords: ["licence", "license", "credits"],
                        symbol: "doc.text.fill", color: .gray, screen: .licences, anchor: nil)
        ]
    }

    /// The entries that match `query`, best first: a title that starts with it, then one that has it, then its
    /// place or other words.
    static func search(_ query: String) -> [SearchEntry] {
        let words = query.split(separator: " ").map { String($0) }
        guard !words.isEmpty else { return [] }
        let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive]
        func has(_ text: String, _ word: String) -> Bool { return text.range(of: word, options: options) != nil }
        var scored: [(entry: SearchEntry, score: Int, order: Int)] = []
        for (order, entry) in entries.enumerated() {
            var score = 0
            var all = true
            for word in words {
                if entry.title.range(of: word, options: options.union(.anchored)) != nil {
                    score += 4
                } else if has(entry.title, word) {
                    score += 3
                } else if entry.keywords.contains(where: { has($0, word) }) {
                    score += 2
                } else if has(entry.place, word) {
                    score += 1
                } else {
                    all = false
                    break
                }
            }
            if all { scored.append((entry, score, order)) }
        }
        return scored.sorted { $0.score != $1.score ? $0.score > $1.score : $0.order < $1.order }.map { $0.entry }
    }
}

// MARK: - Results

/// The main list while searching: the settings that match, each with where it is; a tap goes there.
struct SettingsSearchResults: View {
    let query: String
    let open: (SearchEntry) -> Void
    @Environment(\.dismissSearch) private var dismissSearch

    var body: some View {
        let results = SettingsIndex.search(query)
        GlassList {
            Section {
                if results.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").font(.title2).foregroundColor(.secondary)
                        Text(tr("No settings match \u{201C}%@\u{201D}", query))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                } else {
                    ForEach(results) { entry in
                        Button {
                            Feedback.tap()
                            dismissSearch()
                            open(entry)
                        } label: {
                            HStack(spacing: 12) {
                                IconTile(symbol: entry.symbol, color: entry.color)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.title).foregroundColor(.primary)
                                    Text(entry.place).font(.footnote).foregroundColor(.secondary)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.forward")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(Color(.tertiaryLabel))
                            }
                            .contentShape(Rectangle())
                        }
                    }
                }
            } header: {
                if !results.isEmpty {
                    Text(results.count == 1 ? tr("1 setting") : tr("%@ settings", "\(results.count)"))
                }
            }
            .glassRows()
        }
        .glassScreen()
    }
}

import UIKit

/// Glue between the system text field (`textDocumentProxy`) and all keyboard components.
final class KeyboardViewController: UIInputViewController {

    // MARK: UI

    private let suggestionBar = SuggestionBar()
    private let keyboardView = KeyboardView()
    private var emojiPanel: EmojiPanel?
    private var settingsPanel: SettingsPanel?
    private var totalHeight: NSLayoutConstraint?
    private var suggestionHeight: NSLayoutConstraint?

    // MARK: State

    private let settings = Settings.shared
    private var language: Language = .english
    private var page: KeyboardPage = .letters
    private var shift: ShiftState = .off
    private var returnTitle = "return"

    private var stores: [Language: WordStore] = [:]
    private let decoder = SwipeDecoder()

    private var lastSpaceTime = Date.distantPast
    private var lastShiftTap = Date.distantPast
    private var lastSwipeInserted: String?
    private var swipeAlternatives: [String] = []
    private var refreshScheduled = false

    // MARK: Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.clear

        language = Language(rawValue: settings.languageCode) ?? .english

        suggestionBar.delegate = self
        keyboardView.delegate = self
        keyboardView.popupHost = view

        suggestionBar.translatesAutoresizingMaskIntoConstraints = false
        keyboardView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(suggestionBar)
        view.addSubview(keyboardView)

        let suggestionHeightConstraint = suggestionBar.heightAnchor.constraint(equalToConstant: 44)
        suggestionHeight = suggestionHeightConstraint
        NSLayoutConstraint.activate([
            suggestionBar.topAnchor.constraint(equalTo: view.topAnchor),
            suggestionBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            suggestionHeightConstraint,

            keyboardView.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        updateReturnTitle()
        reloadKeyboardLayout()
        loadStore(for: language)
        EmojiStore.shared.loadIfNeeded()
        Haptics.shared.prepare()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Haptics.shared.prepare()
        applyHeight()
        updateAutoShift()
        scheduleRefresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyHeight()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Keep only the active dictionary in memory.
        stores = stores.filter { $0.key == language }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        updateReturnTitle()
        updateAutoShift()
        scheduleRefresh()
    }

    private func applyHeight() {
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let isLandscape = !isPad && view.bounds.width > 500
        let total: CGFloat = isPad ? 340 : (isLandscape ? 204 : 268)
        let suggestions: CGFloat = isLandscape ? 36 : 44

        if let constraint = totalHeight {
            if constraint.constant != total { constraint.constant = total }
        } else {
            let constraint = view.heightAnchor.constraint(equalToConstant: total)
            constraint.priority = UILayoutPriority(999)
            constraint.isActive = true
            totalHeight = constraint
        }
        if let constraint = suggestionHeight, constraint.constant != suggestions {
            constraint.constant = suggestions
        }
    }

    // MARK: Layout & language

    private func reloadKeyboardLayout() {
        let rows = LayoutBuilder.rows(language: language, page: page, returnTitle: returnTitle)
        keyboardView.configure(rows: rows, page: page, shift: shift)
    }

    private func loadStore(for target: Language) {
        if stores[target] != nil { return }
        let store = WordStore(language: target)
        stores[target] = store
        DispatchQueue.global(qos: .userInitiated).async {
            let parsed = WordStore.parse(language: target)
            DispatchQueue.main.async { [weak self] in
                store.apply(parsed)
                self?.scheduleRefresh()
            }
        }
    }

    private func switchLanguage() {
        language = language.next
        settings.languageCode = language.rawValue
        page = .letters
        clearSwipeState()
        loadStore(for: language)
        updateReturnTitle()
        reloadKeyboardLayout()
        scheduleRefresh()
    }

    private func updateReturnTitle() {
        let type = textDocumentProxy.returnKeyType ?? .default
        let hungarian = (language == .hungarian)
        let title: String
        switch type {
        case .go: title = hungarian ? "Mehet" : "Go"
        case .search: title = hungarian ? "Keresés" : "Search"
        case .send: title = hungarian ? "Küldés" : "Send"
        case .done: title = hungarian ? "Kész" : "Done"
        case .next: title = hungarian ? "Tovább" : "Next"
        default: title = hungarian ? "Enter" : "return"
        }
        if title != returnTitle {
            returnTitle = title
            keyboardView.setReturnTitle(title)
        }
    }

    // MARK: Shift / auto-capitalisation

    private func handleShift() {
        let now = Date()
        switch shift {
        case .off:
            shift = .once
        case .once:
            shift = now.timeIntervalSince(lastShiftTap) < 0.4 ? .locked : .off
        case .locked:
            shift = .off
        }
        lastShiftTap = now
        keyboardView.setShift(shift)
    }

    private func updateAutoShift() {
        guard page == .letters, shift != .locked else { return }   // caps lock is the user's choice
        let newState: ShiftState = shouldAutoCapitalize() ? .once : .off
        if newState != shift {
            shift = newState
            keyboardView.setShift(shift)
        }
    }

    private func shouldAutoCapitalize() -> Bool {
        guard settings.autoCapitalize else { return false }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let type = textDocumentProxy.autocapitalizationType ?? .sentences

        switch type {
        case .none:
            return false
        case .allCharacters:
            return true
        case .words:
            return before.isEmpty || before.hasSuffix(" ") || before.hasSuffix("\n")
        case .sentences:
            if before.isEmpty { return true }
            var trimmed = Substring(before)
            var hadSpace = false
            while let last = trimmed.last, last == " " {
                trimmed = trimmed.dropLast()
                hadSpace = true
            }
            guard let last = trimmed.last else { return true }
            if last == "\n" { return true }
            return hadSpace && (last == "." || last == "!" || last == "?")
        @unknown default:
            return false
        }
    }

    private func afterTyping() {
        if shift == .once {
            shift = .off
            keyboardView.setShift(shift)
        }
        scheduleRefresh()
    }

    // MARK: Typing

    private func insert(_ text: String) {
        clearSwipeState()
        var output = text
        if page == .letters && text.count == 1 && text.first?.isLetter == true {
            switch shift {
            case .off: break
            case .once, .locked: output = text.uppercased()
            }
        }
        textDocumentProxy.insertText(output)
        lastSpaceTime = Date.distantPast
        afterTyping()
    }

    private func handleSpace() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""

        // Double space -> ". "
        if Date().timeIntervalSince(lastSpaceTime) < 0.4, before.hasSuffix(" "), before.count >= 2 {
            let characters = Array(before)
            let previous = characters[characters.count - 2]
            if previous.isLetter || previous.isNumber {
                clearSwipeState()
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(". ")
                lastSpaceTime = Date.distantPast
                afterTyping()
                return
            }
        }

        learnWord(endingAt: before)
        clearSwipeState()
        textDocumentProxy.insertText(" ")
        lastSpaceTime = Date()
        afterTyping()
    }

    private func handleEnter() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        learnWord(endingAt: before)
        clearSwipeState()
        textDocumentProxy.insertText("\n")
        lastSpaceTime = Date.distantPast
        afterTyping()
    }

    private func handleBackspace() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        if let inserted = lastSwipeInserted, before.hasSuffix(inserted) {
            // Right after a swipe, backspace removes the whole swiped word.
            for _ in 0..<inserted.count { textDocumentProxy.deleteBackward() }
            clearSwipeState()
        } else {
            clearSwipeState()
            textDocumentProxy.deleteBackward()
        }
        lastSpaceTime = Date.distantPast
        updateAutoShift()
        scheduleRefresh()
    }

    private func learnWord(endingAt before: String) {
        guard settings.suggestionsEnabled, textDocumentProxy.isSecureTextEntry != true else { return }
        let prefix = currentPrefix(in: before)
        if prefix.count >= 3 {
            stores[language]?.learn(prefix)
        }
    }

    // MARK: Words

    /// The letters (and apostrophes) directly before the cursor.
    private func currentPrefix(in text: String) -> String {
        var collected: [Character] = []
        for character in text.reversed() {
            if character.isLetter || character == "'" || character == "\u{2019}" {
                collected.append(character)
            } else {
                break
            }
        }
        var result = String(collected.reversed())
        while let first = result.first, first == "'" || first == "\u{2019}" {
            result.removeFirst()
        }
        return result
    }

    private func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).uppercased() + text.dropFirst()
    }

    /// Makes a dictionary word match the capitalisation the user is typing with.
    private func matchCase(of typed: String, for word: String) -> String {
        if typed.count > 1 && typed == typed.uppercased() && typed != typed.lowercased() {
            return word.uppercased()
        }
        if let first = typed.first, first.isUppercase {
            return capitalizedFirst(word)
        }
        if language == .english && (word == "i" || word.hasPrefix("i'")) {
            return capitalizedFirst(word)
        }
        return word
    }

    private func applyShift(to word: String) -> String {
        switch shift {
        case .locked: return word.uppercased()
        case .once: return capitalizedFirst(word)
        case .off:
            if language == .english && (word == "i" || word.hasPrefix("i'")) { return capitalizedFirst(word) }
            return word
        }
    }

    // MARK: Suggestions

    private func scheduleRefresh() {
        if refreshScheduled { return }
        refreshScheduled = true
        // The text proxy updates a moment after insertText, so read it on the next run-loop turn.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.refreshScheduled = false
            self.updateAutoShift()
            self.refreshSuggestions()
        }
    }

    private func clearSwipeState() {
        lastSwipeInserted = nil
        swipeAlternatives = []
    }

    private func refreshSuggestions() {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""

        if textDocumentProxy.isSecureTextEntry == true
            || (!settings.suggestionsEnabled && !settings.emojiSuggestionsEnabled) {
            suggestionBar.update([])
            return
        }

        // Right after a swipe the bar offers other readings of the swiped word. Every typing action
        // clears this state, and replacing a word re-checks the text before touching it.
        if lastSwipeInserted != nil && swipeAlternatives.count > 1 {
            suggestionBar.update(swipeAlternatives.map { Suggestion(text: $0, kind: .swipeAlternative) })
            return
        }

        let prefix = currentPrefix(in: before)
        var emojiWord = prefix
        if prefix.isEmpty, before.hasSuffix(" ") {
            emojiWord = currentPrefix(in: String(before.dropLast()))   // word that was just finished
        }

        var emojis: [String] = []
        if settings.emojiSuggestionsEnabled && !emojiWord.isEmpty && EmojiStore.shared.isReady {
            emojis = EmojiStore.shared.suggestions(for: emojiWord, language: language, limit: 2)
        }

        var words: [String] = []
        if settings.suggestionsEnabled && !prefix.isEmpty, let store = stores[language], store.isLoaded {
            words = store.completions(for: prefix, limit: 4).map { matchCase(of: prefix, for: $0) }
        }

        var result: [Suggestion] = []
        let wordSlots = emojis.isEmpty ? 4 : 4 - emojis.count
        if !prefix.isEmpty {
            // Slot 1 is always exactly what was typed, so it can never be auto-"corrected" away.
            result.append(Suggestion(text: prefix, kind: .literal))
            for word in words where word != prefix && result.count < wordSlots {
                result.append(Suggestion(text: word, kind: .word))
            }
        }
        for emoji in emojis {
            result.append(Suggestion(text: emoji, kind: .emoji))
        }
        suggestionBar.update(result)
    }

    private func replacePrefix(with replacement: String) {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let prefix = currentPrefix(in: before)
        for _ in 0..<prefix.count { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(replacement + " ")
        lastSpaceTime = Date()
    }

    // MARK: Swipe typing

    private func commitSwipe(_ words: [String]) {
        guard let first = words.first else { return }
        let word = applyShift(to: first)
        let before = textDocumentProxy.documentContextBeforeInput ?? ""

        var leadingSpace = ""
        if let last = before.last, !last.isWhitespace, !"([{\"\u{201C}\u{2018}'".contains(last) {
            leadingSpace = " "
        }
        let inserted = word + " "
        textDocumentProxy.insertText(leadingSpace + inserted)

        lastSwipeInserted = inserted
        swipeAlternatives = words.map { applyShift(to: $0) }
        lastSpaceTime = Date.distantPast
        if shift == .once {
            shift = .off
            keyboardView.setShift(shift)
        }
        scheduleRefresh()
    }

    private func replaceSwipedWord(with replacement: String) {
        guard let inserted = lastSwipeInserted else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        guard before.hasSuffix(inserted) else { clearSwipeState(); return }
        for _ in 0..<inserted.count { textDocumentProxy.deleteBackward() }
        let newText = replacement + " "
        textDocumentProxy.insertText(newText)
        lastSwipeInserted = newText
    }

    // MARK: Panels

    private func showEmojiPanel() {
        guard emojiPanel == nil else { return }
        let panel = EmojiPanel()
        panel.delegate = self
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        emojiPanel = panel
        panel.reload()
        EmojiStore.shared.loadIfNeeded { [weak panel] in
            panel?.reload()
        }
    }

    private func hideEmojiPanel() {
        emojiPanel?.removeFromSuperview()
        emojiPanel = nil
        scheduleRefresh()
    }

    private func showSettingsPanel() {
        guard settingsPanel == nil else { return }
        let panel = SettingsPanel(hasFullAccess: hasFullAccess)
        panel.delegate = self
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: view.topAnchor),
            panel.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        settingsPanel = panel
    }

    private func hideSettingsPanel() {
        settingsPanel?.removeFromSuperview()
        settingsPanel = nil
        scheduleRefresh()
    }
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardView(_ view: KeyboardView, didTap action: KeyAction) {
        switch action {
        case .character(let text): insert(text)
        case .space: handleSpace()
        case .enter: handleEnter()
        case .backspace: handleBackspace()
        case .shift: handleShift()
        case .showLetters:
            page = .letters
            reloadKeyboardLayout()
            updateAutoShift()
        case .showNumbers:
            page = .numbers
            reloadKeyboardLayout()
        case .showSymbols:
            page = .symbols
            reloadKeyboardLayout()
        case .nextLanguage: switchLanguage()
        case .emoji: showEmojiPanel()
        case .spacer: break
        }
    }

    func keyboardView(_ view: KeyboardView, didSelectAlternate text: String) {
        insert(text)
    }

    func keyboardViewDidHoldGlobe(_ view: KeyboardView) {
        advanceToNextInputMode()   // hand over to the next installed keyboard
    }

    func keyboardView(_ view: KeyboardView, didFinishSwipe path: [CGPoint]) {
        guard let store = stores[language], store.isLoaded else { return }
        let centers = keyboardView.letterCenters()
        let keySize = keyboardView.letterKeySize()
        let decoder = self.decoder

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let words = decoder.decode(path: path, keyCenters: centers, keySize: keySize, store: store)
            DispatchQueue.main.async {
                self?.commitSwipe(words)
            }
        }
    }
}

// MARK: - SuggestionBarDelegate

extension KeyboardViewController: SuggestionBarDelegate {
    func suggestionBar(_ bar: SuggestionBar, didSelect suggestion: Suggestion) {
        Haptics.shared.keyPress()
        switch suggestion.kind {
        case .literal, .word:
            replacePrefix(with: suggestion.text)
            clearSwipeState()
            afterTyping()
        case .swipeAlternative:
            replaceSwipedWord(with: suggestion.text)
            scheduleRefresh()
        case .emoji:
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            let needsSpace = (before.last?.isWhitespace == false)
            textDocumentProxy.insertText((needsSpace ? " " : "") + suggestion.text + " ")
            lastSpaceTime = Date.distantPast
            clearSwipeState()
            afterTyping()
        }
    }

    func suggestionBarDidTapSettings(_ bar: SuggestionBar) {
        Haptics.shared.keyPress()
        showSettingsPanel()
    }
}

// MARK: - EmojiPanelDelegate

extension KeyboardViewController: EmojiPanelDelegate {
    func emojiPanel(_ panel: EmojiPanel, didSelect emoji: String) {
        textDocumentProxy.insertText(emoji)
        var recents = settings.recentEmoji.filter { $0 != emoji }
        recents.insert(emoji, at: 0)
        settings.recentEmoji = Array(recents.prefix(32))
        lastSpaceTime = Date.distantPast
        clearSwipeState()
    }

    func emojiPanelDidTapBackspace(_ panel: EmojiPanel) {
        textDocumentProxy.deleteBackward()
    }

    func emojiPanelDidClose(_ panel: EmojiPanel) {
        hideEmojiPanel()
    }
}

// MARK: - SettingsPanelDelegate

extension KeyboardViewController: SettingsPanelDelegate {
    func settingsPanelDidClose(_ panel: SettingsPanel) {
        hideSettingsPanel()
    }

    func settingsPanelDidChange(_ panel: SettingsPanel) {
        updateAutoShift()
    }

    func settingsPanelDidRequestForgetWords(_ panel: SettingsPanel) {
        settings.clearLearnedWords()
        for store in stores.values { store.forgetLearnedWords() }
    }
}

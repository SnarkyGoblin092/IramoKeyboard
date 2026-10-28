import UIKit

/// Glue between the system text field (`textDocumentProxy`) and all keyboard components.
final class KeyboardViewController: UIInputViewController {

    // MARK: UI

    private let container = UIView()
    private var stage = UIView()
    private var suggestionBar = SuggestionBar()
    private var searchBar = EmojiSearchBar()
    private var keyboardView = KeyboardView()
    private var expandButton: UIButton?
    private var emojiPanel: EmojiPanel?
    private var settingsPanel: SettingsPanel?
    private var languagePicker: LanguagePicker?

    private var totalHeight: NSLayoutConstraint?
    private var suggestionHeight: NSLayoutConstraint?
    private var stageLeading: NSLayoutConstraint?
    private var stageTrailing: NSLayoutConstraint?

    // MARK: State

    private let settings = Settings.shared
    private var language: Language = .english
    private var page: KeyboardPage = .letters
    private var shift: ShiftState = .off
    private var returnTitle = "return"
    private var builtSignature = ""

    private var stores: [Language: WordStore] = [:]
    private let decoder = SwipeDecoder()

    private var lastSpaceTime = Date.distantPast
    private var lastShiftTap = Date.distantPast
    private var lastSwipeInserted: String?
    private var swipeAlternatives: [String] = []
    private var refreshScheduled = false

    // Emoji search (typing on the normal keys while the picker's search field is "active")
    private var isSearchingEmoji = false
    private var searchQuery = ""

    // MARK: Lifecycle

    /// The root view is a keyboard-style input view, so the system draws its native keyboard backdrop.
    override func loadView() {
        let inputView = UIInputView(frame: CGRect(x: 0, y: 0, width: 320, height: 260), inputViewStyle: .keyboard)
        inputView.allowsSelfSizing = true
        view = inputView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Everything we draw lives in `container`, so the system's own backdrop views stay untouched.
        container.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        language = Language(rawValue: settings.languageCode) ?? .english

        buildInterface()
        loadStore(for: language)
        EmojiStore.shared.loadIfNeeded()
        Haptics.shared.prepare()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Haptics.shared.prepare()
        settings.markKeyboardSeen(hasFullAccess: hasFullAccess)

        // Settings changed in the app while the keyboard was away: rebuild the look.
        if settingsSignature() != builtSignature {
            buildInterface()
        }
        applyHeight()
        updateAutoShift()
        scheduleRefresh()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyHeight()
        applyOneHandedInsets()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        stores = stores.filter { $0.key == language }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        updateReturnTitle()
        if !isSearchingEmoji { updateAutoShift() }
        scheduleRefresh()
    }

    // MARK: Building the interface

    private func settingsSignature() -> String {
        let s = settings
        return [
            "\(s.numberRow)", "\(s.keyHints)", s.theme, s.accentName,
            s.oneHanded, "\(s.keyboardHeightScale)", "\(s.keyPopups)", s.enabledLanguages.joined(separator: ",")
        ].joined(separator: "|")
    }

    /// (Re)creates every view. Called at start and whenever a look-changing setting was edited.
    private func buildInterface() {
        validateLanguage()
        hideEmojiPanel(refresh: false)
        hideSettingsPanel(refresh: false)
        hideLanguagePicker(refresh: false)
        isSearchingEmoji = false
        searchQuery = ""
        for sub in container.subviews { sub.removeFromSuperview() }
        totalHeight = nil
        suggestionHeight = nil

        stage = UIView()
        suggestionBar = SuggestionBar()
        searchBar = EmojiSearchBar()
        keyboardView = KeyboardView()

        suggestionBar.delegate = self
        searchBar.delegate = self
        keyboardView.delegate = self
        keyboardView.popupHost = container
        searchBar.isHidden = true

        for item in [stage, suggestionBar, searchBar, keyboardView] as [UIView] {
            item.translatesAutoresizingMaskIntoConstraints = false
        }
        container.addSubview(stage)
        stage.addSubview(suggestionBar)
        stage.addSubview(searchBar)
        stage.addSubview(keyboardView)

        let leading = stage.leadingAnchor.constraint(equalTo: container.leadingAnchor)
        let trailing = stage.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        stageLeading = leading
        stageTrailing = trailing
        let barHeight = suggestionBar.heightAnchor.constraint(equalToConstant: 44)
        suggestionHeight = barHeight

        NSLayoutConstraint.activate([
            stage.topAnchor.constraint(equalTo: container.topAnchor),
            stage.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leading, trailing,

            suggestionBar.topAnchor.constraint(equalTo: stage.topAnchor),
            suggestionBar.leadingAnchor.constraint(equalTo: stage.leadingAnchor),
            suggestionBar.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
            barHeight,

            searchBar.topAnchor.constraint(equalTo: suggestionBar.topAnchor),
            searchBar.leadingAnchor.constraint(equalTo: suggestionBar.leadingAnchor),
            searchBar.trailingAnchor.constraint(equalTo: suggestionBar.trailingAnchor),
            searchBar.bottomAnchor.constraint(equalTo: suggestionBar.bottomAnchor),

            keyboardView.topAnchor.constraint(equalTo: suggestionBar.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: stage.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: stage.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: stage.bottomAnchor)
        ])

        // One-handed mode: a button in the free strip brings the full width back.
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "arrow.left.and.right",
                                withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)),
                        for: .normal)
        button.tintColor = Theme.accent
        button.addAction(UIAction { [weak self] _ in
            Haptics.shared.keyPress()
            self?.settings.oneHanded = "off"
            self?.buildInterface()
            self?.applyHeight()
        }, for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(button)
        NSLayoutConstraint.activate([
            button.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 44),
            button.centerXAnchor.constraint(equalTo: container.leadingAnchor, constant: 0)   // positioned in applyOneHandedInsets
        ])
        expandButton = button

        configureTools()
        if !hasFullAccess {
            suggestionBar.emptyHint = "Allow Full Access for vibration, paste and saving"
        } else {
            suggestionBar.emptyHint = nil
        }
        updateReturnTitle()
        reloadKeyboardLayout()
        builtSignature = settingsSignature()
        applyHeight()
        applyOneHandedInsets()
    }

    private func configureTools() {
        var items: [ToolItem] = []
        if enabledLanguages.count > 1 {
            items.append(ToolItem(id: .language, symbol: "globe", label: language.shortCode))
        }
        items.append(ToolItem(id: .paste, symbol: "doc.on.clipboard"))
        items.append(ToolItem(id: .oneHanded, symbol: "hand.point.right", isActive: settings.oneHanded != "off"))
        items.append(ToolItem(id: .numberRow, symbol: "textformat.123", isActive: settings.numberRow))
        items.append(ToolItem(id: .dismiss, symbol: "keyboard.chevron.compact.down"))
        suggestionBar.setTools(items)
    }

    private func applyHeight() {
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let isLandscape = !isPad && view.bounds.width > 500
        var total: CGFloat = isPad ? 340 : (isLandscape ? 208 : 276)
        if settings.numberRow { total += isLandscape ? 26 : 40 }
        total *= CGFloat(settings.keyboardHeightScale)
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

    private func applyOneHandedInsets() {
        let mode = settings.oneHanded
        let strip = view.bounds.width * 0.2
        switch mode {
        case "right":      // keys hug the right edge, free strip on the left
            stageLeading?.constant = strip
            stageTrailing?.constant = 0
            expandButton?.isHidden = false
            moveExpandButton(centerX: strip / 2)
        case "left":
            stageLeading?.constant = 0
            stageTrailing?.constant = -strip
            expandButton?.isHidden = false
            moveExpandButton(centerX: view.bounds.width - strip / 2)
        default:
            stageLeading?.constant = 0
            stageTrailing?.constant = 0
            expandButton?.isHidden = true
        }
    }

    private func moveExpandButton(centerX: CGFloat) {
        guard let button = expandButton else { return }
        for constraint in container.constraints where constraint.firstItem === button && constraint.firstAttribute == .centerX {
            constraint.constant = centerX
        }
    }

    // MARK: Layout & language

    private func reloadKeyboardLayout() {
        let rows = LayoutBuilder.rows(language: language,
                                      page: page,
                                      returnTitle: returnTitle,
                                      numberRow: settings.numberRow,
                                      showHints: settings.keyHints)
        keyboardView.typingLanguage = language
        keyboardView.configure(rows: rows, page: page, shift: shift)
        updateReturnProminence()
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

    /// The languages the user switched on in the app (always at least one).
    private var enabledLanguages: [Language] {
        return Language.list(from: settings.enabledLanguages, fallback: language)
    }

    /// Makes sure the active language is one of the enabled ones.
    private func validateLanguage() {
        let enabled = enabledLanguages
        if !enabled.contains(language), let first = enabled.first {
            language = first
            settings.languageCode = first.rawValue
            loadStore(for: first)
        }
    }

    private func switchLanguage() {
        let enabled = enabledLanguages
        guard enabled.count > 1 else { return }
        let index = enabled.firstIndex(of: language) ?? -1
        selectLanguage(enabled[(index + 1) % enabled.count])
    }

    private func selectLanguage(_ target: Language) {
        guard target != language else { return }
        language = target
        settings.languageCode = target.rawValue
        page = .letters
        clearSwipeState()
        loadStore(for: target)
        // Words of the other languages are not needed any more.
        stores = stores.filter { $0.key == target }
        configureTools()
        returnTitle = ""
        updateReturnTitle()
        reloadKeyboardLayout()
        scheduleRefresh()
    }

    private func updateReturnTitle() {
        let type = textDocumentProxy.returnKeyType ?? .default
        let texts = language.strings
        let title: String
        switch type {
        case .go: title = texts.go
        case .search: title = texts.search
        case .send: title = texts.send
        case .done: title = texts.done
        case .next: title = texts.next
        default: title = texts.returnKey
        }
        if title != returnTitle {
            returnTitle = title
            keyboardView.setReturnTitle(title)
        }
        updateReturnProminence()
    }

    private func updateReturnProminence() {
        let type = textDocumentProxy.returnKeyType ?? .default
        let prominent: Bool
        switch type {
        case .go, .search, .send, .done: prominent = true
        default: prominent = false
        }
        keyboardView.setReturnProminent(prominent)
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
        guard page == .letters, shift != .locked, !isSearchingEmoji else { return }
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
            case .once, .locked: output = language.uppercase(text)
            }
        }
        if isSearchingEmoji {
            searchQuery += output
            if shift == .once {
                shift = .off
                keyboardView.setShift(shift)
            }
            refreshEmojiSearch()
            return
        }
        textDocumentProxy.insertText(output)
        lastSpaceTime = Date.distantPast
        afterTyping()
    }

    private func handleSpace() {
        if isSearchingEmoji {
            if !searchQuery.isEmpty && !searchQuery.hasSuffix(" ") { searchQuery += " " }
            refreshEmojiSearch()
            return
        }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""

        // Double space -> ". "
        if settings.doubleSpacePeriod,
           Date().timeIntervalSince(lastSpaceTime) < 0.4, before.hasSuffix(" "), before.count >= 2 {
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

        // A text shortcut ("omw" -> "On my way!") expands when space is pressed.
        if let phrase = shortcutExpansion(in: before) {
            replacePrefix(with: phrase)
            clearSwipeState()
            afterTyping()
            return
        }

        learnWord(endingAt: before)
        clearSwipeState()
        textDocumentProxy.insertText(" ")
        lastSpaceTime = Date()
        afterTyping()
    }

    private func handleEnter() {
        if isSearchingEmoji {
            // Enter picks the first match, like pressing search in the system keyboard.
            if let first = EmojiStore.shared.search(searchQuery, limit: 1).first {
                pickEmoji(first)
            }
            return
        }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        if let phrase = shortcutExpansion(in: before) {
            let prefix = currentPrefix(in: before)
            for _ in 0..<prefix.count { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(phrase)
        } else {
            learnWord(endingAt: before)
        }
        clearSwipeState()
        textDocumentProxy.insertText("\n")
        lastSpaceTime = Date.distantPast
        afterTyping()
    }

    private func handleBackspace() {
        if isSearchingEmoji {
            if !searchQuery.isEmpty { searchQuery.removeLast() }
            refreshEmojiSearch()
            return
        }
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

    /// Deletes one word to the left (sliding left from the backspace key).
    private func deleteWordBackward() {
        if isSearchingEmoji {
            var characters = Array(searchQuery)
            while let last = characters.last, last == " " { characters.removeLast() }
            while let last = characters.last, last != " " { characters.removeLast() }
            searchQuery = String(characters)
            refreshEmojiSearch()
            return
        }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        guard !before.isEmpty else { return }
        var count = 0
        var characters = Array(before)
        while let last = characters.last, last.isWhitespace {
            characters.removeLast()
            count += 1
        }
        if let last = characters.last {
            if isWordCharacter(last) {
                while let current = characters.last, isWordCharacter(current) {
                    characters.removeLast()
                    count += 1
                }
            } else {
                characters.removeLast()
                count += 1
            }
        }
        for _ in 0..<max(1, count) { textDocumentProxy.deleteBackward() }
        clearSwipeState()
        lastSpaceTime = Date.distantPast
        updateAutoShift()
        scheduleRefresh()
    }

    private func isWordCharacter(_ character: Character) -> Bool {
        return character.isLetter || character.isNumber || character == "'" || character == "\u{2019}"
    }

    private func learnWord(endingAt before: String) {
        guard settings.suggestionsEnabled, textDocumentProxy.isSecureTextEntry != true else { return }
        let prefix = currentPrefix(in: before)
        if prefix.count >= 3 {
            stores[language]?.learn(prefix)
        }
    }

    private func shortcutExpansion(in before: String) -> String? {
        let prefix = currentPrefix(in: before)
        guard !prefix.isEmpty else { return nil }
        return settings.shortcutPhrase(for: prefix)
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
        return language.uppercase(String(first)) + text.dropFirst()
    }

    /// Makes a dictionary word match the capitalisation the user is typing with.
    private func matchCase(of typed: String, for word: String) -> String {
        if typed.count > 1 && typed == typed.uppercased() && typed != typed.lowercased() {
            return language.uppercase(word)
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
        case .locked: return language.uppercase(word)
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
        if isSearchingEmoji { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""

        if textDocumentProxy.isSecureTextEntry == true
            || (!settings.suggestionsEnabled && !settings.emojiSuggestionsEnabled) {
            suggestionBar.update([])
            return
        }

        // Right after a swipe the bar offers other readings of the swiped word.
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
            emojis = EmojiStore.shared.suggestions(for: emojiWord, language: language, limit: 1)
        }

        var words: [String] = []
        if settings.suggestionsEnabled && !prefix.isEmpty, let store = stores[language], store.isLoaded {
            words = store.completions(for: prefix, limit: 4).map { matchCase(of: prefix, for: $0) }
        }

        var result: [Suggestion] = []
        let wordSlots = 3 - emojis.count
        if !prefix.isEmpty {
            // Slot 1 is always exactly what was typed, so it can never be auto-"corrected" away.
            result.append(Suggestion(text: prefix, kind: .literal))
            if let phrase = settings.shortcutPhrase(for: prefix) {
                result.append(Suggestion(text: phrase, kind: .word))
            }
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

        if isSearchingEmoji {
            if !searchQuery.isEmpty && !searchQuery.hasSuffix(" ") { searchQuery += " " }
            searchQuery += first
            refreshEmojiSearch()
            return
        }

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

    // MARK: Emoji

    private func pickEmoji(_ emoji: String) {
        textDocumentProxy.insertText(emoji)
        var recents = settings.recentEmoji.filter { $0 != emoji }
        recents.insert(emoji, at: 0)
        settings.recentEmoji = Array(recents.prefix(48))
        lastSpaceTime = Date.distantPast
        clearSwipeState()
    }

    private func showEmojiPanel() {
        guard emojiPanel == nil else { return }
        let panel = EmojiPanel()
        panel.delegate = self
        panel.language = language
        panel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: container.topAnchor),
            panel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        emojiPanel = panel
        // The picker replaces the keyboard completely: nothing may show through from behind it.
        stage.isHidden = true
        expandButton?.isHidden = true
        panel.reload()
        EmojiStore.shared.loadIfNeeded { [weak panel] in
            panel?.reload()
        }
    }

    private func hideEmojiPanel(refresh: Bool = true) {
        emojiPanel?.removeFromSuperview()
        emojiPanel = nil
        stage.isHidden = false
        applyOneHandedInsets()
        if refresh { scheduleRefresh() }
    }

    private func beginEmojiSearch() {
        hideEmojiPanel(refresh: false)
        isSearchingEmoji = true
        searchQuery = ""
        page = .letters
        shift = .off
        reloadKeyboardLayout()
        suggestionBar.isHidden = true
        searchBar.isHidden = false
        refreshEmojiSearch()
        EmojiStore.shared.loadSearchIfNeeded(languages: [language, .english]) { [weak self] in
            self?.refreshEmojiSearch()
        }
    }

    private func endEmojiSearch(returnToPicker: Bool) {
        isSearchingEmoji = false
        searchQuery = ""
        searchBar.isHidden = true
        suggestionBar.isHidden = false
        updateAutoShift()
        if returnToPicker {
            showEmojiPanel()
        } else {
            scheduleRefresh()
        }
    }

    private func refreshEmojiSearch() {
        let placeholder = language.strings.searchEmoji
        searchBar.setQuery(searchQuery, placeholder: placeholder)
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            searchBar.setResults(settings.recentEmoji)
        } else {
            searchBar.setResults(EmojiStore.shared.search(searchQuery, limit: 60))
        }
    }

    // MARK: Panels

    private func showSettingsPanel() {
        guard settingsPanel == nil else { return }
        let panel = SettingsPanel(hasFullAccess: hasFullAccess)
        panel.delegate = self
        panel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: container.topAnchor),
            panel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        settingsPanel = panel
        stage.isHidden = true
        expandButton?.isHidden = true
    }

    private func hideSettingsPanel(refresh: Bool = true) {
        settingsPanel?.removeFromSuperview()
        settingsPanel = nil
        stage.isHidden = false
        applyOneHandedInsets()
        if refresh { scheduleRefresh() }
    }

    // MARK: Language picker

    private func showLanguagePicker() {
        guard languagePicker == nil else { return }
        let picker = LanguagePicker(languages: enabledLanguages, current: language)
        picker.delegate = self
        picker.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(picker)
        NSLayoutConstraint.activate([
            picker.topAnchor.constraint(equalTo: container.topAnchor),
            picker.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            picker.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            picker.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        languagePicker = picker
        stage.isHidden = true
        expandButton?.isHidden = true
    }

    private func hideLanguagePicker(refresh: Bool = true) {
        languagePicker?.removeFromSuperview()
        languagePicker = nil
        stage.isHidden = false
        applyOneHandedInsets()
        if refresh { scheduleRefresh() }
    }

    // MARK: Tools

    private func cycleOneHanded() {
        let next: String
        switch settings.oneHanded {
        case "off": next = "right"
        case "right": next = "left"
        default: next = "off"
        }
        settings.oneHanded = next
        suggestionBar.setToolActive(.oneHanded, active: next != "off")
        builtSignature = settingsSignature()
        applyOneHandedInsets()
        view.setNeedsLayout()
    }

    private func toggleNumberRow() {
        settings.numberRow.toggle()
        buildInterface()
    }

    private func pasteFromClipboard() {
        guard hasFullAccess else {
            suggestionBar.flash("Turn on Allow Full Access to paste")
            return
        }
        guard let text = UIPasteboard.general.string, !text.isEmpty else {
            suggestionBar.flash("Clipboard is empty")
            return
        }
        if isSearchingEmoji {
            searchQuery += text
            refreshEmojiSearch()
            return
        }
        clearSwipeState()
        textDocumentProxy.insertText(text)
        lastSpaceTime = Date.distantPast
        afterTyping()
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
        case .emoji:
            if isSearchingEmoji { endEmojiSearch(returnToPicker: true) } else { showEmojiPanel() }
        case .spacer: break
        }
    }

    func keyboardView(_ view: KeyboardView, didSelectAlternate text: String) {
        insert(text)
    }

    func keyboardView(_ view: KeyboardView, didMoveCursorBy offset: Int) {
        guard offset != 0, !isSearchingEmoji else { return }
        textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        Haptics.shared.tick()
        clearSwipeState()
        lastSpaceTime = Date.distantPast
        scheduleRefresh()
    }

    func keyboardViewDidRequestDeleteWord(_ view: KeyboardView) {
        Haptics.shared.tick()
        deleteWordBackward()
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
            var recents = settings.recentEmoji.filter { $0 != suggestion.text }
            recents.insert(suggestion.text, at: 0)
            settings.recentEmoji = Array(recents.prefix(48))
            lastSpaceTime = Date.distantPast
            clearSwipeState()
            afterTyping()
        }
    }

    func suggestionBar(_ bar: SuggestionBar, didTapTool tool: ToolID) {
        Haptics.shared.keyPress()
        switch tool {
        case .paste: pasteFromClipboard()
        case .oneHanded: cycleOneHanded()
        case .numberRow: toggleNumberRow()
        case .dismiss: dismissKeyboard()
        case .settings: showSettingsPanel()
        case .language: showLanguagePicker()
        }
    }
}

// MARK: - EmojiPanelDelegate

extension KeyboardViewController: EmojiPanelDelegate {
    func emojiPanel(_ panel: EmojiPanel, didSelect emoji: String) {
        pickEmoji(emoji)
    }

    func emojiPanelDidTapBackspace(_ panel: EmojiPanel) {
        textDocumentProxy.deleteBackward()
    }

    func emojiPanelDidTapSearch(_ panel: EmojiPanel) {
        beginEmojiSearch()
    }

    func emojiPanelDidClose(_ panel: EmojiPanel) {
        hideEmojiPanel()
    }
}

// MARK: - EmojiSearchBarDelegate

extension KeyboardViewController: EmojiSearchBarDelegate {
    func emojiSearchBar(_ bar: EmojiSearchBar, didSelect emoji: String) {
        pickEmoji(emoji)
        refreshEmojiSearch()
    }

    func emojiSearchBarDidTapBack(_ bar: EmojiSearchBar) {
        endEmojiSearch(returnToPicker: true)
    }
}

// MARK: - SettingsPanelDelegate

extension KeyboardViewController: SettingsPanelDelegate {
    func settingsPanelDidClose(_ panel: SettingsPanel) {
        hideSettingsPanel()
        if settingsSignature() != builtSignature { buildInterface() }
    }
}

// MARK: - LanguagePickerDelegate

extension KeyboardViewController: LanguagePickerDelegate {
    func languagePicker(_ picker: LanguagePicker, didSelect language: Language) {
        hideLanguagePicker(refresh: false)
        selectLanguage(language)
    }

    func languagePickerDidClose(_ picker: LanguagePicker) {
        hideLanguagePicker()
    }
}

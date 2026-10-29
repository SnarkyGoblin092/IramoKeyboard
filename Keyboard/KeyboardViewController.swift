import UIKit

/// Glue between the system text field (`textDocumentProxy`) and all keyboard components.
final class KeyboardViewController: UIInputViewController {

    // MARK: UI

    private let container = UIView()
    private var stage = UIView()
    private var suggestionBar = SuggestionBar()
    private var searchBar = EmojiSearchBar()
    private var keyboardView = KeyboardView()
    private var emojiPanel: EmojiPanel?
    private var hiddenForEmoji: [UIView] = []

    private var totalHeight: NSLayoutConstraint?
    private var suggestionHeight: NSLayoutConstraint?

    // MARK: State

    private let settings = Settings.shared
    private var language: Language = .english
    private var page: KeyboardPage = .letters
    private var shift: ShiftState = .off
    private var returnTitle = "return"
    private var builtSignature = ""

    private var stores: [Language: WordStore] = [:]
    private var loadingStores: Set<String> = []
    private var secondaryStoresAllowed = true
    private let maxSecondaryStores = 3
    private let secondaryWordLimit = 12000
    private let decoder = SwipeDecoder()

    private var lastSpaceTime = Date.distantPast
    private var lastShiftTap = Date.distantPast
    private var lastSwipeInserted: String?
    private var swipeAlternatives: [String] = []
    private var refreshScheduled = false
    private var suggestionWork: DispatchWorkItem?

    // Emoji search (typing on the normal keys while the picker's search field is "active")
    private var isSearchingEmoji = false
    private var searchQuery = ""

    // MARK: Lifecycle

    /// True when the root view uses the system keyboard backdrop. The Liquid Glass theme asks for a plain
    /// (see-through) root instead, so the glass shows what is behind it rather than a flat material.
    private var rootIsKeyboardStyle = true

    /// The root view is an input view: keyboard style (the system's native backdrop) for most themes, default
    /// (no backdrop of its own) for Liquid Glass.
    override func loadView() {
        Theme.reload()
        rootIsKeyboardStyle = !Theme.isLiquidGlass
        let inputView = UIInputView(frame: CGRect(x: 0, y: 0, width: 320, height: 260),
                                    inputViewStyle: rootIsKeyboardStyle ? .keyboard : .default)
        inputView.allowsSelfSizing = true
        inputView.backgroundColor = UIColor.clear
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
        ensureStores()
        EmojiStore.shared.loadIfNeeded()
        Haptics.shared.prepare()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        Haptics.shared.prepare()
        settings.markKeyboardSeen(hasFullAccess: hasFullAccess)

        // Settings changed in the app while the keyboard was away: rebuild the look.
        Prefs.refresh()
        TouchModel.shared.reload()
        if settingsSignature() != builtSignature {
            buildInterface()
        }
        applyHeight()
        updateAutoShift()
        scheduleRefresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Touches near the screen edges and the bottom are normally held back for a moment by the system's
        // own gestures, which makes edge keys feel dead. Ask the window's recognisers not to delay touches.
        view.window?.gestureRecognizers?.forEach {
            $0.delaysTouchesBegan = false
            $0.delaysTouchesEnded = false
        }
    }

    /// Ask the system not to hold back touches at the screen edges for its own gestures (keeps edge keys instant).
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { return [.left, .right, .bottom] }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        applyHeight()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        for store in stores.values { store.saveNow() }
        keyboardView.saveTouchModel()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        secondaryStoresAllowed = false
        for (key, store) in stores where key != language { store.saveNow() }
        stores = stores.filter { $0.key == language }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        updateReturnTitle()
        scheduleRefresh()   // auto-shift and suggestions are refreshed off the typing path
    }

    // MARK: Building the interface

    private func settingsSignature() -> String {
        let s = settings
        return [
            "\(s.numberRow)", "\(s.keyHints)", Theme.storedID(), s.accentName,
            "\(s.keyboardHeightScale)", "\(s.keyPopups)", "\(Prefs.keyRoundness)", "\(s.keyBorders)", s.enabledLanguages.joined(separator: ","),
            SharedStore.defaults.string(forKey: SettingKey.accentHex) ?? "",
            SharedStore.defaults.string(forKey: ThemeCatalog.customThemeKey) ?? ""
        ].joined(separator: "|")
    }

    /// (Re)creates every view. Called at start and whenever a look-changing setting was edited.
    private func buildInterface() {
        Prefs.refresh()
        Theme.reload()
        view.overrideUserInterfaceStyle = Theme.interfaceStyle   // gradient themes force light/dark
        validateLanguage()
        hideEmojiPanel(refresh: false)
        isSearchingEmoji = false
        searchQuery = ""
        for sub in container.subviews { sub.removeFromSuperview() }

        // Gradient backdrop (gradient themes, and a soft wash behind Liquid Glass) covers the system backdrop.
        if Theme.drawsBackdrop {
            let backdrop = BackdropView(theme: Theme.definition, opacity: Theme.backdropOpacity)
            backdrop.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(backdrop)
            NSLayoutConstraint.activate([
                backdrop.topAnchor.constraint(equalTo: container.topAnchor),
                backdrop.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                backdrop.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                backdrop.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
        }
        else if !rootIsKeyboardStyle && !Theme.isLiquidGlass {
            // The root was created see-through (Liquid Glass was active at load time) but this theme wants a
            // normal keyboard background, so paint one.
            let solid = UIView()
            solid.isUserInteractionEnabled = false
            solid.backgroundColor = UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 0.1, alpha: 1) : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1) }
            solid.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(solid)
            NSLayoutConstraint.activate([
                solid.topAnchor.constraint(equalTo: container.topAnchor),
                solid.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                solid.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                solid.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
        }
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

        let barHeight = suggestionBar.heightAnchor.constraint(equalToConstant: 44)
        suggestionHeight = barHeight

        NSLayoutConstraint.activate([
            stage.topAnchor.constraint(equalTo: container.topAnchor),
            stage.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            stage.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stage.trailingAnchor.constraint(equalTo: container.trailingAnchor),

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

        if !hasFullAccess {
            suggestionBar.emptyHint = "Allow Full Access for vibration and saving settings"
        } else {
            suggestionBar.emptyHint = nil
        }
        updateReturnTitle()
        reloadKeyboardLayout()
        builtSignature = settingsSignature()
        applyHeight()
    }

    private func applyHeight() {
        let isPad = traitCollection.userInterfaceIdiom == .pad
        let isLandscape = !isPad && view.bounds.width > 500
        var total: CGFloat = isPad ? 340 : (isLandscape ? 208 : 276)
        if Prefs.numberRow { total += isLandscape ? 26 : 40 }
        total *= CGFloat(Prefs.heightScale)
        // The emoji picker always shows four full rows: the keyboard grows to fit while it is open.
        let panelScale = EmojiPanel.scale(forWidth: view.bounds.width > 100 ? view.bounds.width : UIScreen.main.bounds.width)
        if emojiPanel != nil || isSearchingEmoji {
            // The view may not have its final width yet when the picker opens, so fall back to the screen width.
            let width = view.bounds.width > 100 ? view.bounds.width : UIScreen.main.bounds.width
            total = max(total, EmojiPanel.requiredHeight(forWidth: width))
        }
        var suggestions: CGFloat = isLandscape ? 36 : 44
        if isSearchingEmoji {
            // Same height and top gap as the picker, so the search field stays exactly where it was.
            EmojiSearchBar.topInset = (5 * panelScale).rounded()
            suggestions = 44 * panelScale + EmojiSearchBar.topInset
        }

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
        var rows = LayoutBuilder.rows(language: language,
                                      page: page,
                                      returnTitle: returnTitle,
                                      numberRow: Prefs.numberRow,
                                      showHints: Prefs.keyHints)
        if isSearchingEmoji {
            // While searching for an emoji the emoji key has no use, so it is left out.
            rows = rows.map { row in row.filter { spec in
                if case .emoji = spec.action { return false }
                return true
            } }
        }
        keyboardView.typingLanguage = language
        keyboardView.configure(rows: rows, page: page, shift: shift)
        updateReturnProminence()
    }

    /// Loads a dictionary in the background. The active language is loaded in full (swipe index included);
    /// the other enabled languages only keep their most frequent words, to save memory.
    private func loadStore(for target: Language, full: Bool) {
        let tag = "\(target.rawValue)-\(full)"
        if loadingStores.contains(tag) { return }
        if let existing = stores[target], existing.isLoaded, existing.isFull || !full { return }

        let store = stores[target] ?? WordStore(language: target)
        stores[target] = store
        loadingStores.insert(tag)
        let limit: Int? = full ? nil : secondaryWordLimit
        DispatchQueue.global(qos: .userInitiated).async {
            let parsed = WordStore.parse(language: target, limit: limit, buildEdges: full)
            DispatchQueue.main.async { [weak self] in
                if parsed.isFull || !store.isFull { store.apply(parsed) }
                self?.loadingStores.remove(tag)
                self?.scheduleRefresh()
            }
        }
    }

    /// Keeps exactly the dictionaries that are needed: the active language, plus a few other enabled ones
    /// so words from the language you are really writing in can be suggested.
    private func ensureStores() {
        loadStore(for: language, full: true)
        var wanted: Set<Language> = [language]
        if secondaryStoresAllowed {
            let others = enabledLanguages.filter { $0 != language }.prefix(maxSecondaryStores)
            for other in others {
                wanted.insert(other)
                loadStore(for: other, full: false)
            }
        }
        for key in Array(stores.keys) where !wanted.contains(key) {
            stores[key]?.saveNow()
            stores[key] = nil
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
            ensureStores()
        }
    }

    /// +1 = next enabled language, -1 = previous (wraps around).
    private func switchLanguage(by direction: Int) {
        let enabled = enabledLanguages
        guard enabled.count > 1 else { return }
        let index = enabled.firstIndex(of: language) ?? 0
        let count = enabled.count
        selectLanguage(enabled[((index + direction) % count + count) % count])
    }

    private func selectLanguage(_ target: Language) {
        guard target != language else { return }
        language = target
        settings.languageCode = target.rawValue
        page = .letters
        clearSwipeState()
        ensureStores()
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
        guard Prefs.autoCapitalize else { return false }
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
        if Prefs.doubleSpacePeriod,
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

        // "dont" + space -> "don't ": words that only exist with an apostrophe get it automatically.
        if Prefs.suggestions, textDocumentProxy.isSecureTextEntry != true {
            let typedWord = currentPrefix(in: before)
            let fieldText = Predictor.fieldContext(before: before, after: textDocumentProxy.documentContextAfterInput ?? "")
            // A word the writer keeps using as typed is left alone.
            if !typedWord.isEmpty, !fieldText.uses(typedWord, atLeast: 2),
               let fixed = Predictor.withApostrophe(typedWord, language: language) {
                let replacement = matchCase(of: typedWord, for: fixed)
                recordBigram(contextBefore: before, next: fixed)
                for _ in 0..<typedWord.count { textDocumentProxy.deleteBackward() }
                textDocumentProxy.insertText(replacement + " ")
                clearSwipeState()
                lastSpaceTime = Date()
                afterTyping()
                return
            }
        }

        clearSwipeState()
        textDocumentProxy.insertText(" ")
        lastSpaceTime = Date()
        afterTyping()
        // Learning the finished word is not needed to show the space, so it runs right after.
        DispatchQueue.main.async { [weak self] in self?.learnWord(endingAt: before) }
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
            DispatchQueue.main.async { [weak self] in self?.learnWord(endingAt: before) }
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
        guard Prefs.suggestions, !isSearchingEmoji, textDocumentProxy.isSecureTextEntry != true else { return }
        var prefix = TextFolding.normalizeApostrophes(currentPrefix(in: before))
        while prefix.hasSuffix("'") { prefix.removeLast() }
        guard !prefix.isEmpty else { return }
        let key = TextFolding.key(prefix)
        if prefix.count >= 3, key.count >= 2 {
            // Only unknown words are learned; known words in any enabled language are left alone.
            let known = stores.values.contains { $0.isLoaded && $0.contains(key: key) }
            if !known { stores[language]?.learn(prefix.lowercased()) }
        }
        recordBigram(contextBefore: before, next: prefix)
    }

    /// Remembers which word followed which, for next-word suggestions.
    private func recordBigram(contextBefore: String, next: String) {
        guard Prefs.suggestions, !isSearchingEmoji, textDocumentProxy.isSecureTextEntry != true else { return }
        var text = contextBefore
        let typed = currentPrefix(in: text)
        if !typed.isEmpty, text.hasSuffix(typed) { text = String(text.dropLast(typed.count)) }
        guard let last = text.last, last == " " else { return }
        let following = TextFolding.normalizeApostrophes(next).lowercased()
        guard !following.isEmpty else { return }
        if Predictor.isSentenceStart(text) {
            stores[language]?.learnBigram(previous: ".", next: following)
            return
        }
        let words = Predictor.lastWords(in: text, count: 2)
        guard let previous = words.last, !previous.isEmpty else { return }
        stores[language]?.learnBigram(previous: previous, next: following)
        if words.count == 2 {
            stores[language]?.learnTrigram(first: words[0], second: previous, next: following)
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
        // Cheap part first: the shift state must be right for the very next key.
        if !refreshScheduled {
            refreshScheduled = true
            // The text proxy updates a moment after insertText, so read it on the next run-loop turn.
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.refreshScheduled = false
                self.updateAutoShift()
            }
        }
        // Suggestions are the heavy part: coalesce bursts of typing into one refresh just after the last key,
        // so a fast typist never waits behind dictionary work.
        suggestionWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.refreshSuggestions() }
        suggestionWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06, execute: work)
    }

    private func clearSwipeState() {
        lastSwipeInserted = nil
        swipeAlternatives = []
    }

    private func refreshSuggestions() {
        if isSearchingEmoji { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""

        if textDocumentProxy.isSecureTextEntry == true
            || (!Prefs.suggestions && !Prefs.emojiSuggestions) {
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
        if Prefs.emojiSuggestions && !emojiWord.isEmpty && EmojiStore.shared.isReady {
            emojis = EmojiStore.shared.suggestions(for: emojiWord, language: language, limit: 1)
        }

        ensureStores()
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        let field = Predictor.fieldContext(before: before, after: after)
        var words: [String] = []
        if Prefs.suggestions && stores[language]?.isLoaded == true {
            if !prefix.isEmpty {
                words = Predictor.suggest(typed: prefix,
                                          before: before,
                                          active: language,
                                          enabled: enabledLanguages,
                                          stores: stores,
                                          limit: 4,
                                          field: field)
                    .map { Predictor.styled(matchCase(of: prefix, for: $0), field: field, allowLower: false) }
            } else if before.hasSuffix(" ") {
                words = Predictor.nextWords(before: before,
                                            active: language,
                                            enabled: enabledLanguages,
                                            stores: stores,
                                            limit: 3,
                                            field: field)
                    .map { applyShift(to: Predictor.styled($0, field: field)) }
            }
        }

        // Layout is [left, CENTRE, right]; the most probable word sits in the centre (as on iOS).
        var ranked: [String] = []
        if !prefix.isEmpty, let phrase = settings.shortcutPhrase(for: prefix) { ranked.append(phrase) }
        for word in words where word != prefix && !ranked.contains(word) { ranked.append(word) }
        var result: [Suggestion] = []
        if !prefix.isEmpty {
            let best = ranked.first
            let second = ranked.dropFirst().first
            // Left: exactly what was typed (never auto-"corrected" away); centre: best word; right: runner-up or emoji.
            result.append(Suggestion(text: prefix, kind: .literal))
            result.append(Suggestion(text: best ?? "", kind: .word))
            if let emoji = emojis.first {
                result.append(Suggestion(text: emoji, kind: .emoji))
            } else if let second = second {
                result.append(Suggestion(text: second, kind: .word))
            }
        } else {
            let top = Array(ranked.prefix(3))
            if top.count >= 3 {
                result = [Suggestion(text: top[1], kind: .word), Suggestion(text: top[0], kind: .word), Suggestion(text: top[2], kind: .word)]
            } else if top.count == 2 {
                result = [Suggestion(text: top[1], kind: .word), Suggestion(text: top[0], kind: .word)]
            } else if top.count == 1 {
                result = [Suggestion(text: "", kind: .word), Suggestion(text: top[0], kind: .word)]
            }
            if let emoji = emojis.first {
                while result.count < 2 { result.append(Suggestion(text: "", kind: .word)) }
                if result.count >= 3 { result.removeLast() }
                result.append(Suggestion(text: emoji, kind: .emoji))
            }
        }
        suggestionBar.update(result)
    }

    private func replacePrefix(with replacement: String) {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let prefix = currentPrefix(in: before)
        recordBigram(contextBefore: before, next: replacement)
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
        recordBigram(contextBefore: before, next: first)

        var leadingSpace = ""
        if let last = before.last, !last.isWhitespace, !"([{\"\u{201C}\u{2018}'".contains(last) {
            leadingSpace = " "
        }
        let inserted = word + " "
        textDocumentProxy.insertText(leadingSpace + inserted)

        lastSwipeInserted = inserted
        swipeAlternatives = words.prefix(3).map { applyShift(to: $0) }
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
        settings.recentEmoji = Array(recents.prefix(32))
        lastSpaceTime = Date.distantPast
        clearSwipeState()
    }

    private func showEmojiPanel() {
        guard emojiPanel == nil else { return }
        let panel = EmojiPanel()
        panel.delegate = self
        panel.language = language
        panel.translatesAutoresizingMaskIntoConstraints = false
        // The picker shows only the system keyboard backdrop (like the native emoji picker): hide any theme
        // backdrop, and supply a native one when the root itself is see-through (Liquid Glass).
        hiddenForEmoji = container.subviews.filter { !$0.isHidden }
        for sub in hiddenForEmoji { sub.isHidden = true }
        if !rootIsKeyboardStyle {
            let native = UIInputView(frame: .zero, inputViewStyle: .keyboard)
            native.translatesAutoresizingMaskIntoConstraints = false
            native.accessibilityIdentifier = "emojiNativeBackdrop"
            container.addSubview(native)
            NSLayoutConstraint.activate([
                native.topAnchor.constraint(equalTo: container.topAnchor),
                native.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                native.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                native.trailingAnchor.constraint(equalTo: container.trailingAnchor)
            ])
        }
        container.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.topAnchor.constraint(equalTo: container.topAnchor),
            panel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            panel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            panel.trailingAnchor.constraint(equalTo: container.trailingAnchor)
        ])
        emojiPanel = panel
        applyHeight()
        // The picker replaces the keyboard completely: nothing may show through from behind it.
        stage.isHidden = true
        panel.reload()
        EmojiStore.shared.loadIfNeeded { [weak panel] in
            panel?.reload()
        }
    }

    private func hideEmojiPanel(refresh: Bool = true) {
        if emojiPanel != nil {
            for sub in container.subviews where sub.accessibilityIdentifier == "emojiNativeBackdrop" { sub.removeFromSuperview() }
            for sub in hiddenForEmoji { sub.isHidden = false }
            hiddenForEmoji = []
        }
        emojiPanel?.removeFromSuperview()
        emojiPanel = nil
        applyHeight()
        stage.isHidden = false
        if refresh { scheduleRefresh() }
    }

    private func beginEmojiSearch() {
        hideEmojiPanel(refresh: false)
        isSearchingEmoji = true
        applyHeight()
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
        applyHeight()
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

    func keyboardView(_ view: KeyboardView, didSwipeSpaceBy direction: Int) {
        switchLanguage(by: direction)
    }

    func keyboardViewDidHoldGlobe(_ view: KeyboardView) {
        advanceToNextInputMode()   // hand over to the next installed keyboard
    }

    func keyboardView(_ view: KeyboardView, didFinishSwipe path: [CGPoint]) {
        guard let store = stores[language], store.isLoaded else { return }
        let centers = keyboardView.letterCenters()
        let keySize = keyboardView.letterKeySize()
        let decoder = self.decoder
        // Context is read here on the main thread; the decoder only gets a copy.
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        var previous: String? = nil
        if before.isEmpty || before.last == " " || before.last == "\n" {
            previous = Predictor.lastWords(in: before, count: 1).first
        }
        let bonuses = previous.map { store.contextBonuses(after: $0) } ?? [:]

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let words = decoder.decode(path: path, keyCenters: centers, keySize: keySize, store: store, contextBonuses: bonuses)
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
            guard !suggestion.text.isEmpty else { return }
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
            settings.recentEmoji = Array(recents.prefix(32))
            lastSpaceTime = Date.distantPast
            clearSwipeState()
            afterTyping()
        }
    }

    func suggestionBarDidTapDismiss(_ bar: SuggestionBar) {
        dismissKeyboard()
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

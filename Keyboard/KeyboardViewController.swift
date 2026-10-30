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
    private let maxSecondaryStores = 4
    /// Words kept for all the other enabled languages together (split between them); halved on a memory warning.
    private var secondaryWordBudget = 160_000
    private let minimumSecondaryWords = 20_000
    /// Dictionaries load one at a time (the active language first), so two big lists never parse at once.
    private let loadQueue = DispatchQueue(label: "hunkeys.load", qos: .userInitiated)
    private let decoder = SwipeDecoder()
    /// Swipe decoding runs here, one at a time (live previews, then the final word).
    private let swipeQueue = DispatchQueue(label: "hunkeys.swipe", qos: .userInitiated)
    fileprivate struct SwipeContext {
        let sources: [SwipeDecoder.Source]
        let centers: [Character: CGPoint]
        let keySize: CGSize
    }
    /// The swipe in progress: its decoder input, built once when it starts.
    private var liveSwipe: SwipeContext?
    private var pendingSwipePath: [CGPoint]?
    private var liveDecodeRunning = false
    /// Bumped when a swipe ends, so late live previews of it are ignored.
    private var swipeGeneration = 0
    /// The language that was active before the current one (swiping also considers it, a little less strongly).
    private var lastOtherLanguage: Language?
    /// The text just before the cursor right after a swipe / suggestion added its own trailing space.
    private var autoSpaceMarker: String?

    private var lastSpaceTime = Date.distantPast
    private var lastShiftTap = Date.distantPast
    private var lastSwipeInserted: String?
    private var swipeAlternatives: [String] = []
    /// The last auto-fix (what was typed, what replaced it plus its space), until the next key: backspace undoes it.
    private var lastAutoFix: (typed: String, inserted: String)?
    /// `Settings.personalRevision` when the learned data was last read.
    private var seenPersonalRevision: Int?
    /// The correction the bar shows for the word being typed, so space makes exactly that one.
    private var shownFix: (before: String, fix: String?)?
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
        loadSystemLexicon()
        EmojiStore.shared.loadIfNeeded()
        Haptics.shared.prepare()
    }

    /// The last finished word and the text before it, to notice a word deleted and written again differently.
    private var lastCommitted: (head: String, word: String)?

    /// True when `meant` is close enough to `typed` to be the same word typed right (a slip or two).
    private func isLikelyRetype(_ typed: String, _ meant: String) -> Bool {
        let typedKey = Array(TextFolding.key(typed))
        let meantKey = Array(TextFolding.key(meant))
        guard typedKey.count >= 2, meantKey.count >= 2, typedKey != meantKey || typed != meant else { return false }
        let near = stores[language]?.neighbors ?? [:]
        let costs = typedKey.map { letter -> [Character: Double] in
            var table: [Character: Double] = [letter: 0]
            for other in near[letter] ?? [] { table[other] = 0.5 }
            return table
        }
        return Decoder.typingCost(typedKey, meantKey, costs: costs).whole <= 1.5
    }

    /// Where each letter of the word being typed was tapped, for the typing decoder (nil = not tapped: pasted,
    /// picked from a popup...). Kept in step with the word by length; see `currentTaps(for:)`.
    private var wordTaps: [CGPoint?] = []

    private func noteTap(_ text: String, at point: CGPoint?) {
        let prefix = currentPrefix(in: textDocumentProxy.documentContextBeforeInput ?? "")
        guard !prefix.isEmpty, prefix.hasSuffix(text) else {
            wordTaps = []
            return
        }
        if wordTaps.count + text.count != prefix.count {
            wordTaps = Array(repeating: nil, count: max(0, prefix.count - text.count))
        }
        wordTaps += Array(repeating: point, count: text.count)
    }

    /// The tap positions of `prefix`, when they are known for every letter.
    private func currentTaps(for prefix: String) -> Decoder.Taps? {
        guard !prefix.isEmpty, wordTaps.count == prefix.count, wordTaps.allSatisfy({ $0 != nil }) else { return nil }
        return Decoder.Taps(points: wordTaps, centers: keyboardView.letterCenters(), keySize: keyboardView.letterKeySize())
    }

    /// The user's text replacements (Settings > General > Keyboard > Text Replacement), lower-case shortcut -> phrase.
    private var systemShortcuts: [String: String] = [:]

    /// Contacts' names (suggested, never "corrected") and the user's text replacements, from iOS.
    private func loadSystemLexicon() {
        requestSupplementaryLexicon { [weak self] lexicon in
            var names: [String: String] = [:]
            var shortcuts: [String: String] = [:]
            for entry in lexicon.entries {
                let input = entry.userInput
                let text = entry.documentText
                if input == text {
                    guard text.count >= 2, text.allSatisfy({ Predictor.isWordCharacter($0) }) else { continue }
                    names[text.lowercased()] = text
                } else if !input.isEmpty {
                    shortcuts[input.lowercased()] = text
                }
            }
            DispatchQueue.main.async {
                Decoder.setNames(names)
                self?.systemShortcuts = shortcuts
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if updateKeyStyle() { buildInterface() }
        Haptics.shared.hasFullAccess = hasFullAccess
        Haptics.shared.prepare()
        settings.markKeyboardSeen(hasFullAccess: hasFullAccess)
        var usage: [Language: Double] = [:]
        for (code, value) in settings.languageUsage() {
            if let language = Language(rawValue: code) { usage[language] = value }
        }
        Decoder.languageUsage = usage

        // Learned words changed in the app (removed or cleared) while the keyboard was away: read them again.
        let revision = settings.personalRevision
        if let seen = seenPersonalRevision, seen != revision {
            for store in stores.values { store.reloadPersonal() }
        }
        seenPersonalRevision = revision

        // Settings changed in the app while the keyboard was away: rebuild the look.
        Prefs.refresh()
        if settingsSignature() != builtSignature {
            buildInterface()
        }
        applyHeight()
        updateAutoShift()
        scheduleRefresh()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if updateKeyStyle() { buildInterface() }
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
        var usage: [String: Double] = [:]
        for (language, value) in Decoder.languageUsage { usage[language.rawValue] = value }
        settings.setLanguageUsage(usage)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Shrink the other languages instead of dropping them: they are freed now and reloaded at once with half as
        // many words (never fewer than `minimumSecondaryWords`), so typing in every enabled language keeps working.
        secondaryWordBudget = max(minimumSecondaryWords, secondaryWordBudget / 2)
        let others = max(1, min(maxSecondaryStores, enabledLanguages.count - 1))
        let share = max(minimumSecondaryWords, secondaryWordBudget / others)
        // Memory-mapped dictionaries cost no memory of their own; only lists parsed from text are shrunk.
        for (key, store) in stores
        where key != language && store.isLoaded && !store.entries.isMapped && store.entries.count > share {
            store.saveNow()
            store.unload()
        }
        ensureStores()
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
            SharedStore.defaults.string(forKey: SettingKey.accentHex) ?? ""
        ].joined(separator: "|")
    }

    /// Light or dark. A theme that forces one sets the whole keyboard. Otherwise the keys are dark when the phone
    /// or the app is in dark mode (so a dark mode phone keeps dark keys in an app that stays light), while the
    /// rest (suggestions, emoji picker) keeps the app's style, which the system-drawn keyboard backdrop follows.
    /// Dark keys on that light backdrop get lighter fills (Theme.contrastKeys) so they stand out.
    /// Returns true when contrastKeys changed (the keys must then be rebuilt).
    /// The keys' style for updateKeyStyle: dark when the phone or the app is dark, else the app's.
    private var keyInterfaceStyle: UIUserInterfaceStyle {
        guard Theme.interfaceStyle == .unspecified else { return .unspecified }
        let phone = UIScreen.main.traitCollection.userInterfaceStyle
        return phone == .dark || view.traitCollection.userInterfaceStyle == .dark ? .dark : .unspecified
    }

    private func updateKeyStyle() -> Bool {
        view.overrideUserInterfaceStyle = Theme.interfaceStyle
        let keys = keyInterfaceStyle
        keyboardView.overrideUserInterfaceStyle = keys
        let app = view.traitCollection.userInterfaceStyle
        let differs = keys != .unspecified && app != .unspecified && keys != app
        guard differs != Theme.contrastKeys else { return false }
        Theme.contrastKeys = differs
        return true
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if updateKeyStyle() { buildInterface() }
    }

    /// (Re)creates every view. Called at start and whenever a look-changing setting was edited.
    private func buildInterface() {
        Prefs.refresh()
        Theme.reload()
        _ = updateKeyStyle()
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
        keyboardView.overrideUserInterfaceStyle = keyInterfaceStyle

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
        // The emoji picker always shows four full rows: the keyboard grows to fit while it is open. An iPhone in
        // landscape always has that height, so the keyboard never jumps between letters, picker and search.
        // (The view may not have its final width yet when the picker opens, so fall back to the screen width.)
        let width = view.bounds.width > 100 ? view.bounds.width : UIScreen.main.bounds.width
        let panelScale = EmojiPanel.scale(forWidth: width)
        if emojiPanel != nil || isSearchingEmoji || isLandscape {
            total = max(total, EmojiPanel.requiredHeight(forWidth: width))
        }
        var suggestions: CGFloat = isLandscape ? 36 : 44
        if isSearchingEmoji {
            // Same height and top gap as the picker, so the search field stays exactly where it was.
            EmojiSearchBar.topInset = (5 * panelScale).rounded()
            // (The picker's pill is a full 44pt in its wide layout: iPad, iPhone in landscape.)
            let wide = EmojiPanel.usesWideLayout(width: width, height: total)
            suggestions = (wide ? 44 : 44 * panelScale) + EmojiSearchBar.topInset
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

    /// Loads a dictionary (with its swipe index) in the background. `limit` nil = every word, for the active
    /// language; the other enabled languages keep their `limit` most frequent words, to save memory.
    private func loadStore(for target: Language, limit: Int?) {
        let tag = "\(target.rawValue)-\(limit ?? 0)"
        if loadingStores.contains(tag) { return }
        if let existing = stores[target], existing.isLoaded {
            if existing.entries.isMapped { return }   // the whole list, at no memory cost
            // The whole list is there and fits: nothing to load. A list bigger than the limit (it was the active
            // language) is trimmed; a trimmed one is reloaded only when its limit changes.
            if existing.isFull && (limit == nil || existing.entries.count <= limit ?? 0) { return }
            if let limit = limit, existing.loadedLimit == limit { return }
        }

        let store = stores[target] ?? WordStore(language: target)
        stores[target] = store
        loadingStores.insert(tag)
        loadQueue.async {
            let parsed = WordStore.parse(language: target, limit: limit)
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                // A trimmed list never replaces the language being typed in (a late load after a switch).
                if parsed.isFull || target != self.language { store.apply(parsed) }
                self.loadingStores.remove(tag)
                self.scheduleRefresh()
            }
        }
    }

    /// Keeps exactly the dictionaries that are needed: the active language in full, plus every other enabled
    /// language (up to `maxSecondaryStores`) sharing `secondaryWordBudget` words, so suggestions and swiping
    /// work in all of them.
    private func ensureStores() {
        loadStore(for: language, limit: nil)
        var wanted: Set<Language> = [language]
        let others = Array(enabledLanguages.filter { $0 != language }.prefix(maxSecondaryStores))
        let share = others.isEmpty ? 0 : max(minimumSecondaryWords, secondaryWordBudget / others.count)
        for other in others {
            wanted.insert(other)
            loadStore(for: other, limit: share)
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
        lastOtherLanguage = language
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
        // Punctuation that normally ends a word goes right after the word when the space in front of it was
        // added automatically (by a swipe or a picked suggestion) and nothing was typed since.
        if text.count == 1, ".,!?;:)]}\u{2026}".contains(text) {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            if let marker = autoSpaceMarker, !marker.isEmpty, before.hasSuffix(marker), before.hasSuffix(" "),
               let beforeSpace = before.dropLast().last, beforeSpace.isLetter || beforeSpace.isNumber {
                textDocumentProxy.deleteBackward()
            }
        }
        autoSpaceMarker = nil
        textDocumentProxy.insertText(output)
        lastSpaceTime = Date.distantPast
        afterTyping()
    }

    private func handleSpace() {
        let pendingMarker = autoSpaceMarker
        autoSpaceMarker = nil
        if isSearchingEmoji {
            if !searchQuery.isEmpty && !searchQuery.hasSuffix(" ") { searchQuery += " " }
            refreshEmojiSearch()
            return
        }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""

        // A swiped / suggested word already has its space: the first space tap keeps just that one.
        // Further taps add spaces as usual.
        if let marker = pendingMarker, !marker.isEmpty, before.hasSuffix(marker), before.hasSuffix(" ") {
            clearSwipeState()     // the swiped word is accepted: its alternatives leave the bar
            lastSpaceTime = Date.distantPast
            scheduleRefresh()
            return
        }

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

        // Auto-correction: "vsgyok" + space -> "vagyok ", "koszonom" -> "köszönöm ", "dont" -> "don't ", in any enabled
        // language (see Decoder.autoCorrect). Backspace right after takes it back. Fields that ask for no
        // correction (addresses, codes) are left alone.
        if autoCorrectAllowed {
            let typedWord = currentPrefix(in: before)
            let fieldText = Predictor.fieldContext(before: before, after: textDocumentProxy.documentContextAfterInput ?? "")
            let fix: String?
            if let shown = shownFix, shown.before == before {
                fix = shown.fix
            } else if !typedWord.isEmpty {
                fix = Predictor.autoFix(typed: typedWord, before: before, active: language, enabled: enabledLanguages,
                                        stores: stores, field: fieldText, taps: currentTaps(for: typedWord))
            } else {
                fix = nil
            }
            if !typedWord.isEmpty, let fixed = fix {
                let replacement = matchCase(of: typedWord, for: fixed)
                recordBigram(contextBefore: before, next: fixed)
                noteWordUse(fixed)
                for _ in 0..<typedWord.count { textDocumentProxy.deleteBackward() }
                textDocumentProxy.insertText(replacement + " ")
                clearSwipeState()
                lastAutoFix = (typed: typedWord, inserted: replacement + " ")
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

    /// Auto-correction is on and the field accepts it (not passwords, addresses or codes).
    private var autoCorrectAllowed: Bool {
        return Prefs.suggestions && Prefs.autoCorrect && textDocumentProxy.isSecureTextEntry != true
            && textDocumentProxy.autocorrectionType != .no
            && ![UIKeyboardType.URL, .emailAddress].contains(textDocumentProxy.keyboardType ?? .default)
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
        if let fix = lastAutoFix, before.hasSuffix(fix.inserted) {
            // Right after an auto-fix, backspace puts back what was typed, and that spelling is kept from now on.
            for _ in 0..<fix.inserted.count { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(fix.typed)
            stores[language]?.learn(fix.typed, asTyped: true)
            lastCommitted = nil   // the typed word was kept on purpose: no typo to learn here
            clearSwipeState()
        } else if let inserted = lastSwipeInserted, before.hasSuffix(inserted) {
            // Right after a swipe, backspace removes the whole swiped word (and takes back its use).
            for _ in 0..<inserted.count { textDocumentProxy.deleteBackward() }
            noteWordUse(inserted.trimmingCharacters(in: .whitespaces), delta: -1)
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
        if prefix.count >= 3 { noteWordUse(prefix) }
        recordBigram(contextBefore: before, next: prefix)
    }

    /// Counts a finished word: a dictionary word ranks higher from now on (in the dictionary that has it, the active
    /// language first); a word no enabled dictionary knows is learned. `delta` -1 takes back a swiped word.
    private func noteWordUse(_ word: String, delta: Int = 1) {
        guard Prefs.suggestions, !isSearchingEmoji, textDocumentProxy.isSecureTextEntry != true else { return }
        let cleaned = TextFolding.normalizeApostrophes(word).lowercased()
        guard cleaned.count >= 2, cleaned.allSatisfy({ Predictor.isWordCharacter($0) }) else { return }
        if delta > 0 {
            // Which languages the user writes in (the first words of a text lean towards them).
            var head = textDocumentProxy.documentContextBeforeInput ?? ""
            let typing = currentPrefix(in: head)
            if !typing.isEmpty { head = String(head.dropLast(typing.count)) }
            Decoder.noteLanguage(of: cleaned, before: head, active: language, stores: stores)
            // A different word written where the last one was (the user deleted it): a typo of theirs to learn.
            if let previous = lastCommitted, previous.head == head, previous.word != cleaned,
               isLikelyRetype(previous.word, cleaned) {
                stores[language]?.learnCorrection(from: previous.word, to: cleaned)
            }
            lastCommitted = (head, cleaned)
        }
        if stores[language]?.noteUse(cleaned, delta: delta) == true { return }
        for store in stores.values where store.language != language && store.isLoaded {
            if store.noteUse(cleaned, delta: delta) { return }
        }
        let key = TextFolding.key(cleaned)
        guard delta > 0, cleaned.count >= 3, key.count >= 2 else { return }
        // Only unknown words are learned; known words in any enabled language (other spellings) are left alone.
        let known = stores.values.contains { $0.isLoaded && $0.contains(key: key) }
        if !known { stores[language]?.learn(cleaned) }
    }

    /// Remembers which word followed which, for next-word suggestions.
    private func recordBigram(contextBefore: String, next: String) {
        guard Prefs.suggestions, !isSearchingEmoji, textDocumentProxy.isSecureTextEntry != true else { return }
        var text = contextBefore
        let typed = currentPrefix(in: text)
        if !typed.isEmpty, text.hasSuffix(typed) { text = String(text.dropLast(typed.count)) }
        guard let last = text.last, last == " " else { return }
        // Two words put in for a missing space: the pair is the previous word and the first of them.
        let following = TextFolding.normalizeApostrophes(next).lowercased()
            .split(separator: " ").first.map(String.init) ?? ""
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
        return settings.shortcutPhrase(for: prefix) ?? systemShortcuts[prefix.lowercased()]
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
        if isEnglishI(word) { return capitalizedFirst(word) }
        return word
    }

    private func applyShift(to word: String) -> String {
        switch shift {
        case .locked: return language.uppercase(word)
        case .once: return capitalizedFirst(word)
        case .off:
            if isEnglishI(word) { return capitalizedFirst(word) }
            return word
        }
    }

    /// English "i", "i'm", "i'll" ... take a capital I in any layout while English is enabled, unless the layout's
    /// language has the word itself (Italian "i").
    private func isEnglishI(_ word: String) -> Bool {
        guard word == "i" || word.hasPrefix("i'"), enabledLanguages.contains(.english) else { return false }
        return language == .english || stores[language]?.contains(key: TextFolding.key(word)) != true
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
        lastAutoFix = nil
    }

    private func refreshSuggestions() {
        shownFix = nil
        if isSearchingEmoji { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""

        if textDocumentProxy.isSecureTextEntry == true
            || (!Prefs.suggestions && !Prefs.emojiSuggestions) {
            suggestionBar.update([])
            return
        }

        // Right after a swipe the bar offers other readings of the swiped word, the one inserted in the centre
        // (only while that word is still the last thing in the field).
        if let inserted = lastSwipeInserted, !before.hasSuffix(inserted) { clearSwipeState() }
        if lastSwipeInserted != nil && swipeAlternatives.count > 1 {
            var shown = swipeAlternatives.prefix(3).map { Suggestion(text: $0, kind: .swipeAlternative) }
            shown.swapAt(0, 1)
            suggestionBar.update(shown)
            return
        }

        let prefix = currentPrefix(in: before)
        var emojiWord = prefix
        if prefix.isEmpty, before.hasSuffix(" ") {
            emojiWord = currentPrefix(in: String(before.dropLast()))   // word that was just finished
        }

        var emojis: [String] = []
        if Prefs.emojiSuggestions && !emojiWord.isEmpty && EmojiStore.shared.isReady {
            // The word's own language first ("hat" is six in Hungarian, a hat in English), then the others.
            let owners = Predictor.owners(of: emojiWord, stores: stores)
            let order = owners + ([language] + enabledLanguages).filter { !owners.contains($0) }
            var languages: [Language] = []
            for candidate in order where !languages.contains(candidate) { languages.append(candidate) }
            emojis = EmojiStore.shared.suggestions(for: emojiWord, languages: languages, limit: 1)
        }

        ensureStores()
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        let field = Predictor.fieldContext(before: before, after: after)
        var words: [String] = []
        var fix: String? = nil
        if Prefs.suggestions && stores[language]?.isLoaded == true {
            if !prefix.isEmpty {
                let found = Predictor.suggestAndFix(typed: prefix,
                                                    before: before,
                                                    active: language,
                                                    enabled: enabledLanguages,
                                                    stores: stores,
                                                    limit: 4,
                                                    field: field,
                                                    taps: currentTaps(for: prefix))
                words = found.words.map { Predictor.styled(matchCase(of: prefix, for: $0), field: field, allowLower: false) }
                if autoCorrectAllowed {
                    fix = found.fix
                    shownFix = (before, found.fix)
                }
            } else if before.isEmpty || before.hasSuffix(" ") {
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
        let phrase = shortcutExpansion(in: before)
        if let phrase = phrase { ranked.append(phrase) }
        for word in words where word != prefix && !ranked.contains(word) { ranked.append(word) }
        var result: [Suggestion] = []
        var highlighted: Int? = nil
        if !prefix.isEmpty {
            // Left: exactly what was typed (never auto-"corrected" away); centre: what space will write when it
            // corrects (highlighted), else the best word; right: runner-up or emoji.
            if phrase != nil {
                highlighted = 1   // space expands the shortcut
            } else if let fix = fix {
                let shown = matchCase(of: prefix, for: fix)
                ranked.removeAll { $0 == shown }
                ranked.insert(shown, at: 0)
                highlighted = 1
            }
            let best = ranked.first
            let second = ranked.dropFirst().first
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
        suggestionBar.update(result, highlighted: highlighted)
    }

    private func replacePrefix(with replacement: String) {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let prefix = currentPrefix(in: before)
        recordBigram(contextBefore: before, next: replacement)
        noteWordUse(replacement)
        for _ in 0..<prefix.count { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(replacement + " ")
        lastSpaceTime = Date()
        autoSpaceMarker = String((String(before.dropLast(prefix.count)) + replacement + " ").suffix(12))
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
        noteWordUse(first)
        lastCommitted = nil   // swiped words are not typed: a replacement in their place is no typo

        var leadingSpace = ""
        if let last = before.last, !last.isWhitespace, !"([{\"\u{201C}\u{2018}'".contains(last) {
            leadingSpace = " "
        }
        let inserted = word + " "
        textDocumentProxy.insertText(leadingSpace + inserted)
        autoSpaceMarker = String((before + leadingSpace + inserted).suffix(12))

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
        noteWordUse(inserted.trimmingCharacters(in: .whitespaces), delta: -1)
        noteWordUse(replacement)
        lastCommitted = nil
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
        EmojiStore.shared.loadSearchIfNeeded(languages: enabledLanguages + [.english]) { [weak self] in
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
        if action != .backspace { lastAutoFix = nil }   // an auto-fix can only be undone by the very next key
        switch action {
        case .character(let text):
            insert(text)
            noteTap(text, at: view.lastTapPoint)
        case .space: handleSpace()
        case .enter: handleEnter()
        case .backspace:
            handleBackspace()
            if !wordTaps.isEmpty { wordTaps.removeLast() }
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

    func keyboardView(_ view: KeyboardView, didUpdateSwipe path: [CGPoint]) {
        guard !isSearchingEmoji, textDocumentProxy.isSecureTextEntry != true else { return }
        if liveSwipe == nil { liveSwipe = makeSwipeContext() }
        guard liveSwipe != nil else { return }
        pendingSwipePath = path
        decodeLiveSwipe()
    }

    func keyboardView(_ view: KeyboardView, didFinishSwipe path: [CGPoint]) {
        // Live previews still running belong to this swipe; their results are dropped.
        swipeGeneration += 1
        let context = liveSwipe ?? makeSwipeContext()
        liveSwipe = nil
        pendingSwipePath = nil
        guard let swipe = context else { return }
        let decoder = self.decoder
        swipeQueue.async { [weak self] in
            let words = decoder.decode(path: path, keyCenters: swipe.centers, keySize: swipe.keySize, sources: swipe.sources)
            DispatchQueue.main.async {
                if words.isEmpty { self?.scheduleRefresh() }   // no word: drop the live preview
                self?.commitSwipe(words)
            }
        }
    }

    func keyboardViewDidCancelSwipe(_ view: KeyboardView) {
        swipeGeneration += 1
        liveSwipe = nil
        pendingSwipePath = nil
        scheduleRefresh()   // replace the live preview with the normal suggestions
    }

    /// Decodes the latest swipe path off the main thread and shows the best word in the middle of the bar while the
    /// finger is still moving. One decode at a time: a path that grew meanwhile is decoded right after.
    private func decodeLiveSwipe() {
        guard !liveDecodeRunning, let swipe = liveSwipe, let path = pendingSwipePath else { return }
        pendingSwipePath = nil
        liveDecodeRunning = true
        let generation = swipeGeneration
        let decoder = self.decoder
        swipeQueue.async { [weak self] in
            let words = decoder.decode(path: path, keyCenters: swipe.centers, keySize: swipe.keySize,
                                       sources: swipe.sources, limit: 1)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.liveDecodeRunning = false
                if generation == self.swipeGeneration, let word = words.first {
                    self.suggestionBar.update([Suggestion(text: "", kind: .literal),
                                               Suggestion(text: self.applyShift(to: word), kind: .word),
                                               Suggestion(text: "", kind: .literal)])
                }
                self.decodeLiveSwipe()
            }
        }
    }

    /// Everything the decoder needs for one swipe, read on the main thread: the key geometry and every loaded
    /// dictionary with its context. The decoder only gets copies.
    private func makeSwipeContext() -> SwipeContext? {
        guard let store = stores[language], store.isLoaded else { return nil }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        var previous: String? = nil
        if before.isEmpty || before.last == " " || before.last == "\n" {
            previous = Predictor.lastWords(in: before, count: 1).first
        }
        let before2 = Predictor.lastWords(in: before, count: 2)
        let bonuses = previous.map { store.contextBonuses(after: $0, before2: before2.count > 1 ? before2[0] : nil) } ?? [:]
        // Which language is being written? The layout's language, the words already in the field and the language
        // switched away from last all vote; every loaded language is a candidate with a penalty by how unlikely it is.
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        let field = Predictor.fieldContext(before: before, after: after)
        let weights = Predictor.contextWeights(before: before, currentPrefix: "", active: language, stores: stores)
        let dominant = field.dominant(active: language, stores: stores)
        let foreignDominant: Language? = (dominant != nil && dominant != language) ? dominant : nil
        var fieldBonuses: [String: Double] = [:]
        for word in field.counts.keys { fieldBonuses[word] = field.bonus(for: word) }

        func likelihood(_ candidate: Language) -> Double {
            // The layout's language only breaks near-ties; the language of the text decides.
            var value = 0.5 * (weights[candidate] ?? 0)
            if candidate == language { value += foreignDominant == nil ? 0.12 : 0.04 }
            if candidate == foreignDominant { value += 0.40 }
            if candidate == lastOtherLanguage { value += 0.04 }
            return value
        }
        let candidates = ([language] + enabledLanguages.filter { $0 != language })
            .filter { stores[$0]?.isLoaded == true }
        let best = candidates.map { likelihood($0) }.max() ?? 0
        var sources: [SwipeDecoder.Source] = []
        for candidate in candidates {
            guard let candidateStore = stores[candidate] else { continue }
            let candidatePrevious = previous
            sources.append(SwipeDecoder.Source(
                store: candidateStore,
                // Firm enough that a common word of another language does not beat the one being written.
                penalty: min(0.7, 1.1 * (best - likelihood(candidate))),
                contextBonuses: candidatePrevious.map {
                    candidateStore.contextBonuses(after: $0, before2: (candidate == language && before2.count > 1) ? before2[0] : nil)
                } ?? [:],
                personal: candidateStore.personalStrengths(),
                extras: candidateStore.learnedEntries(),
                fieldBonuses: fieldBonuses))
        }
        if sources.isEmpty {
            sources = [SwipeDecoder.Source(store: store, penalty: 0, contextBonuses: bonuses,
                                           personal: store.personalStrengths(), extras: store.learnedEntries())]
        }
        // With the language models, swiped words are scored like typed ones (see Decoder): each language by its
        // share of the text and the probability of the word after the previous ones.
        if Decoder.isAvailable(stores) {
            let context = Decoder.context(before: before, active: language, stores: stores)
            for index in sources.indices {
                let source = sources[index].store
                guard let candidate = stores.first(where: { $0.value === source })?.key else { continue }
                let history = context.histories[candidate] ?? [LanguageModel.start]
                sources[index].model = source.model
                sources[index].weight = context.weights[candidate] ?? 0
                sources[index].previousId = history[history.count - 1]
                sources[index].beforeId = history.count >= 2 ? history[history.count - 2] : nil
                var learned: [String: Double] = [:]
                for entry in sources[index].extras {
                    if let value = source.learnedLogProb(entry.word) { learned[entry.word] = value }
                }
                // Contacts' names, in every language (their weights add up to one).
                sources[index].extras += Decoder.nameEntries
                for entry in Decoder.nameEntries { learned[entry.word] = max(learned[entry.word] ?? -99, Decoder.nameLogProb) }
                sources[index].learnedLogProbs = learned
                var boosts: [String: Double] = [:]
                for (word, strength) in sources[index].personal { boosts[word] = 0.8 * strength }
                for follower in source.userFollowers(of: context.previous ?? ".") {
                    boosts[follower.word, default: 0] += follower.strength
                }
                sources[index].boosts = boosts
            }
        }
        return SwipeContext(sources: sources, centers: keyboardView.letterCenters(), keySize: keyboardView.letterKeySize())
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
            // The emoji takes the place of the word it was suggested for: the one being typed, or the one just
            // finished ("sad" or "sad " -> the emoji and a space).
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            let typing = currentPrefix(in: before)
            var replaced = 0
            if !typing.isEmpty {
                replaced = typing.count
            } else if before.hasSuffix(" ") {
                let finished = currentPrefix(in: String(before.dropLast()))
                if !finished.isEmpty { replaced = finished.count + 1 }
            }
            for _ in 0..<replaced { textDocumentProxy.deleteBackward() }
            let needsSpace = replaced == 0 && (before.last?.isWhitespace == false)
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

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
    /// The Functions panel, shown in place of the keys (the suggestion bar's left button).
    private var toolsPanel: ToolsPanel?
    /// What the case tool last wrote (it cannot re-select it, so it finds it again before the caret).
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
    /// Swipes being decoded: key taps that come meanwhile wait, so they land after the swiped word.
    private var swipesDecoding = 0
    private var queuedActions: [(action: KeyAction, point: CGPoint?)] = []
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
    /// The live swipe preview waits for the finger to pause for the Update speed delay, as typed words do.
    private var liveSwipeWork: DispatchWorkItem?
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

    /// What a delete took away, so sliding back right from backspace can put it back: text removed from the
    /// document, or what the composing letters or the emoji search were before.
    private enum DeletedPiece {
        case text(String)
        case composing(String)
        case search(String)
    }
    /// The words deleted by the current slide, oldest first (nil: a step that found nothing to delete).
    private var wordDeleteStack: [DeletedPiece?] = []
    /// `Settings.personalRevision` when the learned data was last read.
    private var seenPersonalRevision: Int?
    /// The correction the bar shows for the word being typed, so space makes exactly that one.
    private var shownFix: (before: String, fix: String?)?
    private var refreshScheduled = false
    private var suggestionWork: DispatchWorkItem?

    // Emoji search (typing on the normal keys while the picker's search field is "active")
    private var isSearchingEmoji = false
    private var searchQuery = ""

    // Languages typed by sound (Jyutping, Pinyin, romaji): the letters typed so far, shown underlined in the field
    // (marked text) until a word is picked for them, and the words the bar offers for them.
    private var composing = ""
    private var phoneticCandidates: [PhoneticInput.Candidate] = []
    /// The last word picked, for an emoji suggestion after it (開心 -> 😄).
    private var lastPickedWord: String?
    /// Korean: the syllable being built from jamo (the last character in the field).
    private var hangul = HangulComposer()

    /// Text selected with the space bar's trackpad (a second finger on the keys): where the selection's other end is,
    /// in characters from the cursor (negative: before it). Nil: nothing is selected that way.
    private var selectionAnchor: Int?
    /// The trackpad is selecting (the second finger touched): its moves grow the selection.
    private var selectingWithCursor = false
    /// The calculation or conversion the bar offers for the end of the text.
    private var shownSmart: (result: SmartResult, isCalculation: Bool)?
    /// Every unit the measurement at the end of the text can be written in (all of them are in the bar).
    private var shownConversions: [SmartResult] = []
    /// An emoji the bar offers for the words that end the text ("red heart"), and how many characters it replaces.
    private var shownEmojiPhrase: (emoji: String, length: Int)?
    /// The shortcut the bar offers, filled in ({date}...), with its cursor mark, and as it is shown.
    private var shownShortcut: (expanded: String, shown: String)?
    /// The text before the cursor right after a space was added behind a punctuation mark (the Typing setting).
    private var punctuationSpaceMarker: String?
    /// The letter layouts the dictionaries were loaded with (their typo model knows which keys are neighbours).
    private var loadedLayouts: [String: String] = [:]

    // MARK: Lifecycle

    /// True when the root view uses the system keyboard backdrop. The Liquid Glass theme asks for a plain
    /// (see-through) root instead, so what is behind the keyboard shows through.
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

    /// The keyboard always follows the open app's mode. While the phone turns, the system briefly reports the
    /// wrong mode (the keyboard flashes dark in light apps), so the mode in use is held until the turn is over.
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        let held = view.traitCollection.userInterfaceStyle
        if held != .unspecified { view.overrideUserInterfaceStyle = held }
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            guard let self = self else { return }
            self.view.overrideUserInterfaceStyle = .unspecified
            self.keyboardView.refreshGlassTints()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Everything we draw lives in `container`, so the system's own backdrop views stay untouched.
        container.translatesAutoresizingMaskIntoConstraints = false
        // Never fully see-through: the system does not deliver a keyboard extension's touches that land on
        // completely transparent pixels, so taps in the gaps between keys (and between the Functions tiles) were
        // lost. A tint this faint cannot be seen.
        container.backgroundColor = UIColor(white: 0, alpha: 0.011)
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        language = Language(rawValue: settings.languageCode) ?? .english

        buildInterface()
        loadedLayouts = Prefs.letterLayouts
        ensureStores()
        // Unpacked data of languages turned off in the app since (LanguageData) is removed.
        LanguageData.removeUnpackedInBackground(keeping: Set(settings.enabledLanguages))
        loadSystemLexicon()
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
            LearnedWords.shared.reload()
            for language in Language.allCases where language.usesPhoneticInput {
                PhoneticInput.shared(for: language).reloadPicks()
            }
        }
        seenPersonalRevision = revision

        // Settings changed in the app while the keyboard was away: rebuild the look.
        Prefs.refresh()
        if settingsSignature() != builtSignature {
            buildInterface()
        }
        // A language given another letter layout: its dictionary is loaded again, so its typo model knows the new
        // neighbouring keys.
        if Prefs.letterLayouts != loadedLayouts {
            let changed = Set(Prefs.letterLayouts.keys).union(loadedLayouts.keys)
                .filter { Prefs.letterLayouts[$0] != loadedLayouts[$0] }
            loadedLayouts = Prefs.letterLayouts
            for code in changed {
                guard let changedLanguage = Language(rawValue: code), let store = stores[changedLanguage] else { continue }
                store.saveNow()
                stores[changedLanguage] = nil
            }
            ensureStores()
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
        updatePhoneLandscape()
        if let built = builtSplit, built != KeyboardLayoutMode.split { reloadKeyboardLayout() }
        applyHeight()
        recordEmojiSize()
    }

    /// The keyboard's real size while the emoji picker is open, kept for the app's Emoji preview (upright only: a
    /// landscape keyboard is not recorded).
    private func recordEmojiSize() {
        guard emojiPanel != nil else { return }
        let size = view.bounds.size
        let screen = UIScreen.main.bounds.size
        guard size.width > 100, size.height > 100, size.width <= min(screen.width, screen.height) + 1 else { return }
        let text = "\(Int(size.width.rounded())),\(Int(size.height.rounded()))"
        if SharedStore.defaults.string(forKey: SettingKey.lastEmojiSize) != text {
            SharedStore.defaults.set(text, forKey: SettingKey.lastEmojiSize)
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        finishComposing()
        for language in Language.allCases where language.usesPhoneticInput {
            PhoneticInput.shared(for: language).saveNow()
        }
        LearnedWords.shared.saveNow()
        TapAccuracy.shared.flush()
        TapBias.shared.flush()
        for store in stores.values { store.saveNow() }
        saveLanguageUsage()
        TypingStats.shared.save()
    }

    private var usageNotes = 0

    private func saveLanguageUsage() {
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

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        refreshToolsSoon()   // copy, cut and the case tool follow the selection while the functions stay open
        scheduleRefresh()    // text selected in the app: the bar offers copy, cut and the rest
    }

    override func textDidChange(_ textInput: UITextInput?) {
        refreshToolsSoon()
        updateReturnTitle()
        scheduleRefresh()   // auto-shift and suggestions are refreshed off the typing path
    }

    // MARK: Building the interface

    private func settingsSignature() -> String {
        let s = settings
        // (Worked out apart: in the list below they made the expression too slow for the compiler to type-check.)
        let layouts: String = Settings.signature(of: s.letterLayouts)
        let holds: String = Settings.signature(of: s.customHolds)
        let tools: String = s.keyboardTools.map { $0.rawValue }.joined(separator: ",")
        let parts: [String] = [
            "\(s.numberRow)", "\(s.keyHints)", Theme.storedID(), s.accentName,
            "\(s.keyPopups)", "\(Prefs.keyRoundness)", s.keySurface, s.keyBorderStyle, s.keyGlow, s.keyFont,
            s.enabledLanguages.joined(separator: ","),
            SharedStore.defaults.string(forKey: SettingKey.accentHex) ?? "",
            // Keys and the suggestion bar (the app's Keys and Suggestions screens)
            "\(s.keyHeight)", "\(s.landscapeSeparate)", "\(s.landscapeKeyHeight)", "\(s.keyboardWidth)",
            "\(s.keyGap)", "\(s.rowGap)", "\(s.alwaysCapitals)", "\(s.letterSize)", s.hintPosition, "\(s.hintSize)",
            "\(s.spaceTextSize)", "\(s.spaceLanguageCode)", s.suggestionStyle, s.separatorStyle,
            "\(s.suggestionFollowTheme)", "\(s.suggestionHeight)", "\(s.suggestionFit)", "\(s.suggestionScroll)", "\(s.suggestionScrollThree)", s.extraKeys.joined(), s.extraKeysLeft.joined(), "\(s.commaKey)\(s.periodKey)\(s.emojiKey)", s.commaHold.joined(), s.periodHold.joined(),
            "\(s.splitKeyboard)", s.oneHanded, tools,
            s.effectsJSON, s.systemEditsJSON, layouts, holds
        ]
        return parts.joined(separator: "|")
    }

    /// (Re)creates every view. Called at start and whenever a look-changing setting was edited.
    private func buildInterface() {
        Prefs.refresh()
        Theme.reload()
        validateLanguage()
        hideEmojiPanel(refresh: false)
        isSearchingEmoji = false
        searchQuery = ""
        toolsPanel = nil   // goes with the old stage
        for sub in container.subviews { sub.removeFromSuperview() }

        if !rootIsKeyboardStyle && !Theme.isLiquidGlass {
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
        suggestionBar.showsToolsButton = !availableTools().isEmpty
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
        // The keyboard is as tall as its rows of keys (key height + the gap between rows) and the bar. At the
        // defaults: 276pt on a phone, 208pt in landscape (keys two thirds as tall) and 340pt on an iPad.
        let keyHeight: CGFloat
        if isPad {
            keyHeight = CGFloat(Prefs.keyHeight) * 61 / 45
        } else if isLandscape {
            keyHeight = Prefs.landscapeSeparate ? CGFloat(Prefs.landscapeKeyHeight) : CGFloat(Prefs.keyHeight) * 30 / 45
        } else {
            keyHeight = CGFloat(Prefs.keyHeight)
        }
        // The letter rows (Thai has four), the bottom row and the number row.
        let rowCount = CGFloat(language.letterRows.count + 1 + (Prefs.numberRow ? 1 : 0))
        let barHeight = CGFloat(Prefs.suggestionHeight) * (isLandscape ? 36.0 / 44.0 : 1.0)
        var total = barHeight + 8 + rowCount * (keyHeight + CGFloat(Prefs.rowGap))
        // The emoji picker always shows four full rows: the keyboard grows to fit while it is open. An iPhone in
        // landscape always has that height, so the keyboard never jumps between letters, picker and search.
        // (The view may not have its final width yet when the picker opens, so fall back to the screen width.)
        let width = view.bounds.width > 100 ? view.bounds.width : UIScreen.main.bounds.width
        let panelScale = EmojiPanel.scale(forWidth: width)
        if emojiPanel != nil || isSearchingEmoji || isLandscape {
            total = max(total, EmojiPanel.requiredHeight(forWidth: width))
        }
        var suggestions = barHeight
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

    /// Whether the keys on screen were laid out split (nil until they are first built); an iPhone splits only in
    /// landscape, so turning it rebuilds them.
    private var builtSplit: Bool?

    /// An iPhone keyboard wider than any phone upright is in landscape (as applyHeight); the split keyboard
    /// follows it (KeyboardLayoutMode.phoneLandscape).
    private func updatePhoneLandscape() {
        guard view.bounds.width > 100 else { return }   // not laid out yet
        KeyboardLayoutMode.phoneLandscape = traitCollection.userInterfaceIdiom != .pad && view.bounds.width > 500
    }

    private func reloadKeyboardLayout() {
        updatePhoneLandscape()
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
        // The space bar: the language's name, or its code with "Language code" on.
        let spaceTitle = Prefs.spaceLanguageCode ? language.rawValue.uppercased() : language.displayName
        rows = rows.map { row in row.map { spec in
            guard spec.action == .space else { return spec }
            var titled = spec
            titled.title = spaceTitle
            return titled
        } }
        builtSplit = KeyboardLayoutMode.split
        if builtSplit == true { rows = LayoutBuilder.split(rows) }
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
        // Languages typed by sound have no word list of this kind: their dictionary is loaded on its own (PhoneticInput).
        var wanted: Set<Language> = []
        if language.usesPhoneticInput {
            PhoneticInput.shared(for: language).loadIfNeeded { [weak self] in self?.scheduleRefresh() }
        } else {
            loadStore(for: language, limit: nil)
            wanted.insert(language)
        }
        let others = Array(enabledLanguages.filter { $0 != language && !$0.usesPhoneticInput }.prefix(maxSecondaryStores))
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
        finishComposing()
        lastOtherLanguage = language
        Decoder.layoutFreshWords = 4
        language = target
        settings.languageCode = target.rawValue
        page = .letters
        clearSwipeState()
        ensureStores()
        returnTitle = ""
        updateReturnTitle()
        reloadKeyboardLayout()
        applyHeight()   // Thai's fourth row of letters
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
        guard Prefs.autoCapitalize, language.hasCapitals else { return false }
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
            return hadSpace && (last == "." || last == "!" || last == "?" || last == "\u{061F}")
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
        // Text selected with the trackpad is replaced by what is typed.
        deleteSelection()
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
        if language.usesPhoneticInput && textDocumentProxy.isSecureTextEntry != true {
            // Letters build up the spelling; anything else first turns all the letters so far into words.
            if page == .letters, text.count == 1, let letter = text.first, letter.isASCII, letter.isLetter {
                composing += text.lowercased()
                TypingStats.shared.keystroke()
                showComposing()
                return
            }
            // Japanese: the long-vowel mark (on the comma's long-press) belongs to the word being typed.
            if language == .japanese, text == "\u{30FC}", !composing.isEmpty {
                composing += "-"
                showComposing()
                return
            }
            while !composing.isEmpty { commitCandidate(phoneticCandidates.first) }
        }
        if language == .korean && textDocumentProxy.isSecureTextEntry != true {
            // Jamo build up the syllable being typed; anything else ends it.
            if text.count == 1, let jamo = text.first, HangulComposer.isJamo(jamo) {
                TypingStats.shared.keystroke()
                applyHangul(hangul.type(jamo))
                autoSpaceMarker = nil
                lastSpaceTime = Date.distantPast
                afterTyping()
                return
            }
            hangul.reset()
        }
        if language == .hindi, let independent = independentVowel(for: text) {
            output = independent
        }
        // The space added after a punctuation mark goes again when what comes next belongs right after the mark:
        // another mark, a closing bracket or quote, or the digits of "3.5" and "10:30".
        // (The proxy's text is read once: it changes a moment after an edit. `punctuationBefore` follows the edits.)
        var punctuationBefore = textDocumentProxy.documentContextBeforeInput ?? ""
        if let marker = punctuationSpaceMarker {
            punctuationSpaceMarker = nil
            let characters = Array(punctuationBefore)
            if text.count == 1, punctuationBefore.hasSuffix(marker), punctuationBefore.hasSuffix(" "), characters.count >= 2 {
                let mark = characters[characters.count - 2]
                let beforeMark: Character = characters.count >= 3 ? characters[characters.count - 3] : " "
                let closes = ".,!?;:)]}%\u{2026}\u{00BB}\u{201D}\u{060C}\u{061F}\u{061B}\u{0964}".contains(text)
                    // A quote closes one that is open ("hello." -> "hello.\"), else it opens the next one.
                    || (text == "\"" && insideQuote(String(punctuationBefore.dropLast())))
                let digitGoesOn = text.first?.isNumber == true && beforeMark.isNumber && ".,:".contains(mark)
                if closes || digitGoesOn {
                    textDocumentProxy.deleteBackward()
                    punctuationBefore.removeLast()
                    if autoSpaceMarker == marker { autoSpaceMarker = nil }
                }
            }
        }
        // Smart quotes: " and ' become the language's own quotation marks, opening or closing by what is before them.
        if text == "\"" || text == "'", let curly = smartQuote(for: text, before: punctuationBefore) {
            output = curly
        }
        // Punctuation that normally ends a word goes right after the word when the space in front of it was
        // added automatically (by a swipe or a picked suggestion) and nothing was typed since.
        if text.count == 1, ".,!?;:)]}\u{2026}\u{060C}\u{061F}\u{061B}".contains(text) {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            if let marker = autoSpaceMarker, !marker.isEmpty, before.hasSuffix(marker), before.hasSuffix(" "),
               let beforeSpace = before.dropLast().last, beforeSpace.isLetter || beforeSpace.isNumber {
                textDocumentProxy.deleteBackward()
            } else if autoCorrectAllowed, language != .french, ",.!?;".contains(text), Date().timeIntervalSince(lastSpaceTime) < 1.5,
                      before.hasSuffix(" "), !before.hasSuffix("  "),
                      let beforeSpace = before.dropLast().last, beforeSpace.isLetter || beforeSpace.isNumber {
                // A space typed a moment ago, then a full stop or comma: it belongs right after the word.
                textDocumentProxy.deleteBackward()
            }
        }
        autoSpaceMarker = nil
        // Punctuation right after a word finishes it too: it is learned like a word followed by space.
        if text.count == 1, let mark = text.first, !isWordCharacter(mark), !mark.isWhitespace, page == .letters {
            let before = textDocumentProxy.documentContextBeforeInput ?? ""
            if !currentPrefix(in: before).isEmpty {
                DispatchQueue.main.async { [weak self] in self?.learnWord(endingAt: before) }
            }
        }
        textDocumentProxy.insertText(output)
        TypingStats.shared.keystroke(characters: output.count)
        // A space after . , ! ? ; : (the Typing setting) when it ends a word at the end of the text.
        if shouldAddSpace(after: text, before: punctuationBefore) {
            textDocumentProxy.insertText(" ")
            let marker = String((punctuationBefore + output + " ").suffix(12))
            punctuationSpaceMarker = marker
            autoSpaceMarker = marker   // a space typed next is not doubled
        }
        lastSpaceTime = Date.distantPast
        afterTyping()
    }

    /// The fields where typing is not prose: web addresses, e-mail addresses, numbers and passwords.
    private var isPlainTextField: Bool {
        if textDocumentProxy.isSecureTextEntry == true { return true }
        let type = textDocumentProxy.keyboardType ?? .default
        return [.URL, .emailAddress, .numberPad, .phonePad, .decimalPad, .numbersAndPunctuation, .asciiCapableNumberPad,
                .namePhonePad].contains(type)
    }

    /// The language's curly quote for a typed " or ' (nil: the field or the setting wants it straight).
    private func smartQuote(for typed: String, before: String) -> String? {
        guard Prefs.smartQuotes, !isPlainTextField, textDocumentProxy.smartQuotesType != .no else { return nil }
        let previous = before.last
        // Opening at the start, after a space or an opening bracket or quote; closing after anything else.
        let opening = previous == nil || previous!.isWhitespace
            || "([{\u{201C}\u{2018}\u{201E}\u{201A}\u{00AB}\u{2039}\u{300C}\u{300E}-\u{2013}\u{2014}/".contains(previous!)
        if typed == "'" {
            // After a letter it is an apostrophe ("don't", "it's"): the closing single quote.
            if !opening { return "\u{2019}" }
            switch language {
            case .german, .czech, .slovak, .lithuanian, .bulgarian, .croatian, .hungarian, .polish, .romanian:
                return "\u{201A}"
            default:
                return "\u{2018}"
            }
        }
        guard let pair = quotePair() else { return nil }
        // Marks that are the same both ways (Swedish ”): the second of a pair closes.
        if pair.open == pair.close { return pair.open }
        return opening ? pair.open : pair.close
    }

    /// Whether the line ending `text` has a quotation open (more opening marks than closing ones).
    private func insideQuote(_ text: String) -> Bool {
        let line = text.split(separator: "\n", omittingEmptySubsequences: false).last ?? ""
        guard let pair = quotePair() else { return false }
        let straight = line.filter { $0 == "\"" }.count
        if pair.open == pair.close {
            return (line.filter { String($0) == pair.open }.count + straight) % 2 == 1
        }
        let opens = line.filter { String($0) == pair.open }.count
        let closes = line.filter { String($0) == pair.close }.count
        return opens > closes || straight % 2 == 1
    }

    /// The language's double quotation marks (opening, closing).
    private func quotePair() -> (open: String, close: String)? {
        let marks = language.quoteMarks
        if marks.count >= 2, language != .swedish, language != .finnish { return (marks[0], marks[1]) }
        if let only = marks.first { return (only, only) }
        return ("\u{201C}", "\u{201D}")
    }

    /// Whether a space goes after the mark just typed (the Space after punctuation setting): only at the end of the
    /// text, after a word or a number, and never where typing is not prose.
    private func shouldAddSpace(after text: String, before: String) -> Bool {
        guard Prefs.spaceAfterPunctuation, !isPlainTextField, !language.usesPhoneticInput, language != .thai,
              text.count == 1, ".,!?;:\u{060C}\u{061F}\u{061B}\u{0964}".contains(text) else { return false }
        guard let previous = before.last, previous.isLetter || previous.isNumber
                || "\u{201D}\u{2019}\u{00BB})]\"'".contains(previous) else { return false }
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        return after.isEmpty || after.hasPrefix("\n")
    }

    // MARK: Selecting with the trackpad

    /// The text selected with the trackpad, as it stands in the field.
    private func trackpadSelection() -> String? {
        guard let anchor = selectionAnchor, anchor != 0 else { return nil }
        if anchor > 0 {
            let after = textDocumentProxy.documentContextAfterInput ?? ""
            return String(after.prefix(anchor))
        }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        return String(before.suffix(-anchor))
    }

    /// The selected text: the trackpad's, or what the app itself has selected.
    private func currentSelection() -> String? {
        if let selected = trackpadSelection(), !selected.isEmpty { return selected }
        if let selected = textDocumentProxy.selectedText, !selected.isEmpty { return selected }
        return nil
    }

    /// The selected text for the bar: a few characters of the line around it, and the selection itself, shortened in
    /// the middle when it is long.
    private func selectionPreview(of selected: String) -> SelectionPreview {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let after = textDocumentProxy.documentContextAfterInput ?? ""
        var lead = before, trail = after
        if let anchor = selectionAnchor, anchor != 0 {
            // The trackpad's selection lies in the context the keyboard can see: cut it out of the text around it.
            if anchor > 0 { trail = String(after.dropFirst(anchor)) } else { lead = String(before.dropLast(-anchor)) }
        }
        func flat(_ text: String) -> String {
            return text.replacingOccurrences(of: "\n", with: " \u{21B5} ")
        }
        var leadShown = String(lead.split(separator: "\n", omittingEmptySubsequences: false).last ?? "")
        if leadShown.count > 8 { leadShown = "\u{2026}" + String(leadShown.suffix(8)) }
        var trailShown = String(trail.split(separator: "\n", omittingEmptySubsequences: false).first ?? "")
        if trailShown.count > 8 { trailShown = String(trailShown.prefix(8)) + "\u{2026}" }
        var middle = flat(selected)
        if middle.count > 28 { middle = String(middle.prefix(13)) + "\u{2026}" + String(middle.suffix(13)) }
        return SelectionPreview(lead: leadShown, selected: middle, trail: trailShown)
    }

    /// Deletes the text selected with the trackpad (true when there was some).
    @discardableResult
    private func deleteSelection() -> Bool {
        guard let anchor = selectionAnchor else { return false }
        selectionAnchor = nil
        selectingWithCursor = false
        guard anchor != 0 else { return false }
        if anchor > 0 { textDocumentProxy.adjustTextPosition(byCharacterOffset: anchor) }
        for _ in 0..<abs(anchor) { textDocumentProxy.deleteBackward() }
        return true
    }

    /// The selection bar's buttons: copy, cut and paste need Full Access (the pasteboard).
    private func selectionCommands() -> [Suggestion] {
        var names: [String] = []
        if hasFullAccess {
            names = ["copy", "cut"]
            if UIPasteboard.general.hasStrings { names.append("paste") }
        }
        names += ["case", "delete"]
        return names.prefix(SuggestionBar.capacity).map { Suggestion(text: $0, kind: .command) }
    }

    private func perform(command: String) {
        let selected = currentSelection() ?? ""
        let fromTrackpad = trackpadSelection() != nil
        switch command {
        case "copy":
            if !selected.isEmpty { UIPasteboard.general.string = selected }
            selectionAnchor = nil
        case "cut":
            if !selected.isEmpty { UIPasteboard.general.string = selected }
            if fromTrackpad { deleteSelection() } else { textDocumentProxy.deleteBackward() }
        case "paste":
            let pasted = UIPasteboard.general.string ?? ""
            if fromTrackpad { deleteSelection() }
            if !pasted.isEmpty { textDocumentProxy.insertText(pasted) }
        case "delete":
            if fromTrackpad { deleteSelection() } else { textDocumentProxy.deleteBackward() }
        case "case":
            guard !selected.isEmpty else { return }
            let next = nextCase(of: selected)
            if fromTrackpad { deleteSelection() }
            textDocumentProxy.insertText(next)
            // The new text stays selected, so the case can be changed again.
            selectionAnchor = -next.count
        default:
            break
        }
        selectingWithCursor = false
        clearSwipeState()
        lastSpaceTime = Date.distantPast
        refreshToolsSoon()
        scheduleRefresh()
    }

    /// UPPERCASE, then lowercase, then Capitalized, then round again.
    private func nextCase(of text: String) -> String {
        if text == text.uppercased() && text != text.lowercased() { return text.lowercased() }
        if text == text.lowercased() { return text.capitalized }
        return text.uppercased()
    }

    private func handleSpace() {
        hangul.reset()
        if deleteSelection() {
            textDocumentProxy.insertText(" ")
            afterTyping()
            return
        }
        let pendingMarker = autoSpaceMarker
        autoSpaceMarker = nil
        if isSearchingEmoji {
            if !searchQuery.isEmpty && !searchQuery.hasSuffix(" ") { searchQuery += " " }
            refreshEmojiSearch()
            return
        }
        punctuationSpaceMarker = nil
        if language.usesPhoneticInput {
            // Space writes the best word for the letters (no spaces between words); with nothing typed, a space.
            if !composing.isEmpty {
                commitCandidate(phoneticCandidates.first)
            } else {
                textDocumentProxy.insertText(" ")
                afterTyping()
            }
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
        if Prefs.doubleSpacePeriod, language.supports(.sentencePeriod),
           Date().timeIntervalSince(lastSpaceTime) < 0.4, before.hasSuffix(" "), before.count >= 2 {
            let characters = Array(before)
            let previous = characters[characters.count - 2]
            if previous.isLetter || previous.isNumber {
                clearSwipeState()
                textDocumentProxy.deleteBackward()
                textDocumentProxy.insertText(language.fullStop + " ")   // the language's own: "। " in Hindi
                lastSpaceTime = Date.distantPast
                afterTyping()
                return
            }
        }

        // A text shortcut ("omw" -> "On my way!") expands when space is pressed.
        if let phrase = shortcutExpansion(in: before) {
            TypingStats.shared.note(.shortcut)
            replacePrefix(with: phrase, length: shortcutLength(in: before))
            clearSwipeState()
            afterTyping()
            return
        }

        // Auto-correction: "vsgyok" + space -> "vagyok ", "koszonom" -> "köszönöm ", "dont" -> "don't ", in any enabled
        // language (see Decoder.autoCorrect). Backspace right after takes it back. Fields that ask for no
        // correction (addresses, codes) are left alone, and so are emoticons ("xD" is not a typo of "do").
        if autoCorrectAllowed && Emoticons.match(atEndOf: before) == nil {
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
                TypingStats.shared.word(language)
                TypingStats.shared.note(.autoCorrection)
                for _ in 0..<typedWord.count { textDocumentProxy.deleteBackward() }
                textDocumentProxy.insertText(replacement + " ")
                clearSwipeState()
                lastAutoFix = (typed: typedWord, inserted: replacement + " ")
                lastSpaceTime = Date()
                afterTyping()
                return   // (the word before stays as it is: this fix must stay takeable-back with backspace)
            }
        }

        // A word the user always writes with capitals ("Zsófi", "iOS") gets them without shift. Typed in capitals
        // on purpose, it stays as typed; backspace right after takes the change back.
        if autoCorrectAllowed, Emoticons.match(atEndOf: before) == nil {
            let typedWord = currentPrefix(in: before)
            let lower = TextFolding.normalizeApostrophes(typedWord).lowercased()
            if !typedWord.isEmpty, typedWord == typedWord.lowercased(), let form = LearnedWords.shared.forms[lower],
               form != typedWord, form.count == typedWord.count {
                TypingStats.shared.word(language)
                for _ in 0..<typedWord.count { textDocumentProxy.deleteBackward() }
                textDocumentProxy.insertText(form + " ")
                clearSwipeState()
                lastAutoFix = (typed: typedWord, inserted: form + " ")
                lastSpaceTime = Date()
                afterTyping()
                return
            }
        }

        clearSwipeState()
        if !currentPrefix(in: before).isEmpty { TypingStats.shared.word(language) }
        textDocumentProxy.insertText(" ")
        lastSpaceTime = Date()
        afterTyping()
        // Learning the finished word is not needed to show the space, so it runs right after.
        DispatchQueue.main.async { [weak self] in
            self?.learnWord(endingAt: before)
            self?.retroCorrectPrevious()
        }
    }

    /// Right after a space: the word before the one just finished is looked at again, now that the word after it is
    /// known (Decoder.retroCorrect). Each pair is looked at once; text edited in between is left alone.
    private var retroChecked = ""

    private func retroCorrectPrevious() {
        guard autoCorrectAllowed else { return }
        let text = textDocumentProxy.documentContextBeforeInput ?? ""
        guard text.hasSuffix(" "), !text.hasSuffix("  ") else { return }
        let words = Predictor.lastWords(in: text, count: 2)
        guard words.count == 2 else { return }
        let (previous, current) = (words[0], words[1])
        let tail = previous + " " + current + " "
        guard text.lowercased().hasSuffix(tail.lowercased()), previous.count >= 2 else { return }
        let head = String(text.dropLast(tail.count))
        guard head.isEmpty || head.hasSuffix(" ") || head.hasSuffix("\n") || head.last?.isPunctuation == true else { return }
        let key = head + "|" + previous + "|" + current
        guard key != retroChecked else { return }
        retroChecked = key
        // The written forms (capitals) of the two words as they stand in the field.
        let fullPrevious = String(text.dropLast(current.count + 2).suffix(previous.count))
        let fullCurrent = String(text.dropLast(1).suffix(current.count))
        let field = Predictor.fieldContext(before: head, after: textDocumentProxy.documentContextAfterInput ?? "")
        guard let fix = Decoder.retroCorrect(typed: fullPrevious, before: head, next: fullCurrent, active: language,
                                             enabled: enabledLanguages, stores: stores, field: field) else { return }
        for _ in 0..<tail.count { textDocumentProxy.deleteBackward() }
        textDocumentProxy.insertText(fix + " " + fullCurrent + " ")
        clearSwipeState()
        lastAutoFix = nil
        scheduleRefresh()
    }

    /// Auto-correction is on and the field accepts it (not passwords, addresses or codes).
    private var autoCorrectAllowed: Bool {
        return Prefs.suggestions && Prefs.autoCorrect && language.supports(.autoCorrect) && textDocumentProxy.isSecureTextEntry != true
            && textDocumentProxy.autocorrectionType != .no
            && ![UIKeyboardType.URL, .emailAddress].contains(textDocumentProxy.keyboardType ?? .default)
    }

    private func handleEnter() {
        hangul.reset()
        if isSearchingEmoji {
            // Enter picks the first match, like pressing search in the system keyboard.
            if let first = EmojiStore.shared.search(searchQuery, limit: 1).first {
                pickEmoji(EmojiStore.shared.toned(first, tone: Prefs.emojiSkinTone).base)
            }
            return
        }
        punctuationSpaceMarker = nil
        if deleteSelection() {
            textDocumentProxy.insertText("\n")
            afterTyping()
            return
        }
        if !composing.isEmpty {
            // Return keeps the letters as typed (for a name or an English word; the kana for Japanese), like the
            // system's keyboards.
            finishComposing()
            scheduleRefresh()
            return
        }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        var cursorBack = 0
        if let phrase = shortcutExpansion(in: before) {
            let typedLength = shortcutLength(in: before)
            let written = ShortcutTemplate.split(phrase)
            for _ in 0..<typedLength { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(written.text)
            cursorBack = written.cursorBack
            TypingStats.shared.note(.shortcut)
            TypingStats.shared.saved(written.text.count - typedLength, writing: written.text.count - typedLength)
        } else {
            if !currentPrefix(in: before).isEmpty { TypingStats.shared.word(language) }
            DispatchQueue.main.async { [weak self] in self?.learnWord(endingAt: before) }
        }
        clearSwipeState()
        textDocumentProxy.insertText("\n")
        if cursorBack > 0 { textDocumentProxy.adjustTextPosition(byCharacterOffset: -(cursorBack + 1)) }
        lastSpaceTime = Date.distantPast
        afterTyping()
    }

    private func handleBackspace() {
        if isSearchingEmoji {
            if !searchQuery.isEmpty { searchQuery.removeLast() }
            refreshEmojiSearch()
            return
        }
        punctuationSpaceMarker = nil
        TypingStats.shared.delete()
        if deleteSelection() {
            lastSpaceTime = Date.distantPast
            updateAutoShift()
            scheduleRefresh()
            return
        }
        if !composing.isEmpty {
            composing.removeLast()
            showComposing()
            return
        }
        // Korean: one jamo of the syllable being typed at a time.
        if let step = hangul.backspace() {
            applyHangul(step)
            scheduleRefresh()
            return
        }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        if let fix = lastAutoFix, before.hasSuffix(fix.inserted) {
            // Right after an auto-fix, backspace puts back what was typed, and that spelling is kept from now on.
            TypingStats.shared.note(.correctionUndone)
            for _ in 0..<fix.inserted.count { textDocumentProxy.deleteBackward() }
            textDocumentProxy.insertText(fix.typed)
            stores[language]?.learn(fix.typed, asTyped: true)
            // Taking back the capitals of a word the user writes with them: it is written as typed from now on.
            let lowerTyped = TextFolding.normalizeApostrophes(fix.typed).lowercased()
            if LearnedWords.shared.forms[lowerTyped] == fix.inserted.trimmingCharacters(in: .whitespaces) {
                LearnedWords.shared.setForm(nil, for: lowerTyped)
            }
            lastCommitted = nil   // the typed word was kept on purpose: no typo to learn here
            clearSwipeState()
        } else if Prefs.deleteSwipedWord, let inserted = lastSwipeInserted, before.hasSuffix(inserted) {
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

    /// Deletes one word to the left (sliding left from the backspace key) and returns what it took.
    @discardableResult
    private func deleteWordBackward() -> DeletedPiece? {
        hangul.reset()
        if isSearchingEmoji {
            guard !searchQuery.isEmpty else { return nil }
            let previous = searchQuery
            var characters = Array(searchQuery)
            while let last = characters.last, last == " " { characters.removeLast() }
            while let last = characters.last, last != " " { characters.removeLast() }
            searchQuery = String(characters)
            refreshEmojiSearch()
            return .search(previous)
        }
        if !composing.isEmpty {
            // The letters typed so far go all at once.
            let previous = composing
            composing = ""
            showComposing()
            return .composing(previous)
        }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        guard !before.isEmpty else { return nil }
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
        return .text(String(before.suffix(max(1, count))))
    }

    /// Puts back what a delete took away.
    private func restore(_ piece: DeletedPiece) {
        switch piece {
        case .search(let previous):
            searchQuery = previous
            refreshEmojiSearch()
            return
        case .composing(let previous):
            composing = previous
            showComposing()
        case .text(let text):
            textDocumentProxy.insertText(text)
            clearSwipeState()
        }
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
        noteWrittenForm(prefix, before: before)
        if prefix.count >= 3 { noteWordUse(prefix) }
        recordBigram(contextBefore: before, next: prefix)
    }

    /// Votes of a different way to write a dictionary word (word -> the form seen last), so one slip does not change it.
    private var formVotes: [String: String] = [:]

    /// Learns how the user writes `typed` (just finished, ending `before`): "Zsófi", "iOS", "london". A word the
    /// dictionaries lack takes the form at once (a name typed with a capital in mid-sentence is learned right
    /// away); a dictionary word needs the same different form twice in a row. The first word of a sentence says
    /// nothing about capitals (auto-capitalisation), unless it has capitals inside; ALL CAPS is shouting.
    private func noteWrittenForm(_ typed: String, before: String) {
        let lower = TextFolding.normalizeApostrophes(typed).lowercased()
        guard lower.count >= 2, lower.count <= 24, typed.count == lower.count,
              typed.contains(where: { $0.isLetter }), typed.allSatisfy({ Predictor.isWordCharacter($0) }),
              !WordStore.alwaysCapital.contains(lower) else { return }
        let normalized = TextFolding.normalizeApostrophes(typed)
        if normalized.count > 1 && normalized == normalized.uppercased() { return }
        var head = before
        let tail = currentPrefix(in: before)
        if !tail.isEmpty, head.hasSuffix(tail) { head = String(head.dropLast(tail.count)) }
        let inside = normalized.dropFirst().contains { $0.isUppercase }
        let atStart = Predictor.isSentenceStart(head)
        if atStart && !inside { return }

        let ordered = [language] + enabledLanguages.filter { $0 != language }
        let known = ordered.compactMap { stores[$0]?.isLoaded == true ? stores[$0]?.written(lower) : nil }.first
        let forms = LearnedWords.shared
        if normalized == (known ?? lower) {
            formVotes.removeValue(forKey: lower)
            forms.setForm(nil, for: lower)
        } else if known == nil {
            forms.setForm(normalized, for: lower)
            // A capitalised word in the middle of a sentence that no dictionary has is a name: learned at once.
            if !atStart, normalized.first?.isUppercase == true { learnTappedWord(normalized) }
        } else if formVotes[lower] == normalized {
            formVotes.removeValue(forKey: lower)
            forms.setForm(normalized, for: lower)
        } else {
            formVotes[lower] = normalized
        }
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
            // Saved as it goes: the keyboard can be closed by the system without a chance to save on the way out.
            usageNotes += 1
            if usageNotes % 8 == 0 { saveLanguageUsage() }
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
        let known = stores.values.contains { $0.isLoaded && $0.dictionaryContains(key: key) }
        if !known { stores[language]?.learn(cleaned) }
    }

    /// Tapping the word exactly as typed keeps it: a spelling that no enabled dictionary has is learned at once
    /// (and from then on suggested, and never corrected away). Only the exact spelling counts as known: a
    /// dictionary word with the same letters but other accents ("omaga" for "omágá") must not block it.
    private func learnTappedWord(_ word: String, pin: Bool = false) {
        guard Prefs.suggestions, !isSearchingEmoji, textDocumentProxy.isSecureTextEntry != true else { return }
        let cleaned = TextFolding.normalizeApostrophes(word)
        let key = TextFolding.key(cleaned)
        guard key.count >= 2, cleaned.allSatisfy({ Predictor.isWordCharacter($0) }) else { return }
        ensureStores()
        let known = stores.values.contains { $0.isLoaded && $0.dictionaryHas(word: cleaned) }
        if !known {
            stores[language]?.learn(cleaned, asTyped: true)
            if pin { LearnedWords.shared.pin(TextFolding.normalizeApostrophes(cleaned).lowercased()) }
        }
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

    /// The phrase of the shortcut typed before the cursor, its placeholders ({date}, {time}...) filled in; a
    /// {cursor} is still in it as `ShortcutTemplate.cursorMark`.
    /// The shortcut typed at the end of the text: its phrase and what was typed for it. A trigger may hold any
    /// characters ("@d"), so the whole last stretch without spaces is tried first, then the same without its first
    /// characters up to each symbol, then just the letters before the cursor.
    private func shortcutMatch(in before: String) -> (phrase: String, typed: String)? {
        var reversed: [Character] = []
        for character in before.reversed() {
            if character.isWhitespace { break }
            reversed.append(character)
        }
        let token = Array(reversed.reversed())
        var candidates: [String] = []
        for start in token.indices where start == 0 || !token[start].isLetter {
            candidates.append(String(token[start...]))
        }
        candidates.append(currentPrefix(in: before))
        for typed in candidates where !typed.isEmpty {
            if let phrase = settings.shortcutPhrase(for: typed) ?? systemShortcuts[typed.lowercased()] {
                return (phrase, typed)
            }
        }
        return nil
    }

    /// How many characters the shortcut typed at the end of the text takes up (the word before the cursor when
    /// there is none).
    private func shortcutLength(in before: String) -> Int {
        return shortcutMatch(in: before)?.typed.count ?? currentPrefix(in: before).count
    }

    private func shortcutExpansion(in before: String) -> String? {
        guard let phrase = shortcutMatch(in: before)?.phrase else { return nil }
        guard ShortcutTemplate.hasPlaceholders(phrase) else { return phrase }
        let access = hasFullAccess
        return ShortcutTemplate.expand(phrase, locale: Locale(identifier: language.localeIdentifier)) {
            access ? UIPasteboard.general.string : nil
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

    // MARK: Typed by sound (Jyutping, Pinyin, romaji)

    /// Shows the letters typed so far in the field, underlined (as kana for Japanese), and the words for them in
    /// the bar.
    private func showComposing() {
        let shown = PhoneticInput.shared(for: language).display(composing)
        let length = (shown as NSString).length
        textDocumentProxy.setMarkedText(shown, selectedRange: NSRange(location: length, length: 0))
        if composing.isEmpty { textDocumentProxy.unmarkText() }
        lastPickedWord = nil
        updatePhoneticCandidates()
        refreshSuggestions()
    }

    private func updatePhoneticCandidates() {
        phoneticCandidates = composing.isEmpty ? [] : PhoneticInput.shared(for: language).candidates(for: composing)
    }

    /// Writes `candidate` in place of the letters it stands for; the letters after them stay, for the next word.
    /// Without a candidate the letters are written as typed.
    private func commitCandidate(_ candidate: PhoneticInput.Candidate?) {
        // (A word must stand for at least one letter, or the loops that commit every letter would never end.)
        guard let candidate = candidate, candidate.length > 0 else {
            finishComposing()
            scheduleRefresh()
            return
        }
        let rest = String(composing.dropFirst(candidate.length))
        textDocumentProxy.setMarkedText(candidate.word, selectedRange: NSRange(location: (candidate.word as NSString).length, length: 0))
        textDocumentProxy.unmarkText()
        PhoneticInput.shared(for: language).learn(candidate)
        TypingStats.shared.word(language)
        composing = rest
        if !rest.isEmpty {
            showComposing()
        } else {
            phoneticCandidates = []
            lastPickedWord = candidate.word
            scheduleRefresh()
        }
    }

    /// Korean: replaces the syllable shown so far with what the composer made of it.
    private func applyHangul(_ step: (delete: Int, insert: String)) {
        for _ in 0..<step.delete { textDocumentProxy.deleteBackward() }
        if !step.insert.isEmpty { textDocumentProxy.insertText(step.insert) }
    }

    /// Hindi: a vowel sign typed where it has no consonant to sit on (at the start of a word, after a vowel) is
    /// the vowel itself: ा -> आ, ि -> इ, े -> ए ...; the virama there is अ.
    private func independentVowel(for text: String) -> String? {
        let independents: [String: String] = [
            "\u{093E}": "आ", "\u{093F}": "इ", "\u{0940}": "ई", "\u{0941}": "उ", "\u{0942}": "ऊ", "\u{0943}": "ऋ",
            "\u{0947}": "ए", "\u{0948}": "ऐ", "\u{094B}": "ओ", "\u{094C}": "औ", "\u{0949}": "ऑ", "\u{094D}": "अ"
        ]
        guard let independent = independents[text] else { return nil }
        guard let last = (textDocumentProxy.documentContextBeforeInput ?? "").unicodeScalars.last else { return independent }
        // Consonants (क ... ह, the nukta forms क़ ... य़) and the nukta itself carry a vowel sign.
        let carries = (0x0915...0x0939).contains(last.value) || (0x0958...0x095F).contains(last.value)
            || (0x0978...0x097F).contains(last.value) || last.value == 0x093C
        return carries ? nil : independent
    }

    /// Leaves the letters typed so far in the field as they are (switching language, hiding the keyboard).
    private func finishComposing() {
        hangul.reset()
        guard !composing.isEmpty else { return }
        if language == .japanese {
            // The kana as typed, a final "n" as ん.
            let kana = Romaji.finish(composing)
            textDocumentProxy.setMarkedText(kana, selectedRange: NSRange(location: (kana as NSString).length, length: 0))
        }
        textDocumentProxy.unmarkText()
        composing = ""
        phoneticCandidates = []
    }

    /// The bar while typing by sound: the words for the letters, best first (space writes it), or an emoji for
    /// the word just picked.
    private func refreshPhoneticSuggestions() {
        if composing.isEmpty {
            var shown: [Suggestion] = []
            if Prefs.emojiSuggestions, let word = lastPickedWord,
               let emoji = EmojiStore.shared.suggestions(for: word, languages: [language], limit: 1).first {
                shown = [Suggestion(text: emoji, kind: .emoji)]
            }
            suggestionBar.update(shown)
            return
        }
        if !PhoneticInput.shared(for: language).isLoaded { ensureStores() }
        var shown = phoneticCandidates.prefix(SuggestionBar.capacity).map { Suggestion(text: $0.word, kind: .word) }
        // No word for these letters (yet): offer them as typed.
        if shown.isEmpty { shown = [Suggestion(text: composing, kind: .literal)] }
        suggestionBar.update(shown, highlighted: phoneticCandidates.isEmpty ? nil : 0)
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
        DispatchQueue.main.asyncAfter(deadline: .now() + Prefs.suggestionDelay, execute: work)   // the Update speed setting
    }

    private func clearSwipeState() {
        lastSwipeInserted = nil
        swipeAlternatives = []
        lastAutoFix = nil
    }

    private func refreshSuggestions() {
        shownFix = nil
        if isSearchingEmoji { return }
        shownSmart = nil
        shownConversions = []
        shownEmojiPhrase = nil
        shownShortcut = nil
        // Selected text: the bar shows it, and offers what can be done with it.
        if composing.isEmpty, let selected = currentSelection() {
            suggestionBar.selectionPreview = selectionPreview(of: selected)
            suggestionBar.update(selectionCommands())
            return
        }
        suggestionBar.selectionPreview = nil
        // Chinese and Japanese need the bar to pick their words, whatever the suggestion settings say.
        if language.usesPhoneticInput && textDocumentProxy.isSecureTextEntry != true {
            if !composing.isEmpty && phoneticCandidates.isEmpty && PhoneticInput.shared(for: language).isLoaded { updatePhoneticCandidates() }
            refreshPhoneticSuggestions()
            return
        }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""

        if textDocumentProxy.isSecureTextEntry == true
            || (!Prefs.suggestions && !Prefs.emojiSuggestions && !Prefs.inlineMath && !Prefs.unitConversion) {
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
        let emojiLanguages = ([language] + enabledLanguages).reduce(into: [Language]()) { list, item in
            if !list.contains(item) { list.append(item) }
        }
        if Prefs.emojiSuggestions, let emoticon = Emoticons.match(atEndOf: before) {
            emojis = [emoticon.emoji]   // ":)" -> the emoji, in place of the word's
        } else if Prefs.emojiSuggestions, !emojiWord.isEmpty,
                  let phrase = EmojiStore.shared.phraseSuggestion(before: before, languages: emojiLanguages) {
            // A name of several words ("red heart", "thumbs up") wins over its last word's.
            emojis = [phrase.emoji]
            shownEmojiPhrase = phrase
        } else if Prefs.emojiSuggestions && !emojiWord.isEmpty {
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
        // "Fit more" and "Scrollable" bars show more than three words.
        let capacity = SuggestionBar.capacity
        if Prefs.suggestions && stores[language]?.isLoaded == true {
            if !prefix.isEmpty {
                let found = Predictor.suggestAndFix(typed: prefix,
                                                    before: before,
                                                    active: language,
                                                    enabled: enabledLanguages,
                                                    stores: stores,
                                                    limit: max(4, capacity),
                                                    field: field,
                                                    taps: currentTaps(for: prefix))
                words = found.words.map { Predictor.styled(matchCase(of: prefix, for: $0), field: field, allowLower: false) }
                if autoCorrectAllowed && Emoticons.match(atEndOf: before) == nil {
                    fix = found.fix
                    shownFix = (before, found.fix)
                }
            } else if before.isEmpty || before.hasSuffix(" ") {
                words = Predictor.nextWords(before: before,
                                            active: language,
                                            enabled: enabledLanguages,
                                            stores: stores,
                                            limit: capacity,
                                            field: field)
                    .map { applyShift(to: Predictor.styled($0, field: field)) }
            }
        }

        // A calculation ("12*3") or a measurement ("5 km") at the end of the text: its result in the bar.
        if !isPlainTextField || textDocumentProxy.keyboardType == .numbersAndPunctuation {
            let decimals = Prefs.resultDecimals
            if Prefs.inlineMath, let result = InlineCalculator.result(before: before, language: language, decimals: decimals) {
                shownSmart = (result, true)
            } else if Prefs.unitConversion {
                shownConversions = UnitConverter.results(before: before, language: language, decimals: decimals,
                                                         target: Prefs.unitTarget)
            }
        }
        if !shownConversions.isEmpty {
            // "30m": the bar is every way of writing it, scrolling along.
            suggestionBar.update(shownConversions.map { Suggestion(text: $0.shown, kind: .result) }, showAll: true)
            return
        }
        if let smart = shownSmart, smart.isCalculation {
            // "3+4=": the answer alone, in the middle.
            suggestionBar.update([Suggestion(text: "", kind: .word), Suggestion(text: "=" + smart.result.shown, kind: .result)])
            return
        }

        // Layout is [left, CENTRE, right]; the most probable word sits in the centre (as on iOS).
        var ranked: [String] = []
        let expanded = shortcutExpansion(in: before)
        let phrase = expanded.map { ShortcutTemplate.split($0).text }
        if let expanded = expanded, let phrase = phrase {
            ranked.append(phrase)
            shownShortcut = (expanded, phrase)
        }
        for word in words where word != prefix && !ranked.contains(word) { ranked.append(word) }
        var result: [Suggestion] = []
        var highlighted: Int? = nil
        if !prefix.isEmpty || phrase != nil {
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
            result.append(Suggestion(text: prefix, kind: .literal))
            result.append(Suggestion(text: best ?? "", kind: .word))
            if let emoji = emojis.first {
                result.append(Suggestion(text: emoji, kind: .emoji))
            }
            // The runners-up after them, as many as the bar shows.
            for word in ranked.dropFirst() where result.count < capacity {
                result.append(Suggestion(text: word, kind: .word))
            }
        } else {
            // Next words: the likeliest in the middle, then the others.
            let top = Array(ranked.prefix(capacity))
            if top.count >= 2 {
                result = [Suggestion(text: top[1], kind: .word), Suggestion(text: top[0], kind: .word)]
                result += top.dropFirst(2).map { Suggestion(text: $0, kind: .word) }
            } else if top.count == 1 {
                result = [Suggestion(text: "", kind: .word), Suggestion(text: top[0], kind: .word)]
            }
            if let emoji = emojis.first {
                // The emoji takes the right-hand slot of the three.
                while result.count < 2 { result.append(Suggestion(text: "", kind: .word)) }
                result.insert(Suggestion(text: emoji, kind: .emoji), at: 2)
                if result.count > capacity { result.removeLast() }
            }
        }
        // A conversion ("5 km" -> miles) takes the right-hand slot, before an emoji.
        if let smart = shownSmart {
            while result.count < 2 { result.append(Suggestion(text: "", kind: .word)) }
            result.removeAll { $0.kind == .emoji }
            result.insert(Suggestion(text: smart.isCalculation ? "=" + smart.result.shown : smart.result.shown, kind: .result),
                          at: min(2, result.count))
            while result.count > capacity { result.removeLast() }
        }
        suggestionBar.update(result, highlighted: highlighted)
    }

    /// Writes `replacement` and a space in place of the word being typed. A shortcut's {cursor} puts the cursor there.
    /// `length`: how many characters to take out (a shortcut's trigger can hold symbols); the word before the cursor
    /// by default.
    private func replacePrefix(with replacement: String, length: Int? = nil) {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let removed = length ?? currentPrefix(in: before).count
        let written = ShortcutTemplate.split(replacement)
        recordBigram(contextBefore: before, next: written.text)
        noteWordUse(written.text)
        TypingStats.shared.word(language)
        TypingStats.shared.saved(written.text.count - removed, writing: written.text.count - removed)
        for _ in 0..<removed { textDocumentProxy.deleteBackward() }
        let space = Prefs.spaceAfterSuggestion ? " " : ""
        textDocumentProxy.insertText(written.text + space)
        lastSpaceTime = Date()
        if written.cursorBack > 0 {
            if !space.isEmpty { textDocumentProxy.adjustTextPosition(byCharacterOffset: -(written.cursorBack + 1)) }
            else { textDocumentProxy.adjustTextPosition(byCharacterOffset: -written.cursorBack) }
            autoSpaceMarker = nil
        } else {
            autoSpaceMarker = space.isEmpty ? nil : String((String(before.dropLast(removed)) + written.text + space).suffix(12))
        }
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
        deleteSelection()
        textDocumentProxy.insertText(leadingSpace + inserted)
        autoSpaceMarker = String((before + leadingSpace + inserted).suffix(12))
        punctuationSpaceMarker = nil
        TypingStats.shared.word(language)
        TypingStats.shared.note(.swipe)
        TypingStats.shared.saved(word.count - 1, writing: word.count)

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
        textDocumentProxy.insertText(Prefs.emojiSpaceAfter ? emoji + " " : emoji)
        settings.rememberEmoji(emoji)
        lastSpaceTime = Date.distantPast
        clearSwipeState()
    }

    private func showEmojiPanel() {
        guard emojiPanel == nil else { return }
        finishComposing()
        Prefs.refresh()   // the Emoji screen's settings, which do not rebuild the keyboard
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
        // Everything is set for the search before the picker goes, so the keyboard never shows (or changes its
        // height) in between.
        isSearchingEmoji = true
        searchQuery = ""
        page = .letters
        shift = .off
        suggestionBar.isHidden = true
        searchBar.isHidden = false
        reloadKeyboardLayout()
        hideEmojiPanel(refresh: false)
        refreshEmojiSearch()
        EmojiStore.shared.loadSearchIfNeeded(languages: enabledLanguages + [.english]) { [weak self] in
            self?.refreshEmojiSearch()
        }
    }

    private func endEmojiSearch(returnToPicker: Bool) {
        isSearchingEmoji = false
        searchQuery = ""
        searchBar.isHidden = true
        suggestionBar.isHidden = false
        // The search left the emoji key out: put it back.
        reloadKeyboardLayout()
        updateAutoShift()
        if returnToPicker {
            // (The picker sets the height itself, so the keyboard does not shrink and grow in between.)
            showEmojiPanel()
        } else {
            applyHeight()
            scheduleRefresh()
        }
    }

    private func refreshEmojiSearch() {
        let placeholder = language.strings.searchEmoji
        searchBar.setQuery(searchQuery, placeholder: placeholder)
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            // Recent ones as they were picked (each still offers its other skin tones when held).
            searchBar.setResults(settings.orderedRecentEmoji().map { EmojiStore.shared.toned($0, tone: 0) })
        } else {
            // In the skin tone chosen in the app, like the picker.
            let tone = Prefs.emojiSkinTone
            searchBar.setResults(EmojiStore.shared.search(searchQuery, limit: 60).map { EmojiStore.shared.toned($0, tone: tone) })
        }
    }

    // MARK: Panels
}

// MARK: - KeyboardViewDelegate

extension KeyboardViewController: KeyboardViewDelegate {
    func keyboardView(_ view: KeyboardView, didTap action: KeyAction) {
        // A key tapped while a swipe is still being decoded (two thumbs, space commits) comes after its word, with
        // the place it was tapped (the view's last tap point has moved on by then).
        if swipesDecoding > 0 {
            queuedActions.append((action, view.lastTapPoint))
            return
        }
        handleTap(action, at: view.lastTapPoint)
    }

    private func handleTap(_ action: KeyAction, at point: CGPoint?) {
        if action != .backspace { lastAutoFix = nil }   // an auto-fix can only be undone by the very next key
        switch action {
        case .character(let text):
            insert(text)
            noteTap(text, at: point)
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
        case .showMoreSymbols:
            page = .moreSymbols
            reloadKeyboardLayout()
        case .emoji:
            Prefs.refresh()   // the Emoji screen's choice does not rebuild the keyboard
            if Prefs.emojiNative && !isSearchingEmoji {
                // The system's emoji keyboard is the next keyboard (iOS has no call that opens it directly).
                advanceToNextInputMode()
            } else if isSearchingEmoji {
                endEmojiSearch(returnToPicker: true)
            } else {
                showEmojiPanel()
            }
        case .spacer: break
        }
    }

    func keyboardView(_ view: KeyboardView, didSelectAlternate text: String) {
        insert(text)
    }

    func keyboardView(_ view: KeyboardView, didMoveCursorBy offset: Int) {
        guard offset != 0, !isSearchingEmoji else { return }
        finishComposing()
        // In right-to-left text, sliding right goes back towards the start of the text.
        var move = language.isRightToLeft ? -offset : offset
        if selectingWithCursor {
            // The selection only grows over text the keyboard can see, so it always knows what is selected.
            if move < 0 {
                move = max(move, -(textDocumentProxy.documentContextBeforeInput ?? "").count)
            } else {
                move = min(move, (textDocumentProxy.documentContextAfterInput ?? "").count)
            }
            guard move != 0 else { return }
            selectionAnchor = (selectionAnchor ?? 0) - move
        } else {
            selectionAnchor = nil
        }
        textDocumentProxy.adjustTextPosition(byCharacterOffset: move)
        if Prefs.cursorTickHaptic { Haptics.shared.tick() }
        clearSwipeState()
        lastSpaceTime = Date.distantPast
        scheduleRefresh()
    }

    func keyboardViewDidBeginWordDelete(_ view: KeyboardView) {
        wordDeleteStack = []
        deleteSelection()
    }

    func keyboardViewDidBeginCursorMode(_ view: KeyboardView) {
        // A new trip of the cursor: what was selected before is let go.
        selectingWithCursor = false
        if selectionAnchor != nil {
            selectionAnchor = nil
            scheduleRefresh()
        }
    }

    func keyboardViewDidBeginSelecting(_ view: KeyboardView) {
        finishComposing()
        selectingWithCursor = true
        selectionAnchor = 0
    }

    func keyboardViewDidEndCursorMode(_ view: KeyboardView) {
        selectingWithCursor = false
        if selectionAnchor == 0 { selectionAnchor = nil }
        scheduleRefresh()
    }

    func keyboardViewDidRequestDeleteWord(_ view: KeyboardView) {
        wordDeleteStack.append(deleteWordBackward())
    }

    func keyboardViewDidRequestRestoreWord(_ view: KeyboardView) {
        guard let last = wordDeleteStack.popLast() else { return }
        if let piece = last { restore(piece) }
    }

    func keyboardViewDidEndWordDelete(_ view: KeyboardView) {
        wordDeleteStack = []
    }

    func keyboardView(_ view: KeyboardView, didSwipeSpaceBy direction: Int) {
        switchLanguage(by: direction)
    }

    func keyboardViewDidHoldEmoji(_ view: KeyboardView) {
        openApp()
    }

    /// Opens Iramo's settings app (the `iramo://` scheme in project.yml). Extensions cannot call
    /// `UIApplication.open`, so it is reached through the responder chain and called by selector.
    private func openApp() {
        guard let url = URL(string: "iramo://") else { return }
        var responder: UIResponder? = self
        while let current = responder {
            if current is UIApplication {
                let selector = NSSelectorFromString("openURL:options:completionHandler:")
                guard current.responds(to: selector) else { return }
                typealias Open = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, Any?) -> Void
                let open = unsafeBitCast(current.method(for: selector), to: Open.self)
                open(current, selector, url as NSURL, NSDictionary(), nil)
                return
            }
            responder = current.next
        }
    }

    func keyboardView(_ view: KeyboardView, didUpdateSwipe path: [CGPoint]) {
        guard !isSearchingEmoji, textDocumentProxy.isSecureTextEntry != true else { return }
        if liveSwipe == nil { liveSwipe = makeSwipeContext() }
        guard liveSwipe != nil else { return }
        // Handed to the decoder only once the delay has passed (a decode that is still busy picks it up after).
        liveSwipeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.pendingSwipePath = path
            self?.decodeLiveSwipe()
        }
        liveSwipeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Prefs.suggestionDelay, execute: work)
    }

    func keyboardView(_ view: KeyboardView, didFinishSwipe path: [CGPoint]) {
        // Live previews still running belong to this swipe; their results are dropped.
        liveSwipeWork?.cancel()
        swipeGeneration += 1
        let context = liveSwipe ?? makeSwipeContext()
        liveSwipe = nil
        pendingSwipePath = nil
        guard let swipe = context else { return }
        let decoder = self.decoder
        swipesDecoding += 1
        let multiWord = Prefs.multiWordSwipe && !isSearchingEmoji
        swipeQueue.async { [weak self] in
            var words = decoder.decode(path: path, keyCenters: swipe.centers, keySize: swipe.keySize, sources: swipe.sources)
            // Multi-word glides: a phrase that fits clearly better goes first, the single words stay as alternatives.
            if multiWord {
                let phrases = decoder.decodePhrase(path: path, keyCenters: swipe.centers, keySize: swipe.keySize,
                                                   sources: swipe.sources)
                if let best = phrases.first { words = [best] + words.filter { $0 != best } }
            }
            DispatchQueue.main.async {
                guard let self = self else { return }
                if words.isEmpty { self.scheduleRefresh() }   // no word: drop the live preview
                self.commitSwipe(words)
                self.swipesDecoding -= 1
                if self.swipesDecoding == 0 && !self.queuedActions.isEmpty {
                    let queued = self.queuedActions
                    self.queuedActions = []
                    for item in queued { self.handleTap(item.action, at: item.point) }
                }
            }
        }
    }

    func keyboardViewCanSwipe(_ view: KeyboardView) -> Bool {
        guard textDocumentProxy.isSecureTextEntry != true else { return false }
        return stores[language]?.isLoaded == true
    }

    func keyboardViewDidCancelSwipe(_ view: KeyboardView) {
        liveSwipeWork?.cancel()
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
        guard language.supportsSwipe, let store = stores[language], store.isLoaded else { return nil }
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
        hangul.reset()
        if language.usesPhoneticInput && !composing.isEmpty {
            if suggestion.kind == .literal {
                finishComposing()
                scheduleRefresh()
            } else if let candidate = phoneticCandidates.first(where: { $0.word == suggestion.text }) {
                commitCandidate(candidate)
            }
            return
        }
        if language.usesPhoneticInput && suggestion.kind == .emoji {
            // The emoji goes after the picked word (the word is not replaced by its emoji).
            textDocumentProxy.insertText(suggestion.text)
            settings.rememberEmoji(suggestion.text)
            lastPickedWord = nil
            scheduleRefresh()
            return
        }
        switch suggestion.kind {
        case .command:
            perform(command: suggestion.text)
        case .result:
            var picked: (result: SmartResult, isCalculation: Bool)?
            if let smart = shownSmart, smart.result.shown == suggestion.text || "=" + smart.result.shown == suggestion.text {
                picked = smart
            } else if let conversion = shownConversions.first(where: { $0.shown == suggestion.text }) {
                picked = (conversion, false)
            }
            guard let smart = picked else { return }
            for _ in 0..<smart.result.replaceCount { textDocumentProxy.deleteBackward() }
            var inserted = smart.result.insert
            let wantsSpace = smart.isCalculation ? Prefs.spaceAfterResult : Prefs.spaceAfterConversion
            if wantsSpace && !inserted.hasSuffix(" ") { inserted += " " }
            textDocumentProxy.insertText(inserted)
            TypingStats.shared.note(smart.isCalculation ? .calculation : .conversion)
            shownSmart = nil
            shownConversions = []
            lastSpaceTime = Date.distantPast
            clearSwipeState()
            afterTyping()
        case .literal, .word:
            guard !suggestion.text.isEmpty else { return }
            if suggestion.kind == .literal { learnTappedWord(suggestion.text, pin: true) }
            if let shortcut = shownShortcut, shortcut.shown == suggestion.text {
                // A shortcut picked in the bar: its filled-in phrase, with the cursor where {cursor} is.
                TypingStats.shared.note(.shortcut)
                replacePrefix(with: shortcut.expanded,
                              length: shortcutLength(in: textDocumentProxy.documentContextBeforeInput ?? ""))
            } else {
                // A learned word picked in the bar is kept for good and ranked first from now on.
                LearnedWords.shared.pin(TextFolding.normalizeApostrophes(suggestion.text).lowercased())
                TypingStats.shared.note(.suggestion)
                replacePrefix(with: suggestion.text)
            }
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
            if let emoticon = Emoticons.match(atEndOf: before), emoticon.emoji == suggestion.text {
                replaced = emoticon.length   // ":)" or ":) " becomes the emoji
            } else if let phrase = shownEmojiPhrase, phrase.emoji == suggestion.text, before.count >= phrase.length {
                replaced = phrase.length     // "red heart" becomes the heart
            } else if !typing.isEmpty {
                replaced = typing.count
            } else if before.hasSuffix(" ") {
                let finished = currentPrefix(in: String(before.dropLast()))
                if !finished.isEmpty { replaced = finished.count + 1 }
            }
            for _ in 0..<replaced { textDocumentProxy.deleteBackward() }
            let needsSpace = replaced == 0 && (before.last?.isWhitespace == false)
            textDocumentProxy.insertText((needsSpace ? " " : "") + suggestion.text + (Prefs.spaceAfterEmoji ? " " : ""))
            settings.rememberEmoji(suggestion.text)
            TypingStats.shared.note(.emoji)
            lastSpaceTime = Date.distantPast
            clearSwipeState()
            afterTyping()
        }
    }

    func suggestionBarDidTapDismiss(_ bar: SuggestionBar) {
        dismissKeyboard()
    }

    func suggestionBarDidTapTools(_ bar: SuggestionBar) {
        if toolsPanel == nil {
            showTools()
        } else {
            hideTools()
        }
    }
}

// MARK: - Functions panel

extension KeyboardViewController: ToolsPanelDelegate {
    /// The tools the app's Functions screen picked (split only on an iPad), in the suggestion bar in place of the
    /// suggestions; the keys stay where they are.
    private func showTools() {
        guard toolsPanel == nil else { return }
        finishComposing()
        let tools = availableTools()
        let panel = ToolsPanel(tools: tools)
        panel.toolsDelegate = self
        toolsPanel = panel
        panel.refresh()   // before it slides in, so the dimmed ones animate to their dimmed alpha
        suggestionBar.setTools(panel)
    }

    /// The picked tools (split shows everywhere; an iPhone splits only in landscape).
    func availableTools() -> [KeyboardTool] {
        return settings.keyboardTools
    }

    private func hideTools() {
        toolsPanel = nil
        suggestionBar.setTools(nil)
    }

    /// Saves a setting changed from the panel. A change to the keys' layout rebuilds the keyboard (the panel
    /// opens again over it); the others take effect at once.
    private func saveTool(_ value: Any, forKey key: String, rebuild: Bool) {
        settings.set(value, forKey: key)
        Prefs.refresh()
        if rebuild {
            buildInterface()
            showTools()
        } else {
            builtSignature = settingsSignature()
            toolsPanel?.refresh()
        }
    }

    /// The text proxy updates a moment after an edit, so the tiles (greyed without a selection) read it a beat later.
    private func refreshToolsSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in self?.toolsPanel?.refresh() }
    }

    func toolsPanel(_ panel: ToolsPanel, didPick tool: KeyboardTool) {
        switch tool {
        case .oneHanded:
            // On or off; the arrow beside the keys switches sides, and the side last used comes back.
            let sideKey = "oneHandedLastSide"
            let next: String
            if Prefs.oneHanded == "off" {
                next = SharedStore.defaults.string(forKey: sideKey) ?? "right"
            } else {
                SharedStore.defaults.set(Prefs.oneHanded, forKey: sideKey)
                next = "off"
            }
            saveTool(next, forKey: SettingKey.oneHanded, rebuild: false)
            keyboardView.setNeedsLayout()
        case .numberRow:
            saveTool(!Prefs.numberRow, forKey: SettingKey.numberRow, rebuild: true)
        case .split:
            // Only the keys are laid out again: the suggestion bar stays as it is. (An iPhone splits only in
            // landscape; upright the setting is just kept for when it turns.)
            settings.set(!Prefs.splitKeyboard, forKey: SettingKey.splitKeyboard)
            Prefs.refresh()
            reloadKeyboardLayout()
            keyboardView.setNeedsLayout()
            builtSignature = settingsSignature()
            toolsPanel?.refresh()
        case .lineStart:
            selectionAnchor = nil
            let line = (textDocumentProxy.documentContextBeforeInput ?? "").split(separator: "\n", omittingEmptySubsequences: false).last ?? ""
            textDocumentProxy.adjustTextPosition(byCharacterOffset: -line.count)
            refreshToolsSoon()
            scheduleRefresh()
        case .lineEnd:
            selectionAnchor = nil
            let line = (textDocumentProxy.documentContextAfterInput ?? "").split(separator: "\n", omittingEmptySubsequences: false).first ?? ""
            textDocumentProxy.adjustTextPosition(byCharacterOffset: line.count)
            refreshToolsSoon()
            scheduleRefresh()
        }
    }

    func toolsPanel(_ panel: ToolsPanel, stateOf tool: KeyboardTool) -> Bool? {
        switch tool {
        case .oneHanded: return Prefs.oneHanded != "off"
        case .numberRow: return Prefs.numberRow
        case .split: return Prefs.splitKeyboard
        default: return nil
        }
    }

    func toolsPanel(_ panel: ToolsPanel, detailOf tool: KeyboardTool) -> String? {
        return nil
    }

    func toolsPanel(_ panel: ToolsPanel, isAvailable tool: KeyboardTool) -> Bool {
        return true
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

    func emojiPanelDidTapHide(_ panel: EmojiPanel) {
        hideEmojiPanel(refresh: false)
        dismissKeyboard()
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

    func emojiSearchBarDidTapHide(_ bar: EmojiSearchBar) {
        endEmojiSearch(returnToPicker: false)
        dismissKeyboard()
    }
}

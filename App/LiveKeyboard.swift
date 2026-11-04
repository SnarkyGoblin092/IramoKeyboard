import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// The keyboard itself, pinned above the settings screens: Keyboard/SuggestionBar, Keyboard/KeyboardView and its
/// KeyViews, built from the same settings and played by the same code as while typing, so the keys, the bar, the
/// effects, the haptics and the gestures look and feel as they do there. The emoji key opens no picker and the keys
/// write nothing: the bar always shows the same few words, so its look can be seen. Shift and the number and symbol
/// pages work, so every key can be tried. Laid out at the keyboard's real size and shrunk to fit the pane.
struct LiveKeyboard: View {
    /// The Effects screen's settings as they are being edited (nil: the stored ones).
    var effects: EffectsConfig? = nil
    /// The Hitboxes screen: the touch areas drawn over the keys (HitboxOverlay), and the letters typed on the
    /// preview drive adaptive keys as they do while typing.
    var showsHitboxes = false
    /// What the Hitboxes preview draws over the keys: the touch areas or the hit map.
    var hitboxMode: HitboxOverlay.Mode = .hitboxes
    /// The Emoji screen: the keyboard as it is with its emoji picker open (nothing in it leaves the picker).
    var showsEmoji = false
    @Environment(\.colorScheme) private var scheme

    // Its proportions (LiveKeyboardView.naturalSize): read here so a change redraws it at once.
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.rowGap, store: SharedStore.defaults) private var rowGap = SettingDefault.rowGap
    @AppStorage(SettingKey.numberRow, store: SharedStore.defaults) private var numberRow = SettingDefault.numberRow
    @AppStorage(SettingKey.suggestionHeight, store: SharedStore.defaults) private var barHeight = SettingDefault.suggestionHeight
    @AppStorage(SettingKey.language, store: SharedStore.defaults) private var languageCode = SettingDefault.language

    var body: some View {
        GeometryReader { geometry in
            let size = LiveKeyboardView.naturalSize(keyHeight: keyHeight, rowGap: rowGap, numberRow: numberRow,
                                                    barHeight: barHeight,
                                                    language: LiveKeyboardView.openingLanguage(code: languageCode),
                                                    emoji: showsEmoji)
            let scale = min(geometry.size.width / size.width, geometry.size.height / size.height)
            CurrentThemeLook { look in
                LiveKeyboardHost(effects: effects, showsHitboxes: showsHitboxes, hitboxMode: hitboxMode,
                                 showsEmoji: showsEmoji)
                    // A transparent backdrop shows only the keys, over whatever the screen has behind them. The emoji
                    // picker shows the system's own backdrop (as it does in the keyboard).
                    .background(Group {
                        if showsEmoji {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(scheme == .dark ? Color(white: 0.17) : Color(red: 0.82, green: 0.84, blue: 0.86))
                                .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                        } else {
                            look.backdrop(scale: scale)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                    })
                    .clipShape(RoundedRectangle(cornerRadius: showsEmoji ? 14 : 0, style: .continuous))
            }
            .frame(width: size.width * scale, height: size.height * scale)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minHeight: 60)
    }
}

private struct LiveKeyboardHost: UIViewRepresentable {
    let effects: EffectsConfig?
    let showsHitboxes: Bool
    let hitboxMode: HitboxOverlay.Mode
    let showsEmoji: Bool

    func makeUIView(context: Context) -> LiveKeyboardView {
        let view = LiveKeyboardView()
        view.showsEmoji = showsEmoji
        view.effectsOverride = effects
        view.showsHitboxes = showsHitboxes
        view.hitboxMode = hitboxMode
        return view
    }

    func updateUIView(_ view: LiveKeyboardView, context: Context) {
        // Read by the keys at every press (KeyView.syncEffects), so a change shows on the next one.
        view.effectsOverride = effects
        view.showsHitboxes = showsHitboxes
        view.hitboxMode = hitboxMode
    }
}

/// Holds the suggestion bar and the KeyboardView at the keyboard's size in `stage`, shrunk to fit, and stands in for
/// the keyboard's controller: it builds them (as KeyboardViewController.buildInterface and reloadKeyboardLayout),
/// handles shift and the pages, fills the bar with a few fixed words, and builds everything again when a setting
/// that changes their look is edited (as the controller's settingsSignature).
final class LiveKeyboardView: UIView, KeyboardViewDelegate, SuggestionBarDelegate, EmojiPanelDelegate {
    /// The keyboard's points; scaled to the view. Popups are added here too, so they are drawn at the same scale.
    private let stage = UIView()
    private var bar = SuggestionBar()
    private var keyboard = KeyboardView()
    private var language: Language = .english
    private var page: KeyboardPage = .letters
    private var shift: ShiftState = .off
    private var lastShiftTap = Date.distantPast
    private var builtSignature = ""
    private var refreshQueued = false
    private var builtStyle: UIUserInterfaceStyle = .unspecified

    /// The Effects screen's settings while they are edited; nil plays the stored ones.
    var effectsOverride: EffectsConfig? {
        didSet { applyEffects() }
    }

    /// The Hitboxes screen's preview (LiveKeyboard.showsHitboxes).
    var showsHitboxes = false {
        didSet { if showsHitboxes != oldValue { updateHitboxes() } }
    }
    /// What the overlay draws (LiveKeyboard.hitboxMode).
    var hitboxMode: HitboxOverlay.Mode {
        get { return hitboxOverlay.mode }
        set { hitboxOverlay.mode = newValue }
    }
    private let hitboxOverlay = HitboxOverlay()
    /// The Emoji screen's preview: the emoji picker open in place of the bar and the keys (LiveKeyboard.showsEmoji).
    var showsEmoji = false {
        didSet { if showsEmoji != oldValue { rebuild() } }
    }
    private var emojiPanel: EmojiPanel?
    /// The word typed on the preview so far (the Hitboxes screen), which adaptive keys follow.
    private var typed = ""
    /// The dictionaries adaptive keys read, loaded once for every preview.
    private static var stores: [Language: WordStore] = [:]
    private static var loadingStores = Set<Language>()

    /// The keyboard's size (KeyboardViewController.applyHeight, upright): the screen's width, and the bar above its
    /// rows of keys with the gap between them.
    /// With `emoji` (the picker open) it is as tall as the picker needs, at least (KeyboardViewController.applyHeight).
    static func naturalSize(keyHeight: Double, rowGap: Double, numberRow: Bool, barHeight: Double,
                            language: Language, emoji: Bool = false) -> CGSize {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let height = CGFloat(keyHeight) * (isPad ? 61 / 45 : 1)
        let rows = CGFloat(language.letterRows.count + 1 + (numberRow ? 1 : 0))
        let width = CGFloat(DeviceMetrics.portraitWidth)
        let total = CGFloat(barHeight) + 8 + rows * (height + CGFloat(rowGap))
        // With the picker open: the size the keyboard really had then, once it has been opened on this phone.
        if emoji {
            let parts = (SharedStore.defaults.string(forKey: SettingKey.lastEmojiSize) ?? "")
                .split(separator: ",").compactMap { Double($0) }
            if parts.count == 2, parts[0] > 100, parts[1] > 100 { return CGSize(width: parts[0], height: parts[1]) }
        }
        return CGSize(width: width, height: emoji ? max(total, EmojiPanel.requiredHeight(forWidth: width)) : total)
    }

    /// The language the keyboard opens in: the stored one if it is enabled, else the first enabled one.
    static func openingLanguage(code: String) -> Language {
        let enabled = Language.list(from: Settings.shared.enabledLanguages)
        let stored = Language(rawValue: code) ?? .english
        return enabled.contains(stored) ? stored : (enabled.first ?? stored)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        stage.backgroundColor = .clear
        stage.isMultipleTouchEnabled = true
        addSubview(stage)
        addGestureRecognizer(BackSwipeBlocker(target: nil, action: nil))
        Haptics.shared.hasFullAccess = true   // the app may always play the key-tap sound
        Haptics.shared.prepare()
        NotificationCenter.default.addObserver(self, selector: #selector(settingsChanged),
                                               name: UserDefaults.didChangeNotification, object: nil)
        rebuild()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Building

    /// The settings that change how the bar and the keys are built (the controller's settingsSignature, less the
    /// effects', which the keys read as they play).
    private func signature() -> String {
        let s = Settings.shared
        return [
            Theme.storedID(), s.accentName, SharedStore.defaults.string(forKey: SettingKey.accentHex) ?? "",
            "\(s.numberRow)", "\(s.keyHints)", "\(s.keyPopups)", "\(Prefs.keyRoundness)", s.keySurface, s.keyBorderStyle,
            s.keyGlow, s.keyFont, s.enabledLanguages.joined(separator: ","), s.languageCode,
            "\(s.keyHeight)", "\(s.keyboardWidth)", "\(s.keyGap)", "\(s.rowGap)", "\(s.alwaysCapitals)", "\(s.letterSize)",
            s.hintPosition, "\(s.hintSize)", "\(s.spaceTextSize)", "\(s.spaceLanguageCode)", "\(s.splitKeyboard)", s.oneHanded,
            s.suggestionStyle, s.separatorStyle, "\(s.suggestionFollowTheme)", "\(s.suggestionHeight)",
            "\(s.suggestionsEnabled)", "\(s.suggestionFit)", "\(s.suggestionScroll)", "\(s.suggestionScrollThree)", s.extraKeys.joined(), s.extraKeysLeft.joined(), "\(s.commaKey)\(s.periodKey)\(s.emojiKey)", s.commaHold.joined(), s.periodHold.joined(),
            s.systemEditsJSON, "\(showsEmoji)"
        ].joined(separator: "|") + (showsEmoji ? "|" + emojiSettingsSignature() : "")
    }

    /// The Emoji screen's settings the picker is built from.
    private func emojiSettingsSignature() -> String {
        return SharedStore.defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("hunkeys.emoji") && $0.key != SettingKey.emojiUseCounts }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "|")
    }

    /// A new bar and KeyboardView, as the controller makes them in buildInterface (they read the theme as they are
    /// made).
    private func rebuild() {
        Settings.shared.refresh()
        Prefs.refresh()
        applyEffects()
        Theme.reload()
        builtSignature = signature()
        builtStyle = traitCollection.userInterfaceStyle
        language = LiveKeyboardView.openingLanguage(code: Settings.shared.languageCode)
        bar.removeFromSuperview()
        keyboard.removeFromSuperview()
        bar = SuggestionBar()
        bar.delegate = self
        keyboard = KeyboardView()
        keyboard.delegate = self
        keyboard.popupHost = stage
        stage.addSubview(bar)
        stage.addSubview(keyboard)
        stage.addSubview(hitboxOverlay)
        hitboxOverlay.keyboard = keyboard
        hitboxOverlay.tintColor = UIColor(Color.currentAccent(name: Settings.shared.accentName,
                                                             hex: SharedStore.defaults.string(forKey: SettingKey.accentHex) ?? ""))
        emojiPanel?.removeFromSuperview()
        emojiPanel = nil
        if showsEmoji {
            // The keyboard with its emoji picker open: the picker replaces the bar and the keys (as showEmojiPanel),
            // and nothing in it leaves it (ABC, search and the emoji key do nothing here).
            bar.isHidden = true
            keyboard.isHidden = true
            hitboxOverlay.isHidden = true
            let panel = EmojiPanel()
            panel.delegate = self
            panel.language = language
            stage.addSubview(panel)
            emojiPanel = panel
            layoutStage()
            panel.reload()
            EmojiStore.shared.loadIfNeeded { [weak panel] in panel?.reload() }
            return
        }
        layoutStage()
        loadRows()
        showWords()
    }

    /// The bar: the word typed on the Hitboxes preview, else the fixed words.
    private func showWords() {
        if !Prefs.suggestions {
            bar.update([])   // no words, and not the word being typed either
        } else if showsHitboxes && !typed.isEmpty {
            bar.update([Suggestion(text: typed, kind: .literal)])
        } else {
            bar.update(starters.map { Suggestion(text: $0, kind: .word) })
        }
    }

    // MARK: Hitboxes

    /// The keyboard's touch areas as they are while typing (KeyboardViewController.applyHitMap and
    /// updateAdaptiveHitboxes), drawn over the keys. Off the Hitboxes screen the preview keeps the plain areas.
    private func updateHitboxes() {
        hitboxOverlay.isHidden = !showsHitboxes
        guard showsHitboxes else {
            keyboard.letterBias = [:]
            keyboard.hitOffsets = [:]
            return
        }
        keyboard.hitOffsets = Prefs.hitMap
            ? HitMap().offsets(strength: Prefs.hitMapStrength, positions: keyboard.letterPositions()) : [:]
        keyboard.letterBias = adaptiveBias()
        hitboxOverlay.setNeedsDisplay()
    }

    /// Adaptive keys for the word typed so far: the same sums as the keyboard's (updateAdaptiveHitboxes).
    private func adaptiveBias() -> [Character: CGFloat] {
        guard Prefs.adaptiveHitboxes, Prefs.adaptiveStrength > 0, page == .letters, language.supports(.keyLearning),
              let store = loadedStore() else { return [:] }
        let weights = (typed.isEmpty && !Prefs.adaptiveWordStart) ? [:] : store.nextLetterWeights(after: typed)
        guard let top = weights.values.max(), top > 0 else { return [:] }
        let strength = Prefs.adaptiveStrength
        var bias: [Character: CGFloat] = [:]
        for letter in keyboard.letterCenters().keys {
            let share = ((weights[letter] ?? 0) / top).squareRoot()
            bias[letter] = CGFloat(1 + strength * (share * Prefs.adaptiveGrow - (1 - share) * Prefs.adaptiveShrink))
        }
        return bias
    }

    /// The language's dictionary, or nil while it loads (in the background; the areas are drawn again after).
    private func loadedStore() -> WordStore? {
        let target = language
        if let store = LiveKeyboardView.stores[target], store.isLoaded { return store }
        guard !LiveKeyboardView.loadingStores.contains(target) else { return nil }
        LiveKeyboardView.loadingStores.insert(target)
        let store = LiveKeyboardView.stores[target] ?? WordStore(language: target)
        LiveKeyboardView.stores[target] = store
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let parsed = WordStore.parse(language: target, limit: 30_000)
            DispatchQueue.main.async {
                store.apply(parsed)
                LiveKeyboardView.loadingStores.remove(target)
                self?.updateHitboxes()
            }
        }
        return nil
    }

    /// A key typed on the Hitboxes preview: letters make the word, anything else ends it.
    private func noteTyped(_ action: KeyAction) {
        guard showsHitboxes else { return }
        switch action {
        case .character(let text) where text.count == 1 && text.first?.isLetter == true:
            typed += text.lowercased()
        case .backspace:
            if !typed.isEmpty { typed.removeLast() }
        case .shift, .showLetters, .showNumbers, .showSymbols, .emoji, .spacer:
            return
        default:
            typed = ""
        }
        showWords()
        updateHitboxes()
    }

    private func applyEffects() {
        Prefs.effects = effectsOverride ?? EffectsConfig.decode(Settings.shared.effectsJSON)
    }

    /// The rows of the page shown (KeyboardViewController.reloadKeyboardLayout).
    private func loadRows() {
        var rows = LayoutBuilder.rows(language: language, page: page, returnTitle: language.strings.returnKey,
                                      numberRow: Prefs.numberRow, showHints: Prefs.keyHints)
        let spaceTitle = Prefs.spaceLanguageCode ? language.rawValue.uppercased() : language.displayName
        rows = rows.map { row in row.map { spec in
            guard spec.action == .space else { return spec }
            var titled = spec
            titled.title = spaceTitle
            return titled
        } }
        if KeyboardLayoutMode.split { rows = LayoutBuilder.split(rows) }
        keyboard.typingLanguage = language
        keyboard.configure(rows: rows, page: page, shift: shift)
        updateHitboxes()
    }

    @objc private func settingsChanged() {
        DispatchQueue.main.async { [weak self] in self?.queueRefresh() }
    }

    /// Settings arrive in bursts (a slider); they are read once for each burst.
    private func queueRefresh() {
        guard !refreshQueued else { return }
        refreshQueued = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.refreshQueued = false
            // The settings' half-second snapshot would hide the slider's latest values (the last step of a drag
            // only showed after the next change): read the shared defaults afresh.
            Settings.shared.refresh()
            Prefs.refresh()
            self.applyEffects()
            if self.signature() != self.builtSignature { self.rebuild() } else { self.updateHitboxes() }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != builtStyle { rebuild() }
    }

    // MARK: The bar

    /// The words the bar always shows (as the keyboard's next-word suggestions before anything is typed), also with
    /// suggestions turned off, so the bar's look can always be seen.
    private var starters: [String] {
        // l10n: keep (words of the typing language, not texts of the app)
        if language == .hungarian { return ["A", "Én", "Nem", "Szia", "Ez", "Az", "Hogy", "De", "Jó", "Igen"] }
        return ["I", "The", "It", "You", "We", "This", "Thanks", "Hello", "My", "So"]
    }

    func suggestionBar(_ bar: SuggestionBar, didSelect suggestion: Suggestion) {
        Haptics.shared.keyPress()
    }

    func suggestionBarDidTapDismiss(_ bar: SuggestionBar) {
        Haptics.shared.keyPress()
    }

    func suggestionBarDidTapTools(_ bar: SuggestionBar) {
        Haptics.shared.keyPress()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutStage()
    }

    private func layoutStage() {
        let size = LiveKeyboardView.naturalSize(keyHeight: Prefs.keyHeight, rowGap: Prefs.rowGap,
                                                numberRow: Prefs.numberRow, barHeight: Prefs.suggestionHeight,
                                                language: language, emoji: showsEmoji)
        // The bar and the keys are always laid out at the keyboard's size, also before this view has one (it is
        // built in init): at 0×0 every key's frame would come out null and Core Animation would throw.
        stage.bounds = CGRect(origin: .zero, size: size)
        let barHeight = CGFloat(Prefs.suggestionHeight)
        let barFrame = CGRect(x: 0, y: 0, width: size.width, height: barHeight)
        let keysFrame = CGRect(x: 0, y: barHeight, width: size.width, height: size.height - barHeight)
        if let panel = emojiPanel, panel.frame != stage.bounds { panel.frame = stage.bounds }
        if bar.frame != barFrame { bar.frame = barFrame }
        if keyboard.frame != keysFrame { keyboard.frame = keysFrame }
        if hitboxOverlay.frame != keysFrame {
            hitboxOverlay.frame = keysFrame
            hitboxOverlay.setNeedsDisplay()
        }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        guard scale.isFinite, scale > 0 else { return }
        stage.center = CGPoint(x: bounds.midX, y: bounds.midY)
        stage.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    // MARK: KeyboardViewDelegate

    func keyboardView(_ view: KeyboardView, didTap action: KeyAction) {
        noteTyped(action)
        switch action {
        case .character:
            if shift == .once {
                shift = .off
                keyboard.setShift(shift)
            }
        case .shift:
            let now = Date()
            switch shift {
            case .off: shift = .once
            case .once: shift = now.timeIntervalSince(lastShiftTap) < 0.4 ? .locked : .off
            case .locked: shift = .off
            }
            lastShiftTap = now
            keyboard.setShift(shift)
        case .showLetters:
            page = .letters
            loadRows()
        case .showNumbers:
            page = .numbers
            loadRows()
        case .showSymbols:
            page = .symbols
            loadRows()
        default:
            break
        }
    }

    func keyboardView(_ view: KeyboardView, didSelectAlternate text: String) {}
    func keyboardView(_ view: KeyboardView, didMoveCursorBy offset: Int) {}
    func keyboardViewDidBeginWordDelete(_ view: KeyboardView) {}
    func keyboardViewDidRequestDeleteWord(_ view: KeyboardView) {}
    func keyboardViewDidRequestRestoreWord(_ view: KeyboardView) {}
    func keyboardViewDidEndWordDelete(_ view: KeyboardView) {}
    func keyboardViewDidHoldEmoji(_ view: KeyboardView) {}

    // MARK: EmojiPanelDelegate

    // The picker plays its own taps; the preview writes nothing, searches nothing and never goes back to the keys.
    func emojiPanel(_ panel: EmojiPanel, didSelect emoji: String) {}
    func emojiPanelDidTapBackspace(_ panel: EmojiPanel) {}
    func emojiPanelDidTapSearch(_ panel: EmojiPanel) {}
    func emojiPanelDidClose(_ panel: EmojiPanel) {}
    func keyboardView(_ view: KeyboardView, didSwipeSpaceBy direction: Int) {}
    func keyboardView(_ view: KeyboardView, didUpdateSwipe path: [CGPoint]) {}
    func keyboardView(_ view: KeyboardView, didFinishSwipe path: [CGPoint]) {
        noteTyped(.space)   // a swiped word ends the one being typed
    }
    func keyboardViewDidCancelSwipe(_ view: KeyboardView) {}

    /// Swiping draws its trail (the Swipe trail effect) whenever swipe typing is on.
    func keyboardViewCanSwipe(_ view: KeyboardView) -> Bool {
        return Prefs.swipe
    }
}

/// Keeps the screen's swipe back (from the edge, and on iOS 26 from anywhere on the screen) from starting on the
/// keyboard, so a swipe there stays with the keys (swipe typing, the effects) instead of leaving the screen. It
/// recognizes as soon as a finger lands on the keyboard, which fails the navigation's swipe back for that touch,
/// and only that: every touch still reaches the keys and the bar, and no other gesture is held up. A swipe from
/// the edge beside the keyboard and the back button go back as before.
final class BackSwipeBlocker: UIGestureRecognizer {
    private var fingers = 0

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        cancelsTouchesInView = false
        delaysTouchesBegan = false
        delaysTouchesEnded = false
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        fingers += touches.count
        if state == .possible {
            state = .began
        } else if state == .began || state == .changed {
            state = .changed
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)
        if state == .began || state == .changed { state = .changed }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        lift(touches, as: .ended)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesCancelled(touches, with: event)
        lift(touches, as: .cancelled)
    }

    private func lift(_ touches: Set<UITouch>, as last: UIGestureRecognizer.State) {
        fingers = max(0, fingers - touches.count)
        if fingers == 0 && (state == .began || state == .changed) { state = last }
    }

    override func reset() {
        super.reset()
        fingers = 0
    }

    /// It stops only the swipe back; the keys' and the screen's other gestures go on alongside it.
    override func canPrevent(_ preventedGestureRecognizer: UIGestureRecognizer) -> Bool {
        return isBackSwipe(preventedGestureRecognizer)
    }

    override func canBePrevented(by preventingGestureRecognizer: UIGestureRecognizer) -> Bool {
        return false
    }

    /// The swipe back of a navigation the keyboard is shown in.
    private func isBackSwipe(_ recognizer: UIGestureRecognizer) -> Bool {
        var responder: UIResponder? = view
        while let current = responder {
            if let navigation = current as? UINavigationController {
                if recognizer === navigation.interactivePopGestureRecognizer { return true }
                #if compiler(>=6.2)
                if #available(iOS 26.0, *), recognizer === navigation.interactiveContentPopGestureRecognizer { return true }
                #endif
            }
            responder = current.next
        }
        return false
    }
}

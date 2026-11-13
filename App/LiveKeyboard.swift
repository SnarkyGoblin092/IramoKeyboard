import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// The keyboard itself, pinned above the settings screens: Keyboard/SuggestionBar, Keyboard/KeyboardView and its
/// KeyViews, built from the same settings and played by the same code as while typing, so the keys, the bar, the
/// effects, the haptics and the gestures look and feel as they do there. The emoji key opens nothing and the keys
/// write nothing: the bar always shows the same few words, so its look can be seen. Shift and the number and symbol
/// pages work, so every key can be tried. Laid out at the keyboard's real size and shrunk to fit the pane.
struct LiveKeyboard: View {
    /// Room all round the keys inside the glass card.
    static let room: CGFloat = 18

    /// The height of the card (its room included) that shows the keyboard at the scale that fits `width`: the keyboard
    /// as wide as the settings below it.
    static func cardHeight(width: CGFloat) -> CGFloat {
        let s = Settings.shared
        let natural = LiveKeyboardView.naturalSize(keyHeight: s.keyHeight, rowGap: s.rowGap, numberRow: s.numberRow,
                                                   barHeight: s.suggestionHeight,
                                                   language: LiveKeyboardView.openingLanguage(code: s.languageCode))
        let scale = max(0.3, (width - 2 * room) / natural.width)
        return natural.height * scale + 2 * room
    }

    /// The Effects screen's settings as they are being edited (nil: the stored ones).
    var effects: EffectsConfig? = nil
    /// Only the suggestion bar, cycling through a few words (the Suggestions screen).
    var barOnly = false
    // Its proportions (LiveKeyboardView.naturalSize): read here so a change redraws it at once.
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.rowGap, store: SharedStore.defaults) private var rowGap = SettingDefault.rowGap
    @AppStorage(SettingKey.numberRow, store: SharedStore.defaults) private var numberRow = SettingDefault.numberRow
    @AppStorage(SettingKey.suggestionHeight, store: SharedStore.defaults) private var barHeight = SettingDefault.suggestionHeight
    @AppStorage(SettingKey.language, store: SharedStore.defaults) private var languageCode = SettingDefault.language
    /// The mode picked for the preview (Theme.appearanceStyle, which the keys are drawn in); "auto": the app's own.
    @AppStorage(SettingKey.appearance, store: SharedStore.defaults) private var appearance = SettingDefault.appearance
    @Environment(\.colorScheme) private var appScheme
    @Environment(\.modeWaves) private var waves
    /// On the tab that is shown. Every tab stays built, so a keyboard on a tab that is not shown would still read
    /// every setting and build its keys at each change: there it is not built at all, only its backdrop is drawn.
    @Environment(\.tabIsFront) private var isFront

    /// The mode the keys are drawn in, for the backdrop behind them.
    private var scheme: ColorScheme {
        return appearance == "light" ? .light : (appearance == "dark" ? .dark : appScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = LiveKeyboardView.naturalSize(keyHeight: keyHeight, rowGap: rowGap, numberRow: numberRow,
                                                    barHeight: barHeight,
                                                    language: LiveKeyboardView.openingLanguage(code: languageCode),
                                                    barOnly: barOnly)
            // Room all round the keys inside the glass, so square-cornered keys and their outlines are not cut off.
            let room: CGFloat = barOnly ? 0 : LiveKeyboard.room
            let scale = min((geometry.size.width - 2 * room) / size.width, (geometry.size.height - 2 * room) / size.height)
            CurrentThemeLook { look in
                LiveKeyboardStage(effects: effects, barOnly: barOnly, live: isFront)
                    .frame(width: size.width * scale, height: size.height * scale)
                    .padding(room)
                    // The keys sit on clear Liquid Glass, as the keyboard's own keys do over the app; the keys and the bar
                    // keep the theme.
                    // (The bar alone: only the bar's own height.)
                    .background(ClearGlassCard(cornerRadius: 14).padding(.vertical, barOnly ? 4.5 * scale : 0))
            }
            // The backdrop is drawn in the keys' mode, not the app's: light keys and the bar's dark words would
            // be lost on a dark backdrop.
            .environment(\.colorScheme, scheme)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minHeight: 60)
    }
}

/// The keyboard itself while its tab is shown, and only its room otherwise.
private struct LiveKeyboardStage: View {
    let effects: EffectsConfig?
    let barOnly: Bool
    let live: Bool

    var body: some View {
        if live {
            LiveKeyboardHost(effects: effects, barOnly: barOnly)
        } else {
            Color.clear
        }
    }
}

private struct LiveKeyboardHost: UIViewRepresentable {
    let effects: EffectsConfig?
    let barOnly: Bool

    func makeUIView(context: Context) -> LiveKeyboardView {
        let view = LiveKeyboardView()
        view.barOnly = barOnly
        view.effectsOverride = effects
        return view
    }

    func updateUIView(_ view: LiveKeyboardView, context: Context) {
        // Read by the keys at every press (KeyView.syncEffects), so a change shows on the next one.
        view.effectsOverride = effects
        view.barOnly = barOnly
    }
}

/// Holds the suggestion bar and the KeyboardView at the keyboard's size in `stage`, shrunk to fit, and stands in for
/// the keyboard's controller: it builds them (as KeyboardViewController.buildInterface and reloadKeyboardLayout),
/// handles shift and the pages, fills the bar with a few fixed words, and builds everything again when a setting
/// that changes their look is edited (as the controller's settingsSignature).
final class LiveKeyboardView: UIView, KeyboardViewDelegate, SuggestionBarDelegate {
    /// The keyboard's points; scaled to the view. Popups are added here too, so they are drawn at the same scale.
    private let stage = UIView()
    private var bar = SuggestionBar()
    private var keyboard = KeyboardView()
    private var language: Language = .english
    private var page: KeyboardPage = .letters
    private var shift: ShiftState = .off
    private var lastShiftTap = Date.distantPast
    private var builtSignature = ""
    private var builtAccent = ""
    private func accentKey() -> String {
        return Settings.shared.accentName + "|" + (SharedStore.defaults.string(forKey: SettingKey.accentHex) ?? "")
    }
    private var refreshQueued = false
    /// A setting changed while this keyboard was not on screen: it reads the settings when it is shown again.
    private var stale = false
    private var builtStyle: UIUserInterfaceStyle = .unspecified
    /// Only the bar is shown, and it changes its words every little while to show off its animation.
    var barOnly = false {
        didSet {
            guard oldValue != barOnly else { return }
            rebuild()
            updateCycle()
        }
    }
    private var cycleTimer: Timer?
    private var cycleStep = 0
    /// How long the keys take to fade from light to dark and back when the preview's mode is switched.
    static let modeFade: TimeInterval = 0.3

    /// The Effects screen's settings while they are edited; nil plays the stored ones.
    var effectsOverride: EffectsConfig? {
        didSet { applyEffects() }
    }

    /// The keyboard's size (KeyboardViewController.applyHeight), upright: the screen's width, and the bar above its
    /// rows of keys with the gap between them. An iPad's keys are taller than an iPhone's.
    static func naturalSize(keyHeight: Double, rowGap: Double, numberRow: Bool, barHeight: Double,
                            language: Language, barOnly: Bool = false) -> CGSize {
        // The bar draws its glass 4.5 points low (SuggestionBar.layoutSubviews: inset 3, moved down 4.5), so the strip
        // spans 7.5 ... height + 1.5: the room is made 9 taller, which centres the strip in it.
        if barOnly { return CGSize(width: CGFloat(DeviceMetrics.keyboardWidth), height: CGFloat(barHeight) + 9) }
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let height = isPad ? CGFloat(keyHeight) * 61 / 45 : CGFloat(keyHeight)
        let rows = CGFloat(language.letterRows.count + 1 + (numberRow ? 1 : 0))
        let width = CGFloat(DeviceMetrics.keyboardWidth)
        let total = CGFloat(barHeight) + 8 + rows * (height + CGFloat(rowGap))
        return CGSize(width: width, height: total)
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
        let layouts: String = Settings.signature(of: s.letterLayouts)
        let holds: String = Settings.signature(of: s.customHolds)
        let parts: [String] = [
            Theme.storedID(), s.accentName, String(LiveKeyboardView.effectiveStyle.rawValue), SharedStore.defaults.string(forKey: SettingKey.accentHex) ?? "",
            "\(s.numberRow)", "\(s.keyHints)", "\(s.keyPopups)", "\(Prefs.keyRoundness)", s.keySurface, s.keyBorderStyle,
            s.keyGlow, s.keyFont, s.enabledLanguages.joined(separator: ","), s.languageCode,
            "\(s.keyHeight)", "\(s.keyboardWidth)", "\(s.keyGap)", "\(s.rowGap)", "\(s.alwaysCapitals)", "\(s.letterSize)",
            s.hintPosition, "\(s.hintSize)", "\(s.spaceTextSize)", "\(s.spaceLanguageCode)", "\(s.splitKeyboard)", "\(KeyboardLayoutMode.split)", s.oneHanded,
            s.separatorStyle, "\(s.suggestionFollowTheme)", "\(s.suggestionHeight)",
            "\(s.suggestionsEnabled)", "\(s.suggestionFit)", "\(s.suggestionScroll)", "\(s.suggestionScrollThree)", s.extraKeys.joined(), s.extraKeysLeft.joined(), "\(s.commaKey)\(s.periodKey)\(s.emojiKey)", s.commaHold.joined(), s.periodHold.joined(),
            s.systemEditsJSON, layouts, holds
        ]
        return parts.joined(separator: "|")
    }

    /// The mode the keys are drawn in: the picked one, or (auto) the system's. Picking auto while the system is in
    /// the mode already shown changes nothing about how the keyboard looks, so it is not built again for it.
    static var effectiveStyle: UIUserInterfaceStyle {
        let picked = Theme.appearanceStyle
        return picked != .unspecified ? picked : UIScreen.main.traitCollection.userInterfaceStyle
    }

    /// A new bar and KeyboardView, as the controller makes them in buildInterface (they read the theme as they are
    /// made).
    private func rebuild() {
        Settings.shared.refresh()
        Prefs.refresh()
        applyEffects()
        Theme.reload()
        overrideUserInterfaceStyle = Theme.appearanceStyle
        builtSignature = signature()
        builtAccent = accentKey()
        // The picked mode is the one built even if the view's traits have not caught up yet (a second build for
        // them would cut the fade short).
        builtStyle = LiveKeyboardView.effectiveStyle
        language = LiveKeyboardView.openingLanguage(code: Settings.shared.languageCode)
        bar.removeFromSuperview()
        keyboard.removeFromSuperview()
        bar = SuggestionBar()
        bar.delegate = self
        keyboard = KeyboardView()
        keyboard.delegate = self
        keyboard.popupHost = stage
        stage.addSubview(bar)
        if !barOnly { stage.addSubview(keyboard) }
        layoutStage()
        if !barOnly { loadRows() }
        showWords(animated: false)
    }

    /// The bar: always the same few words.
    private func showWords(animated: Bool = true) {
        // A bar that was just built shows its words at once (not sliding in as new words do).
        let saved = Prefs.suggestionTransition
        if !animated { Prefs.suggestionTransition = "instant" }
        defer { Prefs.suggestionTransition = saved }
        if !Prefs.suggestions {
            bar.update([])
        } else {
            bar.update(shownWords.map { Suggestion(text: $0, kind: .word) })
        }
    }

    /// The words on show: the same few, or (bar only) a new set each time round.
    private var shownWords: [String] {
        guard barOnly else { return starters }
        // A bar that fits more words or scrolls is shown full, with enough words to scroll it.
        if Prefs.suggestionScroll || Prefs.suggestionFit {
            let pool: [String] = language == .hungarian
                ? ["Szia", "Nem", "Igen", "Köszönöm", "Jó", "De", "Hogy", "Az", "Ez", "Én", "A", "Mi", "Most", "Majd", "Itt", "Ott"]
                : ["Hello", "Thanks", "The", "It", "My", "So", "You", "We", "This", "I", "What", "Yes", "Please", "Good", "Sure", "Maybe"]
            let wanted = min(SuggestionBar.capacity, pool.count)
            let start = (cycleStep * 3) % pool.count
            return (0..<wanted).map { pool[(start + $0) % pool.count] }
        }
        let sets: [[String]] = language == .hungarian
            ? [["Szia", "Nem", "Igen"], ["Köszönöm", "Jó", "De"], ["Hogy", "Az", "Ez"], ["Én", "A", "Szia"]]
            : [["Hello", "Thanks", "The"], ["It", "My", "So"], ["You", "We", "This"], ["I", "Hello", "Thanks"]]
        return sets[cycleStep % sets.count]
    }

    private func updateCycle() {
        cycleTimer?.invalidate()
        cycleTimer = nil
        guard barOnly, window != nil else { return }
        cycleTimer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.cycleStep += 1
            self.showWords()
        }
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
    }

    @objc private func settingsChanged() {
        DispatchQueue.main.async { [weak self] in self?.queueRefresh() }
    }

    /// Settings arrive in bursts (a slider); they are read once for each burst.
    private func queueRefresh() {
        // Off screen (on a tab that is not shown, or under a screen opened over it) nothing is read or built: every
        // tab keeps its screens, so several of these can be alive at once, and each would read every setting and
        // build its keys again at every step of a slider on the screen in front. It catches up when it is shown.
        guard window != nil else {
            stale = true
            return
        }
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
            let target = LiveKeyboardView.effectiveStyle
            // Auto to the mode already shown (or back): only the follow-the-system setting changes, not the look.
            if target == self.builtStyle, self.overrideUserInterfaceStyle != Theme.appearanceStyle {
                self.overrideUserInterfaceStyle = Theme.appearanceStyle
            }
            guard self.signature() != self.builtSignature else { return }
            // Light to dark (the Themes screen's switch): the new keys fade in over the old ones where there is no wave
            // (with a wave, the picture of the old window it took (WindowWave) hides the change until it gets there).
            // A new accent fades in the same way, over the time the backdrop takes.
            let accentChanged = self.accentKey() != self.builtAccent
            if self.window != nil, ModeWave.running.isEmpty, target == self.builtStyle, accentChanged {
                // Everything stays where it is: the keyboard is built anew with no animation of its own (nothing
                // slides or jumps), and a picture of the old one over it fades away.
                let old = self.snapshotView(afterScreenUpdates: false)
                UIView.performWithoutAnimation {
                    self.rebuild()
                    self.layoutIfNeeded()
                }
                if let old = old {
                    old.frame = self.bounds
                    old.isUserInteractionEnabled = false
                    self.addSubview(old)
                    UIView.animate(withDuration: 0.7, delay: 0, options: [.curveEaseInOut, .allowUserInteraction],
                                   animations: { old.alpha = 0 },
                                   completion: { _ in old.removeFromSuperview() })
                }
            } else if self.window != nil, ModeWave.running.isEmpty, target != self.builtStyle {
                UIView.transition(with: self, duration: LiveKeyboardView.modeFade,
                                  options: [.transitionCrossDissolve, .allowUserInteraction],
                                  animations: { self.rebuild() })
            } else {
                self.rebuild()
            }
        }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateCycle()
        // Back on screen: the settings changed meanwhile are read now.
        if window != nil, stale {
            stale = false
            queueRefresh()
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
                                                language: language, barOnly: barOnly)
        // The bar and the keys are always laid out at the keyboard's size, also before this view has one (it is
        // built in init): at 0×0 every key's frame would come out null and Core Animation would throw.
        stage.bounds = CGRect(origin: .zero, size: size)
        let barHeight = CGFloat(Prefs.suggestionHeight)
        let barFrame = CGRect(x: 0, y: 0, width: size.width, height: barHeight)
        let keysFrame = CGRect(x: 0, y: barHeight, width: size.width, height: size.height - barHeight)
        if bar.frame != barFrame { bar.frame = barFrame }
        if keyboard.frame != keysFrame { keyboard.frame = keysFrame }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        guard scale.isFinite, scale > 0 else { return }
        stage.center = CGPoint(x: bounds.midX, y: bounds.midY)
        stage.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    // MARK: KeyboardViewDelegate

    func keyboardView(_ view: KeyboardView, didTap action: KeyAction) {
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
        case .showMoreSymbols:
            page = .moreSymbols
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

    func keyboardView(_ view: KeyboardView, didSwipeSpaceBy direction: Int) {}
    func keyboardView(_ view: KeyboardView, didUpdateSwipe path: [CGPoint]) {}
    func keyboardView(_ view: KeyboardView, didFinishSwipe path: [CGPoint]) {}
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

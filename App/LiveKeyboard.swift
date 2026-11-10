import SwiftUI
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// The keyboard itself, pinned above the settings screens: Keyboard/SuggestionBar, Keyboard/KeyboardView and its
/// KeyViews, built from the same settings and played by the same code as while typing, so the keys, the bar, the
/// effects, the haptics and the gestures look and feel as they do there. The emoji key opens nothing and the keys
/// write nothing: the bar always shows the same few words, so its look can be seen. Shift and the number and symbol
/// pages work, so every key can be tried. Laid out at the keyboard's real size and shrunk to fit the pane.
struct LiveKeyboard: View {
    /// The Effects screen's settings as they are being edited (nil: the stored ones).
    var effects: EffectsConfig? = nil
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

    /// The mode the keys are drawn in, for the backdrop behind them.
    private var scheme: ColorScheme {
        return appearance == "light" ? .light : (appearance == "dark" ? .dark : appScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = LiveKeyboardView.naturalSize(keyHeight: keyHeight, rowGap: rowGap, numberRow: numberRow,
                                                    barHeight: barHeight,
                                                    language: LiveKeyboardView.openingLanguage(code: languageCode))
            let scale = min(geometry.size.width / size.width, geometry.size.height / size.height)
            CurrentThemeLook { look in
                LiveKeyboardHost(effects: effects)
                    // A transparent backdrop shows only the keys, over whatever the screen has behind them.
                    .background(
                        ZStack {
                            // The Themes screen's waves (ModeWave): the first one's old backdrop at the bottom, each
                            // wave's new one over it inside that wave's circle, as the keys
                            // (LiveKeyboardView.cover).
                            if waves.isEmpty {
                                // Without a wave it fades with the keys (LiveKeyboardView.modeFade).
                                look.backdrop(scale: scale)
                                    .animation(.easeInOut(duration: LiveKeyboardView.modeFade), value: scheme)
                            } else {
                                backdrop(scheme: waves[0].oldScheme, theme: waves[0].oldTheme, scale: scale)
                                ForEach(waves) { wave in
                                    backdrop(scheme: wave.newScheme, theme: wave.newTheme, scale: scale)
                                        .revealedByWave(wave)
                                }
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
                    )
            }
            // The backdrop is drawn in the keys' mode, not the app's: light keys and the bar's dark words would
            // be lost on a dark backdrop.
            .environment(\.colorScheme, scheme)
            .frame(width: size.width * scale, height: size.height * scale)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minHeight: 60)
    }

    /// The backdrop in one mode and theme, for the waves' layers.
    private func backdrop(scheme: ColorScheme, theme: String, scale: CGFloat) -> some View {
        return CurrentThemeLook(theme: theme) { look in look.backdrop(scale: scale) }
            .environment(\.colorScheme, scheme)
    }
}

private struct LiveKeyboardHost: UIViewRepresentable {
    let effects: EffectsConfig?

    func makeUIView(context: Context) -> LiveKeyboardView {
        let view = LiveKeyboardView()
        view.effectsOverride = effects
        return view
    }

    func updateUIView(_ view: LiveKeyboardView, context: Context) {
        // Read by the keys at every press (KeyView.syncEffects), so a change shows on the next one.
        view.effectsOverride = effects
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
    private var refreshQueued = false
    private var builtStyle: UIUserInterfaceStyle = .unspecified
    /// The keyboard on screen, for the Themes screen to have it covered before anything changes.
    static weak var current: LiveKeyboardView?
    /// The pictures of the old keys, each under its wave's circle.
    private struct Cover {
        let wave: ModeWave
        let view: UIView
        let mask: CAShapeLayer
        /// When its wave has left the keyboard (ModeWave.lifetime).
        let ends: CFTimeInterval
    }
    private var covers: [Cover] = []
    private let coverDriver = WaveDriver()

    /// How long the keys take to fade from light to dark and back when the preview's mode is switched.
    static let modeFade: TimeInterval = 0.3

    /// The Effects screen's settings while they are edited; nil plays the stored ones.
    var effectsOverride: EffectsConfig? {
        didSet { applyEffects() }
    }

    /// The keyboard's size (KeyboardViewController.applyHeight), upright: the screen's width, and the bar above its
    /// rows of keys with the gap between them. An iPad's keys are taller than an iPhone's.
    static func naturalSize(keyHeight: Double, rowGap: Double, numberRow: Bool, barHeight: Double,
                            language: Language) -> CGSize {
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
        LiveKeyboardView.current = self
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
            Theme.storedID(), s.accentName, s.appearance, SharedStore.defaults.string(forKey: SettingKey.accentHex) ?? "",
            "\(s.numberRow)", "\(s.keyHints)", "\(s.keyPopups)", "\(Prefs.keyRoundness)", s.keySurface, s.keyBorderStyle,
            s.keyGlow, s.keyFont, s.enabledLanguages.joined(separator: ","), s.languageCode,
            "\(s.keyHeight)", "\(s.keyboardWidth)", "\(s.keyGap)", "\(s.rowGap)", "\(s.alwaysCapitals)", "\(s.letterSize)",
            s.hintPosition, "\(s.hintSize)", "\(s.spaceTextSize)", "\(s.spaceLanguageCode)", "\(s.splitKeyboard)", "\(KeyboardLayoutMode.split)", s.oneHanded,
            s.suggestionStyle, s.separatorStyle, "\(s.suggestionFollowTheme)", "\(s.suggestionHeight)",
            "\(s.suggestionsEnabled)", "\(s.suggestionFit)", "\(s.suggestionScroll)", "\(s.suggestionScrollThree)", s.extraKeys.joined(), s.extraKeysLeft.joined(), "\(s.commaKey)\(s.periodKey)\(s.emojiKey)", s.commaHold.joined(), s.periodHold.joined(),
            s.systemEditsJSON
        ].joined(separator: "|")
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
        // The picked mode is the one built even if the view's traits have not caught up yet (a second build for
        // them would cut the fade short).
        builtStyle = overrideUserInterfaceStyle != .unspecified ? overrideUserInterfaceStyle : traitCollection.userInterfaceStyle
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
        layoutStage()
        loadRows()
        showWords()
    }

    /// The bar: always the same few words.
    private func showWords() {
        if !Prefs.suggestions {
            bar.update([])
        } else {
            bar.update(starters.map { Suggestion(text: $0, kind: .word) })
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
            guard self.signature() != self.builtSignature else { return }
            // Light to dark (the Themes screen's switch): the new keys fade in over the old ones where there is no wave
            // (with a wave, the picture of the old keys that it took (cover) hides the change until it gets there).
            if self.window != nil, ModeWave.running.isEmpty, Theme.appearanceStyle != self.overrideUserInterfaceStyle {
                UIView.transition(with: self, duration: LiveKeyboardView.modeFade,
                                  options: [.transitionCrossDissolve, .allowUserInteraction],
                                  animations: { self.rebuild() })
            } else {
                self.rebuild()
            }
        }
    }

    /// Takes a picture of the keys as they are, and lays it over them: the wave (called as it sets off, before anything
    /// has changed) then wipes the picture away, so the new keys, the accent colours and all, show only where the
    /// wave has passed. The picture is masked to everything outside the wave's irregular circle, and the circle
    /// follows the wave's own clock and curve, frame by frame. A second wave takes a picture of the first one's
    /// half-done work, and covers it the same way.
    ///
    /// The picture is of the screen itself where the keyboard is, backdrop and all, not of the keys alone: see-through
    /// keys (glass, the transparent theme) taken alone would let the keys under them show through, and the preview
    /// would change the moment the wave sets off.
    func cover(for wave: ModeWave) {
        guard let window = window else { return }
        let taken = window.resizableSnapshotView(from: convert(bounds, to: nil), afterScreenUpdates: false,
                                                 withCapInsets: .zero) ?? snapshotView(afterScreenUpdates: false)
        guard let picture = taken else { return }
        let old = UIView(frame: bounds)
        old.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        old.isUserInteractionEnabled = false
        // Cut to the preview's rounded box (LiveKeyboard's backdrop), so nothing of the screen around it is covered.
        let box = UIView(frame: bounds)
        box.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        box.layer.cornerRadius = 14
        box.layer.cornerCurve = .continuous
        box.layer.masksToBounds = true
        picture.frame = box.bounds
        picture.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        box.addSubview(picture)
        old.addSubview(box)
        addSubview(old)
        let mask = CAShapeLayer()
        mask.fillRule = .evenOdd
        mask.fillColor = UIColor.black.cgColor
        mask.frame = bounds
        old.layer.mask = mask
        covers.append(Cover(wave: wave, view: old, mask: mask, ends: wave.started + wave.lifetime))
        updateCovers(at: CACurrentMediaTime())
        if covers.isEmpty { return }
        coverDriver.start { [weak self] time in self?.updateCovers(at: time) }
    }

    /// Moves every cover's circle to where its wave is at `time`; a wave that has finished takes its cover away.
    private func updateCovers(at time: CFTimeInterval) {
        let origin = convert(CGPoint.zero, to: nil)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for cover in covers {
            if time >= cover.ends {
                cover.view.removeFromSuperview()
                continue
            }
            let path = CGMutablePath()
            path.addRect(CGRect(x: -4000, y: -4000, width: 8000, height: 8000))
            let points = cover.wave.outline(cover.wave.progress(atMediaTime: time), relativeTo: origin)
            if let first = points.first {
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
                path.closeSubpath()
            }
            cover.mask.path = path
        }
        CATransaction.commit()
        covers.removeAll { time >= $0.ends }
        if covers.isEmpty { coverDriver.stop() }
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
                                                language: language)
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

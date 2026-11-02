import SwiftUI
import UIKit

/// The keyboard itself, on the Effects screen: Keyboard/KeyboardView and its KeyViews, built from the same settings
/// and played by the same code as while typing, so every effect looks and moves as it does there. Only the keys: no
/// suggestion bar, and the emoji key opens no picker. The keys type nothing; shift and the number and symbol pages
/// work, so every key can be tried. Laid out at the keyboard's real size and shrunk to fit the pane.
struct LiveKeyboard: View {
    let effects: EffectsConfig

    // Its proportions (LiveKeyboardView.naturalSize): read here so a change redraws it at once.
    @AppStorage(SettingKey.keyHeight, store: SharedStore.defaults) private var keyHeight = SettingDefault.keyHeight
    @AppStorage(SettingKey.rowGap, store: SharedStore.defaults) private var rowGap = SettingDefault.rowGap
    @AppStorage(SettingKey.numberRow, store: SharedStore.defaults) private var numberRow = SettingDefault.numberRow
    @AppStorage(SettingKey.language, store: SharedStore.defaults) private var languageCode = SettingDefault.language

    var body: some View {
        GeometryReader { geometry in
            let size = LiveKeyboardView.naturalSize(keyHeight: keyHeight, rowGap: rowGap, numberRow: numberRow,
                                                    language: LiveKeyboardView.openingLanguage(code: languageCode))
            let scale = min(geometry.size.width / size.width, geometry.size.height / size.height)
            CurrentThemeLook { look in
                LiveKeyboardHost(effects: effects)
                    .background(look.backdrop(scale: scale)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4))
            }
            .frame(width: size.width * scale, height: size.height * scale)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .frame(minHeight: 60)
    }
}

private struct LiveKeyboardHost: UIViewRepresentable {
    let effects: EffectsConfig

    func makeUIView(context: Context) -> LiveKeyboardView {
        Prefs.effects = effects
        return LiveKeyboardView()
    }

    func updateUIView(_ view: LiveKeyboardView, context: Context) {
        // Read by the keys at every press (KeyView.syncEffects), so a change shows on the next one.
        Prefs.effects = effects
    }
}

/// Holds the KeyboardView at the keyboard's size in `stage`, shrunk to fit, and stands in for the keyboard's
/// controller: it builds the rows (as KeyboardViewController.reloadKeyboardLayout), handles shift and the pages, and
/// rebuilds the keys when a setting that changes their look is edited (as the controller's settingsSignature).
final class LiveKeyboardView: UIView, KeyboardViewDelegate {
    /// The keyboard's points; scaled to the view. Popups are added here too, so they are drawn at the same scale.
    private let stage = UIView()
    private var keyboard = KeyboardView()
    private var language: Language = .english
    private var page: KeyboardPage = .letters
    private var shift: ShiftState = .off
    private var lastShiftTap = Date.distantPast
    private var builtSignature = ""
    private var refreshQueued = false
    private var builtStyle: UIUserInterfaceStyle = .unspecified

    /// The keyboard's size without the suggestion bar (KeyboardViewController.applyHeight, upright): the screen's
    /// width, and its rows of keys with the gap between them.
    static func naturalSize(keyHeight: Double, rowGap: Double, numberRow: Bool, language: Language) -> CGSize {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let height = CGFloat(keyHeight) * (isPad ? 61 / 45 : 1)
        let rows = CGFloat(language.letterRows.count + 1 + (numberRow ? 1 : 0))
        return CGSize(width: CGFloat(DeviceMetrics.portraitWidth), height: 8 + rows * (height + CGFloat(rowGap)))
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

    /// The settings that change how the keys are built (the controller's settingsSignature, less the suggestion
    /// bar's and the effects', which the keys read as they play).
    private func signature() -> String {
        let s = Settings.shared
        return [
            Theme.storedID(), Theme.storedEdits(), s.accentName, SharedStore.defaults.string(forKey: SettingKey.accentHex) ?? "",
            "\(s.numberRow)", "\(s.keyHints)", "\(s.keyPopups)", "\(Prefs.keyRoundness)", s.keySurface, s.keyBorderStyle,
            s.keyGlow, s.keyFont, s.enabledLanguages.joined(separator: ","), s.languageCode,
            "\(s.keyHeight)", "\(s.keyboardWidth)", "\(s.keyGap)", "\(s.rowGap)", "\(s.alwaysCapitals)", "\(s.letterSize)",
            s.hintPosition, "\(s.hintSize)", "\(s.spaceTextSize)", "\(s.spaceLanguageCode)", "\(s.splitKeyboard)", s.oneHanded,
            s.systemEditsJSON
        ].joined(separator: "|")
    }

    /// A new KeyboardView, as the controller makes one in buildInterface (it reads the theme as it is made).
    private func rebuild() {
        Prefs.refresh()
        Theme.reload()
        builtSignature = signature()
        builtStyle = traitCollection.userInterfaceStyle
        language = LiveKeyboardView.openingLanguage(code: Settings.shared.languageCode)
        keyboard.removeFromSuperview()
        keyboard = KeyboardView()
        keyboard.delegate = self
        keyboard.popupHost = stage
        stage.overrideUserInterfaceStyle = Theme.interfaceStyle
        stage.addSubview(keyboard)
        layoutStage()
        loadRows()
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
            Prefs.refresh()
            if self.signature() != self.builtSignature { self.rebuild() }
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if traitCollection.userInterfaceStyle != builtStyle { rebuild() }
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutStage()
    }

    private func layoutStage() {
        let size = LiveKeyboardView.naturalSize(keyHeight: Prefs.keyHeight, rowGap: Prefs.rowGap,
                                                numberRow: Prefs.numberRow, language: language)
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        guard scale.isFinite, scale > 0 else { return }
        stage.bounds = CGRect(origin: .zero, size: size)
        stage.center = CGPoint(x: bounds.midX, y: bounds.midY)
        stage.transform = CGAffineTransform(scaleX: scale, y: scale)
        if keyboard.frame != stage.bounds { keyboard.frame = stage.bounds }
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
    func keyboardViewDidRequestDeleteWord(_ view: KeyboardView) {}
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

import SwiftUI
import UIKit

/// The keyboard's own emoji picker (Keyboard/EmojiPanel), pinned above the Emoji screen: built from the same
/// settings and played by the same code as in the keyboard, so the layout, the tabs, the grid, scrolling and the
/// skin-tone popups look and feel as they do there. Tapping an emoji writes nothing. Laid out at the picker's real
/// size on this phone and shrunk to fit the pane.
struct LiveEmojiPicker: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geometry in
            let size = LiveEmojiPickerView.naturalSize
            let scale = min(geometry.size.width / size.width, geometry.size.height / size.height)
            // The first layout pass can be zero-sized.
            if scale.isFinite, scale > 0 {
                LiveEmojiPickerHost()
                    .frame(width: size.width * scale, height: size.height * scale)
                    // The keyboard's backdrop behind the picker (it shows the system's own there).
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(scheme == .dark ? Color(white: 0.17) : Color(red: 0.82, green: 0.84, blue: 0.86))
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .frame(minHeight: 60)
        .accessibilityLabel(tr("Preview of the emoji picker"))
    }
}

private struct LiveEmojiPickerHost: UIViewRepresentable {
    func makeUIView(context: Context) -> LiveEmojiPickerView {
        return LiveEmojiPickerView()
    }

    func updateUIView(_ view: LiveEmojiPickerView, context: Context) {}
}

/// Holds an EmojiPanel at the picker's size in `stage`, shrunk to fit, and stands in for the keyboard's controller
/// (showEmojiPanel). The panel reads the settings as it is made, so it is made anew when one of them changes.
final class LiveEmojiPickerView: UIView, EmojiPanelDelegate {
    private let stage = UIView()
    private var panel: EmojiPanel?
    private var builtSignature = ""
    private var refreshQueued = false
    private var builtStyle: UIUserInterfaceStyle = .unspecified

    /// The picker as the keyboard shows it on this phone, upright (KeyboardViewController.applyHeight): the
    /// keyboard's own height, or taller when the picker needs more for its rows.
    static var naturalSize: CGSize {
        let s = Settings.shared
        let keyboard = LiveKeyboardView.naturalSize(keyHeight: s.keyHeight, rowGap: s.rowGap, numberRow: s.numberRow,
                                                    barHeight: s.suggestionHeight,
                                                    language: LiveKeyboardView.openingLanguage(code: s.languageCode))
        // The width the keyboard really showed its picker at, when it has (its window need not be the screen's width,
        // and the layout and the picker's height both follow the width).
        let parts = (SharedStore.defaults.string(forKey: SettingKey.lastEmojiSize) ?? "").split(separator: ",").compactMap { Double($0) }
        let width = parts.count == 2 && parts[0] > 100 ? CGFloat(parts[0]) : keyboard.width
        return CGSize(width: width, height: max(keyboard.height, EmojiPanel.requiredHeight(forWidth: width)))
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        stage.backgroundColor = .clear
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

    /// The settings the picker is built from: the Emoji screen's, the theme and the typing language.
    private func signature() -> String {
        let emoji = SharedStore.defaults.dictionaryRepresentation()
            .filter { $0.key.hasPrefix("hunkeys.emoji") && $0.key != SettingKey.emojiUseCounts }
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
        return ([Theme.storedID(), Theme.storedEdits(), Settings.shared.languageCode] + emoji).joined(separator: "|")
    }

    private func rebuild() {
        Settings.shared.refresh()
        Prefs.refresh()
        Theme.reload()
        builtSignature = signature()
        builtStyle = traitCollection.userInterfaceStyle
        panel?.removeFromSuperview()
        let panel = EmojiPanel()
        panel.delegate = self
        panel.language = LiveKeyboardView.openingLanguage(code: Settings.shared.languageCode)
        stage.overrideUserInterfaceStyle = Theme.interfaceStyle
        stage.addSubview(panel)
        self.panel = panel
        layoutStage()
        panel.reload()
        EmojiStore.shared.loadIfNeeded { [weak panel] in
            panel?.reload()
        }
    }

    @objc private func settingsChanged() {
        // Settings arrive in bursts (a slider); they are read once for each burst.
        guard !refreshQueued else { return }
        refreshQueued = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.refreshQueued = false
            Settings.shared.refresh()
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
        let size = LiveEmojiPickerView.naturalSize
        // Always laid out at the picker's size, also before this view has one (it is built in init).
        stage.bounds = CGRect(origin: .zero, size: size)
        if let panel = panel, panel.frame != stage.bounds { panel.frame = stage.bounds }
        let scale = min(bounds.width / size.width, bounds.height / size.height)
        guard scale.isFinite, scale > 0 else { return }
        stage.center = CGPoint(x: bounds.midX, y: bounds.midY)
        stage.transform = CGAffineTransform(scaleX: scale, y: scale)
    }

    // MARK: EmojiPanelDelegate

    // The panel plays its own taps; the preview writes nothing, searches nothing and stays open.
    func emojiPanel(_ panel: EmojiPanel, didSelect emoji: String) {}
    func emojiPanelDidTapBackspace(_ panel: EmojiPanel) {}
    func emojiPanelDidTapSearch(_ panel: EmojiPanel) {}
    func emojiPanelDidClose(_ panel: EmojiPanel) {}
}

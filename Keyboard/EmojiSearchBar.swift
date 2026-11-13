import UIKit

protocol EmojiSearchBarDelegate: AnyObject {
    func emojiSearchBar(_ bar: EmojiSearchBar, didSelect emoji: String)
    func emojiSearchBarDidTapBack(_ bar: EmojiSearchBar)
    func emojiSearchBarDidTapHide(_ bar: EmojiSearchBar)
}

/// Replaces the suggestion bar while searching for emoji: a back button, the text typed so far
/// (typed on the normal keys below), and a scrolling strip of matching emoji.
final class EmojiSearchBar: UIView {
    weak var delegate: EmojiSearchBarDelegate?

    private let look = Theme.searchLook(besideKeys: true)
    private lazy var glass = FlatPanel(background: look.fill, allowGlass: look.glass, forceGlass: look.glass)
    private let backButton = HitButton(type: .system)
    private let hideButton = HitButton(type: .system)
    private let queryLabel = UILabel()
    private let divider = UIView()
    private let scroll = UIScrollView()
    private var resultButtons: [HitButton] = []
    private var results: [EmojiItem] = []
    /// The skin tones of a held result: a layer over the keyboard that a tap anywhere else closes.
    /// The skin tones of a held result, in the keyboard's own popup for accented characters (AlternatesPopupView).
    private var variantPopup: AlternatesPopupView?
    private var placeholder = "Search Emoji"
    private var query = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        glass.capsule = true
        addSubview(glass)

        backButton.setImage(UIImage(systemName: "chevron.left",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)),
                            for: .normal)
        backButton.tintColor = look.text
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        glass.contentView.addSubview(backButton)

        hideButton.tintColor = Theme.barIcons
        // The same drawing as the suggestion bar's hide button: a plain image view, never scaled by the button.
        let hideIcon = UIImageView(image: UIImage(systemName: "keyboard.chevron.compact.down",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular)))
        hideIcon.contentMode = .center
        hideIcon.tintColor = Theme.barIcons
        hideIcon.isUserInteractionEnabled = false
        hideIcon.tag = 77
        hideButton.addSubview(hideIcon)
        hideButton.accessibilityLabel = "Hide keyboard"
        hideButton.addTarget(self, action: #selector(hideTapped), for: .touchUpInside)
        addSubview(hideButton)


        queryLabel.font = UIFont.systemFont(ofSize: 16)
        queryLabel.lineBreakMode = .byTruncatingHead
        queryLabel.adjustsFontSizeToFitWidth = true
        queryLabel.minimumScaleFactor = 0.7
        glass.contentView.addSubview(queryLabel)

        divider.backgroundColor = look.secondaryText.withAlphaComponent(0.35)
        glass.contentView.addSubview(divider)

        scroll.showsHorizontalScrollIndicator = false
        scroll.delegate = self
        glass.contentView.addSubview(scroll)

        // Holding a result offers its other skin tones, as in the picker.
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = Prefs.emojiHoldDelay
        scroll.addGestureRecognizer(longPress)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setQuery(_ text: String, placeholder newPlaceholder: String) {
        query = text
        placeholder = newPlaceholder
        if text.isEmpty {
            queryLabel.text = placeholder
            queryLabel.textColor = look.secondaryText
        } else {
            queryLabel.text = text
            queryLabel.textColor = look.text
        }
    }

    /// The matching emoji, each in the form to show (the chosen skin tone) with its other forms to hold for.
    func setResults(_ items: [EmojiItem]) {
        dismissVariants()
        results = items
        for button in resultButtons { button.removeFromSuperview() }
        resultButtons = []
        for (index, item) in items.enumerated() {
            let button = HitButton(type: .custom)
            button.tag = index
            button.setTitle(item.base, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 28)
            button.addTarget(self, action: #selector(resultTapped(_:)), for: .touchUpInside)
            scroll.addSubview(button)
            resultButtons.append(button)
        }
        scroll.contentOffset = .zero
        setNeedsLayout()
    }

    /// Same distance from the keyboard's top edge as the picker's search field, so it does not jump when tapped.
    static var topInset: CGFloat = 5

    override func layoutSubviews() {
        super.layoutSubviews()
        // Same thickness and curve as the picker's search pill.
        let topInset = min(bounds.height - 30, EmojiSearchBar.topInset)
        let side = 6 * bounds.width / 440      // the picker's side inset
        // The pill ends where the picker's does; the hide button stays outside it, in the gap beside it.
        let hideWidth = 60 + side
        let pill = CGRect(x: side, y: topInset, width: max(0, bounds.width - 2 * side - 60), height: bounds.height - topInset)
        // (Set through bounds and centre, so it also works while the pill is being moved in (playEntrance).)
        glass.bounds = CGRect(origin: .zero, size: pill.size)
        glass.center = CGPoint(x: pill.midX, y: pill.midY)
        let area = glass.bounds

        backButton.frame = CGRect(x: 0, y: 0, width: 52, height: area.height)
        hideButton.frame = CGRect(x: pill.maxX, y: pill.minY, width: hideWidth, height: pill.height)
        hideButton.viewWithTag(77)?.frame = hideButton.bounds

        let queryWidth = min(max(110, area.width * 0.36), 170)
        // iPhone: the picker's icon and text size (iPad keeps 16pt, which the picker matches there).
        let isWide = bounds.width > 500   // the picker's wide layout (iPad, iPhone in landscape)
        let f = EmojiPanel.scale(forWidth: bounds.width)
        queryLabel.font = UIFont.systemFont(ofSize: isWide ? 16 : 20 * f)
        // (No magnifying glass here: the back arrow is the icon of the active search.)
        let queryX: CGFloat = 46
        queryLabel.frame = CGRect(x: queryX, y: 0, width: queryWidth - (queryX - 44) - 2, height: area.height)

        // The divider sits as far from the text as from the first result emoji (about 10pt each side).
        let dividerX = 44 + queryWidth + 8
        divider.frame = CGRect(x: dividerX, y: area.height * 0.25, width: 1, height: area.height * 0.5)

        scroll.frame = CGRect(x: dividerX + 4, y: 0, width: max(0, area.width - dividerX - 14), height: area.height)
        let itemWidth: CGFloat = 40
        for (index, button) in resultButtons.enumerated() {
            button.frame = CGRect(x: CGFloat(index) * itemWidth, y: 0, width: itemWidth, height: area.height)
        }
        scroll.contentSize = CGSize(width: itemWidth * CGFloat(resultButtons.count), height: area.height)
    }

    /// The search bar taking over from the picker's search field: the pill (and the placeholder in it) settles from where
    /// the picker's was, the picker's magnifying glass fades out as the back arrow fades in, and the results slide in
    /// from the right.
    func playEntrance(from source: EmojiPanel.SearchGeometry) {
        layoutIfNeeded()
        let pill = CGRect(origin: .zero, size: glass.bounds.size)
        let target = CGRect(x: glass.center.x - pill.width / 2, y: glass.center.y - pill.height / 2,
                            width: pill.width, height: pill.height)
        guard target.width > 1, target.height > 1 else { return }
        glass.transform = CGAffineTransform(translationX: source.pill.midX - target.midX, y: source.pill.midY - target.midY)
            .scaledBy(x: source.pill.width / target.width, y: source.pill.height / target.height)
        // The placeholder starts where (and as big as) the picker's was.
        let fromX = source.placeholder.minX - source.pill.minX
        let fromScale = source.font.pointSize / max(queryLabel.font.pointSize, 1)
        queryLabel.transform = CGAffineTransform(translationX: fromX - queryLabel.frame.minX, y: 0).scaledBy(x: fromScale, y: fromScale)
        // The picker's magnifying glass, fading out where it was.
        let ghost = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        ghost.tintColor = look.secondaryText
        ghost.contentMode = .scaleAspectFit
        ghost.frame = CGRect(x: source.icon.minX - source.pill.minX, y: source.icon.minY - source.pill.minY,
                             width: source.icon.width, height: source.icon.height)
        glass.contentView.addSubview(ghost)
        backButton.alpha = 0
        divider.alpha = 0
        // The results come in from the right edge of the strip, and never from beyond it (the hide button is there).
        scroll.contentOffset = CGPoint(x: -scroll.bounds.width, y: 0)
        UIView.animate(withDuration: 0.42, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.1,
                       options: [.allowUserInteraction]) {
            self.glass.transform = .identity
            self.queryLabel.transform = .identity
        }
        UIView.animate(withDuration: 0.22, delay: 0.04, options: [.curveEaseOut]) {
            ghost.alpha = 0
            self.backButton.alpha = 1
        } completion: { _ in
            ghost.removeFromSuperview()
        }
        UIView.animate(withDuration: 0.36, delay: 0.08, options: [.curveEaseOut, .allowUserInteraction]) {
            self.divider.alpha = 1
            self.scroll.contentOffset = .zero
        }
    }

    /// The way back: the results slide out to the right inside the strip, the placeholder grows back to the picker's
    /// size as the pill settles into the picker's, and the back arrow fades into the magnifying glass.
    func playExit(to target: EmojiPanel.SearchGeometry, completion: @escaping () -> Void) {
        layoutIfNeeded()
        let pill = CGRect(origin: .zero, size: glass.bounds.size)
        let here = CGRect(x: glass.center.x - pill.width / 2, y: glass.center.y - pill.height / 2,
                          width: pill.width, height: pill.height)
        guard here.width > 1, here.height > 1 else {
            completion()
            return
        }
        // The magnifying glass the arrow turns into, where the picker's is.
        let ghost = UIImageView(image: UIImage(systemName: "magnifyingglass"))
        ghost.tintColor = look.secondaryText
        ghost.contentMode = .scaleAspectFit
        ghost.frame = CGRect(x: target.icon.minX - target.pill.minX, y: target.icon.minY - target.pill.minY,
                             width: target.icon.width, height: target.icon.height)
        ghost.alpha = 0
        glass.contentView.addSubview(ghost)
        exitGhost = ghost
        let toX = target.placeholder.minX - target.pill.minX
        let toScale = target.font.pointSize / max(queryLabel.font.pointSize, 1)
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.92, initialSpringVelocity: 0.1,
                       options: [.allowUserInteraction]) {
            self.glass.transform = CGAffineTransform(translationX: target.pill.midX - here.midX, y: target.pill.midY - here.midY)
                .scaledBy(x: target.pill.width / here.width, y: target.pill.height / here.height)
            self.queryLabel.transform = CGAffineTransform(translationX: toX - self.queryLabel.frame.minX, y: 0).scaledBy(x: toScale, y: toScale)
        } completion: { _ in
            completion()
        }
        UIView.animate(withDuration: 0.22, delay: 0, options: [.curveEaseIn]) {
            self.backButton.alpha = 0
            self.divider.alpha = 0
        }
        UIView.animate(withDuration: 0.24, delay: 0.1, options: [.curveEaseOut]) {
            ghost.alpha = 1
        }
        // Out through the right end of the strip, inside it.
        UIView.animate(withDuration: 0.34, delay: 0, options: [.curveEaseIn]) {
            self.scroll.contentOffset = CGPoint(x: -self.scroll.bounds.width, y: 0)
        }
    }

    private var exitGhost: UIImageView?

    /// Puts the bar as it was after `playExit`, for the next time it is shown.
    func resetAfterExit() {
        exitGhost?.removeFromSuperview()
        exitGhost = nil
        glass.layer.removeAllAnimations()
        glass.transform = .identity
        queryLabel.transform = .identity
        backButton.alpha = 1
        divider.alpha = 1
        scroll.contentOffset = .zero
        setNeedsLayout()
    }

    /// The whole strip belongs to a control: the left end is the back button, the query area is dead
    /// (nothing to press), and the results strip takes the rest, so taps near an emoji still hit it.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, bounds.insetBy(dx: -4, dy: -4).contains(point) else { return nil }
        if point.x < 58 { return backButton }
        if point.x > glass.frame.maxX { return hideButton }
        let local = convert(point, to: scroll)
        if scroll.bounds.insetBy(dx: -6, dy: -20).contains(local) {
            let nearest = HitTesting.nearestByX(local.x, in: resultButtons, relativeTo: scroll)
            return nearest ?? scroll
        }
        return super.hitTest(point, with: event)
    }

    @objc private func backTapped() {
        dismissVariants()
        Haptics.shared.keyPress()
        delegate?.emojiSearchBarDidTapBack(self)
    }

    @objc private func hideTapped() {
        dismissVariants()
        Haptics.shared.keyPress()
        delegate?.emojiSearchBarDidTapHide(self)
    }

    @objc private func resultTapped(_ sender: UIButton) {
        guard sender.tag < results.count else { return }
        dismissVariants()
        Haptics.shared.keyPress()
        delegate?.emojiSearchBar(self, didSelect: results[sender.tag].base)
    }

    // MARK: Skin tones

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        switch recognizer.state {
        case .began:
            let point = recognizer.location(in: scroll)
            guard let button = HitTesting.nearestByX(point.x, in: resultButtons, relativeTo: scroll) as? HitButton,
                  button.tag < results.count else { return }
            let item = results[button.tag]
            guard !item.variants.isEmpty else { return }
            Haptics.shared.keyPress()
            showVariants([item.base] + item.variants, under: button)
            // The finger can now slide over the tones: the strip stays where it is.
            scroll.panGestureRecognizer.isEnabled = false
        case .changed:
            guard let host = superview else { return }
            variantPopup?.updateHighlight(hostX: recognizer.location(in: host).x)
        case .ended:
            scroll.panGestureRecognizer.isEnabled = true
            // Lifted: the lit tone is typed, as with an accent on a key.
            if let popup = variantPopup {
                let emoji = popup.selectedItem
                dismissVariants()
                Haptics.shared.keyPress()
                delegate?.emojiSearchBar(self, didSelect: emoji)
            }
        case .cancelled, .failed:
            scroll.panGestureRecognizer.isEnabled = true
            dismissVariants()
        default:
            break
        }
    }

    /// The tones of a held result in the keyboard's popup, just under the bar (the keyboard can't draw above its top
    /// edge), over the keys.
    private func showVariants(_ options: [String], under button: UIView) {
        dismissVariants()
        guard let host = superview else { return }
        let anchor = button.convert(button.bounds, to: host)
        let popup = AlternatesPopupView(alternates: options, keyFrame: anchor, hostBounds: host.bounds)
        popup.frame.origin.y = frame.maxY + 4
        host.addSubview(popup)
        variantPopup = popup
    }

    func dismissVariants() {
        variantPopup?.removeFromSuperview()
        variantPopup = nil
    }

    override func removeFromSuperview() {
        dismissVariants()
        super.removeFromSuperview()
    }

    override var isHidden: Bool {
        didSet { if isHidden { dismissVariants() } }
    }
}

extension EmojiSearchBar: UIScrollViewDelegate {
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        dismissVariants()
    }
}

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
    private lazy var glass = FlatPanel(background: look.fill, allowGlass: look.glass)
    private let backButton = HitButton(type: .system)
    private let hideButton = HitButton(type: .system)
    private let iconView = UIImageView()
    private let queryLabel = UILabel()
    private let divider = UIView()
    private let scroll = UIScrollView()
    private var resultButtons: [HitButton] = []
    private var results: [EmojiItem] = []
    /// The skin tones of a held result: a layer over the keyboard that a tap anywhere else closes.
    private var variantOverlay: UIControl?
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

        iconView.image = UIImage(systemName: "magnifyingglass")
        iconView.tintColor = look.secondaryText
        iconView.contentMode = .scaleAspectFit
        glass.contentView.addSubview(iconView)

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
        glass.frame = CGRect(x: side, y: topInset, width: max(0, bounds.width - 2 * side - 60), height: bounds.height - topInset)
        let area = glass.bounds

        backButton.frame = CGRect(x: 0, y: 0, width: 52, height: area.height)
        hideButton.frame = CGRect(x: glass.frame.maxX, y: glass.frame.minY, width: hideWidth, height: glass.frame.height)
        hideButton.viewWithTag(77)?.frame = hideButton.bounds

        let queryWidth = min(max(110, area.width * 0.36), 170)
        // iPhone: the picker's icon and text size (iPad keeps 16pt, which the picker matches there).
        let isWide = bounds.width > 500   // the picker's wide layout (iPad, iPhone in landscape)
        let f = EmojiPanel.scale(forWidth: bounds.width)
        let iconSide = isWide ? 16 : 17 * f
        queryLabel.font = UIFont.systemFont(ofSize: isWide ? 16 : 20 * f)
        iconView.frame = CGRect(x: 44, y: (area.height - iconSide) / 2, width: iconSide, height: iconSide)
        let queryX = 44 + iconSide + 6
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
        guard recognizer.state == .began else { return }
        let point = recognizer.location(in: scroll)
        guard let button = HitTesting.nearestByX(point.x, in: resultButtons, relativeTo: scroll) as? HitButton,
              button.tag < results.count else { return }
        let item = results[button.tag]
        guard !item.variants.isEmpty else { return }
        Haptics.shared.keyPress()
        showVariants([item.base] + item.variants, under: button)
    }

    /// The forms of a held result in a row like the picker's, just under the bar (the keyboard can't draw above
    /// its top edge), over the keys: a tap on one types it, a tap anywhere else closes the row.
    private func showVariants(_ options: [String], under button: UIView) {
        dismissVariants()
        guard let host = superview else { return }
        let overlay = UIControl(frame: host.bounds)
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.addAction(UIAction { [weak self] _ in self?.dismissVariants() }, for: .touchDown)

        let itemWidth: CGFloat = 44
        let height: CGFloat = 54
        let fitting = max(1, Int((host.bounds.width - 16) / itemWidth))
        let width = CGFloat(min(options.count, fitting)) * itemWidth + 12
        let anchor = button.convert(button.bounds, to: host)
        let x = max(4, min(anchor.midX - width / 2, host.bounds.width - width - 4))
        let y = frame.maxY + 4

        let container = FlatPanel(background: EmojiLook.popup, cornerRadius: 10)
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.3
        container.layer.shadowRadius = 3
        container.layer.shadowOffset = CGSize(width: 0, height: 1)
        container.frame = CGRect(x: x, y: y, width: width, height: height)

        let strip = UIScrollView(frame: CGRect(x: 6, y: 0, width: width - 12, height: height))
        strip.showsHorizontalScrollIndicator = false
        strip.contentSize = CGSize(width: itemWidth * CGFloat(options.count), height: height)
        for (index, emoji) in options.enumerated() {
            let option = HitButton(type: .custom)
            option.frame = CGRect(x: CGFloat(index) * itemWidth, y: 4, width: itemWidth, height: height - 8)
            option.titleLabel?.font = UIFont.systemFont(ofSize: 30)
            option.setTitle(emoji, for: .normal)
            option.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.dismissVariants()
                Haptics.shared.keyPress()
                self.delegate?.emojiSearchBar(self, didSelect: emoji)
            }, for: .touchUpInside)
            strip.addSubview(option)
        }
        container.contentView.addSubview(strip)
        overlay.addSubview(container)
        host.addSubview(overlay)
        variantOverlay = overlay
    }

    func dismissVariants() {
        variantOverlay?.removeFromSuperview()
        variantOverlay = nil
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

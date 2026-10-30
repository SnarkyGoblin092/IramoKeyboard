import UIKit

protocol EmojiSearchBarDelegate: AnyObject {
    func emojiSearchBar(_ bar: EmojiSearchBar, didSelect emoji: String)
    func emojiSearchBarDidTapBack(_ bar: EmojiSearchBar)
}

/// Replaces the suggestion bar while searching for emoji: a back button, the text typed so far
/// (typed on the normal keys below), and a scrolling strip of matching emoji.
final class EmojiSearchBar: UIView {
    weak var delegate: EmojiSearchBarDelegate?

    private let glass = FlatPanel(background: EmojiLook.searchField)
    private let backButton = HitButton(type: .system)
    private let iconView = UIImageView()
    private let queryLabel = UILabel()
    private let divider = UIView()
    private let scroll = UIScrollView()
    private var resultButtons: [HitButton] = []
    private var results: [String] = []
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
        backButton.tintColor = EmojiLook.text
        backButton.addTarget(self, action: #selector(backTapped), for: .touchUpInside)
        glass.contentView.addSubview(backButton)

        iconView.image = UIImage(systemName: "magnifyingglass")
        iconView.tintColor = EmojiLook.secondary
        iconView.contentMode = .scaleAspectFit
        glass.contentView.addSubview(iconView)

        queryLabel.font = UIFont.systemFont(ofSize: 16)
        queryLabel.lineBreakMode = .byTruncatingHead
        queryLabel.adjustsFontSizeToFitWidth = true
        queryLabel.minimumScaleFactor = 0.7
        glass.contentView.addSubview(queryLabel)

        divider.backgroundColor = EmojiLook.separator
        glass.contentView.addSubview(divider)

        scroll.showsHorizontalScrollIndicator = false
        glass.contentView.addSubview(scroll)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func setQuery(_ text: String, placeholder newPlaceholder: String) {
        query = text
        placeholder = newPlaceholder
        if text.isEmpty {
            queryLabel.text = placeholder
            queryLabel.textColor = EmojiLook.secondary
        } else {
            queryLabel.text = text
            queryLabel.textColor = EmojiLook.text
        }
    }

    func setResults(_ emojis: [String]) {
        results = emojis
        for button in resultButtons { button.removeFromSuperview() }
        resultButtons = []
        for (index, emoji) in emojis.enumerated() {
            let button = HitButton(type: .custom)
            button.tag = index
            button.setTitle(emoji, for: .normal)
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
        glass.frame = CGRect(x: side, y: topInset, width: max(0, bounds.width - 2 * side), height: bounds.height - topInset)
        let area = glass.bounds

        backButton.frame = CGRect(x: 0, y: 0, width: 52, height: area.height)

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

        scroll.frame = CGRect(x: dividerX + 4, y: 0, width: max(0, area.width - dividerX - 10), height: area.height)
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
        let local = convert(point, to: scroll)
        if scroll.bounds.insetBy(dx: -6, dy: -20).contains(local) {
            let nearest = HitTesting.nearestByX(local.x, in: resultButtons, relativeTo: scroll)
            return nearest ?? scroll
        }
        return super.hitTest(point, with: event)
    }

    @objc private func backTapped() {
        Haptics.shared.keyPress()
        delegate?.emojiSearchBarDidTapBack(self)
    }

    @objc private func resultTapped(_ sender: UIButton) {
        guard sender.tag < results.count else { return }
        Haptics.shared.keyPress()
        delegate?.emojiSearchBar(self, didSelect: results[sender.tag])
    }
}

import UIKit

/// The Functions panel's Clipboard: the last copied texts (newest first) as key-like rows in place of the keys.
/// Tap one to paste it; the small cross removes it; Clear removes them all.
final class ClipboardPanel: UIView {
    var onPick: ((String) -> Void)?
    var onDelete: ((String) -> Void)?
    var onClear: (() -> Void)?

    private var items: [String]
    private let titleLabel = UILabel()
    private let clearButton = HitButton(type: .system)
    private let scroll = UIScrollView()
    private let emptyLabel = UILabel()
    private var rows: [UIView] = []

    init(items: [String]) {
        self.items = items
        super.init(frame: .zero)
        // Not fully clear: the system drops touches on pixels of a keyboard that draw nothing.
        backgroundColor = UIColor(white: 0.5, alpha: 0.01)

        titleLabel.text = "Clipboard"
        titleLabel.font = Theme.keyFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = Theme.keySecondaryText
        addSubview(titleLabel)

        clearButton.setTitle("Clear", for: .normal)
        clearButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .medium)
        clearButton.tintColor = Theme.accent
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        addSubview(clearButton)

        scroll.showsVerticalScrollIndicator = false
        scroll.alwaysBounceVertical = true
        addSubview(scroll)

        emptyLabel.text = "Copy some text and it shows here."
        emptyLabel.textColor = Theme.keySecondaryText
        emptyLabel.font = UIFont.systemFont(ofSize: 15)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        addSubview(emptyLabel)

        buildRows()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func buildRows() {
        for row in rows { row.removeFromSuperview() }
        rows = []
        for item in items {
            let row = UIControl()
            let background = FlatPanel(background: Theme.letterKey, allowGlass: true, followsKeyRoundness: true, keyLike: true)
            background.isUserInteractionEnabled = false
            background.tag = 1
            row.addSubview(background)

            let label = UILabel()
            // Line breaks shown as spaces, up to two lines.
            label.text = item.components(separatedBy: .newlines).joined(separator: " ")
            label.numberOfLines = 2
            label.font = Theme.keyFont(ofSize: 15)
            label.textColor = Theme.keyText
            label.lineBreakMode = .byTruncatingTail
            label.isUserInteractionEnabled = false
            label.tag = 2
            row.addSubview(label)

            let remove = HitButton(type: .system)
            remove.setImage(UIImage(systemName: "xmark.circle.fill",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .regular)), for: .normal)
            remove.tintColor = Theme.keySecondaryText
            remove.tag = 3
            remove.accessibilityLabel = "Remove"
            remove.addAction(UIAction { [weak self] _ in self?.remove(item) }, for: .touchUpInside)
            row.addSubview(remove)

            row.addAction(UIAction { [weak self] _ in
                Haptics.shared.keyPress()
                self?.onPick?(item)
            }, for: .touchUpInside)
            row.addAction(UIAction { _ in background.alpha = 0.55 }, for: .touchDown)
            row.addAction(UIAction { _ in background.alpha = 1 }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
            row.isAccessibilityElement = true
            row.accessibilityLabel = item
            row.accessibilityHint = "Pastes this text"
            row.accessibilityTraits = .button
            scroll.addSubview(row)
            rows.append(row)
        }
        emptyLabel.isHidden = !items.isEmpty
        clearButton.isHidden = items.isEmpty
        setNeedsLayout()
    }

    private func remove(_ item: String) {
        Haptics.shared.keyPress()
        items.removeAll { $0 == item }
        onDelete?(item)
        buildRows()
    }

    @objc private func clearTapped() {
        Haptics.shared.keyPress()
        items = []
        onClear?()
        buildRows()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset: CGFloat = 8
        let header: CGFloat = 30
        titleLabel.frame = CGRect(x: inset + 4, y: 2, width: bounds.width / 2, height: header)
        clearButton.frame = CGRect(x: bounds.width - inset - 70, y: 2, width: 70, height: header)
        clearButton.contentHorizontalAlignment = .right
        scroll.frame = CGRect(x: 0, y: header + 4, width: bounds.width, height: max(0, bounds.height - header - 4))
        emptyLabel.frame = scroll.frame.insetBy(dx: 30, dy: 0)

        let gap = CGFloat(max(4, Prefs.keyGap))
        let height: CGFloat = 54
        var y: CGFloat = 0
        for row in rows {
            row.frame = CGRect(x: inset, y: y, width: bounds.width - inset * 2, height: height)
            row.viewWithTag(1)?.frame = row.bounds
            row.viewWithTag(2)?.frame = CGRect(x: 12, y: 4, width: row.bounds.width - 12 - 40, height: height - 8)
            row.viewWithTag(3)?.frame = CGRect(x: row.bounds.width - 38, y: (height - 34) / 2, width: 34, height: 34)
            y += height + gap
        }
        scroll.contentSize = CGSize(width: bounds.width, height: max(0, y - gap + inset))
    }
}

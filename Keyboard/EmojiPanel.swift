import UIKit

protocol EmojiPanelDelegate: AnyObject {
    func emojiPanel(_ panel: EmojiPanel, didSelect emoji: String)
    func emojiPanelDidTapBackspace(_ panel: EmojiPanel)
    func emojiPanelDidClose(_ panel: EmojiPanel)
}

/// A button that fires once on touch-down and then repeats while held (used for backspace).
final class RepeatingButton: UIButton {
    var onFire: (() -> Void)?
    private var holdTimer: Timer?
    private var repeatTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        addTarget(self, action: #selector(pressed), for: .touchDown)
        addTarget(self, action: #selector(released), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc private func pressed() {
        Haptics.shared.keyPress()
        onFire?()
        stopTimers()
        let timer = Timer(timeInterval: Settings.shared.holdDelay, repeats: false) { [weak self] _ in
            self?.startRepeating()
        }
        RunLoop.main.add(timer, forMode: .common)
        holdTimer = timer
    }

    private func startRepeating() {
        let timer = Timer(timeInterval: 0.06, repeats: true) { [weak self] _ in
            self?.onFire?()
        }
        RunLoop.main.add(timer, forMode: .common)
        repeatTimer = timer
    }

    @objc private func released() {
        stopTimers()
    }

    private func stopTimers() {
        holdTimer?.invalidate()
        repeatTimer?.invalidate()
        holdTimer = nil
        repeatTimer = nil
    }

    deinit {
        holdTimer?.invalidate()
        repeatTimer?.invalidate()
    }
}

private final class EmojiCell: UICollectionViewCell {
    static let reuseID = "EmojiCell"
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        contentView.addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        label.frame = contentView.bounds
    }
}

/// Full emoji picker: recents plus every group, horizontal paging, long-press for skin tones.
final class EmojiPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    weak var delegate: EmojiPanelDelegate?

    private struct Section {
        let icon: String
        let items: [EmojiItem]
    }

    private var sections: [Section] = []
    private let flowLayout = UICollectionViewFlowLayout()
    private var collectionView: UICollectionView!
    private let bottomBar = UIView()
    private let abcButton = UIButton(type: .system)
    private let backspaceButton = RepeatingButton(frame: .zero)
    private let tabStack = UIStackView()
    private var tabButtons: [UIButton] = []
    private let statusLabel = UILabel()
    private var variantPopup: UIView?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.panelBackground

        flowLayout.scrollDirection = .horizontal
        flowLayout.minimumInteritemSpacing = 0
        flowLayout.minimumLineSpacing = 0
        flowLayout.sectionInset = UIEdgeInsets(top: 0, left: 6, bottom: 0, right: 6)
        flowLayout.itemSize = CGSize(width: 44, height: 44)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: flowLayout)
        collectionView.backgroundColor = UIColor.clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseID)
        addSubview(collectionView)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = max(0.25, Settings.shared.holdDelay)
        collectionView.addGestureRecognizer(longPress)

        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor.secondaryLabel
        statusLabel.font = UIFont.systemFont(ofSize: 15)
        statusLabel.numberOfLines = 0
        addSubview(statusLabel)

        addSubview(bottomBar)

        abcButton.setTitle("ABC", for: .normal)
        abcButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        abcButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        bottomBar.addSubview(abcButton)

        backspaceButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        backspaceButton.tintColor = UIColor.label
        backspaceButton.onFire = { [weak self] in
            guard let self = self else { return }
            self.delegate?.emojiPanelDidTapBackspace(self)
        }
        bottomBar.addSubview(backspaceButton)

        tabStack.axis = .horizontal
        tabStack.distribution = .fillEqually
        bottomBar.addSubview(tabStack)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Content

    /// Rebuilds the sections (recents first). Safe to call before the emoji data has loaded.
    func reload() {
        dismissVariantPopup()
        let store = EmojiStore.shared

        guard store.isReady else {
            sections = []
            statusLabel.text = "Loading emoji…"
            statusLabel.isHidden = false
            rebuildTabs()
            collectionView.reloadData()
            return
        }

        var built: [Section] = []
        let recents = Settings.shared.recentEmoji
        if !recents.isEmpty {
            built.append(Section(icon: "🕘", items: recents.map { EmojiItem(base: $0, variants: []) }))
        }
        for group in store.groups {
            built.append(Section(icon: group.icon, items: group.items))
        }
        sections = built

        if built.isEmpty {
            statusLabel.text = "No emoji data found in this build."
            statusLabel.isHidden = false
        } else {
            statusLabel.isHidden = true
        }
        rebuildTabs()
        collectionView.reloadData()
        collectionView.setContentOffset(.zero, animated: false)
        updateSelectedTab()
    }

    private func rebuildTabs() {
        for button in tabButtons { button.removeFromSuperview() }
        tabButtons = []
        for (index, section) in sections.enumerated() {
            let button = UIButton(type: .custom)
            button.setTitle(section.icon, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 20)
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabStack.addArrangedSubview(button)
            tabButtons.append(button)
        }
    }

    private func updateSelectedTab() {
        let visible = collectionView.indexPathsForVisibleItems.map { $0.section }
        let current = visible.min() ?? 0
        for (index, button) in tabButtons.enumerated() {
            button.alpha = (index == current) ? 1.0 : 0.4
        }
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let barHeight: CGFloat = 42
        bottomBar.frame = CGRect(x: 0, y: bounds.height - barHeight, width: bounds.width, height: barHeight)
        collectionView.frame = CGRect(x: 0, y: 0, width: bounds.width, height: bounds.height - barHeight)
        statusLabel.frame = collectionView.frame.insetBy(dx: 20, dy: 0)

        abcButton.frame = CGRect(x: 6, y: 4, width: 54, height: barHeight - 8)
        backspaceButton.frame = CGRect(x: bounds.width - 60, y: 4, width: 54, height: barHeight - 8)
        tabStack.frame = CGRect(x: 64, y: 0, width: max(0, bounds.width - 128), height: barHeight)

        let height = collectionView.bounds.height
        guard height > 0 else { return }
        let rows = max(2, Int(height / 44))
        let side = floor(height / CGFloat(rows))
        if abs(flowLayout.itemSize.height - side) > 0.5 {
            flowLayout.itemSize = CGSize(width: side, height: side)
            flowLayout.invalidateLayout()
        }
    }

    // MARK: Actions

    @objc private func closeTapped() {
        delegate?.emojiPanelDidClose(self)
    }

    @objc private func tabTapped(_ sender: UIButton) {
        dismissVariantPopup()
        let section = sender.tag
        guard section < sections.count else { return }
        if collectionView.numberOfItems(inSection: section) > 0 {
            collectionView.scrollToItem(at: IndexPath(item: 0, section: section), at: .left, animated: false)
        }
        updateSelectedTab()
    }

    @objc private func handleLongPress(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        let point = recognizer.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: point),
              let cell = collectionView.cellForItem(at: indexPath) else { return }
        let item = sections[indexPath.section].items[indexPath.item]
        guard !item.variants.isEmpty else { return }
        Haptics.shared.keyPress()
        showVariants([item.base] + item.variants, above: cell)
    }

    private func showVariants(_ options: [String], above cell: UICollectionViewCell) {
        dismissVariantPopup()
        let cellFrame = collectionView.convert(cell.frame, to: self)
        let itemWidth: CGFloat = 46
        let fitting = max(1, Int((bounds.width - 16) / itemWidth))
        let visibleCount = min(options.count, fitting)
        let width = CGFloat(visibleCount) * itemWidth + 8
        let height: CGFloat = 54

        var x = cellFrame.midX - width / 2
        x = max(4, min(x, bounds.width - width - 4))
        var y = cellFrame.minY - height - 2
        if y < 0 { y = cellFrame.maxY + 2 }

        let container = UIView(frame: CGRect(x: x, y: y, width: width, height: height))
        container.backgroundColor = Theme.letterKey
        container.layer.cornerRadius = 10
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.3
        container.layer.shadowRadius = 4
        container.layer.shadowOffset = CGSize(width: 0, height: 1)

        let scroll = UIScrollView(frame: container.bounds.insetBy(dx: 4, dy: 0))
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentSize = CGSize(width: itemWidth * CGFloat(options.count), height: height)
        for (index, emoji) in options.enumerated() {
            let button = UIButton(type: .custom)
            button.frame = CGRect(x: CGFloat(index) * itemWidth, y: 4, width: itemWidth, height: height - 8)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 32)
            button.setTitle(emoji, for: .normal)
            button.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.dismissVariantPopup()
                self.delegate?.emojiPanel(self, didSelect: emoji)
            }, for: .touchUpInside)
            scroll.addSubview(button)
        }
        container.addSubview(scroll)
        addSubview(container)
        variantPopup = container
    }

    private func dismissVariantPopup() {
        variantPopup?.removeFromSuperview()
        variantPopup = nil
    }

    // MARK: UICollectionViewDataSource / Delegate

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.reuseID, for: indexPath)
        if let emojiCell = cell as? EmojiCell {
            emojiCell.label.font = UIFont.systemFont(ofSize: flowLayout.itemSize.height * 0.66)
            emojiCell.label.text = sections[indexPath.section].items[indexPath.item].base
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        dismissVariantPopup()
        Haptics.shared.keyPress()
        delegate?.emojiPanel(self, didSelect: sections[indexPath.section].items[indexPath.item].base)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        if scrollView === collectionView {
            dismissVariantPopup()
            updateSelectedTab()
        }
    }
}

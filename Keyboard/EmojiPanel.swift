import UIKit

protocol EmojiPanelDelegate: AnyObject {
    func emojiPanel(_ panel: EmojiPanel, didSelect emoji: String)
    func emojiPanelDidTapBackspace(_ panel: EmojiPanel)
    func emojiPanelDidTapSearch(_ panel: EmojiPanel)
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

// MARK: - Grid layout

/// Emoji are laid out in pages (rows x columns, filled row by row), and every category starts on a
/// fresh page - the same arrangement as the system emoji keyboard.
private final class EmojiGridLayout: UICollectionViewLayout {
    var rows = 4
    var edgeInset: CGFloat = 8

    private(set) var columns = 8
    private(set) var cellSize = CGSize(width: 44, height: 40)
    private(set) var sectionStartX: [CGFloat] = []
    private(set) var pageWidth: CGFloat = 0

    private var cache: [UICollectionViewLayoutAttributes] = []
    private var contentWidth: CGFloat = 0

    override func prepare() {
        super.prepare()
        cache = []
        sectionStartX = []
        guard let collectionView = collectionView else { return }

        pageWidth = collectionView.bounds.width
        let usableWidth = pageWidth - edgeInset * 2
        let height = collectionView.bounds.height
        contentWidth = 0
        guard pageWidth > 0, height > 0 else { return }

        columns = max(4, Int(usableWidth / 42))
        cellSize = CGSize(width: usableWidth / CGFloat(columns), height: height / CGFloat(rows))
        let perPage = rows * columns

        var pageStart: CGFloat = 0
        for section in 0..<collectionView.numberOfSections {
            sectionStartX.append(pageStart)
            let count = collectionView.numberOfItems(inSection: section)
            for item in 0..<count {
                let page = item / perPage
                let slot = item % perPage
                let row = slot / columns
                let column = slot % columns
                let attributes = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: item, section: section))
                attributes.frame = CGRect(x: pageStart + CGFloat(page) * pageWidth + edgeInset + CGFloat(column) * cellSize.width,
                                          y: CGFloat(row) * cellSize.height,
                                          width: cellSize.width,
                                          height: cellSize.height)
                cache.append(attributes)
            }
            let pages = max(1, (count + perPage - 1) / perPage)
            pageStart += CGFloat(pages) * pageWidth
        }
        contentWidth = pageStart
    }

    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: collectionView?.bounds.height ?? 0)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return cache.first { $0.indexPath == indexPath }
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        guard let collectionView = collectionView else { return false }
        return newBounds.size != collectionView.bounds.size
    }
}

private final class EmojiCell: UICollectionViewCell {
    static let reuseID = "EmojiCell"
    let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
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

// MARK: - Panel

/// The emoji keyboard: search field on top, a horizontally paged grid with the category name,
/// and a bottom bar with ABC, the category tabs (including Recently Used) and delete.
final class EmojiPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    weak var delegate: EmojiPanelDelegate?
    var language: Language = .english

    private struct Section {
        let key: String
        let symbol: String
        let fallback: String
        let title: String
        let items: [EmojiItem]
    }

    private var sections: [Section] = []
    private let gridLayout = EmojiGridLayout()
    private var collectionView: UICollectionView!

    private let searchGlass = FlatPanel(background: Theme.searchField, cornerRadius: 10)
    private let searchButton = UIButton(type: .system)
    private let searchIcon = UIImageView()
    private let searchLabel = UILabel()

    private let titleLabel = UILabel()
    private let emptyLabel = UILabel()

    private let tabGlass = FlatPanel()
    private let abcButton = UIButton(type: .system)
    private let backspaceButton = RepeatingButton(frame: .zero)
    private var tabButtons: [UIButton] = []
    private var currentSection = 0
    private var startSection = 0
    private var needsInitialScroll = false
    private var variantPopup: UIView?

    private let searchHeight: CGFloat = 36
    private let titleHeight: CGFloat = 18
    private let barHeight: CGFloat = 44

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = Theme.panelBackground   // opaque, so nothing shows through from behind

        // Search field
        addSubview(searchGlass)
        searchIcon.image = UIImage(systemName: "magnifyingglass")
        searchIcon.tintColor = UIColor.secondaryLabel
        searchIcon.contentMode = .scaleAspectFit
        searchLabel.font = UIFont.systemFont(ofSize: 16)
        searchLabel.textColor = UIColor.secondaryLabel
        searchGlass.contentView.addSubview(searchIcon)
        searchGlass.contentView.addSubview(searchLabel)
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        searchGlass.contentView.addSubview(searchButton)

        // Section title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = UIColor.secondaryLabel
        addSubview(titleLabel)

        // Grid
        gridLayout.rows = 4
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collectionView.backgroundColor = UIColor.clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.decelerationRate = .fast
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseID)
        addSubview(collectionView)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = max(0.25, Settings.shared.holdDelay)
        collectionView.addGestureRecognizer(longPress)

        emptyLabel.textAlignment = .center
        emptyLabel.textColor = UIColor.secondaryLabel
        emptyLabel.font = UIFont.systemFont(ofSize: 15)
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        emptyLabel.isUserInteractionEnabled = false
        addSubview(emptyLabel)

        // Bottom bar
        addSubview(tabGlass)
        abcButton.setTitle("ABC", for: .normal)
        abcButton.setTitleColor(UIColor.label, for: .normal)
        abcButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        abcButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(abcButton)

        backspaceButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        backspaceButton.tintColor = UIColor.label
        backspaceButton.onFire = { [weak self] in
            guard let self = self else { return }
            self.delegate?.emojiPanelDidTapBackspace(self)
        }
        addSubview(backspaceButton)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Content

    /// Rebuilds the tabs (Recently Used always comes first, even when empty).
    /// Safe to call before the emoji data has loaded.
    func reload() {
        dismissVariantPopup()
        searchLabel.text = language.strings.searchEmoji

        let store = EmojiStore.shared
        var built: [Section] = []

        let recents = Settings.shared.recentEmoji.map { EmojiItem(base: $0, variants: []) }
        built.append(Section(key: "recent",
                             symbol: EmojiCategory.recentSymbol,
                             fallback: EmojiCategory.recentFallback,
                             title: recentTitle(),
                             items: recents))

        for category in store.categories {
            built.append(Section(key: category.key,
                                 symbol: category.symbol,
                                 fallback: category.fallbackIcon,
                                 title: category.title(for: language),
                                 items: category.items))
        }
        sections = built
        rebuildTabs()
        collectionView.reloadData()
        collectionView.collectionViewLayout.invalidateLayout()

        // Start on Recently Used when there is history, otherwise on the first real category.
        // The grid can only scroll once it has a real size, so the scroll is done in layoutSubviews
        // (this was the "empty until I tap a tab" bug: reload() ran while the panel still had zero size).
        startSection = (recents.isEmpty && built.count > 1) ? 1 : 0
        currentSection = startSection
        needsInitialScroll = true
        refreshTabHighlight()
        updateEmptyState()
        setNeedsLayout()
        applyInitialScrollIfPossible()
    }

    private func applyInitialScrollIfPossible() {
        guard needsInitialScroll,
              collectionView.bounds.width > 0, collectionView.bounds.height > 0,
              !sections.isEmpty else { return }
        collectionView.layoutIfNeeded()          // computes the grid with the real size
        guard gridLayout.sectionStartX.count == sections.count else { return }
        let target = min(startSection, sections.count - 1)
        collectionView.setContentOffset(CGPoint(x: gridLayout.sectionStartX[target], y: 0), animated: false)
        needsInitialScroll = false
        currentSection = target
        refreshTabHighlight()
        updateEmptyState()
    }

    private func recentTitle() -> String {
        return language.strings.recentlyUsed
    }

    private func updateEmptyState() {
        let store = EmojiStore.shared
        if !store.isReady {
            emptyLabel.text = language.strings.loadingEmoji
            emptyLabel.isHidden = false
        } else if store.categories.isEmpty {
            emptyLabel.text = "No emoji data found in this build."
            emptyLabel.isHidden = false
        } else if currentSection == 0, let first = sections.first, first.items.isEmpty {
            emptyLabel.text = language.strings.emptyRecents
            emptyLabel.isHidden = false
        } else {
            emptyLabel.isHidden = true     // never covers emoji that are on screen
        }
    }

    private func rebuildTabs() {
        for button in tabButtons { button.removeFromSuperview() }
        tabButtons = []
        for (index, section) in sections.enumerated() {
            let button = UIButton(type: .system)
            if let image = UIImage(systemName: section.symbol,
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular)) {
                button.setImage(image, for: .normal)
            } else {
                button.setTitle(section.fallback, for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            }
            button.tag = index
            button.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
            tabGlass.contentView.addSubview(button)
            tabButtons.append(button)
        }
        layoutTabs()
        refreshTabHighlight()
    }

    private func refreshTabHighlight() {
        for (index, button) in tabButtons.enumerated() {
            let selected = (index == currentSection)
            button.tintColor = selected ? UIColor.label : UIColor.tertiaryLabel
            button.alpha = selected ? 1.0 : 0.85
        }
        if currentSection < sections.count {
            titleLabel.text = sections[currentSection].title.uppercased()
        }
    }

    private func scrollToSection(_ section: Int, animated: Bool) {
        guard section < sections.count else { return }
        currentSection = section
        collectionView.layoutIfNeeded()
        if section < gridLayout.sectionStartX.count {
            collectionView.setContentOffset(CGPoint(x: gridLayout.sectionStartX[section], y: 0), animated: animated)
        }
        refreshTabHighlight()
        updateEmptyState()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width

        searchGlass.frame = CGRect(x: 10, y: 5, width: width - 20, height: searchHeight)
        searchButton.frame = searchGlass.bounds
        searchIcon.frame = CGRect(x: 14, y: (searchHeight - 18) / 2, width: 18, height: 18)
        searchLabel.frame = CGRect(x: 40, y: 0, width: searchGlass.bounds.width - 56, height: searchHeight)

        titleLabel.frame = CGRect(x: 14, y: searchGlass.frame.maxY + 4, width: width - 28, height: titleHeight)

        let gridTop = titleLabel.frame.maxY
        let gridHeight = max(0, bounds.height - gridTop - barHeight)
        let newGridFrame = CGRect(x: 0, y: gridTop, width: width, height: gridHeight)
        if collectionView.frame != newGridFrame {
            collectionView.frame = newGridFrame
            gridLayout.rows = gridHeight >= 150 ? 4 : 3
            gridLayout.invalidateLayout()
        }
        emptyLabel.frame = newGridFrame.insetBy(dx: 30, dy: 0)

        let barTop = bounds.height - barHeight
        abcButton.frame = CGRect(x: 8, y: barTop + 4, width: 52, height: barHeight - 8)
        backspaceButton.frame = CGRect(x: width - 60, y: barTop + 4, width: 52, height: barHeight - 8)
        tabGlass.frame = CGRect(x: 64, y: barTop + 4, width: max(0, width - 128), height: barHeight - 8)
        layoutTabs()
        applyInitialScrollIfPossible()
    }

    private func layoutTabs() {
        guard !tabButtons.isEmpty else { return }
        let area = tabGlass.bounds
        let width = area.width / CGFloat(tabButtons.count)
        for (index, button) in tabButtons.enumerated() {
            button.frame = CGRect(x: CGFloat(index) * width, y: 0, width: width, height: area.height)
        }
    }

    // MARK: Actions

    @objc private func closeTapped() {
        Haptics.shared.keyPress()
        delegate?.emojiPanelDidClose(self)
    }

    @objc private func searchTapped() {
        Haptics.shared.keyPress()
        delegate?.emojiPanelDidTapSearch(self)
    }

    @objc private func tabTapped(_ sender: UIButton) {
        Haptics.shared.keyPress()
        dismissVariantPopup()
        scrollToSection(sender.tag, animated: true)
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
        let itemWidth: CGFloat = 44
        let fitting = max(1, Int((bounds.width - 16) / itemWidth))
        let visibleCount = min(options.count, fitting)
        let width = CGFloat(visibleCount) * itemWidth + 12
        let height: CGFloat = 54

        var x = cellFrame.midX - width / 2
        x = max(4, min(x, bounds.width - width - 4))
        var y = cellFrame.minY - height - 2
        if y < 0 { y = cellFrame.maxY + 2 }

        let container = FlatPanel(background: Theme.letterKey, cornerRadius: 10)
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.3
        container.layer.shadowRadius = 3
        container.layer.shadowOffset = CGSize(width: 0, height: 1)
        container.frame = CGRect(x: x, y: y, width: width, height: height)

        let scroll = UIScrollView(frame: CGRect(x: 6, y: 0, width: width - 12, height: height))
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentSize = CGSize(width: itemWidth * CGFloat(options.count), height: height)
        for (index, emoji) in options.enumerated() {
            let button = UIButton(type: .custom)
            button.frame = CGRect(x: CGFloat(index) * itemWidth, y: 4, width: itemWidth, height: height - 8)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 30)
            button.setTitle(emoji, for: .normal)
            button.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.dismissVariantPopup()
                Haptics.shared.keyPress()
                self.delegate?.emojiPanel(self, didSelect: emoji)
            }, for: .touchUpInside)
            scroll.addSubview(button)
        }
        container.contentView.addSubview(scroll)
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
            let side = min(gridLayout.cellSize.width, gridLayout.cellSize.height)
            emojiCell.label.font = UIFont.systemFont(ofSize: side * 0.72)
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
        guard scrollView === collectionView, !needsInitialScroll else { return }
        dismissVariantPopup()

        // The current category is the last one whose first page has started to scroll into view.
        let probe = scrollView.contentOffset.x + gridLayout.pageWidth * 0.5
        var section = 0
        for (index, start) in gridLayout.sectionStartX.enumerated() where start <= probe {
            section = index
        }
        if section != currentSection {
            currentSection = section
            refreshTabHighlight()
            updateEmptyState()
        }
    }

    func scrollViewWillEndDragging(_ scrollView: UIScrollView,
                                   withVelocity velocity: CGPoint,
                                   targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        // Settle on a page boundary, like flicking between pages.
        guard scrollView === collectionView, gridLayout.pageWidth > 0 else { return }
        let page = (targetContentOffset.pointee.x / gridLayout.pageWidth).rounded()
        targetContentOffset.pointee.x = page * gridLayout.pageWidth
    }
}

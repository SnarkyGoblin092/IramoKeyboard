import UIKit

protocol EmojiPanelDelegate: AnyObject {
    func emojiPanel(_ panel: EmojiPanel, didSelect emoji: String)
    func emojiPanelDidTapBackspace(_ panel: EmojiPanel)
    func emojiPanelDidTapSearch(_ panel: EmojiPanel)
    func emojiPanelDidClose(_ panel: EmojiPanel)
    func emojiPanel(_ panel: EmojiPanel, didSelectSticker emoji: String, image: UIImage)
}

/// Renders an emoji as a large transparent image, used as a sticker.
enum StickerRenderer {
    static func image(for emoji: String, side: CGFloat = 512) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
        return renderer.image { _ in
            let font = UIFont.systemFont(ofSize: side * 0.78)
            let attributes: [NSAttributedString.Key: Any] = [.font: font]
            let text = emoji as NSString
            let size = text.size(withAttributes: attributes)
            text.draw(at: CGPoint(x: (side - size.width) / 2, y: (side - size.height) / 2), withAttributes: attributes)
        }
    }

    static let recentsKey = "hunkeys.recentStickers"

    static func recents() -> [String] {
        return SharedStore.defaults.stringArray(forKey: recentsKey) ?? []
    }

    static func remember(_ emoji: String) {
        var list = recents().filter { $0 != emoji }
        list.insert(emoji, at: 0)
        SharedStore.defaults.set(Array(list.prefix(24)), forKey: recentsKey)
    }
}

/// A button that fires once on touch-down and then repeats while held (used for backspace).
final class RepeatingButton: HitButton {
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
        let timer = Timer(timeInterval: Prefs.holdDelay, repeats: false) { [weak self] _ in
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

/// Emoji flow in columns (top to bottom, then left to right) like the system emoji keyboard, in one
/// continuous strip that scrolls freely. Categories follow each other with a small gap.
private final class EmojiGridLayout: UICollectionViewLayout {
    var rows = 4
    var edgeInset: CGFloat = 0
    var sectionGap: CGFloat = 0
    /// Band at the top of the strip for the category names (they scroll with the content, like stock).
    var headerHeight: CGFloat = 0

    private(set) var cellSize = CGSize(width: 40, height: 40)
    /// The content offset that puts each category's first column at the left edge.
    private(set) var sectionStartX: [CGFloat] = []
    private(set) var viewWidth: CGFloat = 0

    private var cache: [UICollectionViewLayoutAttributes] = []
    private var byPath: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentWidth: CGFloat = 0

    override func prepare() {
        super.prepare()
        cache = []
        byPath = [:]
        sectionStartX = []
        contentWidth = 0
        guard let collectionView = collectionView else { return }

        viewWidth = collectionView.bounds.width
        let height = collectionView.bounds.height
        guard viewWidth > 0, height > 0, rows > 0 else { return }

        let side = max(1, (height - headerHeight) / CGFloat(rows))
        // About eight columns across the screen, like the stock picker.
        cellSize = CGSize(width: max(36, viewWidth / 8), height: side)

        var x = edgeInset
        for section in 0..<collectionView.numberOfSections {
            sectionStartX.append(x - edgeInset)
            let count = collectionView.numberOfItems(inSection: section)
            for item in 0..<count {
                let column = item / rows
                let row = item % rows
                let path = IndexPath(item: item, section: section)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: path)
                attributes.frame = CGRect(x: x + CGFloat(column) * cellSize.width,
                                          y: headerHeight + CGFloat(row) * cellSize.height,
                                          width: cellSize.width,
                                          height: cellSize.height)
                cache.append(attributes)
                byPath[path] = attributes
            }
            if count == 0 {
                x += viewWidth - edgeInset * 2          // an empty tab (Recently Used) still owns one screen
            } else {
                let columns = (count + rows - 1) / rows
                x += CGFloat(columns) * cellSize.width
            }
            x += sectionGap
        }
        // Room so that even the last category can be scrolled to the left edge.
        let lastStart = (sectionStartX.last ?? 0)
        contentWidth = max(x + edgeInset, lastStart + viewWidth)
    }

    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: collectionView?.bounds.height ?? 0)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        return cache.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        return byPath[indexPath]
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

/// The emoji keyboard: search field on top, a smoothly scrolling emoji strip with the category name,
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
    private let stickerLayout = UICollectionViewFlowLayout()
    private var stickerView: UICollectionView!
    private var stickerItems: [String] = []
    private var stickerMode = false
    private var headerLabels: [UILabel] = []
    private let stickerHeader = UILabel()

    private let searchGlass = FlatPanel(background: Theme.searchField, cornerRadius: 20, keyLike: true)
    private let searchButton = HitButton(type: .system)
    private let searchIcon = UIImageView()
    private let searchLabel = UILabel()

    private let titleLabel = UILabel()
    private let emptyLabel = UILabel()

    private let tabGlass = FlatPanel(background: EmojiPanel.tabBarFill, followsKeyRoundness: true, keyLike: true)
    private let tabSelection = FlatPanel(background: EmojiPanel.selectionFill, cornerRadius: 100)
    private let tabUnderline = UIView()
    private let abcPanel = FlatPanel(background: EmojiPanel.buttonFill, allowGlass: true, followsKeyRoundness: true, keyLike: true)
    private let deletePanel = FlatPanel(background: EmojiPanel.buttonFill, allowGlass: true, followsKeyRoundness: true, keyLike: true)
    private let abcButton = HitButton(type: .system)
    private let backspaceButton = RepeatingButton(frame: .zero)
    private var tabButtons: [HitButton] = []
    private var currentSection = 0
    private var startSection = 0
    private var needsInitialScroll = false
    private var isProgrammaticScroll = false
    private var variantPopup: UIView?

    /// Fill behind the selected category tab (the native theme keeps a flat bar and only changes the icon colour).
    private static var selectionFill: UIColor {
        if Theme.kind == .native { return Theme.separator }
        return Theme.accent.withAlphaComponent(0.28)
    }

    /// Fill behind the ABC and delete buttons: a function-key look in the themed keyboards, nothing in native.
    /// The tab container: key-coloured with the key outline in themed keyboards, flat in native.
    private static var tabBarFill: UIColor {
        return Theme.kind == .native ? UIColor.clear : Theme.letterKey
    }

    private static var buttonFill: UIColor {
        return Theme.kind == .native ? UIColor.clear : Theme.functionKey
    }

    // These shrink on short keyboards (landscape, small height scale) so the panel always fits exactly.
    private var searchHeight: CGFloat = 36
    private var titleHeight: CGFloat = 18
    private var barHeight: CGFloat = 44

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear   // the keyboard's own backdrop (system / gradient / glass) shows; the key stage is hidden while this is open

        // Search field
        addSubview(searchGlass)
        searchIcon.image = UIImage(systemName: "magnifyingglass")
        searchIcon.tintColor = Theme.secondaryText
        searchIcon.contentMode = .scaleAspectFit
        searchLabel.font = UIFont.systemFont(ofSize: 17)
        searchLabel.textColor = Theme.secondaryText
        searchGlass.contentView.addSubview(searchIcon)
        searchGlass.contentView.addSubview(searchLabel)
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        searchGlass.contentView.addSubview(searchButton)

        // Section title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = Theme.secondaryText
        addSubview(titleLabel)

        // Grid
        gridLayout.rows = 4
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collectionView.backgroundColor = UIColor.clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseID)
        addSubview(collectionView)

        stickerLayout.scrollDirection = .horizontal
        stickerLayout.minimumInteritemSpacing = 0
        stickerLayout.minimumLineSpacing = 0
        stickerLayout.sectionInset = UIEdgeInsets(top: 0, left: 8, bottom: 0, right: 8)
        stickerView = UICollectionView(frame: .zero, collectionViewLayout: stickerLayout)
        stickerView.backgroundColor = UIColor.clear
        stickerView.showsHorizontalScrollIndicator = false
        stickerView.alwaysBounceHorizontal = true
        stickerView.dataSource = self
        stickerView.delegate = self
        stickerView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseID)
        stickerView.isHidden = true
        addSubview(stickerView)
        stickerHeader.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        stickerHeader.textColor = Theme.secondaryText
        stickerHeader.isUserInteractionEnabled = false
        stickerView.addSubview(stickerHeader)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = max(0.25, Prefs.holdDelay)
        collectionView.addGestureRecognizer(longPress)

        emptyLabel.textAlignment = .center
        emptyLabel.textColor = Theme.secondaryText
        emptyLabel.font = UIFont.systemFont(ofSize: 15)
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = true
        emptyLabel.isUserInteractionEnabled = false
        addSubview(emptyLabel)

        // Bottom bar
        addSubview(abcPanel)
        addSubview(deletePanel)
        addSubview(tabGlass)
        tabSelection.isUserInteractionEnabled = false
        tabGlass.contentView.addSubview(tabSelection)
        tabUnderline.isUserInteractionEnabled = false
        abcButton.setTitle("ABC", for: .normal)
        abcButton.setTitleColor(Theme.secondaryText, for: .normal)
        abcButton.titleLabel?.font = UIFont.systemFont(ofSize: 15, weight: .regular)
        abcButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(abcButton)

        backspaceButton.setImage(UIImage(systemName: "delete.left"), for: .normal)
        backspaceButton.tintColor = Theme.text
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

        var stickers = StickerRenderer.recents()
        for category in store.categories {
            for item in category.items where !stickers.contains(item.base) { stickers.append(item.base) }
        }
        stickerItems = stickers
        stickerMode = false
        stickerView.isHidden = true
        collectionView.isHidden = false
        stickerView.reloadData()
        rebuildHeaders()
        rebuildTabs()
        collectionView.reloadData()
        collectionView.collectionViewLayout.invalidateLayout()

        // Always start on Recently Used (its hint is shown while it is empty).
        // The grid can only scroll once it has a real size, so the scroll is done in layoutSubviews
        // (this was the "empty until I tap a tab" bug: reload() ran while the panel still had zero size).
        startSection = 0
        currentSection = startSection
        needsInitialScroll = true
        refreshTabHighlight()
        updateEmptyState()
        setNeedsLayout()
        applyInitialScrollIfPossible()
    }

    /// Category names live inside the scrolling strip, so they move with their emoji.
    private func rebuildHeaders() {
        // The stock picker has no titles inside the grid: it is purely emoji.
        for label in headerLabels { label.removeFromSuperview() }
        headerLabels = []
        stickerHeader.removeFromSuperview()
    }

    private func positionHeaders() {
        // (no headers any more)
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
        if stickerMode {
            emptyLabel.isHidden = true
        } else if !store.isReady {
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
            let button = HitButton(type: .system)
            if let image = UIImage(systemName: section.symbol,
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .light)) {
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
        // Stickers tab (last).
        let stickerButton = HitButton(type: .system)
        if let image = UIImage(systemName: "photo.on.rectangle",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .light)) {
            stickerButton.setImage(image, for: .normal)
        } else {
            stickerButton.setTitle("🏷", for: .normal)
        }
        stickerButton.tag = sections.count
        stickerButton.accessibilityLabel = language.stickersTitle
        stickerButton.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)
        tabGlass.contentView.addSubview(stickerButton)
        tabButtons.append(stickerButton)
        layoutTabs()
        refreshTabHighlight()
    }

    private func refreshTabHighlight() {
        for (index, button) in tabButtons.enumerated() {
            let selected = (index == selectedTabIndex)
            button.tintColor = selected ? Theme.text : Theme.secondaryText.withAlphaComponent(0.7)
            button.alpha = selected ? 1.0 : 0.85
        }
        if stickerMode {
            titleLabel.text = language.stickersTitle.uppercased()
        } else if currentSection < sections.count {
            titleLabel.text = sections[currentSection].title.uppercased()
        }
        positionTabSelection(animated: true)
    }

    private var selectedTabIndex: Int { return stickerMode ? sections.count : currentSection }

    private func positionTabSelection(animated: Bool) {
        guard selectedTabIndex < tabButtons.count, tabGlass.bounds.height > 0 else {
            tabSelection.isHidden = true
            tabUnderline.isHidden = true
            return
        }
        tabSelection.isHidden = false
        tabUnderline.isHidden = false
        tabUnderline.backgroundColor = Theme.accent
        tabUnderline.layer.cornerRadius = 1
        let buttonFrame = tabButtons[selectedTabIndex].frame
        let circle = max(0, min(buttonFrame.width, buttonFrame.height) - 4)
        let target = CGRect(x: buttonFrame.midX - circle / 2, y: buttonFrame.midY - circle / 2, width: circle, height: circle)
        let underlineTarget = CGRect(x: buttonFrame.midX - 9, y: buttonFrame.maxY - 3, width: 18, height: 2)
        tabGlass.contentView.addSubview(tabUnderline)
        tabGlass.contentView.sendSubviewToBack(tabSelection)
        if animated && tabSelection.frame != .zero {
            UIView.animate(withDuration: 0.16, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.tabSelection.frame = target
                self.tabUnderline.frame = underlineTarget
            }
        } else {
            tabSelection.frame = target
            tabUnderline.frame = underlineTarget
        }
    }

    private func setStickerMode(_ on: Bool) {
        guard stickerMode != on else { return }
        stickerMode = on
        stickerView.isHidden = !on
        collectionView.isHidden = on
        if on { stickerView.setContentOffset(.zero, animated: false) }
    }

    private func scrollToSection(_ section: Int, animated: Bool) {
        if section == sections.count {
            dismissVariantPopup()
            setStickerMode(true)
            refreshTabHighlight()
            updateEmptyState()
            return
        }
        guard section < sections.count else { return }
        let wasSticker = stickerMode
        setStickerMode(false)
        currentSection = section
        collectionView.layoutIfNeeded()
        if section < gridLayout.sectionStartX.count {
            // Smooth scroll; the highlight stays on the tapped tab until the scroll settles.
            let maxOffset = max(0, collectionView.contentSize.width - collectionView.bounds.width)
            let target = min(gridLayout.sectionStartX[section], maxOffset)
            isProgrammaticScroll = animated && !wasSticker
            collectionView.setContentOffset(CGPoint(x: target, y: 0), animated: animated && !wasSticker)
        }
        refreshTabHighlight()
        updateEmptyState()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width

        let total = bounds.height
        let showTitle = false
        gridLayout.headerHeight = 0
        let tall = total >= 250
        searchHeight = tall ? 40 : (total >= 190 ? 34 : 30)
        barHeight = tall ? 44 : (total >= 190 ? 40 : 36)
        let searchTop: CGFloat = tall ? 9 : 6
        let searchGap: CGFloat = tall ? 17 : (total >= 190 ? 10 : 6)
        titleLabel.isHidden = true

        searchGlass.frame = CGRect(x: 9, y: searchTop, width: width - 18, height: searchHeight)
        searchButton.frame = searchGlass.bounds
        searchIcon.frame = CGRect(x: 14, y: (searchHeight - 18) / 2, width: 18, height: 18)
        searchLabel.frame = CGRect(x: 40, y: 0, width: searchGlass.bounds.width - 56, height: searchHeight)

        let gridTop = searchGlass.frame.maxY + searchGap
        let gridHeight = max(0, bounds.height - gridTop - barHeight)
        let newGridFrame = CGRect(x: 0, y: gridTop, width: width, height: gridHeight)
        if collectionView.frame != newGridFrame {
            collectionView.frame = newGridFrame
            gridLayout.rows = max(2, min(5, Int((gridHeight / max(40, width / 8)).rounded())))
            gridLayout.invalidateLayout()
        }
        if collectionView.bounds.width > 0 {
            collectionView.layoutIfNeeded()
            positionHeaders()
        }
        emptyLabel.frame = newGridFrame.insetBy(dx: 30, dy: 0)

        // Stickers: big cells, two rows when there is room.
        stickerView.frame = newGridFrame
        let stickerRows: CGFloat = gridHeight >= 130 ? 2 : 1
        let stickerSide = max(40, floor((gridHeight - gridLayout.headerHeight) / stickerRows))
        stickerLayout.sectionInset = UIEdgeInsets(top: gridLayout.headerHeight, left: 8, bottom: 0, right: 8)
        if stickerLayout.itemSize.width != stickerSide || stickerLayout.itemSize.height != stickerSide {
            stickerLayout.itemSize = CGSize(width: stickerSide, height: stickerSide)
            stickerLayout.invalidateLayout()
        }

        let barTop = bounds.height - barHeight
        abcButton.frame = CGRect(x: 0, y: barTop, width: 64, height: barHeight)
        backspaceButton.frame = CGRect(x: width - 64, y: barTop, width: 64, height: barHeight)
        abcPanel.frame = CGRect(x: 8, y: barTop + 4, width: 48, height: barHeight - 8)
        deletePanel.frame = CGRect(x: width - 56, y: barTop + 4, width: 48, height: barHeight - 8)
        tabGlass.frame = CGRect(x: 64, y: barTop + 4, width: max(0, width - 128), height: barHeight - 8)
        layoutTabs()
        positionTabSelection(animated: false)
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

    // MARK: Touch handling

    /// Generous targets: the whole top band is the search field, and the whole bottom band belongs to
    /// ABC / the category tabs / delete (by x position), so taps never have to hit an icon exactly.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, bounds.contains(point) else { return nil }
        if let popup = variantPopup, popup.frame.insetBy(dx: -4, dy: -4).contains(point) {
            return super.hitTest(point, with: event)
        }
        if point.y < searchGlass.frame.maxY + 4 { return searchButton }
        let barTop = bounds.height - barHeight
        if point.y >= barTop - 4 {
            if point.x < 64 { return abcButton }
            if point.x > bounds.width - 64 { return backspaceButton }
            if let tab = HitTesting.nearestByX(point.x, in: tabButtons, relativeTo: self) { return tab }
        }
        return super.hitTest(point, with: event)
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

        let container = FlatPanel(background: Theme.popupFill, cornerRadius: 10, allowGlass: true, followsKeyRoundness: true)
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.3
        container.layer.shadowRadius = 3
        container.layer.shadowOffset = CGSize(width: 0, height: 1)
        container.frame = CGRect(x: x, y: y, width: width, height: height)

        let scroll = UIScrollView(frame: CGRect(x: 6, y: 0, width: width - 12, height: height))
        scroll.showsHorizontalScrollIndicator = false
        scroll.contentSize = CGSize(width: itemWidth * CGFloat(options.count), height: height)
        for (index, emoji) in options.enumerated() {
            let button = HitButton(type: .custom)
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
        return collectionView === stickerView ? 1 : sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if collectionView === stickerView { return stickerItems.count }
        return sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.reuseID, for: indexPath)
        if collectionView === stickerView, let stickerCell = cell as? EmojiCell {
            stickerCell.label.font = UIFont.systemFont(ofSize: stickerLayout.itemSize.width * 0.7)
            stickerCell.label.text = stickerItems[indexPath.item]
            return stickerCell
        }
        if let emojiCell = cell as? EmojiCell {
            let side = min(gridLayout.cellSize.width, gridLayout.cellSize.height)
            emojiCell.label.font = UIFont.systemFont(ofSize: min(32, side * 0.8))
            emojiCell.label.text = sections[indexPath.section].items[indexPath.item].base
        }
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if collectionView === stickerView {
            guard indexPath.item < stickerItems.count else { return }
            let emoji = stickerItems[indexPath.item]
            Haptics.shared.keyPress()
            delegate?.emojiPanel(self, didSelectSticker: emoji, image: StickerRenderer.image(for: emoji))
            StickerRenderer.remember(emoji)
            return
        }
        dismissVariantPopup()
        Haptics.shared.keyPress()
        delegate?.emojiPanel(self, didSelect: sections[indexPath.section].items[indexPath.item].base)
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView === collectionView, !stickerMode, !needsInitialScroll, !isProgrammaticScroll else { return }
        dismissVariantPopup()

        // The current category is the last one whose first column has reached the left edge.
        let probe = scrollView.contentOffset.x + gridLayout.cellSize.width * 0.6
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

    func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        isProgrammaticScroll = false
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isProgrammaticScroll = false
    }
}

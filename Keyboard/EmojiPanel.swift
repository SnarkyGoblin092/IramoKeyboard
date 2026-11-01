import UIKit

/// The emoji picker uses the native iOS look whatever the theme (only the search pill follows it: Theme.searchLook).
enum EmojiLook {
    private static func pick(_ light: UIColor, _ dark: UIColor) -> UIColor {
        return UIColor { trait in trait.userInterfaceStyle == .dark ? dark : light }
    }
    static let text = UIColor.label
    static let secondary = UIColor.secondaryLabel
    static let separator = pick(UIColor(white: 0, alpha: 0.12), UIColor(white: 1, alpha: 0.20))
    static let selection = pick(UIColor(white: 0, alpha: 0.30), UIColor(white: 1, alpha: 0.30))
    static let popup = pick(UIColor.white, UIColor(white: 0.42, alpha: 1))
    static let background = pick(UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1), UIColor(white: 0.17, alpha: 1))
}

protocol EmojiPanelDelegate: AnyObject {
    func emojiPanel(_ panel: EmojiPanel, didSelect emoji: String)
    func emojiPanelDidTapBackspace(_ panel: EmojiPanel)
    func emojiPanelDidTapSearch(_ panel: EmojiPanel)
    func emojiPanelDidClose(_ panel: EmojiPanel)
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
/// continuous strip that scrolls freely. Categories follow each other with a small gap. `vertical` (the Emoji
/// screen's Scroll direction): rows across instead, the categories one under another.
private final class EmojiGridLayout: UICollectionViewLayout {
    var rows = 4
    var edgeInset: CGFloat = 7.3
    var sectionGap: CGFloat = 0
    var vertical = false
    /// Extra points between neighbouring emoji (the Emoji screen's Cell spacing).
    var spacing: CGFloat = 0
    /// The Recently Used section (it may stand anywhere, or be left out); nil when there is none.
    var recentsSection: Int?
    /// Band at the top of the strip for the category names (they scroll with the content, like stock).
    var headerHeight: CGFloat = 0
    /// Empty space after the Recently Used block, before the smileys begin.
    var gapAfterRecents: CGFloat = 0
    /// Square cells sized by the height (iPad), instead of the phone's eight columns across.
    var squareCells = false
    /// Width an empty Recently Used block keeps (eight columns, at most one screen), for its hint.
    private(set) var emptyRecentsWidth: CGFloat = 0
    /// Height an empty Recently Used block keeps when scrolling vertically (one row).
    private(set) var emptyRecentsHeight: CGFloat = 0

    private(set) var cellSize = CGSize(width: 40, height: 40)
    /// The content offset (along the scroll direction) that puts each category's start at the edge.
    private(set) var sectionStart: [CGFloat] = []
    private(set) var viewWidth: CGFloat = 0

    private var cache: [UICollectionViewLayoutAttributes] = []
    private var byPath: [IndexPath: UICollectionViewLayoutAttributes] = [:]
    private var contentWidth: CGFloat = 0
    private var contentHeight: CGFloat = 0

    override func prepare() {
        super.prepare()
        cache = []
        byPath = [:]
        sectionStart = []
        contentWidth = 0
        contentHeight = 0
        guard let collectionView = collectionView else { return }

        viewWidth = collectionView.bounds.width
        let height = collectionView.bounds.height
        guard viewWidth > 0, height > 0, rows > 0 else { return }
        if vertical {
            prepareVertical(in: collectionView, height: height)
            return
        }
        contentHeight = height

        let side = max(1, (height - headerHeight) / CGFloat(rows))
        if squareCells {
            cellSize = CGSize(width: side, height: side)
            edgeInset = side * 0.2
        } else {
            // Stock metrics (measured on 440pt): 54.8pt pitch, 7.3pt left inset, eight columns across.
            cellSize = CGSize(width: viewWidth * 54.8 / 440, height: side)
            edgeInset = viewWidth * 7.3 / 440
        }
        gapAfterRecents = cellSize.width * 0.75

        let pitch = cellSize.width + spacing
        var x = edgeInset
        for section in 0..<collectionView.numberOfSections {
            sectionStart.append(x - edgeInset)
            let count = collectionView.numberOfItems(inSection: section)
            for item in 0..<count {
                let column = item / rows
                let row = item % rows
                let path = IndexPath(item: item, section: section)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: path)
                attributes.frame = CGRect(x: x + CGFloat(column) * pitch,
                                          y: headerHeight + CGFloat(row) * cellSize.height,
                                          width: cellSize.width,
                                          height: cellSize.height)
                cache.append(attributes)
                byPath[path] = attributes
            }
            if count == 0 {
                // An empty tab (Recently Used) still owns eight columns (it holds 32 emoji), at most one screen.
                emptyRecentsWidth = min(viewWidth - edgeInset * 2, 8 * pitch)
                x += emptyRecentsWidth
            } else {
                let columns = (count + rows - 1) / rows
                x += CGFloat(columns) * pitch
            }
            x += (section == recentsSection && count > 0) ? gapAfterRecents : sectionGap
        }
        // Room so that even the last category can be scrolled to the left edge.
        let lastStart = (sectionStart.last ?? 0)
        contentWidth = max(x + edgeInset, lastStart + viewWidth)
    }

    /// Rows across the width, `rows` of them on screen; each category starts on a new row.
    private func prepareVertical(in collectionView: UICollectionView, height: CGFloat) {
        let side = max(1, height / CGFloat(rows))
        edgeInset = side * 0.15
        let usable = viewWidth - edgeInset * 2
        let columns = max(1, Int((usable + spacing) / (side + spacing)))
        cellSize = CGSize(width: (usable - spacing * CGFloat(columns - 1)) / CGFloat(columns), height: side)
        gapAfterRecents = side * 0.35
        emptyRecentsHeight = side
        contentWidth = viewWidth

        var y: CGFloat = 0
        for section in 0..<collectionView.numberOfSections {
            sectionStart.append(y)
            let count = collectionView.numberOfItems(inSection: section)
            for item in 0..<count {
                let path = IndexPath(item: item, section: section)
                let attributes = UICollectionViewLayoutAttributes(forCellWith: path)
                attributes.frame = CGRect(x: edgeInset + CGFloat(item % columns) * (cellSize.width + spacing),
                                          y: y + CGFloat(item / columns) * (side + spacing),
                                          width: cellSize.width,
                                          height: side)
                cache.append(attributes)
                byPath[path] = attributes
            }
            let lines = count == 0 ? 1 : (count + columns - 1) / columns
            y += CGFloat(lines) * (side + spacing)
            y += (section == recentsSection) ? gapAfterRecents : sectionGap
        }
        // Room so that even the last category can be scrolled to the top.
        contentHeight = max(y, (sectionStart.last ?? 0) + height)
    }

    override var collectionViewContentSize: CGSize {
        return CGSize(width: contentWidth, height: contentHeight)
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
final class EmojiPanel: UIView, UICollectionViewDataSource, UICollectionViewDelegate, UIGestureRecognizerDelegate {
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

    private let searchLook = Theme.searchLook(besideKeys: false)
    private lazy var searchGlass = FlatPanel(background: searchLook.fill, cornerRadius: 20, allowGlass: searchLook.glass)
    private let searchButton = HitButton(type: .system)
    private let searchIcon = UIImageView()
    private let searchLabel = UILabel()

    private let titleLabel = UILabel()
    private let emptyLabel = UILabel()

    private let tabGlass = FlatPanel(background: UIColor.clear)
    private let tabSelection = UIView()
    private let abcPanel = FlatPanel(background: UIColor.clear)
    private let deletePanel = FlatPanel(background: UIColor.clear)
    private let abcButton = HitButton(type: .system)
    private let backspaceButton = RepeatingButton(frame: .zero)
    private var tabButtons: [HitButton] = []
    private var currentSection = 0
    /// Where Recently Used sits among the tabs (nil when it is turned off).
    private var recentsIndex: Int?
    private var compact = false
    /// The row of ABC, the tabs and delete (in the custom layouts it may sit at the top).
    private var barFrame = CGRect.zero
    private let vertical = Prefs.emojiVertical
    private let tabsShown = Prefs.emojiTabsPosition != "hidden"
    private let searchShown = Prefs.emojiSearchPosition != "hidden"
    /// The system picker's own layout (search on top, tabs at the bottom, four rows across); anything else the
    /// Emoji screen sets uses the custom layout (layoutCustom).
    private let stockLayout = !Prefs.emojiVertical && Prefs.emojiSearchPosition == "top"
        && Prefs.emojiTabsPosition == "bottom" && Prefs.emojiRows == 4
    /// iPad width: the compact layout (tabs, ABC and delete in one row) with a dense grid of square cells.
    private var wide = false
    /// The `wide` the tab icons were drawn for.
    private var tabsDrawnWide: Bool?
    private var tabImages: [Int: (outline: UIImage, filled: UIImage)] = [:]
    private var tabCentreY: CGFloat = 302
    private var tabBandTop: CGFloat = 282
    private var startSection = 0
    private var needsInitialScroll = false
    private var isProgrammaticScroll = false
    private var variantPopup: UIView?

    /// Everything is measured on the stock 440 x 402pt picker and scaled by the width (capped in landscape).
    static func scale(forWidth width: CGFloat) -> CGFloat {
        return width > 500 ? 0.75 : min(1, max(0.6, width / 440))
    }

    /// iPad, and iPhone in landscape: one bottom row (ABC, tabs, delete) under a dense grid of square cells.
    static func usesWideLayout(width: CGFloat, height: CGFloat) -> Bool {
        return width > 500 && height > 250
    }

    /// Bigger tab icons and selection circle: only on iPad (an iPhone in landscape keeps the phone's sizes).
    private var bigTabs: Bool { return wide && traitCollection.userInterfaceIdiom == .pad }

    /// Keyboard height needed to show the whole picker.
    static func requiredHeight(forWidth width: CGFloat) -> CGFloat {
        return (337 * scale(forWidth: width)).rounded()
    }

    // These shrink on short keyboards (landscape, small height scale) so the panel always fits exactly.
    private var searchHeight: CGFloat = 36

    override init(frame: CGRect) {
        super.init(frame: frame)
        // Native look: the system keyboard backdrop shows in the native theme; other themes get the native colour.
        // Light or dark comes from the keyboard itself (the app's keyboard appearance, or the theme), like the keys.
        // (UIScreen's style is not the keyboard's: in dark mode it could still say light, leaving black icons.)
        // Not fully clear: the system drops touches on pixels of a keyboard that draw nothing, so a swipe that
        // started between emoji or on the empty part of Recently Used never reached the grid. 1% is invisible.
        backgroundColor = UIColor(white: 0.5, alpha: 0.01)

        // Search field
        searchGlass.capsule = true
        addSubview(searchGlass)
        searchIcon.image = UIImage(systemName: "magnifyingglass")
        searchIcon.tintColor = searchLook.secondaryText
        searchIcon.contentMode = .scaleAspectFit
        searchLabel.font = UIFont.systemFont(ofSize: 20)
        searchLabel.textColor = searchLook.secondaryText
        searchGlass.contentView.addSubview(searchIcon)
        searchGlass.contentView.addSubview(searchLabel)
        searchButton.addTarget(self, action: #selector(searchTapped), for: .touchUpInside)
        searchGlass.contentView.addSubview(searchButton)

        // Section title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = EmojiLook.secondary
        addSubview(titleLabel)

        // Grid
        gridLayout.rows = 4
        gridLayout.vertical = vertical
        gridLayout.spacing = CGFloat(Prefs.emojiSpacing)
        searchGlass.isHidden = !searchShown
        tabGlass.isHidden = !tabsShown
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: gridLayout)
        collectionView.backgroundColor = UIColor.clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.showsVerticalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = !vertical
        collectionView.alwaysBounceVertical = vertical
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(EmojiCell.self, forCellWithReuseIdentifier: EmojiCell.reuseID)
        addSubview(collectionView)


        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = Prefs.emojiHoldDelay
        collectionView.addGestureRecognizer(longPress)

        if Prefs.emojiSwipeTabs {
            // Across the scroll direction: up / left for the next tab, down / right for the one before.
            let next = UISwipeGestureRecognizer(target: self, action: #selector(swipedToNextTab))
            next.direction = vertical ? .left : .up
            let previous = UISwipeGestureRecognizer(target: self, action: #selector(swipedToPreviousTab))
            previous.direction = vertical ? .right : .down
            for swipe in [next, previous] {
                swipe.delegate = self
                collectionView.addGestureRecognizer(swipe)
            }
        }

        emptyLabel.textAlignment = .center
        emptyLabel.textColor = EmojiLook.secondary
        emptyLabel.font = UIFont.systemFont(ofSize: 15)
        emptyLabel.numberOfLines = 0
        emptyLabel.adjustsFontSizeToFitWidth = true
        emptyLabel.minimumScaleFactor = 0.6
        emptyLabel.isHidden = true
        emptyLabel.isUserInteractionEnabled = false
        addSubview(emptyLabel)

        // Bottom bar
        addSubview(abcPanel)
        addSubview(deletePanel)
        addSubview(tabGlass)
        tabSelection.isUserInteractionEnabled = false
        tabSelection.backgroundColor = Theme.accent   // the theme's highlight colour, like the suggestion bar
        if Theme.usesRealGlass {
            // Liquid Glass theme: an accent-tinted glass circle, like the suggestion bar's pill.
            GlassSupport.addBackground(to: tabSelection, tint: Theme.accent.withAlphaComponent(0.85))
        }
        tabSelection.layer.cornerCurve = .continuous
        tabGlass.contentView.addSubview(tabSelection)
        abcButton.setTitle("ABC", for: .normal)
        abcButton.setTitleColor(EmojiLook.text, for: .normal)
        abcButton.titleLabel?.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        abcButton.contentHorizontalAlignment = .left
        abcButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        addSubview(abcButton)

        backspaceButton.setImage(UIImage(systemName: "delete.left",
                                         withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .light)), for: .normal)
        backspaceButton.tintColor = EmojiLook.text
        backspaceButton.isHidden = !Prefs.emojiBackspaceKey
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

        let recents = Settings.shared.orderedRecentEmoji().map { EmojiItem(base: $0, variants: []) }
        var byKey: [String: Section] = [:]
        if Prefs.emojiShowRecents {
            byKey["recent"] = Section(key: "recent",
                                      symbol: EmojiCategory.recentSymbol,
                                      fallback: EmojiCategory.recentFallback,
                                      title: recentTitle(),
                                      items: recents)
        }
        let tone = Prefs.emojiSkinTone
        for category in store.categories {
            byKey[category.key] = Section(key: category.key,
                                          symbol: category.symbol,
                                          fallback: category.fallbackIcon,
                                          title: category.title(for: language),
                                          items: tone > 0 ? category.items.map { EmojiPanel.toned($0, tone) } : category.items)
        }
        // The Emoji screen's order (Recently Used first by default) and the tabs it hides.
        let standard = ["recent"] + EmojiCategory.layout.map { $0.key }
        let order = Prefs.emojiCategoryOrder.filter { standard.contains($0) }
            + standard.filter { !Prefs.emojiCategoryOrder.contains($0) }
        let hidden = Set(Prefs.emojiHiddenCategories)
        for key in order where !hidden.contains(key) {
            if let section = byKey[key] { built.append(section) }
        }
        if built.allSatisfy({ $0.key == "recent" }) {
            // Never an empty picker: every category hidden shows them all.
            built += order.compactMap { $0 == "recent" ? nil : byKey[$0] }
        }
        sections = built
        recentsIndex = sections.firstIndex { $0.key == "recent" }
        gridLayout.recentsSection = recentsIndex

        collectionView.isHidden = false
        rebuildTabs()
        collectionView.reloadData()
        collectionView.collectionViewLayout.invalidateLayout()

        // The grid can only scroll once it has a real size, so the scroll is done in layoutSubviews
        // (this was the "empty until I tap a tab" bug: reload() ran while the panel still had zero size).
        // The first tab, passing over an empty Recently Used.
        if let recents = recentsIndex, recents == 0, sections[recents].items.isEmpty, sections.count > 1 {
            startSection = 1
        } else {
            startSection = 0
        }
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
        guard gridLayout.sectionStart.count == sections.count else { return }
        let target = min(startSection, sections.count - 1)
        collectionView.setContentOffset(offset(forSection: target), animated: false)
        needsInitialScroll = false
        currentSection = target
        refreshTabHighlight()
        updateEmptyState()
    }

    private func recentTitle() -> String {
        return language.strings.recentlyUsed
    }

    /// The scroll position that brings a section's start to the edge (never past the end).
    private func offset(forSection section: Int) -> CGPoint {
        guard section < gridLayout.sectionStart.count else { return .zero }
        let start = gridLayout.sectionStart[section]
        if vertical {
            let most = max(0, collectionView.contentSize.height - collectionView.bounds.height)
            return CGPoint(x: 0, y: min(start, most))
        }
        let most = max(0, collectionView.contentSize.width - collectionView.bounds.width)
        return CGPoint(x: min(start, most), y: 0)
    }

    private static let toneModifiers: [Unicode.Scalar] = (UInt32(0x1F3FB)...UInt32(0x1F3FF)).compactMap { Unicode.Scalar($0) }

    /// The emoji in the default skin tone (1 light ... 5 dark) when it has one with that tone alone; holding it
    /// still offers the yellow one and the others.
    private static func toned(_ item: EmojiItem, _ tone: Int) -> EmojiItem {
        guard tone >= 1, tone <= toneModifiers.count, !item.variants.isEmpty else { return item }
        let wanted = toneModifiers[tone - 1]
        guard let match = item.variants.first(where: { variant in
            Set(variant.unicodeScalars.filter { toneModifiers.contains($0) }) == [wanted]
        }) else { return item }
        return EmojiItem(base: match, variants: [item.base] + item.variants.filter { $0 != match })
    }

    private func updateEmptyState() {
        let store = EmojiStore.shared
        if !store.isReady {
            emptyLabel.text = language.strings.loadingEmoji
            emptyLabel.isHidden = false
        } else if store.categories.isEmpty {
            emptyLabel.text = "No emoji data found in this build."
            emptyLabel.isHidden = false
        } else if let recents = recentsIndex, sections[recents].items.isEmpty {
            emptyLabel.text = language.strings.emptyRecents
            emptyLabel.isHidden = false
        } else {
            emptyLabel.isHidden = true     // never covers emoji that are on screen
        }
        positionEmptyLabel()
    }

    /// The empty-recents hint sits on the Recently Used page and scrolls with it; other messages stay put.
    private func positionEmptyLabel() {
        let isRecentsHint = emptyLabel.text == language.strings.emptyRecents && EmojiStore.shared.isReady
        let grid = collectionView.frame
        // Where the empty Recently Used block starts in the strip.
        let start = isRecentsHint ? (recentsIndex.flatMap { $0 < gridLayout.sectionStart.count ? gridLayout.sectionStart[$0] : nil } ?? 0) : 0
        if vertical && isRecentsHint {
            // Its one empty row, scrolling with it (hidden once it would cover the bars).
            emptyLabel.frame = CGRect(x: grid.minX + 30, y: grid.minY + start - collectionView.contentOffset.y,
                                      width: max(0, grid.width - 60), height: gridLayout.emptyRecentsHeight)
            if !emptyLabel.isHidden && !grid.insetBy(dx: 0, dy: -2).contains(emptyLabel.frame) { emptyLabel.isHidden = true }
        } else if wide && isRecentsHint && gridLayout.emptyRecentsWidth > 0 {
            // iPad: inside the eight empty columns, scrolling with them.
            emptyLabel.frame = CGRect(x: grid.minX + gridLayout.edgeInset + 10 + start - collectionView.contentOffset.x,
                                      y: grid.minY,
                                      width: max(0, gridLayout.emptyRecentsWidth - 20),
                                      height: grid.height)
        } else {
            let shift = isRecentsHint ? collectionView.contentOffset.x - start : 0
            emptyLabel.frame = grid.insetBy(dx: 30, dy: 0).offsetBy(dx: -shift, dy: 0)
        }
    }

    private func rebuildTabs() {
        for button in tabButtons { button.removeFromSuperview() }
        tabButtons = []
        tabImages = [:]
        tabsDrawnWide = wide
        let iconScale: CGFloat = bigTabs ? 1.3 : 1
        for (index, section) in sections.enumerated() {
            let button = HitButton(type: .system)
            if Prefs.emojiTabStyle == "emoji" {
                // The Emoji screen's Tab style: an emoji for each tab instead of the outline icon.
                button.setTitle(section.fallback, for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 18 * iconScale)
            } else if let drawn = EmojiTabIcons.icons(forKey: section.key, side: 80.0 / 3.0 * iconScale) {
                button.setImage(drawn.outline, for: .normal)
                tabImages[index] = (drawn.outline, drawn.filled)
            } else if let image = UIImage(systemName: section.symbol,
                                   withConfiguration: UIImage.SymbolConfiguration(pointSize: 14.4 * iconScale, weight: .light)) {
                button.setImage(image, for: .normal)
                // Outline by default, filled while this is the active tab.
                let filledConfig = UIImage.SymbolConfiguration(pointSize: 14.4 * iconScale, weight: .regular)
                let filled = UIImage(systemName: section.symbol + ".fill", withConfiguration: filledConfig) ?? image
                if section.key == "smileys" {
                    // On iOS the plain smiley symbol is the solid one, so the roles are swapped for this tab.
                    tabImages[index] = (filled, image)
                } else {
                    tabImages[index] = (image, filled)
                }
            } else {
                button.setTitle(section.fallback, for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: 14)
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
            let selected = (index == selectedTabIndex)
            button.tintColor = selected ? Theme.onAccent : EmojiLook.text
            if let pair = tabImages[index] { button.setImage(selected ? pair.filled : pair.outline, for: .normal) }
            button.alpha = selected ? 1.0 : 0.9
        }
        if currentSection < sections.count {
            titleLabel.text = sections[currentSection].title.uppercased()
        }
        positionTabSelection(animated: true)
    }

    private var selectedTabIndex: Int { return currentSection }

    private func positionTabSelection(animated: Bool) {
        guard selectedTabIndex < tabButtons.count, tabGlass.bounds.height > 0 else {
            tabSelection.isHidden = true
            return
        }
        tabSelection.isHidden = false
        let buttonFrame = tabButtons[selectedTabIndex].frame
        // iPad: clear of the bigger icon all round.
        let circle: CGFloat = bigTabs ? 44 : (wide ? 32 : 30 * EmojiPanel.scale(forWidth: bounds.width))
        tabSelection.layer.cornerRadius = circle / 2
        let target = CGRect(x: buttonFrame.midX - circle / 2, y: buttonFrame.midY - circle / 2, width: circle, height: circle)
        tabGlass.contentView.sendSubviewToBack(tabSelection)
        if animated && tabSelection.frame != .zero {
            UIView.animate(withDuration: 0.16, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState]) {
                self.tabSelection.frame = target
            }
        } else {
            tabSelection.frame = target
        }
    }

    private func scrollToSection(_ section: Int, animated: Bool) {
        guard section < sections.count else { return }
        currentSection = section
        collectionView.layoutIfNeeded()
        if section < gridLayout.sectionStart.count {
            // Smooth scroll; the highlight stays on the tapped tab until the scroll settles.
            isProgrammaticScroll = animated
            collectionView.setContentOffset(offset(forSection: section), animated: animated)
        }
        refreshTabHighlight()
        updateEmptyState()
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        let width = bounds.width
        let xf = width / 440
        let f = EmojiPanel.scale(forWidth: width)
        gridLayout.headerHeight = 0
        titleLabel.isHidden = true

        // Full stock layout (440 x 402pt) when the keyboard is tall enough, otherwise a compact layout that
        // is anchored to the real height so the tab row, ABC and delete are never cut off.
        let height = bounds.height
        wide = EmojiPanel.usesWideLayout(width: width, height: height)
        if !stockLayout {
            layoutCustom(width: width, height: height, f: f)
            return
        }
        compact = wide || height < 390 * f
        // The pill hugs the keyboard's rounded top corners: small insets, fully rounded ends, a little taller.
        let pillTop: CGFloat = compact ? 5 * f : 6 * f
        searchHeight = wide ? 44 : (compact ? 44 : 46) * f
        searchGlass.frame = CGRect(x: 6 * xf, y: pillTop, width: width - 12 * xf, height: searchHeight)
        searchButton.frame = searchGlass.bounds
        let ix = wide ? f : xf      // the icon and placeholder keep their spacing on iPad
        // iPad: the same icon and text size as the active search field (EmojiSearchBar).
        let iconSide = wide ? 16 : 17 * f
        searchIcon.frame = CGRect(x: 13 * ix, y: (searchHeight - iconSide) / 2, width: iconSide, height: iconSide)
        searchLabel.font = UIFont.systemFont(ofSize: wide ? 16 : 20 * f)
        let labelX = wide ? 13 * ix + iconSide + 6 : 37 * ix
        searchLabel.frame = CGRect(x: labelX, y: 0, width: max(0, searchGlass.bounds.width - labelX - 13 * ix), height: searchHeight)

        let gridTop: CGFloat
        let gridHeight: CGFloat
        if compact {
            let tabHalf = wide ? 27 : 22 * f
            tabCentreY = height - (wide ? 30 : 24 * f)
            gridTop = pillTop + searchHeight + 3 * f
            gridHeight = max(120, (tabCentreY - tabHalf) - gridTop)
            tabBandTop = tabCentreY - tabHalf
        } else {
            tabCentreY = 302 * f
            gridTop = 61.6 * f
            gridHeight = 4 * 54.8 * f
            tabBandTop = 282 * f
        }
        // iPad: emoji at most twice the size they had in the scaled phone layout (cells up to 82pt), more rows
        // when the keyboard is taller.
        let rows = wide ? max(4, Int((gridHeight / 82).rounded(.up))) : 4
        placeGrid(CGRect(x: 0, y: gridTop, width: width, height: gridHeight), rows: rows, square: wide)
        barFrame = CGRect(x: 0, y: tabBandTop, width: width, height: height - tabBandTop)

        let tabBand = wide ? 50 : 36 * f
        tabGlass.frame = CGRect(x: 0, y: tabCentreY - tabBand / 2, width: width, height: tabBand)
        if tabsDrawnWide != nil && tabsDrawnWide != wide { rebuildTabs() }
        if compact {
            // ABC sits at the left of the tab row.
            // ABC is centred between the screen edge and the first (recents) icon at x = 84.
            // ABC, the nine tabs and delete share eleven equally spaced slots (centres 38 ... 402).
            abcButton.contentHorizontalAlignment = .center
            let abcWidth = min(56 * xf, 80)
            abcButton.frame = CGRect(x: slotLayout().abc - abcWidth / 2, y: tabCentreY - 22, width: abcWidth, height: 44)
        } else {
            abcButton.contentHorizontalAlignment = .left
            abcButton.frame = CGRect(x: 27.7 * xf, y: 369 * f - 22, width: 80, height: 44)
        }
        let deleteCentre: CGFloat = slotLayout().delete
        backspaceButton.frame = CGRect(x: deleteCentre - 26, y: tabCentreY - 22, width: 52, height: 44)
        layoutTabs()
        positionTabSelection(animated: false)
        applyInitialScrollIfPossible()
    }

    private func placeGrid(_ frame: CGRect, rows: Int, square: Bool) {
        if collectionView.frame != frame || gridLayout.rows != rows || gridLayout.squareCells != square {
            collectionView.frame = frame
            gridLayout.rows = rows
            gridLayout.squareCells = square
            gridLayout.invalidateLayout()
            collectionView.reloadData()       // cell fonts follow the cell size
        }
        if collectionView.bounds.width > 0 { collectionView.layoutIfNeeded() }
        positionEmptyLabel()
    }

    /// The Emoji screen's own arrangement: the search field and the bar (ABC, tabs, delete) at the top or the
    /// bottom, the grid between them with the rows asked for. Always the compact one-row bar.
    private func layoutCustom(width: CGFloat, height: CGFloat, f: CGFloat) {
        compact = true
        let xf = width / 440
        let pill: CGFloat = wide ? 44 : 44 * f
        let band: CGFloat = wide ? 56 : 46 * f
        var top: CGFloat = 5 * f
        var bottom = height

        func placeSearch(y: CGFloat) {
            searchHeight = pill
            searchGlass.frame = CGRect(x: 6 * xf, y: y, width: width - 12 * xf, height: pill)
            searchButton.frame = searchGlass.bounds
            let ix = wide ? f : xf
            let iconSide = wide ? 16 : 17 * f
            searchIcon.frame = CGRect(x: 13 * ix, y: (pill - iconSide) / 2, width: iconSide, height: iconSide)
            searchLabel.font = UIFont.systemFont(ofSize: wide ? 16 : 20 * f)
            let labelX = wide ? 13 * ix + iconSide + 6 : 37 * ix
            searchLabel.frame = CGRect(x: labelX, y: 0, width: max(0, searchGlass.bounds.width - labelX - 13 * ix), height: pill)
        }

        if Prefs.emojiSearchPosition == "top" {
            placeSearch(y: top)
            top += pill + 3 * f
        }
        if Prefs.emojiTabsPosition == "top" {
            barFrame = CGRect(x: 0, y: top, width: width, height: band)
            top += band
        } else {
            barFrame = CGRect(x: 0, y: bottom - band, width: width, height: band)
            bottom -= band
        }
        if Prefs.emojiSearchPosition == "bottom" {
            placeSearch(y: bottom - pill - 4 * f)
            bottom -= pill + 7 * f
        }

        tabCentreY = barFrame.midY
        tabBandTop = barFrame.minY
        let gridHeight = max(60, bottom - top)
        var rows = Prefs.emojiRows
        if wide { rows = max(rows, Int((gridHeight / 82).rounded(.up))) }
        placeGrid(CGRect(x: 0, y: top, width: width, height: gridHeight), rows: rows, square: wide || rows != 4 || vertical)

        let tabBand = wide ? 50 : 36 * f
        tabGlass.frame = CGRect(x: 0, y: tabCentreY - tabBand / 2, width: width, height: tabBand)
        if tabsDrawnWide != nil && tabsDrawnWide != wide { rebuildTabs() }
        abcButton.contentHorizontalAlignment = .center
        let abcWidth = min(56 * xf, 80)
        abcButton.frame = CGRect(x: slotLayout().abc - abcWidth / 2, y: tabCentreY - 22, width: abcWidth, height: 44)
        backspaceButton.frame = CGRect(x: slotLayout().delete - 26, y: tabCentreY - 22, width: 52, height: 44)
        layoutTabs()
        positionTabSelection(animated: false)
        applyInitialScrollIfPossible()
    }

    /// Equally spaced slots (in points; measured on 440pt and scaled by the width): compact = ABC, every tab,
    /// delete; full = every tab, delete (ABC has its own row there). On iPad, ABC and delete stay near the edges
    /// and the tabs keep a modest pitch in the middle.
    private func slotLayout() -> (abc: CGFloat, first: CGFloat, step: CGFloat, delete: CGFloat) {
        let tabs = max(1, tabButtons.count)
        let xf = bounds.width / 440
        if wide {
            let step = min(32 * xf, 64)
            let abc: CGFloat = 50, delete = bounds.width - 50
            return (abc, (abc + delete) / 2 - step * CGFloat(tabs - 1) / 2, step, delete)
        }
        let step: CGFloat = 32
        // The tab group is centred between ABC and delete.
        if compact {
            let first = (38 + 402) / 2 - step * CGFloat(tabs - 1) / 2
            return (38 * xf, first * xf, step * xf, 402 * xf)
        }
        let first = (37.7 + 411) / 2 - step * CGFloat(tabs - 1) / 2
        return (27.7 * xf, first * xf, step * xf, 411 * xf)
    }

    private func layoutTabs() {
        guard !tabButtons.isEmpty else { return }
        let area = tabGlass.bounds
        let slots = slotLayout()
        let pitch = slots.step
        for (index, button) in tabButtons.enumerated() {
            let centre = slots.first + slots.step * CGFloat(index)
            button.frame = CGRect(x: centre - pitch / 2, y: 0, width: pitch, height: area.height)
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
        let f = EmojiPanel.scale(forWidth: bounds.width)
        if searchShown {
            if stockLayout {
                if point.y < searchGlass.frame.maxY + 4 { return searchButton }
            } else if searchGlass.frame.insetBy(dx: -6, dy: -4).contains(point) {
                return searchButton
            }
        }
        if compact {
            if point.y >= barFrame.minY && point.y <= barFrame.maxY {
                let slots = slotLayout()
                if point.x < slots.abc + slots.step / 2 { return abcButton }
                if point.x > slots.delete - slots.step / 2 { if !backspaceButton.isHidden { return backspaceButton } }
                if tabsShown, let tab = HitTesting.nearestByX(point.x, in: tabButtons, relativeTo: self) { return tab }
                return super.hitTest(point, with: event)
            }
            return super.hitTest(point, with: event)
        }
        if point.y >= 346 * f {
            return point.x < bounds.width * 0.4 ? abcButton : super.hitTest(point, with: event)
        }
        if point.y >= tabBandTop {
            if !backspaceButton.isHidden && point.x > slotLayout().delete - slotLayout().step / 2 { return backspaceButton }
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

    @objc private func swipedToNextTab() {
        switchTab(by: 1)
    }

    @objc private func swipedToPreviousTab() {
        switchTab(by: -1)
    }

    private func switchTab(by step: Int) {
        let target = currentSection + step
        guard target >= 0, target < sections.count else { return }
        Haptics.shared.keyPress()
        dismissVariantPopup()
        // The swipe fires while the grid's own pan is still dragging; cancel it (and any momentum) first,
        // or its deceleration takes over from the animated jump and rolls past the category's start.
        let pan = collectionView.panGestureRecognizer
        pan.isEnabled = false
        pan.isEnabled = true
        collectionView.setContentOffset(collectionView.contentOffset, animated: false)
        scrollToSection(target, animated: true)
    }

    /// The tab swipes work alongside the grid's own scrolling.
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        return gestureRecognizer is UISwipeGestureRecognizer
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

        let container = FlatPanel(background: EmojiLook.popup, cornerRadius: 10)
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
        return sections.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return sections[section].items.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: EmojiCell.reuseID, for: indexPath)
        if let emojiCell = cell as? EmojiCell {
            let side = min(gridLayout.cellSize.width, gridLayout.cellSize.height)
            emojiCell.label.font = UIFont.systemFont(ofSize: side * CGFloat(Prefs.emojiSize))
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
        guard scrollView === collectionView else { return }
        updateEmptyState()
        guard !needsInitialScroll, !isProgrammaticScroll else { return }
        dismissVariantPopup()

        // The current category is the last one whose start has reached the edge.
        let probe = vertical ? scrollView.contentOffset.y + gridLayout.cellSize.height * 0.6
            : scrollView.contentOffset.x + gridLayout.cellSize.width * 0.6
        var section = 0
        for (index, start) in gridLayout.sectionStart.enumerated() where start <= probe {
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

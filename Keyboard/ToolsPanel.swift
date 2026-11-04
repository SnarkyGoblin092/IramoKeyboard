import UIKit

protocol ToolsPanelDelegate: AnyObject {
    func toolsPanel(_ panel: ToolsPanel, didPick tool: KeyboardTool)
    /// On for a tool that is switched on (number row, swipe typing...), nil for one that is an action.
    func toolsPanel(_ panel: ToolsPanel, stateOf tool: KeyboardTool) -> Bool?
    /// What a tool's tile says in place of its name (the one-handed side), if anything.
    func toolsPanel(_ panel: ToolsPanel, detailOf tool: KeyboardTool) -> String?
    func toolsPanel(_ panel: ToolsPanel, isAvailable tool: KeyboardTool) -> Bool
}

/// The Functions strip: the tools the app's Functions screen picked, as icon buttons in a row that
/// scrolls sideways. It takes the place of the suggestions in the suggestion bar (SuggestionBar.setTools). Tools
/// that are on light up in the accent.
final class ToolsPanel: UIScrollView {
    weak var toolsDelegate: ToolsPanelDelegate?
    /// The wash behind each tile (the suggestion bar's segment colour).
    var tileFill: UIColor = UIColor(white: 0.5, alpha: 0.15) {
        didSet { for tile in tiles { tile.base.backgroundColor = tileFill } }
    }

    private final class Tile: UIView {
        let tool: KeyboardTool
        let base = UIView()
        private let onFill = UIView()
        private let icon = UIImageView()
        private var isAvailable = true

        init(tool: KeyboardTool) {
            self.tool = tool
            super.init(frame: .zero)
            base.layer.cornerCurve = .continuous
            addSubview(base)
            onFill.backgroundColor = Theme.accent.withAlphaComponent(0.22)
            onFill.layer.cornerCurve = .continuous
            onFill.isHidden = true
            addSubview(onFill)
            icon.image = UIImage(systemName: tool.symbol,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 22, weight: .regular))
            icon.contentMode = .center
            addSubview(icon)
            // The panel takes every touch itself, so a swipe can start anywhere and a tap is told apart from it.
            for view in [base, onFill, icon] as [UIView] { view.isUserInteractionEnabled = false }
            isUserInteractionEnabled = false
            accessibilityLabel = tool.title
            isAccessibilityElement = true
            accessibilityTraits = .button
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        var enabled: Bool { return isAvailable }

        func show(on: Bool?, detail text: String?, available: Bool) {
            let lit = on == true
            onFill.isHidden = !lit
            icon.tintColor = lit ? Theme.accent : Theme.barIcons
            isAvailable = available
            alpha = available ? 1 : 0.35
            accessibilityValue = text ?? (on.map { $0 ? "On" : "Off" })
        }

        /// A quick dip when tapped.
        func flash() {
            UIView.animate(withDuration: 0.08, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                self.base.alpha = 0.4
            } completion: { _ in
                UIView.animate(withDuration: 0.2) { self.base.alpha = 1 }
            }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // The tiles touch, but each is drawn a little smaller, so they read as separate rounded buttons.
            base.frame = bounds.insetBy(dx: 3, dy: 3)
            onFill.frame = base.frame
            base.layer.cornerRadius = min(14, base.bounds.height / 2.5)
            onFill.layer.cornerRadius = base.layer.cornerRadius
            icon.frame = bounds
        }
    }

    private var tiles: [Tile] = []
    private let emptyLabel = UILabel()

    init(tools: [KeyboardTool]) {
        super.init(frame: .zero)
        showsHorizontalScrollIndicator = false
        alwaysBounceHorizontal = true
        delaysContentTouches = false
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
        addGestureRecognizer(tap)
        for tool in tools {
            let tile = Tile(tool: tool)
            addSubview(tile)
            tile.base.backgroundColor = tileFill
            tiles.append(tile)
        }
        emptyLabel.text = "Add functions in the Iramo app"
        emptyLabel.textColor = Theme.secondaryText
        emptyLabel.font = UIFont.systemFont(ofSize: 13)
        emptyLabel.textAlignment = .center
        emptyLabel.adjustsFontSizeToFitWidth = true
        emptyLabel.minimumScaleFactor = 0.7
        emptyLabel.isHidden = !tools.isEmpty
        addSubview(emptyLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Reads every tile's state again (after a tool changed one).
    func refresh() {
        for tile in tiles {
            tile.show(on: toolsDelegate?.toolsPanel(self, stateOf: tile.tool),
                      detail: toolsDelegate?.toolsPanel(self, detailOf: tile.tool),
                      available: toolsDelegate?.toolsPanel(self, isAvailable: tile.tool) ?? true)
        }
    }

    @objc private func tapped(_ recognizer: UITapGestureRecognizer) {
        let x = recognizer.location(in: self).x
        guard let tile = tiles.first(where: { x >= $0.frame.minX && x < $0.frame.maxX }), tile.enabled else { return }
        tile.flash()
        Haptics.shared.keyPress()
        toolsDelegate?.toolsPanel(self, didPick: tile.tool)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        emptyLabel.frame = bounds
        guard !tiles.isEmpty else { return }
        // The tiles touch, so a finger anywhere along the strip is on one of them (and a swipe never starts in a gap).
        let tileWidth: CGFloat = 64
        for (index, tile) in tiles.enumerated() {
            tile.frame = CGRect(x: CGFloat(index) * tileWidth, y: 0, width: tileWidth, height: bounds.height)
        }
        contentSize = CGSize(width: CGFloat(tiles.count) * tileWidth, height: bounds.height)
    }

    /// How far left a tile must go to be fully behind the toolbox button (the strip clips what leaves its edge).
    private func hiddenShift(_ tile: Tile) -> CGFloat {
        return -(tile.frame.maxX - contentOffset.x)
    }

    /// The tiles slide back into the toolbox button, then `completion` runs.
    func slideOut(completion: @escaping () -> Void) {
        isUserInteractionEnabled = false
        let visible = tiles.filter { $0.frame.maxX > contentOffset.x && $0.frame.minX < contentOffset.x + bounds.width }
        for (index, tile) in visible.enumerated() {
            UIView.animate(withDuration: 0.24, delay: 0.02 * Double(min(index, 6)), options: [.curveEaseIn, .beginFromCurrentState]) {
                tile.transform = CGAffineTransform(translationX: self.hiddenShift(tile), y: 0)
            }
        }
        let total = 0.24 + 0.02 * Double(min(max(visible.count - 1, 0), 6))
        DispatchQueue.main.asyncAfter(deadline: .now() + total + 0.02, execute: completion)
    }

    /// The tiles slide out of the toolbox button at the left, one after the other.
    func slideIn() {
        layoutIfNeeded()
        for (index, tile) in tiles.enumerated() {
            tile.transform = CGAffineTransform(translationX: hiddenShift(tile), y: 0)
            UIView.animate(withDuration: 0.3, delay: 0.025 * Double(min(index, 8)), options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]) {
                tile.transform = .identity
            }
        }
    }
}

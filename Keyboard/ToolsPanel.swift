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
            onFill.alpha = 0
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
            isAvailable = available
            let changes = {
                self.onFill.alpha = lit ? 1 : 0
                self.onFill.transform = lit ? .identity : CGAffineTransform(scaleX: 0.85, y: 0.85)
                self.icon.tintColor = lit ? Theme.accent : Theme.barIcons
                self.alpha = available ? 1 : 0.35
            }
            if window != nil {
                // The wash grows in behind the icon (and shrinks out) rather than switching.
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0,
                               options: [.beginFromCurrentState, .allowUserInteraction], animations: changes)
            } else {
                changes()
            }
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
        panGestureRecognizer.delaysTouchesBegan = false
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

    // A tap is read from the raw touches rather than a tap recogniser, which would hold the scrolling back: a flick
    // that starts anywhere on the strip scrolls at once, and a touch that stays put is a tap.
    private var touchStart: CGPoint?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = touches.first?.location(in: self)
        super.touchesBegan(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        defer { touchStart = nil }
        guard let start = touchStart, let end = touches.first?.location(in: self),
              hypot(end.x - start.x, end.y - start.y) < 10, !isDragging, !isDecelerating else { return }
        picked(atX: end.x)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchStart = nil
        super.touchesCancelled(touches, with: event)
    }

    private func picked(atX x: CGFloat) {
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
            // Bounds and centre rather than frame: a tile may be mid-slide with a transform.
            tile.bounds = CGRect(x: 0, y: 0, width: tileWidth, height: bounds.height)
            tile.center = CGPoint(x: (CGFloat(index) + 0.5) * tileWidth, y: bounds.height / 2)
        }
        contentSize = CGSize(width: CGFloat(tiles.count) * tileWidth, height: bounds.height)
    }

    /// How far left the tiles must go to be fully behind the toolbox button (the strip clips what leaves its edge):
    /// the same for all, so they move as one row.
    private func hiddenShift() -> CGFloat {
        let lastVisible = tiles.last { $0.center.x - $0.bounds.width / 2 < contentOffset.x + bounds.width }
        let edge = (lastVisible.map { $0.center.x + $0.bounds.width / 2 } ?? contentOffset.x + bounds.width)
        return -(edge - contentOffset.x)
    }

    /// The tiles slide back into the toolbox button, then `completion` runs (a little before the last one is in, so
    /// the suggestions can start coming back).
    func slideOut(completion: @escaping () -> Void) {
        isUserInteractionEnabled = false
        let shift = hiddenShift()
        let step = 0.012
        for (index, tile) in tiles.enumerated() where index < 12 {
            UIView.animate(withDuration: 0.3, delay: step * Double(index), options: [.curveEaseIn, .beginFromCurrentState]) {
                tile.transform = CGAffineTransform(translationX: shift, y: 0)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3 + step * Double(min(tiles.count, 12)) * 0.6, execute: completion)
    }

    /// The tiles slide out of the toolbox button at the left, one after the other.
    func slideIn() {
        layoutIfNeeded()
        let shift = hiddenShift()
        for (index, tile) in tiles.enumerated() {
            tile.transform = CGAffineTransform(translationX: shift, y: 0)
            UIView.animate(withDuration: 0.3, delay: 0.012 * Double(min(index, 12)), options: [.curveEaseOut, .allowUserInteraction, .beginFromCurrentState]) {
                tile.transform = .identity
            }
        }
    }
}

import UIKit

protocol ToolsPanelDelegate: AnyObject {
    func toolsPanel(_ panel: ToolsPanel, didPick tool: KeyboardTool)
    /// On for a tool that is switched on (number row, swipe typing...), nil for one that is an action.
    func toolsPanel(_ panel: ToolsPanel, stateOf tool: KeyboardTool) -> Bool?
    /// What a tool's tile says in place of its name (the one-handed side), if anything.
    func toolsPanel(_ panel: ToolsPanel, detailOf tool: KeyboardTool) -> String?
    func toolsPanel(_ panel: ToolsPanel, isAvailable tool: KeyboardTool) -> Bool
}

/// The Functions strip: the tools the app's Functions screen picked, as small icon-and-name buttons in a row that
/// scrolls sideways. It takes the place of the suggestions in the suggestion bar (SuggestionBar.setTools). Tools
/// that are on light up in the accent.
final class ToolsPanel: UIScrollView {
    weak var toolsDelegate: ToolsPanelDelegate?

    private final class Tile: UIControl {
        let tool: KeyboardTool
        private let onFill = UIView()
        private let icon = UIImageView()
        private let title = UILabel()

        init(tool: KeyboardTool) {
            self.tool = tool
            super.init(frame: .zero)
            onFill.backgroundColor = Theme.accent
            onFill.layer.cornerCurve = .continuous
            onFill.isUserInteractionEnabled = false
            onFill.isHidden = true
            addSubview(onFill)
            icon.image = UIImage(systemName: tool.symbol,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .regular))
            icon.contentMode = .center
            title.text = tool.title
            title.font = Theme.keyFont(ofSize: 10, weight: .medium)
            title.textAlignment = .center
            title.adjustsFontSizeToFitWidth = true
            title.minimumScaleFactor = 0.6
            for view in [icon, title] as [UIView] {
                view.isUserInteractionEnabled = false
                addSubview(view)
            }
            accessibilityLabel = tool.title
            isAccessibilityElement = true
            accessibilityTraits = .button
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported")
        }

        func show(on: Bool?, detail text: String?, available: Bool) {
            let lit = on == true
            onFill.isHidden = !lit
            let colour = lit ? Theme.onAccent : Theme.barIcons
            icon.tintColor = colour
            title.textColor = colour
            // A tool with something to say about its state (the one-handed side) says it in place of its name.
            title.text = text ?? tool.title
            alpha = available ? 1 : 0.35
            isEnabled = available
            accessibilityValue = text ?? (on.map { $0 ? "On" : "Off" })
        }

        override var isHighlighted: Bool {
            didSet { alpha = isEnabled ? (isHighlighted ? 0.45 : 1) : 0.35 }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            onFill.frame = bounds.insetBy(dx: 1, dy: 1)
            onFill.layer.cornerRadius = min(10, onFill.bounds.height / 2.6)
            let block: CGFloat = 22 + 1 + 12
            let top = max(1, (bounds.height - block) / 2)
            icon.frame = CGRect(x: 0, y: top, width: bounds.width, height: 22)
            title.frame = CGRect(x: 3, y: icon.frame.maxY + 1, width: bounds.width - 6, height: 12)
        }
    }

    private var tiles: [Tile] = []
    private let emptyLabel = UILabel()

    init(tools: [KeyboardTool]) {
        super.init(frame: .zero)
        showsHorizontalScrollIndicator = false
        alwaysBounceHorizontal = true
        delaysContentTouches = false
        for tool in tools {
            let tile = Tile(tool: tool)
            tile.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            addSubview(tile)
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

    // The tiles are controls: a drag on one still scrolls the strip.
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }

    /// Reads every tile's state again (after a tool changed one).
    func refresh() {
        for tile in tiles {
            tile.show(on: toolsDelegate?.toolsPanel(self, stateOf: tile.tool),
                      detail: toolsDelegate?.toolsPanel(self, detailOf: tile.tool),
                      available: toolsDelegate?.toolsPanel(self, isAvailable: tile.tool) ?? true)
        }
    }

    @objc private func tapped(_ tile: Tile) {
        Haptics.shared.keyPress()
        toolsDelegate?.toolsPanel(self, didPick: tile.tool)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        emptyLabel.frame = bounds
        guard !tiles.isEmpty else { return }
        let tileWidth: CGFloat = 64
        let gap: CGFloat = 2
        for (index, tile) in tiles.enumerated() {
            tile.frame = CGRect(x: CGFloat(index) * (tileWidth + gap), y: 0, width: tileWidth, height: bounds.height)
        }
        contentSize = CGSize(width: CGFloat(tiles.count) * (tileWidth + gap) - gap, height: bounds.height)
    }
}

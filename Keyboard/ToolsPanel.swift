import UIKit

protocol ToolsPanelDelegate: AnyObject {
    func toolsPanel(_ panel: ToolsPanel, didPick tool: KeyboardTool)
    /// On for a tool that is switched on (number row, swipe typing...), nil for one that is an action.
    func toolsPanel(_ panel: ToolsPanel, stateOf tool: KeyboardTool) -> Bool?
    /// What a tool's tile says under its name (the one-handed side), if anything.
    func toolsPanel(_ panel: ToolsPanel, detailOf tool: KeyboardTool) -> String?
    func toolsPanel(_ panel: ToolsPanel, isAvailable tool: KeyboardTool) -> Bool
}

/// The Functions panel: the tools the app's Functions screen picked, as key-like tiles in a grid where the keys
/// were. Tiles of tools that are on light up in the accent.
final class ToolsPanel: UIView {
    weak var delegate: ToolsPanelDelegate?

    private final class Tile: UIControl {
        let tool: KeyboardTool
        private let background = FlatPanel(background: Theme.letterKey, allowGlass: true, followsKeyRoundness: true, keyLike: true)
        private let onFill = UIView()
        private let icon = UIImageView()
        private let title = UILabel()
        private let detail = UILabel()

        init(tool: KeyboardTool) {
            self.tool = tool
            super.init(frame: .zero)
            background.isUserInteractionEnabled = false
            addSubview(background)
            onFill.backgroundColor = Theme.accent
            onFill.layer.cornerCurve = .continuous
            onFill.isUserInteractionEnabled = false
            onFill.isHidden = true
            addSubview(onFill)
            icon.image = UIImage(systemName: tool.symbol,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 19, weight: .regular))
            icon.contentMode = .center
            title.text = tool.title
            title.font = Theme.keyFont(ofSize: 12, weight: .medium)
            title.textAlignment = .center
            title.adjustsFontSizeToFitWidth = true
            title.minimumScaleFactor = 0.7
            detail.font = Theme.keyFont(ofSize: 10)
            detail.textAlignment = .center
            for view in [icon, title, detail] as [UIView] {
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
            let colour = lit ? Theme.onAccent : Theme.keyText
            icon.tintColor = colour
            title.textColor = colour
            detail.textColor = lit ? Theme.onAccent.withAlphaComponent(0.8) : Theme.keySecondaryText
            detail.text = text
            detail.isHidden = text == nil
            alpha = available ? 1 : 0.4
            isEnabled = available
            accessibilityValue = text ?? (on.map { $0 ? "On" : "Off" })
        }

        override var isHighlighted: Bool {
            didSet { background.alpha = isHighlighted ? 0.55 : 1 }
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            background.frame = bounds
            onFill.frame = bounds
            onFill.layer.cornerRadius = Theme.keyCornerRadius(for: bounds.size)
            let hasDetail = !detail.isHidden
            let iconHeight: CGFloat = 24
            let block = iconHeight + 4 + 15 + (hasDetail ? 13 : 0)
            let top = max(2, (bounds.height - block) / 2)
            icon.frame = CGRect(x: 0, y: top, width: bounds.width, height: iconHeight)
            title.frame = CGRect(x: 4, y: icon.frame.maxY + 4, width: bounds.width - 8, height: 15)
            detail.frame = CGRect(x: 4, y: title.frame.maxY, width: bounds.width - 8, height: 13)
        }
    }

    private var tiles: [Tile] = []
    private let emptyLabel = UILabel()

    init(tools: [KeyboardTool]) {
        super.init(frame: .zero)
        // Not fully clear: the system drops touches on pixels of a keyboard that draw nothing.
        backgroundColor = UIColor(white: 0.5, alpha: 0.01)
        for tool in tools {
            let tile = Tile(tool: tool)
            tile.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            addSubview(tile)
            tiles.append(tile)
        }
        emptyLabel.text = "Add functions in the Iramo app: Functions panel"
        emptyLabel.textColor = Theme.keySecondaryText
        emptyLabel.font = UIFont.systemFont(ofSize: 15)
        emptyLabel.textAlignment = .center
        emptyLabel.numberOfLines = 0
        emptyLabel.isHidden = !tools.isEmpty
        addSubview(emptyLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Reads every tile's state again (after a tool changed one).
    func refresh() {
        for tile in tiles {
            tile.show(on: delegate?.toolsPanel(self, stateOf: tile.tool),
                      detail: delegate?.toolsPanel(self, detailOf: tile.tool),
                      available: delegate?.toolsPanel(self, isAvailable: tile.tool) ?? true)
            tile.setNeedsLayout()
        }
    }

    @objc private func tapped(_ tile: Tile) {
        Haptics.shared.keyPress()
        delegate?.toolsPanel(self, didPick: tile.tool)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        emptyLabel.frame = bounds.insetBy(dx: 30, dy: 10)
        guard !tiles.isEmpty else { return }
        let gap = CGFloat(max(4, Prefs.keyGap))
        let inset: CGFloat = 6
        let columns = bounds.width > 600 ? 6 : 4
        let rows = (tiles.count + columns - 1) / columns
        let width = (bounds.width - inset * 2 - gap * CGFloat(columns - 1)) / CGFloat(columns)
        let available = bounds.height - inset * 2 - gap * CGFloat(rows - 1)
        let height = min(max(36, available / CGFloat(max(rows, 2))), 76)
        for (index, tile) in tiles.enumerated() {
            let column = CGFloat(index % columns), row = CGFloat(index / columns)
            tile.frame = CGRect(x: inset + column * (width + gap), y: inset + row * (height + gap),
                                width: width, height: height)
        }
    }
}

import UIKit

struct Suggestion {
    enum Kind {
        case literal           // exactly what has been typed so far
        case word              // dictionary completion or shortcut expansion
        case emoji             // emoji that matches the word
        case swipeAlternative  // another reading of the word that was just swiped
    }
    let text: String
    let kind: Kind
}

enum ToolID {
    case paste
    case oneHanded
    case numberRow
    case dismiss
    case settings          // only offered when the app's settings cannot reach the keyboard
}

struct ToolItem {
    let id: ToolID
    let symbol: String
    var isActive = false
}

protocol SuggestionBarDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBar, didSelect suggestion: Suggestion)
    func suggestionBar(_ bar: SuggestionBar, didTapTool tool: ToolID)
}

/// A flat strip above the keys, like the native one. Normally it shows three suggestion slots (words and emoji);
/// the arrow on its left swaps them for a row of quick tools.
final class SuggestionBar: UIView {
    weak var delegate: SuggestionBarDelegate?

    private let glass = FlatPanel()
    private let toggleButton = UIButton(type: .system)
    private let hintLabel = UILabel()
    private var slotButtons: [UIButton] = []
    private var separators: [UIView] = []
    private var toolButtons: [UIButton] = []
    private var tools: [ToolItem] = []
    private var suggestions: [Suggestion] = []
    private let slotCount = 3

    private(set) var showingTools = false

    /// Shown (in place of suggestions) when there is nothing to suggest.
    var emptyHint: String? {
        didSet { refreshVisibility() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        addSubview(glass)

        toggleButton.tintColor = UIColor.secondaryLabel
        toggleButton.addTarget(self, action: #selector(toggleTapped), for: .touchUpInside)
        glass.contentView.addSubview(toggleButton)
        updateToggleIcon()

        hintLabel.font = UIFont.systemFont(ofSize: 13)
        hintLabel.textColor = UIColor.secondaryLabel
        hintLabel.textAlignment = .center
        hintLabel.adjustsFontSizeToFitWidth = true
        hintLabel.minimumScaleFactor = 0.7
        glass.contentView.addSubview(hintLabel)

        for index in 0..<slotCount {
            let button = UIButton(type: .system)
            button.tag = index
            button.setTitleColor(UIColor.label, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 17)
            button.titleLabel?.adjustsFontSizeToFitWidth = true
            button.titleLabel?.minimumScaleFactor = 0.6
            button.titleLabel?.lineBreakMode = .byTruncatingTail
            button.addTarget(self, action: #selector(slotTapped(_:)), for: .touchUpInside)
            glass.contentView.addSubview(button)
            slotButtons.append(button)

            if index > 0 {
                let line = UIView()
                line.backgroundColor = Theme.separator
                glass.contentView.addSubview(line)
                separators.append(line)
            }
        }
        refreshVisibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Content

    func update(_ newSuggestions: [Suggestion]) {
        suggestions = Array(newSuggestions.prefix(slotCount))
        for (index, button) in slotButtons.enumerated() {
            if index < suggestions.count {
                let item = suggestions[index]
                button.setTitle(item.text, for: .normal)
                button.titleLabel?.font = UIFont.systemFont(ofSize: item.kind == .emoji ? 26 : 17)
                button.isEnabled = true
            } else {
                button.setTitle(nil, for: .normal)
                button.isEnabled = false
            }
        }
        refreshVisibility()
    }

    func setTools(_ items: [ToolItem]) {
        tools = items
        for button in toolButtons { button.removeFromSuperview() }
        toolButtons = []
        for (index, item) in items.enumerated() {
            let button = UIButton(type: .system)
            button.tag = index
            button.setImage(UIImage(systemName: item.symbol,
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)),
                            for: .normal)
            button.tintColor = item.isActive ? Theme.accent : UIColor.label
            button.addTarget(self, action: #selector(toolTapped(_:)), for: .touchUpInside)
            glass.contentView.addSubview(button)
            toolButtons.append(button)
        }
        refreshVisibility()
        setNeedsLayout()
    }

    func setToolActive(_ id: ToolID, active: Bool) {
        for (index, item) in tools.enumerated() where item.id == id {
            tools[index].isActive = active
            toolButtons[index].tintColor = active ? Theme.accent : UIColor.label
        }
    }

    // MARK: Layout

    private func updateToggleIcon() {
        let name = showingTools ? "chevron.left" : "chevron.right"
        toggleButton.setImage(UIImage(systemName: name,
                                      withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .semibold)),
                              for: .normal)
    }

    private func refreshVisibility() {
        let hasSuggestions = !suggestions.isEmpty
        for button in slotButtons { button.isHidden = showingTools }
        for line in separators { line.isHidden = showingTools || !hasSuggestions }
        for button in toolButtons { button.isHidden = !showingTools }
        hintLabel.text = emptyHint
        hintLabel.isHidden = showingTools || hasSuggestions || emptyHint == nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        glass.frame = bounds.insetBy(dx: 2, dy: 3)
        let area = glass.bounds
        let toggleWidth: CGFloat = 40
        toggleButton.frame = CGRect(x: 2, y: 0, width: toggleWidth, height: area.height)

        let contentX = toggleWidth + 2
        let contentWidth = max(0, area.width - contentX - 12)
        hintLabel.frame = CGRect(x: contentX, y: 0, width: contentWidth, height: area.height)

        let slotWidth = contentWidth / CGFloat(slotCount)
        for (index, button) in slotButtons.enumerated() {
            button.frame = CGRect(x: contentX + CGFloat(index) * slotWidth, y: 0, width: slotWidth, height: area.height)
        }
        for (index, line) in separators.enumerated() {
            line.frame = CGRect(x: contentX + CGFloat(index + 1) * slotWidth - 0.5,
                                y: area.height * 0.25,
                                width: 1,
                                height: area.height * 0.5)
        }

        if !toolButtons.isEmpty {
            let toolWidth = contentWidth / CGFloat(toolButtons.count)
            for (index, button) in toolButtons.enumerated() {
                button.frame = CGRect(x: contentX + CGFloat(index) * toolWidth, y: 0, width: toolWidth, height: area.height)
            }
        }
    }

    // MARK: Actions

    @objc private func toggleTapped() {
        showingTools.toggle()
        updateToggleIcon()
        refreshVisibility()
        Haptics.shared.keyPress()
    }

    @objc private func slotTapped(_ sender: UIButton) {
        guard sender.tag < suggestions.count else { return }
        delegate?.suggestionBar(self, didSelect: suggestions[sender.tag])
    }

    @objc private func toolTapped(_ sender: UIButton) {
        guard sender.tag < tools.count else { return }
        delegate?.suggestionBar(self, didTapTool: tools[sender.tag].id)
    }
}

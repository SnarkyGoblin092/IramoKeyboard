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

protocol SuggestionBarDelegate: AnyObject {
    func suggestionBar(_ bar: SuggestionBar, didSelect suggestion: Suggestion)
    func suggestionBarDidTapDismiss(_ bar: SuggestionBar)
}

/// A flat strip above the keys, like the native one: three suggestion slots (words and emoji)
/// and a permanent "hide keyboard" button on the right.
final class SuggestionBar: UIView {
    weak var delegate: SuggestionBarDelegate?

    private let glass = FlatPanel(background: Theme.stripFill)
    private let dismissButton = HitButton(type: .system)
    private let hintLabel = UILabel()
    private var slotButtons: [HitButton] = []
    private var separators: [UIView] = []
    private var suggestions: [Suggestion] = []
    private let slotCount = 3

    /// Shown (in place of suggestions) when there is nothing to suggest.
    var emptyHint: String? {
        didSet { refreshVisibility() }
    }

    /// Flashes a short message in place of the suggestions.
    func flash(_ message: String, duration: TimeInterval = 2.5) {
        let previousHint = emptyHint
        update([])
        emptyHint = message
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self = self, self.emptyHint == message else { return }
            self.emptyHint = previousHint
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.clear
        addSubview(glass)

        hintLabel.font = UIFont.systemFont(ofSize: 13)
        hintLabel.textColor = Theme.secondaryText
        hintLabel.textAlignment = .center
        hintLabel.adjustsFontSizeToFitWidth = true
        hintLabel.minimumScaleFactor = 0.7
        glass.contentView.addSubview(hintLabel)

        for index in 0..<slotCount {
            let button = HitButton(type: .system)
            button.tag = index
            button.setTitleColor(Theme.text, for: .normal)
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

        dismissButton.tintColor = Theme.secondaryText
        dismissButton.setImage(UIImage(systemName: "keyboard.chevron.compact.down",
                                       withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .regular)),
                               for: .normal)
        dismissButton.addTarget(self, action: #selector(dismissTapped), for: .touchUpInside)
        glass.contentView.addSubview(dismissButton)

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

    private func refreshVisibility() {
        let hasSuggestions = !suggestions.isEmpty
        for line in separators { line.isHidden = !hasSuggestions }
        hintLabel.text = emptyHint
        hintLabel.isHidden = hasSuggestions || emptyHint == nil
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        glass.frame = bounds.insetBy(dx: 2, dy: 3)
        let area = glass.bounds
        let dismissWidth: CGFloat = 52
        dismissButton.frame = CGRect(x: area.width - dismissWidth, y: 0, width: dismissWidth, height: area.height)

        let contentWidth = max(0, area.width - dismissWidth - 6)
        hintLabel.frame = CGRect(x: 6, y: 0, width: contentWidth, height: area.height)

        let slotWidth = contentWidth / CGFloat(slotCount)
        for (index, button) in slotButtons.enumerated() {
            button.frame = CGRect(x: 6 + CGFloat(index) * slotWidth, y: 0, width: slotWidth, height: area.height)
        }
        for (index, line) in separators.enumerated() {
            line.frame = CGRect(x: 6 + CGFloat(index + 1) * slotWidth - 0.5,
                                y: area.height * 0.25,
                                width: 1,
                                height: area.height * 0.5)
        }
    }

    // MARK: Touch handling

    /// Every point of the strip (including its margins) belongs to a control: the right end is the hide
    /// button, everything else goes to the suggestion slot at that x position, so a tap never needs to
    /// land on the text itself.
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, bounds.insetBy(dx: -4, dy: -4).contains(point) else { return nil }
        let dismissZone = dismissButton.superview?.convert(dismissButton.frame, to: self) ?? .zero
        if point.x >= dismissZone.minX { return dismissButton }
        if let slot = HitTesting.nearestByX(point.x, in: slotButtons, relativeTo: self), slot.isEnabled {
            return slot
        }
        return super.hitTest(point, with: event)
    }

    // MARK: Actions

    @objc private func slotTapped(_ sender: UIButton) {
        guard sender.tag < suggestions.count else { return }
        delegate?.suggestionBar(self, didSelect: suggestions[sender.tag])
    }

    @objc private func dismissTapped() {
        Haptics.shared.keyPress()
        delegate?.suggestionBarDidTapDismiss(self)
    }
}

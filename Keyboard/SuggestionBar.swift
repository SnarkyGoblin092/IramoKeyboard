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
    private let dismissIcon = UIImageView()
    private let dismissHighlight = UIView()
    private let hintLabel = UILabel()
    private var slotLabels: [UILabel] = []
    private var slotHighlights: [UIView] = []
    private var separators: [UIView] = []
    private var suggestions: [Suggestion] = []
    private let slotCount = 3

    /// Layout cache used by the touch handling (the whole strip is one touch surface).
    private var slotMinX: CGFloat = 0
    private var slotWidth: CGFloat = 0
    private var dismissMinX: CGFloat = 0

    /// What the current touch went down on: a slot index, `dismissIndex`, or nil.
    private let dismissIndex = -1
    private var pressedIndex: Int?
    private var touchStart = CGPoint.zero

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
        isMultipleTouchEnabled = false
        addSubview(glass)

        hintLabel.font = UIFont.systemFont(ofSize: 13)
        hintLabel.textColor = Theme.secondaryText
        hintLabel.textAlignment = .center
        hintLabel.adjustsFontSizeToFitWidth = true
        hintLabel.minimumScaleFactor = 0.7
        glass.contentView.addSubview(hintLabel)

        for index in 0..<slotCount {
            // Highlight (pressed state) below the label; both are purely visual - the bar itself takes the touches.
            let highlight = UIView()
            highlight.backgroundColor = Theme.accent.withAlphaComponent(0.22)
            highlight.alpha = 0
            glass.contentView.addSubview(highlight)
            slotHighlights.append(highlight)

            let label = UILabel()
            label.textColor = Theme.text
            label.font = UIFont.systemFont(ofSize: 17)
            label.textAlignment = .center
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.6
            label.lineBreakMode = .byTruncatingTail
            glass.contentView.addSubview(label)
            slotLabels.append(label)

            if index > 0 {
                let line = UIView()
                line.backgroundColor = Theme.separator
                glass.contentView.addSubview(line)
                separators.append(line)
            }
        }

        dismissHighlight.backgroundColor = Theme.accent.withAlphaComponent(0.22)
        dismissHighlight.alpha = 0
        glass.contentView.addSubview(dismissHighlight)

        dismissIcon.tintColor = Theme.accent
        dismissIcon.contentMode = .center
        dismissIcon.image = UIImage(systemName: "keyboard.chevron.compact.down",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .regular))
        glass.contentView.addSubview(dismissIcon)

        // Nothing inside the strip takes touches itself: the bar decides from the x position.
        for view in [glass as UIView, hintLabel, dismissIcon, dismissHighlight] { view.isUserInteractionEnabled = false }
        glass.contentView.isUserInteractionEnabled = false
        for view in slotLabels + slotHighlights + separators { view.isUserInteractionEnabled = false }

        refreshVisibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Content

    /// `highlighted`: the slot space will write (the auto-correction), shown in the accent colour.
    func update(_ newSuggestions: [Suggestion], highlighted: Int? = nil) {
        suggestions = Array(newSuggestions.prefix(slotCount))
        for (index, label) in slotLabels.enumerated() {
            if index < suggestions.count {
                let item = suggestions[index]
                label.text = item.text
                let isBest = (index == highlighted)
                label.font = UIFont.systemFont(ofSize: item.kind == .emoji ? 26 : 17, weight: isBest ? .semibold : .regular)
                label.textColor = isBest ? Theme.accent : Theme.text
            } else {
                label.text = nil
            }
        }
        setPressed(nil)
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
        let contentWidth = max(0, area.width - dismissWidth - 6)

        slotMinX = 6
        slotWidth = contentWidth / CGFloat(slotCount)
        dismissMinX = area.width - dismissWidth

        dismissIcon.frame = CGRect(x: dismissMinX, y: 0, width: dismissWidth, height: area.height)
        // The pressed state is a circle around the icon.
        let circle = min(area.height - 2, dismissWidth - 6)
        dismissHighlight.frame = CGRect(x: dismissIcon.frame.midX - circle / 2, y: (area.height - circle) / 2,
                                        width: circle, height: circle)
        hintLabel.frame = CGRect(x: 6, y: 0, width: contentWidth, height: area.height)

        let radius = Theme.keyCornerRadius(for: CGSize(width: slotWidth, height: area.height))
        for index in 0..<slotCount {
            let frame = CGRect(x: slotMinX + CGFloat(index) * slotWidth, y: 0, width: slotWidth, height: area.height)
            slotHighlights[index].frame = frame.insetBy(dx: 2, dy: 2)
            slotHighlights[index].layer.cornerRadius = radius
            slotLabels[index].frame = frame.insetBy(dx: 6, dy: 0)
        }
        dismissHighlight.layer.cornerRadius = circle / 2
        for (index, line) in separators.enumerated() {
            line.frame = CGRect(x: slotMinX + CGFloat(index + 1) * slotWidth - 0.5,
                                y: area.height * 0.25,
                                width: 1,
                                height: area.height * 0.5)
        }
    }

    // MARK: Touch handling
    //
    // The whole strip is a single touch surface. Wherever the finger lands (margins and gaps
    // included) the x position decides: right end = hide keyboard, otherwise the suggestion slot
    // whose separated area contains it. Nothing depends on touching the word itself.

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, bounds.insetBy(dx: -4, dy: -4).contains(point) else { return nil }
        return self
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.insetBy(dx: -4, dy: -4).contains(point)
    }

    private func index(at point: CGPoint) -> Int? {
        let x = point.x - glass.frame.minX
        if x >= dismissMinX { return dismissIndex }
        guard slotWidth > 0 else { return nil }
        let raw = Int(floor((x - slotMinX) / slotWidth))
        let clamped = min(max(raw, 0), slotCount - 1)
        return clamped < suggestions.count ? clamped : nil
    }

    private func setPressed(_ index: Int?) {
        if pressedIndex == index { return }
        if let old = pressedIndex { highlight(old, on: false) }
        pressedIndex = index
        if let new = index { highlight(new, on: true) }
    }

    private func highlight(_ index: Int, on: Bool) {
        let view = (index == dismissIndex) ? dismissHighlight : slotHighlights[index]
        view.alpha = on ? 1 : 0
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        touchStart = touch.location(in: self)
        setPressed(index(at: touchStart))
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let point = touch.location(in: self)
        // Keep the press while the finger stays near its start; a long drag cancels it.
        if hypot(point.x - touchStart.x, point.y - touchStart.y) > 40 { setPressed(nil) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { setPressed(nil) }
        guard let pressed = pressedIndex else { return }
        if pressed == dismissIndex {
            Haptics.shared.keyPress()
            delegate?.suggestionBarDidTapDismiss(self)
        } else if pressed < suggestions.count {
            delegate?.suggestionBar(self, didSelect: suggestions[pressed])
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        setPressed(nil)
    }
}

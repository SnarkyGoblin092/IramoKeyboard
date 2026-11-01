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

/// The strip above the keys: suggestion slots (words and emoji) and a permanent "hide keyboard" button on the
/// right. Set up by the Suggestions screen of the app:
///  - three equal slots like the native bar, slots sized to their words so more fit ("Fit more"), or up to ten
///    in a strip that scrolls sideways ("Scrollable");
///  - thin separators between the slots (solid, dashed, dotted or none), or each slot on a key-like segment;
///  - colours from the theme ("Follow theme") or neutral ones.
final class SuggestionBar: UIView {
    weak var delegate: SuggestionBarDelegate?

    /// How many suggestions the bar can show with the current settings (the controller asks for this many).
    static var capacity: Int {
        if Prefs.suggestionScroll { return 10 }
        return Prefs.suggestionFit ? 6 : 3
    }

    private enum Layout { case equal, fit, scroll }
    private let layoutMode: Layout
    private let segments: Bool
    private let followTheme: Bool

    private let glass = FlatPanel(background: Theme.stripFill)
    /// Holds the slots. It scrolls only in the scrollable layout; otherwise the bar handles the touches itself.
    private let strip = UIScrollView()
    private let dismissIcon = UIImageView()
    private let hintLabel = UILabel()
    /// The accent pill behind the word space will write (the auto-correction).
    private let bestPill = UIView()

    private var labels: [UILabel] = []
    private var highlights: [UIView] = []
    private var segmentViews: [UIView] = []
    /// Liquid Glass theme: real glass behind the pill and the segments.
    private let usesGlass = Theme.usesRealGlass
    private var pillGlass: UIVisualEffectView?
    private var segmentGlass: [UIVisualEffectView?] = []
    /// The pressed highlight behind a word: drawn exactly like the pill (accent fill, or accent-tinted glass).
    private var highlightGlass: [UIVisualEffectView?] = []
    private let separatorLayer = CAShapeLayer()

    private var suggestions: [Suggestion] = []
    private var highlightedIndex: Int?
    /// Where each suggestion is drawn, in the strip's content coordinates.
    private var slotFrames: [CGRect] = []

    private var dismissMinX: CGFloat = 0
    private let dismissIndex = -1
    private var pressedIndex: Int?
    private var touchStart = CGPoint.zero

    /// Shown (in place of suggestions) when there is nothing to suggest.
    var emptyHint: String? {
        didSet { refreshVisibility() }
    }

    override init(frame: CGRect) {
        layoutMode = Prefs.suggestionScroll ? .scroll : (Prefs.suggestionFit ? .fit : .equal)
        segments = Prefs.suggestionStyle == "segments"
        followTheme = Prefs.suggestionFollowTheme
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

        strip.showsHorizontalScrollIndicator = false
        strip.alwaysBounceHorizontal = layoutMode == .scroll
        strip.isScrollEnabled = layoutMode == .scroll
        strip.isUserInteractionEnabled = layoutMode == .scroll
        strip.clipsToBounds = true
        glass.contentView.addSubview(strip)
        if layoutMode == .scroll {
            // The strip pans by itself; a tap picks the suggestion under the finger.
            strip.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(stripTapped(_:))))
        }

        separatorLayer.fillColor = nil
        separatorLayer.lineWidth = 1
        switch Prefs.separatorStyle {
        case "dashed": separatorLayer.lineDashPattern = [4, 3]
        case "dotted":
            separatorLayer.lineDashPattern = [1, 3]
            separatorLayer.lineCap = .round
            separatorLayer.lineWidth = 1.5
        default: break
        }
        separatorLayer.isHidden = segments || Prefs.separatorStyle == "none"
        strip.layer.addSublayer(separatorLayer)

        bestPill.backgroundColor = Theme.accent
        bestPill.layer.cornerCurve = .continuous
        bestPill.isHidden = true
        strip.addSubview(bestPill)
        if usesGlass {
            // Accent-tinted glass, like the keys' glass.
            pillGlass = GlassSupport.addBackground(to: bestPill, tint: Theme.accent.withAlphaComponent(0.85))
        }

        dismissIcon.tintColor = Theme.accent
        dismissIcon.contentMode = .center
        // Drawn smaller than its touch area, which is still the bar's whole right end (`dismissMinX`).
        dismissIcon.image = UIImage(systemName: "keyboard.chevron.compact.down",
                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .regular))
        glass.contentView.addSubview(dismissIcon)

        // Nothing but the strip takes touches itself: the bar decides from the x position.
        for view in [glass as UIView, hintLabel, dismissIcon, bestPill] { view.isUserInteractionEnabled = false }
        if layoutMode != .scroll { glass.contentView.isUserInteractionEnabled = false }

        refreshVisibility()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: Colours

    /// Separators: a faded version of the theme's key labels, or the neutral system hairline.
    private var separatorColor: UIColor {
        return followTheme ? Theme.keySecondaryText.withAlphaComponent(0.45) : Theme.separator
    }

    /// Segments: the theme's letter keys, or a neutral wash.
    private var segmentColor: UIColor {
        if followTheme { return Theme.letterKey }
        return UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.12) : UIColor(white: 0, alpha: 0.06) }
    }

    private var textColor: UIColor {
        return followTheme && segments ? Theme.keyText : Theme.text
    }

    // MARK: Content

    /// `highlighted`: the slot space will write (the auto-correction), shown on an accent-coloured pill.
    func update(_ newSuggestions: [Suggestion], highlighted: Int? = nil) {
        let incoming = Array(newSuggestions.prefix(SuggestionBar.capacity))
        // A picture of the old words, animated away while the new ones come in (the Switching setting).
        var outgoing: UIView?
        if Prefs.suggestionTransition != "instant", window != nil, !strip.bounds.isEmpty,
           incoming.map({ $0.text }) != suggestions.map({ $0.text }),
           suggestions.contains(where: { !$0.text.isEmpty }) || incoming.contains(where: { !$0.text.isEmpty }) {
            outgoing = strip.snapshotView(afterScreenUpdates: false)
        }
        suggestions = incoming
        highlightedIndex = nil
        if let index = highlighted, index < suggestions.count, !suggestions[index].text.isEmpty {
            highlightedIndex = index
        }
        while labels.count < suggestions.count { addSlot() }
        for (index, label) in labels.enumerated() {
            guard index < suggestions.count else {
                label.text = nil
                label.isHidden = true
                segmentViews[index].isHidden = true
                continue
            }
            label.isHidden = false
            label.text = suggestions[index].text
            styleLabel(index, onPill: index == highlightedIndex)
            segmentViews[index].isHidden = !segments || suggestions[index].text.isEmpty
        }
        bestPill.isHidden = highlightedIndex == nil
        strip.contentOffset = .zero
        setPressed(nil)
        refreshVisibility()
        setNeedsLayout()
        if let old = outgoing { animateSwitch(from: old) }
    }

    /// Where the strip sits in the bar, whatever transform a switch has on it.
    private var stripRect: CGRect {
        return CGRect(x: strip.center.x - strip.bounds.width / 2, y: strip.center.y - strip.bounds.height / 2,
                      width: strip.bounds.width, height: strip.bounds.height)
    }

    /// The old words' picture, still on its way out when newer words arrive.
    private weak var leaving: UIView?

    /// Moves the old words (a snapshot) out and the new ones in, the way the Switching setting says: a cross-fade,
    /// rising up, sliding along in the reading direction, or popping in.
    private func animateSwitch(from old: UIView) {
        leaving?.removeFromSuperview()
        layoutIfNeeded()
        old.frame = stripRect
        old.isUserInteractionEnabled = false
        glass.contentView.insertSubview(old, aboveSubview: strip)
        leaving = old

        let shift: CGFloat = effectiveUserInterfaceLayoutDirection == .rightToLeft ? -18 : 18
        var outgoing = CGAffineTransform.identity
        var incoming = CGAffineTransform.identity
        var duration = 0.18
        switch Prefs.suggestionTransition {
        case "rise":
            outgoing = CGAffineTransform(translationX: 0, y: -10)
            incoming = CGAffineTransform(translationX: 0, y: 10)
        case "slide":
            outgoing = CGAffineTransform(translationX: -shift, y: 0)
            incoming = CGAffineTransform(translationX: shift, y: 0)
        case "pop":
            outgoing = CGAffineTransform(scaleX: 0.92, y: 0.92)
            incoming = CGAffineTransform(scaleX: 0.85, y: 0.85)
            duration = 0.26
        default:
            duration = 0.16   // fade
        }
        strip.alpha = 0
        strip.transform = incoming
        let damping: CGFloat = Prefs.suggestionTransition == "pop" ? 0.7 : 1
        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: 0,
                       options: [.beginFromCurrentState, .allowUserInteraction], animations: {
            self.strip.alpha = 1
            self.strip.transform = .identity
            old.alpha = 0
            old.transform = outgoing
        }, completion: { _ in old.removeFromSuperview() })
    }

    /// A word on the pill (the auto-correction, or one being pressed) is semibold in the colour that reads on the
    /// accent; the others are regular in the bar's text colour.
    private func styleLabel(_ index: Int, onPill: Bool) {
        guard index < labels.count, index < suggestions.count else { return }
        labels[index].font = suggestions[index].kind == .emoji ? UIFont.systemFont(ofSize: 26)
            : Theme.keyFont(ofSize: 17, weight: onPill ? .semibold : .regular)
        labels[index].textColor = onPill ? Theme.onAccent : textColor
    }

    private func addSlot() {
        let segment = UIView()
        segment.backgroundColor = segmentColor
        segment.layer.cornerCurve = .continuous
        segment.isUserInteractionEnabled = false
        strip.insertSubview(segment, at: 0)
        segmentViews.append(segment)
        segmentGlass.append(usesGlass ? GlassSupport.addBackground(to: segment, tint: nil) : nil)

        let highlight = UIView()
        highlight.backgroundColor = Theme.accent
        highlight.layer.cornerCurve = .continuous
        highlight.alpha = 0
        highlight.isUserInteractionEnabled = false
        strip.addSubview(highlight)
        highlights.append(highlight)
        highlightGlass.append(usesGlass ? GlassSupport.addBackground(to: highlight, tint: Theme.accent.withAlphaComponent(0.85)) : nil)

        let label = UILabel()
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.lineBreakMode = .byTruncatingTail
        label.isUserInteractionEnabled = false
        strip.addSubview(label)
        labels.append(label)
    }

    private func refreshVisibility() {
        let hasSuggestions = suggestions.contains { !$0.text.isEmpty }
        separatorLayer.opacity = hasSuggestions ? 1 : 0
        hintLabel.text = emptyHint
        hintLabel.isHidden = hasSuggestions || emptyHint == nil
    }

    // MARK: Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // Centred between the keyboard's top edge and the first row of keys (which starts ~9.5pt below the bar),
        // not just within the bar.
        glass.frame = bounds.insetBy(dx: 2, dy: 3).offsetBy(dx: 0, dy: 4.5)
        let area = glass.bounds
        let dismissWidth: CGFloat = 52
        let contentWidth = max(0, area.width - dismissWidth - 6)
        dismissMinX = area.width - dismissWidth

        dismissIcon.frame = CGRect(x: dismissMinX, y: 0, width: dismissWidth, height: area.height)
        hintLabel.frame = CGRect(x: 6, y: 0, width: contentWidth, height: area.height)
        // Bounds and centre rather than frame: the strip may be mid-switch with a transform.
        strip.bounds.size = CGSize(width: contentWidth, height: area.height)
        strip.center = CGPoint(x: 6 + contentWidth / 2, y: area.height / 2)

        var frames: [CGRect] = []
        for width in slotWidths(contentWidth: contentWidth) {
            frames.append(CGRect(x: frames.last?.maxX ?? 0, y: 0, width: width, height: area.height))
        }
        slotFrames = frames
        strip.contentSize = CGSize(width: max(contentWidth, frames.last?.maxX ?? 0), height: area.height)

        let segmentRadius = Theme.keyCornerRadius(for: CGSize(width: 60, height: max(0, area.height - 6)))
        let separators = UIBezierPath()
        for (index, label) in labels.enumerated() {
            guard index < frames.count, frames[index].width > 0 else {
                // A word that did not fit ("Fit more" shows only what fits).
                label.isHidden = true
                segmentViews[index].isHidden = true
                continue
            }
            let frame = frames[index]
            label.frame = frame.insetBy(dx: 6, dy: 0)
            let (pillFrame, pillRadius) = pillShape(for: index, in: frame, areaHeight: area.height, segmentRadius: segmentRadius)
            highlights[index].frame = pillFrame
            highlights[index].layer.cornerRadius = pillRadius
            if let glassPiece = highlightGlass[index] {
                glassPiece.frame = highlights[index].bounds
                GlassSupport.applyShape(glassPiece, radius: highlights[index].layer.cornerRadius,
                                        size: highlights[index].bounds.size)
            }
            segmentViews[index].frame = frame.insetBy(dx: 2.5, dy: 3)
            segmentViews[index].layer.cornerRadius = segmentRadius
            if let glassPiece = segmentGlass[index] {
                glassPiece.frame = segmentViews[index].bounds
                GlassSupport.applyShape(glassPiece, radius: segmentRadius, size: segmentViews[index].bounds.size)
            }
        }
        // A line between neighbouring slots (also the empty ones of the three-slot bar, like the native bar).
        for frame in frames.dropFirst() where frame.minX > 0 && frame.width > 0 {
            separators.move(to: CGPoint(x: frame.minX, y: area.height * 0.25))
            separators.addLine(to: CGPoint(x: frame.minX, y: area.height * 0.75))
        }
        separatorLayer.frame = CGRect(origin: .zero, size: strip.contentSize)
        separatorLayer.path = separators.cgPath
        separatorLayer.strokeColor = separatorColor.resolvedColor(with: traitCollection).cgColor

        if let best = highlightedIndex, best < frames.count, frames[best].width > 0 {
            let (pillFrame, pillRadius) = pillShape(for: best, in: frames[best], areaHeight: area.height, segmentRadius: segmentRadius)
            bestPill.frame = pillFrame
            bestPill.layer.cornerRadius = pillRadius
            if let glassPiece = pillGlass {
                glassPiece.frame = bestPill.bounds
                GlassSupport.applyShape(glassPiece, radius: bestPill.layer.cornerRadius, size: bestPill.bounds.size)
            }
        }
    }

    /// The accent pill of a slot (the auto-correction's, and a pressed word's): with segments the segment itself;
    /// otherwise a bubble hugging the word, like the system's auto-correction bubble, with the keys' corner style.
    private func pillShape(for index: Int, in frame: CGRect, areaHeight: CGFloat, segmentRadius: CGFloat) -> (CGRect, CGFloat) {
        if segments || index >= suggestions.count { return (frame.insetBy(dx: 2.5, dy: 3), segmentRadius) }
        let item = suggestions[index]
        // Measured in the pill's semibold, so a pressed word gets the same bubble as the auto-correction would.
        let textWidth = item.kind == .emoji ? labels[index].intrinsicContentSize.width
            : ceil((item.text as NSString).size(withAttributes: [.font: Theme.keyFont(ofSize: 17, weight: .semibold)]).width)
        let width = min(frame.width - 4, max(textWidth + 28, areaHeight * 1.6))
        let height = max(0, areaHeight - 8)
        let size = CGSize(width: width, height: height)
        return (CGRect(x: frame.midX - width / 2, y: (areaHeight - height) / 2, width: width, height: height),
                min(height / 2, Theme.keyCornerRadius(for: size) * 1.6))
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        separatorLayer.strokeColor = separatorColor.resolvedColor(with: traitCollection).cgColor
    }

    /// The width of each suggestion's slot.
    private func slotWidths(contentWidth: CGFloat) -> [CGFloat] {
        let count = suggestions.count
        let equal = Array(repeating: contentWidth / 3, count: max(count, 3))
        guard layoutMode != .equal, count > 0 else { return equal }
        // Each word as wide as it needs (with room around it), never narrower than a key or two.
        var natural: [CGFloat] = []
        for (index, item) in suggestions.enumerated() {
            let font = item.kind == .emoji ? UIFont.systemFont(ofSize: 26)
                : Theme.keyFont(ofSize: 17, weight: index == highlightedIndex ? .semibold : .regular)
            let text = (item.text as NSString).size(withAttributes: [.font: font]).width
            natural.append(item.text.isEmpty ? 0 : max(56, ceil(text) + 30))
        }
        let shown = CGFloat(natural.filter { $0 > 0 }.count)
        if layoutMode == .scroll {
            let total = natural.reduce(0, +)
            guard total < contentWidth, shown > 0 else { return natural }
            let extra = (contentWidth - total) / shown
            return natural.map { $0 > 0 ? $0 + extra : 0 }
        }
        // Fit more: as many words as fit, in order; the room left over is shared out.
        var fitted: [CGFloat] = []
        var used: CGFloat = 0
        for width in natural {
            if used + width > contentWidth { break }
            fitted.append(width)
            used += width
        }
        guard fitted.count >= 3 else { return equal }
        let fittedShown = CGFloat(fitted.filter { $0 > 0 }.count)
        let extra = fittedShown > 0 ? (contentWidth - used) / fittedShown : 0
        // Words that did not fit get no room (their labels end up empty-sized at the end).
        return fitted.map { $0 > 0 ? $0 + extra : 0 } + Array(repeating: 0, count: count - fitted.count)
    }

    // MARK: Touch handling
    //
    // The whole strip is a single touch surface. Wherever the finger lands (margins and gaps included) the x
    // position decides: right end = hide keyboard, otherwise the suggestion slot whose area contains it. In the
    // scrollable layout the strip itself takes the touches (it pans, and a tap picks a suggestion).

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, alpha > 0.01, bounds.insetBy(dx: -4, dy: -4).contains(point) else { return nil }
        if layoutMode == .scroll && point.x - glass.frame.minX < dismissMinX { return strip }
        return self
    }

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.insetBy(dx: -4, dy: -4).contains(point)
    }

    /// The suggestion whose slot is nearest to `x` (in the strip's content coordinates).
    private func slot(atContentX x: CGFloat) -> Int? {
        var best: Int?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, frame) in slotFrames.enumerated() where index < suggestions.count && frame.width > 0 {
            let distance = x < frame.minX ? frame.minX - x : (x > frame.maxX ? x - frame.maxX : 0)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    private func index(at point: CGPoint) -> Int? {
        let x = point.x - glass.frame.minX
        if x >= dismissMinX { return dismissIndex }
        return slot(atContentX: x - stripRect.minX + strip.contentOffset.x)
    }

    private func setPressed(_ index: Int?) {
        if pressedIndex == index { return }
        if let old = pressedIndex { highlight(old, on: false) }
        pressedIndex = index
        if let new = index { highlight(new, on: true) }
    }

    private func highlight(_ index: Int, on: Bool) {
        if index == dismissIndex {
            // No background behind the icon: it just dims while held, like a system button.
            dismissIcon.alpha = on ? 0.35 : 1
            return
        }
        guard index < highlights.count else { return }
        highlights[index].alpha = on ? 1 : 0
        styleLabel(index, onPill: on || index == highlightedIndex)
    }

    @objc private func stripTapped(_ recognizer: UITapGestureRecognizer) {
        guard let index = slot(atContentX: recognizer.location(in: strip).x), !suggestions[index].text.isEmpty else { return }
        let picked = suggestions[index]
        highlight(index, on: true)
        UIView.animate(withDuration: 0.25, animations: { self.highlights[index].alpha = 0 },
                       completion: { _ in self.styleLabel(index, onPill: index == self.highlightedIndex) })
        delegate?.suggestionBar(self, didSelect: picked)
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

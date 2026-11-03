import UIKit

/// The Hitboxes screen's drawing over the live keyboard. It takes no touches: the keys under it still type.
/// - hitboxes: a tinted box over every letter where its touch area is, with every hitbox setting (letter room,
///   adaptive keys, the hit map) as the keyboard applies them (KeyboardView.touchOutlines).
/// - hitMap: what the hit map learned: a tinted box where a moved key's room has gone (KeyboardView.hitMapOutlines).
final class HitboxOverlay: UIView {
    enum Mode {
        case hitboxes
        case hitMap
    }

    weak var keyboard: KeyboardView?

    var mode: Mode = .hitboxes {
        didSet { if mode != oldValue { setNeedsDisplay() } }
    }

    /// How far each box sits inside its area, so neighbouring boxes stay apart.
    private let inset: CGFloat = 1.5
    /// The boxes' corner radius, the same at every size (as the Hit map draws them).
    private let cornerRadius: CGFloat = 8

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func draw(_ rect: CGRect) {
        guard let keyboard = keyboard, let context = UIGraphicsGetCurrentContext() else { return }
        let accent = tintColor ?? UIColor.systemBlue
        switch mode {
        case .hitboxes:
            for outline in keyboard.touchOutlines() where outline.letter != nil {
                guard let path = box(keyboard.convert(outline.rect, to: self)) else { continue }
                highlight(path, accent: accent, in: context)
            }
        case .hitMap:
            for outline in keyboard.hitMapOutlines() {
                if let moved = outline.moved, let path = box(keyboard.convert(moved, to: self)) {
                    highlight(path, accent: accent, in: context)
                }
            }
        }
    }

    private func box(_ frame: CGRect) -> UIBezierPath? {
        let frame = frame.insetBy(dx: inset, dy: inset)
        guard frame.width > 0, frame.height > 0 else { return nil }
        return UIBezierPath(roundedRect: frame, cornerRadius: min(cornerRadius, frame.width / 2, frame.height / 2))
    }

    /// The Hit map's look: a tinted fill with a solid outline.
    private func highlight(_ path: UIBezierPath, accent: UIColor, in context: CGContext) {
        context.setFillColor(accent.withAlphaComponent(0.28).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
        stroke(path, accent, width: 1.5, in: context)
    }

    private func stroke(_ path: UIBezierPath, _ color: UIColor, width: CGFloat, in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.addPath(path.cgPath)
        context.strokePath()
    }
}

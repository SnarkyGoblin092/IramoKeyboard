import UIKit

/// The Hitboxes screen's drawing over the live keyboard. It takes no touches: the keys under it still type.
/// A tinted box over every letter where its touch area is, with every hitbox setting (letter room, adaptive keys,
/// the hit map) as the keyboard applies them (KeyboardView.touchOutlines); a key the hit map has moved the room of
/// gets a stronger box, so what was learned shows in the same picture (KeyboardView.hitMapOutlines).
final class HitboxOverlay: UIView {
    weak var keyboard: KeyboardView?

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
        for outline in keyboard.touchOutlines() where outline.letter != nil {
            guard let path = box(keyboard.convert(outline.rect, to: self)) else { continue }
            highlight(path, accent: accent, fill: 0.22, width: 1.5, in: context)
        }
        for outline in keyboard.hitMapOutlines() {
            guard let moved = outline.moved, let path = box(keyboard.convert(moved, to: self)) else { continue }
            highlight(path, accent: accent, fill: 0.2, width: 3, in: context)
        }
    }

    private func box(_ frame: CGRect) -> UIBezierPath? {
        let frame = frame.insetBy(dx: inset, dy: inset)
        guard frame.width > 0, frame.height > 0 else { return nil }
        return UIBezierPath(roundedRect: frame, cornerRadius: min(cornerRadius, frame.width / 2, frame.height / 2))
    }

    /// A tinted fill with a solid outline.
    private func highlight(_ path: UIBezierPath, accent: UIColor, fill: CGFloat, width: CGFloat, in context: CGContext) {
        context.setFillColor(accent.withAlphaComponent(fill).cgColor)
        context.addPath(path.cgPath)
        context.fillPath()
        stroke(path, accent, width: width, in: context)
    }

    private func stroke(_ path: UIBezierPath, _ color: UIColor, width: CGFloat, in context: CGContext) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.addPath(path.cgPath)
        context.strokePath()
    }
}

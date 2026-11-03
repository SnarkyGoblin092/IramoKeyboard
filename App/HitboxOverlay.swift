import UIKit

/// The Hitboxes screen's drawing over the live keyboard: an outline round every key where its touch area is, with
/// every hitbox setting (letter room, adaptive keys, the hit map) as the keyboard applies them
/// (KeyboardView.touchOutlines). A letter given more room is outlined bolder, one given less fainter. It takes no
/// touches: the keys under it still type.
final class HitboxOverlay: UIView {
    weak var keyboard: KeyboardView?

    /// How far the outline stands off a key whose area is unchanged, so it reads as a ring round the key.
    private let standOff: CGFloat = 2

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
        for outline in keyboard.touchOutlines() {
            let frame = keyboard.convert(outline.rect, to: self).insetBy(dx: -standOff, dy: -standOff)
            let path = UIBezierPath(roundedRect: frame, cornerRadius: outline.cornerRadius + standOff)
            let color: UIColor
            let width: CGFloat
            if outline.letter == nil {
                color = UIColor.white.withAlphaComponent(0.3)
                width = 1
            } else if outline.factor > 1.001 {
                color = accent
                width = 2
            } else if outline.factor < 0.999 {
                color = accent.withAlphaComponent(0.55)
                width = 1.25
            } else {
                color = accent.withAlphaComponent(0.85)
                width = 1.5
            }
            context.setStrokeColor(color.cgColor)
            context.setLineWidth(width)
            context.addPath(path.cgPath)
            context.strokePath()
        }
    }
}

import UIKit

/// The Hitboxes screen's drawing over the live keyboard: where a tap counts as which key, with every hitbox setting
/// (letter room, adaptive keys, the hit map), worked out by the keyboard's own hit test (KeyboardView.touchArea).
/// The letters' areas are tinted, more strongly the more room adaptive keys give them, and a line runs between
/// neighbouring areas. It takes no touches: the keys under it still type.
final class HitboxOverlay: UIView {
    weak var keyboard: KeyboardView?

    /// How finely the areas are sampled, in keyboard points.
    private let step: CGFloat = 2

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
        guard let keyboard = keyboard, let context = UIGraphicsGetCurrentContext(), bounds.width > 0 else { return }
        let columns = Int(ceil(bounds.width / step))
        let lines = Int(ceil(bounds.height / step))
        var ids = [Int](repeating: -1, count: columns * lines)
        var letters = [Character?](repeating: nil, count: columns * lines)
        for y in 0..<lines {
            for x in 0..<columns {
                let point = CGPoint(x: (CGFloat(x) + 0.5) * step, y: (CGFloat(y) + 0.5) * step)
                if let area = keyboard.touchArea(at: convert(point, to: keyboard)) {
                    ids[y * columns + x] = area.id
                    letters[y * columns + x] = area.letter
                }
            }
        }

        let accent = tintColor ?? UIColor.systemBlue
        let bias = keyboard.letterBias
        let grow = max(CGFloat(Prefs.adaptiveGrow * Prefs.adaptiveStrength), 0.01)
        let shrink = max(CGFloat(Prefs.adaptiveShrink * Prefs.adaptiveStrength), 0.01)
        // The areas: letters in the accent (likely ones stronger, unlikely ones fainter), the other keys grey.
        for y in 0..<lines {
            for x in 0..<columns {
                let index = y * columns + x
                guard ids[index] >= 0 else { continue }
                let alpha: CGFloat
                if let letter = letters[index] {
                    let factor = (bias[letter] ?? 1) - 1
                    alpha = factor >= 0 ? 0.16 + 0.34 * min(factor / grow, 1) : 0.16 - 0.12 * min(-factor / shrink, 1)
                    context.setFillColor(accent.withAlphaComponent(alpha).cgColor)
                } else {
                    context.setFillColor(UIColor.gray.withAlphaComponent(0.12).cgColor)
                }
                context.fill(CGRect(x: CGFloat(x) * step, y: CGFloat(y) * step, width: step, height: step))
            }
        }
        // The borders between areas.
        context.setFillColor(accent.withAlphaComponent(0.9).cgColor)
        let line: CGFloat = 1
        for y in 0..<lines {
            for x in 0..<columns {
                let id = ids[y * columns + x]
                guard id >= 0 else { continue }
                if x + 1 < columns, ids[y * columns + x + 1] != id {
                    context.fill(CGRect(x: CGFloat(x + 1) * step - line / 2, y: CGFloat(y) * step, width: line, height: step))
                }
                if y + 1 < lines, ids[(y + 1) * columns + x] != id {
                    context.fill(CGRect(x: CGFloat(x) * step, y: CGFloat(y + 1) * step - line / 2, width: step, height: line))
                }
            }
        }
    }
}

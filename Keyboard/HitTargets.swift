import UIKit

/// A button whose touch area is never smaller than 44 x 44 pt, however small it is drawn.
/// (A parent must also let the touch reach it: its own bounds have to contain the point, so the
/// containers in this keyboard forward touches in their margins to the nearest control as well.)
class HitButton: UIButton {
    var minimumHitSize = CGSize(width: 44, height: 44)

    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        let dx = max(0, (minimumHitSize.width - bounds.width) / 2)
        let dy = max(0, (minimumHitSize.height - bounds.height) / 2)
        return bounds.insetBy(dx: -dx, dy: -dy).contains(point)
    }
}

enum HitTesting {
    /// The control in `candidates` whose horizontal span is closest to `x` (spans may be in any order).
    static func nearestByX(_ x: CGFloat, in candidates: [UIView], relativeTo container: UIView) -> UIView? {
        var best: UIView?
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for view in candidates where !view.isHidden && view.isUserInteractionEnabled {
            let frame = view.superview?.convert(view.frame, to: container) ?? view.frame
            let distance: CGFloat
            if x < frame.minX {
                distance = frame.minX - x
            } else if x > frame.maxX {
                distance = x - frame.maxX
            } else {
                distance = 0
            }
            if distance < bestDistance {
                bestDistance = distance
                best = view
            }
        }
        return best
    }
}

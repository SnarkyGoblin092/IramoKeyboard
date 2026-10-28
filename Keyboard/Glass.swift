import UIKit

/// iOS 26 "Liquid Glass" helpers. Everything is guarded so the project still builds with older SDKs and
/// falls back to a plain blur on iOS 25 and earlier.
enum GlassSupport {
    /// True when this build and this iPhone can use the real glass engine (`UIGlassEffect`).
    static var isAvailable: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    /// One piece of Liquid Glass (`UIGlassEffect`), or a blur on older systems. Put content in `contentView`.
    /// `clear` picks the more transparent glass style; `tint` colours it; `interactive` adds the touch shimmer.
    static func makeEffectView(clear: Bool = false, tint: UIColor? = nil, interactive: Bool = false) -> UIVisualEffectView {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: clear ? .clear : .regular)
            if let tint = tint { effect.tintColor = tint }
            effect.isInteractive = interactive
            let view = UIVisualEffectView(effect: effect)
            view.cornerConfiguration = .capsule()
            return view
        }
        #endif
        return UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    }

    /// The shared container that lets neighbouring glass pieces sample the same background (and merge when
    /// they come closer than `spacing`). Glass pieces must be placed inside its `contentView`.
    static func makeContainer(spacing: CGFloat) -> UIVisualEffectView {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let effect = UIGlassContainerEffect()
            effect.spacing = spacing
            return UIVisualEffectView(effect: effect)
        }
        #endif
        return UIVisualEffectView(effect: nil)
    }

    /// Replaces the effect of a glass view (used for the pressed look).
    static func setTint(_ view: UIVisualEffectView, clear: Bool, tint: UIColor?, interactive: Bool = false) {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let effect = UIGlassEffect(style: clear ? .clear : .regular)
            effect.tintColor = tint
            effect.isInteractive = interactive
            view.effect = effect
        }
        #endif
    }

    /// Gives a glass view rounded-rectangle corners. Only literal radii are used with
    /// `.uniformCorners(radius:)` (the form shown in Apple's examples), so the radius is rounded to whole points.
    static func applyShape(_ view: UIView, radius: CGFloat, size: CGSize) {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let limit = min(size.width, size.height) / 2
            if limit <= 0 { return }
            if radius >= limit - 0.5 {
                view.cornerConfiguration = .capsule()
                return
            }
            switch Int(radius.rounded()) {
            case Int.min...0: view.cornerConfiguration = .uniformCorners(radius: 0)
            case 1: view.cornerConfiguration = .uniformCorners(radius: 1)
            case 2: view.cornerConfiguration = .uniformCorners(radius: 2)
            case 3: view.cornerConfiguration = .uniformCorners(radius: 3)
            case 4: view.cornerConfiguration = .uniformCorners(radius: 4)
            case 5: view.cornerConfiguration = .uniformCorners(radius: 5)
            case 6: view.cornerConfiguration = .uniformCorners(radius: 6)
            case 7: view.cornerConfiguration = .uniformCorners(radius: 7)
            case 8: view.cornerConfiguration = .uniformCorners(radius: 8)
            case 9: view.cornerConfiguration = .uniformCorners(radius: 9)
            case 10: view.cornerConfiguration = .uniformCorners(radius: 10)
            case 11: view.cornerConfiguration = .uniformCorners(radius: 11)
            case 12: view.cornerConfiguration = .uniformCorners(radius: 12)
            case 13: view.cornerConfiguration = .uniformCorners(radius: 13)
            case 14: view.cornerConfiguration = .uniformCorners(radius: 14)
            case 15: view.cornerConfiguration = .uniformCorners(radius: 15)
            case 16: view.cornerConfiguration = .uniformCorners(radius: 16)
            case 17: view.cornerConfiguration = .uniformCorners(radius: 17)
            case 18: view.cornerConfiguration = .uniformCorners(radius: 18)
            case 19: view.cornerConfiguration = .uniformCorners(radius: 19)
            case 20: view.cornerConfiguration = .uniformCorners(radius: 20)
            case 21: view.cornerConfiguration = .uniformCorners(radius: 21)
            case 22: view.cornerConfiguration = .uniformCorners(radius: 22)
            case 23: view.cornerConfiguration = .uniformCorners(radius: 23)
            case 24: view.cornerConfiguration = .uniformCorners(radius: 24)
            case 25: view.cornerConfiguration = .uniformCorners(radius: 25)
            case 26: view.cornerConfiguration = .uniformCorners(radius: 26)
            case 27: view.cornerConfiguration = .uniformCorners(radius: 27)
            case 28: view.cornerConfiguration = .uniformCorners(radius: 28)
            case 29: view.cornerConfiguration = .uniformCorners(radius: 29)
            case 30: view.cornerConfiguration = .uniformCorners(radius: 30)
            default: view.cornerConfiguration = .uniformCorners(radius: 30)
            }
        }
        #else
        _ = (view, radius, size)
        #endif
    }
}

/// A container with a `contentView`, used for the suggestion strip, the emoji search field, the tab bar
/// and pop-ups. Flat (a plain coloured rectangle) in most themes; a Liquid Glass shape in the Liquid Glass theme.
/// With `followsKeyRoundness` the corners track the user's key-roundness setting, so panels match the keys.
final class FlatPanel: UIView {
    private let effectView: UIVisualEffectView?
    private let fixedRadius: CGFloat
    private let followsKeyRoundness: Bool

    var contentView: UIView { return effectView?.contentView ?? self }

    init(background: UIColor? = nil, cornerRadius: CGFloat = 0, allowGlass: Bool = true, followsKeyRoundness: Bool = false) {
        self.fixedRadius = cornerRadius
        self.followsKeyRoundness = followsKeyRoundness
        if allowGlass && Theme.usesRealGlass {
            effectView = GlassSupport.makeEffectView(clear: false)
        } else {
            effectView = nil
        }
        super.init(frame: .zero)
        if let effectView = effectView {
            addSubview(effectView)
        } else {
            backgroundColor = background ?? UIColor.clear
            layer.cornerCurve = .continuous
            layer.cornerRadius = cornerRadius
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = followsKeyRoundness ? Theme.keyCornerRadius(for: bounds.size) : fixedRadius
        if let effectView = effectView {
            effectView.frame = bounds
            if followsKeyRoundness {
                GlassSupport.applyShape(effectView, radius: radius, size: bounds.size)
            }
        } else {
            layer.cornerRadius = radius
        }
    }
}

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

    /// A visual-effect view with Liquid Glass, or a blur on older systems. Put content in `contentView`.
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
}

/// A container with a `contentView`, used for the suggestion strip, the emoji search field and the
/// tab bar. Flat (a plain coloured rectangle) in most themes; a Liquid Glass capsule in the Liquid Glass theme.
final class FlatPanel: UIView {
    private let effectView: UIVisualEffectView?
    private let radius: CGFloat   // kept for debugging; flat panels round their own layer

    var contentView: UIView { return effectView?.contentView ?? self }

    init(background: UIColor? = nil, cornerRadius: CGFloat = 0, allowGlass: Bool = true) {
        self.radius = cornerRadius
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
            if cornerRadius > 0 {
                layer.cornerRadius = cornerRadius
                layer.cornerCurve = .continuous
            }
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView?.frame = bounds
    }
}

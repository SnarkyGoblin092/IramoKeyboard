import UIKit

/// A capsule of Liquid Glass (iOS 26 and later), or a blurred capsule on older iOS versions.
///
/// Everything that should look like glass goes inside `contentView`, never directly into this view.
final class GlassView: UIView {
    private let effectView: UIVisualEffectView

    var contentView: UIView { return effectView.contentView }

    /// True when this device uses real Liquid Glass (needs an iOS 26+ SDK at build time and iOS 26+ on the phone).
    static var usesRealGlass: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            return true
        }
        #endif
        return false
    }

    init(tint: UIColor? = nil, interactive: Bool = false) {
        effectView = UIVisualEffectView(effect: GlassView.makeEffect(tint: tint, interactive: interactive))
        super.init(frame: .zero)
        addSubview(effectView)
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            // Since iOS 26 beta 3 the glass shape comes from cornerConfiguration, not layer.cornerRadius.
            effectView.cornerConfiguration = .capsule()
        }
        #endif
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        effectView.frame = bounds
        if !GlassView.usesRealGlass {
            effectView.layer.cornerRadius = min(bounds.width, bounds.height) / 2
            effectView.layer.cornerCurve = .continuous
            effectView.clipsToBounds = true
        }
    }

    private static func makeEffect(tint: UIColor?, interactive: Bool) -> UIVisualEffect {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let glass = UIGlassEffect(style: Settings.shared.glassClear ? .clear : .regular)
            glass.tintColor = tint
            glass.isInteractive = interactive
            return glass
        }
        #endif
        return UIBlurEffect(style: .systemUltraThinMaterial)
    }
}

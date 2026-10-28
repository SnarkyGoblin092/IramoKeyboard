import UIKit

/// One drawn key. It never receives touches itself: `KeyboardView` handles all touches so that
/// multi-touch typing, long-press accents, cursor control and swiping work across key boundaries.
///
/// Looks (see `Theme`):
///  * native       - the iOS key cap (opaque, 5pt corners, 1pt shadow line)
///  * transparent / gradient - translucent fills with a thin outline, no shadow
///  * liquid glass - a real `UIGlassEffect` capsule (iOS 26), tinted a little for function keys
final class KeyView: UIView {
    private(set) var spec: KeySpec
    let label = UILabel()
    private let hintLabel = UILabel()
    private let iconView = UIImageView()

    /// Real-glass background, only in the Liquid Glass theme on iOS 26.
    private let glassView: UIVisualEffectView?
    /// The view that carries the key's fill colour (the key itself, or a tint layer inside the glass).
    private let fillView: UIView
    private let drawsBorder: Bool
    private let drawsShadow: Bool

    var isPressed = false {
        didSet {
            guard oldValue != isPressed else { return }
            refreshAppearance()
        }
    }
    var isActive = false { didSet { refreshAppearance() } }
    var isProminent = false { didSet { refreshAppearance() } }

    init(spec: KeySpec) {
        self.spec = spec
        self.drawsBorder = Theme.drawsKeyBorder
        self.drawsShadow = Theme.drawsKeyShadow
        if Theme.usesRealGlass {
            let effect = GlassSupport.makeEffectView(clear: false)
            self.glassView = effect
            self.fillView = UIView()
        } else {
            self.glassView = nil
            self.fillView = UIView()   // unused without glass (the key itself carries the fill)
        }
        super.init(frame: .zero)
        isUserInteractionEnabled = false

        let host: UIView
        if let glassView = glassView {
            addSubview(glassView)
            glassView.contentView.addSubview(fillView)
            host = glassView.contentView
        } else {
            host = self
            layer.cornerRadius = Theme.keyCornerRadius
            layer.cornerCurve = .continuous
            if drawsBorder {
                layer.borderWidth = 0.5
            }
            if drawsShadow {
                layer.shadowOpacity = 1
                layer.shadowRadius = 0
                layer.shadowOffset = CGSize(width: 0, height: 1)
            }
        }

        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6
        label.baselineAdjustment = .alignCenters
        host.addSubview(label)

        hintLabel.textAlignment = .right
        hintLabel.font = UIFont.systemFont(ofSize: 10, weight: .regular)
        hintLabel.textColor = Theme.secondaryText
        hintLabel.text = spec.hint
        host.addSubview(hintLabel)

        iconView.contentMode = .scaleAspectFit
        host.addSubview(iconView)

        configureContent()
        refreshAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    private func configureContent() {
        if let symbol = spec.symbol {
            iconView.image = UIImage(systemName: symbol,
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
            iconView.isHidden = false
            label.isHidden = true
        } else {
            label.text = spec.title
            if spec.action == .space {
                label.font = UIFont.systemFont(ofSize: 16)
            } else if spec.title.count == 1 {
                label.font = UIFont.systemFont(ofSize: 23, weight: .light)
            } else {
                label.font = UIFont.systemFont(ofSize: 16)
            }
            label.isHidden = false
            iconView.isHidden = true
        }
    }

    func setIcon(_ symbolName: String) {
        iconView.image = UIImage(systemName: symbolName,
                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
    }

    func setTitle(_ title: String) {
        spec.title = title
        label.text = title
    }

    /// Fades the glyphs (used while the space bar acts as a trackpad).
    func setContentAlpha(_ alpha: CGFloat) {
        label.alpha = alpha
        iconView.alpha = alpha
        hintLabel.alpha = alpha
    }

    private func refreshAppearance() {
        let textColor: UIColor
        if isProminent {
            textColor = Theme.onAccent
        } else if isActive {
            textColor = Theme.onActiveKey
        } else {
            textColor = Theme.text
        }
        label.textColor = textColor
        iconView.tintColor = textColor

        let fill: UIColor
        if isProminent {
            fill = isPressed ? Theme.accent.withAlphaComponent(0.7) : Theme.accent
        } else if isActive {
            fill = Theme.activeKey
        } else if isPressed {
            fill = spec.isFunction ? Theme.functionKeyPressed : Theme.letterKeyPressed
        } else {
            fill = spec.isFunction ? Theme.functionKey : Theme.letterKey
        }
        if glassView != nil {
            fillView.backgroundColor = fill
        } else {
            backgroundColor = fill
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        if let glassView = glassView {
            glassView.frame = bounds
            fillView.frame = bounds
            fillView.layer.cornerRadius = min(bounds.width, bounds.height) / 2
            fillView.layer.cornerCurve = .continuous
        } else if drawsBorder {
            layer.borderColor = Theme.keyBorder.resolvedColor(with: traitCollection).cgColor
        } else if drawsShadow {
            layer.shadowColor = Theme.keyShadow.resolvedColor(with: traitCollection).cgColor
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
        }
        label.frame = bounds.insetBy(dx: 2, dy: 0)
        hintLabel.frame = CGRect(x: bounds.width - 18, y: 3, width: 14, height: 12)
        let side: CGFloat = 26
        iconView.frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
    }
}

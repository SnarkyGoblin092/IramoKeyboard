import UIKit

/// One drawn key. It never receives touches itself: `KeyboardView` handles all touches so that
/// multi-touch typing, long-press accents, cursor control and swiping work across key boundaries.
///
/// Looks (see `Theme`):
///  * native       - the iOS key cap (opaque, 5pt corners, 1pt shadow line)
///  * transparent / gradient - translucent fills with a thin outline, no shadow
///  * liquid glass - a real `UIGlassEffect` piece (iOS 26) inside the keyboard's shared glass container,
///                   tinted a little for function keys, with a springy press
final class KeyView: UIView {
    private(set) var spec: KeySpec
    let label = UILabel()
    private let hintLabel = UILabel()
    private let iconView = UIImageView()

    /// Real-glass background, only in the Liquid Glass theme on iOS 26.
    private let glassView: UIVisualEffectView?
    private var lastGlassState = ""
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
        self.glassView = Theme.usesRealGlass ? GlassSupport.makeEffectView(clear: false) : nil
        super.init(frame: .zero)
        // Keys on the app's light backdrop keep the light glass the theme shows in light mode.
        if Theme.contrastKeys { glassView?.overrideUserInterfaceStyle = .light }
        isUserInteractionEnabled = false

        let host: UIView
        if let glassView = glassView {
            addSubview(glassView)
            host = glassView.contentView
        } else {
            host = self
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
        hintLabel.textColor = Theme.keySecondaryText
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
        if spec.action == .emoji, let smiley = EmojiTabIcons.icon(forKey: "smileys", side: 36, weight: 1.8) {
            // The emoji picker's smiley (an outline in light and dark mode), drawn at the size and line weight the
            // other key symbols reach in their 26pt frame (so it is shown unscaled).
            iconView.contentMode = .center
            iconView.image = smiley
            iconView.isHidden = false
            label.isHidden = true
        } else if let symbol = spec.symbol {
            iconView.contentMode = .scaleAspectFit
            iconView.image = UIImage(systemName: symbol,
                                     withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .regular))
            iconView.isHidden = false
            label.isHidden = true
        } else {
            label.text = spec.title
            if spec.action == .space {
                label.font = UIFont.systemFont(ofSize: CGFloat(Prefs.spaceTextSize))
            } else if spec.title.count == 1 {
                label.font = UIFont.systemFont(ofSize: 23 * CGFloat(Prefs.letterSize), weight: .light)
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

    /// The return key is always accent-coloured (like Gboard); shift lights up in the accent when on.
    private var usesAccent: Bool {
        if isProminent || isActive { return true }
        if case .enter = spec.action { return true }
        return false
    }

    private func refreshAppearance() {
        let textColor: UIColor
        if usesAccent {
            textColor = Theme.onAccent
        } else {
            textColor = Theme.keyText
        }
        label.textColor = textColor
        iconView.tintColor = textColor

        let fill: UIColor
        if usesAccent {
            fill = isPressed ? Theme.accent.withAlphaComponent(0.7) : Theme.accent
        } else if isPressed {
            fill = spec.isFunction ? Theme.functionKeyPressed : Theme.letterKeyPressed
        } else {
            fill = spec.isFunction ? Theme.functionKey : Theme.letterKey
        }
        if let glassView = glassView {
            applyGlass(glassView, fill: fill)
        } else {
            backgroundColor = fill
        }
    }

    /// Tints the glass for the key's state (plain letter keys stay untinted) and gives it the springy press.
    private func applyGlass(_ glassView: UIVisualEffectView, fill: UIColor) {
        let tint: UIColor?
        if usesAccent {
            tint = Theme.accent.withAlphaComponent(isPressed ? 0.55 : 0.85)
        } else if isPressed {
            tint = Theme.letterKeyPressed
        } else if spec.isFunction {
            tint = Theme.functionKey
        } else if Theme.contrastKeys {
            tint = Theme.letterKey   // on a backdrop of the other style, clear glass would vanish
        } else {
            tint = nil
        }
        let state = "\(usesAccent)|\(isPressed)|\(spec.isFunction)"
        if state != lastGlassState {
            lastGlassState = state
            GlassSupport.setTint(glassView, clear: false, tint: tint)
        }
        let scale: CGFloat = 1.0   // keys never change size while typing
        UIView.animate(withDuration: 0.22, delay: 0,
                       usingSpringWithDamping: 0.62, initialSpringVelocity: 0.8,
                       options: [.allowUserInteraction, .beginFromCurrentState]) {
            glassView.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let radius = Theme.keyCornerRadius(for: bounds.size)
        if let glassView = glassView {
            let wasScaled = glassView.transform != .identity
            if !wasScaled { glassView.frame = bounds }
            GlassSupport.applyShape(glassView, radius: radius, size: bounds.size)
        } else {
            layer.cornerRadius = radius
            if drawsBorder {
                layer.borderColor = Theme.keyBorder.resolvedColor(with: traitCollection).cgColor
            } else if drawsShadow {
                layer.shadowColor = Theme.keyShadow.resolvedColor(with: traitCollection).cgColor
                layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
            }
        }
        label.frame = bounds.insetBy(dx: 2, dy: 0)
        layoutHint(radius: radius)
        let side: CGFloat = 26
        iconView.frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
    }

    /// The accent hint, in the corner (or edge) the user picked. It sits inside the rounded corner: pulled in from
    /// the edge by an amount that grows with the corner radius (and a bit closer to the main character), so
    /// round keys never clip it.
    private func layoutHint(radius: CGFloat) {
        let scale = CGFloat(Prefs.hintSize)
        hintLabel.font = UIFont.systemFont(ofSize: (radius > 12 ? 9 : 10) * scale, weight: .regular)
        let width = 14 * scale
        let height = 11 * scale
        let inset = 3 + radius * 0.4
        let position = Prefs.hintPosition
        let x: CGFloat
        if position.hasSuffix("Left") {
            x = max(inset, bounds.midX - 16 * scale)
            hintLabel.textAlignment = .left
        } else if position.hasSuffix("Center") {
            x = bounds.midX - width / 2
            hintLabel.textAlignment = .center
        } else {
            x = min(bounds.width - inset, bounds.midX + 16 * scale) - width
            hintLabel.textAlignment = .right
        }
        let edge = 2 + radius * 0.12
        let y = position.hasPrefix("bottom") ? bounds.height - height - edge : edge
        hintLabel.frame = CGRect(x: x, y: y, width: width, height: height)
    }
}

import UIKit

/// One drawn key. It never receives touches itself: `KeyboardView` handles all touches so that
/// multi-touch typing, long-press accents, cursor control and swiping work across key boundaries.
///
/// Looks (see `Theme`):
///  * native       - the iOS key cap (opaque, 5pt corners, 1pt shadow line)
///  * transparent / gradient - translucent fills with a thin outline, no shadow
///  * liquid glass - a real `UIGlassEffect` piece (iOS 26) inside the keyboard's shared glass container,
///                   tinted a little for function keys, with a springy press
///  * designed     - the theme's own fill (frosted over a blur if it says so), sheen and depth, outline,
///                   shadow or glow, and glowing labels (ThemeStyle)
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
    /// The Keys screen's Surface and Glow (Theme.keySurface, Theme.keyGlow).
    private let surface: Theme.KeySurface
    private let glow: (radius: CGFloat, opacity: Float)
    /// Light at the top fading to a little shade at the bottom, over the fill (sheen and raised keys).
    private let sheen = CAGradientLayer()
    /// A designed theme's frosted keys: the blur under the fill (the fill is then its content's background).
    private let frostView: UIVisualEffectView?
    /// A designed theme's shadow, at rest and pressed (nil: none).
    private let designedShadow: (color: UIColor, opacity: Float, radius: CGFloat, offset: CGSize)?
    private let designedPressedShadow: (color: UIColor, opacity: Float, radius: CGFloat, offset: CGSize)?
    /// A designed theme's glow around the labels.
    private let labelGlow: (radius: CGFloat, opacity: Float)?

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
        self.surface = Theme.keySurface
        self.glow = Theme.keyGlow
        self.glassView = Theme.usesRealGlass ? GlassSupport.makeEffectView(clear: false) : nil
        self.frostView = Theme.frostedKeys ? UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial)) : nil
        self.designedShadow = Theme.designedShadow(pressed: false)
        self.designedPressedShadow = Theme.designedShadow(pressed: true)
        self.labelGlow = Theme.labelGlow
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
                layer.borderWidth = Theme.keyBorderWidth
            }
            if let frostView = frostView {
                frostView.isUserInteractionEnabled = false
                frostView.clipsToBounds = true
                frostView.layer.cornerCurve = .continuous
                addSubview(frostView)   // under the sheen, the label and the icon, added after it
            }
            if surface != .flat {
                sheen.locations = [0, 0.55, 1]
                sheen.cornerCurve = .continuous
                layer.addSublayer(sheen)   // under the label and icon, added after it
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

        if let glow = labelGlow {
            // Neon labels: a halo in the label's own colour (set with it in refreshAppearance).
            for glowing in [label, iconView] as [UIView] {
                glowing.layer.shadowRadius = glow.radius
                glowing.layer.shadowOpacity = glow.opacity
                glowing.layer.shadowOffset = .zero
            }
        }

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
                label.font = Theme.keyFont(ofSize: CGFloat(Prefs.spaceTextSize))
            } else if spec.title.count == 1 {
                label.font = Theme.keyFont(ofSize: 23 * CGFloat(Prefs.letterSize), weight: .light)
            } else {
                label.font = Theme.keyFont(ofSize: 16)
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
        if labelGlow != nil {
            let glowColor = textColor.resolvedColor(with: traitCollection).cgColor
            label.layer.shadowColor = glowColor
            iconView.layer.shadowColor = glowColor
        }

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
        } else if let frostView = frostView {
            backgroundColor = UIColor.clear
            frostView.contentView.backgroundColor = fill
            applyShadow()
        } else {
            backgroundColor = fill
            applyShadow()
        }
    }

    /// The shadow under or around the key: a designed theme's own (soft, lift, block or glow, pulled in while
    /// pressed, as if pushed in), the accent glow, the raised key's drop shadow (flattened while pressed), or the
    /// native key's 1pt line.
    private func applyShadow() {
        if let shadow = isPressed ? designedPressedShadow : designedShadow {
            layer.shadowColor = shadow.color.resolvedColor(with: traitCollection).cgColor
            layer.shadowOpacity = shadow.opacity
            layer.shadowRadius = shadow.radius
            layer.shadowOffset = shadow.offset
        } else if glow.radius > 0 {
            layer.shadowColor = Theme.accent.resolvedColor(with: traitCollection).cgColor
            layer.shadowOpacity = isPressed ? glow.opacity * 0.6 : glow.opacity
            layer.shadowRadius = glow.radius
            layer.shadowOffset = .zero
        } else if surface == .raised {
            let dark = traitCollection.userInterfaceStyle == .dark
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = isPressed ? 0.08 : (dark ? 0.45 : 0.25)
            layer.shadowRadius = isPressed ? 0.5 : 1.5
            layer.shadowOffset = CGSize(width: 0, height: isPressed ? 0.5 : 1.5)
        } else if drawsShadow {
            layer.shadowColor = Theme.keyShadow.resolvedColor(with: traitCollection).cgColor
            layer.shadowOpacity = 1
            layer.shadowRadius = 0
            layer.shadowOffset = CGSize(width: 0, height: 1)
        } else {
            layer.shadowOpacity = 0
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        refreshAppearance()   // the shadow and sheen colours follow light and dark
        setNeedsLayout()
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
                layer.borderColor = Theme.keyBorderColor.resolvedColor(with: traitCollection).cgColor
            }
            layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
            applyShadow()
            if let frostView = frostView {
                frostView.frame = bounds
                frostView.layer.cornerRadius = radius
            }
            if surface != .flat {
                let dark = traitCollection.userInterfaceStyle == .dark
                sheen.frame = bounds
                sheen.cornerRadius = radius
                sheen.colors = Theme.sheenColors(dark: dark)
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

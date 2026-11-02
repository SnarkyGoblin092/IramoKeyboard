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
            playPressEffects(pressed: isPressed)
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
        let target = shadowTarget
        if let shadow = isPressed ? designedPressedShadow : designedShadow {
            target.shadowColor = shadow.color.resolvedColor(with: traitCollection).cgColor
            target.shadowOpacity = shadow.opacity
            target.shadowRadius = shadow.radius
            target.shadowOffset = shadow.offset
        } else if glow.radius > 0 {
            target.shadowColor = Theme.accent.resolvedColor(with: traitCollection).cgColor
            target.shadowOpacity = isPressed ? glow.opacity * 0.6 : glow.opacity
            target.shadowRadius = glow.radius
            target.shadowOffset = .zero
        } else if surface == .raised {
            let dark = traitCollection.userInterfaceStyle == .dark
            target.shadowColor = UIColor.black.cgColor
            target.shadowOpacity = isPressed ? 0.08 : (dark ? 0.45 : 0.25)
            target.shadowRadius = isPressed ? 0.5 : 1.5
            target.shadowOffset = CGSize(width: 0, height: isPressed ? 0.5 : 1.5)
        } else if drawsShadow {
            target.shadowColor = Theme.keyShadow.resolvedColor(with: traitCollection).cgColor
            target.shadowOpacity = 1
            target.shadowRadius = 0
            target.shadowOffset = CGSize(width: 0, height: 1)
        } else {
            target.shadowOpacity = 0
        }
    }

    // MARK: One layer for every key's light

    /// The key's shadows and glows are drawn by this layer, which lives in a layer under all the keys
    /// (KeyboardView.haloLayer) and not in the key itself: a key's light then never lands on top of another key,
    /// whichever side of it that key is on.
    private let halo = CALayer()
    private var haloAttached = false

    private var shadowTarget: CALayer { return haloAttached ? halo : layer }

    func attachHalo(to host: CALayer) {
        haloAttached = true
        layer.shadowOpacity = 0
        host.addSublayer(halo)
        if let glow = pressGlow {
            glow.removeFromSuperlayer()
            halo.addSublayer(glow)
        }
        refreshAppearance()
        syncHalo()
    }

    func detachHalo() {
        halo.removeFromSuperlayer()
        haloAttached = false
    }

    /// Puts the halo where the key is (the key's frame and the host layer share the keyboard's coordinates).
    func syncHalo() {
        guard haloAttached else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        halo.frame = frame
        halo.shadowPath = keyShapePath()
        pressGlow?.frame = halo.bounds
        pressGlow?.shadowPath = halo.shadowPath
        CATransaction.commit()
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
            shadowTarget.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
            applyShadow()
            syncHalo()
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
        layoutEffects(radius: radius)
        label.frame = bounds.insetBy(dx: 2, dy: 0)
        layoutHint(radius: radius)
        let side: CGFloat = 26
        iconView.frame = CGRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side)
    }

    // MARK: Press effects (the Effects screen)

    /// Where effects that leave the key (sparks, the echo) are drawn: a layer over all the keys, so a neighbouring
    /// key never hides them.
    private weak var effectsHost: CALayer?
    /// Called when the key goes down with an effect colour, so the keyboard can light the keys around it (wave).
    var onEffectPress: ((KeyView, UIColor) -> Void)?
    /// The light under the key: fades in on press, out on release, and pulses for the wave. Made on first use.
    private var pressGlow: CALayer?
    /// The next rainbow hue (shared by every key, so each press is a new colour).
    private static var rainbowHue: CGFloat = 0

    func attachEffects(overlay: CALayer) {
        effectsHost = overlay
    }

    /// The colour of one press's effects, by the Effects screen's colour choice.
    static func effectColor(traits: UITraitCollection) -> UIColor {
        let effects = Prefs.effects
        switch effects.colorMode {
        case "white":
            return .white
        case "custom":
            return effects.customColor.uiColor
        case "rainbow":
            rainbowHue = (rainbowHue + 0.11).truncatingRemainder(dividingBy: 1)
            return UIColor(hue: rainbowHue, saturation: 0.75, brightness: 1, alpha: 1)
        default:
            return Theme.accent.resolvedColor(with: traits)
        }
    }

    private func keyShapePath() -> CGPath {
        return UIBezierPath(roundedRect: bounds, cornerRadius: Theme.keyCornerRadius(for: bounds.size)).cgPath
    }

    private func layoutEffects(radius: CGFloat) {
        guard let glow = pressGlow else { return }
        glow.frame = bounds
        glow.shadowPath = keyShapePath()
        glow.shadowRadius = 9 * CGFloat(Prefs.effects.glowSpread)
    }

    private func playPressEffects(pressed: Bool) {
        let effects = Prefs.effects
        guard effects.playsOnPress else { return }
        guard pressed else {
            if effects.glow { fadeGlow(on: false, color: nil) }
            return
        }
        let color = KeyView.effectColor(traits: traitCollection)
        if effects.glow { fadeGlow(on: true, color: color) }
        if effects.border { lightBorder(color) }
        if effects.ripple { ripple(color) }
        if effects.shine { shine(color) }
        if effects.sparks { sparks(color) }
        if effects.pop { pop() }
        if effects.echo { echo() }
        if effects.wave { onEffectPress?(self, color) }
    }

    private func glowLayer() -> CALayer {
        if let existing = pressGlow { return existing }
        let glow = CALayer()
        glow.shadowOffset = .zero
        glow.shadowOpacity = 0
        glow.frame = haloAttached ? halo.bounds : bounds
        glow.shadowPath = keyShapePath()
        glow.shadowRadius = 9 * CGFloat(Prefs.effects.glowSpread)
        if haloAttached {
            halo.addSublayer(glow)   // under every key, so it never lights a neighbour
        } else if let glassView = glassView {
            layer.insertSublayer(glow, above: glassView.layer)
        } else {
            layer.insertSublayer(glow, at: 0)
        }
        pressGlow = glow
        return glow
    }

    private func fadeGlow(on: Bool, color: UIColor?) {
        let effects = Prefs.effects
        let glow = glowLayer()
        if on, let color = color { glow.shadowColor = color.cgColor }
        let target = on ? Float(effects.glowStrength) : 0
        let duration = on ? effects.glowFadeIn : effects.glowFadeOut
        let from = glow.presentation()?.shadowOpacity ?? glow.shadowOpacity
        glow.shadowOpacity = target
        glow.removeAnimation(forKey: "glow")
        guard duration > 0.001 else { return }
        let fade = CABasicAnimation(keyPath: "shadowOpacity")
        fade.fromValue = from
        fade.toValue = target
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: on ? .easeOut : .easeIn)
        glow.add(fade, forKey: "glow")
    }

    /// The key lights up as part of a wave that started at a neighbour: a pulse of its glow, `delay` seconds late.
    func waveLight(color: UIColor, strength: Float, delay: TimeInterval) {
        guard haloAttached else { return }
        let glow = glowLayer()
        glow.shadowColor = color.cgColor
        let pulse = CAKeyframeAnimation(keyPath: "shadowOpacity")
        pulse.values = [0, strength, 0]
        pulse.keyTimes = [0, 0.3, 1]
        pulse.duration = max(Prefs.effects.glowFadeOut, 0.3)
        pulse.beginTime = CACurrentMediaTime() + delay
        pulse.fillMode = .backwards
        glow.add(pulse, forKey: "wave")
    }

    /// A line round the key in the effect colour that fades away.
    private func lightBorder(_ color: UIColor) {
        let effects = Prefs.effects
        let width = CGFloat(effects.borderWidth)
        let line = CAShapeLayer()
        line.frame = bounds
        line.path = UIBezierPath(roundedRect: bounds.insetBy(dx: width / 2, dy: width / 2),
                                 cornerRadius: max(0, Theme.keyCornerRadius(for: bounds.size) - width / 2)).cgPath
        line.fillColor = nil
        line.strokeColor = color.cgColor
        line.lineWidth = width
        line.opacity = 0
        layer.addSublayer(line)
        CATransaction.begin()
        CATransaction.setCompletionBlock { line.removeFromSuperlayer() }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = effects.borderFade
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        line.add(fade, forKey: "fade")
        CATransaction.commit()
    }

    /// A holder the size of the key, clipped to its shape, for effects that stay inside the key.
    private func clippedHolder() -> CALayer {
        let mask = CAShapeLayer()
        mask.path = keyShapePath()
        let holder = CALayer()
        holder.frame = bounds
        holder.mask = mask
        layer.addSublayer(holder)
        return holder
    }

    /// A disc (or a ring) of light spreading from the middle of the key, inside its shape, while it fades away.
    private func ripple(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let effects = Prefs.effects
        let diameter = hypot(bounds.width, bounds.height)
        let holder = clippedHolder()
        let wave: CALayer
        if effects.rippleStyle == "ring" {
            let ring = CAShapeLayer()
            ring.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            ring.path = UIBezierPath(ovalIn: ring.bounds.insetBy(dx: 2, dy: 2)).cgPath
            ring.fillColor = nil
            ring.strokeColor = color.withAlphaComponent(0.8).cgColor
            ring.lineWidth = 3
            wave = ring
        } else {
            let disc = CALayer()
            disc.bounds = CGRect(x: 0, y: 0, width: diameter, height: diameter)
            disc.cornerRadius = diameter / 2
            disc.backgroundColor = color.withAlphaComponent(0.55).cgColor
            wave = disc
        }
        wave.position = CGPoint(x: bounds.midX, y: bounds.midY)
        wave.opacity = 0
        holder.addSublayer(wave)
        let duration = effects.rippleDuration
        CATransaction.begin()
        CATransaction.setCompletionBlock { holder.removeFromSuperlayer() }
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.05
        grow.toValue = CGFloat(effects.rippleReach) / 3   // the largest setting covers the whole key
        grow.duration = duration
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        wave.add(grow, forKey: "grow")
        wave.add(fade, forKey: "fade")
        CATransaction.commit()
    }

    /// A band of light sweeping across the key from left to right.
    private func shine(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let effects = Prefs.effects
        let holder = clippedHolder()
        let bandWidth = bounds.width * CGFloat(effects.shineWidth)
        let band = CAGradientLayer()
        band.bounds = CGRect(x: 0, y: 0, width: bandWidth, height: bounds.height * 1.6)
        band.position = CGPoint(x: -bandWidth, y: bounds.midY)
        band.colors = [color.withAlphaComponent(0).cgColor, color.withAlphaComponent(0.75).cgColor,
                       color.withAlphaComponent(0).cgColor]
        band.startPoint = CGPoint(x: 0, y: 0.5)
        band.endPoint = CGPoint(x: 1, y: 0.5)
        band.setAffineTransform(CGAffineTransform(rotationAngle: .pi / 10))   // a slanted band
        holder.addSublayer(band)
        CATransaction.begin()
        CATransaction.setCompletionBlock { holder.removeFromSuperlayer() }
        let sweep = CABasicAnimation(keyPath: "position.x")
        sweep.fromValue = -bandWidth
        sweep.toValue = bounds.width + bandWidth
        sweep.duration = effects.shineDuration
        sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        band.add(sweep, forKey: "sweep")
        CATransaction.commit()
        band.position = CGPoint(x: bounds.width + bandWidth, y: bounds.midY)
    }

    /// The layer and the middle of the key in it, for effects that leave the key.
    private func overlayTarget() -> (host: CALayer, center: CGPoint) {
        if let host = effectsHost { return (host, CGPoint(x: frame.midX, y: frame.midY)) }
        return (layer, CGPoint(x: bounds.midX, y: bounds.midY))
    }

    /// Specks that fly out of the key in every direction and fade.
    private func sparks(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let effects = Prefs.effects
        let target = overlayTarget()
        let count = max(1, Int(effects.sparkCount.rounded()))
        let size = CGFloat(effects.sparkSize)
        let reach = bounds.width * CGFloat(effects.sparkDistance)
        let offset = CGFloat.random(in: 0..<(2 * .pi))
        var specks: [CALayer] = []
        CATransaction.begin()
        CATransaction.setCompletionBlock { specks.forEach { $0.removeFromSuperlayer() } }
        for index in 0..<count {
            let angle = offset + 2 * .pi * CGFloat(index) / CGFloat(count)
            let distance = reach * CGFloat.random(in: 0.7...1.15)
            let speck = CALayer()
            speck.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            speck.cornerRadius = size / 2
            speck.backgroundColor = (Prefs.effects.colorMode == "rainbow"
                ? UIColor(hue: CGFloat(index) / CGFloat(count), saturation: 0.7, brightness: 1, alpha: 1) : color).cgColor
            speck.position = target.center
            speck.opacity = 0
            target.host.addSublayer(speck)
            specks.append(speck)
            let fly = CABasicAnimation(keyPath: "position")
            fly.fromValue = target.center
            fly.toValue = CGPoint(x: target.center.x + cos(angle) * distance, y: target.center.y + sin(angle) * distance)
            fly.duration = effects.sparkDuration
            fly.timingFunction = CAMediaTimingFunction(name: .easeOut)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            fade.duration = effects.sparkDuration
            fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
            let shrink = CABasicAnimation(keyPath: "transform.scale")
            shrink.fromValue = 1
            shrink.toValue = 0.3
            shrink.duration = effects.sparkDuration
            speck.add(fly, forKey: "fly")
            speck.add(fade, forKey: "fade")
            speck.add(shrink, forKey: "shrink")
        }
        CATransaction.commit()
    }

    /// The label swells (or shrinks) and springs back.
    private func pop() {
        let effects = Prefs.effects
        let scale = CGFloat(effects.popScale)
        let duration = effects.popDuration
        for view in [label, iconView] where !view.isHidden {
            UIView.animate(withDuration: duration * 0.35, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                view.transform = CGAffineTransform(scaleX: scale, y: scale)
            } completion: { _ in
                UIView.animate(withDuration: duration * 0.65, delay: 0, usingSpringWithDamping: 0.45,
                               initialSpringVelocity: 0.6, options: [.allowUserInteraction]) {
                    view.transform = .identity
                }
            }
        }
    }

    /// A copy of the label floats up out of the key and fades.
    private func echo() {
        let effects = Prefs.effects
        let source: UIView = label.isHidden ? iconView : label
        guard source.bounds.width > 0, source.bounds.height > 0 else { return }
        let image = UIGraphicsImageRenderer(bounds: source.bounds).image { source.layer.render(in: $0.cgContext) }
        let target = overlayTarget()
        let ghost = CALayer()
        ghost.bounds = source.bounds
        ghost.contents = image.cgImage
        ghost.contentsScale = UIScreen.main.scale
        ghost.position = target.center
        ghost.opacity = 0
        target.host.addSublayer(ghost)
        CATransaction.begin()
        CATransaction.setCompletionBlock { ghost.removeFromSuperlayer() }
        let rise = CABasicAnimation(keyPath: "position.y")
        rise.fromValue = target.center.y
        rise.toValue = target.center.y - CGFloat(effects.echoRise)
        rise.duration = effects.echoDuration
        rise.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0.85
        fade.toValue = 0
        fade.duration = effects.echoDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        ghost.add(rise, forKey: "rise")
        ghost.add(fade, forKey: "fade")
        CATransaction.commit()
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

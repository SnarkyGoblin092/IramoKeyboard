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
    /// The label drawn once for the echo, kept while the key shows the same thing.
    private var echoImage: CGImage?
    private var echoSignature = ""
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
        let start = EffectPosition.offset(effects.position, size: bounds.size, random: { CGFloat.random(in: 0..<1) })
        effectOffset = start
        if effects.glow { fadeGlow(on: true, color: color) }
        if effects.border { lightBorder(color) }
        if effects.ripple { ripple(color) }
        if effects.shine { shine(color) }
        if effects.pop { pop() }
        if effects.wave { onEffectPress?(self, color) }
        if effects.squish { squish() }
        if effects.flash { flash(color) }
        if effects.jelly { jelly() }
        if effects.heartbeat { heartbeat() }
        if effects.flip { flip() }
        if effects.shake { shake() }
        if effects.drop { drop() }
        if effects.glitch { glitch() }
        if effects.underline { underline(color) }
        if effects.sweep { neonSweep(color) }
        // The effects that make many layers are built a moment later, after the press itself has been handled, and are
        // left out while too many are still on screen: typing fast stays smooth.
        guard KeyView.liveLayers < KeyView.layerBudget else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.window != nil else { return }
            self.effectOffset = start
            let effects = Prefs.effects
            if effects.sparks { self.sparks(color) }
            if effects.echo { self.echo() }
            if effects.shockwave { self.shockwave(color) }
            if effects.confetti { self.confetti(color) }
            if effects.bubbles { self.bubbles(color) }
            if effects.lightning { self.lightning(color) }
            if effects.beam { self.beam(color) }
            self.playParticles(color)
        }
    }

    /// How many layers of the bursts (specks, pieces, bubbles) are on screen, and how many are allowed: past that,
    /// new bursts are thinned out or skipped until the older ones have faded.
    private static var liveLayers = 0
    private static let layerBudget = 140

    /// How many of `wanted` layers a burst may use now; they count as live until `release` is called with the same number.
    private static func reserve(_ wanted: Int) -> Int {
        let allowed = max(0, min(wanted, layerBudget + 20 - liveLayers))
        liveLayers += allowed
        return allowed
    }

    private static func release(_ count: Int) {
        liveLayers = max(0, liveLayers - count)
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
        glow.add(pulse, forKey: "wave" + String(CACurrentMediaTime()))
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
        let holder = CALayer()
        holder.frame = bounds
        holder.cornerRadius = Theme.keyCornerRadius(for: bounds.size)
        holder.cornerCurve = .continuous
        holder.masksToBounds = true
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
        wave.position = CGPoint(x: bounds.midX + effectOffset.x, y: bounds.midY + effectOffset.y)
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
        if let host = effectsHost { return (host, CGPoint(x: frame.midX + effectOffset.x, y: frame.midY + effectOffset.y)) }
        return (layer, CGPoint(x: bounds.midX + effectOffset.x, y: bounds.midY + effectOffset.y))
    }

    /// Where the current press's effects start, from the middle of the key (the position setting).
    private var effectOffset = CGPoint.zero

    /// Specks that fly out of the key in every direction and fade.
    private func sparks(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let effects = Prefs.effects
        let target = overlayTarget()
        let count = KeyView.reserve(max(1, Int(effects.sparkCount.rounded())))
        guard count > 0 else { return }
        let size = CGFloat(effects.sparkSize)
        let reach = bounds.width * CGFloat(effects.sparkDistance)
        let offset = CGFloat.random(in: 0..<(2 * .pi))
        var specks: [CALayer] = []
        CATransaction.begin()
        CATransaction.setCompletionBlock { specks.forEach { $0.removeFromSuperlayer() }; KeyView.release(count) }
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

    /// The label swells (or shrinks) and springs back. Taps in quick succession add up instead of cutting each other off.
    private func pop() {
        let effects = Prefs.effects
        let swell = CGFloat(effects.popScale) - 1
        for view in [label, iconView] where !view.isHidden {
            let spring = CAKeyframeAnimation(keyPath: "transform.scale")
            spring.values = [0, swell, -swell * 0.25, swell * 0.08, 0]
            spring.keyTimes = [0, 0.35, 0.6, 0.82, 1]
            spring.duration = effects.popDuration
            spring.isAdditive = true
            view.layer.add(spring, forKey: "pop" + String(CACurrentMediaTime()))
        }
    }

    /// A copy of the label floats up out of the key and fades.
    private func echo() {
        let effects = Prefs.effects
        let source: UIView = label.isHidden ? iconView : label
        guard source.bounds.width > 0, source.bounds.height > 0 else { return }
        let signature = "\(label.text ?? "")|\(source.bounds.size)|\(label.isHidden)"
        if echoSignature != signature || echoImage == nil {
            echoImage = UIGraphicsImageRenderer(bounds: source.bounds).image { source.layer.render(in: $0.cgContext) }.cgImage
            echoSignature = signature
        }
        guard let image = echoImage else { return }
        let target = overlayTarget()
        let ghost = CALayer()
        ghost.bounds = source.bounds
        ghost.contents = image
        ghost.contentsScale = UIScreen.main.scale
        ghost.position = target.center
        ghost.opacity = 0
        target.host.addSublayer(ghost)
        CATransaction.begin()
        CATransaction.setCompletionBlock { ghost.removeFromSuperlayer() }
        let away = EffectDirection.turn(CGPoint(x: 0, y: -CGFloat(effects.echoRise)), by: effectTurn())
        let rise = CABasicAnimation(keyPath: "position")
        rise.fromValue = NSValue(cgPoint: target.center)
        rise.toValue = NSValue(cgPoint: CGPoint(x: target.center.x + away.x, y: target.center.y + away.y))
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

    /// A ring of light that spreads out far past the key, over the keys around it.
    private func shockwave(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let effects = Prefs.effects
        let target = overlayTarget()
        let radius = bounds.width * CGFloat(effects.shockReach)
        let ring = CAShapeLayer()
        ring.bounds = CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2)
        ring.path = UIBezierPath(ovalIn: ring.bounds.insetBy(dx: 1.5, dy: 1.5)).cgPath
        ring.fillColor = nil
        ring.strokeColor = color.withAlphaComponent(0.85).cgColor
        ring.lineWidth = 2.5
        ring.position = target.center
        ring.opacity = 0
        target.host.addSublayer(ring)
        CATransaction.begin()
        CATransaction.setCompletionBlock { ring.removeFromSuperlayer() }
        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.1
        grow.toValue = 1
        grow.duration = effects.shockDuration
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = effects.shockDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        ring.add(grow, forKey: "grow")
        ring.add(fade, forKey: "fade")
        CATransaction.commit()
    }

    /// The angle, clockwise from straight up, the throwing effects go at for one press (0 when they go up as designed).
    private func effectTurn() -> CGFloat {
        return EffectDirection.target(Prefs.effects.direction, random: { CGFloat.random(in: 0..<1) }) ?? 0
    }

    /// Small pieces of paper thrown up out of the key that tumble down, fading.
    private func confetti(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let effects = Prefs.effects
        let target = overlayTarget()
        let count = KeyView.reserve(max(1, Int(effects.confettiCount.rounded())))
        guard count > 0 else { return }
        let duration = effects.confettiDuration
        let width = bounds.width
        let turn = effectTurn()
        var pieces: [CALayer] = []
        CATransaction.begin()
        CATransaction.setCompletionBlock { pieces.forEach { $0.removeFromSuperlayer() }; KeyView.release(count) }
        for _ in 0..<count {
            let piece = CALayer()
            piece.bounds = CGRect(x: 0, y: 0, width: CGFloat.random(in: 4...7), height: CGFloat.random(in: 2...4))
            piece.backgroundColor = (effects.colorMode == "rainbow"
                ? UIColor(hue: CGFloat.random(in: 0..<1), saturation: 0.7, brightness: 1, alpha: 1)
                : color.withAlphaComponent(CGFloat.random(in: 0.6...1))).cgColor
            piece.position = target.center
            piece.opacity = 0
            target.host.addSublayer(piece)
            pieces.append(piece)
            // A throw up and sideways, then gravity: y = vy * t + g * t * t / 2 over the whole flight.
            let dx = CGFloat.random(in: -1...1) * width * 0.9
            let dy = -CGFloat.random(in: 0.8...1.8) * width
            let gravity = width * 3.2
            var points: [NSValue] = []
            for step in 0...10 {
                let t = CGFloat(step) / 10
                let offset = EffectDirection.turn(CGPoint(x: dx * t, y: dy * t + gravity * t * t / 2), by: turn)
                points.append(NSValue(cgPoint: CGPoint(x: target.center.x + offset.x, y: target.center.y + offset.y)))
            }
            let fly = CAKeyframeAnimation(keyPath: "position")
            fly.values = points
            fly.duration = duration
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = CGFloat.random(in: -8...8)
            spin.duration = duration
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [1, 1, 0]
            fade.keyTimes = [0, 0.6, 1]
            fade.duration = duration
            piece.add(fly, forKey: "fly")
            piece.add(spin, forKey: "spin")
            piece.add(fade, forKey: "fade")
        }
        CATransaction.commit()
    }

    /// Bubbles that float up from the key, swaying a little, one after the other.
    private func bubbles(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let effects = Prefs.effects
        let target = overlayTarget()
        let count = KeyView.reserve(max(1, Int(effects.bubbleCount.rounded())))
        guard count > 0 else { return }
        let rise = CGFloat(effects.bubbleRise)
        let turn = effectTurn()
        var drops: [CALayer] = []
        CATransaction.begin()
        CATransaction.setCompletionBlock { drops.forEach { $0.removeFromSuperlayer() }; KeyView.release(count) }
        for _ in 0..<count {
            let size = CGFloat.random(in: 5...11)
            let bubble = CAShapeLayer()
            bubble.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            bubble.path = UIBezierPath(ovalIn: bubble.bounds.insetBy(dx: 0.75, dy: 0.75)).cgPath
            bubble.fillColor = color.withAlphaComponent(0.18).cgColor
            bubble.strokeColor = color.withAlphaComponent(0.9).cgColor
            bubble.lineWidth = 1.5
            bubble.opacity = 0
            let startX = target.center.x + CGFloat.random(in: -0.35...0.35) * bounds.width
            let lift = EffectDirection.turn(CGPoint(x: startX - target.center.x, y: 0), by: turn)
            bubble.position = CGPoint(x: target.center.x + lift.x, y: target.center.y + lift.y)
            target.host.addSublayer(bubble)
            drops.append(bubble)
            let delay = Double.random(in: 0...0.25)
            let duration = Double.random(in: 0.7...1.1)
            let sway = CGFloat.random(in: 4...9)
            var points: [NSValue] = []
            for step in 0...10 {
                let t = CGFloat(step) / 10
                let offset = EffectDirection.turn(CGPoint(x: startX - target.center.x + sin(t * 2 * .pi * 1.5) * sway, y: -rise * t), by: turn)
                points.append(NSValue(cgPoint: CGPoint(x: target.center.x + offset.x, y: target.center.y + offset.y)))
            }
            let float = CAKeyframeAnimation(keyPath: "position")
            float.values = points
            float.duration = duration
            float.beginTime = CACurrentMediaTime() + delay
            float.fillMode = .backwards
            float.timingFunction = CAMediaTimingFunction(name: .easeOut)
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, 1, 1, 0]
            fade.keyTimes = [0, 0.15, 0.6, 1]
            fade.duration = duration
            fade.beginTime = CACurrentMediaTime() + delay
            fade.fillMode = .backwards
            bubble.add(float, forKey: "float")
            bubble.add(fade, forKey: "fade")
        }
        CATransaction.commit()
    }

    /// The key squashes under the finger and springs back.
    private func squish() {
        let depth = Prefs.effects.squishDepth
        let squash = CAKeyframeAnimation(keyPath: "transform.scale")
        squash.values = [0, depth - 1, 0.05, -0.01, 0]
        squash.keyTimes = [0, 0.25, 0.55, 0.8, 1]
        squash.duration = 0.4
        addOverlapping(squash, "squish")
    }

    /// The key flashes in the effect colour, inside its shape.
    private func flash(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let effects = Prefs.effects
        let holder = clippedHolder()
        let fill = CALayer()
        fill.frame = bounds
        fill.backgroundColor = color.withAlphaComponent(CGFloat(effects.flashStrength)).cgColor
        fill.opacity = 0
        holder.addSublayer(fill)
        CATransaction.begin()
        CATransaction.setCompletionBlock { holder.removeFromSuperlayer() }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = effects.flashDuration
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        fill.add(fade, forKey: "fade")
        CATransaction.commit()
    }

    /// The key wobbles like jelly, the swings getting smaller.
    private func jelly() {
        let angle = CGFloat(Prefs.effects.jellyAngle) * .pi / 180
        let wobble = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        wobble.values = [0, angle, -angle * 0.8, angle * 0.5, -angle * 0.25, 0]
        wobble.keyTimes = [0, 0.18, 0.4, 0.62, 0.82, 1]
        wobble.duration = 0.5
        addOverlapping(wobble, "jelly")
    }

    // MARK: More press effects

    /// Plays an animation on the key without stopping one that is still playing: taps in quick succession add up
    /// (the animation moves the key relative to where it is, and each one has a key of its own).
    private func addOverlapping(_ animation: CAAnimation, _ name: String) {
        if let property = animation as? CAPropertyAnimation { property.isAdditive = true }
        layer.add(animation, forKey: name + String(CACurrentMediaTime()))
    }

    /// The layer of one speck (see EffectParticles): its shape in the press's colour, with its middle at the layer's position.
    private func particleLayer(_ spec: EffectParticle, color: UIColor) -> CALayer {
        let size = spec.size
        switch spec.shape {
        case .art(let art):
            let picture = CAShapeLayer()
            picture.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            picture.path = art.path(side: size)
            picture.fillColor = color.cgColor
            picture.fillRule = art.cutsHoles ? .evenOdd : .nonZero
            return picture
        case .dot:
            let dot = CALayer()
            dot.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            dot.cornerRadius = size / 2
            dot.backgroundColor = color.cgColor
            return dot
        case .streak(let angle):
            let line = CAShapeLayer()
            line.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            let path = UIBezierPath()
            let reach = size / 2
            path.move(to: CGPoint(x: size / 2 - cos(angle) * reach, y: size / 2 - sin(angle) * reach))
            path.addLine(to: CGPoint(x: size / 2 + cos(angle) * reach, y: size / 2 + sin(angle) * reach))
            line.path = path.cgPath
            line.strokeColor = color.cgColor
            line.lineWidth = 2
            line.lineCap = .round
            return line
        case .drop:
            let drop = CAGradientLayer()
            drop.bounds = CGRect(x: 0, y: 0, width: 2, height: size)
            drop.cornerRadius = 1
            drop.colors = [color.withAlphaComponent(0).cgColor, color.cgColor]
            drop.startPoint = CGPoint(x: 0.5, y: 0)
            drop.endPoint = CGPoint(x: 0.5, y: 1)
            return drop
        case .soft:
            let puff = CALayer()
            puff.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            puff.cornerRadius = size / 2
            puff.backgroundColor = color.withAlphaComponent(0.35).cgColor
            puff.shadowColor = color.cgColor
            puff.shadowRadius = 4
            puff.shadowOpacity = 0.8
            puff.shadowOffset = .zero
            puff.shadowPath = CGPath(ellipseIn: puff.bounds, transform: nil)
            return puff
        case .ring:
            let ring = CAShapeLayer()
            ring.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            ring.path = UIBezierPath(ovalIn: ring.bounds.insetBy(dx: 1, dy: 1)).cgPath
            ring.fillColor = nil
            ring.strokeColor = color.cgColor
            ring.lineWidth = 2
            return ring
        case .square:
            let square = CALayer()
            square.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            square.backgroundColor = color.cgColor
            return square
        case .bar:
            let bar = CALayer()
            bar.bounds = CGRect(x: 0, y: 0, width: size, height: size * 0.4)
            bar.cornerRadius = 1
            bar.backgroundColor = color.cgColor
            return bar
        case .ember:
            let ember = CALayer()
            ember.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            ember.cornerRadius = size / 2
            ember.backgroundColor = color.cgColor
            ember.shadowColor = color.cgColor
            ember.shadowRadius = 3
            ember.shadowOpacity = 1
            ember.shadowOffset = .zero
            ember.shadowPath = CGPath(ellipseIn: ember.bounds, transform: nil)
            return ember
        }
    }

    /// Hearts, stars, snow, notes, fireworks, rays, rain, embers, smoke, orbit and spiral: all the particle effects
    /// that are on, flying out of the key over the keys around it.
    private func playParticles(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        var specs = EffectParticles.make(Prefs.effects, keySize: bounds.size) { _, _ in CGFloat.random(in: 0..<1) }
        guard !specs.isEmpty else { return }
        let allowed = KeyView.reserve(specs.count)
        guard allowed > 0 else { return }
        if allowed < specs.count { specs = Array(specs.prefix(allowed)) }
        let target = overlayTarget()
        var specks: [CALayer] = []
        CATransaction.begin()
        CATransaction.setCompletionBlock { specks.forEach { $0.removeFromSuperlayer() }; KeyView.release(allowed) }
        for spec in specs {
            let tint = spec.hue.map { UIColor(hue: $0, saturation: 0.7, brightness: 1, alpha: 1) } ?? color
            let speck = particleLayer(spec, color: tint)
            speck.position = target.center
            speck.opacity = 0
            target.host.addSublayer(speck)
            specks.append(speck)
            let begin = CACurrentMediaTime() + spec.delay

            let move = CAKeyframeAnimation(keyPath: "position")
            move.values = (0...20).map { step -> NSValue in
                let offset = spec.path(CGFloat(step) / 20)
                return NSValue(cgPoint: CGPoint(x: target.center.x + offset.x, y: target.center.y + offset.y))
            }
            let fade = CAKeyframeAnimation(keyPath: "opacity")
            fade.values = [0, Float(spec.peak), Float(spec.peak), 0]
            fade.keyTimes = [0, 0.12, 0.6, 1]
            var animations: [CAAnimation] = [move, fade]
            if spec.scaleFrom != spec.scaleTo {
                let scale = CABasicAnimation(keyPath: "transform.scale")
                scale.fromValue = spec.scaleFrom
                scale.toValue = spec.scaleTo
                animations.append(scale)
            }
            if spec.spin != 0 || spec.tilt != 0 {
                let tilt = spec.isOriented ? spec.tilt : 0
                speck.transform = CATransform3DMakeRotation(tilt, 0, 0, 1)
                if spec.spin != 0 {
                    let turn = CABasicAnimation(keyPath: "transform.rotation.z")
                    turn.fromValue = tilt
                    turn.toValue = tilt + spec.spin
                    animations.append(turn)
                }
            }
            for animation in animations {
                animation.duration = spec.duration
                animation.beginTime = begin
                animation.fillMode = .backwards
                speck.add(animation, forKey: String(animation.hash))
            }
        }
        CATransaction.commit()
    }

    /// A forked bolt of lightning strikes down onto the key: a wide glow, the colour and a white core, flickering, while
    /// the key itself flashes.
    private func lightning(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let target = overlayTarget()
        let length = bounds.width * CGFloat(Prefs.effects.lightningLength)
        let bolt = EffectBolt.make(length: length, width: bounds.width) { _, _ in CGFloat.random(in: 0..<1) }

        func line(_ points: [CGPoint]) -> UIBezierPath {
            let path = UIBezierPath()
            guard let first = points.first else { return path }
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
            return path
        }
        let main = line(bolt.main)
        let forks = UIBezierPath()
        for fork in bolt.forks { forks.append(line(fork)) }

        // Wide glow, colour, white core: each stroke of the main bolt, then the thinner ones of the forks.
        let strokes: [(path: UIBezierPath, color: UIColor, width: CGFloat, glow: Bool)] = [
            (main, color.withAlphaComponent(0.3), 14, true), (main, color.withAlphaComponent(0.5), 8, true), (main, color, 3.5, false), (main, .white, 1.5, false),
            (forks, color.withAlphaComponent(0.3), 8, true), (forks, color.withAlphaComponent(0.5), 4, true), (forks, color, 1.8, false), (forks, .white, 0.8, false),
        ]
        var layers: [CAShapeLayer] = []
        for stroke in strokes {
            let layer = CAShapeLayer()
            layer.path = stroke.path.cgPath
            layer.position = target.center
            layer.fillColor = nil
            layer.strokeColor = stroke.color.cgColor
            layer.lineWidth = stroke.width
            layer.lineJoin = .round
            layer.lineCap = .round
            layer.opacity = 0
            target.host.addSublayer(layer)
            layers.append(layer)
        }
        let holder = clippedHolder()
        let flash = CALayer()
        flash.frame = bounds
        flash.backgroundColor = UIColor.white.withAlphaComponent(0.55).cgColor
        flash.opacity = 0
        holder.addSublayer(flash)

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            layers.forEach { $0.removeFromSuperlayer() }
            holder.removeFromSuperlayer()
        }
        let flicker = CAKeyframeAnimation(keyPath: "opacity")
        flicker.values = [0, 1, 0.3, 1, 0.5, 0]
        flicker.keyTimes = [0, 0.05, 0.2, 0.35, 0.6, 1]
        flicker.duration = 0.45
        layers.forEach { $0.add(flicker, forKey: "flicker") }
        let blink = CABasicAnimation(keyPath: "opacity")
        blink.fromValue = 1
        blink.toValue = 0
        blink.duration = 0.3
        blink.timingFunction = CAMediaTimingFunction(name: .easeIn)
        flash.add(blink, forKey: "blink")
        CATransaction.commit()
    }

    /// The key pulses twice, like a heartbeat.
    private func heartbeat() {
        let strength = Prefs.effects.heartbeatStrength
        let beat = CAKeyframeAnimation(keyPath: "transform.scale")
        beat.values = [0, strength - 1, 0, strength - 1, 0]
        beat.keyTimes = [0, 0.2, 0.4, 0.62, 1]
        beat.duration = 0.55
        addOverlapping(beat, "heartbeat")
    }

    /// The key turns over like a card.
    private func flip() {
        let turn = CAKeyframeAnimation(keyPath: "transform")
        var values: [NSValue] = []
        for step in 0...12 {
            var matrix = CATransform3DIdentity
            matrix.m34 = -1 / 500
            matrix = CATransform3DRotate(matrix, CGFloat(step) / 12 * 2 * .pi, 1, 0, 0)
            values.append(NSValue(caTransform3D: matrix))
        }
        turn.values = values
        turn.duration = Prefs.effects.flipDuration
        turn.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        addOverlapping(turn, "flip")
    }

    /// The key shakes from side to side.
    private func shake() {
        let distance = CGFloat(Prefs.effects.shakeDistance)
        let sway = CAKeyframeAnimation(keyPath: "transform.translation.x")
        sway.values = [0, -distance, distance, -distance * 0.7, distance * 0.5, -distance * 0.2, 0]
        sway.duration = 0.3
        addOverlapping(sway, "shake")
    }

    /// The key sinks and bounces back.
    private func drop() {
        let depth = CGFloat(Prefs.effects.dropDepth)
        let sink = CAKeyframeAnimation(keyPath: "transform.translation.y")
        sink.values = [0, depth, -depth * 0.35, depth * 0.12, 0]
        sink.keyTimes = [0, 0.3, 0.6, 0.8, 1]
        sink.duration = 0.4
        addOverlapping(sink, "drop")
    }

    /// The key jumps sideways while pink and cyan copies flicker over it.
    private func glitch() {
        guard bounds.width > 0 else { return }
        let strength = CGFloat(Prefs.effects.glitchStrength)
        let jump = CAKeyframeAnimation(keyPath: "transform.translation.x")
        jump.values = [0, -strength * 6, strength * 5, -strength * 3, strength * 4, 0]
        jump.duration = 0.24
        addOverlapping(jump, "glitch")
        let holder = clippedHolder()
        CATransaction.begin()
        CATransaction.setCompletionBlock { holder.removeFromSuperlayer() }
        let slabs: [(color: UIColor, shift: CGFloat)] = [(.systemPink, -3), (.cyan, 3)]
        for slab in slabs {
            let copy = CALayer()
            copy.frame = bounds.offsetBy(dx: slab.shift, dy: 0)
            copy.backgroundColor = slab.color.withAlphaComponent(0.4 * strength).cgColor
            copy.opacity = 0
            holder.addSublayer(copy)
            let flicker = CAKeyframeAnimation(keyPath: "opacity")
            flicker.values = [1, 0, 1, 0, 1, 0]
            flicker.duration = 0.26
            copy.add(flicker, forKey: "flicker")
        }
        CATransaction.commit()
    }

    /// A line grows from the middle along the bottom of the key and fades.
    private func underline(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let duration = Prefs.effects.underlineDuration
        let holder = clippedHolder()
        let bar = CALayer()
        bar.bounds = CGRect(x: 0, y: 0, width: bounds.width * 0.8, height: 3)
        bar.position = CGPoint(x: bounds.midX, y: bounds.height - 4)
        bar.backgroundColor = color.cgColor
        bar.opacity = 0
        holder.addSublayer(bar)
        CATransaction.begin()
        CATransaction.setCompletionBlock { holder.removeFromSuperlayer() }
        let grow = CABasicAnimation(keyPath: "transform.scale.x")
        grow.fromValue = 0.05
        grow.toValue = 1
        grow.duration = duration
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        bar.add(grow, forKey: "grow")
        bar.add(fade, forKey: "fade")
        CATransaction.commit()
    }

    /// A short stretch of light runs once round the key's outline.
    private func neonSweep(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let duration = Prefs.effects.sweepDuration
        let width: CGFloat = 3
        let line = CAShapeLayer()
        line.frame = bounds
        line.path = UIBezierPath(roundedRect: bounds.insetBy(dx: width / 2, dy: width / 2),
                                 cornerRadius: max(0, Theme.keyCornerRadius(for: bounds.size) - width / 2)).cgPath
        line.fillColor = nil
        line.strokeColor = color.cgColor
        line.lineWidth = width
        line.lineCap = .round
        line.opacity = 0
        layer.addSublayer(line)
        CATransaction.begin()
        CATransaction.setCompletionBlock { line.removeFromSuperlayer() }
        let head = CABasicAnimation(keyPath: "strokeEnd")
        head.fromValue = 0.15
        head.toValue = 1
        let tail = CABasicAnimation(keyPath: "strokeStart")
        tail.fromValue = 0
        tail.toValue = 0.85
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.8, 1]
        for animation in [head, tail, fade] as [CAAnimation] {
            animation.duration = duration
            line.add(animation, forKey: String(animation.hash))
        }
        CATransaction.commit()
    }

    /// A beam of light rises from the middle of the key and fades.
    private func beam(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let target = overlayTarget()
        let height = bounds.width * CGFloat(Prefs.effects.beamHeight)
        let column = CAGradientLayer()
        column.bounds = CGRect(x: 0, y: 0, width: bounds.width * 0.5, height: height)
        column.anchorPoint = CGPoint(x: 0.5, y: 1)
        // Held in a layer on the key's middle, which turns the beam to the chosen direction.
        let turner = CALayer()
        turner.position = target.center
        turner.transform = CATransform3DMakeRotation(effectTurn(), 0, 0, 1)
        column.position = .zero
        column.colors = [color.withAlphaComponent(0.8).cgColor, color.withAlphaComponent(0).cgColor]
        column.startPoint = CGPoint(x: 0.5, y: 1)
        column.endPoint = CGPoint(x: 0.5, y: 0)
        column.opacity = 0
        turner.addSublayer(column)
        target.host.addSublayer(turner)
        CATransaction.begin()
        CATransaction.setCompletionBlock { turner.removeFromSuperlayer() }
        let grow = CABasicAnimation(keyPath: "transform.scale.y")
        grow.fromValue = 0.15
        grow.toValue = 1
        grow.timingFunction = CAMediaTimingFunction(name: .easeOut)
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        for animation in [grow, fade] as [CAAnimation] {
            animation.duration = 0.5
            column.add(animation, forKey: String(animation.hash))
        }
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

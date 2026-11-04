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
    /// The Keys screen's Surface and Glow (Theme.keySurface, Theme.keyGlow).
    private let surface: Theme.KeySurface
    private let glow: (radius: CGFloat, opacity: Float)
    /// Light at the top fading to a little shade at the bottom, over the fill (sheen and raised keys).
    private let sheen = CAGradientLayer()
    /// A glow around the labels.
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
        self.labelGlow = Theme.labelGlow
        super.init(frame: .zero)
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
        hintLabel.textColor = Theme.hintText
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

    /// The key becomes `newSpec` (the page key on the next page), keeping its view and the effects playing on it.
    func reuse(as newSpec: KeySpec) {
        spec = newSpec
        hintLabel.text = newSpec.hint
        configureContent()
        refreshAppearance()
        setNeedsLayout()
    }

    /// What this key's effects are still playing, before it goes (KeyEffectPlayer.Handover).
    func effectsHandover() -> KeyEffectPlayer.Handover {
        return effects.handover()
    }

    /// Goes on with another key's effects, as if it were that key (after this key is laid out).
    func takeEffects(_ handover: KeyEffectPlayer.Handover) {
        syncEffects()
        effects.take(handover)
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

    /// Hides the key with its light and shadow (another key is drawn over it: the stretched backspace).
    func setCovered(_ covered: Bool) {
        alpha = covered ? 0 : 1
        halo.opacity = covered ? 0 : 1
    }

    /// The return key is always accent-coloured (like Gboard); shift lights up in the accent when on.
    private var usesAccent: Bool {
        if isProminent || isActive { return true }
        if case .enter = spec.action { return true }
        return false
    }

    private func refreshAppearance() {
        let textColor: UIColor
        if spec.action == .enter {
            textColor = Theme.onReturnKey
        } else if usesAccent {
            textColor = Theme.onShiftOn
        } else {
            textColor = spec.isFunction ? Theme.functionKeyText : Theme.keyText
        }
        label.textColor = textColor
        iconView.tintColor = textColor
        if labelGlow != nil {
            let glowColor = textColor.resolvedColor(with: traitCollection).cgColor
            label.layer.shadowColor = glowColor
            iconView.layer.shadowColor = glowColor
        }

        let fill: UIColor
        // A press does not change the key's colour: lighting it up is the Flash effect's job.
        if spec.action == .enter {
            fill = Theme.returnKey
        } else if usesAccent {
            fill = Theme.shiftOn
        } else if spec.action == .space {
            fill = Theme.spaceKey
        } else {
            fill = spec.isFunction ? Theme.functionKey : Theme.letterKey
        }
        if let glassView = glassView {
            applyGlass(glassView, fill: fill)
        } else {
            backgroundColor = fill
            applyShadow()
        }
    }

    /// The shadow under or around the key: the accent glow, the raised key's drop shadow (flattened while pressed),
    /// or the native key's 1pt line.
    private func applyShadow() {
        let target = shadowTarget
        if glow.radius > 0 {
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
        if let path = halo.shadowPath { effects.shapeGlow(frame: halo.bounds, path: path) }
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
            tint = Theme.accent.withAlphaComponent(0.85)
        } else if spec.isFunction {
            tint = Theme.functionKey
        } else {
            tint = nil
        }
        let state = "\(usesAccent)|\(spec.isFunction)"
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

    /// The effects themselves (KeyEffectPlayer), drawn by the same code as the app's preview of them.
    private lazy var effects: KeyEffectPlayer = makeEffects()
    private func keyShapePath() -> CGPath {
        return UIBezierPath(roundedRect: bounds, cornerRadius: Theme.keyCornerRadius(for: bounds.size)).cgPath
    }

    /// The label drawn once for the echo, kept while the key shows the same thing.
    private var echoImage: CGImage?
    private var echoSignature = ""
    /// Called when the key goes down with an effect colour, so the keyboard can light the keys around it (wave).
    var onEffectPress: ((KeyView, UIColor) -> Void)?

    /// The light under the key, once an effect has made it.
    private var pressGlow: CALayer? { return effects.pressGlow }

    /// Where effects that leave the key (sparks, the echo) are drawn: a layer over all the keys, so a neighbouring
    /// key never hides them.
    func attachEffects(overlay: CALayer) {
        effects.overlay = overlay
    }

    private func makeEffects() -> KeyEffectPlayer {
        let player = KeyEffectPlayer()
        player.keyLayer = layer
        player.labelLayers = { [weak self] in
            guard let self = self else { return [] }
            return ([self.label, self.iconView] as [UIView]).filter { !$0.isHidden }.map { $0.layer }
        }
        player.echoImage = { [weak self] in self?.renderEcho() }
        // The light and shadow under the key live outside it (the halo), so they are moved with it.
        player.followers = { [weak self] in
            guard let self = self, self.haloAttached else { return [] }
            return [self.halo]
        }
        player.installGlow = { [weak self] glow in
            guard let self = self else { return }
            if self.haloAttached {
                self.halo.addSublayer(glow)   // under every key, so it never lights a neighbour
            } else if let glassView = self.glassView {
                self.layer.insertSublayer(glow, above: glassView.layer)
            } else {
                self.layer.insertSublayer(glow, at: 0)
            }
        }
        player.onWave = { [weak self] color in
            guard let self = self else { return }
            self.onEffectPress?(self, color)
        }
        return player
    }

    /// The colour of one press's effects, by the Effects screen's colour choice for all the effects.
    static func effectColor(traits: UITraitCollection) -> UIColor {
        let effects = Prefs.effects
        return KeyEffectPlayer.color(mode: effects.colorMode, custom: effects.customColor,
                                     accent: Theme.accent.resolvedColor(with: traits))
    }

    /// Gives the effects the settings, the colours and the key's place.
    private func syncEffects() {
        let player = effects
        player.config = Prefs.effects
        player.accent = Theme.accent.resolvedColor(with: traitCollection)
        player.bounds = bounds
        player.radius = Theme.keyCornerRadius(for: bounds.size)
        player.frameInOverlay = frame
    }

    /// The effects follow the key's size (the stretched backspace grows while its press effects still play).
    private func layoutEffects(radius: CGFloat) {
        syncEffects()
        effects.refit()
    }

    private func playPressEffects(pressed: Bool) {
        guard Prefs.effects.playsOnPress else { return }
        syncEffects()
        effects.press(pressed)
    }

    /// A swiping finger passed over the key: its press effects play once (the glow comes and goes) without the key
    /// itself showing as held down.
    func playSwipeEffects() {
        guard Prefs.effects.playsOnPress else { return }
        syncEffects()
        effects.press(true)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            guard let self = self, !self.isPressed else { return }
            self.effects.press(false)
        }
    }

    /// The key lights up as part of a wave that started at a neighbour: a pulse of its glow, `delay` seconds late.
    func waveLight(color: UIColor, strength: Float, delay: TimeInterval) {
        guard haloAttached else { return }
        syncEffects()
        effects.waveLight(color: color, strength: strength, delay: delay)
    }

    /// The label (or symbol) as a picture, for the echo.
    private func renderEcho() -> CGImage? {
        let source: UIView = label.isHidden ? iconView : label
        guard source.bounds.width > 0, source.bounds.height > 0 else { return nil }
        let signature = "\(label.text ?? "")|\(source.bounds.size)|\(label.isHidden)"
        if echoSignature != signature || echoImage == nil {
            echoImage = UIGraphicsImageRenderer(bounds: source.bounds).image { source.layer.render(in: $0.cgContext) }.cgImage
            echoSignature = signature
        }
        return echoImage
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

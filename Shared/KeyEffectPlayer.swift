import UIKit

/// One move of a key (or of its label) while an effect plays: offsets from where it rests, one after another.
struct KeyMove {
    enum Part {
        /// Scale, turn (radians), sideways and up-down (points), a turn over (radians), the label's scale.
        case scale, turn, x, y, flip, label
    }
    let part: Part
    let values: [CGFloat]
    /// When each value is reached, as shares of the duration (nil: evenly spaced).
    var keyTimes: [Double]? = nil
    let duration: Double
    var eased = false

    /// The offset `elapsed` seconds in, as Core Animation plays it (KeyEffectPlayer.move): straight lines between the
    /// values, the whole run eased in and out when `eased`; 0 once it is over.
    func value(after elapsed: Double) -> CGFloat {
        guard duration > 0, elapsed >= 0, elapsed < duration, values.count > 1 else { return 0 }
        var t = min(max(elapsed / duration, 0), 1)
        if eased { t = KeyMove.easeInOut(t) }
        let times = keyTimes ?? values.indices.map { Double($0) / Double(values.count - 1) }
        for index in 1..<min(values.count, times.count) where t <= times[index] {
            let from = times[index - 1]
            let share = times[index] > from ? (t - from) / (times[index] - from) : 1
            return values[index - 1] + (values[index] - values[index - 1]) * CGFloat(share)
        }
        return values[values.count - 1]
    }

    /// Core Animation's ease in and out: the curve (0.42, 0) to (0.58, 1), solved for the time.
    private static func easeInOut(_ x: Double) -> Double {
        func bezier(_ s: Double, _ a: Double, _ b: Double) -> Double {
            return 3 * (1 - s) * (1 - s) * s * a + 3 * (1 - s) * s * s * b + s * s * s
        }
        var low = 0.0, high = 1.0
        for _ in 0..<20 {
            let mid = (low + high) / 2
            if bezier(mid, 0.42, 0.58) < x { low = mid } else { high = mid }
        }
        return bezier((low + high) / 2, 0, 1)
    }
}

/// The press effects (the Effects screen) of one key, drawn with Core Animation. The keyboard (KeyView) and the app's
/// Effects preview both play them with this code, so the preview looks exactly like the keyboard.
final class KeyEffectPlayer {
    // What the owner sets before each press.
    var config = EffectsConfig()
    var accent: UIColor = .systemBlue
    /// The key's size and corner radius.
    var bounds: CGRect = .zero
    var radius: CGFloat = 0
    /// The key's frame in `overlay`.
    var frameInOverlay: CGRect = .zero

    /// The key's own layer: the effects drawn on the key are added to it, and the moves (squish, jelly) play on it.
    weak var keyLayer: CALayer?
    /// Where effects that leave the key are drawn: a layer over all the keys, so a neighbour never hides them.
    weak var overlay: CALayer?
    /// The label's layers, which the pop swells.
    var labelLayers: () -> [CALayer] = { [] }
    /// The label drawn as a picture, for the echo.
    var echoImage: () -> CGImage? = { nil }
    /// Puts the glow (made on first use) under the keys; without it the glow goes under the key's own content.
    var installGlow: ((CALayer) -> Void)?
    /// Layers outside the key that move with it (the light and shadow under it), so they follow the squish and the rest.
    var followers: () -> [CALayer] = { [] }
    /// Whether the moves are played on the key's layers. The app's preview turns it off and plays them itself from
    /// `onMove`, on its drawing of the key and on everything drawn on it at once.
    var playsMoves = true
    /// Told of every move, after it has been played on the key's layer.
    var onMove: ((KeyMove) -> Void)?
    /// Told when the key goes down with the wave's colour, so the keys around it can light up.
    var onWave: ((UIColor) -> Void)?

    /// The light under the key: fades in on press, out on release, and pulses for the wave.
    private(set) var pressGlow: CALayer?

    /// The effects still playing on the key, each with how to fit it to a new size and corner radius.
    private var fitters: [(layer: CALayer, fit: (CGRect, CGFloat) -> Void)] = []

    private func track(_ layer: CALayer, _ fit: @escaping (CGRect, CGFloat) -> Void) {
        fitters.removeAll { $0.layer.superlayer == nil }
        fitters.append((layer, fit))
    }

    /// The key changed size (the stretched backspace): the glow and everything still playing on it follow, so
    /// outlines, flashes, shines and the rest always cover the key as it is now.
    func refit() {
        fitters.removeAll { $0.layer.superlayer == nil }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for fitter in fitters { fitter.fit(bounds, radius) }
        CATransaction.commit()
        layoutGlow()
    }

    // MARK: Colours

    /// The next rainbow hue (shared by every key, so each press is a new colour).
    private static var rainbowHue: CGFloat = 0

    /// The colour of one press for a colour choice (`mode`), with `custom` the chosen colour.
    static func color(mode: String, custom: ThemeRGBA, accent: UIColor) -> UIColor {
        switch mode {
        case "white":
            return .white
        case "custom":
            return UIColor(red: CGFloat(custom.r), green: CGFloat(custom.g), blue: CGFloat(custom.b), alpha: CGFloat(custom.a))
        case "accent":
            return accent
        case "rainbow":
            rainbowHue = (rainbowHue + 0.11).truncatingRemainder(dividingBy: 1)
            return palette(mode, rainbowHue)
        default:
            return palette(mode, CGFloat.random(in: 0..<1))
        }
    }

    /// One colour of a palette (EffectPalette) as a UIColor.
    static func palette(_ mode: String, _ hue: CGFloat) -> UIColor {
        let tint = EffectPalette.tint(mode, hue)
        return UIColor(hue: tint.h, saturation: tint.s, brightness: tint.b, alpha: 1)
    }

    /// The colour of one press's effect `id`: its own colour choice, else the one for all.
    private func color(_ id: String) -> UIColor {
        return KeyEffectPlayer.color(mode: config.mode(for: id), custom: config.custom(for: id), accent: accent)
    }

    /// The colour of one speck of an effect that gives each speck its own: a colour of the palette, else `color`.
    private func speckColor(_ id: String, _ hue: CGFloat, _ color: UIColor) -> UIColor {
        let mode = config.mode(for: id)
        return EffectPalette.isMulti(mode) ? KeyEffectPlayer.palette(mode, hue) : color
    }

    // MARK: Press

    /// Plays the effects of the key going down, or fades its glow as it comes up.
    func press(_ pressed: Bool) {
        let effects = config
        guard effects.playsOnPress else { return }
        guard pressed else {
            if effects.glow { fadeGlow(on: false, color: nil) }
            return
        }
        if effects.glow { fadeGlow(on: true, color: color("glow")) }
        if effects.border { lightBorder(color("border")) }
        if effects.ripple { ripple(color("ripple")) }
        if effects.shine { shine(color("shine")) }
        if effects.pop { pop() }
        if effects.wave { onWave?(color("wave")) }
        if effects.squish { squish() }
        if effects.flash { flash(color("flash")) }
        if effects.jelly { jelly() }
        if effects.heartbeat { heartbeat() }
        if effects.flip { flip() }
        if effects.shake { shake() }
        if effects.drop { drop() }
        if effects.glitch { glitch() }
        if effects.underline { underline(color("underline")) }
        if effects.sweep { neonSweep(color("sweep")) }
        // The effects that make many layers are built a moment later, after the press itself has been handled, and are
        // left out while too many are still on screen: typing fast stays smooth.
        guard KeyEffectPlayer.liveLayers < KeyEffectPlayer.layerBudget else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self = self, self.keyLayer != nil else { return }
            if effects.sparks { self.sparks(self.color("sparks")) }
            if effects.echo { self.echo() }
            if effects.shockwave { self.shockwave(self.color("shockwave")) }
            if effects.confetti { self.confetti(self.color("confetti")) }
            if effects.bubbles { self.bubbles(self.color("bubbles")) }
            if effects.lightning { self.lightning(self.color("lightning")) }
            self.playParticles(self.accent)
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

    /// The size the effects are made for: the key's, but not much wider than it is tall, so a wide key (space,
    /// return) gets effects about the size of a letter key's instead of ones stretched across it.
    private var effectSize: CGSize {
        return CGSize(width: min(bounds.width, bounds.height * 1.3), height: bounds.height)
    }

    /// The width the effects are measured in (effectSize).
    private var unit: CGFloat { return effectSize.width }

    private func keyShapePath() -> CGPath {
        return UIBezierPath(roundedRect: bounds, cornerRadius: radius).cgPath
    }

    // MARK: Glow

    /// Fits the glow to the key after it is laid out.
    func layoutGlow() {
        shapeGlow(frame: bounds, path: keyShapePath())
    }

    /// Fits the glow's lights to `path` (in the glow's own coordinates) and to the Spread setting: a wide soft light
    /// and a tight bright core.
    func shapeGlow(frame: CGRect, path: CGPath) {
        guard let glow = pressGlow else { return }
        glow.frame = frame
        let spread = 12 * CGFloat(config.glowSpread)
        for (index, light) in (glow.sublayers ?? []).enumerated() {
            light.frame = glow.bounds
            light.shadowPath = path
            light.shadowRadius = index == 0 ? spread : spread * 0.35
        }
    }

    /// The glow: two lights at full strength in a holder whose opacity fades in and out (so both fade together).
    private func glowLayer() -> CALayer {
        if let existing = pressGlow { return existing }
        let glow = CALayer()
        glow.opacity = 0
        for _ in 0..<2 {
            let light = CALayer()
            light.shadowOffset = .zero
            light.shadowOpacity = 1
            glow.addSublayer(light)
        }
        pressGlow = glow
        layoutGlow()
        if let install = installGlow {
            install(glow)   // under every key, so it never lights a neighbour
        } else {
            keyLayer?.insertSublayer(glow, at: 0)
        }
        return glow
    }

    private func fadeGlow(on: Bool, color: UIColor?) {
        let effects = config
        let glow = glowLayer()
        layoutGlow()
        if on, let color = color { tintGlow(glow, color) }
        let target = on ? Float(effects.glowStrength) : 0
        let duration = on ? effects.glowFadeIn : effects.glowFadeOut
        let from = glow.presentation()?.opacity ?? glow.opacity
        glow.opacity = target
        glow.removeAnimation(forKey: "glow")
        guard duration > 0.001 else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = from
        fade.toValue = target
        fade.duration = duration
        fade.timingFunction = CAMediaTimingFunction(name: on ? .easeOut : .easeIn)
        glow.add(fade, forKey: "glow")
    }

    private func tintGlow(_ glow: CALayer, _ color: UIColor) {
        for light in glow.sublayers ?? [] { light.shadowColor = color.cgColor }
    }

    /// The key lights up as part of a wave that started at a neighbour: a pulse of its glow, `delay` seconds late.
    func waveLight(color: UIColor, strength: Float, delay: TimeInterval) {
        let glow = glowLayer()
        tintGlow(glow, color)
        let pulse = CAKeyframeAnimation(keyPath: "opacity")
        pulse.values = [0, min(1, strength * 1.6), 0]
        pulse.keyTimes = [0, 0.3, 1]
        pulse.duration = max(config.glowFadeOut, 0.45)
        pulse.beginTime = CACurrentMediaTime() + delay
        pulse.fillMode = .backwards
        glow.add(pulse, forKey: "wave" + String(CACurrentMediaTime()))
    }

    // MARK: On the key

    /// A line round the key in the effect colour that fades away.
    private func lightBorder(_ color: UIColor) {
        guard let keyLayer = keyLayer else { return }
        let width = CGFloat(config.borderWidth)
        let line = CAShapeLayer()
        line.frame = bounds
        line.path = UIBezierPath(roundedRect: bounds.insetBy(dx: width / 2, dy: width / 2),
                                 cornerRadius: max(0, radius - width / 2)).cgPath
        line.fillColor = nil
        line.strokeColor = color.cgColor
        line.lineWidth = width
        line.opacity = 0
        keyLayer.addSublayer(line)
        track(line) { bounds, radius in KeyEffectPlayer.fitOutline(line, width: width, bounds: bounds, radius: radius) }
        CATransaction.begin()
        CATransaction.setCompletionBlock { line.removeFromSuperlayer() }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = config.borderFade
        fade.timingFunction = CAMediaTimingFunction(name: .easeIn)
        line.add(fade, forKey: "fade")
        CATransaction.commit()
    }

    /// An outline stroke of `width` round a key of `bounds` and `radius`.
    private static func fitOutline(_ line: CAShapeLayer, width: CGFloat, bounds: CGRect, radius: CGFloat) {
        line.frame = bounds
        line.path = UIBezierPath(roundedRect: bounds.insetBy(dx: width / 2, dy: width / 2),
                                 cornerRadius: max(0, radius - width / 2)).cgPath
    }

    /// A holder the size of the key, clipped to its shape, for effects that stay inside the key. When the key
    /// changes size the holder takes the new shape and what is in it is stretched to match.
    private func clippedHolder() -> CALayer {
        let holder = CALayer()
        holder.frame = bounds
        holder.cornerRadius = radius
        holder.cornerCurve = .continuous
        holder.masksToBounds = true
        keyLayer?.addSublayer(holder)
        let made = bounds.size
        track(holder) { bounds, radius in
            holder.frame = bounds
            holder.cornerRadius = radius
            // Content laid out for `made`, scaled about the holder's middle so its corner stays at the corner.
            let kx = made.width > 0 ? bounds.width / made.width : 1
            let ky = made.height > 0 ? bounds.height / made.height : 1
            holder.sublayerTransform = CATransform3DConcat(
                CATransform3DMakeScale(kx, ky, 1),
                CATransform3DMakeTranslation((kx - 1) * bounds.width / 2, (ky - 1) * bounds.height / 2, 0))
        }
        return holder
    }

    /// A disc (or a ring) of light spreading from the middle of the key, inside its shape, while it fades away.
    private func ripple(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let effects = config
        // Across the whole key, whatever its width, so the widest setting always reaches its edges.
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
        let start = startOffset("ripple")
        wave.position = CGPoint(x: bounds.midX + start.x, y: bounds.midY + start.y)
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
        let effects = config
        let holder = clippedHolder()
        // A share of the key's own width, so a wide key gets a band in proportion.
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

    /// The key flashes in the effect colour, inside its shape.
    private func flash(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let effects = config
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

    /// A line grows from the middle along the bottom of the key and fades.
    private func underline(_ color: UIColor) {
        guard bounds.width > 0 else { return }
        let duration = config.underlineDuration
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
        guard bounds.width > 0, let keyLayer = keyLayer else { return }
        let duration = config.sweepDuration
        let width: CGFloat = 3
        let line = CAShapeLayer()
        line.frame = bounds
        line.path = UIBezierPath(roundedRect: bounds.insetBy(dx: width / 2, dy: width / 2),
                                 cornerRadius: max(0, radius - width / 2)).cgPath
        line.fillColor = nil
        line.strokeColor = color.cgColor
        line.lineWidth = width
        line.lineCap = .round
        line.opacity = 0
        keyLayer.addSublayer(line)
        track(line) { bounds, radius in KeyEffectPlayer.fitOutline(line, width: width, bounds: bounds, radius: radius) }
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

    // MARK: Moves

    /// Plays a move on the key (or its label) without stopping one that is still playing: taps in quick succession
    /// add up (the animation moves the key relative to where it is, and each one has a key of its own).
    private func move(_ move: KeyMove) {
        let animation: CAKeyframeAnimation
        switch move.part {
        case .scale, .label: animation = CAKeyframeAnimation(keyPath: "transform.scale")
        case .turn: animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        case .x: animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        case .y: animation = CAKeyframeAnimation(keyPath: "transform.translation.y")
        case .flip: animation = CAKeyframeAnimation(keyPath: "transform")
        }
        if move.part == .flip {
            // In steps, so the turn goes all the way round instead of taking the short way back to the start.
            let total = move.values.last ?? 0
            animation.values = (0...12).map { step -> NSValue in
                var matrix = CATransform3DIdentity
                matrix.m34 = -1 / 500
                return NSValue(caTransform3D: CATransform3DRotate(matrix, CGFloat(step) / 12 * total, 1, 0, 0))
            }
        } else {
            animation.values = move.values
            animation.keyTimes = move.keyTimes?.map { NSNumber(value: $0) }
        }
        animation.duration = move.duration
        if move.eased { animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut) }
        animation.isAdditive = true
        let name = "move" + String(CACurrentMediaTime())
        if !playsMoves {
            // The owner plays it.
        } else if move.part == .label {
            for layer in labelLayers() { layer.add(animation, forKey: name) }
        } else {
            keyLayer?.add(animation, forKey: name)
            for layer in followers() { layer.add(animation, forKey: name) }
        }
        onMove?(move)
    }

    /// The label swells (or shrinks) and springs back.
    private func pop() {
        let swell = CGFloat(config.popScale) - 1
        move(KeyMove(part: .label, values: [0, swell, -swell * 0.25, swell * 0.08, 0], keyTimes: [0, 0.35, 0.6, 0.82, 1],
                     duration: config.popDuration))
    }

    /// The key squashes under the finger and springs back, with only a hint of overshoot so the shrink is what shows.
    private func squish() {
        let depth = CGFloat(config.squishDepth) - 1
        move(KeyMove(part: .scale, values: [0, depth, depth * 0.6, -depth * 0.1, 0], keyTimes: [0, 0.2, 0.5, 0.8, 1],
                     duration: 0.4))
    }

    /// The key wobbles like jelly, the swings getting smaller.
    private func jelly() {
        let angle = CGFloat(config.jellyAngle) * .pi / 180
        move(KeyMove(part: .turn, values: [0, angle, -angle * 0.8, angle * 0.5, -angle * 0.25, 0],
                     keyTimes: [0, 0.18, 0.4, 0.62, 0.82, 1], duration: 0.5))
    }

    /// The key pulses twice, like a heartbeat.
    private func heartbeat() {
        let beat = CGFloat(config.heartbeatStrength) - 1
        move(KeyMove(part: .scale, values: [0, beat, 0, beat, 0], keyTimes: [0, 0.2, 0.4, 0.62, 1], duration: 0.55))
    }

    /// The key turns over like a card.
    private func flip() {
        move(KeyMove(part: .flip, values: [0, 2 * .pi], duration: config.flipDuration, eased: true))
    }

    /// The key shakes from side to side.
    private func shake() {
        let distance = CGFloat(config.shakeDistance)
        move(KeyMove(part: .x, values: [0, -distance, distance, -distance * 0.7, distance * 0.5, -distance * 0.2, 0], duration: 0.3))
    }

    /// The key sinks and bounces back.
    private func drop() {
        let depth = CGFloat(config.dropDepth)
        move(KeyMove(part: .y, values: [0, depth, -depth * 0.35, depth * 0.12, 0], keyTimes: [0, 0.3, 0.6, 0.8, 1], duration: 0.4))
    }

    /// The key jumps sideways while pink and cyan copies flicker over it.
    private func glitch() {
        guard bounds.width > 0 else { return }
        let strength = CGFloat(config.glitchStrength)
        move(KeyMove(part: .x, values: [0, -strength * 6, strength * 5, -strength * 3, strength * 4, 0], duration: 0.24))
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

    // MARK: Leaving the key

    /// The layer and the middle of the key in it, for effects that leave the key.
    /// `id` is the effect: where on the key it starts is its own position setting (nil: the middle, for the particle
    /// effects, which are placed when their specks are made).
    private func overlayTarget(_ id: String? = nil) -> (host: CALayer, center: CGPoint)? {
        let start = id.map { startOffset($0) } ?? .zero
        if let host = overlay {
            return (host, CGPoint(x: frameInOverlay.midX + start.x, y: frameInOverlay.midY + start.y))
        }
        guard let layer = keyLayer else { return nil }
        return (layer, CGPoint(x: bounds.midX + start.x, y: bounds.midY + start.y))
    }

    /// Where the effect `id` starts on the key for this press, from the middle (its position setting).
    private func startOffset(_ id: String) -> CGPoint {
        return EffectPosition.offset(config.position(for: id), size: bounds.size, random: { CGFloat.random(in: 0..<1) })
    }

    /// The angle, clockwise from straight up, the throwing effects go at for one press (0 when they go up as designed).
    private func effectTurn(_ id: String) -> CGFloat {
        return EffectDirection.target(config.direction(for: id), random: { CGFloat.random(in: 0..<1) }) ?? 0
    }

    /// Specks that fly out of the key in every direction and fade.
    private func sparks(_ color: UIColor) {
        guard bounds.width > 0, let target = overlayTarget("sparks") else { return }
        let effects = config
        let count = KeyEffectPlayer.reserve(max(1, Int(effects.sparkCount.rounded())))
        guard count > 0 else { return }
        let size = CGFloat(effects.sparkSize)
        let reach = unit * CGFloat(effects.sparkDistance)
        let offset = CGFloat.random(in: 0..<(2 * .pi))
        var specks: [CALayer] = []
        CATransaction.begin()
        CATransaction.setCompletionBlock { specks.forEach { $0.removeFromSuperlayer() }; KeyEffectPlayer.release(count) }
        for index in 0..<count {
            let angle = offset + 2 * .pi * CGFloat(index) / CGFloat(count)
            let distance = reach * CGFloat.random(in: 0.7...1.15)
            let speck = CALayer()
            speck.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            speck.cornerRadius = size / 2
            speck.backgroundColor = speckColor("sparks", CGFloat(index) / CGFloat(count), color).cgColor
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

    /// A copy of the label floats up out of the key and fades.
    private func echo() {
        guard let image = echoImage(), let target = overlayTarget("echo") else { return }
        let effects = config
        let scale = UIScreen.main.scale
        let ghost = CALayer()
        ghost.bounds = CGRect(x: 0, y: 0, width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        ghost.contents = image
        ghost.contentsScale = scale
        ghost.position = target.center
        ghost.opacity = 0
        target.host.addSublayer(ghost)
        CATransaction.begin()
        CATransaction.setCompletionBlock { ghost.removeFromSuperlayer() }
        let away = EffectDirection.turn(CGPoint(x: 0, y: -CGFloat(effects.echoRise)), by: effectTurn("echo"))
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
        guard bounds.width > 0, let target = overlayTarget("shockwave") else { return }
        let effects = config
        let radius = unit * CGFloat(effects.shockReach)
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

    /// Small pieces of paper thrown up out of the key that tumble down, fading.
    private func confetti(_ color: UIColor) {
        guard bounds.width > 0, let target = overlayTarget("confetti") else { return }
        let effects = config
        let count = KeyEffectPlayer.reserve(max(1, Int(effects.confettiCount.rounded())))
        guard count > 0 else { return }
        let duration = effects.confettiDuration
        let width = unit
        let turn = effectTurn("confetti")
        var pieces: [CALayer] = []
        CATransaction.begin()
        CATransaction.setCompletionBlock { pieces.forEach { $0.removeFromSuperlayer() }; KeyEffectPlayer.release(count) }
        for _ in 0..<count {
            let piece = CALayer()
            piece.bounds = CGRect(x: 0, y: 0, width: CGFloat.random(in: 4...7), height: CGFloat.random(in: 2...4))
            piece.backgroundColor = speckColor("confetti", CGFloat.random(in: 0..<1), color)
                .withAlphaComponent(CGFloat.random(in: 0.6...1)).cgColor
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
        guard bounds.width > 0, let target = overlayTarget("bubbles") else { return }
        let effects = config
        let count = KeyEffectPlayer.reserve(max(1, Int(effects.bubbleCount.rounded())))
        guard count > 0 else { return }
        let rise = CGFloat(effects.bubbleRise)
        let turn = effectTurn("bubbles")
        var drops: [CALayer] = []
        CATransaction.begin()
        CATransaction.setCompletionBlock { drops.forEach { $0.removeFromSuperlayer() }; KeyEffectPlayer.release(count) }
        for _ in 0..<count {
            let size = CGFloat.random(in: 5...11)
            let bubble = CAShapeLayer()
            bubble.bounds = CGRect(x: 0, y: 0, width: size, height: size)
            bubble.path = UIBezierPath(ovalIn: bubble.bounds.insetBy(dx: 0.75, dy: 0.75)).cgPath
            bubble.fillColor = color.withAlphaComponent(0.18).cgColor
            bubble.strokeColor = color.withAlphaComponent(0.9).cgColor
            bubble.lineWidth = 1.5
            bubble.opacity = 0
            let startX = target.center.x + CGFloat.random(in: -0.35...0.35) * unit
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

    /// Hearts, stars, snow, notes, fireworks, rays, rain, embers, smoke, orbit, spiral and the catalog's effects: all
    /// the particle effects that are on, flying out of the key over the keys around it.
    private func playParticles(_ color: UIColor) {
        guard bounds.width > 0, let target = overlayTarget() else { return }
        var specs = EffectParticles.make(config, keySize: effectSize, area: bounds.size) { _, _ in CGFloat.random(in: 0..<1) }
        guard !specs.isEmpty else { return }
        let allowed = KeyEffectPlayer.reserve(specs.count)
        guard allowed > 0 else { return }
        if allowed < specs.count { specs = Array(specs.prefix(allowed)) }
        var specks: [CALayer] = []
        CATransaction.begin()
        CATransaction.setCompletionBlock { specks.forEach { $0.removeFromSuperlayer() }; KeyEffectPlayer.release(allowed) }
        for spec in specs {
            let tint = spec.tint.map { UIColor(hue: $0.h, saturation: $0.s, brightness: $0.b, alpha: 1) } ?? color
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
        guard bounds.width > 0, let target = overlayTarget("lightning") else { return }
        let length = unit * CGFloat(config.lightningLength)
        let bolt = EffectBolt.make(length: length, width: unit) { _, _ in CGFloat.random(in: 0..<1) }

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
        let strokes: [(path: UIBezierPath, color: UIColor, width: CGFloat)] = [
            (main, color.withAlphaComponent(0.3), 14), (main, color.withAlphaComponent(0.5), 8), (main, color, 3.5), (main, .white, 1.5),
            (forks, color.withAlphaComponent(0.3), 8), (forks, color.withAlphaComponent(0.5), 4), (forks, color, 1.8), (forks, .white, 0.8),
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
}

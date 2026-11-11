import SwiftUI
import UIKit
import ObjectiveC

/// The theme switch's wave used between the app's screens, in place of the slide: going into a screen, the wave
/// spreads out from the centre of the element tapped; going back, from the centre of the screen's left edge.
///
/// No pictures of the screen are taken. Both screens are live: the new one is put over the old one and cut to the
/// wave's irregular circle (a mask the render server animates on its own, nothing is drawn for each frame), so the old
/// screen shows outside the front and the new one inside it, and the rim (GlassWaveBand) is laid over the window.
/// Every animated change of a navigation stack asks its delegate for the animation (NavigationWaveDelegate, put in
/// place whoever sets the delegate), so pushes, pops, a path changed in code and the edge swipe back all play it.
/// Reduce Motion keeps the system's slide.
/// What the touches have told: kept apart from the (main actor's) wave so a gesture can write it at once.
enum WaveNote {
    /// The centre of the element just tapped (window coordinates), noted by `waveSource()` when it was tapped.
    static var nextSource: (point: CGPoint, time: CFTimeInterval)?
    /// Where the screen was last touched: the start of the wave when no element noted its centre.
    static var lastTouch: CGPoint?
}

@MainActor
enum NavigationWave {
    /// A quarter faster than the theme switch's wave, and a quarter again.
    static let length: TimeInterval = ModeWave.duration / 1.25 / 1.25
    /// How long a change in the look (the accent colour) waits: the ring round a swatch settles first, so the picture
    /// of the window the wave carries is of a window at rest.
    static let changeSettle: TimeInterval = 0.3

    /// Whether the wave plays at all (Reduce Motion keeps the system's own changes).
    static var canPlay: Bool {
        return !UIAccessibility.isReduceMotionEnabled && WindowWave.window != nil
    }
    private static var recording = false

    /// Where the wave sets off: into a screen, the centre of the list element under the last touch (every element that
    /// opens a screen is marked with `waveSource()`), else the touch itself; back, the centre of the left edge.
    static func source(push: Bool) -> CGPoint {
        let size = WindowWave.window?.bounds.size ?? UIScreen.main.bounds.size
        guard push else { return CGPoint(x: 0, y: size.height / 2) }
        if let touch = WaveNote.lastTouch { return ViewAnchor.centerOfElement(containing: touch) ?? touch }
        return CGPoint(x: size.width / 2, y: size.height / 2)
    }

    /// A wave over the whole window, set off from `source` now.
    static func makeWave(from source: CGPoint) -> ModeWave {
        let size = WindowWave.window?.bounds.size ?? UIScreen.main.bounds.size
        ModeWave.count += 1
        let scheme: ColorScheme = WindowWave.window?.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        return ModeWave(id: ModeWave.count, oldScheme: scheme, newScheme: scheme, oldTheme: "", newTheme: "",
                        source: source, minX: 0, minY: 0, width: size.width, height: size.height,
                        started: CACurrentMediaTime(), startedDate: Date(), length: length)
    }

    /// Plays the wave across a change that is not a screen change (the accent colour): the window is photographed,
    /// `apply` makes the change, and the wave carries the window over to its new look. `source` is the centre of
    /// the element that asked for it (the last touch, without one). With Reduce Motion the change is just made.
    static func change(from source: CGPoint?, delay: TimeInterval = NavigationWave.changeSettle, apply: @escaping () -> Void) {
        guard canPlay, let window = WindowWave.window else {
            apply()
            return
        }
        let size = window.bounds.size
        let origin = source ?? WaveNote.lastTouch ?? CGPoint(x: size.width / 2, y: size.height / 2)
        // After the animations of the tap (the ring round a swatch) have finished.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            WindowWave.start(for: makeWave(from: origin))
            // With every animation off, so the new picture is of the finished look.
            var transaction = Transaction(animation: nil)
            transaction.disablesAnimations = true
            UIView.performWithoutAnimation {
                withTransaction(transaction, apply)
            }
        }
    }

    /// Whether the system is showing something over the app (the colour picker, while it is open).
    static var isPresenting: Bool {
        func presenting(_ controller: UIViewController) -> Bool {
            return controller.presentedViewController != nil || controller.children.contains(where: presenting)
        }
        guard let root = WindowWave.window?.rootViewController else { return false }
        return presenting(root)
    }

    /// Notes where every touch lands in the window, as it lands (a gesture that fails at once and takes nothing).
    static func recordTouches(in window: UIWindow) {
        guard !recording else { return }
        recording = true
        window.addGestureRecognizer(TouchNoter())
    }

    private final class TouchNoter: UIGestureRecognizer {
        init() {
            super.init(target: nil, action: nil)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if let touch = touches.first { WaveNote.lastTouch = touch.location(in: nil) }
            state = .failed
        }
    }

    /// The rim, over the window, for as long as `wave` lives (it takes no touches).
    static func showRim(of wave: ModeWave, lasting duration: TimeInterval) {
        guard let window = WindowWave.window else { return }
        let host = UIHostingController(rootView: GlassWaveBand(waves: [wave]))
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        host.view.frame = window.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        window.addSubview(host.view)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { host.view.removeFromSuperview() }
    }
}

/// The navigation controller's delegate while the wave is in use: it supplies the transition and passes everything
/// else on to the delegate that was there (the one SwiftUI's stack set).
@MainActor
final class NavigationWaveDelegate: NSObject, UINavigationControllerDelegate {
    fileprivate weak var original: UINavigationControllerDelegate?
    private static var associationKey: UInt8 = 0

    static func install(on navigation: UINavigationController) {
        if navigation.delegate is NavigationWaveDelegate { return }
        wrap(navigation.delegate, on: navigation)
    }

    /// Makes the delegate `original` (or none) the one this proxy passes things on to, and sets the proxy.
    fileprivate static func wrap(_ original: UINavigationControllerDelegate?, on navigation: UINavigationController) {
        let proxy = NavigationWaveDelegate()
        proxy.original = original
        objc_setAssociatedObject(navigation, &associationKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        navigation.wave_setDelegate(proxy)
    }

    func navigationController(_ navigationController: UINavigationController,
                              animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        // The app's own screens only (not a stack inside a system sheet, such as the colour picker's).
        guard operation != .none, NavigationWave.canPlay, navigationController.presentingViewController == nil,
              navigationController.view.window === WindowWave.window else {
            return original?.navigationController?(navigationController, animationControllerFor: operation, from: fromVC, to: toVC)
        }
        return WaveTransition(push: operation == .push)
    }

    // What the stack's own delegate may be listening for goes on to it.
    func navigationController(_ navigationController: UINavigationController, willShow viewController: UIViewController,
                              animated: Bool) {
        original?.navigationController?(navigationController, willShow: viewController, animated: animated)
    }

    func navigationController(_ navigationController: UINavigationController, didShow viewController: UIViewController,
                              animated: Bool) {
        original?.navigationController?(navigationController, didShow: viewController, animated: animated)
    }

    func navigationController(_ navigationController: UINavigationController,
                              interactionControllerFor animationController: UIViewControllerAnimatedTransitioning)
        -> UIViewControllerInteractiveTransitioning? {
        return original?.navigationController?(navigationController, interactionControllerFor: animationController)
    }

    // Anything else the stack's own delegate answers.
    override func responds(to selector: Selector!) -> Bool {
        return super.responds(to: selector) || (original?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if let original = original, original.responds(to: selector) { return original }
        return super.forwardingTarget(for: selector)
    }
}

/// The transition itself: the new screen goes over the old one, cut to the wave's circle, which grows (the cut is a
/// mask whose outline is animated by Core Animation: the render server does the work, every frame is ready before it
/// is wanted), and the rim travels with it.
@MainActor
private final class WaveTransition: NSObject, UIViewControllerAnimatedTransitioning {
    let push: Bool
    private let wave: ModeWave
    private let duration: TimeInterval

    init(push: Bool) {
        self.push = push
        wave = NavigationWave.makeWave(from: NavigationWave.source(push: push))
        duration = wave.lifetime
        WaveNote.nextSource = nil
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return duration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let to = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        let container = transitionContext.containerView
        let toView = to.view!
        toView.frame = transitionContext.finalFrame(for: to)
        container.addSubview(toView)
        toView.layoutIfNeeded()

        // The outline at each step of the way, relative to the new screen's corner.
        let origin = toView.convert(CGPoint.zero, to: nil)
        let steps = max(24, Int(duration * 60))
        let paths: [CGPath] = (0...steps).map { index in
            let elapsed = Double(index) / Double(steps) * duration
            let share = ModeWave.ease(CGFloat(elapsed / wave.length))
            let path = CGMutablePath()
            let points = wave.outline(share, relativeTo: origin)
            if let first = points.first {
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
                path.closeSubpath()
            }
            return path
        }
        let mask = CAShapeLayer()
        mask.frame = toView.bounds
        mask.fillColor = UIColor.black.cgColor
        mask.path = paths.last
        toView.layer.mask = mask
        let animation = CAKeyframeAnimation(keyPath: "path")
        animation.values = paths
        animation.duration = duration
        animation.calculationMode = .linear
        animation.isRemovedOnCompletion = false
        animation.fillMode = .forwards
        mask.add(animation, forKey: "wave")

        NavigationWave.showRim(of: wave, lasting: duration)
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            toView.layer.mask = nil
            transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
        }
    }
}

/// Put in the background of a screen's content: gives its navigation controller the wave transition.
struct NavigationWaveHook: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> HookController { return HookController() }
    func updateUIViewController(_ controller: HookController, context: Context) {}

    final class HookController: UIViewController {
        override func viewDidLoad() {
            super.viewDidLoad()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
        }

        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            install()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            install()
        }

        private func install() {
            guard let navigation = navigationController else { return }
            NavigationWaveDelegate.install(on: navigation)
            if let window = view.window { NavigationWave.recordTouches(in: window) }
        }
    }
}

// MARK: - The element tapped

/// Where a view is in the window, read when it is tapped.
final class ViewAnchor {
    weak var view: UIView?

    private struct Entry { weak var anchor: ViewAnchor? }
    private static var registered: [Entry] = []

    /// Makes this anchor one of the elements that open a screen (see `centerOfElement`).
    func register() {
        ViewAnchor.registered.removeAll { $0.anchor == nil }
        if !ViewAnchor.registered.contains(where: { $0.anchor === self }) { ViewAnchor.registered.append(Entry(anchor: self)) }
    }

    /// The centre (window coordinates) of the smallest registered element on screen that holds `point`.
    static func centerOfElement(containing point: CGPoint) -> CGPoint? {
        var best: (area: CGFloat, center: CGPoint)?
        for entry in registered {
            guard let view = entry.anchor?.view, view.window != nil else { continue }
            let frame = view.convert(view.bounds, to: nil)
            guard frame.insetBy(dx: -2, dy: -2).contains(point) else { continue }
            let area = frame.width * frame.height
            if best == nil || area < best!.area { best = (area, CGPoint(x: frame.midX, y: frame.midY)) }
        }
        return best?.center
    }

    var center: CGPoint? {
        guard let view = view, view.window != nil else { return nil }
        return view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
    }
}

struct AnchorView: UIViewRepresentable {
    let anchor: ViewAnchor
    /// An element that opens a screen: the wave into the screen starts from its centre.
    var registers = false

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        anchor.view = view
        if registers { anchor.register() }
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        anchor.view = view
        if registers { anchor.register() }
    }
}

private struct WaveSource: ViewModifier {
    @State private var anchor = ViewAnchor()

    func body(content: Content) -> some View {
        content.background(AnchorView(anchor: anchor, registers: true))
    }
}

extension View {
    /// Marks the element whose tap opens a screen: the wave into that screen spreads from the element's centre.
    func waveSource() -> some View {
        return modifier(WaveSource())
    }
}

/// A set of anchors, one for each of several views (the accent colour's swatches), kept by a view.
final class AnchorBook {
    private var anchors: [String: ViewAnchor] = [:]

    func anchor(_ key: String) -> ViewAnchor {
        if let known = anchors[key] { return known }
        let new = ViewAnchor()
        anchors[key] = new
        return new
    }
}

extension View {
    /// Lets `anchor` find this view in the window.
    func waveAnchor(_ anchor: ViewAnchor) -> some View {
        return background(AnchorView(anchor: anchor))
    }
}

// MARK: - Every delegate a stack is given

extension UINavigationController {
    /// Swaps in a setter for the delegate that puts the wave's delegate between the stack and whatever it sets, so
    /// the wave plays however the stack's owner (SwiftUI) arranges it. Done once.
    static let installWave: Void = {
        guard let a = class_getInstanceMethod(UINavigationController.self, #selector(setter: UINavigationController.delegate)),
              let b = class_getInstanceMethod(UINavigationController.self, #selector(UINavigationController.wave_setDelegate(_:))) else { return }
        method_exchangeImplementations(a, b)
    }()

    /// (After the swap this is the original setter, and the original setter is this.)
    @objc fileprivate func wave_setDelegate(_ delegate: UINavigationControllerDelegate?) {
        if let delegate = delegate, !(delegate is NavigationWaveDelegate) {
            NavigationWaveDelegate.wrap(delegate, on: self)
        } else {
            wave_setDelegate(delegate)
        }
    }
}

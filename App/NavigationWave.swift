import SwiftUI
import UIKit
import ObjectiveC

/// The theme switch's wave (ModeWave, WindowWave) used between the app's screens, in place of the slide: going into a
/// screen, the wave spreads out from the centre of the element tapped; going back, from the centre of the screen's
/// left edge. A quarter faster than the theme switch's.
///
/// Every push and pop of a navigation stack asks its delegate for the animation; the one set here (NavigationWaveDelegate)
/// photographs the window as it is, lets the screens change at once, and the wave carries the window across to the new
/// picture. Reduce Motion keeps the system's slide.
/// What the touches have told: kept apart from the (main actor's) wave so a gesture can write it at once.
enum WaveNote {
    /// The centre of the element just tapped (window coordinates), noted by `waveSource()` when it was tapped.
    static var nextSource: (point: CGPoint, time: CFTimeInterval)?
    /// Where the screen was last touched: the start of the wave when no element noted its centre.
    static var lastTouch: CGPoint?
}

@MainActor
enum NavigationWave {
    /// A quarter faster than the theme switch's wave.
    static let length: TimeInterval = ModeWave.duration / 1.25
    /// How long a tap waits before its change starts: the pressed look of the element, and whatever else was set
    /// moving, settles first, so the picture of the window the wave carries is of a window at rest.
    static let settle: TimeInterval = 0.4

    /// Whether the wave plays at all (Reduce Motion keeps the system's own changes).
    static var canPlay: Bool {
        return !UIAccessibility.isReduceMotionEnabled && WindowWave.window != nil
    }
    private static var recording = false

    /// Starts the wave: the window is photographed now, before the screens change.
    static func start(push: Bool) {
        guard let window = WindowWave.window else { return }
        let size = window.bounds.size
        let source: CGPoint
        if push {
            // The centre of the list element under the last touch (every element that opens a screen is marked with
            // `waveSource()`), else the touch itself.
            if let touch = WaveNote.lastTouch {
                source = ViewAnchor.centerOfElement(containing: touch) ?? touch
            } else {
                source = CGPoint(x: size.width / 2, y: size.height / 2)
            }
        } else {
            source = CGPoint(x: 0, y: size.height / 2)
        }
        WaveNote.nextSource = nil
        start(from: source)
    }

    /// Plays the wave across a change that is not a screen change (the accent colour): the window is photographed,
    /// `apply` makes the change, and the wave carries the window over to its new look. `source` is the centre of
    /// the element that asked for it (the last touch, without one). With Reduce Motion the change is just made.
    static func change(from source: CGPoint?, delay: TimeInterval = NavigationWave.settle, apply: @escaping () -> Void) {
        guard canPlay, let window = WindowWave.window else {
            apply()
            return
        }
        let size = window.bounds.size
        let origin = source ?? WaveNote.lastTouch ?? CGPoint(x: size.width / 2, y: size.height / 2)
        // After the animations of the tap (the element's press, the ring round a swatch) have finished.
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            start(from: origin)
            apply()
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
}

/// The navigation controller's delegate while the wave is in use: it supplies the transition and passes everything
/// else on to the delegate that was there (the one SwiftUI's stack set).
@MainActor
final class NavigationWaveDelegate: NSObject, UINavigationControllerDelegate {
    private weak var original: UINavigationControllerDelegate?
    private static var associationKey: UInt8 = 0

    static func install(on navigation: UINavigationController) {
        if navigation.delegate is NavigationWaveDelegate { return }
        let proxy = NavigationWaveDelegate()
        proxy.original = navigation.delegate
        objc_setAssociatedObject(navigation, &associationKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        navigation.delegate = proxy
    }

    func navigationController(_ navigationController: UINavigationController,
                              animationControllerFor operation: UINavigationController.Operation,
                              from fromVC: UIViewController, to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        guard operation != .none, !UIAccessibility.isReduceMotionEnabled else { return nil }
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
}

/// The transition itself: the window's picture is taken, the new screen is put in place at once, and the wave over
/// the window (WindowWave) shows the change.
@MainActor
private final class WaveTransition: NSObject, UIViewControllerAnimatedTransitioning {
    let push: Bool

    init(push: Bool) {
        self.push = push
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.01
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let from = transitionContext.viewController(forKey: .from),
              let to = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }
        NavigationWave.start(push: push)
        let container = transitionContext.containerView
        to.view.frame = transitionContext.finalFrame(for: to)
        if push {
            container.addSubview(to.view)
        } else {
            container.insertSubview(to.view, belowSubview: from.view)
        }
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
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

// MARK: - Every push and pop

extension UINavigationController {
    /// Swaps in versions of the push and pop calls that play the wave in place of the slide: the window is
    /// photographed, then the change is made without animation. (The edge swipe back is the system's own gesture; it
    /// goes through the delegate's transition, NavigationWaveDelegate.) Done once.
    static let installWave: Void = {
        func swap(_ original: Selector, _ replacement: Selector) {
            guard let a = class_getInstanceMethod(UINavigationController.self, original),
                  let b = class_getInstanceMethod(UINavigationController.self, replacement) else { return }
            method_exchangeImplementations(a, b)
        }
        swap(#selector(UINavigationController.pushViewController(_:animated:)), #selector(UINavigationController.wave_push(_:animated:)))
        swap(#selector(UINavigationController.popViewController(animated:)), #selector(UINavigationController.wave_pop(animated:)))
        swap(#selector(UINavigationController.popToRootViewController(animated:)), #selector(UINavigationController.wave_popToRoot(animated:)))
        swap(#selector(UINavigationController.popToViewController(_:animated:)), #selector(UINavigationController.wave_popTo(_:animated:)))
        swap(#selector(UINavigationController.setViewControllers(_:animated:)), #selector(UINavigationController.wave_set(_:animated:)))
    }()

    /// The app's own screens only (not a stack inside a system sheet, such as the colour picker's).
    private var playsWave: Bool {
        return NavigationWave.canPlay && presentingViewController == nil && view.window != nil && view.window === WindowWave.window
    }

    private static var pendingKey: UInt8 = 0

    /// Makes the change after the tap's own animations have finished (a later change replaces one still waiting), with
    /// the wave started first.
    private func afterSettling(push: Bool, _ change: @escaping () -> Void) {
        (objc_getAssociatedObject(self, &UINavigationController.pendingKey) as? DispatchWorkItem)?.cancel()
        let item = DispatchWorkItem {
            NavigationWave.start(push: push)
            change()
        }
        objc_setAssociatedObject(self, &UINavigationController.pendingKey, item, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        DispatchQueue.main.asyncAfter(deadline: .now() + NavigationWave.settle, execute: item)
    }

    @objc fileprivate func wave_push(_ viewController: UIViewController, animated: Bool) {
        guard animated, playsWave else { return wave_push(viewController, animated: animated) }
        afterSettling(push: true) { self.wave_push(viewController, animated: false) }
    }

    @objc fileprivate func wave_pop(animated: Bool) -> UIViewController? {
        guard animated, playsWave, viewControllers.count > 1 else { return wave_pop(animated: animated) }
        let leaving = viewControllers.last
        afterSettling(push: false) { _ = self.wave_pop(animated: false) }
        return leaving
    }

    @objc fileprivate func wave_popToRoot(animated: Bool) -> [UIViewController]? {
        guard animated, playsWave, viewControllers.count > 1 else { return wave_popToRoot(animated: animated) }
        let leaving = Array(viewControllers.dropFirst())
        afterSettling(push: false) { _ = self.wave_popToRoot(animated: false) }
        return leaving
    }

    @objc fileprivate func wave_popTo(_ viewController: UIViewController, animated: Bool) -> [UIViewController]? {
        guard animated, playsWave, viewControllers.last !== viewController,
              let index = viewControllers.firstIndex(of: viewController) else {
            return wave_popTo(viewController, animated: animated)
        }
        let leaving = Array(viewControllers.suffix(from: index + 1))
        afterSettling(push: false) { _ = self.wave_popTo(viewController, animated: false) }
        return leaving
    }

    @objc fileprivate func wave_set(_ controllers: [UIViewController], animated: Bool) {
        guard animated, playsWave, controllers.last !== viewControllers.last else {
            return wave_set(controllers, animated: animated)
        }
        let push = controllers.count >= viewControllers.count
        afterSettling(push: push) { self.wave_set(controllers, animated: false) }
    }
}

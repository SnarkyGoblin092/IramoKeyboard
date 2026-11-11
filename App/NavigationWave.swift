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
    private static var recording = false

    /// Starts the wave: the window is photographed now, before the screens change.
    static func start(push: Bool) {
        guard let window = WindowWave.window else { return }
        let size = window.bounds.size
        let source: CGPoint
        if push {
            if let next = WaveNote.nextSource, CACurrentMediaTime() - next.time < 1.5 {
                source = next.point
            } else {
                source = WaveNote.lastTouch ?? CGPoint(x: size.width / 2, y: size.height / 2)
            }
        } else {
            source = CGPoint(x: 0, y: size.height / 2)
        }
        WaveNote.nextSource = nil
        start(from: source)
    }

    /// Starts the wave from `source` (window coordinates): the window is photographed now, before anything changes.
    static func start(from source: CGPoint) {
        guard let window = WindowWave.window else { return }
        let size = window.bounds.size
        ModeWave.count += 1
        let scheme: ColorScheme = window.traitCollection.userInterfaceStyle == .dark ? .dark : .light
        let wave = ModeWave(id: ModeWave.count, oldScheme: scheme, newScheme: scheme, oldTheme: "", newTheme: "",
                            source: source, minX: 0, minY: 0, width: size.width, height: size.height,
                            started: CACurrentMediaTime(), startedDate: Date(), length: length)
        WindowWave.start(for: wave)
    }

    /// Plays the wave across a change that is not a screen change (the accent colour): the window is photographed,
    /// `apply` makes the change, and the wave carries the window over to its new look. `source` is the centre of
    /// the element that asked for it (the last touch, without one). With Reduce Motion the change is just made.
    static func change(from source: CGPoint?, apply: () -> Void) {
        guard !UIAccessibility.isReduceMotionEnabled, let window = WindowWave.window else {
            apply()
            return
        }
        let size = window.bounds.size
        start(from: source ?? WaveNote.lastTouch ?? CGPoint(x: size.width / 2, y: size.height / 2))
        apply()
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

    var center: CGPoint? {
        guard let view = view, view.window != nil else { return nil }
        return view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil)
    }
}

struct AnchorView: UIViewRepresentable {
    let anchor: ViewAnchor

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        anchor.view = view
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        anchor.view = view
    }
}

private struct WaveSource: ViewModifier {
    @State private var anchor = ViewAnchor()

    func body(content: Content) -> some View {
        content
            .background(AnchorView(anchor: anchor))
            .simultaneousGesture(TapGesture().onEnded {
                if let center = anchor.center { WaveNote.nextSource = (center, CACurrentMediaTime()) }
            })
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

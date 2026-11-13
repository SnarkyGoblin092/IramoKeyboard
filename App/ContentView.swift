import SwiftUI
import UIKit

// MARK: - The app's areas

/// The four areas of the settings and the search, as the tab bar has them. Each area is one short list (HomeTabs)
/// instead of one long list of everything: what the keyboard writes, how it looks, how it answers the fingers, and
/// the rest. A new setting goes on the tab it belongs to (`owning`), and into the search (SettingsIndex).
enum AppTab: String, Hashable, CaseIterable {
    case typing, look, touch, more, search

    var title: String {
        switch self {
        case .typing: return tr("Typing")
        case .look: return tr("Look")
        case .touch: return tr("Touch")
        case .more: return tr("More")
        case .search: return tr("Search")
        }
    }

    var symbol: String {
        switch self {
        case .typing: return "keyboard"
        case .look: return "paintpalette"
        case .touch: return "hand.tap"
        case .more: return "ellipsis"
        case .search: return "magnifyingglass"
        }
    }

    /// The tab's own list, as a place the search can take the user to.
    var scope: Screen { return .tab(rawValue) }

    /// The tab a screen is opened from.
    static func owning(_ screen: Screen) -> AppTab {
        switch screen {
        case .tab(let name): return AppTab(rawValue: name) ?? .typing
        case .languages, .languageLayout, .suggestions, .smartTyping, .shortcuts, .learnedWords: return .typing
        case .themes, .themeEditor, .keys, .effects: return .look
        case .gestures, .haptics, .longPress, .functions, .tapAccuracy: return .touch
        case .stats, .appLanguage, .licences: return .more
        }
    }
}

/// The app: its areas as the tabs of the system's tab view (Liquid Glass bar), the search as its search tab, which the
/// bar turns into the search field when it is tapped. Every tab keeps its own place: the screens opened on it, and how
/// far its list is scrolled.
struct ContentView: View {
    @State private var tab = AppTab.typing
    /// The tab shown before this one (the search is cleared when it is left).
    @State private var previous = AppTab.typing
    /// The screens open on each tab.
    @State private var paths: [AppTab: [Screen]] = [:]
    /// What is typed in the search.
    @State private var query = ""
    /// The search is being left for a setting it found: its words stay.
    @State private var keepsQuery = false
    @AppStorage(SettingKey.appLanguage, store: SharedStore.defaults) private var appLanguage = SettingDefault.appLanguage
    @AppStorage(SettingKey.appearance, store: SharedStore.defaults) private var appearance = SettingDefault.appearance
    /// The first-run welcome page (Welcome.swift); the More tab's button shows it again by clearing this.
    @AppStorage(SettingKey.welcomeSeen, store: SharedStore.defaults) private var welcomeSeen = false
    /// Whether the welcome page is up. Kept apart from the setting, so nothing the system does as the app leaves
    /// and returns can close it or open it again: only its own buttons close it, and Replay opens it.
    @State private var showWelcome = !SharedStore.defaults.bool(forKey: SettingKey.welcomeSeen)

    /// The window's full size (the keyboard showing doesn't change it): wide enough, a tab shows two columns.
    @State private var windowSize: CGSize = .zero

    /// Landscape on an iPhone or iPad: a tab's list on the left and the open screen beside it.
    private static func isWide(_ size: CGSize) -> Bool {
        return size.width > size.height && size.width >= 640
    }

    private func path(_ tab: AppTab) -> Binding<[Screen]> {
        return Binding(get: { paths[tab] ?? [] }, set: { paths[tab] = $0 })
    }

    /// The tab chosen in the bar: a soft tick, and the system keyboard put away.
    private var selection: Binding<AppTab> {
        return Binding(get: { tab }, set: { item in
            if item == tab {
                // The tab already shown goes back to its own list.
                if !(paths[item] ?? []).isEmpty { paths[item] = [] }
                return
            }
            Feedback.tick()
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            TabSlide.towardsEnd = AppTab.allCases.firstIndex(of: item).map { $0 > (AppTab.allCases.firstIndex(of: tab) ?? 0) } ?? true
            tab = item
        })
    }

    var body: some View {
        tabs
            .background(GlassBackdrop())
            .background(GeometryReader { geometry in
                Color.clear
                    .onAppear { windowSize = geometry.size }
                    .onChange(of: geometry.size) { windowSize = $0 }
            }.ignoresSafeArea())
            // The app switcher's snapshot of the app shows the glass and the colours empty; a picture of the window
            // as it is, laid over it while the app is not active, is what that snapshot then takes.
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                SnapshotCover.show()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                SnapshotCover.hide()
            }
            .onChange(of: welcomeSeen) { seen in
                // The More tab's "Replay welcome" clears it.
                if !seen { showWelcome = true }
            }
            .onChange(of: tab) { new in
                if previous == .search, new != .search, !keepsQuery { query = "" }
                keepsQuery = false
                previous = new
            }
            .toggleStyle(GlassSwitchStyle())   // every switch in the app is the system's glass switch, in the accent
            // Everything is built again in the new language when it changes (tr reads it as the views are drawn);
            // the tab and the screens open on it are kept, so the user stays where the language was picked.
            .id(appLanguage)
            .environment(\.locale, AppLanguage.locale)
            .environment(\.layoutDirection, AppLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
            .modifier(AccentTint())
            .roundedType()
            // The Themes screen's light / dark switch sets the mode of the whole app ("auto": the system's).
            .preferredColorScheme(appearance == "light" ? .light : (appearance == "dark" ? .dark : nil))
            .fullScreenCover(isPresented: Binding(get: { showWelcome }, set: { _ in })) {
                WelcomeView {
                    SharedStore.defaults.set(0, forKey: WelcomeView.pageKey)
                    showWelcome = false
                    welcomeSeen = true
                }
                    .environment(\.locale, AppLanguage.locale)
                    .environment(\.layoutDirection, AppLanguage.isRightToLeft ? .rightToLeft : .leftToRight)
                    .modifier(AccentTint())
                    .roundedType()
            }
            .onAppear {
                Feedback.prepare()
                // The enabled languages' data is unpacked now, so the keyboard finds it ready.
                LanguageData.prepareInBackground(enabled: Settings.shared.enabledLanguages)
            }
    }

    // MARK: The tabs

    @ViewBuilder private var tabs: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            TabView(selection: selection) {
                ForEach([AppTab.typing, .look, .touch, .more], id: \.self) { item in
                    Tab(value: item) {
                        page(item)
                    } label: {
                        Label(item.title, systemImage: item.symbol)
                    }
                }
                // The search tab stands apart from the others in the bar, and becomes the search field when tapped.
                Tab(value: AppTab.search, role: .search) {
                    page(.search)
                } label: {
                    Label(AppTab.search.title, systemImage: AppTab.search.symbol)
                }
            }
        } else {
            classicTabs
        }
        #else
        classicTabs
        #endif
    }

    private var classicTabs: some View {
        TabView(selection: selection) {
            ForEach(AppTab.allCases, id: \.self) { item in
                page(item)
                    .tabItem { Label(item.title, systemImage: item.symbol) }
                    .tag(item)
            }
        }
    }

    @ViewBuilder private func page(_ item: AppTab) -> some View {
        Group {
            if item == .search {
                SearchTab(query: $query) { entry in open(entry) }
            } else {
                TabColumn(tab: item, path: path(item), wide: ContentView.isWide(windowSize), windowWidth: windowSize.width)
            }
        }
        // What a tab that is not shown would do for nothing (a live keyboard, a looping picture) rests until it is.
        .environment(\.tabIsFront, item == tab)
        .background(TabSlideInstaller())
    }

    /// A setting picked in the search: its tab comes to the front with its screen open, and its row lights up.
    private func open(_ entry: SearchEntry) {
        if let anchor = entry.anchor {
            SearchFocus.shared.request = SearchFocus.Request(screen: entry.screen, anchor: anchor)
        }
        guard let screen = entry.screen else { return }
        keepsQuery = true
        let target = AppTab.owning(screen)
        if case .tab = screen {
            paths[target] = []
        } else if paths[target] == [screen] {
            // Already open on that tab: opened afresh, so it starts on the page the setting is on.
            paths[target] = []
            DispatchQueue.main.async { paths[target] = [screen] }
        } else {
            paths[target] = [screen]
        }
        TabSlide.towardsEnd = AppTab.allCases.firstIndex(of: target).map { $0 > (AppTab.allCases.firstIndex(of: tab) ?? 0) } ?? true
        tab = target
    }
}

private struct TabIsFrontKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether the view is on the tab that is shown. Every tab stays built beside the others, so what would run for
    /// nothing on a tab that is not shown (a live keyboard, a looping picture) reads this and rests.
    var tabIsFront: Bool {
        get { return self[TabIsFrontKey.self] }
        set { self[TabIsFrontKey.self] = newValue }
    }
}

/// One tab: its list, and the screens opened from it. Upright they are pushed over the list (and the tab bar makes
/// way for them: ContentView); in landscape the list stays as a column on the left and the screens open beside it. The same
/// `path` either way, so turning the device keeps the place.
struct TabColumn: View {
    let tab: AppTab
    @Binding var path: [Screen]
    let wide: Bool
    let windowWidth: CGFloat

    var body: some View {
        if wide {
            landscape
        } else {
            NavigationStack(path: $path) {
                TabRoot(tab: tab)
                    .navigationDestination(for: Screen.self) { $0.scopedView }
            }
            // A screen opened on the tab takes the whole screen: the tab bar slides away for it, and back up from
            // the bottom when it is left.
            .toolbar(path.isEmpty ? .visible : .hidden, for: .tabBar)
            .environment(\.openScreen, { screen in path.append(screen) })
        }
    }

    private var landscape: some View {
        HStack(spacing: 0) {
            NavigationStack { TabRoot(tab: tab) }
                .frame(width: min(400, max(300, windowWidth * 0.38)))
                .environment(\.openScreen, { screen in path = [screen] })
                .environment(\.shownScreen, path.first)
            Divider().ignoresSafeArea()
            NavigationStack(path: Binding(get: { Array(path.dropFirst()) },
                                          set: { path = Array(path.prefix(1)) + $0 })) {
                Group {
                    if let screen = path.first {
                        screen.scopedView
                    } else {
                        VStack(spacing: 14) {
                            Keycap(size: 64) {
                                Image(systemName: tab.symbol).font(.system(size: 26, weight: .semibold))
                            }
                            Text(tr("Pick a setting on the left."))
                        }
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .glassScreen()
                    }
                }
                .navigationDestination(for: Screen.self) { $0.scopedView }
            }
            // Another screen picked on the left starts afresh.
            .id(path.first)
            .environment(\.openScreen, { screen in path.append(screen) })
        }
    }
}

/// The list a tab opens with (HomeTabs.swift).
private struct TabRoot: View {
    let tab: AppTab

    var body: some View {
        switch tab {
        case .typing: TypingTab()
        case .look: LookTab()
        case .touch: TouchTab()
        case .more: MoreTab()
        case .search: EmptyView()
        }
    }
}

// MARK: - Screens

/// The screens the tabs open.
enum Screen: Hashable {
    case languages, appLanguage, suggestions, gestures, shortcuts, functions, themes, themeEditor, keys, effects, haptics, learnedWords, licences
    case smartTyping, stats, longPress, tapAccuracy
    /// The letter layout of one language (its code).
    case languageLayout(String)
    /// A tab's own list (AppTab's name): not a screen that is opened, but a place the search can point at.
    case tab(String)

    /// The screen, marked as itself for the settings search (SearchFocus).
    var scopedView: some View {
        return view.environment(\.searchScope, self)
    }

    @ViewBuilder var view: some View {
        switch self {
        case .smartTyping: SmartTypingView()
        case .stats: StatsView()
        case .longPress: LongPressCharactersView()
        case .tapAccuracy: TapAccuracyView()
        case .languageLayout(let code): LanguageLayoutView(language: Language(rawValue: code) ?? .english)
        case .languages: LanguagesView()
        case .appLanguage: AppLanguageView()
        case .suggestions: SuggestionsView()
        case .gestures: GesturesView()
        case .shortcuts: ShortcutsView()
        case .functions: FunctionsView()
        case .themes: ThemesView()
        case .themeEditor: ThemeEditorView()
        case .keys: KeysView()
        case .effects: EffectsView()
        case .haptics: HapticsView()
        case .learnedWords: LearnedWordsView()
        case .licences: LicensesView()
        case .tab: EmptyView()
        }
    }
}

private struct OpenScreenKey: EnvironmentKey {
    static let defaultValue: (Screen) -> Void = { _ in }
}

private struct ShownScreenKey: EnvironmentKey {
    static let defaultValue: Screen? = nil
}

extension EnvironmentValues {
    /// The screen open beside a tab's list in landscape (its row is marked).
    var shownScreen: Screen? {
        get { return self[ShownScreenKey.self] }
        set { self[ShownScreenKey.self] = newValue }
    }

    /// Opens a screen on the tab the view is on (set by TabColumn).
    var openScreen: (Screen) -> Void {
        get { return self[OpenScreenKey.self] }
        set { self[OpenScreenKey.self] = newValue }
    }
}

/// A row that opens a screen: the whole row is one button (a soft tap, then the screen), with the disclosure arrow
/// on the right. A plain button rather than a NavigationLink with an extra tap gesture, which in a list could take
/// the tap and leave the screen unopened.
struct ScreenRow<Label: View>: View {
    let screen: Screen
    @ViewBuilder let label: () -> Label
    @Environment(\.openScreen) private var openScreen
    @Environment(\.shownScreen) private var shownScreen
    @Environment(\.swipeFade) private var swipeFade

    init(_ screen: Screen, @ViewBuilder label: @escaping () -> Label) {
        self.screen = screen
        self.label = label
    }

    var body: some View {
        Button {
            Feedback.tap()
            openScreen(screen)
        } label: {
            HStack(spacing: 8) {
                label()
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(shownScreen == screen ? .accentColor : Color(.tertiaryLabel))
                    .opacity(swipeFade)
            }
            .foregroundColor(.primary)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Status

struct KeyboardStatus {
    var seen: Bool
    var fullAccess: Bool

    static func read() -> KeyboardStatus {
        let store = SharedStore.defaults
        // Enabled: the system lists the keyboard among the ones switched on (checked here, in the app, so the answer
        // is current). Full Access can only be told by the keyboard itself, which saves it each time it opens.
        // A visit to Settings (the buttons that open it) may have changed it, so it counts once the keyboard has
        // opened after the visit and saved it again.
        let visit = UserDefaults.standard.double(forKey: KeyboardStatus.visitKey)
        let confirmed = store.double(forKey: SettingKey.lastSeen) > visit
        return KeyboardStatus(seen: isEnabled, fullAccess: store.bool(forKey: SettingKey.fullAccess) && confirmed)
    }

    private static let visitKey = "hunkeys.settingsVisit"

    /// Opens the app's page in Settings, noting the time.
    static func openSettings() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: visitKey)
        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }

    /// Whether the keyboard is among the system's enabled keyboards.
    private static var isEnabled: Bool {
        let id = (Bundle.main.bundleIdentifier ?? "") + ".keyboard"
        return UITextInputMode.activeInputModes.contains { ($0.value(forKey: "identifier") as? String) == id }
    }

    /// Nothing left to set up: the Typing tab then shows no setup card.
    var isReady: Bool { return seen && fullAccess && SharedStore.isShared }
}

/// A picture of the window, laid over it while the app is not in front (see ContentView).
@MainActor
private enum SnapshotCover {
    private static var cover: UIView?

    static func show() {
        guard cover == nil, let window = WindowWave.window else { return }
        let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        let view = UIImageView(image: image)
        view.frame = window.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.isUserInteractionEnabled = false
        window.addSubview(view)
        cover = view
    }

    static func hide() {
        cover?.removeFromSuperview()
        cover = nil
    }
}

// MARK: - Sliding between the tabs

/// Puts the slide on the system tab view's own tab controller, so the pages slide from one tab to the next while the
/// tab bar stays the system's. Found from inside a tab, through the responder chain.
private struct TabSlideInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = InstallerView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {}

    private final class InstallerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in
                var responder: UIResponder? = self
                while let next = responder?.next {
                    if let controller = next as? UITabBarController {
                        TabSlide.install(on: controller)
                        return
                    }
                    responder = next
                }
            }
        }
    }
}

/// The tab controller's delegate: the slide, and everything else passed on to the delegate the system had set.
final class TabSlide: NSObject, UITabBarControllerDelegate, UIViewControllerAnimatedTransitioning {
    private static var current: TabSlide?
    /// The tab being switched to comes after the one shown (is on its right, in a left-to-right app).
    static var towardsEnd = true
    private weak var original: UITabBarControllerDelegate?

    static func install(on controller: UITabBarController) {
        // The backdrop is behind the whole tab view: nothing of the controller paints over it.
        controller.view.backgroundColor = .clear
        if controller.delegate is TabSlide { return }
        let slide = TabSlide()
        slide.original = controller.delegate
        current = slide
        controller.delegate = slide
    }

    override func responds(to selector: Selector!) -> Bool {
        return super.responds(to: selector) || (original?.responds(to: selector) ?? false)
    }

    override func forwardingTarget(for selector: Selector!) -> Any? {
        if let original = original, original.responds(to: selector) { return original }
        return super.forwardingTarget(for: selector)
    }

    func tabBarController(_ tabBarController: UITabBarController,
                          animationControllerForTransitionFrom fromVC: UIViewController,
                          to toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return UIAccessibility.isReduceMotionEnabled ? nil : self
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.38
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        guard let from = context.viewController(forKey: .from), let to = context.viewController(forKey: .to) else {
            context.completeTransition(false)
            return
        }
        // Which side the new tab is on, noted by ContentView as the tab is chosen (not mirrored for right-to-left
        // languages: the tabs keep their order).
        let forward: CGFloat = TabSlide.towardsEnd ? 1 : -1
        let width = context.containerView.bounds.width
        let frame = context.finalFrame(for: to)
        context.containerView.addSubview(to.view)
        to.view.frame = frame
        to.view.transform = CGAffineTransform(translationX: forward * width, y: 0)
        UIView.animate(withDuration: transitionDuration(using: context), delay: 0,
                       usingSpringWithDamping: 0.92, initialSpringVelocity: 0, options: [.curveEaseInOut]) {
            from.view.transform = CGAffineTransform(translationX: -forward * width, y: 0)
            to.view.transform = .identity
        } completion: { _ in
            from.view.transform = .identity
            context.completeTransition(!context.transitionWasCancelled)
        }
    }
}

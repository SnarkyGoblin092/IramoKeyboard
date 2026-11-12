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
        case .gestures, .haptics, .longPress, .functions: return .touch
        case .stats, .appLanguage, .licences: return .more
        }
    }
}

/// The app: a tab for each area and one for the search, under the system's Liquid Glass tab bar. Every tab keeps
/// its own place (the screens opened on it), so going to another tab and back loses nothing.
struct ContentView: View {
    @State private var tab = AppTab.typing
    /// The screens open on each tab.
    @State private var paths: [AppTab: [Screen]] = [:]
    /// What is typed in the search.
    @State private var query = ""
    @AppStorage(SettingKey.appLanguage, store: SharedStore.defaults) private var appLanguage = SettingDefault.appLanguage
    @AppStorage(SettingKey.appearance, store: SharedStore.defaults) private var appearance = SettingDefault.appearance
    /// The first-run welcome page (Welcome.swift); the More tab's button shows it again by clearing this.
    @AppStorage(SettingKey.welcomeSeen, store: SharedStore.defaults) private var welcomeSeen = false

    /// The window's full size (the keyboard showing doesn't change it): wide enough, a tab shows two columns.
    @State private var windowSize: CGSize = .zero
    /// How far the tab just chosen still has to slide in: 1 from the trailing side, -1 from the leading side, 0 at
    /// rest.
    @State private var slide: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Landscape on an iPhone or iPad: a tab's list on the left and the open screen beside it.
    private static func isWide(_ size: CGSize) -> Bool {
        return size.width > size.height && size.width >= 640
    }

    private func path(_ tab: AppTab) -> Binding<[Screen]> {
        return Binding(get: { paths[tab] ?? [] }, set: { paths[tab] = $0 })
    }

    var body: some View {
        tabs
            // A tab chosen (in the bar, by a swipe or by the search) slides in from the side it is on.
            .onChange(of: tab) { [tab] chosen in slideIn(from: tab, to: chosen) }
            .environment(\.tabSwipe, { step in swipe(step) })
            .background(GeometryReader { geometry in
                Color.clear
                    .onAppear { windowSize = geometry.size }
                    .onChange(of: geometry.size) { windowSize = $0 }
            }.ignoresSafeArea())
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
            .fullScreenCover(isPresented: Binding(get: { !welcomeSeen }, set: { welcomeSeen = !$0 })) {
                WelcomeView { welcomeSeen = true }
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

    private func column(_ tab: AppTab) -> some View {
        return TabColumn(tab: tab, path: path(tab), wide: ContentView.isWide(windowSize), windowWidth: windowSize.width)
            .modifier(TabSlide(amount: slide))
    }

    private var search: some View {
        return SearchTab(query: $query) { entry in open(entry) }
            .modifier(TabSlide(amount: slide))
    }

    /// The tab beside the one shown (`step` 1: the next one, -1: the one before), for a swipe across a tab's list.
    private func swipe(_ step: Int) {
        let order = AppTab.allCases
        guard let index = order.firstIndex(of: tab) else { return }
        // The tabs run right to left where the app does.
        let next = index + (AppLanguage.isRightToLeft ? -step : step)
        guard order.indices.contains(next) else { return }
        Feedback.tick()
        tab = order[next]
    }

    /// Starts the new tab a little to the side it is on and lets it slide into place.
    private func slideIn(from old: AppTab, to chosen: AppTab) {
        let order = AppTab.allCases
        guard !reduceMotion, let from = order.firstIndex(of: old), let to = order.firstIndex(of: chosen),
              from != to else { return }
        let forward = (to > from) != AppLanguage.isRightToLeft
        slide = forward ? 1 : -1
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.86)) { slide = 0 }
        }
    }

    /// The tab bar. From iOS 18 the tabs are declared as `Tab`s, so the search is the system's search tab (on
    /// iOS 26 and later it stands apart from the others in the glass bar and opens into the search field).
    @ViewBuilder private var tabs: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $tab) {
                Tab(AppTab.typing.title, systemImage: AppTab.typing.symbol, value: AppTab.typing) { column(.typing) }
                Tab(AppTab.look.title, systemImage: AppTab.look.symbol, value: AppTab.look) { column(.look) }
                Tab(AppTab.touch.title, systemImage: AppTab.touch.symbol, value: AppTab.touch) { column(.touch) }
                Tab(AppTab.more.title, systemImage: AppTab.more.symbol, value: AppTab.more) { column(.more) }
                Tab(value: AppTab.search, role: .search) { search }
            }
            .modifier(TabBarBehaviour())
        } else {
            TabView(selection: $tab) {
                column(.typing)
                    .tabItem { Label(AppTab.typing.title, systemImage: AppTab.typing.symbol) }
                    .tag(AppTab.typing)
                column(.look)
                    .tabItem { Label(AppTab.look.title, systemImage: AppTab.look.symbol) }
                    .tag(AppTab.look)
                column(.touch)
                    .tabItem { Label(AppTab.touch.title, systemImage: AppTab.touch.symbol) }
                    .tag(AppTab.touch)
                column(.more)
                    .tabItem { Label(AppTab.more.title, systemImage: AppTab.more.symbol) }
                    .tag(AppTab.more)
                search
                    .tabItem { Label(AppTab.search.title, systemImage: AppTab.search.symbol) }
                    .tag(AppTab.search)
            }
        }
    }

    /// A setting picked in the search: its tab comes to the front with its screen open, and its row lights up.
    private func open(_ entry: SearchEntry) {
        if let anchor = entry.anchor {
            SearchFocus.shared.request = SearchFocus.Request(screen: entry.screen, anchor: anchor)
        }
        query = ""
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard let screen = entry.screen else { return }
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
        tab = target
    }
}

/// A tab on its way in: moved to the side it comes from, by `amount` (0: in place). It is only moved, not faded:
/// a see-through tab would have all its glass drawn off screen on every frame of the slide.
private struct TabSlide: ViewModifier {
    let amount: CGFloat

    func body(content: Content) -> some View {
        content.offset(x: amount * 56)
    }
}

private struct TabSwipeKey: EnvironmentKey {
    static let defaultValue: (Int) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Moves to the tab beside the one shown (1: the next, -1: the one before). Set by ContentView.
    var tabSwipe: (Int) -> Void {
        get { return self[TabSwipeKey.self] }
        set { self[TabSwipeKey.self] = newValue }
    }
}

/// A sideways swipe across a tab's own list moves to the tab beside it (iOS 18 and later). Only the tabs' lists
/// take it: on the screens opened from them a sideways drag belongs to the sliders, the rows that swipe to delete
/// and the keyboard pinned at the top.
struct TabSwipeable: ViewModifier {
    @Environment(\.tabSwipe) private var tabSwipe

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.gesture(TabSwipePan(swiped: tabSwipe))
        } else {
            content
        }
    }
}

/// A pan that begins only when the drag starts out sideways, leaving vertical drags to the list, and reports a swipe
/// when it ends far or fast enough. It runs alongside the list's own pan.
@available(iOS 18.0, *)
private struct TabSwipePan: UIGestureRecognizerRepresentable {
    /// 1: swiped towards the leading edge (the next tab); -1: towards the trailing edge (the one before).
    let swiped: (Int) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        return Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {}

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        guard recognizer.state == .ended else { return }
        let moved = recognizer.translation(in: recognizer.view)
        let speed = recognizer.velocity(in: recognizer.view)
        guard abs(moved.x) > abs(moved.y) * 1.5, abs(moved.x) > 60 || abs(speed.x) > 500 else { return }
        swiped(moved.x < 0 ? 1 : -1)
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) * 1.5
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            return true
        }
    }
}

/// The glass tab bar draws back to a single button while a list is scrolled down, and comes back on the way up
/// (iOS 26 and later).
private struct TabBarBehaviour: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

/// One tab: its list, and the screens opened from it. Upright they are pushed over the list (and the tab bar makes
/// way for them); in landscape the list stays as a column on the left and the screens open beside it. The same
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
                    .modifier(TabSwipeable())
                    .navigationDestination(for: Screen.self) { screen in
                        screen.scopedView.toolbar(.hidden, for: .tabBar)
                    }
            }
            .environment(\.openScreen, { screen in path.append(screen) })
        }
    }

    private var landscape: some View {
        HStack(spacing: 0) {
            NavigationStack { TabRoot(tab: tab).modifier(TabSwipeable()) }
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
    case smartTyping, stats, longPress
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
        return KeyboardStatus(seen: store.double(forKey: SettingKey.lastSeen) > 0,
                              fullAccess: store.bool(forKey: SettingKey.fullAccess))
    }

    /// Nothing left to set up: the Typing tab then shows no setup card.
    var isReady: Bool { return seen && fullAccess && SharedStore.isShared }
}

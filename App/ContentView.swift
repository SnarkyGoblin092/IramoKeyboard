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

/// The app: its areas side by side as the pages of a pager, under a glass tab bar. A tab chosen in the bar slides in
/// with the one it replaces sliding out, and a sideways drag across a tab's list pulls the tab beside it in under the
/// finger. (The system's tab bar can do neither: it swaps its tabs in place.) Every tab stays built, so it keeps its
/// own place: the screens opened on it, and how far its list is scrolled.
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
    /// The tabs built so far: the first one at once, the others a moment after the app has opened.
    @State private var mounted: Set<AppTab> = [.typing]
    /// The system keyboard is up (the try-it field, the search): the tab bar makes way for it.
    @State private var keyboardUp = false
    /// How far the finger has pulled the pages sideways.
    @StateObject private var motion = PagerMotion()
    /// A sideways drag is moving the pages (and for a moment after): the lists under it neither scroll nor take taps.
    @State private var swiping = false
    /// The search is being left for a setting it found: its words stay.
    @State private var keepsQuery = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How the pages slide from one tab to another.
    private static let slide = Animation.spring(response: 0.42, dampingFraction: 0.9)

    /// Landscape on an iPhone or iPad: a tab's list on the left and the open screen beside it.
    private static func isWide(_ size: CGSize) -> Bool {
        return size.width > size.height && size.width >= 640
    }

    private func path(_ tab: AppTab) -> Binding<[Screen]> {
        return Binding(get: { paths[tab] ?? [] }, set: { paths[tab] = $0 })
    }

    var body: some View {
        pager
            .background(GlassBackdrop())
            .safeAreaInset(edge: .bottom, spacing: 0) { bar }
            .environment(\.tabDrag, { event in drag(event) })
            .environment(\.tabSwiping, swiping)
            .background(GeometryReader { geometry in
                Color.clear
                    .onAppear { windowSize = geometry.size }
                    .onChange(of: geometry.size) { windowSize = $0 }
            }.ignoresSafeArea())
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardUp = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardUp = false
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
                // The other tabs are built once the first one is on screen, so the app opens as fast as before.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { mounted = Set(AppTab.allCases) }
            }
    }

    // MARK: The pages

    /// Every tab built so far, each a whole screen: the one shown in place, the others a screen's width to either
    /// side for each place they are away (PagerPlace).
    private var pager: some View {
        let order = AppTab.allCases
        let current = order.firstIndex(of: tab) ?? 0
        let wide = ContentView.isWide(windowSize)
        return ZStack {
            ForEach(order, id: \.self) { item in
                if mounted.contains(item) {
                    page(item, wide: wide)
                        // What a tab that is not shown would do for nothing (a live keyboard, a looping picture)
                        // rests until it is.
                        .environment(\.tabIsFront, item == tab)
                        .modifier(PagerPlace(motion: motion, position: (order.firstIndex(of: item) ?? 0) - current,
                                             width: windowSize.width, mirrored: AppLanguage.isRightToLeft))
                        .accessibilityHidden(item != tab)
                }
            }
        }
    }

    @ViewBuilder private func page(_ item: AppTab, wide: Bool) -> some View {
        if item == .search {
            SearchTab(query: $query) { entry in open(entry) }
        } else {
            TabColumn(tab: item, path: path(item), wide: wide, windowWidth: windowSize.width)
        }
    }

    /// The tab bar. It makes way for a screen opened on a tab (upright, where the screen takes the whole width) and
    /// for the system keyboard.
    private var bar: some View {
        let shown = !keyboardUp && (ContentView.isWide(windowSize) || (paths[tab] ?? []).isEmpty)
        return ZStack {
            if shown {
                GlassTabBar(selected: tab) { item in select(item) }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.spring(response: 0.34, dampingFraction: 0.9), value: shown)
    }

    // MARK: Moving between the tabs

    /// A tab tapped in the bar. The one already shown goes back to its own list.
    private func select(_ item: AppTab) {
        guard item != tab else {
            if !(paths[item] ?? []).isEmpty { paths[item] = [] }
            return
        }
        Feedback.tick()
        show(item)
    }

    /// Brings a tab to the front, the pages sliding to it.
    private func show(_ item: AppTab) {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        guard mounted.contains(item) else {
            // Not built yet (chosen in the app's first half second): built first, where it stands, then slid to.
            mounted.insert(item)
            DispatchQueue.main.async { show(item) }
            return
        }
        if tab == .search, item != .search, !keepsQuery { query = "" }
        keepsQuery = false
        if reduceMotion {
            motion.drag = 0
            tab = item
        } else {
            withAnimation(ContentView.slide) {
                motion.drag = 0
                tab = item
            }
        }
    }

    /// A sideways drag across a tab's list: the pages follow the finger, and on letting go settle on the tab beside
    /// it (pulled far or fast enough) or back where they were.
    private func drag(_ event: TabDrag) {
        let order = AppTab.allCases
        guard let index = order.firstIndex(of: tab) else { return }
        // The tabs run right to left where the app does.
        let towardsNext: (CGFloat) -> Bool = { dx in (dx < 0) != AppLanguage.isRightToLeft }
        switch event {
        case .moved(let dx):
            if !swiping { swiping = true }
            let beside = index + (towardsNext(dx) ? 1 : -1)
            // Past the last tab there is nothing to pull in: the pages resist.
            motion.drag = order.indices.contains(beside) ? dx : dx * 0.22
        case .ended(let dx, let speed):
            // The lists wake again once the pages have settled.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { swiping = false }
            let beside = index + (towardsNext(dx) ? 1 : -1)
            let far = abs(dx) > max(60, windowSize.width * 0.3) || (abs(speed) > 550 && abs(dx) > 16)
            if far, order.indices.contains(beside) {
                Feedback.tick()
                show(order[beside])
            } else if reduceMotion {
                motion.drag = 0
            } else {
                withAnimation(ContentView.slide) { motion.drag = 0 }
            }
        }
    }

    /// A setting picked in the search: its tab comes to the front with its screen open, and its row lights up.
    private func open(_ entry: SearchEntry) {
        if let anchor = entry.anchor {
            SearchFocus.shared.request = SearchFocus.Request(screen: entry.screen, anchor: anchor)
        }
        keepsQuery = true
        guard let screen = entry.screen else { keepsQuery = false; return }
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
        show(target)
    }
}

// MARK: - The pager

/// How far the finger has pulled the pages. It is kept apart from ContentView's own state so that a drag redraws
/// only where the pages stand (PagerPlace), not the pages themselves, on every frame.
final class PagerMotion: ObservableObject {
    @Published var drag: CGFloat = 0
}

/// Where a page stands: `position` screens to the side of the one shown (0: it is the one shown), moved by the drag.
/// Every page has the whole screen as its frame and is only moved from there, so each keeps the screen's safe areas
/// (a page laid out off screen would lose them until it came in).
private struct PagerPlace: ViewModifier {
    @ObservedObject var motion: PagerMotion
    let position: Int
    let width: CGFloat
    let mirrored: Bool

    func body(content: Content) -> some View {
        content
            .offset(x: CGFloat(position) * width * (mirrored ? -1 : 1) + motion.drag)
            // Before the window's width is known the pages would lie on top of one another.
            .opacity(width > 0 || position == 0 ? 1 : 0)
    }
}

private struct TabIsFrontKey: EnvironmentKey {
    static let defaultValue = true
}

/// A sideways drag across a tab's list, as it goes and as it ends (how far, and how fast it was going).
enum TabDrag {
    case moved(CGFloat)
    case ended(CGFloat, speed: CGFloat)
}

private struct TabSwipingKey: EnvironmentKey {
    static let defaultValue = false
}

private struct TabDragKey: EnvironmentKey {
    static let defaultValue: (TabDrag) -> Void = { _ in }
}

extension EnvironmentValues {
    /// Whether the view is on the tab that is shown. Every tab stays built beside the others, so what would run for
    /// nothing on a tab that is not shown (a live keyboard, a looping picture) reads this and rests.
    var tabIsFront: Bool {
        get { return self[TabIsFrontKey.self] }
        set { self[TabIsFrontKey.self] = newValue }
    }

    /// A sideways drag is moving the pages: the lists on them hold still and take no taps.
    var tabSwiping: Bool {
        get { return self[TabSwipingKey.self] }
        set { self[TabSwipingKey.self] = newValue }
    }

    /// Takes a sideways drag across a tab's list (set by ContentView, which moves the pages with it).
    var tabDrag: (TabDrag) -> Void {
        get { return self[TabDragKey.self] }
        set { self[TabDragKey.self] = newValue }
    }
}

/// A sideways drag across a tab's own list pulls the tab beside it in (iOS 18 and later). Only the tabs' lists take
/// it: on the screens opened from them a sideways drag belongs to the sliders, the rows that swipe to delete and the
/// keyboard pinned at the top.
struct TabSwipeable: ViewModifier {
    @Environment(\.tabDrag) private var tabDrag
    @Environment(\.tabSwiping) private var swiping

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
                .scrollDisabled(swiping)
                // A sheet of nothing over the list while it is swiped: no button under the finger can take the tap.
                .overlay {
                    if swiping { Color.clear.contentShape(Rectangle()).onTapGesture {} }
                }
                .gesture(TabSwipePan(report: tabDrag))
        } else {
            content
        }
    }
}

/// A pan that begins only when the drag starts out sideways, leaving vertical drags to the list, and reports how far
/// it has gone as it goes. It runs alongside the list's own pan.
@available(iOS 18.0, *)
private struct TabSwipePan: UIGestureRecognizerRepresentable {
    let report: (TabDrag) -> Void

    func makeCoordinator(converter: CoordinateSpaceConverter) -> Coordinator {
        return Coordinator()
    }

    func makeUIGestureRecognizer(context: Context) -> UIPanGestureRecognizer {
        let pan = UIPanGestureRecognizer()
        pan.delegate = context.coordinator
        pan.cancelsTouchesInView = true
        return pan
    }

    func updateUIGestureRecognizer(_ recognizer: UIPanGestureRecognizer, context: Context) {}

    func handleUIGestureRecognizerAction(_ recognizer: UIPanGestureRecognizer, context: Context) {
        // Measured in the window: the page under the finger moves with it.
        let moved = recognizer.translation(in: nil).x
        switch recognizer.state {
        case .began, .changed: report(.moved(moved))
        case .ended: report(.ended(moved, speed: recognizer.velocity(in: nil).x))
        case .cancelled, .failed: report(.ended(0, speed: 0))
        default: break
        }
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizerShouldBegin(_ recognizer: UIGestureRecognizer) -> Bool {
            guard let pan = recognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: nil)
            return abs(velocity.x) > abs(velocity.y) * 1.5
        }

        func gestureRecognizer(_ recognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            // Beside the list's own pan only: every other touch under the finger (a row's tap) is cancelled when the
            // drag takes over.
            return other is UIPanGestureRecognizer && other.view is UIScrollView
        }
    }
}

// MARK: - The tab bar

/// The tab bar: the four areas in one capsule of Liquid Glass and the search in a round one beside it, as the
/// system's bar has them. The selection is a lens of glass, as on the system's bar: touching the bar makes it swell
/// under the finger, it follows the finger from tab to tab, and on letting go it settles, small again, on the tab
/// chosen.
private struct GlassTabBar: View {
    let selected: AppTab
    let select: (AppTab) -> Void
    /// The tab under the finger while the bar is touched.
    @State private var touched: Int?
    @Environment(\.layoutDirection) private var direction

    private let areas: [AppTab] = [.typing, .look, .touch, .more]

    var body: some View {
        HStack(spacing: 10) {
            areaBar
                .padding(4)
                .glassShape(Capsule())
            Button {
                select(.search)
            } label: {
                Image(systemName: AppTab.search.symbol)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(selected == .search ? .accentColor : .primary)
                    .frame(width: 60, height: 60)
                    .glassShape(Circle(), interactive: true)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AppTab.search.title)
            .accessibilityAddTraits(selected == .search ? .isSelected : [])
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 2)
    }

    /// The place (left to right) of a tab on the bar.
    private func place(of index: Int) -> Int {
        return direction == .rightToLeft ? areas.count - 1 - index : index
    }

    private var areaBar: some View {
        let current = areas.firstIndex(of: selected)
        let lensAt = touched ?? current
        return GeometryReader { proxy in
            let slot = proxy.size.width / CGFloat(areas.count)
            ZStack {
                if let lensAt = lensAt {
                    lens
                        .frame(width: slot, height: proxy.size.height)
                        .scaleEffect(touched == nil ? 1 : 1.22)
                        .position(x: slot * (CGFloat(place(of: lensAt)) + 0.5), y: proxy.size.height / 2)
                }
                HStack(spacing: 0) {
                    ForEach(Array(areas.enumerated()), id: \.offset) { index, item in
                        label(item, on: index == lensAt)
                            .accessibilityElement(children: .combine)
                            .accessibilityAddTraits(item == selected ? [.isButton, .isSelected] : .isButton)
                            .accessibilityAction { select(item) }
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { value in touched = index(at: value.location.x, slot: slot) }
                .onEnded { value in
                    let index = index(at: value.location.x, slot: slot)
                    touched = nil
                    select(areas[index])
                })
            .animation(.spring(response: 0.36, dampingFraction: 0.74), value: touched)
            .animation(.spring(response: 0.36, dampingFraction: 0.78), value: selected)
        }
        .frame(height: 52)
    }

    private func index(at x: CGFloat, slot: CGFloat) -> Int {
        let place = min(areas.count - 1, max(0, Int(x / max(slot, 1))))
        return direction == .rightToLeft ? areas.count - 1 - place : place
    }

    private func label(_ item: AppTab, on: Bool) -> some View {
        VStack(spacing: 3) {
            Image(systemName: item.symbol)
                .font(.system(size: 19, weight: .medium))
                .frame(height: 24)
            Text(item.title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .foregroundColor(on ? .accentColor : .primary)
        .frame(maxWidth: .infinity)
    }

    /// The selection: a lens of Liquid Glass (a plain pill before iOS 26).
    @ViewBuilder private var lens: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            Color.clear.glassEffect(.regular, in: Capsule())
        } else {
            Capsule().fill(Color.primary.opacity(0.1))
        }
        #else
        Capsule().fill(Color.primary.opacity(0.1))
        #endif
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
                    .modifier(TabSwipeable())
                    .tabBarClearance()
                    .navigationDestination(for: Screen.self) { $0.scopedView }
            }
            .environment(\.openScreen, { screen in path.append(screen) })
        }
    }

    private var landscape: some View {
        HStack(spacing: 0) {
            NavigationStack { TabRoot(tab: tab).modifier(TabSwipeable()).tabBarClearance() }
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
    @Environment(\.tabSwiping) private var swiping

    init(_ screen: Screen, @ViewBuilder label: @escaping () -> Label) {
        self.screen = screen
        self.label = label
    }

    var body: some View {
        Button {
            // A tab swipe that began on the row doesn't open it.
            guard !swiping else { return }
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

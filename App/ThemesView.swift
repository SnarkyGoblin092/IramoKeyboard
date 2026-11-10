import SwiftUI

/// The theme picker: a big preview of the current theme, a way into its editor, and a grid of all themes.
struct ThemesView: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.systemEdits, store: SharedStore.defaults) private var systemEdits = SettingDefault.systemEdits
    /// The mode of the preview only ("auto": the app's own); the keyboard itself always follows the app it is in.
    @AppStorage(SettingKey.appearance, store: SharedStore.defaults) private var previewMode = SettingDefault.appearance
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openScreen) private var openScreen
    /// The waves of glass that carry the previews to the other mode (ModeWave), while they cross the screen.
    @State private var waves: [ModeWave] = []
    /// Where this screen is in the window: the wave crosses exactly it.
    @State private var screenFrame = CGRect.zero
    /// The mode just picked while its wave is setting off: the switch shows it in the picture of the window the wave
    /// wipes away, so it does not seem to jump back to the old one.
    @State private var pendingMode: String?
    /// Where the finger last touched the screen: the light / dark wave spreads out from there.
    @State private var touches = TouchPoint()

    /// Two cards across on a phone held upright, more where there is room (iPad, landscape).
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }
    private var selected: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }
    /// The mode every preview on this screen is drawn in: the toggle's, or the app's own until it is used.
    private var previewScheme: ColorScheme {
        return previewMode == "light" ? .light : (previewMode == "dark" ? .dark : colorScheme)
    }

    // The chosen theme stays pinned above the grid (PinnedPreview); drag the bar under it to make it smaller.
    var body: some View {
        PinnedPreview(height: 240, fills: true, edgeToEdge: true) {
            VStack(spacing: 8) {
                LiveKeyboard()
                SegmentedChoice(names: [tr("Auto"), tr("Light"), tr("Dark")],
                                selected: (pendingMode ?? previewMode) == "light" ? 1 : ((pendingMode ?? previewMode) == "dark" ? 2 : 0)) {
                    switchMode(["auto", "light", "dark"][$0])
                }
            }
        } content: {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                header

                grid
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
        }
        .environment(\.modeWaves, waves)
        .background(TouchRecorder(touches: touches))
        .background(GeometryReader { geometry in
            Color.clear
                .onAppear { screenFrame = geometry.frame(in: .global) }
                .onChange(of: geometry.frame(in: .global)) { screenFrame = $0 }
        })
        .overlay {
            // Nothing on the screen can be touched while a wave is out.
            if !waves.isEmpty { Color.clear.contentShape(Rectangle()).onTapGesture {}.gesture(DragGesture()) }
        }
        .overlay {
            if !waves.isEmpty { GlassWaveBand(waves: waves) }
        }
        .onAppear { prewarm() }
        .navigationTitle(tr("Themes"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The chosen theme's name and what it is, and the way into its editor.
    private var header: some View {
        VStack(spacing: 10) {
            layered { theme in
                VStack(spacing: 2) {
                    HStack(spacing: 8) {
                        Text(theme.name).font(.title3.weight(.semibold))
                        if theme.isEdited {
                            StatusChip(text: tr("Edited"), symbol: "slider.horizontal.3", color: accent)
                        }
                    }
                    Text(theme.summaryValue.map { tr(theme.summary, $0) } ?? tr(theme.summary))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            Button {
                Feedback.tap()
                openScreen(.themeEditor)
            } label: {
                layered { theme in
                    Label(tr("Customize %@", "\(theme.name)"), systemImage: "paintbrush.pointed.fill")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 46)
                        .foregroundColor(.white)
                }
                .glassTile(Capsule(), isOn: true)
                .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    /// `content` for the chosen theme; while a wave crosses, the old theme's at the bottom and each wave's new
    /// theme's over it inside that wave's circle, as the previews are.
    @ViewBuilder private func layered<Content: View>(@ViewBuilder _ content: @escaping (ThemeDefinition) -> Content) -> some View {
        if let first = waves.first {
            let edits = SystemEdits.decode(systemEdits)
            ZStack {
                content(edited(ThemeCatalog.theme(id: first.oldTheme), edits)).hiddenByWave(first)
                ForEach(waves) { wave in
                    content(edited(ThemeCatalog.theme(id: wave.newTheme), edits)).revealedByWave(wave)
                }
            }
        } else {
            content(selected)
        }
    }

    /// Switches the previews to the other mode behind a wave of glass (at once with Reduce Motion, where the
    /// previews fade instead).
    private func switchMode(_ mode: String) {
        guard waves.isEmpty, pendingMode == nil, mode != previewMode else { return }
        // Auto follows the system's mode (the screen's traits, which the app's own override does not touch).
        let dark = mode == "auto" ? UIScreen.main.traitCollection.userInterfaceStyle == .dark : mode == "dark"
        guard (previewScheme == .dark) != dark, screenFrame.width > 0, !UIAccessibility.isReduceMotionEnabled else {
            previewMode = mode
            return
        }
        // The switch is drawn with its new choice first, then (once it has settled) the picture of the window is taken and the mode changes.
        pendingMode = mode
        let source = touches.point ?? CGPoint(x: screenFrame.midX, y: screenFrame.midY)
        // Once the switch has played its little slide to the new choice.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            launch(source: source, newScheme: dark ? .dark : .light, newTheme: themeID)
            previewMode = mode
            pendingMode = nil
        }
    }

    /// Switches to the theme `id` behind the same wave of glass, spreading out from the tap (at once with Reduce
    /// Motion).
    private func chooseTheme(_ id: String) {
        guard waves.isEmpty else { return }
        if screenFrame.width > 0, !UIAccessibility.isReduceMotionEnabled {
            launch(source: touches.point ?? CGPoint(x: screenFrame.midX, y: screenFrame.midY), newScheme: previewScheme, newTheme: id)
        }
        themeID = id
    }

    /// Starts a wave across `frame` (before the setting itself changes: what that sets going, the keyboard's
    /// rebuild and the cards' new pictures, looks for the wave) and takes it away when it is done.
    private func launch(source: CGPoint, newScheme: ColorScheme, newTheme: String) {
        let frame = screenFrame
        ModeWave.count += 1
        let id = ModeWave.count
        let new = ModeWave(id: id, oldScheme: previewScheme, newScheme: newScheme, oldTheme: themeID,
                           newTheme: newTheme, source: source, minX: frame.minX, minY: frame.minY,
                           width: frame.width, height: frame.height, started: CACurrentMediaTime(), startedDate: Date())
        // The keyboard's picture of itself is taken now, before the setting changes anything on it.
        LiveKeyboardView.current?.cover(for: new)
        // The whole app changes mode with the previews: a picture of the window is wiped away by the same wave.
        if newScheme != previewScheme { WindowWaveCover.start(for: new) }
        ModeWave.running.append(new)
        waves.append(new)
        // Nothing is updated while it crosses: everything that draws it reads the clock (ModeWave.progress).
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(new.lifetime * 1_000_000_000))
            waves.removeAll { $0.id == id }
            ModeWave.running.removeAll { $0.id == id }
        }
    }

    /// Every theme's light and dark picture, drawn ahead (one by one, when nothing else is wanted), so cards and
    /// the light / dark switch never wait for one.
    private func prewarm() {
        let edits = SystemEdits.decode(systemEdits)
        let scale = UIScreen.main.scale
        for section in ThemeCatalog.pickerSections {
            for base in section.themes {
                let theme = edited(base, edits)
                for dark in [previewScheme == .dark, previewScheme != .dark] {
                    let key = ThemeThumbnail.key(theme: theme, dark: dark)
                    guard ThumbnailCache.shared.image(for: key) == nil else { continue }
                    ThemeThumbnail.enqueue(theme: theme, accent: accent, scale: scale, dark: dark, key: key, idle: true) { _ in }
                }
            }
        }
    }

    /// The picker's sections (ThemeCatalog.pickerSections) in one lazy grid: only the cards in view are built.
    private var grid: some View {
        let edits = SystemEdits.decode(systemEdits)
        let modeWaves = waves
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            ForEach(ThemeCatalog.pickerSections, id: \.title) { section in
                Section {
                    ForEach(section.themes, id: \.id) { base in
                        let theme = edited(base, edits)
                        ThemeCard(theme: theme, accent: accent, scheme: previewScheme, isSelected: theme.id == themeID) {
                            guard theme.id != themeID else { return }
                            Feedback.choose()
                            chooseTheme(theme.id)
                        }
                        // Each card on its own, not the grid: only the cards the front is near are drawn through
                        // the shader. (Not the header: its toggles are views the system draws, which it cannot reach.)
                        .waveLensed(modeWaves)
                    }
                } header: {
                    HStack(spacing: 10) {
                        Text(tr(section.title)).font(.title3.weight(.semibold)).foregroundColor(.secondary)
                        Rectangle().fill(Color.primary.opacity(0.12)).frame(height: 1)
                        Text("\(section.themes.count)").font(.subheadline).foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
            }
        }
    }

    /// The theme with its stored edits (as ThemeCatalog.themes, from edits decoded once for the grid).
    private func edited(_ base: ThemeDefinition, _ edits: [String: SystemStyle]) -> ThemeDefinition {
        guard let style = edits[base.id] else { return base }
        var theme = base
        theme.systemStyle = style
        theme.isEdited = true
        return theme
    }
}

/// The whole card (preview, name, spacing around them) is one button.
private struct ThemeCard: View {
    let theme: ThemeDefinition
    let accent: Color
    /// Light or dark, for the miniature keyboard only (the card's name follows the app).
    let scheme: ColorScheme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ThemeThumbnail(theme: theme, accent: accent)
                    .environment(\.colorScheme, scheme)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? accent : Color.primary.opacity(0.12),
                                    lineWidth: isSelected ? 3 : 1))
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(accent)
                                .background(Circle().fill(Color.white).padding(3))
                                .padding(6)
                        }
                    }
                    // The shadow of a plain card shape, not of the whole miniature keyboard (far cheaper to draw).
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black)
                            .shadow(color: Color.black.opacity(0.14), radius: 6, x: 0, y: 3))
                HStack(spacing: 4) {
                    Text(theme.name)
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    if theme.isEdited {
                        Image(systemName: "slider.horizontal.3")
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                            .accessibilityLabel(tr("Edited"))
                    }
                }
            }
            .padding(4)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(theme.isEdited ? tr("%@, edited", "\(theme.name)") : theme.name)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A card's miniature keyboard as a picture, drawn once when the card first comes into view and kept
/// (ThumbnailCache) until the theme, the look settings or light/dark mode change. Liquid Glass is a live system
/// material that can't be drawn into a picture, so its card is a picture of a flat glass look (staticGlass).
@MainActor
private struct ThemeThumbnail: View {
    let theme: ThemeDefinition
    let accent: Color
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale
    @Environment(\.modeWaves) private var allWaves
    @State private var image: UIImage?
    /// The picture shown before `image`, kept under it while the new one fades in (an edit).
    @State private var previous: UIImage?
    @State private var fade: Double = 1
    @State private var shownKey = ""
    @State private var wantedKey = ""
    /// Counts the pictures of the other mode that arrive while a wave crosses, to draw them.
    @State private var arrived = 0

    /// The width the picture is drawn at (about a card's width); it is scaled to the card.
    private static let renderWidth: CGFloat = 200

    /// The light / dark waves (the theme waves are the main preview's).
    private var waves: [ModeWave] { return allWaves }

    var body: some View {
        Group {
            if !waves.isEmpty {
                // The first wave's old look at the bottom, each wave's new look over it inside that wave's circle.
                ZStack {
                    layer(dark: waves[0].oldScheme == .dark)
                    ForEach(waves) { wave in
                        layer(dark: wave.newScheme == .dark).revealedByWave(wave)
                    }
                }
            } else if let image = image {
                ZStack {
                    if let previous = previous {
                        Image(uiImage: previous).resizable().interpolation(.high)
                    }
                    Image(uiImage: image).resizable().interpolation(.high).opacity(fade)
                }
            } else {
                placeholder(dark: scheme == .dark)
            }
        }
        .aspectRatio(ThemePreview.aspectKeysOnly, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        // The other mode's picture is drawn too, when nothing else is to be: a wave then has both ready, and none
        // is drawn while it crosses (each takes the main thread, and the wave's frames with it).
        .onAppear {
            load(theme: theme, dark: scheme == .dark)
            prepare(theme: theme, dark: scheme != .dark, idle: true)
        }
        // onChange's closure sees the view as it was before the change, so the new value is passed in rather
        // than read from `scheme` / `theme` (which would still be the old ones and draw the wrong look).
        .onChange(of: scheme) { newScheme in load(theme: theme, dark: newScheme == .dark) }
        .onChange(of: theme) { newTheme in
            load(theme: newTheme, dark: scheme == .dark)
            prepare(theme: newTheme, dark: scheme != .dark, idle: true)
        }
        // A wave shows both modes at once: the other one's picture is made too.
        .onChange(of: waves.count) { count in
            guard count > 0 else { return }
            prepare(theme: theme, dark: true)
            prepare(theme: theme, dark: false)
        }
    }

    static let fadeAnimation = Animation.easeInOut(duration: 0.3)

    /// The card in one mode, for the wave's layers.
    @ViewBuilder private func layer(dark: Bool) -> some View {
        if let picture = picture(dark: dark) {
            Image(uiImage: picture).resizable().interpolation(.high)
        } else {
            placeholder(dark: dark)
        }
    }

    private func picture(dark: Bool) -> UIImage? {
        _ = arrived
        if let cached = ThumbnailCache.shared.image(for: ThemeThumbnail.key(theme: theme, dark: dark)) { return cached }
        return image
    }

    /// Until it is drawn: the keyboard's backdrop.
    private func placeholder(dark: Bool) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(dark ? Color(white: 0.17) : Color(red: 0.82, green: 0.84, blue: 0.86))
    }

    /// Shows `new`: at once on a card that has no picture yet (it has just scrolled into view) or while a wave
    /// crosses (the wave shows the change); over the picture it replaces otherwise, faded in.
    private func show(_ new: UIImage?, key: String) {
        guard let new = new else { return }
        let replaces = image != nil && shownKey != key && ModeWave.running.isEmpty
        previous = replaces ? image : nil
        image = new
        shownKey = key
        guard replaces else {
            fade = 1
            return
        }
        // Drawn clear once, over the old picture, then faded in (set to 1 in this same update it would not fade).
        fade = 0
        Task { @MainActor in
            withAnimation(ThemeThumbnail.fadeAnimation) { fade = 1 }
        }
    }

    /// What the picture depends on: the theme with its edits, light or dark, and every setting the preview reads.
    fileprivate static func key(theme: ThemeDefinition, dark: Bool) -> String {
        // Nothing here may change from one launch to the next without the picture being out of date (hashValue does:
        // it is seeded anew each run, so pictures saved on disk would never be found again).
        let style = theme.systemStyle.flatMap { try? ThumbnailCache.encoder.encode($0) }.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        return "\(ThumbnailCache.version)|\(theme.id)|\(style)|\(dark)|\(ThumbnailCache.settingsSignature())"
    }

    /// Queues the picture for `key` (drawn once, then kept in the cache, on disk too).
    private func queue(theme: ThemeDefinition, dark: Bool, key: String, idle: Bool = false,
                       done: @escaping (UIImage?) -> Void) {
        ThemeThumbnail.enqueue(theme: theme, accent: accent, scale: displayScale, dark: dark, key: key, idle: idle, done: done)
    }

    /// The picture of a theme in one mode. Liquid Glass is drawn as the real glass keyboard (GlassSnapshot) and
    /// photographed; the other themes go through ImageRenderer.
    fileprivate static func enqueue(theme: ThemeDefinition, accent: Color, scale: CGFloat, dark: Bool, key: String,
                                    idle: Bool, done: @escaping (UIImage?) -> Void) {
        let width = ThemeThumbnail.renderWidth
        let size = CGSize(width: width, height: width / ThemePreview.aspectKeysOnly)
        func preview() -> some View {
            return ThemePreview(theme: theme, accent: accent, showsStrip: false, cornerRadius: 14)
                .frame(width: size.width, height: size.height)
                .environment(\.colorScheme, dark ? .dark : .light)
        }
        ThumbnailCache.shared.render(key: key, idle: idle) {
            if theme.kind == .liquidGlass,
               let shot = await GlassSnapshot.take(AnyView(preview()), size: size, dark: dark, scale: scale,
                                                   backdrop: ThemePreviewBackdrop.color(theme: theme, dark: dark)) {
                return shot
            }
            let renderer = ImageRenderer(content: preview().environment(\.staticGlass, true))
            renderer.scale = scale
            return renderer.uiImage
        } done: { rendered in
            done(rendered)
        }
    }

    /// Draws the picture for `dark` ahead of the wave that needs it (`idle`: after everything that is wanted now).
    private func prepare(theme: ThemeDefinition, dark: Bool, idle: Bool = false) {
        let key = ThemeThumbnail.key(theme: theme, dark: dark)
        guard ThumbnailCache.shared.image(for: key) == nil else { return }
        queue(theme: theme, dark: dark, key: key, idle: idle) { _ in arrived += 1 }
    }

    private func load(theme: ThemeDefinition, dark: Bool) {
        let key = ThemeThumbnail.key(theme: theme, dark: dark)
        wantedKey = key
        guard key != shownKey || image == nil else { return }
        if let cached = ThumbnailCache.shared.image(for: key) {
            show(cached, key: key)
            return
        }
        queue(theme: theme, dark: dark, key: key) { rendered in
            // iOS flips light/dark briefly while taking app-switcher snapshots; a picture queued for the
            // flipped look may finish after the card has switched back, so drop it unless it is still wanted.
            guard wantedKey == key else { return }
            show(rendered, key: key)
        }
    }
}

/// The theme cards' pictures, and a queue that draws them one per run-loop turn so that a screenful of new cards
/// never stalls a scroll.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys   // the same text on every run
        return encoder
    }()
    /// Part of every key: a new build (new themes, a changed look) draws its pictures afresh.
    static let version = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") + "." +
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")

    private let images = NSCache<NSString, UIImage>()
    private var queue: [(key: String, make: () async -> UIImage?, done: (UIImage?) -> Void)] = []
    /// The pictures nothing shows yet (the other mode's, for the next wave): drawn when `queue` is empty.
    private var idle: [(key: String, make: () async -> UIImage?, done: (UIImage?) -> Void)] = []
    private var draining = false

    init() {
        images.countLimit = 160
    }

    /// The picture in memory, else the one kept on disk from an earlier run (a theme is drawn once, ever, until
    /// what it depends on changes: the key holds all of that).
    func image(for key: String) -> UIImage? {
        if let image = images.object(forKey: key as NSString) { return image }
        guard let url = diskURL(key), let data = try? Data(contentsOf: url),
              let image = UIImage(data: data, scale: UIScreen.main.scale) else { return nil }
        images.setObject(image, forKey: key as NSString)
        return image
    }

    func store(_ image: UIImage, key: String) {
        images.setObject(image, forKey: key as NSString)
        if let url = diskURL(key), let data = image.pngData() { try? data.write(to: url, options: .atomic) }
    }

    private lazy var directory: URL? = {
        guard let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let url = base.appendingPathComponent("ThemeCards", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }()

    /// A file name that is the same on every run (String.hashValue is not).
    private func diskURL(_ key: String) -> URL? {
        var hash: UInt64 = 5381
        for byte in key.utf8 { hash = hash &* 33 &+ UInt64(byte) }
        return directory?.appendingPathComponent(String(hash, radix: 16) + ".png")
    }

    func render(key: String, idle: Bool = false, make: @escaping () async -> UIImage?, done: @escaping (UIImage?) -> Void) {
        if idle { self.idle.append((key, make, done)) } else { queue.append((key, make, done)) }
        drain()
    }

    private func drain() {
        guard !draining, !(queue.isEmpty && idle.isEmpty) else { return }
        draining = true
        Task { @MainActor in
            await Task.yield()   // let the scroll draw a frame between pictures
            // The idle ones are spaced out (a scroll stays smooth), and wait for a wave to end.
            if self.queue.isEmpty {
                repeat {
                    try? await Task.sleep(nanoseconds: 150_000_000)
                } while self.queue.isEmpty && !ModeWave.running.isEmpty
            }
            let job = self.queue.isEmpty ? self.idle.removeFirst() : self.queue.removeFirst()
            let made = await job.make()
            let image = self.image(for: job.key) ?? made
            if let image = image, self.image(for: job.key) == nil { self.store(image, key: job.key) }
            job.done(image)
            self.draining = false
            self.drain()
        }
    }

    /// Every setting the previews draw with (ThemePreview's), so a change made on another screen redraws them.
    static func settingsSignature() -> String {
        let keys = [SettingKey.keyRoundness, SettingKey.keySurface, SettingKey.keyBorderStyle, SettingKey.keyGlow,
                    SettingKey.keyHints, SettingKey.keyGap, SettingKey.rowGap, SettingKey.keyHeight, SettingKey.keyboardWidth,
                    SettingKey.splitKeyboard, SettingKey.oneHanded, SettingKey.letterSize, SettingKey.hintPosition,
                    SettingKey.hintSize, SettingKey.spaceTextSize, SettingKey.spaceLanguageCode,
                    SettingKey.numberRow, SettingKey.autoCapitalize, SettingKey.alwaysCapitals, SettingKey.keyFont,
                    SettingKey.accent, SettingKey.accentHex, SettingKey.enabledLanguages, SettingKey.language]
        let defaults = SharedStore.defaults
        return keys.map { "\(defaults.object(forKey: $0) ?? "")" }.joined(separator: "|")
    }
}

/// The keyboard's backdrop colour (ThemeLook.backdrop) for a snapshot to sit on, as a UIColor.
enum ThemePreviewBackdrop {
    static func color(theme: ThemeDefinition, dark: Bool) -> UIColor {
        if theme.kind == .transparent { return dark ? UIColor(white: 0.12, alpha: 1) : UIColor(white: 0.93, alpha: 1) }
        return dark ? UIColor(white: 0.17, alpha: 1) : UIColor(red: 0.82, green: 0.84, blue: 0.86, alpha: 1)
    }
}

/// Takes a picture of a view with real Liquid Glass in it: the view is put, on its backdrop, in the key window just
/// off the screen (where the glass is drawn as on a real keyboard) and photographed once. One at a time.
@MainActor
enum GlassSnapshot {
    private static var busy = false
    private static var waiters: [CheckedContinuation<Void, Never>] = []

    static func take(_ content: AnyView, size: CGSize, dark: Bool, scale: CGFloat, backdrop: UIColor) async -> UIImage? {
        if busy {
            await withCheckedContinuation { waiters.append($0) }
        } else {
            busy = true
        }
        defer { if waiters.isEmpty { busy = false } else { waiters.removeFirst().resume() } }
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap { $0.windows }
        guard let window = windows.first(where: { $0.isKeyWindow }) ?? windows.first else { return nil }
        let container = UIView(frame: CGRect(x: window.bounds.maxX + 40, y: 0, width: size.width, height: size.height))
        container.backgroundColor = backdrop
        container.overrideUserInterfaceStyle = dark ? .dark : .light
        let host = UIHostingController(rootView: AnyView(content.ignoresSafeArea()))
        host.view.backgroundColor = .clear
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        host.view.frame = container.bounds
        container.addSubview(host.view)
        window.addSubview(container)
        window.rootViewController?.addChild(host)
        host.didMove(toParent: window.rootViewController)
        defer {
            host.willMove(toParent: nil)
            host.removeFromParent()
            container.removeFromSuperview()
        }
        container.layoutIfNeeded()
        // Long enough for the glass to be laid out and drawn.
        try? await Task.sleep(nanoseconds: 350_000_000)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            container.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
}

/// The last place the screen was touched (written as touches begin, read when a wave is launched; not state, so
/// touching redraws nothing).
final class TouchPoint {
    var point: CGPoint?
}

/// Records where each touch lands, in the window, the moment it lands (before any button's action runs, which a
/// SwiftUI gesture does not manage). It fails at once, so it never takes a touch from anything.
private struct TouchRecorder: UIViewRepresentable {
    let touches: TouchPoint

    func makeUIView(context: Context) -> RecorderView { return RecorderView(touches: touches) }
    func updateUIView(_ view: RecorderView, context: Context) {}

    final class RecorderView: UIView {
        let touches: TouchPoint
        private var recorder: Recorder?

        init(touches: TouchPoint) {
            self.touches = touches
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if let recorder = recorder { recorder.view?.removeGestureRecognizer(recorder) }
            recorder = nil
            guard let window = window else { return }
            let new = Recorder(touches: touches)
            window.addGestureRecognizer(new)
            recorder = new
        }
    }

    final class Recorder: UIGestureRecognizer {
        let touches: TouchPoint

        init(touches: TouchPoint) {
            self.touches = touches
            super.init(target: nil, action: nil)
            cancelsTouchesInView = false
            delaysTouchesBegan = false
            delaysTouchesEnded = false
        }

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if let touch = touches.first { self.touches.point = touch.location(in: nil) }
            state = .failed
        }
    }
}

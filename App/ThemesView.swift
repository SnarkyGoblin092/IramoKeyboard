import SwiftUI

/// The theme picker: a big preview of the current theme, a way into its editor, and a grid of all themes.
struct ThemesView: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme
    @AppStorage(SettingKey.accent, store: SharedStore.defaults) private var accentName = SettingDefault.accent
    @AppStorage(SettingKey.accentHex, store: SharedStore.defaults) private var accentHex = SettingDefault.accentHex
    @AppStorage(SettingKey.systemEdits, store: SharedStore.defaults) private var systemEdits = SettingDefault.systemEdits
    @Environment(\.openScreen) private var openScreen

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var accent: Color { return Color.currentAccent(name: accentName, hex: accentHex) }
    private var selected: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    // The chosen theme stays pinned above the grid (PinnedPreview); drag the bar under it to make it smaller.
    var body: some View {
        PinnedPreview(height: 240, fills: true) {
            LiveKeyboard()
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
        .navigationTitle(tr("Themes"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// The chosen theme's name and what it is, and the way into its editor.
    private var header: some View {
        VStack(spacing: 10) {
            VStack(spacing: 2) {
                HStack(spacing: 8) {
                    Text(selected.name).font(.title3.weight(.semibold))
                    if selected.isEdited {
                        StatusChip(text: tr("Edited"), symbol: "slider.horizontal.3", color: accent)
                    }
                }
                Text(tr(selected.summary))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                Feedback.tap()
                openScreen(.themeEditor)
            } label: {
                Label(tr("Customize %@", "\(selected.name)"), systemImage: "paintbrush.pointed.fill")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .foregroundColor(.white)
                    .glassTile(Capsule(), isOn: true)
                    .contentShape(Capsule())
            }
            .buttonStyle(PressableStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    /// The picker's sections (ThemeCatalog.pickerSections) in one lazy grid: only the cards in view are built.
    private var grid: some View {
        let edits = SystemEdits.decode(systemEdits)
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 18) {
            ForEach(ThemeCatalog.pickerSections, id: \.title) { section in
                Section {
                    ForEach(section.themes, id: \.id) { base in
                        let theme = edited(base, edits)
                        ThemeCard(theme: theme, accent: accent, isSelected: theme.id == themeID) {
                            guard theme.id != themeID else { return }
                            Feedback.choose()
                            themeID = theme.id
                        }
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
    let isSelected: Bool
    let action: () -> Void


    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ThemeThumbnail(theme: theme, accent: accent)
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
/// material that can't be drawn into a picture, so that card stays live.
@MainActor
private struct ThemeThumbnail: View {
    let theme: ThemeDefinition
    let accent: Color
    @Environment(\.colorScheme) private var scheme
    @Environment(\.displayScale) private var displayScale
    @State private var image: UIImage?
    @State private var shownKey = ""
    @State private var wantedKey = ""

    /// The width the picture is drawn at (about a card's width); it is scaled to the card.
    private static let renderWidth: CGFloat = 200

    var body: some View {
        Group {
            if theme.kind == .liquidGlass {
                ThemePreview(theme: theme, accent: accent, showsStrip: false, cornerRadius: 14)
            } else if let image = image {
                Image(uiImage: image).resizable().interpolation(.high)
            } else {
                // Until it is drawn: the keyboard's backdrop.
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(scheme == .dark ? Color(white: 0.17) : Color(red: 0.82, green: 0.84, blue: 0.86))
            }
        }
        .aspectRatio(ThemePreview.aspectKeysOnly, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onAppear { load(theme: theme, dark: scheme == .dark) }
        // onChange's closure sees the view as it was before the change, so the new value is passed in rather
        // than read from `scheme` / `theme` (which would still be the old ones and draw the wrong look).
        .onChange(of: scheme) { newScheme in load(theme: theme, dark: newScheme == .dark) }
        .onChange(of: theme) { newTheme in load(theme: newTheme, dark: scheme == .dark) }
    }

    /// What the picture depends on: the theme with its edits, light or dark, and every setting the preview reads.
    private static func key(theme: ThemeDefinition, dark: Bool) -> String {
        return "\(theme.id)|\(theme.hashValue)|\(dark)|\(ThumbnailCache.settingsSignature())"
    }

    private func load(theme: ThemeDefinition, dark: Bool) {
        guard theme.kind != .liquidGlass else { return }
        let key = ThemeThumbnail.key(theme: theme, dark: dark)
        wantedKey = key
        guard key != shownKey || image == nil else { return }
        if let cached = ThumbnailCache.shared.image(for: key) {
            image = cached
            shownKey = key
            return
        }
        let accent = self.accent, scale = displayScale
        ThumbnailCache.shared.render(key: key) {
            let width = ThemeThumbnail.renderWidth
            let preview = ThemePreview(theme: theme, accent: accent, showsStrip: false, cornerRadius: 14)
                .frame(width: width, height: width / ThemePreview.aspectKeysOnly)
                .environment(\.colorScheme, dark ? .dark : .light)
            let renderer = ImageRenderer(content: preview)
            renderer.scale = scale
            return renderer.uiImage
        } done: { rendered in
            // iOS flips light/dark briefly while taking app-switcher snapshots; a picture queued for the
            // flipped look may finish after the card has switched back, so drop it unless it is still wanted.
            guard wantedKey == key else { return }
            image = rendered
            shownKey = key
        }
    }
}

/// The theme cards' pictures, and a queue that draws them one per run-loop turn so that a screenful of new cards
/// never stalls a scroll.
@MainActor
final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let images = NSCache<NSString, UIImage>()
    private var queue: [(key: String, make: () -> UIImage?, done: (UIImage?) -> Void)] = []
    private var draining = false

    init() {
        images.countLimit = 120
    }

    func image(for key: String) -> UIImage? { return images.object(forKey: key as NSString) }

    func render(key: String, make: @escaping () -> UIImage?, done: @escaping (UIImage?) -> Void) {
        queue.append((key, make, done))
        drain()
    }

    private func drain() {
        guard !draining, !queue.isEmpty else { return }
        draining = true
        Task { @MainActor in
            await Task.yield()   // let the scroll draw a frame between pictures
            let job = self.queue.removeFirst()
            let image = self.image(for: job.key) ?? job.make()
            if let image = image { self.images.setObject(image, forKey: job.key as NSString) }
            job.done(image)
            self.draining = false
            self.drain()
        }
    }

    /// Every setting the previews draw with (ThemePreview's), so a change made on another screen redraws them.
    static func settingsSignature() -> String {
        let keys = [SettingKey.keyRoundness, SettingKey.keySurface, SettingKey.keyBorderStyle, SettingKey.keyGlow,
                    SettingKey.keyHints, SettingKey.keyGap, SettingKey.rowGap, SettingKey.keyboardWidth,
                    SettingKey.splitKeyboard, SettingKey.oneHanded, SettingKey.letterSize, SettingKey.hintPosition,
                    SettingKey.hintSize, SettingKey.spaceTextSize, SettingKey.spaceLanguageCode,
                    SettingKey.numberRow, SettingKey.autoCapitalize, SettingKey.alwaysCapitals, SettingKey.keyFont,
                    SettingKey.accent, SettingKey.accentHex, SettingKey.enabledLanguages, SettingKey.language]
        let defaults = SharedStore.defaults
        return keys.map { "\(defaults.object(forKey: $0) ?? "")" }.joined(separator: "|")
    }
}

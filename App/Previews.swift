import SwiftUI

// MARK: - Live previews for the settings screens
//
// Each screen opens with a small picture of the keyboard that shows what its settings do: the suggestion bar as
// it will look, a swipe being drawn the way the gestures are set, the keys' touch areas, the vibration's feel.
// They read the same stored settings as the controls below them, so they change as the controls do.

/// A card around a preview, with a caption under it. The card is the chosen theme's keyboard background (the
/// keys inside are drawn with the theme too, through ThemeLook), so every preview looks like the user's keyboard.
struct PreviewCard<Content: View>: View {
    let caption: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        CurrentThemeLook { look in
            VStack(spacing: 10) {
                content()
                    .padding(10)
                    .background(look.backdrop())
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    // The keyboard is laid out left to right, also when the app reads right to left.
                    .environment(\.layoutDirection, .leftToRight)
                Text(caption)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .animation(nil, value: caption)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Pinned preview

/// A settings screen with its preview pinned at the top: the preview stays in view while the settings below it
/// scroll. A card preview keeps its natural height (caption included); the keyboard, which sizes itself to the
/// pane, gets the height it starts at (or, with `aspect`, the height that keeps that width : height ratio).
struct PinnedPreview<Preview: View, Content: View>: View {
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let content: () -> Content
    /// The preview sizes itself to the pane (the keyboard) instead of keeping its own height.
    let fills: Bool
    /// The preview's width over its height: the pane is as tall as that ratio makes it at the full width.
    let aspect: CGFloat?
    /// The height the pane has.
    let startHeight: CGFloat
    /// The scrolling content runs down to the screen's bottom edge, under the home indicator.
    let edgeToEdge: Bool

    /// The card preview's own height, measured (0 until it has been laid out once).
    @State private var naturalHeight: CGFloat = 0

    private static var topPadding: CGFloat { return 12 }
    private static var bottomPadding: CGFloat { return 6 }
    /// The keyboard preview's smallest pane.
    private static var keyboardMinimum: CGFloat { return 150 }

    /// `height` is the pane's height (`fills` panes only; a card preview keeps its own).
    init(height: CGFloat, fills: Bool = false, aspect: CGFloat? = nil, edgeToEdge: Bool = false,
         @ViewBuilder preview: @escaping () -> Preview,
         @ViewBuilder content: @escaping () -> Content) {
        self.edgeToEdge = edgeToEdge
        self.preview = preview
        self.content = content
        self.fills = fills
        self.aspect = aspect
        self.startHeight = height
    }

    /// The smallest pane that still shows the whole preview.
    private var minimum: CGFloat {
        if fills { return PinnedPreview.keyboardMinimum }
        let content = naturalHeight > 0 ? naturalHeight : 90
        return content + PinnedPreview.topPadding + PinnedPreview.bottomPadding
    }

    /// The pane's height: the one it starts at, or what `aspect` makes of the full width.
    private func wantedHeight(width: CGFloat) -> CGFloat {
        guard let aspect = aspect, aspect > 0 else { return startHeight }
        return (width - 32) / aspect + PinnedPreview.topPadding + PinnedPreview.bottomPadding
    }

    var body: some View {
        GeometryReader { geometry in
            let wanted = wantedHeight(width: geometry.size.width)
            let maximum = max(minimum, min(wanted, geometry.size.height * 0.62))
            let height = fills ? maximum : minimum
            VStack(spacing: 0) {
                Group {
                    if fills {
                        // A keyboard is laid out left to right, also when the app reads
                        // right to left.
                        preview().frame(maxWidth: .infinity, maxHeight: .infinity)
                            .environment(\.layoutDirection, .leftToRight)
                    } else {
                        // At its own height (measured for the minimum), centred in a taller pane.
                        preview()
                            .fixedSize(horizontal: false, vertical: true)
                            .background(GeometryReader { inner in
                                Color.clear.preference(key: NaturalHeightKey.self, value: inner.size.height)
                            })
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, PinnedPreview.topPadding)
                .padding(.bottom, PinnedPreview.bottomPadding)
                .frame(height: height)
                .clipped()
                .zIndex(1)
                Divider().opacity(0.6)
                // The list scrolls under the preview, never over it (also while a menu is still closing).
                content()
                    .frame(maxHeight: .infinity)
                    .clipped()
            }
        }
        .ignoresSafeArea(edges: edgeToEdge ? .bottom : [])
        .background(GlassBackdrop())
        .onPreferenceChange(NaturalHeightKey.self) { value in
            if abs(value - naturalHeight) > 0.5 { naturalHeight = value }
        }
    }
}

private struct NaturalHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

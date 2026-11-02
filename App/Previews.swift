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
/// pane, gets the height it starts at. Only a `resizable` pane (the theme picker's) has a bar under it that drags
/// to make it smaller and back (remembered per screen), never past the height it starts at nor below a size where
/// the keyboard stays readable.
struct PinnedPreview<Preview: View, Content: View>: View {
    @ViewBuilder let preview: () -> Preview
    @ViewBuilder let content: () -> Content
    /// The preview sizes itself to the pane (the keyboard) instead of keeping its own height.
    let fills: Bool
    let resizable: Bool
    /// The height the pane starts at, and a resizable pane's largest.
    let startHeight: CGFloat

    @AppStorage private var storedHeight: Double
    @State private var dragStartHeight: CGFloat?
    @State private var liveHeight: CGFloat?
    /// The card preview's own height, measured (0 until it has been laid out once).
    @State private var naturalHeight: CGFloat = 0

    private static var topPadding: CGFloat { return 12 }
    private static var bottomPadding: CGFloat { return 6 }
    /// The keyboard preview's smallest pane.
    private static var keyboardMinimum: CGFloat { return 150 }

    /// `id` names the screen (its height is remembered under it); `height` is where it starts.
    init(id: String, height: CGFloat, fills: Bool = false, resizable: Bool = false,
         @ViewBuilder preview: @escaping () -> Preview,
         @ViewBuilder content: @escaping () -> Content) {
        self.preview = preview
        self.content = content
        self.fills = fills
        self.resizable = resizable
        self.startHeight = height
        _storedHeight = AppStorage(wrappedValue: Double(height), "previewHeight." + id)
    }

    /// The smallest pane that still shows the whole preview.
    private var minimum: CGFloat {
        if fills { return PinnedPreview.keyboardMinimum }
        let content = naturalHeight > 0 ? naturalHeight : 90
        return content + PinnedPreview.topPadding + PinnedPreview.bottomPadding
    }

    private func clamped(_ height: CGFloat, maximum: CGFloat) -> CGFloat {
        return min(max(height, minimum), maximum)
    }

    var body: some View {
        GeometryReader { geometry in
            let maximum = max(minimum, min(startHeight, geometry.size.height * 0.62))
            let height = resizable ? clamped(liveHeight ?? CGFloat(storedHeight), maximum: maximum)
                : (fills ? maximum : minimum)
            VStack(spacing: 0) {
                Group {
                    if fills {
                        // A keyboard (or the emoji picker) is laid out left to right, also when the app reads
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
                if resizable {
                    handle(height: height, maximum: maximum)
                } else {
                    Divider().opacity(0.6)
                }
                // The list scrolls under the preview, never over it (also while a menu is still closing).
                content()
                    .frame(maxHeight: .infinity)
                    .clipped()
            }
        }
        .background(GlassBackdrop())
        .onPreferenceChange(NaturalHeightKey.self) { value in
            if abs(value - naturalHeight) > 0.5 { naturalHeight = value }
        }
    }

    /// The grip under the preview: drag it to resize (never below what the preview needs).
    private func handle(height: CGFloat, maximum: CGFloat) -> some View {
        Capsule()
            .fill(Color.secondary.opacity(0.45))
            .frame(width: 40, height: 5)
            .frame(maxWidth: .infinity, minHeight: 26)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { value in
                    if dragStartHeight == nil { dragStartHeight = height }
                    liveHeight = clamped((dragStartHeight ?? height) + value.translation.height, maximum: maximum)
                }
                .onEnded { _ in
                    if let final = liveHeight { storedHeight = Double(final) }
                    liveHeight = nil
                    dragStartHeight = nil
                    Feedback.tick()
                })
            .overlay(alignment: .bottom) { Divider().opacity(0.6) }
            .accessibilityElement()
            .accessibilityLabel(tr("Preview size"))
            .accessibilityValue(tr("%@ points", "\(Int(height))"))
            .accessibilityAdjustableAction { direction in
                let step: CGFloat = direction == .increment ? 30 : -30
                storedHeight = Double(clamped(height + step, maximum: maximum))
            }
    }
}

private struct NaturalHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

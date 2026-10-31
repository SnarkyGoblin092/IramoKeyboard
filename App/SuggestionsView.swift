import SwiftUI

/// The suggestion bar: how many words it shows, how it looks and how quickly it updates. The keyboard reads the
/// same settings (Keyboard/SuggestionBar.swift, KeyboardViewController.scheduleRefresh).
struct SuggestionsView: View {
    private enum Tab: Hashable { case look, speed }

    @State private var tab: Tab = .look
    @AppStorage(SettingKey.suggestions, store: SharedStore.defaults) private var enabled = SettingDefault.suggestions
    @AppStorage(SettingKey.suggestionFit, store: SharedStore.defaults) private var fit = SettingDefault.suggestionFit
    @AppStorage(SettingKey.suggestionScroll, store: SharedStore.defaults) private var scroll = SettingDefault.suggestionScroll
    @AppStorage(SettingKey.suggestionStyle, store: SharedStore.defaults) private var style = SettingDefault.suggestionStyle
    @AppStorage(SettingKey.separatorStyle, store: SharedStore.defaults) private var separator = SettingDefault.separatorStyle
    @AppStorage(SettingKey.suggestionFollowTheme, store: SharedStore.defaults) private var followTheme = SettingDefault.suggestionFollowTheme
    @AppStorage(SettingKey.suggestionHeight, store: SharedStore.defaults) private var height = SettingDefault.suggestionHeight
    @AppStorage(SettingKey.suggestionDelay, store: SharedStore.defaults) private var delay = SettingDefault.suggestionDelay

    private struct Speed {
        let name: String
        let delay: Double
        let text: String
    }

    private let speeds = [Speed(name: "Instant", delay: 0, text: "Works out suggestions right after every key: the quickest bar, the most work."),
                          Speed(name: "Balanced", delay: 0.06, text: "Waits a moment, so a burst of fast typing is worked out once."),
                          Speed(name: "Efficient", delay: 0.2, text: "Waits until you pause: fewer checks, the least battery.")]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                GlassToggle(title: "Suggestion bar",
                            subtitle: "Words to finish or fix what you're typing, above the keys.",
                            isOn: $enabled)
                    .padding(18)
                    .glassCard(cornerRadius: GlassMetrics.cardRadius)

                VStack(alignment: .leading, spacing: 16) {
                    GlassToggle(title: "Fit more suggestions",
                                subtitle: "Sizes each suggestion to its word, so more fit in the bar.",
                                isOn: $fit)
                    GlassToggle(title: "Scrollable suggestions",
                                subtitle: "Swipe sideways through up to ten suggestions instead of three.",
                                isOn: $scroll)
                    Divider()
                    GlassTabs(tabs: [Tab.look, .speed], selection: $tab,
                              title: { $0 == .look ? "Look" : "Speed" },
                              symbol: { $0 == .look ? "paintbrush.pointed" : "speedometer" })
                    Divider()
                    switch tab {
                    case .look: lookTab
                    case .speed: speedTab
                    }
                }
                .padding(16)
                .glassCard(cornerRadius: GlassMetrics.cardRadius)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.5)
            }
            .padding(16)
        }
        .background(GlassBackdrop())
        .navigationTitle("Suggestions")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: Look

    private var lookTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Bar style").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
            HStack(spacing: 10) {
                PresetCard(title: "Separators", isSelected: style == "separators") {
                    Feedback.tick()
                    style = "separators"
                } picture: {
                    HStack(spacing: 10) {
                        Text("the")
                        Rectangle().frame(width: 1, height: 18).opacity(0.5)
                        Text("then")
                        Rectangle().frame(width: 1, height: 18).opacity(0.5)
                        Text("they")
                    }
                    .font(.footnote)
                }
                PresetCard(title: "Segments", isSelected: style == "segments") {
                    Feedback.tick()
                    style = "segments"
                } picture: {
                    HStack(spacing: 4) {
                        ForEach(["the", "then", "they"], id: \.self) { word in
                            Text(word)
                                .font(.footnote)
                                .foregroundColor(Color(.systemBackground))
                                .frame(maxWidth: .infinity, minHeight: 26)
                                .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.primary.opacity(0.85)))
                        }
                    }
                    .padding(.horizontal, 6)
                }
            }

            if style == "separators" {
                Text("Separators").font(.subheadline.weight(.semibold)).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(["solid", "dashed", "dotted", "none"], id: \.self) { kind in
                        PresetCard(title: kind.capitalized, isSelected: separator == kind) {
                            Feedback.tick()
                            separator = kind
                        } picture: {
                            SeparatorSample(kind: kind)
                        }
                    }
                }
            }

            GlassToggle(title: "Follow theme",
                        subtitle: "Separators and segments take the theme's key colours.",
                        isOn: $followTheme)
            Divider()
            GlassSlider(title: "Height", symbol: "arrow.up.and.down", value: $height,
                        range: Settings.suggestionHeightRange, step: 1) { "\(Int($0.rounded()))pt" }
        }
    }

    // MARK: Speed

    private var speedTab: some View {
        let current = speeds.first { abs($0.delay - delay) < 0.001 }
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                ForEach(speeds, id: \.name) { speed in
                    PresetCard(title: speed.name, isSelected: current?.name == speed.name) {
                        Feedback.tick()
                        delay = speed.delay
                    } picture: {
                        Image(systemName: speed.delay == 0 ? "hare" : (speed.delay < 0.1 ? "gauge.medium" : "leaf"))
                            .font(.system(size: 22))
                    }
                }
            }
            Text("Delay \(Int((delay * 1000).rounded()))ms. \(current?.text ?? "Your own timing.")")
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            GlassSlider(title: "Delay", symbol: "timer", value: $delay,
                        range: Settings.suggestionDelayRange, step: 0.01) { "\(Int(($0 * 1000).rounded()))ms" }
        }
    }
}

/// Two dashes with a separator line between them, drawn the way the bar draws it.
private struct SeparatorSample: View {
    let kind: String

    var body: some View {
        HStack(spacing: 6) {
            Capsule().frame(width: 14, height: 3)
            Path { path in
                path.move(to: CGPoint(x: 1, y: 0))
                path.addLine(to: CGPoint(x: 1, y: 26))
            }
            .stroke(style: StrokeStyle(lineWidth: kind == "dotted" ? 2 : 1.5,
                                       lineCap: kind == "dotted" ? .round : .butt,
                                       dash: kind == "dashed" ? [4, 3] : (kind == "dotted" ? [0.1, 4] : [])))
            .frame(width: 2, height: 26)
            .opacity(kind == "none" ? 0 : 1)
            Capsule().frame(width: 14, height: 3)
        }
        .foregroundColor(.primary)
    }
}

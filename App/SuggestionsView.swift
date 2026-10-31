import SwiftUI

/// The suggestion bar: whether it shows, how many words, how it looks and how quickly it updates. The keyboard
/// reads the same settings (Keyboard/SuggestionBar.swift, KeyboardViewController.scheduleRefresh).
struct SuggestionsView: View {
    @AppStorage(SettingKey.suggestions, store: SharedStore.defaults) private var enabled = SettingDefault.suggestions
    @AppStorage(SettingKey.suggestionFit, store: SharedStore.defaults) private var fit = SettingDefault.suggestionFit
    @AppStorage(SettingKey.suggestionScroll, store: SharedStore.defaults) private var scroll = SettingDefault.suggestionScroll
    @AppStorage(SettingKey.suggestionStyle, store: SharedStore.defaults) private var style = SettingDefault.suggestionStyle
    @AppStorage(SettingKey.separatorStyle, store: SharedStore.defaults) private var separator = SettingDefault.separatorStyle
    @AppStorage(SettingKey.suggestionFollowTheme, store: SharedStore.defaults) private var followTheme = SettingDefault.suggestionFollowTheme
    @AppStorage(SettingKey.suggestionHeight, store: SharedStore.defaults) private var height = SettingDefault.suggestionHeight
    @AppStorage(SettingKey.suggestionDelay, store: SharedStore.defaults) private var delay = SettingDefault.suggestionDelay

    private let separators = ["solid", "dashed", "dotted", "none"]
    private let delays: [Double] = [0, 0.06, 0.2]

    /// Three equal words, words sized to fit (more of them), or a strip that scrolls.
    private var countIndex: Int { return scroll ? 2 : (fit ? 1 : 0) }

    var body: some View {
        List {
            Section {
                GlassToggle(title: "Word suggestions",
                            subtitle: "Words to finish or fix what you're typing, above the keys.",
                            isOn: $enabled)
            }
            .glassRows()

            Group {
                Section {
                    SegmentedChoice(names: ["Three", "Fit to words", "Scrolling"], selected: countIndex) { index in
                        fit = index == 1
                        scroll = index == 2
                    }
                } header: {
                    SectionHeader("Words shown", symbol: "text.line.first.and.arrowtriangle.forward", color: .blue)
                } footer: {
                    Text(["Three equal places, like the system keyboard.",
                          "Each word as wide as it needs, so up to six fit.",
                          "Up to ten words in a strip you swipe sideways."][countIndex])
                }
                .glassRows()

                Section {
                    SegmentedChoice(title: "Between words", names: ["Lines", "Tiles"],
                                    selected: style == "segments" ? 1 : 0) { style = $0 == 1 ? "segments" : "separators" }
                    if style != "segments" {
                        SegmentedChoice(title: "Line", names: ["Solid", "Dashed", "Dotted", "None"],
                                        selected: separators.firstIndex(of: separator)) { separator = separators[$0] }
                    }
                    GlassToggle(title: "Theme colours",
                                subtitle: "Lines and tiles take the colours of the theme's keys.",
                                isOn: $followTheme)
                    GlassSlider(title: "Bar height", symbol: "arrow.up.and.down", value: $height,
                                range: Settings.suggestionHeightRange, step: 1) { "\(Int($0.rounded())) pt" }
                } header: {
                    SectionHeader("Look", symbol: "paintbrush.pointed", color: .purple)
                }
                .glassRows()

                Section {
                    SegmentedChoice(names: ["Fastest", "Normal", "Battery saver"],
                                    selected: delays.firstIndex { abs($0 - delay) < 0.001 }) { delay = delays[$0] }
                    GlassSlider(title: "Wait after typing", symbol: "timer", value: $delay,
                                range: Settings.suggestionDelayRange, step: 0.01) { "\(Int(($0 * 1000).rounded())) ms" }
                } header: {
                    SectionHeader("Update speed", symbol: "speedometer", color: .green)
                } footer: {
                    Text("How long the bar waits for a pause in typing before working out new words: no wait is the quickest, a longer one saves battery.")
                }
                .glassRows()
            }
            .disabled(!enabled)
        }
        .listStyle(.insetGrouped)
        .glassScreen()
        .navigationTitle("Suggestion bar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

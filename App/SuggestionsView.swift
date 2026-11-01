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
    @AppStorage(SettingKey.suggestionTransition, store: SharedStore.defaults) private var transition = SettingDefault.suggestionTransition
    @AppStorage(SettingKey.suggestionTransitionDuration, store: SharedStore.defaults) private var duration = SettingDefault.suggestionTransitionDuration

    private let separators = ["solid", "dashed", "dotted", "none"]
    /// Very slow ... Very fast.
    private let delays: [Double] = [0.5, 0.3, 0.15, 0.1, 0.05]
    private let transitions = ["instant", "fade", "rise", "slide", "pop"]
    private let transitionNotes = [tr("New words simply replace the old ones, with nothing in between."),
                                   tr("The old words fade out as the new ones fade in."),
                                   tr("New words float up into place while the old ones drift away above."),
                                   tr("New words glide in along the reading direction and push the old ones out."),
                                   tr("New words spring in from slightly smaller, with a little bounce.")]

    /// Three equal words, words sized to fit (more of them), or a strip that scrolls.
    private var countIndex: Int { return scroll ? 2 : (fit ? 1 : 0) }

    // The preview stays pinned above the settings (PinnedPreview).
    var body: some View {
        PinnedPreview(id: "suggestions", height: 170) {
            SuggestionBarPreview()
        } content: {
        GlassList {
            Section {
                GlassToggle(title: tr("Word suggestions"),
                            subtitle: tr("Words to finish or fix what you're typing, above the keys."),
                            isOn: $enabled)
            }
            .glassRows()

            Group {
                Section {
                    SegmentedChoice(names: [tr("Three"), tr("Fit to words"), tr("Scrolling")], selected: countIndex) { index in
                        fit = index == 1
                        scroll = index == 2
                    }
                } header: {
                    SectionHeader(tr("Words shown"), symbol: "text.line.first.and.arrowtriangle.forward", color: .blue)
                } footer: {
                    Text([tr("Three equal places, like the system keyboard."),
                          tr("Each word as wide as it needs, so up to six fit."),
                          tr("Up to ten words in a strip you swipe sideways.")][countIndex])
                }
                .glassRows()

                Section {
                    SegmentedChoice(title: tr("Between words"), names: [tr("Lines"), tr("Tiles")],
                                    selected: style == "segments" ? 1 : 0) { style = $0 == 1 ? "segments" : "separators" }
                    if style != "segments" {
                        SegmentedChoice(title: tr("Line"), names: [tr("Solid"), tr("Dashed"), tr("Dotted"), tr("None")],
                                        selected: separators.firstIndex(of: separator)) { separator = separators[$0] }
                    }
                    GlassToggle(title: tr("Theme colours"),
                                subtitle: tr("Lines and tiles take the colours of the theme's keys."),
                                isOn: $followTheme)
                    GlassSlider(title: tr("Bar height"), symbol: "arrow.up.and.down", value: $height,
                                range: Settings.suggestionHeightRange, step: 1) { "\(Int($0.rounded())) pt" }
                } header: {
                    SectionHeader(tr("Look"), symbol: "paintbrush.pointed", color: .purple)
                }
                .glassRows()

                Section {
                    SegmentedChoice(names: [tr("Instant"), tr("Fade"), tr("Rise"), tr("Slide"), tr("Pop")],
                                    selected: transitions.firstIndex(of: transition)) { transition = transitions[$0] }
                    GlassSlider(title: tr("Duration"), symbol: "timer", value: $duration,
                                range: Settings.suggestionTransitionDurationRange, step: 0.05) { String(format: "%.2f s", $0) }
                        .disabled(transition == "instant")
                } header: {
                    SectionHeader(tr("Switching"), symbol: "arrow.left.arrow.right", color: .orange)
                } footer: {
                    Text(transitionNotes[transitions.firstIndex(of: transition) ?? 0])
                }
                .glassRows()

                Section {
                    SegmentedChoice(names: [tr("Very slow"), tr("Slow"), tr("Normal"), tr("Fast"), tr("Very fast")],
                                    selected: delays.firstIndex { abs($0 - delay) < 0.001 }) { delay = delays[$0] }
                    GlassSlider(title: tr("Wait after typing"), symbol: "timer", value: $delay,
                                range: Settings.suggestionDelayRange, step: 0.01) { "\(Int(($0 * 1000).rounded())) ms" }
                } header: {
                    SectionHeader(tr("Update speed"), symbol: "speedometer", color: .green)
                } footer: {
                    Text(tr("How long the bar waits for a pause in typing (or swiping) before working out new words: a short wait is the quickest, a longer one saves battery. Very slow waits 500 ms, Slow 300, Normal 150, Fast 100, Very fast 50."))
                }
                .glassRows()
            }
            .disabled(!enabled)
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Suggestion bar"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

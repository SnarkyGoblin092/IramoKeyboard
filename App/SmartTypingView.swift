import SwiftUI

/// Calculations and measurements in the suggestion bar: "12*3" offers 36, "5 km" offers 3.107 mi. The keyboard does
/// the work (Keyboard/SmartInput.swift); this screen turns it on and off and shows examples worked out live.
struct SmartTypingView: View {
    @AppStorage(SettingKey.inlineMath, store: SharedStore.defaults) private var inlineMath = SettingDefault.inlineMath
    @AppStorage(SettingKey.unitConversion, store: SharedStore.defaults) private var units = SettingDefault.unitConversion
    @AppStorage(SettingKey.unitTarget, store: SharedStore.defaults) private var target = SettingDefault.unitTarget
    @AppStorage(SettingKey.resultDecimals, store: SharedStore.defaults) private var decimals = SettingDefault.resultDecimals
    @AppStorage(SettingKey.spaceAfterResult, store: SharedStore.defaults) private var spaceAfterResult = SettingDefault.spaceAfterResult
    @AppStorage(SettingKey.spaceAfterConversion, store: SharedStore.defaults) private var spaceAfterConversion = SettingDefault.spaceAfterConversion
    @AppStorage(SettingKey.language, store: SharedStore.defaults) private var languageCode = SettingDefault.language
    @State private var tryText = "(12+3)*4^2"

    private let targets = ["auto", "metric", "imperial"]

    private var language: Language { return LiveKeyboardView.openingLanguage(code: languageCode) }

    /// What the bar would offer for `text`, worked out as the keyboard does.
    private func offer(for text: String) -> String? {
        let places = Int(decimals.rounded())
        if inlineMath, let result = InlineCalculator.result(before: text, language: language, decimals: places) {
            return result.shown
        }
        if units {
            // The bar has every unit; the preview, room for the first few.
            let all = UnitConverter.results(before: text, language: language, decimals: places, target: target)
            if !all.isEmpty { return all.prefix(3).map { $0.shown }.joined(separator: "  \u{00B7}  ") }
        }
        return nil
    }

    private var mathExamples: [String] { return ["12*3", "(2+3)^2/5", "200+15%", "\u{221A}2\u{00B7}\u{03C0}", "sin(30)", "5!"] }
    private var unitExamples: [String] { return ["5 km", "70 kg", "20 \u{00B0}C", "60 mph", "500 ml", "6 ft"] }

    var body: some View {
        PinnedPreview(height: 130) {
            PreviewCard(caption: tr("Type a calculation or a number with a unit: the bar offers the result.")) {
                SmartBarPreview(typed: tryText, offer: offer(for: tryText))
            }
        } content: {
            GlassList {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "pencil.line")
                            .foregroundStyle(.tint)
                            .accessibilityHidden(true)
                        TextField(tr("Try your own"), text: $tryText)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.numbersAndPunctuation)
                            .font(.body.monospaced())
                        if !tryText.isEmpty {
                            Button { tryText = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(tr("Clear"))
                        }
                    }
                } footer: {
                    Text(tr("Type here, or tap an example below: the bar above shows what the keyboard would offer."))
                }
                .glassRows()

                Section {
                    GlassToggle(title: tr("Calculator"),
                                subtitle: tr("Type a calculation to get its answer in the bar: + - \u{00D7} \u{00F7} ^ % !, brackets, \u{221A}, \u{03C0}, sin, cos, tan, log and more."),
                                isOn: $inlineMath)
                        .searchAnchor("smart.math")
                    exampleRow(mathExamples)
                        .opacity(inlineMath ? 1 : 0.45)
                    GlassToggle(title: tr("Space after the answer"),
                                subtitle: tr("A space goes after the answer written in place of the calculation"),
                                isOn: $spaceAfterResult)
                        .searchAnchor("smart.spaceResult")
                        .disabled(!inlineMath)
                        .opacity(inlineMath ? 1 : 0.45)
                } header: {
                    SectionHeader(tr("Calculator"), symbol: "plus.forwardslash.minus", color: .orange)
                } footer: {
                    Text(tr("Angles are in degrees. Tap the answer to write it in place of the calculation. Dates and phone numbers are left alone."))
                }
                .glassRows()

                Section {
                    GlassToggle(title: tr("Unit conversion"),
                                subtitle: tr("A number with a unit (5 km, 70 kg, 20 \u{00B0}C) gets the same in other units; tap it to write it in its place."),
                                isOn: $units)
                        .searchAnchor("smart.units")
                    Group {
                        SegmentedChoice(title: tr("Convert"), names: [tr("Both ways"), tr("To metric"), tr("To imperial")],
                                        selected: targets.firstIndex(of: target)) { target = targets[$0] }
                        exampleRow(unitExamples)
                        GlassToggle(title: tr("Space after the conversion"),
                                    subtitle: tr("A space goes after the converted measurement written in place of the original"),
                                    isOn: $spaceAfterConversion)
                            .searchAnchor("smart.spaceConversion")
                    }
                    .disabled(!units)
                    .opacity(units ? 1 : 0.45)
                } header: {
                    SectionHeader(tr("Units"), symbol: "ruler", color: .teal)
                } footer: {
                    Text(tr("Length, weight, volume, temperature, speed and area."))
                }
                .glassRows()

                Section {
                    GlassSlider(title: tr("Decimal places"), symbol: "number", value: $decimals,
                                range: Settings.resultDecimalsRange, step: 1) { "\(Int($0.rounded()))" }
                        .searchAnchor("smart.decimals")
                } footer: {
                    Text(tr("At most this many digits after the decimal point; trailing zeros are left off."))
                }
                .glassRows()
                .disabled(!inlineMath && !units)
            }
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .navigationTitle(tr("Calculator & units"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Examples to tap: each one is typed into the preview above.
    private func exampleRow(_ examples: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(examples, id: \.self) { example in
                    Button {
                        Feedback.tick()
                        withAnimation(.easeOut(duration: 0.2)) { tryText = example }
                    } label: {
                        Text(example)
                            .font(.subheadline.monospaced())
                            .foregroundColor(.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Capsule().fill(tryText == example
                                                       ? Color.accentColor.opacity(0.28) : Color.primary.opacity(0.07)))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

/// What was typed, then the bar's offer for it (or a dash when there is none).
private struct SmartBarPreview: View {
    let typed: String
    let offer: String?

    var body: some View {
        AccentOfferPreview(typed: typed, offer: offer)
    }
}

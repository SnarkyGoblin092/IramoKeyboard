import SwiftUI

/// How accurately the thumbs hit the letters: the keyboard's adaptive aim (where this user's thumbs tend to land
/// moves the point a tap is read from), and a heatmap of the real taps (TapAccuracy) - every key as the keyboard
/// drew it, brighter the more it was tapped, with the average landing point and the spread of the taps on it.
struct TapAccuracyView: View {
    @State private var map = TapMapData()
    @State private var wide = false
    @State private var selected: String?
    @State private var confirmReset = false
    @State private var bias = TapBias.savedOffsets()
    @AppStorage(SettingKey.tapAdaptive, store: SharedStore.defaults) private var adaptive = SettingDefault.tapAdaptive
    @AppStorage(SettingKey.tapLearnSpeed, store: SharedStore.defaults) private var speed = SettingDefault.tapLearnSpeed
    @AppStorage(SettingKey.tapRecord, store: SharedStore.defaults) private var record = SettingDefault.tapRecord
    @Environment(\.scenePhase) private var scenePhase

    private var layout: TapMapData.Layout { return map.layout(landscape: wide) }

    private func reload() {
        map = TapAccuracy.load()
        bias = TapBias.savedOffsets()
    }

    var body: some View {
        GlassList {
            Section {
                SegmentedChoice(names: [tr("Portrait"), tr("Landscape")], selected: wide ? 1 : 0) { index in
                    selected = nil
                    withAnimation(.easeInOut(duration: 0.25)) { wide = index == 1 }
                }
            }
            .glassRows()

            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    StatTile(value: number(layout.total), label: tr("Taps recorded"), symbol: "hand.tap.fill", color: .teal)
                    StatTile(value: layout.meanMiss.map { percent($0) } ?? "\u{2014}", label: tr("Average miss"),
                             symbol: "scope", color: .orange)
                    StatTile(value: number(layout.keys.count), label: tr("Keys mapped"), symbol: "keyboard", color: .indigo)
                    StatTile(value: shiftText, label: tr("Aim shift"), symbol: "arrow.up.left.and.arrow.down.right", color: .pink)
                }
                .padding(.vertical, 4)
                .glassOutsideCard()
            } footer: {
                Text(tr("The average miss is how far taps land from the middle of the key, as a share of the key."))
            }
            .glassRows()

            Section {
                VStack(spacing: 12) {
                    if layout.total == 0 {
                        emptyState
                    } else {
                        TapHeatmap(layout: layout, selected: $selected)
                        legend
                    }
                    Text(detail)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 6)
            } header: {
                SectionHeader(tr("Heatmap"), symbol: "square.grid.3x3.fill", color: .teal)
            } footer: {
                Text(footer)
            }
            .glassRows()

            Section {
                GlassToggle(title: tr("Adaptive aim"),
                            subtitle: tr("Reads each tap from where your thumbs tend to land, so letters are hit more often"),
                            isOn: $adaptive)
                    .searchAnchor("tap.adaptive")
                SegmentedChoice(title: tr("Learning speed"), names: [tr("Slow"), tr("Normal"), tr("Fast")], selected: speed) { index in
                    speed = index
                }
                .opacity(adaptive ? 1 : 0.45)
                .disabled(!adaptive)
                .searchAnchor("tap.speed")
                thumbRow(tr("Left thumb"), slot: wide ? 2 : 0, symbol: "hand.point.left.fill")
                thumbRow(tr("Right thumb"), slot: wide ? 3 : 1, symbol: "hand.point.right.fill")
            } header: {
                SectionHeader(tr("Adaptive mode"), symbol: "wand.and.stars", color: .pink)
            } footer: {
                Text(tr("The aim moves by a fifth of a key at most and only drifts slowly, so one odd tap changes nothing."))
            }
            .glassRows()

            Section {
                GlassToggle(title: tr("Record where I tap"),
                            subtitle: tr("Counts and averages for each letter key; never what you type. Needs Full Access."),
                            isOn: $record)
                    .searchAnchor("tap.record")
                Button(role: .destructive) {
                    Feedback.danger()
                    confirmReset = true
                } label: {
                    HStack(spacing: 12) {
                        IconTile(symbol: "trash.fill", color: .red)
                        Text(tr("Reset tap data")).foregroundColor(.red)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .confirmationDialog(tr("Reset tap data?"), isPresented: $confirmReset, titleVisibility: .visible) {
                    Button(tr("Reset"), role: .destructive) {
                        TapAccuracy.reset()
                        Feedback.warning()
                        selected = nil
                        withAnimation { reload() }
                    }
                    Button(tr("Cancel"), role: .cancel) {}
                } message: {
                    Text(tr("The heatmap and the learned aim start again from nothing."))
                }
            } header: {
                SectionHeader(tr("Privacy & data"), symbol: "hand.raised.fill", color: .gray)
            }
            .glassRows()
        }
        .glassScreen()
        .navigationTitle(tr("Tap accuracy"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .onChange(of: scenePhase) { phase in if phase == .active { reload() } }
    }

    // MARK: Pieces

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.tap")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.secondary)
            Text(record ? tr("No taps recorded yet. Type with the keyboard and the map fills in.")
                        : tr("Recording is off. Switch it on below and the map fills in as you type."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            Text(tr("Fewer taps")).font(.caption).foregroundColor(.secondary)
            Capsule()
                .fill(LinearGradient(colors: [Color.accentColor.opacity(TapHeatmap.lowest), Color.accentColor.opacity(TapHeatmap.highest)],
                                     startPoint: .leading, endPoint: .trailing))
                .frame(height: 6)
            Text(tr("More taps")).font(.caption).foregroundColor(.secondary)
        }
        .accessibilityHidden(true)
    }

    private var footer: String {
        guard layout.total > 0 else { return tr("A key's colour shows how often it is tapped.") }
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.dateStyle = .medium
        return tr("Since %@. The dot is where taps land on a key on average; the ring shows how far they spread.",
                  formatter.string(from: map.since))
    }

    /// The tapped key, in words; else a hint.
    private var detail: String {
        guard layout.total > 0 else { return "" }
        guard let letter = selected, let key = layout.keys[letter] else { return tr("Tap a key to see where its taps land.") }
        var landing: [String] = []
        let x = Int((abs(key.meanX) * 100).rounded()), y = Int((abs(key.meanY) * 100).rounded())
        if x >= 1 { landing.append(key.meanX > 0 ? tr("%@ right", "\(x)%") : tr("%@ left", "\(x)%")) }
        if y >= 1 { landing.append(key.meanY > 0 ? tr("%@ below", "\(y)%") : tr("%@ above", "\(y)%")) }
        let place = landing.isEmpty ? tr("on the centre") : landing.joined(separator: ", ")
        return letter.uppercased() + "  \u{00B7}  " + tr("%@ taps", number(key.count)) + "  \u{00B7}  " + tr("Lands %@", place)
    }

    /// The learned aim of one half of the keyboard.
    private func thumbRow(_ title: String, slot: Int, symbol: String) -> some View {
        let offset = bias[min(slot, bias.count - 1)]
        return SettingsRow(title: title, symbol: symbol, color: .purple, value: aimText(offset))
            .opacity(adaptive ? 1 : 0.45)
    }

    private func aimText(_ offset: (x: Double, y: Double)) -> String {
        let x = Int((abs(offset.x) * 100).rounded()), y = Int((abs(offset.y) * 100).rounded())
        if x < 1 && y < 1 { return tr("On target") }
        var parts: [String] = []
        if x >= 1 { parts.append(offset.x > 0 ? tr("%@ right", "\(x)%") : tr("%@ left", "\(x)%")) }
        if y >= 1 { parts.append(offset.y > 0 ? tr("%@ below", "\(y)%") : tr("%@ above", "\(y)%")) }
        return parts.joined(separator: ", ")
    }

    /// How far the aim is moved now (the larger of the two halves), when adaptive aim is on.
    private var shiftText: String {
        guard adaptive else { return tr("Off") }
        let slots = wide ? [bias[2], bias[3]] : [bias[0], bias[1]]
        let most = slots.map { ($0.x * $0.x + $0.y * $0.y).squareRoot() }.max() ?? 0
        return percent(most)
    }

    private func percent(_ value: Double) -> String {
        return "\(Int((value * 100).rounded()))%"
    }

    private func number(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = AppLanguage.locale
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

/// The keys as the keyboard drew them (their real places and sizes), each coloured by how often it was tapped, with
/// the average landing point as a dot and the spread of the taps as a ring (once there are enough taps to say).
private struct TapHeatmap: View {
    let layout: TapMapData.Layout
    @Binding var selected: String?

    static let lowest = 0.12
    static let highest = 0.9
    /// Taps needed on a key before its spread is drawn.
    private static let enoughForSpread = 10

    var body: some View {
        let aspect = min(0.8, max(0.2, layout.aspect))
        GeometryReader { proxy in
            let width = proxy.size.width, height = proxy.size.height
            ZStack(alignment: .topLeading) {
                ForEach(layout.keys.keys.sorted(), id: \.self) { letter in
                    if let key = layout.keys[letter] {
                        cell(letter, key, width: width, height: height)
                    }
                }
            }
        }
        .aspectRatio(1 / aspect, contentMode: .fit)
        .frame(maxWidth: .infinity)
    }

    private func cell(_ letter: String, _ key: TapMapData.Key, width: CGFloat, height: CGFloat) -> some View {
        let w = max(4, CGFloat(key.w) * width - 3), h = max(4, CGFloat(key.h) * height - 3)
        let share = layout.maxCount > 0 ? Double(key.count) / Double(layout.maxCount) : 0
        let heat = TapHeatmap.lowest + (TapHeatmap.highest - TapHeatmap.lowest) * pow(share, 0.6)
        let shape = RoundedRectangle(cornerRadius: min(w, h) * 0.22, style: .continuous)
        let isSelected = selected == letter
        return ZStack {
            shape.fill(Color.accentColor.opacity(heat))
            if key.count >= TapHeatmap.enoughForSpread {
                Ellipse()
                    .stroke(Color.white.opacity(0.55), lineWidth: 1)
                    .frame(width: max(4, min(w, CGFloat(key.spreadX * 2) * w)), height: max(4, min(h, CGFloat(key.spreadY * 2) * h)))
                    .offset(x: CGFloat(key.meanX) * w, y: CGFloat(key.meanY) * h)
            }
            Text(letter.uppercased())
                .font(.system(size: max(8, min(15, h * 0.42)), weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
                .offset(y: -h * 0.12)
            Circle()
                .fill(Color.white)
                .frame(width: 5, height: 5)
                .shadow(color: .black.opacity(0.25), radius: 1)
                .offset(x: CGFloat(key.meanX) * w, y: CGFloat(key.meanY) * h)
        }
        .frame(width: w, height: h)
        .clipShape(shape)
        .overlay(shape.stroke(Color.primary.opacity(isSelected ? 0.9 : 0), lineWidth: 2))
        .contentShape(shape)
        .onTapGesture {
            Feedback.tap()
            withAnimation(.easeInOut(duration: 0.15)) { selected = isSelected ? nil : letter }
        }
        .position(x: CGFloat(key.cx) * width, y: CGFloat(key.cy) * height)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(letter.uppercased())
        .accessibilityValue("\(key.count)")
    }
}

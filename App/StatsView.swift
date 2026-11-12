import Charts
import SwiftUI

/// What the keyboard counted while typing (TypingStats): words, typing speed, how much the suggestions, swiping and
/// shortcuts saved, the last two weeks and the languages. Everything stays on this device.
struct StatsView: View {
    @State private var stats = TypingStatsData()
    @State private var confirmReset = false
    @AppStorage(SettingKey.statsEnabled, store: SharedStore.defaults) private var enabled = SettingDefault.statsEnabled
    @Environment(\.scenePhase) private var scenePhase

    private func reload() {
        Settings.shared.refresh()
        stats = TypingStatsData.decode(Settings.shared.typingStatsJSON)
    }

    var body: some View {
        GlassList {
            Section {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    StatTile(value: number(stats.words), label: tr("Words"), symbol: "text.word.spacing", color: .blue)
                    StatTile(value: stats.wordsPerMinute.map { "\(Int($0.rounded()))" } ?? "\u{2014}", label: tr("Words a minute"),
                             symbol: "speedometer", color: .green)
                    StatTile(value: stats.accuracy.map { "\(Int(($0 * 100).rounded()))%" } ?? "\u{2014}", label: tr("Accuracy"),
                             symbol: "scope", color: .orange)
                    StatTile(value: number(stats.savedKeystrokes), label: tr("Keystrokes saved"), symbol: "bolt.fill", color: .purple)
                }
                .padding(.vertical, 4)
                .glassOutsideCard()
            } footer: {
                Text(tr("Since %@. Typing speed counts only the time you are typing, not the pauses.", sinceText))
            }
            .glassRows()

            Section {
                WeekChart(days: stats.days)
                    .frame(height: 170)
                    .padding(.vertical, 6)
            } header: {
                SectionHeader(tr("Last 14 days"), symbol: "chart.bar.fill", color: .blue)
            }
            .glassRows()

            Section {
                countRow(tr("Swiped words"), stats.swipedWords, symbol: "scribble.variable", color: .teal)
                countRow(tr("Suggestions picked"), stats.suggestionsPicked, symbol: "text.line.first.and.arrowtriangle.forward", color: .indigo)
                countRow(tr("Auto-corrections"), stats.autoCorrections, symbol: "checkmark.seal.fill", color: .green)
                countRow(tr("Corrections undone"), stats.correctionsUndone, symbol: "arrow.uturn.backward", color: .gray)
                countRow(tr("Emoji"), stats.emojis, symbol: "face.smiling", color: .yellow)
                countRow(tr("Shortcuts expanded"), stats.shortcuts, symbol: "bolt.fill", color: .orange)
                countRow(tr("Calculations"), stats.calculations, symbol: "plus.forwardslash.minus", color: .orange)
                countRow(tr("Conversions"), stats.conversions, symbol: "ruler", color: .teal)
                countRow(tr("Characters"), stats.characters, symbol: "character", color: .blue)
                countRow(tr("Deletes"), stats.deletes, symbol: "delete.left", color: .red)
            } header: {
                SectionHeader(tr("Counts"), symbol: "number", color: .purple)
            }
            .glassRows()

            if !stats.languages.isEmpty {
                Section {
                    LanguageShares(languages: stats.languages)
                        .padding(.vertical, 4)
                } header: {
                    SectionHeader(tr("Languages"), symbol: "globe", color: .blue)
                }
                .glassRows()
            }

            Section {
                GlassToggle(title: tr("Keep typing stats"),
                            subtitle: tr("Counted on this device only; never in password fields. Needs Full Access."),
                            isOn: $enabled)
                    .searchAnchor("stats.enabled")
                Button(role: .destructive) {
                    Feedback.danger()
                    confirmReset = true
                } label: {
                    HStack(spacing: 12) {
                        IconTile(symbol: "trash.fill", color: .red)
                        Text(tr("Reset stats")).foregroundColor(.red)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .confirmationDialog(tr("Reset typing stats?"), isPresented: $confirmReset, titleVisibility: .visible) {
                    Button(tr("Reset"), role: .destructive) {
                        Settings.shared.typingStatsJSON = TypingStatsData().encoded()
                        Feedback.warning()
                        withAnimation { reload() }
                    }
                    Button(tr("Cancel"), role: .cancel) {}
                } message: {
                    Text(tr("Every count starts again from zero."))
                }
            } header: {
                SectionHeader(tr("Privacy & data"), symbol: "hand.raised.fill", color: .gray)
            }
            .glassRows()
        }
        .glassScreen()
        .navigationTitle(tr("Typing stats"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { reload() }
        .onChange(of: scenePhase) { phase in if phase == .active { reload() } }
    }

    private var sinceText: String {
        let formatter = DateFormatter()
        formatter.locale = AppLanguage.locale
        formatter.dateStyle = .medium
        return formatter.string(from: stats.since)
    }

    private func number(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = AppLanguage.locale
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func countRow(_ title: String, _ value: Int, symbol: String, color: Color) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, color: color)
            Text(title)
            Spacer(minLength: 8)
            Text(number(value)).foregroundColor(.secondary).monospacedDigit()
        }
    }
}

/// One figure on a glass tile.
private struct StatTile: View {
    let value: String
    let label: String
    let symbol: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(.numericText())
            Text(label)
                .font(.footnote)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassShape(RoundedRectangle(cornerRadius: 18, style: .continuous), tint: color.opacity(0.12))
    }
}

/// Words written on each of the last fourteen days.
private struct WeekChart: View {
    let days: [String: Int]

    private struct Day: Identifiable {
        let id: String
        let date: Date
        let words: Int
    }

    private var shown: [Day] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<14).reversed().compactMap { back -> Day? in
            guard let date = calendar.date(byAdding: .day, value: -back, to: today) else { return nil }
            let key = TypingStatsData.dayKey(date)
            return Day(id: key, date: date, words: days[key] ?? 0)
        }
    }

    var body: some View {
        let list = shown
        if list.allSatisfy({ $0.words == 0 }) {
            VStack(spacing: 8) {
                Image(systemName: "chart.bar").font(.title2).foregroundColor(.secondary)
                Text(tr("Type with Iramo and your days show up here."))
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart(list) { day in
                BarMark(x: .value(tr("Day"), day.date, unit: .day), y: .value(tr("Words"), day.words))
                    .foregroundStyle(Color.accentColor.gradient)
                    .cornerRadius(4)
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 2)) { _ in
                    AxisValueLabel(format: .dateTime.day().month(.narrow), centered: true)
                }
            }
            .environment(\.locale, AppLanguage.locale)
        }
    }
}

/// Each language's share of the words, as bars.
private struct LanguageShares: View {
    let languages: [String: Int]

    var body: some View {
        let total = max(1, languages.values.reduce(0, +))
        let sorted = languages.sorted { $0.value > $1.value }.prefix(6)
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(sorted), id: \.key) { item in
                let share = Double(item.value) / Double(total)
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(Language(rawValue: item.key)?.localizedName ?? item.key)
                        Spacer()
                        Text("\(Int((share * 100).rounded()))%").foregroundColor(.secondary).monospacedDigit()
                    }
                    .font(.subheadline)
                    GeometryReader { geometry in
                        Capsule()
                            .fill(Color.accentColor.gradient)
                            .frame(width: max(6, geometry.size.width * share), height: 8)
                    }
                    .frame(height: 8)
                }
            }
        }
    }
}

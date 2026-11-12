import SwiftUI

/// The welcome page, shown the first time the app opens and again from the More tab: what the keyboard does, how to
/// turn it on, and its features, each with a small looping animation of it at work, and at the end where everything
/// is in the app. It is built from the same pieces as the settings: the keybed behind, glass cards (the animation in
/// one, the points in another, as rows with their keycaps), and the app's glass buttons. Swipe through, step with
/// the buttons, or skip at any time.
struct WelcomeView: View {
    let finish: () -> Void
    @State private var page = 0

    private struct Page {
        let color: Color
        let title: String
        let text: String
        let demo: Demo
        let points: [(symbol: String, text: String)]
    }

    private enum Demo { case typing, turnOn, swipe, cursor, smart, look, stats, ready }

    private var pages: [Page] {
        return [
            Page(color: .blue, title: tr("Welcome to Iramo"),
                 text: tr("A keyboard that is yours to shape. Here is what it can do."),
                 demo: .typing,
                 points: [("character.bubble.fill", tr("38 languages: suggestions follow the one you write in")),
                          ("text.bubble.fill", tr("Suggestions and auto-correction that learn your words")),
                          ("lock.fill", tr("Everything it learns stays on this device"))]),
            Page(color: .green, title: tr("Turn it on"),
                 text: tr("Add Iramo in the system settings, then pick it with the globe key."),
                 demo: .turnOn,
                 points: [("1.circle.fill", tr("Open Settings, then General, Keyboard, Keyboards")),
                          ("2.circle.fill", tr("Add New Keyboard and choose Iramo")),
                          ("3.circle.fill", tr("Allow Full Access for vibration, copy and paste, and stats")),
                          ("4.circle.fill", tr("Touch and hold the globe key to switch to it"))]),
            Page(color: .teal, title: tr("Glide to type"),
                 text: tr("Slide across the letters: the word appears when you lift your finger."),
                 demo: .swipe,
                 points: [("scribble.variable", tr("Swipe a word, or glide through space for the next one")),
                          ("paintbrush.pointed.fill", tr("Give the trail your own colour, width and style")),
                          ("delete.left.fill", tr("Slide left from delete to remove whole words"))]),
            Page(color: .indigo, title: tr("Move and select"),
                 text: tr("Hold the space bar until the letters fade: it is now a trackpad."),
                 demo: .cursor,
                 points: [("cursorarrow.motionlines", tr("Slide to move the cursor, as fast as you like")),
                          ("selection.pin.in.out", tr("Touch the keys with a second finger to select")),
                          ("doc.on.clipboard", tr("Copy, cut, paste or change case from the bar"))]),
            Page(color: .orange, title: tr("Smart typing"),
                 text: tr("The bar does more than finish words."),
                 demo: .smart,
                 points: [("plus.forwardslash.minus", tr("Type a sum and = for its answer")),
                          ("ruler", tr("Numbers with units convert: km, kg, \u{00B0}C...")),
                          ("bolt.fill", tr("Shortcuts fill in {date}, {time} and more")),
                          ("face.smiling", tr("Emoji for words and names: \u{201C}red heart\u{201D}")),
                          ("quote.opening", tr("Curly quotes in your language's style"))]),
            Page(color: .purple, title: tr("Make it yours"),
                 text: tr("Themes change the whole look, and every theme can be edited."),
                 demo: .look,
                 points: [("paintpalette.fill", tr("Themes, key styles, effects, haptics and sounds")),
                          ("keyboard", tr("QWERTY, AZERTY, Dvorak, Colemak and more, per language")),
                          ("hand.point.up.left", tr("Your own characters on any key's hold"))]),
            Page(color: .pink, title: tr("Find and follow"),
                 text: tr("Search for any setting, and see how you type."),
                 demo: .stats,
                 points: [("magnifyingglass", tr("The Search tab finds any setting and takes you to it")),
                          ("chart.bar.fill", tr("Typing stats: words, speed and time saved")),
                          ("hand.raised.fill", tr("Counted on this device only, never in passwords"))]),
            Page(color: .indigo, title: tr("All set"),
                 text: tr("Try the keyboard in the box at the top of the Typing tab. This page can be seen again from the More tab."),
                 demo: .ready,
                 points: [])
        ]
    }

    /// Where everything is: the app's tabs, on the last page.
    private var places: [(symbol: String, color: Color, title: String, text: String)] {
        return [
            ("keyboard", .blue, AppTab.typing.title, tr("Languages, corrections, suggestions and shortcuts")),
            ("paintpalette.fill", .purple, AppTab.look.title, tr("Themes, keys, effects and the accent colour")),
            ("hand.tap.fill", .teal, AppTab.touch.title, tr("Gestures, haptics and your own characters")),
            ("ellipsis", .gray, AppTab.more.title, tr("Typing stats, the app's language and your data")),
            ("magnifyingglass", .pink, AppTab.search.title, tr("Any setting, by name"))
        ]
    }

    var body: some View {
        let pages = self.pages
        let last = page == pages.count - 1
        VStack(spacing: 0) {
            header(last: last)
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    pageView(item, shown: index == page).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            footer(pages: pages, last: last)
        }
        .background(GlassBackdrop().ignoresSafeArea())
    }

    // MARK: The bars

    /// The app's mark, and the way out.
    private func header(last: Bool) -> some View {
        HStack(spacing: 10) {
            Image("AppLogo")
                .resizable()
                .frame(width: 30, height: 30)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .accessibilityHidden(true)
            Text(tr("Iramo")).font(.headline)
            Spacer()
            Button {
                finish()
            } label: {
                Text(tr("Skip"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .glassShape(Capsule(), interactive: true)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .opacity(last ? 0 : 1)
            .disabled(last)
        }
        .padding(.horizontal, 20)
        .frame(height: 52)
    }

    /// Where you are (a mark for each page, the current one stretched in its colour), and the way on and back.
    private func footer(pages: [Page], last: Bool) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 6) {
                ForEach(pages.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? pages[page].color : Color.secondary.opacity(0.3))
                        .frame(width: index == page ? 22 : 7, height: 7)
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
            .accessibilityHidden(true)
            HStack(spacing: 12) {
                if page > 0 {
                    Button {
                        Feedback.tap()
                        withAnimation { page -= 1 }
                    } label: {
                        Image(systemName: "chevron.backward")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.primary)
                            .frame(width: 50, height: 50)
                            .glassShape(Circle(), interactive: true)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(tr("Back"))
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
                Button {
                    Feedback.tap()
                    if last {
                        finish()
                    } else {
                        withAnimation { page += 1 }
                    }
                } label: {
                    Text(last ? tr("Get started") : tr("Next")).frame(minHeight: 28)
                }
                .buttonStyle(ActionButtonStyle())
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: page > 0)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }

    // MARK: A page

    /// A glass card, as the settings have them.
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity)
            .glassShape(RoundedRectangle(cornerRadius: GlassMetrics.cardRadius, style: .continuous))
    }

    private func pageView(_ item: Page, shown: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                card {
                    demoView(item.demo, color: item.color, running: shown)
                        .frame(height: 196)
                        .frame(maxWidth: .infinity)
                }
                .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.title)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(item.text)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 4)
                if !item.points.isEmpty {
                    pointsCard(item)
                }
                if item.demo == .turnOn {
                    settingsButton
                }
                if item.demo == .ready {
                    placesCard
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }

    /// The page's points as the rows of a card, each with its keycap (the steps of turning the keyboard on carry
    /// their numbers).
    private func pointsCard(_ item: Page) -> some View {
        card {
            VStack(spacing: 0) {
                ForEach(Array(item.points.enumerated()), id: \.offset) { index, point in
                    HStack(spacing: 14) {
                        if item.demo == .turnOn {
                            KeycapLabel(text: "\(index + 1)", color: item.color)
                        } else {
                            IconTile(symbol: point.symbol, color: item.color)
                        }
                        Text(point.text).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    if index < item.points.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// The app's own page in the system Settings: Keyboards > Iramo, and Allow Full Access.
    private var settingsButton: some View {
        Button {
            Feedback.tap()
            if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
        } label: {
            Label(tr("Open Settings"), systemImage: "gearshape.fill")
                .font(.body.weight(.semibold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, minHeight: 50)
                .glassShape(Capsule(), interactive: true)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    /// The tabs of the app and what is on each.
    private var placesCard: some View {
        let places = self.places
        return card {
            VStack(spacing: 0) {
                ForEach(places.indices, id: \.self) { index in
                    HStack(spacing: 14) {
                        IconTile(symbol: places[index].symbol, color: places[index].color)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(places[index].title).font(.body.weight(.semibold))
                            Text(places[index].text)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    if index < places.count - 1 {
                        Divider().padding(.leading, 62)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder private func demoView(_ demo: Demo, color: Color, running: Bool) -> some View {
        DemoClock(running: running) { time in
            switch demo {
            case .typing: TypingDemo(time: time, color: color)
            case .turnOn: TurnOnDemo(time: time, color: color)
            case .swipe: SwipeDemo(time: time, color: color)
            case .cursor: CursorDemo(time: time, color: color)
            case .smart: SmartDemo(time: time, color: color)
            case .look: LookDemo(time: time, color: color)
            case .stats: StatsDemo(time: time, color: color)
            case .ready: ReadyDemo(time: time, color: color)
            }
        }
    }
}

// MARK: - The animations

/// The time for a looping animation: running only on the page being shown, and stopped (at a moment that shows the
/// feature) when the system asks for less motion.
private struct DemoClock<Content: View>: View {
    let running: Bool
    @ViewBuilder let content: (Double) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if running && !reduceMotion {
            TimelineView(.animation) { timeline in
                content(timeline.date.timeIntervalSinceReferenceDate)
            }
        } else {
            content(1.6)
        }
    }
}

/// Three rows of small keys, one of them lit.
private struct MiniKeys: View {
    var rows = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
    var lit: Character? = nil
    var color: Color
    var tint: Color = Color.primary.opacity(0.08)

    var body: some View {
        VStack(spacing: 5) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 4) {
                    ForEach(Array(rows[row].enumerated()), id: \.offset) { _, letter in
                        Text(String(letter))
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(letter == lit ? .white : .primary)
                            .frame(width: 22, height: 26)
                            .background(RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(letter == lit ? color : tint))
                            .scaleEffect(letter == lit ? 1.15 : 1)
                    }
                }
            }
        }
    }
}

/// A bubble of text above the keys, typed letter by letter.
private struct TypingDemo: View {
    let time: Double
    let color: Color

    var body: some View {
        let message = Array("Hello from Iramo")
        let step = Int(time * 7) % (message.count + 14)
        let shown = String(message.prefix(step))
        let current: Character? = step > 0 && step <= message.count ? message[step - 1].lowercased().first : nil
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                Text(shown.isEmpty ? " " : shown)
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                Rectangle().fill(color).frame(width: 2, height: 20)
                    .opacity(sin(time * 8) > 0 ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
            MiniKeys(lit: current, color: color)
        }
    }
}

/// A row of the system settings, its switch turning on.
private struct TurnOnDemo: View {
    let time: Double
    let color: Color

    var body: some View {
        let phase = time.truncatingRemainder(dividingBy: 3.2)
        let on = phase > 1.0
        VStack(spacing: 10) {
            row(title: "Iramo", symbol: "keyboard", on: on, highlighted: phase > 0.6 && phase < 1.2)
            row(title: tr("Allow Full Access"), symbol: "lock.open.fill", on: phase > 2.0, highlighted: phase > 1.6 && phase < 2.2)
        }
        .padding(.horizontal, 22)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: on)
        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: phase > 2.0)
    }

    private func row(title: String, symbol: String, on: Bool, highlighted: Bool) -> some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, color: color)
            Text(title).font(.body.weight(.medium))
            Spacer()
            ZStack(alignment: on ? .trailing : .leading) {
                Capsule().fill(on ? color : Color.secondary.opacity(0.3)).frame(width: 50, height: 30)
                Circle().fill(.white).frame(width: 26, height: 26).padding(2)
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color.primary.opacity(highlighted ? 0.1 : 0.05)))
    }
}

/// The keyboard's swipe trail (TrailGeometry): the finger's points as one smooth curve that thins and fades towards
/// its tail.
private struct SmoothTrail: View {
    let points: [CGPoint]
    let color: Color

    var body: some View {
        Canvas { context, _ in
            let shade = UIColor(color)
            context.withCGContext { cg in
                TrailGeometry.draw(in: cg, points: points, width: 8, style: "fade", color: shade, opacity: 0.85)
            }
        }
        .allowsHitTesting(false)
    }
}

/// A finger gliding through "hello", its trail fading behind it, and the word landing in the bar.
private struct SwipeDemo: View {
    let time: Double
    let color: Color

    /// Where h, e, l, l, o are on the mini keys (columns and rows).
    private static let stops: [(column: Double, row: Double)] = [(5, 1), (2, 0), (8, 1), (8, 1), (8, 0)]

    var body: some View {
        let cycle = 3.0
        let phase = time.truncatingRemainder(dividingBy: cycle)
        let progress = min(1, phase / 1.8)
        let done = phase > 1.9
        GeometryReader { geometry in
            let width = geometry.size.width
            let keysWidth: CGFloat = 22 * 10 + 4 * 9
            let left = (width - keysWidth) / 2
            let points = SwipeDemo.stops.map { stop -> CGPoint in
                let rowShift: CGFloat = stop.row == 1 ? 13 : 0
                return CGPoint(x: left + rowShift + CGFloat(stop.column) * 26 + 11, y: 74 + CGFloat(stop.row) * 31 + 13)
            }
            let travelled = progress * Double(points.count - 1)
            let index = min(points.count - 2, Int(travelled))
            let part = CGFloat(travelled - Double(index))
            let head = CGPoint(x: points[index].x + (points[index + 1].x - points[index].x) * part,
                               y: points[index].y + (points[index + 1].y - points[index].y) * part)
            ZStack(alignment: .top) {
                Text("hello")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(color))
                    .scaleEffect(done ? 1 : 0.6)
                    .opacity(done ? 1 : 0)
                    .padding(.top, 18)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: done)
                MiniKeys(color: color)
                    .padding(.top, 74)
                if !done {
                    SmoothTrail(points: Array(points[0...index]) + [head], color: color)
                    Circle().fill(color.opacity(0.25)).frame(width: 34, height: 34).position(head)
                }
            }
            .frame(width: width)
        }
    }
}

/// The space bar as a trackpad: the cursor slides through a sentence, then a second finger selects a word and the bar
/// offers copy and cut.
private struct CursorDemo: View {
    let time: Double
    let color: Color

    var body: some View {
        let words = Array("The quick brown fox")
        let phase = time.truncatingRemainder(dividingBy: 4.4)
        // 0-1.6: the caret slides left; 1.6-3: a selection grows over "brown"; then the bar's buttons.
        let caret: Int
        let selection: Range<Int>?
        if phase < 1.6 {
            caret = words.count - Int(phase / 1.6 * 4)
            selection = nil
        } else {
            caret = 15
            let grown = min(5, Int((phase - 1.6) / 1.2 * 6))
            selection = (15 - grown)..<15
        }
        let selecting = phase >= 1.6
        // The finger slides along the bar and never leaves it: from the right part to the left while the caret
        // moves, then it rests while the second finger selects. (Bar 240 wide, finger 30: it stays within +-90.)
        let fingerOffset: CGFloat = {
            let x: Double = phase < 1.6 ? 70.0 - phase / 1.6 * 110.0 : -40.0 - min(1.0, (phase - 1.6) / 1.2) * 20.0
            return CGFloat(min(90.0, max(-90.0, x)))
        }()
        return VStack(spacing: 16) {
            HStack(spacing: 0) {
                ForEach(words.indices, id: \.self) { index in
                    ZStack(alignment: .leading) {
                        Text(String(words[index]))
                            .font(.system(size: 19, weight: .medium, design: .rounded))
                            .background(selection?.contains(index) == true ? color.opacity(0.3) : Color.clear)
                        if index == caret && !selecting {
                            Rectangle().fill(color).frame(width: 2, height: 24).offset(x: -1)
                        }
                    }
                }
                if caret >= words.count && !selecting {
                    Rectangle().fill(color).frame(width: 2, height: 24)
                }
            }
            HStack(spacing: 22) {
                ForEach(["doc.on.doc", "scissors", "doc.on.clipboard", "textformat"], id: \.self) { symbol in
                    Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                }
            }
            .foregroundColor(color)
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
            .opacity(phase > 3.0 ? 1 : 0.15)
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(selecting ? 0.14 : 0.08))
                    .frame(width: 240, height: 32)
                Circle().fill(color.opacity(0.3)).frame(width: 30, height: 30)
                    .offset(x: fingerOffset)
                if selecting {
                    Circle().fill(color.opacity(0.3)).frame(width: 30, height: 30).offset(x: 110, y: -46)
                }
            }
        }
        .animation(.easeOut(duration: 0.2), value: phase > 3.0)
    }
}

/// The bar working things out: a sum, a measurement, a shortcut and an emoji name, one after the other.
private struct SmartDemo: View {
    let time: Double
    let color: Color

    var body: some View {
        let examples: [(typed: String, result: String)] = [
            ("(12+3)\u{00D7}4=", "60"),
            ("5 km", "3.107 mi"),
            ("sent @d", ShortcutTemplate.dateText(Date(), locale: AppLanguage.locale, style: "medium")),
            ("red heart", "\u{2764}\u{FE0F}"),
            ("20 \u{00B0}C", "68 \u{00B0}F")
        ]
        let length = 2.2
        let index = Int(time / length) % examples.count
        let phase = time.truncatingRemainder(dividingBy: length)
        let example = examples[index]
        let typedCount = min(example.typed.count, Int(phase / 0.8 * Double(example.typed.count)) + 1)
        let showResult = phase > 0.95
        return VStack(spacing: 18) {
            Text(String(example.typed.prefix(typedCount)))
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .frame(height: 30)
            HStack(spacing: 0) {
                slot(" ", highlighted: false)
                Divider().frame(height: 22)
                slot(showResult ? example.result : " ", highlighted: showResult)
                Divider().frame(height: 22)
                slot(" ", highlighted: false)
            }
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.06)))
            .padding(.horizontal, 22)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.65), value: showResult)
        .animation(.easeOut(duration: 0.15), value: index)
    }

    private func slot(_ text: String, highlighted: Bool) -> some View {
        Text(text)
            .font(.system(size: 17, weight: highlighted ? .semibold : .regular))
            .foregroundColor(highlighted ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(highlighted ? color : Color.clear))
            .scaleEffect(highlighted ? 1 : 0.9)
            .frame(maxWidth: .infinity)
    }
}

/// Keys changing colour as the themes go by, and their letters changing layout.
private struct LookDemo: View {
    let time: Double
    let color: Color

    var body: some View {
        let layouts: [(name: String, rows: [String])] = [
            ("QWERTY", ["qwertyuiop", "asdfghjkl", "zxcvbnm"]),
            ("AZERTY", ["azertyuiop", "qsdfghjklm", "wxcvbn"]),
            ("Dvorak", ["pyfgcrl", "aoeuidhtns", "qjkxbmwvz"]),
            ("Colemak", ["qwfpgjluy", "arstdhneio", "zxcvbkm"])
        ]
        let index = Int(time / 2.4) % layouts.count
        let hue = (time / 9).truncatingRemainder(dividingBy: 1)
        let keyColor = Color(hue: hue, saturation: 0.45, brightness: 0.95)
        return VStack(spacing: 12) {
            Text(layouts[index].name)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color(hue: hue, saturation: 0.7, brightness: 0.75)))
                .id(index)
                .transition(.scale.combined(with: .opacity))
            MiniKeys(rows: layouts[index].rows, color: color, tint: keyColor.opacity(0.45))
                .id("keys\(index)")
                .transition(.opacity)
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: index)
    }
}

/// A search for a setting, typed letter by letter, with the matching settings listed under it.
private struct StatsDemo: View {
    let time: Double
    let color: Color

    /// The first matches of a query, kept: the animation draws sixty times a second, and searching builds the whole
    /// settings index each time.
    private static var cache: [String: [SearchEntry]] = [:]

    private static func matches(for query: String) -> [SearchEntry] {
        if let known = cache[query] { return known }
        let found = Array(SettingsIndex.search(query).prefix(3))
        cache[query] = found
        return found
    }

    var body: some View {
        // Typing into the search field: the real settings that match are listed under it as each letter goes in.
        let queries = ["swipe", "haptic", "theme", "emoji"]
        let length = 3.4
        let round = Int(time / length)
        let phase = time.truncatingRemainder(dividingBy: length)
        let query = Array(queries[round % queries.count])
        let typed = String(query.prefix(min(query.count, max(0, Int((phase - 0.3) * 5)))))
        let results = typed.isEmpty ? [] : StatsDemo.matches(for: typed)
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                Text(typed.isEmpty ? tr("Search settings") : typed)
                    .foregroundColor(typed.isEmpty ? .secondary : .primary)
                Spacer()
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.primary.opacity(0.07)))
            VStack(spacing: 6) {
                ForEach(results) { entry in
                    HStack(spacing: 10) {
                        Keycap(color: entry.color, size: 26) {
                            Image(systemName: entry.symbol).font(.system(size: 12, weight: .semibold))
                        }
                        VStack(alignment: .leading, spacing: 0) {
                            Text(entry.title).font(.subheadline).lineLimit(1)
                            Text(entry.place).font(.caption2).foregroundColor(.secondary).lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .frame(height: 3 * 34, alignment: .top)
        }
        .padding(.horizontal, 22)
    }
}

/// A check mark drawn again and again, with sparks around it.
private struct ReadyDemo: View {
    let time: Double
    let color: Color

    var body: some View {
        let phase = time.truncatingRemainder(dividingBy: 2.6)
        let drawn = min(1, phase / 0.7)
        ZStack {
            Circle().fill(color.opacity(0.15)).frame(width: 120, height: 120)
                .scaleEffect(1 + 0.05 * sin(time * 3))
            Path { path in
                path.move(to: CGPoint(x: 38, y: 62))
                path.addLine(to: CGPoint(x: 54, y: 78))
                path.addLine(to: CGPoint(x: 84, y: 44))
            }
            .trim(from: 0, to: CGFloat(drawn))
            .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            .frame(width: 120, height: 120)
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi
                let distance = 70 + 30 * min(1, max(0, (phase - 0.6) / 0.8))
                Circle().fill(color)
                    .frame(width: 6, height: 6)
                    .offset(x: CGFloat(cos(angle) * distance), y: CGFloat(sin(angle) * distance))
                    .opacity(phase > 0.6 ? max(0, 1 - (phase - 0.6) / 1.2) : 0)
            }
        }
    }
}

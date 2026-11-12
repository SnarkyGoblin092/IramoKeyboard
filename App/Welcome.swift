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
                        // The animations are laid out left to right, as a keyboard is.
                        .environment(\.layoutDirection, .leftToRight)
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
//
// Each animation is a picture worked out from the time alone: where the finger is, how far a switch has slid, how
// much of a word is typed. Nothing in them jumps from one state to the next: every move is eased from the time
// (Motion), so they run smoothly at any frame rate, loop without a seam (each fades out before it starts again),
// and stand still at a moment that shows the feature when the system asks for less motion.

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

/// The animations' easing: shares between 0 and 1 worked out from the time.
private enum Motion {
    static func clamp(_ x: Double) -> Double {
        return min(1, max(0, x))
    }

    /// 0 until `start`, 1 from `end`, easing in and out between them.
    static func ease(_ time: Double, _ start: Double, _ end: Double) -> Double {
        let x = clamp((time - start) / max(end - start, 0.0001))
        return x * x * (3 - 2 * x)
    }

    /// 0 until `start`, then up to 1 with a little overshoot that settles, as a spring does (about `length` long).
    static func spring(_ time: Double, _ start: Double, _ length: Double) -> Double {
        let x = (time - start) / max(length, 0.0001)
        if x <= 0 { return 0 }
        if x >= 1.6 { return 1 }
        return 1 - exp(-5 * x) * cos(7.5 * x)
    }

    /// A rise and a fall, `length` long from `start`: a tap.
    static func pulse(_ time: Double, _ start: Double, _ length: Double) -> Double {
        let x = (time - start) / max(length, 0.0001)
        if x <= 0 || x >= 1 { return 0 }
        return sin(x * Double.pi)
    }

    static func mix(_ a: CGFloat, _ b: CGFloat, _ share: Double) -> CGFloat {
        return a + (b - a) * CGFloat(share)
    }

    static func mixPoint(_ a: CGPoint, _ b: CGPoint, _ share: Double) -> CGPoint {
        return CGPoint(x: mix(a.x, b.x, share), y: mix(a.y, b.y, share))
    }

    /// A caret's slow blink.
    static func blink(_ time: Double) -> Double {
        return 0.3 + 0.7 * abs(sin(time * 3.4))
    }
}

/// How one key of the small keyboard is drawn.
private struct KeyLook {
    var fill: Color
    var text: Color = .primary
    var scale: CGFloat = 1
}

/// The small keyboard of the animations: three rows of keys, each drawn as `look` says for its letter, row and
/// place in the row.
private struct DemoKeys: View {
    static let rows: [String] = ["qwertyuiop", "asdfghjkl", "zxcvbnm"]
    static let keyWidth: CGFloat = 22
    static let keyHeight: CGFloat = 27
    static let gap: CGFloat = 4
    static let rowGap: CGFloat = 5
    static let width: CGFloat = 10 * 22 + 9 * 4
    static let height: CGFloat = 3 * 27 + 2 * 5

    let look: (Character, Int, Int) -> KeyLook

    /// The middle of a key, measured from the keyboard's top left corner.
    static func center(row: Int, column: Int) -> CGPoint {
        let count = CGFloat(rows[row].count)
        let rowWidth: CGFloat = count * keyWidth + (count - 1) * gap
        let left: CGFloat = (width - rowWidth) / 2
        let x: CGFloat = left + CGFloat(column) * (keyWidth + gap) + keyWidth / 2
        let y: CGFloat = CGFloat(row) * (keyHeight + rowGap) + keyHeight / 2
        return CGPoint(x: x, y: y)
    }

    var body: some View {
        VStack(spacing: DemoKeys.rowGap) {
            ForEach(DemoKeys.rows.indices, id: \.self) { row in
                HStack(spacing: DemoKeys.gap) {
                    ForEach(Array(DemoKeys.rows[row].enumerated()), id: \.offset) { item in
                        key(item.element, row: row, column: item.offset)
                    }
                }
            }
        }
        .frame(width: DemoKeys.width, height: DemoKeys.height)
    }

    private func key(_ letter: Character, row: Int, column: Int) -> some View {
        let style = look(letter, row, column)
        return Text(String(letter))
            .font(.system(size: 12, weight: .medium, design: .rounded))
            .foregroundColor(style.text)
            .frame(width: DemoKeys.keyWidth, height: DemoKeys.keyHeight)
            .background(RoundedRectangle(cornerRadius: 6, style: .continuous).fill(style.fill))
            .scaleEffect(style.scale)
    }
}

/// A finger on the screen: a soft disc, a little smaller and fuller the harder it presses.
private struct DemoFinger: View {
    let color: Color
    var pressed: Double = 0

    var body: some View {
        Circle()
            .fill(color.opacity(0.22 + 0.18 * pressed))
            .overlay(Circle().strokeBorder(color.opacity(0.55), lineWidth: 1.5))
            .frame(width: 30, height: 30)
            .scaleEffect(CGFloat(1 - 0.18 * pressed))
    }
}

/// A caret in the page's colour.
private struct DemoCaret: View {
    let color: Color
    var height: CGFloat = 22

    var body: some View {
        Capsule().fill(color).frame(width: 2.5, height: height)
    }
}

/// A line typed letter by letter: each key lights as it is pressed and fades as the next one is.
private struct TypingDemo: View {
    let time: Double
    let color: Color

    var body: some View {
        let message = Array("Hello from Iramo")
        let pace: Double = 0.16
        let cycle: Double = Double(message.count) * pace + 2.6
        let phase: Double = time.truncatingRemainder(dividingBy: cycle)
        let beat: Double = phase / pace
        let count: Int = min(message.count, Int(beat))
        // Since the last key went down: its light fades with this.
        let since: Double = beat - Double(count)
        let strength: Double = count > 0 ? exp(-2.6 * since) : 0
        let pressed: Character? = count > 0 ? String(message[count - 1]).lowercased().first : nil
        let shown = String(message.prefix(count))
        let leaving: Double = 1 - Motion.ease(phase, cycle - 0.45, cycle)
        return VStack(spacing: 18) {
            HStack(spacing: 2) {
                Text(shown.isEmpty ? " " : shown)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                DemoCaret(color: color).opacity(Motion.blink(time))
            }
            .opacity(leaving)
            .frame(minWidth: 44)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
            DemoKeys { letter, _, _ in
                let hit: Double = letter == pressed ? strength : 0
                return KeyLook(fill: color.opacity(0.12 + 0.88 * hit), text: hit > 0.45 ? .white : .primary,
                               scale: CGFloat(1 + 0.2 * hit))
            }
        }
    }
}

/// Two rows of the system settings: a finger comes to each switch in turn and taps it on.
private struct TurnOnDemo: View {
    let time: Double
    let color: Color

    var body: some View {
        let phase: Double = time.truncatingRemainder(dividingBy: 4.6)
        let reset: Double = Motion.ease(phase, 4.0, 4.5)
        let first: Double = Motion.spring(phase, 1.0, 0.5) * (1 - reset)
        let second: Double = Motion.spring(phase, 2.5, 0.5) * (1 - reset)
        let start = CGPoint(x: 150, y: 132)
        let one = CGPoint(x: 213, y: 25)
        let two = CGPoint(x: 213, y: 85)
        let toOne: Double = Motion.ease(phase, 0.25, 0.9)
        let toTwo: Double = Motion.ease(phase, 1.7, 2.4)
        let finger: CGPoint = Motion.mixPoint(Motion.mixPoint(start, one, toOne), two, toTwo)
        let shown: Double = Motion.ease(phase, 0.1, 0.4) * (1 - Motion.ease(phase, 3.0, 3.4))
        let press: Double = Motion.pulse(phase, 0.9, 0.3) + Motion.pulse(phase, 2.4, 0.3)
        return ZStack(alignment: .topLeading) {
            VStack(spacing: 10) {
                row(title: "Iramo", symbol: "keyboard", on: first)
                row(title: tr("Allow Full Access"), symbol: "lock.open.fill", on: second)
            }
            DemoFinger(color: color, pressed: press)
                .position(finger)
                .opacity(shown)
        }
        .frame(width: 250, height: 110)
    }

    private func row(title: String, symbol: String, on: Double) -> some View {
        let knob: CGFloat = Motion.mix(-10, 10, on)
        return HStack(spacing: 12) {
            IconTile(symbol: symbol, color: color)
            Text(title)
                .font(.body.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer(minLength: 4)
            ZStack {
                Capsule().fill(Color.secondary.opacity(0.3))
                Capsule().fill(color).opacity(Motion.clamp(on))
                Circle()
                    .fill(Color.white)
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.black.opacity(0.18), radius: 2, x: 0, y: 1)
                    .offset(x: knob)
            }
            .frame(width: 50, height: 30)
        }
        .padding(.horizontal, 12)
        .frame(width: 250, height: 50)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.06)))
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

/// A finger gliding through "hello" along one smooth curve, the keys warming as it passes and its trail fading
/// behind it; the word then lands in the bar.
private struct SwipeDemo: View {
    let time: Double
    let color: Color

    /// The keys of h, e, l and o.
    private static let stops: [CGPoint] = [DemoKeys.center(row: 1, column: 5), DemoKeys.center(row: 0, column: 2),
                                           DemoKeys.center(row: 1, column: 8), DemoKeys.center(row: 0, column: 8)]
    /// The finger's way through them: close points along a smooth curve.
    private static let path: [CGPoint] = TrailGeometry.curve(SwipeDemo.stops, spacing: 2)

    var body: some View {
        let path = SwipeDemo.path
        let phase: Double = time.truncatingRemainder(dividingBy: 3.8)
        let glide: Double = Motion.ease(phase, 0.35, 2.1)
        let last: Int = max(path.count - 1, 0)
        let headIndex: Int = min(last, Int((glide * Double(last)).rounded()))
        let head: CGPoint = path.isEmpty ? SwipeDemo.stops[0] : path[headIndex]
        let tailIndex: Int = max(0, headIndex - 70)
        let trail: [CGPoint] = path.isEmpty ? [] : Array(path[tailIndex...headIndex])
        let fingerShown: Double = Motion.ease(phase, 0.1, 0.35) * (1 - Motion.ease(phase, 2.1, 2.4))
        let trailShown: Double = 1 - Motion.ease(phase, 2.1, 2.6)
        let word: Double = Motion.spring(phase, 2.15, 0.45)
        let wordShown: Double = Motion.ease(phase, 2.15, 2.3) * (1 - Motion.ease(phase, 3.4, 3.8))
        let top: CGFloat = 52
        return ZStack(alignment: .topLeading) {
            Text("hello")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 7)
                .background(Capsule().fill(color))
                .scaleEffect(CGFloat(0.7 + 0.3 * word))
                .opacity(wordShown)
                .frame(width: DemoKeys.width, height: 38)
            DemoKeys { _, row, column in
                let centre = DemoKeys.center(row: row, column: column)
                let distance: CGFloat = hypot(centre.x - head.x, centre.y - head.y)
                let near: Double = fingerShown * Double(max(0, 1 - distance / 30))
                return KeyLook(fill: color.opacity(0.12 + 0.5 * near), scale: CGFloat(1 + 0.12 * near))
            }
            .offset(y: top)
            if trail.count > 1 {
                SmoothTrail(points: trail, color: color)
                    .opacity(trailShown)
                    .offset(y: top)
            }
            DemoFinger(color: color, pressed: 0.6)
                .position(x: head.x, y: head.y + top)
                .opacity(fingerShown)
        }
        .frame(width: DemoKeys.width, height: top + DemoKeys.height)
    }
}

/// The space bar as a trackpad: the finger slides along it and the caret slides through the sentence with it; a
/// second finger then touches down and the slide selects a word, and the bar's tools light up.
private struct CursorDemo: View {
    let time: Double
    let color: Color

    var body: some View {
        let letters = Array("The quick brown fox")
        let cell: CGFloat = 12
        let phase: Double = time.truncatingRemainder(dividingBy: 5.4)
        let leaving: Double = 1 - Motion.ease(phase, 4.8, 5.3)
        // The caret goes from the end of the line to just after "brown"; then the selection grows back over it.
        let move: Double = Motion.ease(phase, 0.5, 1.7)
        let grow: Double = Motion.ease(phase, 2.2, 3.3)
        let caretAt: CGFloat = Motion.mix(CGFloat(letters.count), 15, move)
        let selectionStart: CGFloat = Motion.mix(15, 10, grow * leaving)
        let caretShown: Double = (1 - Motion.ease(phase, 2.0, 2.2)) * Motion.blink(time)
        let tools: Double = Motion.ease(phase, 3.3, 3.6) * leaving
        let hold: Double = Motion.ease(phase, 0.1, 0.4) * leaving
        let fingerX: CGFloat = Motion.mix(Motion.mix(74, -30, move), -78, grow)
        let second: Double = Motion.spring(phase, 1.95, 0.4) * (1 - Motion.ease(phase, 3.5, 3.8))
        return VStack(spacing: 16) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(color.opacity(0.3))
                    .frame(width: max(0, (15 - selectionStart) * cell), height: 26)
                    .offset(x: selectionStart * cell)
                HStack(spacing: 0) {
                    ForEach(letters.indices, id: \.self) { index in
                        Text(String(letters[index]))
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .fixedSize()
                            .frame(width: cell)
                    }
                }
                DemoCaret(color: color, height: 24)
                    .offset(x: caretAt * cell - 1.25)
                    .opacity(caretShown)
            }
            .frame(width: cell * CGFloat(letters.count), height: 28, alignment: .leading)
            HStack(spacing: 22) {
                ForEach(["doc.on.doc", "scissors", "doc.on.clipboard", "textformat"], id: \.self) { symbol in
                    Image(systemName: symbol).font(.system(size: 17, weight: .medium))
                }
            }
            .foregroundColor(color)
            .padding(.horizontal, 22)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
            .opacity(0.18 + 0.82 * tools)
            .scaleEffect(CGFloat(0.96 + 0.04 * tools))
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color.primary.opacity(0.08 + 0.06 * hold))
                    .frame(width: 240, height: 34)
                DemoFinger(color: color, pressed: 0.7)
                    .offset(x: fingerX)
                    .opacity(hold)
                DemoFinger(color: color, pressed: 0.4)
                    .scaleEffect(CGFloat(second))
                    .offset(x: 98)
                    .opacity(Motion.clamp(second))
            }
        }
    }
}

/// The bar working things out: a sum, a measurement, a shortcut and an emoji name, one after the other. Each is
/// typed, and its answer springs into the bar.
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
        let length: Double = 2.8
        let index: Int = Int(time / length) % examples.count
        let phase: Double = time.truncatingRemainder(dividingBy: length)
        let example = examples[index]
        let typedShare: Double = Motion.clamp((phase - 0.15) / 0.8)
        let typedCount: Int = min(example.typed.count, Int(typedShare * Double(example.typed.count) + 0.999))
        let arriving: Double = Motion.ease(phase, 0, 0.25)
        let leaving: Double = 1 - Motion.ease(phase, length - 0.3, length)
        let result: Double = Motion.spring(phase, 1.1, 0.45)
        let resultShown: Double = Motion.ease(phase, 1.1, 1.22) * leaving
        return VStack(spacing: 18) {
            HStack(spacing: 2) {
                Text(String(example.typed.prefix(typedCount)))
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                DemoCaret(color: color, height: 24).opacity(Motion.blink(time))
            }
            .frame(height: 30)
            .offset(y: Motion.mix(8, 0, arriving))
            .opacity(arriving * leaving)
            HStack(spacing: 0) {
                placeholder
                Divider().frame(height: 22)
                Text(example.result)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(color))
                    .scaleEffect(CGFloat(0.6 + 0.4 * result))
                    .opacity(resultShown)
                    .frame(maxWidth: .infinity)
                Divider().frame(height: 22)
                placeholder
            }
            .frame(height: 34)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.primary.opacity(0.06)))
            .padding(.horizontal, 22)
        }
    }

    /// A word of the bar that is not the one being shown.
    private var placeholder: some View {
        Capsule()
            .fill(Color.primary.opacity(0.1))
            .frame(width: 34, height: 8)
            .frame(maxWidth: .infinity)
    }
}

/// A theme taking over from another: its colours sweep across the keyboard, each key turning over in its turn.
private struct LookDemo: View {
    let time: Double
    let color: Color

    private struct Palette {
        let name: String
        let board: Color
        let key: Color
        let text: Color
    }

    private static let palettes: [Palette] = [
        Palette(name: "Classic", board: Color(white: 0.68), key: Color(white: 0.98), text: Color.black),
        Palette(name: "Midnight", board: Color(red: 0.10, green: 0.11, blue: 0.17),
                key: Color(red: 0.24, green: 0.26, blue: 0.37), text: Color.white),
        Palette(name: "Sunset", board: Color(red: 0.78, green: 0.33, blue: 0.36),
                key: Color(red: 1.0, green: 0.70, blue: 0.52), text: Color(red: 0.36, green: 0.10, blue: 0.12)),
        Palette(name: "Mint", board: Color(red: 0.25, green: 0.58, blue: 0.52),
                key: Color(red: 0.72, green: 0.94, blue: 0.86), text: Color(red: 0.05, green: 0.30, blue: 0.26))
    ]

    var body: some View {
        let palettes = LookDemo.palettes
        let length: Double = 2.8
        let index: Int = Int(time / length) % palettes.count
        let phase: Double = time.truncatingRemainder(dividingBy: length)
        let now = palettes[index]
        let next = palettes[(index + 1) % palettes.count]
        let over: Double = Motion.ease(phase, 1.5, 2.6)
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)
        return VStack(spacing: 12) {
            ZStack {
                label(now).opacity(1 - over)
                label(next).opacity(over)
            }
            DemoKeys { _, row, column in
                // Later for the keys farther along and farther down: the change sweeps across.
                let delay: Double = Double(column) * 0.06 + Double(row) * 0.1
                let turn: Double = Motion.ease(phase, 1.5 + delay, 1.85 + delay)
                let shown = turn < 0.5 ? now : next
                return KeyLook(fill: shown.key, text: shown.text, scale: CGFloat(1 - 0.35 * sin(turn * Double.pi)))
            }
            .padding(10)
            .background(
                ZStack {
                    shape.fill(now.board)
                    shape.fill(next.board).opacity(over)
                })
        }
    }

    private func label(_ palette: Palette) -> some View {
        Text(palette.name)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(palette.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 5)
            .background(Capsule().fill(palette.key))
    }
}

/// A search for a setting, typed letter by letter; the settings it finds then come in one after the other.
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
        let queries = ["swipe", "haptic", "theme", "emoji"]
        let length: Double = 3.8
        let round: Int = Int(time / length)
        let phase: Double = time.truncatingRemainder(dividingBy: length)
        let query = queries[round % queries.count]
        let pace: Double = 0.14
        let typedCount: Int = min(query.count, max(0, Int((phase - 0.3) / pace)))
        let typed = String(query.prefix(typedCount))
        let typedAt: Double = 0.3 + Double(query.count) * pace
        let results = StatsDemo.matches(for: query)
        let leaving: Double = 1 - Motion.ease(phase, length - 0.4, length)
        return VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                Text(typed.isEmpty ? tr("Search settings") : typed)
                    .foregroundColor(typed.isEmpty ? .secondary : .primary)
                    .lineLimit(1)
                if !typed.isEmpty {
                    DemoCaret(color: color, height: 16).opacity(Motion.blink(time))
                }
                Spacer(minLength: 0)
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(Color.primary.opacity(0.07)))
            .opacity(leaving)
            VStack(spacing: 6) {
                ForEach(Array(results.enumerated()), id: \.offset) { item in
                    let start: Double = typedAt + 0.1 + Double(item.offset) * 0.14
                    let arrive: Double = Motion.ease(phase, start, start + 0.3)
                    row(item.element)
                        .offset(y: Motion.mix(12, 0, arrive))
                        .opacity(arrive * leaving)
                }
            }
            .frame(height: 3 * 34, alignment: .top)
        }
        .padding(.horizontal, 22)
    }

    private func row(_ entry: SearchEntry) -> some View {
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

/// A ring closing and a check mark drawn in it, with a burst of sparks as it is done.
private struct ReadyDemo: View {
    let time: Double
    let color: Color

    var body: some View {
        let phase: Double = time.truncatingRemainder(dividingBy: 3.4)
        let leaving: Double = 1 - Motion.ease(phase, 2.9, 3.35)
        let ring: Double = Motion.ease(phase, 0.1, 0.85)
        let check: Double = Motion.ease(phase, 0.7, 1.15)
        let pop: Double = Motion.pulse(phase, 1.05, 0.45)
        let burst: Double = Motion.ease(phase, 1.05, 1.9)
        let fade: Double = phase > 1.05 ? 1 - Motion.ease(phase, 1.4, 2.0) : 0
        let reach: Double = 66 + 34 * (1 - (1 - burst) * (1 - burst))
        return ZStack {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: 118, height: 118)
                .scaleEffect(CGFloat(0.9 + 0.1 * ring + 0.06 * pop))
            Circle()
                .trim(from: 0, to: CGFloat(ring))
                .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: 118, height: 118)
            Path { path in
                path.move(to: CGPoint(x: 38, y: 62))
                path.addLine(to: CGPoint(x: 54, y: 78))
                path.addLine(to: CGPoint(x: 84, y: 44))
            }
            .trim(from: 0, to: CGFloat(check))
            .stroke(color, style: StrokeStyle(lineWidth: 9, lineCap: .round, lineJoin: .round))
            .frame(width: 120, height: 120)
            .scaleEffect(CGFloat(1 + 0.08 * pop))
            ForEach(0..<10, id: \.self) { index in
                spark(index, reach: reach, fade: fade)
            }
        }
        .opacity(leaving)
    }

    private func spark(_ index: Int, reach: Double, fade: Double) -> some View {
        let angle: Double = Double(index) / 10 * 2 * Double.pi
        let size: CGFloat = index % 2 == 0 ? 6 : 4
        let x: CGFloat = CGFloat(cos(angle) * reach)
        let y: CGFloat = CGFloat(sin(angle) * reach)
        return Circle()
            .fill(color)
            .frame(width: size, height: size)
            .offset(x: x, y: y)
            .opacity(fade)
    }
}

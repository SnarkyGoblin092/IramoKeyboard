import SwiftUI

/// A short tour of the app, shown the first time it opens and again from the About section: a few pages on what the
/// keyboard does, how to turn it on, the themes and the settings. Swipe through, or skip at any time.
struct TutorialView: View {
    let finish: () -> Void
    @State private var page = 0

    private struct Page {
        let symbol: String
        let color: Color
        let title: String
        let text: String
        let points: [(symbol: String, text: String)]
    }

    private var pages: [Page] {
        return [
            Page(symbol: "keyboard", color: .blue, title: tr("Welcome to Iramo"),
                 text: tr("A keyboard that is yours to shape. This short tour shows what it can do."),
                 points: [("character.bubble.fill", tr("Many languages, one keyboard")),
                          ("hand.tap.fill", tr("Gestures, swipe typing and suggestions")),
                          ("paintpalette.fill", tr("Themes and settings for every detail"))]),
            Page(symbol: "switch.2", color: .green, title: tr("Turn it on"),
                 text: tr("Add Iramo in the system settings, then pick it with the globe key."),
                 points: [("1.circle.fill", tr("Open Settings, then General, Keyboard, Keyboards")),
                          ("2.circle.fill", tr("Add New Keyboard and choose Iramo")),
                          ("3.circle.fill", tr("Touch and hold the globe key to switch to it"))]),
            Page(symbol: "hand.tap.fill", color: .teal, title: tr("Type your way"),
                 text: tr("Everything about typing can be tuned in the main list."),
                 points: [("scribble.variable", tr("Glide across the letters to swipe-type")),
                          ("text.cursor", tr("Slide on the space bar to move the cursor")),
                          ("delete.left.fill", tr("Slide left from backspace to delete word by word")),
                          ("face.smiling", tr("Touch and hold the emoji key to open the settings"))]),
            Page(symbol: "text.bubble.fill", color: .orange, title: tr("Suggestions and tools"),
                 text: tr("The bar above the keys finishes your words and holds handy tools."),
                 points: [("textformat.abc", tr("Pick a word, or let it fix what you typed")),
                          ("square.grid.2x2.fill", tr("The button at its left opens the tools")),
                          ("slider.horizontal.3", tr("Choose and order the tools under Functions"))]),
            Page(symbol: "paintpalette.fill", color: .purple, title: tr("Make it yours"),
                 text: tr("Themes change the whole look, and every theme can be edited."),
                 points: [("square.grid.2x2", tr("Pick a theme under Look & feel")),
                          ("circle.lefthalf.filled", tr("Switch between light, dark and auto")),
                          ("sparkles", tr("Add key effects, haptics and sounds"))]),
            Page(symbol: "checkmark.seal.fill", color: .indigo, title: tr("All set"),
                 text: tr("Try the keyboard in the box at the top of the main list. You can replay this tour at the bottom of the app."),
                 points: [])
        ]
    }

    var body: some View {
        let pages = self.pages
        let last = page == pages.count - 1
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(tr("Skip")) { finish() }
                    .opacity(last ? 0 : 1)
                    .disabled(last)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .frame(height: 44)
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                    pageView(item).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            Button {
                Feedback.tap()
                if last {
                    finish()
                } else {
                    withAnimation { page += 1 }
                }
            } label: {
                Text(last ? tr("Get started") : tr("Next"))
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundColor(.white)
                    .glassTile(Capsule(), isOn: true)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .background(GlassBackdrop().ignoresSafeArea())
    }

    private func pageView(_ item: Page) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: item.symbol)
                    .font(.system(size: 64, weight: .medium))
                    .foregroundColor(item.color)
                    .frame(height: 96)
                    .padding(.top, 24)
                Text(item.title)
                    .font(.largeTitle.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(item.text)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(Array(item.points.enumerated()), id: \.offset) { _, point in
                        HStack(spacing: 14) {
                            IconTile(symbol: point.symbol, color: item.color)
                            Text(point.text).fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 40)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
    }
}

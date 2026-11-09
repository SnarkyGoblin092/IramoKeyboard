import SwiftUI

/// The editor of the chosen theme (Native, Transparent or Liquid Glass): the corners and key style, how solid the
/// keys are and a glow on the labels (SystemThemeSections). Every change is saved at once, so the pinned keyboard
/// above and the keyboard itself follow it.
struct ThemeEditorView: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme

    @AppStorage(SettingKey.appearance, store: SharedStore.defaults) private var appearance = SettingDefault.appearance
    private let modes = ["auto", "light", "dark"]

    private var theme: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    var body: some View {
        PinnedPreview(height: 240, fills: true) {
            LiveKeyboard()
        } content: {
        GlassList {
            Section {
                SegmentedChoice(names: [tr("Auto"), tr("Light"), tr("Dark")],
                                selected: modes.firstIndex(of: appearance)) { appearance = modes[$0] }
            } header: {
                SectionHeader(tr("Mode"), symbol: "circle.lefthalf.filled", color: .teal)
            } footer: {
                Text(tr("Light and Dark keep the keyboard in that mode. Auto follows the app you are typing in."))
            }
            .glassRows()
            SystemThemeSections(theme: theme)
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Customize %@", "\(theme.name)"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

import SwiftUI

/// The editor of the chosen theme (Native, Transparent or Liquid Glass): the corners and key style, how solid the
/// keys are and a glow on the labels (SystemThemeSections). Every change is saved at once, so the pinned keyboard
/// above and the keyboard itself follow it.
struct ThemeEditorView: View {
    @AppStorage(SettingKey.theme, store: SharedStore.defaults) private var themeID = SettingDefault.theme

    private var theme: ThemeDefinition { return ThemeCatalog.theme(id: themeID) }

    var body: some View {
        PinnedPreview(height: 240, fills: true) {
            LiveKeyboard()
        } content: {
        GlassList {
            SystemThemeSections(theme: theme)
        }
        .scrollContentBackground(.hidden)
        }
        .navigationTitle(tr("Customize %@", "\(theme.name)"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

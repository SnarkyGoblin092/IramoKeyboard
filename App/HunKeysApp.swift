import SwiftUI

@main
struct HunKeysApp: App {
    init() {
        _ = Settings.shared   // registers the default values
        _ = UINavigationController.installWave   // screens change with the wave
        HunKeysApp.useRoundedBarFonts()
    }

    /// The navigation bar's titles are UIKit text that `fontDesign` doesn't reach: give them the app's rounded type too.
    private static func useRoundedBarFonts() {
        func rounded(_ style: UIFont.TextStyle, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: UIFont.preferredFont(forTextStyle: style).pointSize, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.rounded) else { return base }
            return UIFont(descriptor: descriptor, size: base.pointSize)
        }
        let bar = UINavigationBar.appearance()
        let attributes: [NSAttributedString.Key: Any] = [.font: rounded(.headline, .semibold)]
        let largeAttributes: [NSAttributedString.Key: Any] = [.font: rounded(.largeTitle, .bold)]
        bar.titleTextAttributes = attributes
        bar.largeTitleTextAttributes = largeAttributes
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

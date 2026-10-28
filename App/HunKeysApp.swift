import SwiftUI

@main
struct HunKeysApp: App {
    init() {
        _ = Settings.shared   // registers the default values
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

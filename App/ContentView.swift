import SwiftUI

/// The container app only exists to carry the keyboard extension. It explains how to turn the
/// keyboard on and gives you a text field to try it in. All keyboard options live inside the
/// keyboard itself (gear button, top left of the keyboard).
struct ContentView: View {
    @State private var sample = ""

    var body: some View {
        NavigationStack {
            List {
                Section("1. Add the keyboard") {
                    Text("Settings > General > Keyboard > Keyboards > Add New Keyboard… > HunKeys")
                    Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                }

                Section("2. Allow Full Access (for vibration)") {
                    Text("Tap HunKeys in the keyboard list and switch on Allow Full Access. iOS only lets keyboards vibrate when this is on. HunKeys has no networking code and never sends anything anywhere.")
                }

                Section("3. Try it") {
                    TextField("Tap here, then hold the globe key to pick HunKeys", text: $sample, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Using the keyboard") {
                    Text("Globe key: tap = switch English / Magyar, hold = next keyboard on your phone.")
                    Text("Hold a letter to see its accents (Hungarian only shows Hungarian accents).")
                    Text("Slide a finger across the letters to swipe-type.")
                    Text("Gear button (top left of the keyboard): hold delay, vibration strength and more.")
                }
            }
            .navigationTitle("HunKeys")
        }
    }
}

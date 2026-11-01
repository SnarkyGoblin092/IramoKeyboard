import SwiftUI

/// The keyboard's Functions panel (the button at the left of the suggestion bar): which tools it shows and in
/// what order. Tools move up or down, swipe left to remove, and come back from the list under them.
struct FunctionsView: View {
    @State private var tools: [KeyboardTool] = []

    private var isPad: Bool { return UIDevice.current.userInterfaceIdiom == .pad }

    /// The tools not on the panel (split only on an iPad).
    private var others: [KeyboardTool] {
        return KeyboardTool.allCases.filter { !tools.contains($0) && ($0 != .split || isPad) }
    }

    var body: some View {
        GlassList {
            Section {
                if tools.isEmpty {
                    Text("No functions yet: add some below.").foregroundColor(.secondary)
                } else {
                    ForEach(tools, id: \.self) { tool in
                        let index = tools.firstIndex(of: tool) ?? 0
                        HStack(spacing: 12) {
                            ToolRow(tool: tool)
                            Spacer(minLength: 8)
                            VStack(spacing: 2) {
                                arrow("chevron.up", enabled: index > 0) { move(index, by: -1) }
                                arrow("chevron.down", enabled: index < tools.count - 1) { move(index, by: 1) }
                            }
                        }
                        .swipeToDelete { remove(tool) }
                    }
                }
            } header: {
                SectionHeader("On the panel", symbol: "square.grid.2x2.fill", color: .pink)
            } footer: {
                Text("Tap the grid button at the left of the suggestion bar to open the panel; the order here is the "
                     + "panel's, left to right and row by row. Swipe a function left to remove it.")
            }
            .glassRows()

            if !others.isEmpty {
                Section {
                    ForEach(others, id: \.self) { tool in
                        Button {
                            add(tool)
                        } label: {
                            HStack(spacing: 12) {
                                ToolRow(tool: tool)
                                Spacer(minLength: 8)
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.tint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    SectionHeader("Add", symbol: "plus", color: .green)
                } footer: {
                    Text("Copy, cut, paste, the clipboard and vibration need Full Access.")
                }
                .glassRows()
            }

            Section {
                Button("Restore the standard functions") {
                    Feedback.choose()
                    save(KeyboardTool.standard)
                }
                .disabled(tools == KeyboardTool.standard)
            }
            .glassRows()
        }
        .glassScreen()
        .navigationTitle("Functions panel")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            tools = KeyboardTool.list(from: SharedStore.defaults.stringArray(forKey: SettingKey.keyboardTools)
                                      ?? SettingDefault.keyboardTools)
        }
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .frame(width: 30, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .accessibilityLabel(symbol == "chevron.up" ? "Move up" : "Move down")
    }

    private func move(_ index: Int, by step: Int) {
        let target = index + step
        guard target >= 0, target < tools.count else { return }
        Feedback.tick()
        var list = tools
        list.swapAt(index, target)
        save(list)
    }

    private func add(_ tool: KeyboardTool) {
        Feedback.success()
        save(tools + [tool])
    }

    private func remove(_ tool: KeyboardTool) {
        Feedback.delete()
        save(tools.filter { $0 != tool })
    }

    private func save(_ list: [KeyboardTool]) {
        withAnimation(.easeOut(duration: 0.2)) { tools = list }
        SharedStore.defaults.set(list.map { $0.rawValue }, forKey: SettingKey.keyboardTools)
    }
}

/// A tool's icon, name and what it does.
private struct ToolRow: View {
    let tool: KeyboardTool

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: tool.symbol, color: .pink)
            VStack(alignment: .leading, spacing: 2) {
                Text(tool.title).foregroundColor(.primary)
                Text(tool.subtitle).font(.footnote).foregroundColor(.secondary)
            }
        }
    }
}

import SwiftUI

/// The keyboard's Functions panel (the button at the left of the suggestion bar): which tools it shows and in
/// what order. Tools move up or down, swipe left to remove, and come back from the list under them.
struct FunctionsView: View {
    /// The panel's tools as this device shows them (split only on an iPad).
    @State private var tools: [KeyboardTool] = []
    /// The stored list has split, which an iPhone does not show but keeps for the iPad.
    @State private var keepsSplit = false

    private var isPad: Bool { return UIDevice.current.userInterfaceIdiom == .pad }

    /// The tools not on the panel (split only on an iPad).
    private var others: [KeyboardTool] {
        return KeyboardTool.allCases.filter { !tools.contains($0) && ($0 != .split || isPad) }
    }

    var body: some View {
        GlassList {
            Section {
                if tools.isEmpty {
                    Text(tr("No functions yet: add some below.")).foregroundColor(.secondary)
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
                SectionHeader(tr("On the panel"), symbol: "square.grid.2x2.fill", color: .pink)
            } footer: {
                Text(tr("Tap the grid button at the left of the suggestion bar to open the panel; the order here is the panel's, left to right and row by row. Swipe a function left to remove it."))
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
                    SectionHeader(tr("Add"), symbol: "plus", color: .green)
                } footer: {
                    Text(tr("Copy, cut, paste, the clipboard and vibration need Full Access."))
                }
                .glassRows()
            }

            Section {
                Button(tr("Restore the standard functions")) {
                    Feedback.choose()
                    keepsSplit = !isPad
                    save(KeyboardTool.standard.filter { $0 != .split || isPad })
                }
                .disabled(tools == KeyboardTool.standard.filter { $0 != .split || isPad })
            }
            .glassRows()
        }
        .glassScreen()
        .navigationTitle(tr("Functions panel"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let stored = KeyboardTool.list(from: SharedStore.defaults.stringArray(forKey: SettingKey.keyboardTools)
                                           ?? SettingDefault.keyboardTools)
            keepsSplit = !isPad && stored.contains(.split)
            tools = stored.filter { $0 != .split || isPad }
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
        .accessibilityLabel(symbol == "chevron.up" ? tr("Move up") : tr("Move down"))
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
        let stored = keepsSplit && !list.contains(.split) ? list + [.split] : list
        SharedStore.defaults.set(stored.map { $0.rawValue }, forKey: SettingKey.keyboardTools)
    }
}

/// A tool's icon, name and what it does.
private struct ToolRow: View {
    let tool: KeyboardTool

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: tool.symbol, color: .pink)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr(tool.title)).foregroundColor(.primary)
                Text(tr(tool.subtitle)).font(.footnote).foregroundColor(.secondary)
            }
        }
    }
}

import SwiftUI
import UniformTypeIdentifiers

/// The keyboard's Functions panel (the button at the left of the suggestion bar): which tools it shows and in
/// what order. Hold a tool and drag it: within the panel's list to reorder, onto it from the list under it to add
/// it, or back down to take it off.
struct FunctionsView: View {
    /// The panel's tools (split shows everywhere; an iPhone splits only in landscape).
    @State private var tools: [KeyboardTool] = []
    /// The tool being dragged (it moves between and within the lists as it passes over their rows).
    @State private var dragging: KeyboardTool?

    /// The tools not on the panel.
    private var others: [KeyboardTool] {
        return KeyboardTool.allCases.filter { !tools.contains($0) }
    }

    var body: some View {
        GlassList {
            Section {
                if tools.isEmpty {
                    dropZone(tr("No functions yet: drag some here from below."), onPanel: true)
                } else {
                    ForEach(tools, id: \.self) { tool in
                        draggableRow(tool, onPanel: true)
                    }
                }
            } header: {
                SectionHeader(tr("On the panel"), symbol: "square.grid.2x2.fill", color: .pink)
            } footer: {
                Text(tr("Tap the grid button at the left of the suggestion bar to open the panel; the order here is the panel's, left to right and row by row. Hold a function and drag it to move it."))
            }
            .glassRows()

            Section {
                if others.isEmpty {
                    dropZone(tr("Every function is on the panel. Drag one here to take it off."), onPanel: false)
                } else {
                    ForEach(others, id: \.self) { tool in
                        draggableRow(tool, onPanel: false)
                    }
                }
            } header: {
                SectionHeader(tr("Not on the panel"), symbol: "square.dashed", color: .gray)
            } footer: {
                Text(tr("Drag a function up to add it to the panel, or down here to take it off. Copy, cut, paste and vibration need Full Access."))
            }
            .glassRows()

            Section {
                // Red: it throws the panel as it was arranged away.
                Button(role: .destructive) {
                    Feedback.delete()
                    save(KeyboardTool.standard)
                } label: {
                    Label(tr("Restore the standard functions"), systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(ActionButtonStyle())
                .disabled(tools == KeyboardTool.standard)
                .glassOutsideCard()
            }
            .glassRows()
        }
        .glassScreen()
        // A drag let go anywhere else ends too.
        .onDrop(of: [UTType.text], isTargeted: nil) { _ in
            dragging = nil
            return false
        }
        .navigationTitle(tr("Functions panel"))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            let stored = KeyboardTool.list(from: SharedStore.defaults.stringArray(forKey: SettingKey.keyboardTools)
                                           ?? SettingDefault.keyboardTools)
            tools = stored
        }
    }

    /// A tool's row: held, it is dragged; another tool dragged over it takes its place.
    private func draggableRow(_ tool: KeyboardTool, onPanel: Bool) -> some View {
        HStack(spacing: 10) {
            ToolRow(tool: tool)
            Spacer(minLength: 4)
            // A tap does what a drag between the lists does, for those who would rather not drag.
            Button {
                toggle(tool, onPanel: onPanel)
            } label: {
                Image(systemName: onPanel ? "minus.circle.fill" : "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(onPanel ? .red : .green)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(onPanel ? tr("Remove") : tr("Add"))
            if onPanel {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(Color(.tertiaryLabel))
                    .accessibilityHidden(true)
            }
        }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opacity(dragging == tool ? 0.35 : 1)
            .onDrag {
                dragging = tool
                Feedback.choose()
                return NSItemProvider(object: tool.rawValue as NSString)
            }
            .onDrop(of: [UTType.text], delegate: ToolDrop(enter: { move(onto: tool, onPanel: onPanel) },
                                                          end: { dragging = nil }))
    }

    /// The row an empty list shows, which takes the dragged tool.
    private func dropZone(_ text: String, onPanel: Bool) -> some View {
        Text(text)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .onDrop(of: [UTType.text], delegate: ToolDrop(enter: { move(onto: nil, onPanel: onPanel) },
                                                          end: { dragging = nil }))
    }

    /// The dragged tool passes over `target` (nil: an empty list): on the panel it takes the target's place (added
    /// if it was not there); in the other list it comes off the panel.
    private func move(onto target: KeyboardTool?, onPanel: Bool) {
        guard let tool = dragging, tool != target else { return }
        var list = tools
        if onPanel {
            let to = target.flatMap { list.firstIndex(of: $0) } ?? list.count
            if let from = list.firstIndex(of: tool) {
                guard from != to else { return }
                list.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
            } else {
                list.insert(tool, at: to)
            }
        } else {
            guard list.contains(tool) else { return }
            list.removeAll { $0 == tool }
        }
        Feedback.tick()
        save(list)
    }

    /// The row's button: takes the tool off the panel, or puts it at the panel's end.
    private func toggle(_ tool: KeyboardTool, onPanel: Bool) {
        var list = tools
        if onPanel {
            list.removeAll { $0 == tool }
            Feedback.delete()
        } else {
            list.append(tool)
            Feedback.success()
        }
        save(list)
    }

    private func save(_ list: [KeyboardTool]) {
        withAnimation(.easeOut(duration: 0.2)) { tools = list }
        SharedStore.defaults.set(list.map { $0.rawValue }, forKey: SettingKey.keyboardTools)
    }
}

/// Moves the dragged tool as it enters a row, and ends the drag when it is let go there.
private struct ToolDrop: DropDelegate {
    let enter: () -> Void
    let end: () -> Void

    func dropEntered(info: DropInfo) { enter() }

    func dropUpdated(info: DropInfo) -> DropProposal? { return DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        end()
        return true
    }
}

/// A tool's icon, name and what it does.
private struct ToolRow: View {
    let tool: KeyboardTool

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: tool.symbol, color: .indigo)
            VStack(alignment: .leading, spacing: 2) {
                Text(tr(tool.title)).foregroundColor(.primary)
                Text(tr(tool.subtitle)).font(.footnote).foregroundColor(.secondary)
            }
        }
    }
}

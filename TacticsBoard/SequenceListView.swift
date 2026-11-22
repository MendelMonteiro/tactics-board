import SwiftUI
import TacticsCore

/// The launch screen: a grid of saved sequences, one tap from the board.
struct SequenceListView: View {
    @EnvironmentObject private var library: LibraryModel

    @State private var path: [BoardRoute] = []
    @State private var showNew = false
    @State private var showSquad = false
    @State private var renaming: TacticsSequence?
    @State private var renameText = ""
    @State private var deleting: TacticsSequence?

    var body: some View {
        NavigationStack(path: $path) {
            content
                .navigationTitle("Tactics Board")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button("Squad", systemImage: "person.3") { showSquad = true }
                        Button("New sequence", systemImage: "plus") { showNew = true }
                    }
                }
                .navigationDestination(for: BoardRoute.self) { route in
                    BoardLoader(route: route)
                }
        }
        .sheet(isPresented: $showSquad) {
            NavigationStack { SquadView() }
                .environmentObject(library)
        }
        .sheet(isPresented: $showNew) {
            NewSequenceView(
                onCreated: { id in
                    showNew = false
                    path.append(BoardRoute(sequenceID: id, startInEdit: true))
                },
                onOpenSquad: {
                    showNew = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { showSquad = true }
                })
                .environmentObject(library)
        }
        .alert(
            "Rename sequence",
            isPresented: Binding(
                get: { renaming != nil },
                set: { shown in if !shown { renaming = nil } }
            ),
            actions: {
                TextField("Name", text: $renameText)
                Button("Save") {
                    if let target = renaming {
                        library.renameSequence(id: target.id, to: renameText)
                    }
                    renaming = nil
                }
                Button("Cancel", role: .cancel) { renaming = nil }
            }
        )
        .alert(
            "Delete sequence?",
            isPresented: Binding(
                get: { deleting != nil },
                set: { shown in if !shown { deleting = nil } }
            ),
            actions: {
                Button("Delete", role: .destructive) {
                    if let target = deleting {
                        library.deleteSequence(id: target.id)
                    }
                    deleting = nil
                }
                Button("Cancel", role: .cancel) { deleting = nil }
            },
            message: {
                Text("\"\(deleting?.name ?? "")\" will be removed. This can't be undone.")
            }
        )
        .libraryAlert(library, isActive: path.isEmpty && !showSquad && !showNew)
    }

    @ViewBuilder
    private var content: some View {
        if library.data.sequences.isEmpty {
            ContentUnavailableView(
                "No sequences yet",
                systemImage: "sportscourt",
                description: Text("Add your players under Squad, then tap + to make your first sequence."))
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 20)], spacing: 20) {
                    ForEach(library.data.sequences) { sequence in
                        card(for: sequence)
                    }
                }
                .padding(20)
            }
        }
    }

    private func card(for sequence: TacticsSequence) -> some View {
        NavigationLink(value: BoardRoute(sequenceID: sequence.id, startInEdit: false)) {
            VStack(alignment: .leading, spacing: 8) {
                SequencePreview(sequence: sequence, squad: library.squadByID)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                Text(sequence.name)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("\(sequence.format.displayName) · \(sequence.steps.count) \(sequence.steps.count == 1 ? "step" : "steps")")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Rename", systemImage: "pencil") {
                renameText = sequence.name
                renaming = sequence
            }
            Button("Duplicate", systemImage: "plus.square.on.square") {
                library.duplicateSequence(id: sequence.id)
            }
            Button("Delete", systemImage: "trash", role: .destructive) {
                deleting = sequence
            }
        }
    }
}

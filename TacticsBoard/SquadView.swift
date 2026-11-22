import SwiftUI
import TacticsCore

struct SquadView: View {
    @EnvironmentObject private var library: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @State private var blockedMessage: String?

    var body: some View {
        List {
            Section {
                ForEach(library.data.squad) { player in
                    SquadRow(player: player)
                }
                .onDelete { offsets in
                    let players = library.data.squad
                    for index in offsets where players.indices.contains(index) {
                        if let message = library.removePlayer(id: players[index].id) {
                            blockedMessage = message
                        }
                    }
                }
            } footer: {
                let duplicates = library.data.duplicateNumbers
                if !duplicates.isEmpty {
                    Text("Shirt number \(duplicates.map { String($0) }.joined(separator: ", ")) is used more than once.")
                        .foregroundStyle(.orange)
                }
            }

            Section {
                Button("Add player", systemImage: "plus") {
                    library.addNextPlayer()
                }
            }
        }
        .navigationTitle("Squad")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
        .alert(
            "Can't remove player",
            isPresented: Binding(
                get: { blockedMessage != nil },
                set: { shown in if !shown { blockedMessage = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(blockedMessage ?? "") }
        )
        .libraryAlert(library)
    }
}

/// One squad player: a number field and a name field. The text lives in the row so
/// you can clear a field while typing a new value.
struct SquadRow: View {
    @EnvironmentObject private var library: LibraryModel
    let player: SquadPlayer
    @State private var numberText: String
    @State private var nameText: String

    init(player: SquadPlayer) {
        self.player = player
        _numberText = State(initialValue: String(player.number))
        _nameText = State(initialValue: player.name)
    }

    var body: some View {
        HStack(spacing: 16) {
            TextField("No.", text: $numberText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.title3.bold())
                .frame(width: 64)
                .onChange(of: numberText) { _, newValue in
                    if let number = Int(newValue) {
                        var updated = player
                        updated.number = number
                        library.updatePlayer(updated)
                    }
                }
            TextField("Name", text: $nameText)
                .onChange(of: nameText) { _, newValue in
                    var updated = player
                    updated.name = newValue
                    library.updatePlayer(updated)
                }
        }
        .padding(.vertical, 4)
    }
}

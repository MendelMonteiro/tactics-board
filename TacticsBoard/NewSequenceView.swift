import SwiftUI
import TacticsCore

struct NewSequenceView: View {
    @EnvironmentObject private var library: LibraryModel
    @Environment(\.dismiss) private var dismiss

    let onCreated: (UUID) -> Void
    let onOpenSquad: () -> Void

    @State private var name = ""
    @State private var format: MatchFormat = .seven
    @State private var selected: Set<UUID> = []

    private var squad: [SquadPlayer] { library.data.squad }
    private var needed: Int { format.playersPerSide }
    private var canCreate: Bool { selected.count == needed && squad.count >= needed }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("For example: Goal kick, play out left", text: $name)
                }

                Section("Format") {
                    Picker("Format", selection: $format) {
                        ForEach(MatchFormat.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Starting players: \(selected.count) of \(needed)") {
                    if squad.count < needed {
                        Text("Add at least \(needed) players to your squad")
                            .foregroundStyle(.secondary)
                        Button("Open squad") { onOpenSquad() }
                    } else {
                        ForEach(squad) { player in
                            Button {
                                toggle(player.id)
                            } label: {
                                HStack(spacing: 14) {
                                    Text("\(player.number)")
                                        .font(.title3.bold())
                                        .frame(width: 44)
                                    Text(player.name)
                                    Spacer()
                                    if selected.contains(player.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(Theme.home)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("New sequence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") { create() }
                        .disabled(!canCreate)
                }
            }
            .onAppear { resetStarters() }
            .onChange(of: format) { _, _ in resetStarters() }
        }
    }

    /// The first N squad players are ticked already.
    private func resetStarters() {
        selected = Set(squad.prefix(needed).map { $0.id })
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }

    private func create() {
        let starters = squad.filter { selected.contains($0.id) }.map { $0.id }
        if let id = library.makeSequence(name: name, format: format, starters: starters) {
            onCreated(id)
        }
    }
}

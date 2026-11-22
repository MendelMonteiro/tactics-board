import SwiftUI
import TacticsCore

struct AppAlert: Equatable {
    var title: String
    var message: String
}

extension LibraryStorage {
    /// library.json in Application Support/TacticsBoard (created if missing when saving).
    static func appDefault() -> LibraryStorage {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return LibraryStorage(directory: base.appendingPathComponent("TacticsBoard", isDirectory: true))
    }
}

/// The squad and sequences, loaded at launch. Every change goes through here and is
/// saved straight away. A save failure is shown as an alert.
final class LibraryModel: ObservableObject {
    @Published private(set) var data: Library
    @Published var alert: AppAlert?

    private let storage: LibraryStorage
    private let savingAllowed: Bool
    private let blockedMessage: String

    init(storage: LibraryStorage = .appDefault()) {
        self.storage = storage
        let result = storage.load()
        self.data = result.library
        self.savingAllowed = result.savingAllowed
        self.blockedMessage = result.notice ?? "Changes can't be saved right now."
        if let notice = result.notice {
            self.alert = AppAlert(title: "Saved data", message: notice)
        }
    }

    var squadByID: [UUID: SquadPlayer] {
        Dictionary(data.squad.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Squad

    func addNextPlayer() {
        let used = Set(data.squad.map { $0.number })
        let number = (1...99).first(where: { !used.contains($0) }) ?? 99
        var copy = data
        copy.addPlayer(SquadPlayer(name: "Player \(data.squad.count + 1)", number: number))
        commit(copy)
    }

    func updatePlayer(_ player: SquadPlayer) {
        var copy = data
        copy.updatePlayer(player)
        commit(copy)
    }

    /// Returns a message if the player can't be removed, otherwise nil.
    func removePlayer(id: UUID) -> String? {
        var copy = data
        do {
            try copy.removePlayer(id: id)
        } catch LibraryError.playerInUse(let names) {
            return "Used in: \(names.joined(separator: ", ")). Remove them from those sequences first."
        } catch {
            return "That player can't be removed."
        }
        commit(copy)
        return nil
    }

    // MARK: Sequences

    func sequence(id: UUID) -> TacticsSequence? {
        data.sequences.first(where: { $0.id == id })
    }

    /// Returns the new sequence's id, or nil (with an alert) if it couldn't be made.
    func makeSequence(name: String, format: MatchFormat, starters: [UUID]) -> UUID? {
        var copy = data
        do {
            let sequence = try copy.makeSequence(name: name, format: format, starters: starters)
            commit(copy)
            return sequence.id
        } catch LibraryError.notEnoughPlayers(let needed, let available) {
            alert = AppAlert(
                title: "Not enough players",
                message: "\(format.displayName) needs \(needed) players, but \(available) were chosen.")
        } catch {
            alert = AppAlert(title: "Couldn't create sequence", message: "\(error)")
        }
        return nil
    }

    func saveSequence(_ sequence: TacticsSequence) {
        var copy = data
        copy.save(sequence)
        commit(copy)
    }

    func renameSequence(id: UUID, to name: String) {
        var copy = data
        copy.renameSequence(id: id, to: name)
        commit(copy)
    }

    func duplicateSequence(id: UUID) {
        var copy = data
        copy.duplicateSequence(id: id)
        commit(copy)
    }

    func deleteSequence(id: UUID) {
        var copy = data
        copy.deleteSequence(id: id)
        commit(copy)
    }

    // MARK: Saving

    private func commit(_ library: Library) {
        data = library
        guard savingAllowed else {
            alert = AppAlert(title: "Not saved", message: blockedMessage)
            return
        }
        do {
            try storage.save(library)
        } catch {
            alert = AppAlert(
                title: "Not saved",
                message: "Your changes couldn't be saved: \(error.localizedDescription)")
        }
    }
}

extension View {
    /// Shows the library's alert (a save error, or the one-time notice about a damaged file).
    /// `isActive` lets a screen that is covered by another stop showing it.
    func libraryAlert(_ library: LibraryModel, isActive: Bool = true) -> some View {
        alert(
            library.alert?.title ?? "",
            isPresented: Binding(
                get: { isActive && library.alert != nil },
                set: { shown in if !shown { library.alert = nil } }
            ),
            actions: { Button("OK", role: .cancel) {} },
            message: { Text(library.alert?.message ?? "") }
        )
    }
}

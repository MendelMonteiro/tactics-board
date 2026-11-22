import Foundation

public struct SquadPlayer: Hashable, Codable, Identifiable, Sendable {
    public static let numberRange = 1...99

    public var id: UUID
    public var name: String
    /// Shirt numbers are kept within 1...99.
    public var number: Int {
        didSet {
            let clamped = SquadPlayer.clampNumber(number)
            if clamped != number { number = clamped }
        }
    }

    public init(id: UUID = UUID(), name: String, number: Int) {
        self.id = id
        self.name = name
        self.number = SquadPlayer.clampNumber(number)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, number
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decode(UUID.self, forKey: .id)
        let name = try container.decode(String.self, forKey: .name)
        let number = try container.decode(Int.self, forKey: .number)
        self.init(id: id, name: name, number: number)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(number, forKey: .number)
    }

    static func clampNumber(_ value: Int) -> Int {
        min(max(value, numberRange.lowerBound), numberRange.upperBound)
    }
}

public enum LibraryError: Error, Equatable, Sendable {
    /// The player appears in these saved sequences.
    case playerInUse(sequenceNames: [String])
    case notEnoughPlayers(needed: Int, available: Int)
    case unknownPlayer(UUID)
}

/// The squad and the saved sequences.
public struct Library: Equatable, Codable, Sendable {
    public var squad: [SquadPlayer]
    public var sequences: [TacticsSequence]

    public init(squad: [SquadPlayer] = [], sequences: [TacticsSequence] = []) {
        self.squad = squad
        self.sequences = sequences
    }

    // MARK: Squad

    public func player(id: UUID) -> SquadPlayer? {
        squad.first(where: { $0.id == id })
    }

    public mutating func addPlayer(_ player: SquadPlayer) {
        squad.append(player)
    }

    public mutating func updatePlayer(_ player: SquadPlayer) {
        if let index = squad.firstIndex(where: { $0.id == player.id }) {
            squad[index] = player
        }
    }

    public func sequencesUsing(playerID: UUID) -> [TacticsSequence] {
        sequences.filter { $0.setup.home.contains(where: { $0.id == playerID }) }
    }

    /// Refused while any sequence uses the player, naming those sequences.
    public mutating func removePlayer(id: UUID) throws {
        let users = sequencesUsing(playerID: id)
        guard users.isEmpty else {
            throw LibraryError.playerInUse(sequenceNames: users.map { $0.name })
        }
        squad.removeAll(where: { $0.id == id })
    }

    /// Shirt numbers used more than once, in ascending order, for a warning.
    public var duplicateNumbers: [Int] {
        var counts: [Int: Int] = [:]
        for player in squad {
            counts[player.number, default: 0] += 1
        }
        return counts.filter { $0.value > 1 }.map { $0.key }.sorted()
    }

    // MARK: Sequences

    /// Makes a sequence with the first N starters in the format's formation, the opposition
    /// numbered from 1 and a loose ball on the centre spot, and adds it to the library.
    @discardableResult
    public mutating func makeSequence(name: String, format: MatchFormat,
                                      starters: [UUID]) throws -> TacticsSequence {
        let needed = format.playersPerSide
        guard starters.count >= needed else {
            throw LibraryError.notEnoughPlayers(needed: needed, available: starters.count)
        }
        let ids = Array(starters.prefix(needed))
        for id in ids where player(id: id) == nil {
            throw LibraryError.unknownPlayer(id)
        }

        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let sequence = TacticsSequence(
            name: trimmed.isEmpty ? "Untitled" : trimmed,
            setup: BoardState.kickoff(format: format, homeIDs: ids)
        )
        sequences.append(sequence)
        return sequence
    }

    /// Replaces any existing sequence with the same id, otherwise appends.
    public mutating func save(_ sequence: TacticsSequence) {
        if let index = sequences.firstIndex(where: { $0.id == sequence.id }) {
            sequences[index] = sequence
        } else {
            sequences.append(sequence)
        }
    }

    public mutating func renameSequence(id: UUID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = sequences.firstIndex(where: { $0.id == id }) else { return }
        sequences[index].name = trimmed
    }

    /// A copy with a new id, named "<name> copy", placed straight after the original.
    @discardableResult
    public mutating func duplicateSequence(id: UUID) -> TacticsSequence? {
        guard let index = sequences.firstIndex(where: { $0.id == id }) else { return nil }
        var copy = sequences[index]
        copy.id = UUID()
        copy.name = "\(copy.name) copy"
        sequences.insert(copy, at: index + 1)
        return copy
    }

    public mutating func deleteSequence(id: UUID) {
        sequences.removeAll(where: { $0.id == id })
    }
}

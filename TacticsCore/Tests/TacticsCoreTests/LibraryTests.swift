import Testing
import Foundation
@testable import TacticsCore

@Suite struct LibraryTests {
    /// A library with `count` squad players numbered from 1.
    private func makeLibrary(players count: Int) -> Library {
        var library = Library()
        for number in 1...count {
            library.addPlayer(SquadPlayer(name: "Player \(number)", number: number))
        }
        return library
    }

    @Test func renamingAPlayerShowsEverywhereBecauseSequencesStoreIDs() throws {
        var library = makeLibrary(players: 8)
        let sequence = try library.makeSequence(
            name: "Goal kick", format: .seven, starters: library.squad.map { $0.id })
        let id = sequence.setup.home[0].id
        var renamed = library.player(id: id)!
        renamed.name = "Sam"
        library.updatePlayer(renamed)
        #expect(library.player(id: sequence.homePlayerIDs[0])?.name == "Sam")
    }

    @Test func removingAPlayerUsedInASequenceIsRefused() throws {
        var library = makeLibrary(players: 8)
        try library.makeSequence(name: "Goal kick", format: .seven,
                                 starters: library.squad.map { $0.id })
        let used = library.squad[0].id
        var thrown: LibraryError?
        do {
            try library.removePlayer(id: used)
        } catch let error as LibraryError {
            thrown = error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(thrown == .playerInUse(sequenceNames: ["Goal kick"]))
        #expect(library.squad.count == 8)
    }

    @Test func removingAnUnusedPlayerWorks() throws {
        var library = makeLibrary(players: 8)
        try library.makeSequence(name: "Goal kick", format: .seven,
                                 starters: library.squad.map { $0.id })
        let spare = library.squad[7].id
        try library.removePlayer(id: spare)
        #expect(library.squad.count == 7)
    }

    @Test func duplicateShirtNumbersAreReported() {
        var library = makeLibrary(players: 3)
        library.addPlayer(SquadPlayer(name: "Another", number: 1))
        library.addPlayer(SquadPlayer(name: "Third", number: 1))
        #expect(library.duplicateNumbers == [1])
        library.squad[0].number = 7
        library.squad[3].number = 7
        #expect(library.duplicateNumbers == [7])
    }

    @Test func shirtNumbersAreKeptWithinOneToNinetyNine() {
        var player = SquadPlayer(name: "A", number: 150)
        #expect(player.number == 99)
        player.number = 0
        #expect(player.number == 1)
    }

    @Test func aSequenceNeedsEnoughStarters() {
        var library = makeLibrary(players: 6)
        var thrown: LibraryError?
        do {
            try library.makeSequence(name: "Too few", format: .seven,
                                     starters: library.squad.map { $0.id })
        } catch let error as LibraryError {
            thrown = error
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        #expect(thrown == .notEnoughPlayers(needed: 7, available: 6))
        #expect(library.sequences.isEmpty)
    }

    @Test func aNewSequenceUsesTheFormationAndPutsTheBallOnTheCentreSpot() throws {
        var library = makeLibrary(players: 8)
        let starters = library.squad.map { $0.id }
        let sequence = try library.makeSequence(name: "Kick off", format: .seven, starters: starters)
        #expect(sequence.setup.home.map { $0.id } == Array(starters.prefix(7)))
        let formation = MatchFormat.seven.homeFormation
        for (slot, expected) in zip(sequence.setup.home, formation) {
            #expect(slot.position == expected)
        }
        #expect(sequence.setup.away.map { $0.number } == Array(1...7))
        #expect(sequence.setup.ball == .loose(PitchPoint(x: 0.5, y: 0.5)))
        #expect(library.sequences.count == 1)
    }

    @Test func aBlankNameBecomesUntitled() throws {
        var library = makeLibrary(players: 7)
        let sequence = try library.makeSequence(name: "   ", format: .seven,
                                                starters: library.squad.map { $0.id })
        #expect(sequence.name == "Untitled")
    }

    @Test func duplicatingCopiesTheStepsAndGivesANewID() throws {
        var library = makeLibrary(players: 7)
        var original = try library.makeSequence(name: "Corner", format: .seven,
                                                starters: library.squad.map { $0.id })
        original.steps = [.move(.player(.home(original.homePlayerIDs[1])),
                                to: PitchPoint(x: 0.3, y: 0.3))]
        library.save(original)

        let copy = library.duplicateSequence(id: original.id)
        #expect(copy != nil)
        #expect(copy?.id != original.id)
        #expect(copy?.name == "Corner copy")
        #expect(copy?.steps == original.steps)
        #expect(library.sequences.count == 2)
    }

    @Test func savingReplacesASequenceWithTheSameID() throws {
        var library = makeLibrary(players: 7)
        var sequence = try library.makeSequence(name: "Corner", format: .seven,
                                                starters: library.squad.map { $0.id })
        sequence.name = "Corner, near post"
        library.save(sequence)
        #expect(library.sequences.count == 1)
        #expect(library.sequences[0].name == "Corner, near post")
    }

    @Test func deletingRemovesASequence() throws {
        var library = makeLibrary(players: 7)
        let sequence = try library.makeSequence(name: "Corner", format: .seven,
                                                starters: library.squad.map { $0.id })
        library.deleteSequence(id: sequence.id)
        #expect(library.sequences.isEmpty)
    }

    @Test func theSquadHoldsAtLeastSixteenPlayers() {
        let library = makeLibrary(players: 16)
        #expect(library.squad.count == 16)
    }
}

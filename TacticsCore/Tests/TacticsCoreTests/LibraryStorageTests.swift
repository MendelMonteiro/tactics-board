import Testing
import Foundation
@testable import TacticsCore

@Suite struct LibraryStorageTests {
    private func sampleLibrary() throws -> Library {
        var library = Library()
        for number in 1...8 {
            library.addPlayer(SquadPlayer(name: "Player \(number)", number: number))
        }
        var sequence = try library.makeSequence(name: "Goal kick", format: .seven,
                                                starters: library.squad.map { $0.id })
        let ids = sequence.homePlayerIDs
        sequence.setup.ball = .held(.home(ids[6]))
        sequence.steps = [
            .move(.player(.home(ids[1])), to: PitchPoint(x: 0.3, y: 0.3)),
            .pass(from: .home(ids[6]), to: .player(.home(ids[5]))),
            .shoot(from: .home(ids[5]), at: PitchPoint(x: 0.95, y: 0.4)),
        ]
        library.save(sequence)
        return library
    }

    @Test func aMissingFileLoadsAsAnEmptyLibrary() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = LibraryStorage(directory: folder).load()
        #expect(result.library == Library())
        #expect(result.savingAllowed)
        #expect(result.notice == nil)
    }

    @Test func saveThenLoadGivesTheSameLibrary() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = LibraryStorage(directory: folder)
        let library = try sampleLibrary()
        try storage.save(library)
        let result = storage.load()
        #expect(result.library == library)
        #expect(result.savingAllowed)
    }

    @Test func savingCreatesTheFolderIfItIsMissing() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let nested = folder.appendingPathComponent("Application Support/Tactics")
        let storage = LibraryStorage(directory: nested)
        try storage.save(Library())
        #expect(FileManager.default.fileExists(atPath: storage.fileURL.path))
    }

    @Test func aDamagedFileIsKeptAndLoadingGivesAnEmptyLibrary() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = LibraryStorage(directory: folder)
        try "not json".write(to: storage.fileURL, atomically: true, encoding: .utf8)

        let result = storage.load()
        #expect(result.library == Library())
        #expect(result.notice != nil)
        let moved = try #require(result.movedAsideTo)
        #expect(moved.lastPathComponent.contains(".corrupt-"))
        #expect(try String(contentsOf: moved, encoding: .utf8) == "not json")
        #expect(FileManager.default.fileExists(atPath: storage.fileURL.path) == false)
    }

    @Test func editingStepByStepSurvivesEachSaveAndLoad() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = LibraryStorage(directory: folder)

        var library = Library()
        library.addPlayer(SquadPlayer(name: "Alex", number: 9))
        try storage.save(library)
        #expect(storage.load().library == library)

        for number in 1...7 {
            library.addPlayer(SquadPlayer(name: "P\(number)", number: number))
        }
        var sequence = try library.makeSequence(name: "Kick off", format: .seven,
                                                starters: library.squad.suffix(7).map { $0.id })
        try storage.save(library)
        #expect(storage.load().library == library)

        sequence.steps.append(.move(.player(.home(sequence.homePlayerIDs[2])),
                                    to: PitchPoint(x: 0.4, y: 0.4)))
        library.save(sequence)
        try storage.save(library)
        #expect(storage.load().library == library)
    }
}

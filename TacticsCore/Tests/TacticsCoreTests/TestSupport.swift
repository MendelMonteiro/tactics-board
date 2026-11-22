import Foundation
import CoreGraphics
@testable import TacticsCore

func approxEqual(_ a: Double, _ b: Double, tolerance: Double = 1e-9) -> Bool {
    abs(a - b) <= tolerance
}

func approxEqual(_ a: PitchPoint, _ b: PitchPoint, tolerance: Double = 1e-9) -> Bool {
    approxEqual(a.x, b.x, tolerance: tolerance) && approxEqual(a.y, b.y, tolerance: tolerance)
}

/// A 7-a-side board in the default formations, with seven new squad ids and the ball
/// loose on the centre spot. `home(n)` and `away(n)` are numbered from 1.
struct Fixture {
    let ids: [UUID]
    var board: BoardState

    init(format: MatchFormat = .seven) {
        let ids = (0..<format.playersPerSide).map { _ in UUID() }
        self.ids = ids
        self.board = BoardState.kickoff(format: format, homeIDs: ids)
    }

    func home(_ number: Int) -> PlayerRef { .home(ids[number - 1]) }
    func away(_ number: Int) -> PlayerRef { .away(number - 1) }

    func sequence(name: String = "Test", steps: [Step] = []) -> TacticsSequence {
        TacticsSequence(name: name, setup: board, steps: steps)
    }

    /// `count` steps that are always valid: home player 1 running to different points.
    func moveSteps(_ count: Int) -> [Step] {
        (0..<count).map { index in
            Step.move(.player(home(1)), to: PitchPoint(x: 0.1 + 0.1 * Double(index), y: 0.5))
        }
    }

    func editor(steps: Int = 0, mode: EditorMode = .edit) -> SequenceEditor {
        SequenceEditor(sequence: sequence(steps: moveSteps(steps)), mode: mode)
    }
}

func temporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("TacticsCoreTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

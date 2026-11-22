import Testing
import Foundation
@testable import TacticsCore

@Suite struct BoardTests {
    @Test func dribbleCarriesTheBall() throws {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let next = try fx.board.applying(.move(.player(fx.home(7)), to: PitchPoint(x: 0.8, y: 0.5)))
        #expect(approxEqual(next.ballPosition, PitchPoint(x: 0.8, y: 0.5)))
        #expect(next.holder == fx.home(7))
    }

    @Test func movingOntoALooseBallPicksItUp() throws {
        let fx = Fixture()
        let next = try fx.board.applying(.move(.player(fx.home(7)), to: PitchPoint(x: 0.505, y: 0.5)))
        #expect(next.holder == fx.home(7))
    }

    @Test func movingFarFromALooseBallLeavesItWhereItWas() throws {
        let fx = Fixture()
        let next = try fx.board.applying(.move(.player(fx.home(7)), to: PitchPoint(x: 0.7, y: 0.5)))
        #expect(next.ball == .loose(PitchPoint(x: 0.5, y: 0.5)))
    }

    @Test func passToATeammateMovesPossession() throws {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let next = try fx.board.applying(.pass(from: fx.home(7), to: .player(fx.home(6))))
        #expect(next.holder == fx.home(6))
    }

    @Test func passIntoSpaceLeavesTheBallLoose() throws {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let target = PitchPoint(x: 0.7, y: 0.2)
        let next = try fx.board.applying(.pass(from: fx.home(7), to: .space(target)))
        #expect(next.ball == .loose(target))
    }

    @Test func interceptionGivesTheBallToTheOpposition() throws {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let next = try fx.board.applying(.pass(from: fx.home(7), to: .player(fx.away(4))))
        #expect(next.holder == fx.away(4))
    }

    @Test func passWithoutTheBallIsRejected() {
        let fx = Fixture()
        #expect(throws: StepError.noBall) {
            try fx.board.applying(.pass(from: fx.home(7), to: .player(fx.home(6))))
        }
    }

    @Test func shotWhileTheBallIsLooseIsRejected() {
        let fx = Fixture()
        #expect(throws: StepError.noBall) {
            try fx.board.applying(.shoot(from: fx.home(7), at: PitchPoint(x: 0.9, y: 0.5)))
        }
    }

    @Test func passToSelfIsRejected() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        #expect(throws: StepError.passToSelf) {
            try fx.board.applying(.pass(from: fx.home(7), to: .player(fx.home(7))))
        }
    }

    @Test func unknownPlayerIsRejected() {
        let fx = Fixture()
        let tenth = PlayerRef.away(9)
        #expect(throws: StepError.unknownPlayer(tenth)) {
            try fx.board.applying(.move(.player(tenth), to: PitchPoint(x: 0.5, y: 0.5)))
        }
    }

    @Test func shotEndsInTheGoalMouth() throws {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let next = try fx.board.applying(.shoot(from: fx.home(7), at: PitchPoint(x: 0.9, y: 0.0)))
        let expected = PitchPoint(x: 1, y: 0.5 - 1.83 / 37)
        guard case .loose(let end) = next.ball else {
            Issue.record("The ball should be loose after a shot")
            return
        }
        #expect(approxEqual(end, expected))
    }

    @Test func shotInTheHomeHalfGoesToTheHomeGoal() {
        let fx = Fixture()
        let end = fx.board.shotTarget(tap: PitchPoint(x: 0.2, y: 0.5))
        #expect(end.x == 0)
    }

    @Test func ballPlacedNextToAPlayerGivesThemPossession() throws {
        let fx = Fixture()
        let next = try fx.board.applying(.move(.ball, to: PitchPoint(x: 0.455, y: 0.5)))
        #expect(next.holder == fx.home(7))
    }

    @Test func ballPlacedInOpenSpaceIsLoose() throws {
        let fx = Fixture()
        let target = PitchPoint(x: 0.6, y: 0.1)
        let next = try fx.board.applying(.move(.ball, to: target))
        #expect(next.ball == .loose(target))
    }

    @Test func applyingAStepDoesNotChangeTheOriginal() throws {
        let fx = Fixture()
        let before = fx.board
        _ = try fx.board.applying(.move(.player(fx.home(7)), to: PitchPoint(x: 0.8, y: 0.5)))
        #expect(fx.board == before)
    }
}

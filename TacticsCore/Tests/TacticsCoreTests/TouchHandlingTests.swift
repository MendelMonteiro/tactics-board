import Testing
import Foundation
import CoreGraphics
@testable import TacticsCore

@Suite struct TouchHandlingTests {
    private let screen = CGSize(width: 1180, height: 820)

    private func make(_ fx: Fixture, tool: EditTool = .move, selection: Piece? = nil)
        -> (layout: PitchLayout, touch: TouchInterpreter) {
        let layout = PitchLayout(format: fx.board.format, in: screen)
        return (layout, TouchInterpreter(layout: layout, board: fx.board, tool: tool, selection: selection))
    }

    private func point(_ layout: PitchLayout, _ fx: Fixture, _ ref: PlayerRef) -> CGPoint {
        layout.screenPoint(for: fx.board.position(of: ref)!)
    }

    private func dragTarget(_ outcome: TouchOutcome) -> (piece: Piece, point: PitchPoint)? {
        if case .edit(.drag(let piece, let target)) = outcome { return (piece, target) }
        return nil
    }

    @Test func draggingAPieceMovesIt() {
        let fx = Fixture()
        let (layout, touch) = make(fx)
        let start = point(layout, fx, fx.home(3))
        let end = CGPoint(x: start.x + 150, y: start.y + 20)
        let outcome = touch.end(touch.begin(at: start), at: end)
        let drag = dragTarget(outcome)
        #expect(drag?.piece == .player(fx.home(3)))
        #expect(approxEqual(drag!.point, layout.pitchPoint(for: end), tolerance: 1e-9))
    }

    @Test func draggingTheGrassDoesNothing() {
        let fx = Fixture()
        let (layout, touch) = make(fx)
        let start = layout.screenPoint(for: PitchPoint(x: 0.65, y: 0.1))
        let outcome = touch.end(touch.begin(at: start), at: CGPoint(x: start.x + 100, y: start.y))
        #expect(outcome == .none)
    }

    @Test func tappingAPlayerSelectsThem() {
        let fx = Fixture()
        let (layout, touch) = make(fx)
        let spot = point(layout, fx, fx.home(3))
        #expect(touch.end(touch.begin(at: spot), at: spot) == .select(.player(fx.home(3))))
    }

    @Test func tappingAnotherPlayerSwitchesTheSelection() {
        let fx = Fixture()
        let (layout, touch) = make(fx, selection: .player(fx.home(3)))
        let spot = point(layout, fx, fx.home(4))
        #expect(touch.end(touch.begin(at: spot), at: spot) == .select(.player(fx.home(4))))
    }

    @Test func tappingTheGrassMovesTheSelectedPiece() {
        let fx = Fixture()
        let (layout, touch) = make(fx, selection: .player(fx.home(3)))
        let grass = layout.screenPoint(for: PitchPoint(x: 0.65, y: 0.1))
        let drag = dragTarget(touch.end(touch.begin(at: grass), at: grass))
        #expect(drag?.piece == .player(fx.home(3)))
        #expect(approxEqual(drag!.point, PitchPoint(x: 0.65, y: 0.1), tolerance: 1e-6))
    }

    @Test func tappingTheBallMovesTheSelectedPlayerOntoIt() {
        let fx = Fixture()
        let (layout, touch) = make(fx, selection: .player(fx.home(3)))
        let ball = layout.screenPoint(for: PitchPoint.centre)
        let drag = dragTarget(touch.end(touch.begin(at: ball), at: ball))
        #expect(drag?.piece == .player(fx.home(3)))
        #expect(drag?.point == fx.board.ballPosition)
    }

    @Test func tappingTheBallWithNothingSelectedSelectsTheBall() {
        let fx = Fixture()
        let (layout, touch) = make(fx)
        let ball = layout.screenPoint(for: PitchPoint.centre)
        #expect(touch.end(touch.begin(at: ball), at: ball) == .select(.ball))
    }

    @Test func aPassPreviewFollowsThePlayerUnderTheFingerNow() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let (layout, touch) = make(fx, tool: .pass)
        var gesture = touch.begin(at: point(layout, fx, fx.home(7)))
        #expect(touch.preview(for: gesture) == nil)   // still on the holder

        gesture.update(to: point(layout, fx, fx.home(5)))
        let onTeammate = touch.preview(for: gesture)
        #expect(onTeammate == .pass(from: fx.board.position(of: fx.home(7))!,
                                    to: fx.board.position(of: fx.home(5))!,
                                    receiver: fx.home(5)))

        gesture.update(to: layout.screenPoint(for: PitchPoint(x: 0.65, y: 0.1)))
        if case .pass(_, _, let receiver)? = touch.preview(for: gesture) {
            #expect(receiver == nil)
        } else {
            Issue.record("Expected a pass preview into space")
        }
    }

    @Test func aShotPreviewShowsTheGhostBallInTheGoalMouth() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let (layout, touch) = make(fx, tool: .shoot)
        let tap = layout.screenPoint(for: PitchPoint(x: 0.9, y: 0.0))
        let gesture = touch.begin(at: tap)
        guard case .shot(_, let end)? = touch.preview(for: gesture) else {
            Issue.record("Expected a shot preview")
            return
        }
        #expect(approxEqual(end, PitchPoint(x: 1, y: 0.5 - 1.83 / 37), tolerance: 1e-6))
    }

    @Test func shootingRecordsTheTappedPoint() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let (layout, touch) = make(fx, tool: .shoot)
        let tap = layout.screenPoint(for: PitchPoint(x: 0.9, y: 0.45))
        let outcome = touch.end(touch.begin(at: tap), at: tap)
        guard case .edit(.addStep(.shoot(let from, let at))) = outcome else {
            Issue.record("Expected a shoot step")
            return
        }
        #expect(from == fx.home(7))
        #expect(approxEqual(at, PitchPoint(x: 0.9, y: 0.45), tolerance: 1e-6))
    }

    @Test func passAndShootWithNobodyHoldingTheBallGiveAHint() {
        let fx = Fixture()
        for tool in [EditTool.pass, .shoot] {
            let (layout, touch) = make(fx, tool: tool)
            let spot = layout.screenPoint(for: PitchPoint(x: 0.65, y: 0.1))
            if case .hint = touch.end(touch.begin(at: spot), at: spot) {
                continue
            }
            Issue.record("Expected a hint for \(tool)")
        }
    }
}

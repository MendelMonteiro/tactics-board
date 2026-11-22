import Testing
import Foundation
import CoreGraphics
@testable import TacticsCore

/// One test (at least) for each fix from the final review that the core can check.
/// B3.9 (save errors on the board) and B3.10 (the bottom bar) are screen-only.
@Suite struct ReviewFixesTests {
    private let screen = CGSize(width: 1180, height: 820)

    private func make(_ fx: Fixture, tool: EditTool, selection: Piece? = nil)
        -> (layout: PitchLayout, touch: TouchInterpreter) {
        let layout = PitchLayout(format: fx.board.format, in: screen)
        return (layout, TouchInterpreter(layout: layout, board: fx.board, tool: tool, selection: selection))
    }

    // B3.1
    @Test func tappingTheHolderWithPassSelectedShowsAHintAndRecordsNothing() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let (layout, touch) = make(fx, tool: .pass)
        let holder = layout.screenPoint(for: fx.board.position(of: fx.home(7))!)
        let outcome = touch.end(touch.begin(at: holder), at: holder)
        #expect(outcome == .hint("Now tap a teammate or an open space."))
    }

    @Test func tappingTheHeldBallWithPassSelectedAlsoShowsTheHint() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let (layout, touch) = make(fx, tool: .pass)
        let drawnBall = layout.drawnBallPoint(for: Frame(board: fx.board))
        let outcome = touch.end(touch.begin(at: drawnBall), at: drawnBall)
        #expect(outcome == .hint("Now tap a teammate or an open space."))
    }

    // B3.2
    @Test func draggingFromThePasserToATeammateMakesThatTeammateTheReceiver() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let (layout, touch) = make(fx, tool: .pass)
        let from = layout.screenPoint(for: fx.board.position(of: fx.home(7))!)
        let to = layout.screenPoint(for: fx.board.position(of: fx.home(5))!)
        let outcome = touch.end(touch.begin(at: from), at: to)
        #expect(outcome == .edit(.addStep(.pass(from: fx.home(7), to: .player(fx.home(5))))))
    }

    @Test func theReceiverIsWhoeverIsUnderTheFingerWhenItLiftsNotWhereItLanded() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let (layout, touch) = make(fx, tool: .pass)
        let grass = layout.screenPoint(for: PitchPoint(x: 0.65, y: 0.1))
        let teammate = layout.screenPoint(for: fx.board.position(of: fx.home(5))!)
        let outcome = touch.end(touch.begin(at: grass), at: teammate)
        #expect(outcome == .edit(.addStep(.pass(from: fx.home(7), to: .player(fx.home(5))))))
    }

    @Test func liftingOnOpenGrassPassesIntoSpaceAtThatPoint() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let (layout, touch) = make(fx, tool: .pass)
        let from = layout.screenPoint(for: fx.board.position(of: fx.home(7))!)
        let grass = layout.screenPoint(for: PitchPoint(x: 0.65, y: 0.1))
        let outcome = touch.end(touch.begin(at: from), at: grass)
        guard case .edit(.addStep(.pass(let passer, .space(let target)))) = outcome else {
            Issue.record("Expected a pass into space")
            return
        }
        #expect(passer == fx.home(7))
        #expect(approxEqual(target, PitchPoint(x: 0.65, y: 0.1), tolerance: 1e-6))
    }

    // B3.3
    @Test func duringSetupDraggingAPlayerOntoTheLooseBallGivesThemTheBall() {
        let fx = Fixture()
        var editor = fx.editor()
        // New sequences start with the ball loose on the centre spot.
        #expect(editor.sequence.setup.ball == .loose(PitchPoint.centre))
        let result = editor.propose(.drag(.player(fx.home(7)), to: PitchPoint(x: 0.505, y: 0.5)))
        #expect(result == .applied)
        #expect(editor.sequence.setup.holder == fx.home(7))
    }

    // B3.4
    @Test func pickupReachIsThreePointFivePercentOfThePitchLength() {
        #expect(approxEqual(MatchFormat.seven.pickupReachMetres, 0.035 * 55))
        #expect(approxEqual(MatchFormat.eleven.pickupReachMetres, 0.035 * 105))
        #expect(approxEqual(MatchFormat.five.pickupReachMetres, 0.035 * 37))
    }

    @Test func aPlayerThreeMetresAwayPicksUpTheBallOnAnElevenASidePitchButNotAFixedReach() throws {
        let fx = Fixture(format: .eleven)
        // 3 m across a 68 m width. The old fixed 1.5 m reach would have missed this.
        let target = PitchPoint(x: 0.5, y: 0.5 + 3.0 / 68.0)
        let next = try fx.board.applying(.move(.player(fx.home(11)), to: target))
        #expect(next.holder == fx.home(11))
    }

    @Test func aPlayerBeyondTheReachDoesNotPickUpTheBall() throws {
        let fx = Fixture()
        // 7-a-side reach is 1.925 m. This is 2.2 m away.
        let target = PitchPoint(x: 0.5 + 2.2 / 55.0, y: 0.5)
        let next = try fx.board.applying(.move(.player(fx.home(7)), to: target))
        #expect(next.holder == nil)
    }

    // B3.5
    @Test func everyNewTouchStartsAFreshGesture() {
        let fx = Fixture()
        let (layout, touch) = make(fx, tool: .move)
        let playerSpot = layout.screenPoint(for: fx.board.position(of: fx.home(3))!)

        var first = touch.begin(at: playerSpot)
        first.update(to: CGPoint(x: playerSpot.x + 200, y: playerSpot.y))
        #expect(first.didDrag)
        #expect(first.grabbed == .player(fx.home(3)))

        let grass = layout.screenPoint(for: PitchPoint(x: 0.65, y: 0.1))
        let second = touch.begin(at: grass)
        #expect(second.didDrag == false)
        #expect(second.grabbed == nil)
        #expect(second.start == grass)
        #expect(second.current == grass)
    }

    // B3.6
    @Test func tappingTheSelectedPieceDeselectsItWithoutAZeroLengthMove() {
        let fx = Fixture()
        let (layout, touch) = make(fx, tool: .move, selection: .player(fx.home(3)))
        let spot = layout.screenPoint(for: fx.board.position(of: fx.home(3))!)
        let outcome = touch.end(touch.begin(at: spot), at: spot)
        #expect(outcome == .select(nil))
    }

    @Test func aSmallWobbleWhileTappingStillCountsAsATap() {
        let fx = Fixture()
        let (layout, touch) = make(fx, tool: .move, selection: .player(fx.home(3)))
        let spot = layout.screenPoint(for: fx.board.position(of: fx.home(3))!)
        let outcome = touch.end(touch.begin(at: spot), at: CGPoint(x: spot.x + 3, y: spot.y + 2))
        #expect(outcome == .select(nil))
    }

    // B3.7
    @Test func aFileThatExistsButCannotBeReadBlocksSaving() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = LibraryStorage(directory: folder)
        // A directory where the file should be: it exists, but reading it fails.
        try FileManager.default.createDirectory(at: storage.fileURL, withIntermediateDirectories: false)

        let result = storage.load()
        #expect(result.savingAllowed == false)
        #expect(result.notice != nil)
        #expect(result.library == Library())
    }

    @Test func aFailedMoveBlocksSavingAndNeverTouchesTheOriginalFile() throws {
        struct MoveFailed: Error {}
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let storage = LibraryStorage(directory: folder, moveItem: { _, _ in throw MoveFailed() })
        try "not json".write(to: storage.fileURL, atomically: true, encoding: .utf8)

        let result = storage.load()
        #expect(result.savingAllowed == false)
        #expect(result.notice != nil)
        #expect(result.movedAsideTo == nil)
        #expect(try String(contentsOf: storage.fileURL, encoding: .utf8) == "not json")
    }

    @Test func aMissingFileIsTheOnlyCaseThatLoadsEmptyAndStillAllowsSaving() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let result = LibraryStorage(directory: folder).load()
        #expect(result.savingAllowed)
        #expect(result.notice == nil)
    }

    @Test func theMovedAsideFileNameCarriesATimestamp() throws {
        let folder = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: folder) }
        let fixedDate = Date(timeIntervalSince1970: 1_800_000_000)
        let storage = LibraryStorage(directory: folder, now: { fixedDate })
        try "not json".write(to: storage.fileURL, atomically: true, encoding: .utf8)

        let moved = try #require(storage.load().movedAsideTo)
        #expect(moved.lastPathComponent.hasPrefix("library.json.corrupt-"))
        #expect(moved.lastPathComponent.count > "library.json.corrupt-".count)
    }

    // B3.8
    @Test func aSavedSequenceOpensInViewModeOnTheSetupAndEditJumpsToTheLastStep() {
        let fx = Fixture()
        var editor = SequenceEditor(sequence: fx.sequence(steps: fx.moveSteps(3)))
        #expect(editor.mode == .view)
        #expect(editor.cursor == 0)
        #expect(editor.board == fx.board)

        editor.enterEditMode()
        #expect(editor.mode == .edit)
        #expect(editor.cursor == 3)
    }

    @Test func aNewSequenceOpensStraightIntoEditMode() {
        let fx = Fixture()
        let editor = SequenceEditor(sequence: fx.sequence(), mode: .edit)
        #expect(editor.mode == .edit)
        #expect(editor.cursor == 0)
    }

    // Damaged steps
    @Test func openingASequenceDropsStepsFromTheFirstInvalidOneOnwards() {
        let fx = Fixture()
        let steps: [Step] = [
            .move(.player(fx.home(2)), to: PitchPoint(x: 0.3, y: 0.3)),
            .pass(from: fx.home(7), to: .player(fx.home(6))),   // nobody has the ball
            .move(.player(fx.home(3)), to: PitchPoint(x: 0.4, y: 0.4)),
        ]
        let editor = SequenceEditor(sequence: fx.sequence(steps: steps))
        #expect(editor.stepCount == 1)
    }
}

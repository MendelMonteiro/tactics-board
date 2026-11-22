import Testing
import Foundation
@testable import TacticsCore

@Suite struct SequenceTests {
    @Test func survivesSavingToJSONAndLoadingBack() throws {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let sequence = fx.sequence(name: "Goal kick", steps: [
            .pass(from: fx.home(7), to: .player(fx.home(6))),
            .move(.player(fx.home(6)), to: PitchPoint(x: 0.7, y: 0.6)),
            .shoot(from: fx.home(6), at: PitchPoint(x: 0.95, y: 0.5)),
        ])
        let data = try JSONEncoder().encode(sequence)
        let loaded = try JSONDecoder().decode(TacticsSequence.self, from: data)
        #expect(loaded == sequence)
        #expect(loaded.usableStepCount == 3)
    }

    @Test func boardListStopsBeforeTheFirstInvalidStep() {
        let fx = Fixture()
        let sequence = fx.sequence(steps: [
            .move(.player(fx.home(7)), to: PitchPoint(x: 0.6, y: 0.5)),            // valid
            .pass(from: fx.home(7), to: .player(fx.home(6))),                       // no ball
            .move(.player(fx.home(2)), to: PitchPoint(x: 0.3, y: 0.3)),            // valid
        ])
        #expect(sequence.boards().count == 2)
        #expect(sequence.usableStepCount == 1)
    }

    @Test func droppingInvalidStepsKeepsOnlyTheUsableOnes() {
        let fx = Fixture()
        var sequence = fx.sequence(steps: [
            .move(.player(fx.home(7)), to: PitchPoint(x: 0.6, y: 0.5)),
            .pass(from: fx.home(7), to: .player(fx.home(6))),
        ])
        sequence.dropInvalidSteps()
        #expect(sequence.steps.count == 1)
    }
}

@Suite struct SequenceEditorTests {
    @Test func viewModeRefusesEditsAndUndo() {
        let fx = Fixture()
        var editor = fx.editor(steps: 2, mode: .view)
        let step = Step.move(.player(fx.home(2)), to: PitchPoint(x: 0.3, y: 0.3))
        let addResult = editor.propose(.addStep(step))
        let dragResult = editor.propose(.drag(.player(fx.home(2)), to: PitchPoint(x: 0.3, y: 0.3)))
        let undone = editor.undo()
        #expect(addResult == .refusedInViewMode)
        #expect(dragResult == .refusedInViewMode)
        #expect(undone == false)
        #expect(editor.stepCount == 2)
    }

    @Test func addingAtTheEndAppendsAndMovesTheCursor() {
        let fx = Fixture()
        var editor = fx.editor()
        let result = editor.propose(.addStep(.move(.player(fx.home(2)), to: PitchPoint(x: 0.3, y: 0.3))))
        #expect(result == .applied)
        #expect(editor.stepCount == 1)
        #expect(editor.cursor == 1)
    }

    @Test func addingEarlierAsksToReplaceTheLaterSteps() {
        let fx = Fixture()
        var editor = fx.editor(steps: 5)
        editor.jump(to: 2)
        let result = editor.propose(.addStep(.move(.player(fx.home(2)), to: PitchPoint(x: 0.3, y: 0.3))))
        #expect(result == .needsConfirmation(replacing: 3...5))
        #expect(editor.pending != nil)
        #expect(editor.stepCount == 5)
    }

    @Test func confirmingReplacesTheLaterSteps() {
        let fx = Fixture()
        var editor = fx.editor(steps: 5)
        editor.jump(to: 2)
        editor.propose(.addStep(.move(.player(fx.home(2)), to: PitchPoint(x: 0.3, y: 0.3))))
        let confirmed = editor.confirmPending()
        #expect(confirmed)
        #expect(editor.stepCount == 3)
        #expect(editor.cursor == 3)
        #expect(editor.pending == nil)
    }

    @Test func cancellingChangesNothing() {
        let fx = Fixture()
        var editor = fx.editor(steps: 5)
        editor.jump(to: 2)
        editor.propose(.addStep(.move(.player(fx.home(2)), to: PitchPoint(x: 0.3, y: 0.3))))
        editor.cancelPending()
        #expect(editor.stepCount == 5)
        #expect(editor.cursor == 2)
        #expect(editor.pending == nil)
    }

    @Test func aPassWithoutTheBallIsRefused() {
        let fx = Fixture()
        var editor = fx.editor()
        let result = editor.propose(.addStep(.pass(from: fx.home(7), to: .player(fx.home(6)))))
        #expect(result == .rejected(.noBall))
        #expect(editor.stepCount == 0)
    }

    @Test func draggingWithNoStepsChangesTheSetup() {
        let fx = Fixture()
        var editor = fx.editor()
        let target = PitchPoint(x: 0.3, y: 0.3)
        let result = editor.propose(.drag(.player(fx.home(2)), to: target))
        #expect(result == .applied)
        #expect(editor.stepCount == 0)
        #expect(editor.sequence.setup.position(of: fx.home(2)) == target)
    }

    @Test func draggingOnTheSetupWithStepsAsksToReplaceAllOfThem() {
        let fx = Fixture()
        var editor = fx.editor(steps: 3)
        editor.jump(to: 0)
        let result = editor.propose(.drag(.player(fx.home(2)), to: PitchPoint(x: 0.3, y: 0.3)))
        #expect(result == .needsConfirmation(replacing: 1...3))
        let confirmed = editor.confirmPending()
        #expect(confirmed)
        #expect(editor.stepCount == 0)
        #expect(editor.sequence.setup.position(of: fx.home(2)) == PitchPoint(x: 0.3, y: 0.3))
    }

    @Test func draggingOnALaterStepIsRecordedAsAMove() {
        let fx = Fixture()
        var editor = fx.editor(steps: 1)
        let target = PitchPoint(x: 0.3, y: 0.3)
        let result = editor.propose(.drag(.player(fx.home(2)), to: target))
        #expect(result == .applied)
        #expect(editor.stepCount == 2)
        #expect(editor.sequence.steps.last == .move(.player(fx.home(2)), to: target))
    }

    @Test func undoRemovesTheLastStep() {
        let fx = Fixture()
        var editor = fx.editor(steps: 3)
        let undone = editor.undo()
        #expect(undone)
        #expect(editor.stepCount == 2)
        #expect(editor.cursor == 2)
    }

    @Test func undoWithNoStepsDoesNothing() {
        let fx = Fixture()
        var editor = fx.editor()
        let undone = editor.undo()
        #expect(undone == false)
    }

    @Test func jumpingIsClampedToTheSequence() {
        let fx = Fixture()
        var editor = fx.editor(steps: 4)
        editor.jump(to: 99)
        #expect(editor.cursor == 4)
        editor.jump(to: -1)
        #expect(editor.cursor == 0)
    }

    @Test func passAndShootNeedSomeoneWithTheBall() {
        var fx = Fixture()
        #expect(fx.editor().canPass == false)
        #expect(fx.editor().canShoot == false)
        fx.board.ball = .held(fx.home(7))
        #expect(fx.editor().canPass)
        #expect(fx.editor().canShoot)
    }

    @Test func replacePromptWording() {
        #expect(replacePrompt(for: 3...5) == "Replace steps 3–5?")
        #expect(replacePrompt(for: 2...2) == "Replace step 2?")
    }
}

import SwiftUI
import TacticsCore

struct BoardRoute: Hashable {
    let sequenceID: UUID
    let startInEdit: Bool
}

/// A playback in progress: either the whole sequence or a single step.
struct PlaybackState {
    var timeline: PlaybackTimeline
    var clock: PlaybackClock
    /// The step the board rests on when the playback finishes.
    var target: Int
}

/// All the state of the board screen. The rules and touch logic live in TacticsCore;
/// this just holds the editor, the playback and the current touch.
final class BoardViewModel: ObservableObject {
    @Published private(set) var editor: SequenceEditor
    @Published private(set) var tool: EditTool = .move
    @Published private(set) var selection: Piece?
    @Published private(set) var gesture: EditGesture?
    @Published private(set) var hint: String?
    @Published private(set) var pendingRange: ClosedRange<Int>?
    @Published private(set) var playback: PlaybackState?
    @Published private(set) var playbackStep = 0
    @Published private(set) var speed: PlaybackSpeed = .normal

    private let persist: (TacticsSequence) -> Void
    private var hintToken = 0

    init(sequence: TacticsSequence, startInEdit: Bool, persist: @escaping (TacticsSequence) -> Void) {
        self.editor = SequenceEditor(sequence: sequence, mode: startInEdit ? .edit : .view)
        self.persist = persist
    }

    // MARK: Read-only state for the screen

    var name: String { editor.sequence.name }
    var format: MatchFormat { editor.sequence.format }
    var isEditing: Bool { editor.mode == .edit }
    var stepCount: Int { editor.stepCount }
    var isPlaybackActive: Bool { playback != nil }
    var isPlaybackRunning: Bool { playback?.clock.isRunning ?? false }

    /// The step shown in the dots: the cursor, or the step being played.
    var shownStep: Int { playback == nil ? editor.cursor : playbackStep }

    var canPass: Bool { editor.canPass }
    var canUndo: Bool { editor.canUndo }

    /// The player with the ball is highlighted while Pass or Shoot is selected.
    var highlightedHolder: PlayerRef? {
        guard isEditing, playback == nil, tool != .move else { return nil }
        return editor.board.holder
    }

    /// The step leading to the current one. Hidden while playing.
    var stepArrow: StepArrow? {
        guard playback == nil, editor.cursor > 0 else { return nil }
        let boards = editor.sequence.boards()
        let index = editor.cursor
        guard index < boards.count else { return nil }
        let before = boards[index - 1]
        let after = boards[index]

        switch editor.sequence.steps[index - 1] {
        case .move(let piece, _):
            switch piece {
            case .player(let ref):
                guard let from = before.position(of: ref), let to = after.position(of: ref) else { return nil }
                return StepArrow(from: from, to: to, kind: .run)
            case .ball:
                return StepArrow(from: before.ballPosition, to: after.ballPosition, kind: .run)
            }
        case .pass, .shoot:
            return StepArrow(from: before.ballPosition, to: after.ballPosition, kind: .passOrShot)
        }
    }

    /// What to draw at `now`: the playback frame, or the board at the cursor
    /// with any dragged piece shown under the finger.
    func displayFrame(at now: Double, preview: TouchPreview?) -> Frame {
        if let playback = playback {
            return playback.timeline.frame(at: playback.clock.time(at: now))
        }
        var frame = Frame(board: editor.board)
        if case .dragging(let piece, let point)? = preview {
            switch piece {
            case .ball:
                frame.ball = point
                frame.holder = nil
            case .player(let ref):
                let hadBall = frame.holder == ref
                frame.setPosition(of: ref, to: point)
                if hadBall { frame.ball = point }
            }
        }
        return frame
    }

    func preview(layout: PitchLayout) -> TouchPreview? {
        guard let gesture = gesture else { return nil }
        return interpreter(layout).preview(for: gesture)
    }

    // MARK: Mode

    func enterEdit() {
        stopPlayback()
        editor.enterEditMode()
        tool = .move
        selection = nil
    }

    func leaveEdit() {
        stopPlayback()
        editor.leaveEditMode()
        tool = .move
        selection = nil
        gesture = nil
        pendingRange = nil
    }

    func selectTool(_ newTool: EditTool) {
        guard isEditing, playback == nil else { return }
        if newTool != .move && !editor.canPass { return }
        tool = newTool
        selection = nil
        gesture = nil
    }

    func undo() {
        guard playback == nil else { return }
        if editor.undo() {
            selection = nil
            persist(editor.sequence)
            fixTool()
        }
    }

    // MARK: Navigation and playback

    func jump(to step: Int) {
        stopPlayback()
        editor.jump(to: step)
        selection = nil
        gesture = nil
        fixTool()
    }

    /// Back one step is instant.
    func stepBack() {
        jump(to: max(shownStep - 1, 0))
    }

    /// Forward one step is animated.
    func stepForward(now: Double) {
        let current = shownStep
        guard current < stepCount else { return }
        stopPlayback()
        editor.jump(to: current)
        selection = nil
        gesture = nil
        let timeline = PlaybackTimeline(sequence: editor.sequence, steps: (current + 1)...(current + 1))
        startPlayback(timeline: timeline, target: current + 1, firstStep: current, now: now)
    }

    func togglePlay(now: Double) {
        if playback != nil {
            togglePause(now: now)
            return
        }
        guard stepCount > 0 else { return }
        selection = nil
        gesture = nil
        pendingRange = nil
        editor.cancelPending()
        let timeline = PlaybackTimeline(sequence: editor.sequence)
        startPlayback(timeline: timeline, target: stepCount, firstStep: 0, now: now)
    }

    func cycleSpeed(now: Double) {
        speed = speed.next
        playback?.clock.setSpeed(speed, at: now)
    }

    func stopPlayback() {
        playback = nil
    }

    /// Called every frame while playing, to update the step dots and to finish.
    func tick(now: Double) {
        guard let playback = playback, playback.clock.isRunning else { return }
        let time = playback.clock.time(at: now)
        let step = playback.timeline.stepNumber(at: time)
        if step != playbackStep { playbackStep = step }
        if time >= playback.timeline.duration {
            finishPlayback()
        }
    }

    private func startPlayback(timeline: PlaybackTimeline, target: Int, firstStep: Int, now: Double) {
        var clock = PlaybackClock(speed: speed)
        clock.start(at: now)
        playbackStep = firstStep
        playback = PlaybackState(timeline: timeline, clock: clock, target: target)
    }

    private func togglePause(now: Double) {
        guard playback != nil else { return }
        if playback?.clock.isRunning == true {
            playback?.clock.pause(at: now)
        } else {
            playback?.clock.resume(at: now)
        }
    }

    /// The board rests on the last step played.
    private func finishPlayback() {
        guard let playback = playback else { return }
        self.playback = nil
        editor.jump(to: playback.target)
        fixTool()
    }

    // MARK: Touches

    func touchChanged(location: CGPoint, startLocation: CGPoint, layout: PitchLayout) {
        guard playback == nil, isEditing, pendingRange == nil else { return }
        // Every new touch starts a fresh gesture.
        if var current = gesture, current.start == startLocation {
            current.update(to: location)
            gesture = current
        } else {
            var fresh = interpreter(layout).begin(at: startLocation)
            fresh.update(to: location)
            gesture = fresh
        }
    }

    func touchEnded(location: CGPoint, startLocation: CGPoint, layout: PitchLayout, now: Double) {
        // While a sequence plays, any touch only pauses or resumes it.
        if playback != nil {
            gesture = nil
            togglePause(now: now)
            return
        }
        guard isEditing, pendingRange == nil else {
            gesture = nil
            return
        }

        let touch = interpreter(layout)
        let finished: EditGesture
        if let current = gesture, current.start == startLocation {
            finished = current
        } else {
            finished = touch.begin(at: startLocation)
        }
        gesture = nil
        handle(touch.end(finished, at: location))
    }

    func confirmPending() {
        if editor.confirmPending() {
            persist(editor.sequence)
        }
        pendingRange = nil
        selection = nil
        tool = .move
        fixTool()
    }

    func cancelPending() {
        editor.cancelPending()
        pendingRange = nil
    }

    // MARK: Private

    private func interpreter(_ layout: PitchLayout) -> TouchInterpreter {
        TouchInterpreter(layout: layout, board: editor.board, tool: tool, selection: selection)
    }

    private func handle(_ outcome: TouchOutcome) {
        switch outcome {
        case .none:
            break
        case .select(let piece):
            selection = piece
        case .hint(let text):
            showHint(text)
        case .edit(let edit):
            switch editor.propose(edit) {
            case .applied:
                selection = nil
                tool = .move   // after each step the tool goes back to Move
                persist(editor.sequence)
                fixTool()
            case .needsConfirmation(let range):
                pendingRange = range
            case .rejected(let error):
                showHint(error.hint)
            case .refusedInViewMode:
                break
            }
        }
    }

    /// Pass and Shoot only make sense when somebody has the ball.
    private func fixTool() {
        if tool != .move && !editor.canPass {
            tool = .move
        }
    }

    private func showHint(_ text: String) {
        hint = text
        hintToken += 1
        let token = hintToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self, self.hintToken == token else { return }
            self.hint = nil
        }
    }
}

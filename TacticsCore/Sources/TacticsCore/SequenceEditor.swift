import Foundation

public enum EditorMode: Sendable {
    case view
    case edit
}

/// What the coach wants to do. A drag is sent the same way from the screen whatever
/// the cursor is; the editor decides whether it changes the setup or records a move.
public enum EditorEdit: Equatable, Sendable {
    case addStep(Step)
    case drag(Piece, to: PitchPoint)
}

public enum EditResult: Equatable, Sendable {
    case applied
    /// Steps numbered from 1 that would be thrown away. The edit waits as pending.
    case needsConfirmation(replacing: ClosedRange<Int>)
    case rejected(StepError)
    case refusedInViewMode
}

/// "Replace step 3?" or "Replace steps 3–5?"
public func replacePrompt(for range: ClosedRange<Int>) -> String {
    if range.lowerBound == range.upperBound {
        return "Replace step \(range.lowerBound)?"
    }
    return "Replace steps \(range.lowerBound)–\(range.upperBound)?"
}

/// A sequence plus a mode (view or edit) and a cursor (which step is shown).
/// Cursor 0 is the setup; cursor k is the board after step k.
public struct SequenceEditor: Equatable, Sendable {
    public private(set) var sequence: TacticsSequence
    public private(set) var mode: EditorMode
    public private(set) var cursor: Int
    public private(set) var pending: EditorEdit?

    /// Steps from the first invalid one onwards are dropped when a sequence is opened.
    /// View mode starts on the setup (before step 1). Edit mode starts on the last step.
    public init(sequence: TacticsSequence, mode: EditorMode = .view) {
        var cleaned = sequence
        cleaned.dropInvalidSteps()
        self.sequence = cleaned
        self.mode = mode
        self.cursor = mode == .edit ? cleaned.steps.count : 0
        self.pending = nil
    }

    public var stepCount: Int { sequence.steps.count }

    /// The board at the cursor.
    public var board: BoardState {
        let boards = sequence.boards()
        return boards[min(max(cursor, 0), boards.count - 1)]
    }

    public var canPass: Bool { board.holder != nil }
    public var canShoot: Bool { board.holder != nil }
    public var canUndo: Bool { mode == .edit && !sequence.steps.isEmpty }

    // MARK: Mode and navigation

    /// Pressing Edit jumps to the last step.
    public mutating func enterEditMode() {
        mode = .edit
        cursor = stepCount
        pending = nil
    }

    public mutating func leaveEditMode() {
        mode = .view
        pending = nil
    }

    /// Allowed in both modes. Out-of-range steps land on the nearest end.
    public mutating func jump(to step: Int) {
        cursor = min(max(step, 0), stepCount)
        pending = nil
    }

    // MARK: Editing

    @discardableResult
    public mutating func propose(_ edit: EditorEdit) -> EditResult {
        guard mode == .edit else { return .refusedInViewMode }
        pending = nil

        switch edit {
        case .addStep(let step):
            return addStep(step)

        case .drag(let piece, let target):
            if cursor == 0 {
                switch sequence.setup.apply(.move(piece, to: target)) {
                case .failure(let error):
                    return .rejected(error)
                case .success(let newSetup):
                    if sequence.steps.isEmpty {
                        sequence.setup = newSetup
                        return .applied
                    }
                    pending = edit
                    return .needsConfirmation(replacing: 1...stepCount)
                }
            }
            return addStep(.move(piece, to: target))
        }
    }

    /// Drops the steps after the cursor and applies the pending edit.
    @discardableResult
    public mutating func confirmPending() -> Bool {
        guard mode == .edit, let edit = pending else { return false }
        pending = nil

        switch edit {
        case .addStep(let step):
            guard case .success = board.apply(step) else { return false }
            sequence.steps = Array(sequence.steps.prefix(cursor))
            sequence.steps.append(step)
            cursor = stepCount
            return true

        case .drag(let piece, let target):
            guard cursor == 0,
                  case .success(let newSetup) = sequence.setup.apply(.move(piece, to: target))
            else { return false }
            sequence.steps = []
            sequence.setup = newSetup
            cursor = 0
            return true
        }
    }

    public mutating func cancelPending() {
        pending = nil
    }

    /// Removes the last step and moves the cursor to the end. Refused in view mode.
    @discardableResult
    public mutating func undo() -> Bool {
        guard mode == .edit, !sequence.steps.isEmpty else { return false }
        sequence.steps.removeLast()
        cursor = stepCount
        pending = nil
        return true
    }

    // MARK: Private

    private mutating func addStep(_ step: Step) -> EditResult {
        switch board.apply(step) {
        case .failure(let error):
            return .rejected(error)
        case .success:
            if cursor == stepCount {
                sequence.steps.append(step)
                cursor = stepCount
                return .applied
            }
            pending = .addStep(step)
            return .needsConfirmation(replacing: (cursor + 1)...stepCount)
        }
    }
}

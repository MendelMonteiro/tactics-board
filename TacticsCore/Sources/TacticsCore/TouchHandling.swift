import Foundation
import CoreGraphics

public enum EditTool: Sendable {
    case move
    case pass
    case shoot
}

/// What a finished touch means. The screen code just carries this out.
public enum TouchOutcome: Equatable, Sendable {
    case none
    /// Change the selected piece (nil clears the selection).
    case select(Piece?)
    /// Send this to the editor. The screen clears the selection afterwards.
    case edit(EditorEdit)
    /// A short non-blocking hint.
    case hint(String)
}

/// What to draw while the finger is down.
public enum TouchPreview: Equatable, Sendable {
    /// The dragged piece follows the finger.
    case dragging(Piece, to: PitchPoint)
    /// A pass arrow and a ghost ball at `to`. `receiver` is whoever is under the finger now.
    case pass(from: PitchPoint, to: PitchPoint, receiver: PlayerRef?)
    /// A shot arrow and a ghost ball at `to` (the end of the shot, in the goal mouth).
    case shot(from: PitchPoint, to: PitchPoint)
}

/// One touch, from finger-down to finger-up. A new value is made for every touch,
/// so nothing carries over from a previous gesture.
public struct EditGesture: Equatable, Sendable {
    public static let dragThreshold: CGFloat = 10

    public let start: CGPoint
    public private(set) var current: CGPoint
    /// The piece under the finger when it went down.
    public let grabbed: Piece?
    /// True once the finger has moved far enough to count as a drag.
    public private(set) var didDrag: Bool

    public init(start: CGPoint, grabbed: Piece?) {
        self.start = start
        self.current = start
        self.grabbed = grabbed
        self.didDrag = false
    }

    public mutating func update(to point: CGPoint) {
        current = point
        if hypot(point.x - start.x, point.y - start.y) >= EditGesture.dragThreshold {
            didDrag = true
        }
    }
}

/// Turns touches into edits. Lives in the core so it can be tested without the screen.
public struct TouchInterpreter: Sendable {
    public let layout: PitchLayout
    public let board: BoardState
    public let tool: EditTool
    public let selection: Piece?

    public init(layout: PitchLayout, board: BoardState, tool: EditTool, selection: Piece?) {
        self.layout = layout
        self.board = board
        self.tool = tool
        self.selection = selection
    }

    private var drawn: [DrawnPiece] {
        layout.drawnPieces(for: Frame(board: board))
    }

    /// Starts a fresh gesture for a new touch.
    public func begin(at point: CGPoint) -> EditGesture {
        EditGesture(start: point, grabbed: PitchLayout.nearestPiece(to: point, among: drawn))
    }

    // MARK: Preview (finger down)

    /// The piece under the finger *right now* decides what a pass previews.
    public func preview(for gesture: EditGesture) -> TouchPreview? {
        switch tool {
        case .move:
            guard gesture.didDrag, let piece = gesture.grabbed else { return nil }
            return .dragging(piece, to: layout.pitchPoint(for: gesture.current))

        case .pass:
            guard let holder = board.holder, let from = board.position(of: holder) else { return nil }
            switch pick(at: gesture.current, holder: holder) {
            case .holder:
                return nil
            case .player(let ref):
                guard let to = board.position(of: ref) else { return nil }
                return .pass(from: from, to: to, receiver: ref)
            case .space:
                return .pass(from: from, to: layout.pitchPoint(for: gesture.current), receiver: nil)
            }

        case .shoot:
            guard let holder = board.holder, let from = board.position(of: holder) else { return nil }
            let end = board.shotTarget(tap: layout.pitchPoint(for: gesture.current))
            return .shot(from: from, to: end)
        }
    }

    // MARK: Finish (finger up)

    public func end(_ gesture: EditGesture, at point: CGPoint) -> TouchOutcome {
        var finished = gesture
        finished.update(to: point)

        switch tool {
        case .move:
            return endMove(finished)

        case .pass:
            guard let holder = board.holder else {
                return .hint("Pass needs someone with the ball.")
            }
            // The receiver is whoever is under the finger when it lifts,
            // not where it touched down.
            switch pick(at: finished.current, holder: holder) {
            case .holder:
                return .hint("Now tap a teammate or an open space.")
            case .player(let ref):
                return .edit(.addStep(.pass(from: holder, to: .player(ref))))
            case .space:
                let target = layout.pitchPoint(for: finished.current)
                return .edit(.addStep(.pass(from: holder, to: .space(target))))
            }

        case .shoot:
            guard let holder = board.holder else {
                return .hint("Shoot needs someone with the ball.")
            }
            let tap = layout.pitchPoint(for: finished.current)
            return .edit(.addStep(.shoot(from: holder, at: tap)))
        }
    }

    // MARK: Private

    private enum Pick {
        case holder
        case player(PlayerRef)
        case space
    }

    private func pick(at point: CGPoint, holder: PlayerRef) -> Pick {
        switch PitchLayout.nearestPiece(to: point, among: drawn) {
        case .player(let ref)?:
            return ref == holder ? .holder : .player(ref)
        case .ball?:
            // A held ball belongs to its holder.
            return board.holder != nil ? .holder : .space
        case nil:
            return .space
        }
    }

    /// Move tool: dragging a piece moves it. Tapping selects, tapping the selected piece
    /// deselects, tapping another player switches, and with a piece selected tapping the
    /// ball or the grass moves the piece there.
    private func endMove(_ gesture: EditGesture) -> TouchOutcome {
        if gesture.didDrag {
            guard let piece = gesture.grabbed else { return .none }
            return .edit(.drag(piece, to: layout.pitchPoint(for: gesture.current)))
        }

        if let tapped = gesture.grabbed {
            if selection == tapped {
                return .select(nil)   // no zero-length move
            }
            if let selected = selection, tapped == .ball {
                if case .player(let ref) = selected, board.holder == ref {
                    return .select(nil)   // they already have it
                }
                return .edit(.drag(selected, to: board.ballPosition))
            }
            return .select(tapped)
        }

        if let selected = selection {
            return .edit(.drag(selected, to: layout.pitchPoint(for: gesture.current)))
        }
        return .none
    }
}

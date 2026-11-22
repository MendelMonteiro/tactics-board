import Foundation

/// A named starting setup plus an ordered list of steps.
/// (Not called `Sequence`, which would clash with Swift's own protocol.)
public struct TacticsSequence: Hashable, Codable, Sendable, Identifiable {
    public var id: UUID
    public var name: String
    public var setup: BoardState
    public var steps: [Step]

    public init(id: UUID = UUID(), name: String, setup: BoardState, steps: [Step] = []) {
        self.id = id
        self.name = name
        self.setup = setup
        self.steps = steps
    }

    public var format: MatchFormat { setup.format }

    /// The setup followed by the board after each step.
    /// If a step (for example one loaded from a file) is invalid, the list stops just before it.
    public func boards() -> [BoardState] {
        var result = [setup]
        var current = setup
        for step in steps {
            guard case .success(let next) = current.apply(step) else { break }
            result.append(next)
            current = next
        }
        return result
    }

    /// How many steps are usable.
    public var usableStepCount: Int { boards().count - 1 }

    /// Drops the first invalid step and everything after it.
    public mutating func dropInvalidSteps() {
        let usable = usableStepCount
        if usable < steps.count {
            steps = Array(steps.prefix(usable))
        }
    }

    /// Squad ids of the home players on the pitch.
    public var homePlayerIDs: [UUID] { setup.home.map { $0.id } }
}

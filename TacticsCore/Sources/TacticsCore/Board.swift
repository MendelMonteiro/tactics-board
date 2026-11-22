import Foundation

/// A player on the pitch: a home player (by squad id) or an opposition player
/// (by position in the opposition list).
public enum PlayerRef: Hashable, Codable, Sendable {
    case home(UUID)
    case away(Int)
}

/// Something that can be moved: a player or the ball.
public enum Piece: Hashable, Codable, Sendable {
    case player(PlayerRef)
    case ball
}

public enum BallState: Hashable, Codable, Sendable {
    case held(PlayerRef)
    case loose(PitchPoint)
}

public enum PassTarget: Hashable, Codable, Sendable {
    case player(PlayerRef)
    case space(PitchPoint)
}

/// One action in a sequence. Steps run strictly one after another.
public enum Step: Hashable, Codable, Sendable {
    case move(Piece, to: PitchPoint)
    case pass(from: PlayerRef, to: PassTarget)
    /// `at` is the point the coach tapped; the ball ends in the nearest goal mouth.
    case shoot(from: PlayerRef, at: PitchPoint)
}

public enum StepError: Error, Equatable, Sendable {
    case unknownPlayer(PlayerRef)
    case noBall
    case passToSelf

    /// A short message suitable for a non-blocking hint on screen.
    public var hint: String {
        switch self {
        case .unknownPlayer: return "That player isn't on the pitch."
        case .noBall: return "Only the player with the ball can do that."
        case .passToSelf: return "Now tap a teammate or an open space."
        }
    }
}

public struct HomeSlot: Hashable, Codable, Sendable {
    public var id: UUID
    public var position: PitchPoint

    public init(id: UUID, position: PitchPoint) {
        self.id = id
        self.position = position
    }
}

public struct AwaySlot: Hashable, Codable, Sendable {
    public var number: Int
    public var position: PitchPoint

    public init(number: Int, position: PitchPoint) {
        self.number = number
        self.position = position
    }
}

/// Where everyone and the ball are at one moment.
public struct BoardState: Hashable, Codable, Sendable {
    public var format: MatchFormat
    public var home: [HomeSlot]
    public var away: [AwaySlot]
    public var ball: BallState

    public init(format: MatchFormat, home: [HomeSlot], away: [AwaySlot], ball: BallState) {
        self.format = format
        self.home = home
        self.away = away
        self.ball = ball
    }

    /// Both teams in their default formations (the first N ids are used),
    /// opposition numbered from 1, and a loose ball on the centre spot.
    public static func kickoff(format: MatchFormat, homeIDs: [UUID]) -> BoardState {
        let home = zip(homeIDs, format.homeFormation).map { HomeSlot(id: $0.0, position: $0.1) }
        let away = zip(1..., format.awayFormation).map { AwaySlot(number: $0.0, position: $0.1) }
        return BoardState(format: format, home: home, away: away, ball: .loose(.centre))
    }

    // MARK: Lookup

    public func position(of ref: PlayerRef) -> PitchPoint? {
        switch ref {
        case .home(let id):
            return home.first(where: { $0.id == id })?.position
        case .away(let index):
            return away.indices.contains(index) ? away[index].position : nil
        }
    }

    public func contains(_ ref: PlayerRef) -> Bool {
        position(of: ref) != nil
    }

    /// Who has the ball, if anyone.
    public var holder: PlayerRef? {
        if case .held(let ref) = ball { return ref }
        return nil
    }

    /// Where the ball is. A held ball is with its holder.
    public var ballPosition: PitchPoint {
        switch ball {
        case .loose(let point):
            return point
        case .held(let ref):
            return position(of: ref) ?? PitchPoint.centre
        }
    }

    public var allPlayerPositions: [(ref: PlayerRef, position: PitchPoint)] {
        var result: [(ref: PlayerRef, position: PitchPoint)] = []
        for slot in home {
            result.append((ref: PlayerRef.home(slot.id), position: slot.position))
        }
        for (index, slot) in away.enumerated() {
            result.append((ref: PlayerRef.away(index), position: slot.position))
        }
        return result
    }

    public func shotTarget(tap: PitchPoint) -> PitchPoint {
        format.shotTarget(forTap: tap)
    }

    // MARK: Rules

    /// Applies a step and returns the new board; `self` is not changed.
    public func apply(_ step: Step) -> Result<BoardState, StepError> {
        var next = self

        switch step {
        case .move(let piece, let target):
            switch piece {
            case .player(let ref):
                guard contains(ref) else { return .failure(.unknownPlayer(ref)) }
                next.setPosition(of: ref, to: target)
                // A player who already has the ball keeps it (a dribble).
                // Otherwise they pick up a loose ball they are moved onto.
                if case .loose(let ballPoint) = ball,
                   format.distanceMetres(from: target, to: ballPoint) <= format.pickupReachMetres {
                    next.ball = .held(ref)
                }
            case .ball:
                if let nearest = nearestPlayerWithinReach(of: target) {
                    next.ball = .held(nearest)
                } else {
                    next.ball = .loose(target)
                }
            }

        case .pass(let from, let target):
            guard contains(from) else { return .failure(.unknownPlayer(from)) }
            if case .player(let receiver) = target, !contains(receiver) {
                return .failure(.unknownPlayer(receiver))
            }
            guard holder == from else { return .failure(.noBall) }
            switch target {
            case .player(let receiver):
                if receiver == from { return .failure(.passToSelf) }
                next.ball = .held(receiver)
            case .space(let point):
                next.ball = .loose(point)
            }

        case .shoot(let from, let tap):
            guard contains(from) else { return .failure(.unknownPlayer(from)) }
            guard holder == from else { return .failure(.noBall) }
            next.ball = .loose(shotTarget(tap: tap))
        }

        return .success(next)
    }

    /// Same as `apply`, but throws the `StepError`.
    public func applying(_ step: Step) throws -> BoardState {
        try apply(step).get()
    }

    // MARK: Private

    private mutating func setPosition(of ref: PlayerRef, to point: PitchPoint) {
        switch ref {
        case .home(let id):
            if let index = home.firstIndex(where: { $0.id == id }) {
                home[index].position = point
            }
        case .away(let index):
            if away.indices.contains(index) {
                away[index].position = point
            }
        }
    }

    private func nearestPlayerWithinReach(of point: PitchPoint) -> PlayerRef? {
        var best: (ref: PlayerRef, distance: Double)?
        for entry in allPlayerPositions {
            let distance = format.distanceMetres(from: entry.position, to: point)
            guard distance <= format.pickupReachMetres else { continue }
            if let current = best, distance >= current.distance { continue }
            best = (ref: entry.ref, distance: distance)
        }
        return best?.ref
    }
}

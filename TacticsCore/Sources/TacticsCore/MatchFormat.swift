import Foundation

/// 5, 7, 9 or 11-a-side.
public enum MatchFormat: Int, CaseIterable, Codable, Sendable, Identifiable {
    case five = 5
    case seven = 7
    case nine = 9
    case eleven = 11

    public var id: Int { rawValue }

    /// Players per side, including the goalkeeper.
    public var playersPerSide: Int { rawValue }

    /// For example "7-a-side".
    public var displayName: String { "\(rawValue)-a-side" }

    public var pitchLengthMetres: Double {
        switch self {
        case .five: return 37
        case .seven: return 55
        case .nine: return 73
        case .eleven: return 105
        }
    }

    public var pitchWidthMetres: Double {
        switch self {
        case .five: return 27
        case .seven: return 37
        case .nine: return 46
        case .eleven: return 68
        }
    }

    public var goalWidthMetres: Double {
        switch self {
        case .five, .seven: return 3.66
        case .nine: return 4.88
        case .eleven: return 7.32
        }
    }

    /// How close (in metres) a player must be to a loose ball to pick it up:
    /// 3.5% of the pitch length, which is about a token's width on screen in every format.
    public var pickupReachMetres: Double { 0.035 * pitchLengthMetres }

    /// Home formation, goalkeeper first. Positions are (along the length, across the width).
    public var homeFormation: [PitchPoint] {
        let pairs: [(Double, Double)]
        switch self {
        case .five:
            pairs = [(0.05, 0.5), (0.22, 0.3), (0.22, 0.7), (0.35, 0.5), (0.45, 0.5)]
        case .seven:
            pairs = [(0.05, 0.5), (0.2, 0.25), (0.2, 0.5), (0.2, 0.75),
                     (0.35, 0.3), (0.35, 0.7), (0.45, 0.5)]
        case .nine:
            pairs = [(0.05, 0.5), (0.2, 0.25), (0.2, 0.5), (0.2, 0.75),
                     (0.33, 0.2), (0.33, 0.5), (0.33, 0.8), (0.45, 0.35), (0.45, 0.65)]
        case .eleven:
            pairs = [(0.05, 0.5), (0.2, 0.15), (0.2, 0.38), (0.2, 0.62), (0.2, 0.85),
                     (0.33, 0.15), (0.33, 0.38), (0.33, 0.62), (0.33, 0.85),
                     (0.45, 0.38), (0.45, 0.62)]
        }
        return pairs.map { PitchPoint(x: $0.0, y: $0.1) }
    }

    /// The home formation mirrored end to end.
    public var awayFormation: [PitchPoint] {
        homeFormation.map { PitchPoint(x: 1 - $0.x, y: $0.y) }
    }

    /// Straight-line distance in metres between two pitch points.
    public func distanceMetres(from a: PitchPoint, to b: PitchPoint) -> Double {
        let dx = (a.x - b.x) * pitchLengthMetres
        let dy = (a.y - b.y) * pitchWidthMetres
        return (dx * dx + dy * dy).squareRoot()
    }

    /// Where a shot tapped at `tap` ends up: the nearest goal mouth.
    /// The home goal (x = 0) if the tap is in the home half, otherwise the away goal (x = 1).
    /// Across the width the end is kept within the goal mouth.
    public func shotTarget(forTap tap: PitchPoint) -> PitchPoint {
        let halfGoal = (goalWidthMetres / 2) / pitchWidthMetres
        let x = tap.x < 0.5 ? 0.0 : 1.0
        let y = min(max(tap.y, 0.5 - halfGoal), 0.5 + halfGoal)
        return PitchPoint(x: x, y: y)
    }
}

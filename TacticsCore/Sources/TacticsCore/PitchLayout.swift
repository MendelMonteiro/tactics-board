import Foundation
import CoreGraphics

/// A piece (player or ball) and where it is drawn on screen.
public struct DrawnPiece: Equatable, Sendable {
    public var piece: Piece
    public var point: CGPoint

    public init(piece: Piece, point: CGPoint) {
        self.piece = piece
        self.point = point
    }
}

/// Pitch markings in screen coordinates.
public struct PitchMarkings: Sendable {
    public let outline: CGRect
    public let halfwayTop: CGPoint
    public let halfwayBottom: CGPoint
    public let centreCircleCentre: CGPoint
    public let centreCircleRadius: CGFloat
    /// Home end first, then away end.
    public let penaltyAreas: [CGRect]
    /// Drawn outside the goal lines. Home end first, then away end.
    public let goals: [CGRect]
}

/// Fits a format's pitch inside a screen area (length runs left to right) and converts
/// between pitch points and screen points.
public struct PitchLayout: Sendable {
    public static let margin: CGFloat = 16
    /// Player circles are 52 pt across in every format.
    public static let tokenDiameter: CGFloat = 52
    public static let touchRadius: CGFloat = 40
    /// A held ball is drawn this many token diameters beside its holder.
    public static let heldBallOffsetFactor: CGFloat = 0.45
    /// Goals are drawn this fraction of the pitch length deep, outside the goal lines.
    public static let goalDepthFraction: CGFloat = 0.02

    public let format: MatchFormat
    public let size: CGSize
    /// The pitch's area on screen.
    public let pitchRect: CGRect

    public init(format: MatchFormat, in size: CGSize, margin: CGFloat = 16) {
        self.format = format
        self.size = size

        let length = CGFloat(format.pitchLengthMetres)
        let width = CGFloat(format.pitchWidthMetres)
        let availableWidth = max(size.width - 2 * margin, 1)
        let availableHeight = max(size.height - 2 * margin, 1)

        // Leave room for a goal at each end.
        let totalLength = length * (1 + 2 * PitchLayout.goalDepthFraction)
        let scale = min(availableWidth / totalLength, availableHeight / width)

        let pitchWidth = length * scale
        let pitchHeight = width * scale
        self.pitchRect = CGRect(
            x: (size.width - pitchWidth) / 2,
            y: (size.height - pitchHeight) / 2,
            width: pitchWidth,
            height: pitchHeight
        )
    }

    // MARK: Conversion

    public func screenPoint(for point: PitchPoint) -> CGPoint {
        CGPoint(
            x: pitchRect.minX + CGFloat(point.x) * pitchRect.width,
            y: pitchRect.minY + CGFloat(point.y) * pitchRect.height
        )
    }

    /// A drop off the pitch lands on the edge.
    public func pitchPoint(for screen: CGPoint) -> PitchPoint {
        guard pitchRect.width > 0, pitchRect.height > 0 else { return PitchPoint.centre }
        return PitchPoint(
            x: Double((screen.x - pitchRect.minX) / pitchRect.width),
            y: Double((screen.y - pitchRect.minY) / pitchRect.height)
        )
    }

    // MARK: Drawing positions and touch search

    /// Where the ball is drawn. A held ball sits beside its holder, 0.45 × the token
    /// diameter towards the way they attack (right for home, left for away),
    /// so it never covers the number.
    public func drawnBallPoint(for frame: Frame) -> CGPoint {
        let base = screenPoint(for: frame.ball)
        guard let holder = frame.holder else { return base }
        let offset = PitchLayout.tokenDiameter * PitchLayout.heldBallOffsetFactor
        switch holder {
        case .home: return CGPoint(x: base.x + offset, y: base.y)
        case .away: return CGPoint(x: base.x - offset, y: base.y)
        }
    }

    public func drawnPieces(for frame: Frame) -> [DrawnPiece] {
        var result: [DrawnPiece] = []
        for slot in frame.home {
            result.append(DrawnPiece(piece: .player(.home(slot.id)),
                                     point: screenPoint(for: slot.position)))
        }
        for (index, slot) in frame.away.enumerated() {
            result.append(DrawnPiece(piece: .player(.away(index)),
                                     point: screenPoint(for: slot.position)))
        }
        result.append(DrawnPiece(piece: .ball, point: drawnBallPoint(for: frame)))
        return result
    }

    /// The nearest piece within the touch radius. If the ball and a player are equally
    /// near, the ball wins, so the coach can always grab a ball at a player's feet.
    public static func nearestPiece(
        to point: CGPoint,
        among pieces: [DrawnPiece],
        radius: CGFloat = PitchLayout.touchRadius
    ) -> Piece? {
        let epsilon: CGFloat = 0.000_001
        var best: (piece: Piece, distance: CGFloat)?

        for candidate in pieces {
            let distance = hypot(candidate.point.x - point.x, candidate.point.y - point.y)
            guard distance <= radius else { continue }
            if let current = best {
                if distance < current.distance - epsilon {
                    best = (piece: candidate.piece, distance: distance)
                } else if abs(distance - current.distance) <= epsilon, candidate.piece == .ball {
                    best = (piece: candidate.piece, distance: distance)
                }
            } else {
                best = (piece: candidate.piece, distance: distance)
            }
        }
        return best?.piece
    }

    /// Touches are matched to where pieces are drawn.
    public func hitTest(at point: CGPoint, frame: Frame) -> Piece? {
        PitchLayout.nearestPiece(to: point, among: drawnPieces(for: frame))
    }

    // MARK: Markings

    public var markings: PitchMarkings {
        let rect = pitchRect
        let penaltyDepth = 0.16 * rect.width
        let penaltyHeight = 0.6 * rect.height
        let goalDepth = PitchLayout.goalDepthFraction * rect.width
        let goalHeight = CGFloat(format.goalWidthMetres / format.pitchWidthMetres) * rect.height

        let penaltyAreas = [
            CGRect(x: rect.minX, y: rect.midY - penaltyHeight / 2,
                   width: penaltyDepth, height: penaltyHeight),
            CGRect(x: rect.maxX - penaltyDepth, y: rect.midY - penaltyHeight / 2,
                   width: penaltyDepth, height: penaltyHeight),
        ]
        let goals = [
            CGRect(x: rect.minX - goalDepth, y: rect.midY - goalHeight / 2,
                   width: goalDepth, height: goalHeight),
            CGRect(x: rect.maxX, y: rect.midY - goalHeight / 2,
                   width: goalDepth, height: goalHeight),
        ]

        return PitchMarkings(
            outline: rect,
            halfwayTop: CGPoint(x: rect.midX, y: rect.minY),
            halfwayBottom: CGPoint(x: rect.midX, y: rect.maxY),
            centreCircleCentre: CGPoint(x: rect.midX, y: rect.midY),
            centreCircleRadius: 0.09 * rect.height,
            penaltyAreas: penaltyAreas,
            goals: goals
        )
    }
}

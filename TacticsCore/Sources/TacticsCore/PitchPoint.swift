import Foundation

/// A position on the pitch in pitch-relative units.
///
/// `x` runs along the length: 0 is the home goal line, 1 is the away goal line.
/// `y` runs across the width: 0 is the top touchline.
/// Both values are always kept within 0...1, including when decoded from a file.
public struct PitchPoint: Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double

    public static let centre = PitchPoint(x: 0.5, y: 0.5)

    public init(x: Double, y: Double) {
        self.x = PitchPoint.clamped(x)
        self.y = PitchPoint.clamped(y)
    }

    private enum CodingKeys: String, CodingKey {
        case x, y
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let x = try container.decode(Double.self, forKey: .x)
        let y = try container.decode(Double.self, forKey: .y)
        self.init(x: x, y: y)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(x, forKey: .x)
        try container.encode(y, forKey: .y)
    }

    /// The point a fraction `t` of the way from `self` to `other`.
    public func interpolated(to other: PitchPoint, _ t: Double) -> PitchPoint {
        PitchPoint(x: x + (other.x - x) * t, y: y + (other.y - y) * t)
    }

    static func clamped(_ value: Double) -> Double {
        if value.isNaN { return 0.5 }
        return min(max(value, 0), 1)
    }
}

import Testing
import Foundation
@testable import TacticsCore

@Suite struct FormatTests {
    @Test func formationsHaveOnePositionPerPlayer() {
        for format in MatchFormat.allCases {
            #expect(format.homeFormation.count == format.playersPerSide)
            #expect(format.awayFormation.count == format.playersPerSide)
        }
    }

    @Test func sevenASideFormationIsExact() {
        let expected: [(Double, Double)] = [
            (0.05, 0.5), (0.2, 0.25), (0.2, 0.5), (0.2, 0.75),
            (0.35, 0.3), (0.35, 0.7), (0.45, 0.5),
        ]
        let actual = MatchFormat.seven.homeFormation
        #expect(actual.count == expected.count)
        for (point, pair) in zip(actual, expected) {
            #expect(approxEqual(point, PitchPoint(x: pair.0, y: pair.1)))
        }
    }

    @Test func awayKeeperIsAtTheFarEnd() {
        let keeper = MatchFormat.seven.awayFormation[0]
        #expect(approxEqual(keeper, PitchPoint(x: 0.95, y: 0.5)))
    }

    @Test func pitchSizes() {
        #expect(MatchFormat.seven.pitchLengthMetres == 55)
        #expect(MatchFormat.seven.pitchWidthMetres == 37)
        #expect(MatchFormat.eleven.pitchLengthMetres == 105)
        #expect(MatchFormat.eleven.pitchWidthMetres == 68)
    }

    @Test func goalWidths() {
        #expect(MatchFormat.five.goalWidthMetres == 3.66)
        #expect(MatchFormat.seven.goalWidthMetres == 3.66)
        #expect(MatchFormat.nine.goalWidthMetres == 4.88)
        #expect(MatchFormat.eleven.goalWidthMetres == 7.32)
    }

    @Test func pointsOffThePitchAreKept() {
        let point = PitchPoint(x: -0.2, y: 1.4)
        #expect(point.x == 0)
        #expect(point.y == 1)
    }

    @Test func decodedPointsAreKept() throws {
        let data = Data(#"{"x":-5,"y":3}"#.utf8)
        let point = try JSONDecoder().decode(PitchPoint.self, from: data)
        #expect(point.x == 0)
        #expect(point.y == 1)
    }

    @Test func distanceAlongTheLength() {
        let metres = MatchFormat.seven.distanceMetres(
            from: PitchPoint(x: 0, y: 0.5), to: PitchPoint(x: 1, y: 0.5))
        #expect(approxEqual(metres, 55))
    }
}

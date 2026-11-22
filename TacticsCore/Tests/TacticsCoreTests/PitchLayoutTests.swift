import Testing
import Foundation
import CoreGraphics
@testable import TacticsCore

@Suite struct PitchLayoutTests {
    private let screen = CGSize(width: 1180, height: 820)

    @Test func thePitchKeepsItsShape() {
        let layout = PitchLayout(format: .seven, in: screen)
        let ratio = Double(layout.pitchRect.width / layout.pitchRect.height)
        #expect(abs(ratio - 55.0 / 37.0) < 0.01)
    }

    @Test func thePitchFitsInsideTheMarginWithRoomForTheGoals() {
        for format in MatchFormat.allCases {
            let layout = PitchLayout(format: format, in: screen)
            let goalDepth = layout.markings.goals[0].width
            #expect(layout.pitchRect.minX - goalDepth >= PitchLayout.margin - 0.001)
            #expect(layout.pitchRect.maxX + goalDepth <= screen.width - PitchLayout.margin + 0.001)
            #expect(layout.pitchRect.minY >= PitchLayout.margin - 0.001)
            #expect(layout.pitchRect.maxY <= screen.height - PitchLayout.margin + 0.001)
        }
    }

    @Test func thePitchIsCentred() {
        let layout = PitchLayout(format: .seven, in: screen)
        #expect(abs(layout.pitchRect.midX - screen.width / 2) < 0.001)
        #expect(abs(layout.pitchRect.midY - screen.height / 2) < 0.001)
    }

    @Test func convertingToTheScreenAndBackGivesTheSamePoint() {
        let layout = PitchLayout(format: .seven, in: screen)
        let point = PitchPoint(x: 0.3, y: 0.7)
        let back = layout.pitchPoint(for: layout.screenPoint(for: point))
        #expect(approxEqual(back, point, tolerance: 1e-9))
    }

    @Test func aDropFarOffTheLeftEdgeLandsOnTheLeftEdge() {
        let layout = PitchLayout(format: .seven, in: screen)
        let point = layout.pitchPoint(for: CGPoint(x: -500, y: layout.pitchRect.midY))
        #expect(point.x == 0)
        #expect(approxEqual(point.y, 0.5))
    }

    @Test func theTouchSearchFindsTheNearestPieceWithinTheRadius() {
        let pieces = [
            DrawnPiece(piece: .player(.away(0)), point: CGPoint(x: 100, y: 100)),
            DrawnPiece(piece: .player(.away(1)), point: CGPoint(x: 130, y: 100)),
        ]
        let found = PitchLayout.nearestPiece(to: CGPoint(x: 120, y: 100), among: pieces)
        #expect(found == .player(.away(1)))
    }

    @Test func theTouchSearchFindsNothingBeyondTheRadius() {
        let pieces = [DrawnPiece(piece: .player(.away(0)), point: CGPoint(x: 100, y: 100))]
        #expect(PitchLayout.nearestPiece(to: CGPoint(x: 100, y: 141), among: pieces) == nil)
        #expect(PitchLayout.nearestPiece(to: CGPoint(x: 100, y: 139), among: pieces) != nil)
    }

    @Test func theBallWinsATie() {
        let spot = CGPoint(x: 200, y: 200)
        let playerFirst = [
            DrawnPiece(piece: .player(.away(0)), point: spot),
            DrawnPiece(piece: .ball, point: spot),
        ]
        let ballFirst = Array(playerFirst.reversed())
        #expect(PitchLayout.nearestPiece(to: CGPoint(x: 205, y: 200), among: playerFirst) == .ball)
        #expect(PitchLayout.nearestPiece(to: CGPoint(x: 205, y: 200), among: ballFirst) == .ball)
    }

    @Test func aHeldBallIsDrawnBesideItsHolderTowardsTheirAttack() {
        var fx = Fixture()
        let layout = PitchLayout(format: .seven, in: screen)
        let offset = PitchLayout.tokenDiameter * PitchLayout.heldBallOffsetFactor

        fx.board.ball = .held(fx.home(7))
        let homeFrame = Frame(board: fx.board)
        let homeHolder = layout.screenPoint(for: fx.board.position(of: fx.home(7))!)
        let homeBall = layout.drawnBallPoint(for: homeFrame)
        #expect(abs(homeBall.x - (homeHolder.x + offset)) < 0.001)
        #expect(abs(homeBall.y - homeHolder.y) < 0.001)

        fx.board.ball = .held(fx.away(7))
        let awayFrame = Frame(board: fx.board)
        let awayHolder = layout.screenPoint(for: fx.board.position(of: fx.away(7))!)
        let awayBall = layout.drawnBallPoint(for: awayFrame)
        #expect(abs(awayBall.x - (awayHolder.x - offset)) < 0.001)
    }

    @Test func touchesAreMatchedToWhereAHeldBallIsDrawn() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let layout = PitchLayout(format: .seven, in: screen)
        let frame = Frame(board: fx.board)
        let drawnBall = layout.drawnBallPoint(for: frame)
        // Just next to the drawn ball, on the far side from its holder.
        let touch = CGPoint(x: drawnBall.x + 12, y: drawnBall.y)
        #expect(layout.hitTest(at: touch, frame: frame) == .ball)
    }

    @Test func elevenASideHasTwoPenaltyAreasAndTwoGoals() {
        let markings = PitchLayout(format: .eleven, in: screen).markings
        #expect(markings.penaltyAreas.count == 2)
        #expect(markings.goals.count == 2)
    }

    @Test func markingsUseTheSpecifiedProportions() {
        let layout = PitchLayout(format: .seven, in: screen)
        let markings = layout.markings
        let rect = layout.pitchRect
        #expect(abs(markings.centreCircleRadius - 0.09 * rect.height) < 0.001)
        #expect(abs(markings.penaltyAreas[0].width - 0.16 * rect.width) < 0.001)
        #expect(abs(markings.penaltyAreas[0].height - 0.6 * rect.height) < 0.001)
        #expect(abs(markings.goals[0].width - 0.02 * rect.width) < 0.001)
        let goalHeight = rect.height * CGFloat(3.66 / 37.0)
        #expect(abs(markings.goals[0].height - goalHeight) < 0.001)
    }
}

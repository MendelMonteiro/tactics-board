import Testing
import Foundation
@testable import TacticsCore

@Suite struct PlaybackTests {
    /// Home 7 starts at (0.45, 0.5). A run of 0.2 of the pitch length is 11 m in 7-a-side.
    private func runStep(_ fx: Fixture, by fraction: Double = 0.2) -> Step {
        .move(.player(fx.home(7)), to: PitchPoint(x: 0.45 + fraction, y: 0.5))
    }

    @Test func aRunOfElevenMetresTakesTwoPointTwoSeconds() {
        let fx = Fixture()
        let timeline = PlaybackTimeline(sequence: fx.sequence(steps: [runStep(fx)]))
        #expect(approxEqual(timeline.duration, 2.2))
    }

    @Test func aTinyRunStillTakesSixTenthsOfASecond() {
        let fx = Fixture()
        let timeline = PlaybackTimeline(sequence: fx.sequence(steps: [runStep(fx, by: 0.001)]))
        #expect(approxEqual(timeline.duration, 0.6))
    }

    @Test func aPassIsFasterThanARunOverTheSameDistance() {
        var fx = Fixture()
        let run = PlaybackTimeline(sequence: fx.sequence(steps: [runStep(fx)]))
        fx.board.ball = .held(fx.home(7))
        let pass = PlaybackTimeline(sequence: fx.sequence(steps: [
            .pass(from: fx.home(7), to: .space(PitchPoint(x: 0.65, y: 0.5))),
        ]))
        #expect(pass.duration < run.duration)
    }

    @Test func pausesSitBetweenSteps() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let steps: [Step] = [
            runStep(fx),
            .pass(from: fx.home(7), to: .space(PitchPoint(x: 0.9, y: 0.2))),
        ]
        let sequence = fx.sequence(steps: steps)
        let a = PlaybackTimeline(sequence: sequence, steps: 1...1).duration
        let b = PlaybackTimeline(sequence: sequence, steps: 2...2).duration
        let all = PlaybackTimeline(sequence: sequence).duration
        #expect(approxEqual(all, a + 0.4 + b))
    }

    @Test func theFrameAtTheStartIsTheSetupAndAtTheEndIsTheFinalBoard() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let sequence = fx.sequence(steps: [
            runStep(fx),
            .pass(from: fx.home(7), to: .space(PitchPoint(x: 0.9, y: 0.2))),
        ])
        let timeline = PlaybackTimeline(sequence: sequence)
        #expect(timeline.frame(at: 0) == Frame(board: sequence.setup))
        #expect(timeline.frame(at: -5) == Frame(board: sequence.setup))
        let final = Frame(board: sequence.boards().last!)
        #expect(timeline.frame(at: timeline.duration) == final)
        #expect(timeline.frame(at: timeline.duration + 10) == final)
    }

    @Test func theBallStaysWithARunningPlayerHalfwayThroughADribble() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let timeline = PlaybackTimeline(sequence: fx.sequence(steps: [runStep(fx)]))
        let frame = timeline.frame(at: timeline.duration / 2)
        #expect(frame.holder == fx.home(7))
        let runner = frame.position(of: fx.home(7))!
        #expect(approxEqual(frame.ball, runner))
        #expect(approxEqual(runner, PitchPoint(x: 0.55, y: 0.5), tolerance: 1e-6))
    }

    @Test func theBallIsHalfwayAtTheMidpointOfAPass() {
        var fx = Fixture()
        fx.board.ball = .held(fx.home(7))
        let timeline = PlaybackTimeline(sequence: fx.sequence(steps: [
            .pass(from: fx.home(7), to: .space(PitchPoint(x: 0.85, y: 0.5))),
        ]))
        let frame = timeline.frame(at: timeline.duration / 2)
        #expect(frame.holder == nil)
        #expect(approxEqual(frame.ball, PitchPoint(x: 0.65, y: 0.5), tolerance: 1e-6))
    }

    @Test func onlyTheMovingPieceChangesDuringAStep() {
        let fx = Fixture()
        let sequence = fx.sequence(steps: [runStep(fx)])
        let timeline = PlaybackTimeline(sequence: sequence)
        let frame = timeline.frame(at: timeline.duration / 2)
        for number in 1...6 {
            #expect(frame.position(of: fx.home(number)) == sequence.setup.position(of: fx.home(number)))
        }
        #expect(frame.away == sequence.setup.away)
    }

    @Test func theStepNumberGoesUpByOnePerStep() {
        let fx = Fixture()
        let sequence = fx.sequence(steps: fx.moveSteps(3))
        let timeline = PlaybackTimeline(sequence: sequence)
        #expect(timeline.stepNumber(at: 0) == 0)
        for number in 1...3 {
            let segment = timeline.segments[number - 1]
            #expect(timeline.stepNumber(at: segment.start + segment.duration / 2) == number)
        }
        #expect(timeline.stepNumber(at: timeline.duration) == 3)
    }

    @Test func steppingForwardPlaysJustOneStep() {
        let fx = Fixture()
        let sequence = fx.sequence(steps: fx.moveSteps(3))
        let timeline = PlaybackTimeline(sequence: sequence, steps: 2...2)
        #expect(timeline.startBoard == sequence.boards()[1])
        #expect(timeline.endBoard == sequence.boards()[2])
        #expect(timeline.stepNumber(at: timeline.duration) == 2)
    }

    @Test func aSequenceWithNoStepsHasNoDuration() {
        let fx = Fixture()
        let timeline = PlaybackTimeline(sequence: fx.sequence())
        #expect(timeline.duration == 0)
        #expect(timeline.frame(at: 1) == Frame(board: fx.board))
    }

    @Test func easingIsSmoothstep() {
        #expect(smoothstep(0) == 0)
        #expect(smoothstep(1) == 1)
        #expect(approxEqual(smoothstep(0.5), 0.5))
        #expect(approxEqual(smoothstep(0.25), 3 * 0.0625 - 2 * 0.015625))
    }
}

@Suite struct PlaybackClockTests {
    @Test func timeFollowsRealTime() {
        var clock = PlaybackClock()
        clock.start(at: 100)
        #expect(approxEqual(clock.time(at: 102), 2))
        #expect(clock.isRunning)
    }

    @Test func pausingFreezesTime() {
        var clock = PlaybackClock()
        clock.start(at: 0)
        clock.pause(at: 2)
        #expect(clock.isRunning == false)
        #expect(approxEqual(clock.time(at: 50), 2))
        clock.resume(at: 50)
        #expect(approxEqual(clock.time(at: 51), 3))
    }

    @Test func doubleSpeedPassesTimeTwiceAsFast() {
        var clock = PlaybackClock(speed: .double)
        clock.start(at: 0)
        #expect(approxEqual(clock.time(at: 3), 6))
    }

    @Test func changingSpeedDoesNotMakeThePositionJump() {
        var clock = PlaybackClock()
        clock.start(at: 0)
        let before = clock.time(at: 2)
        clock.setSpeed(.double, at: 2)
        #expect(approxEqual(clock.time(at: 2), before))
        #expect(approxEqual(clock.time(at: 3), 4))
    }

    @Test func speedsCycle() {
        #expect(PlaybackSpeed.half.next == .normal)
        #expect(PlaybackSpeed.normal.next == .double)
        #expect(PlaybackSpeed.double.next == .half)
    }
}

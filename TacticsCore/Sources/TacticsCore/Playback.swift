import Foundation

/// Where every piece is drawn at one instant, plus who has the ball (if anyone).
public struct Frame: Equatable, Sendable {
    public var home: [HomeSlot]
    public var away: [AwaySlot]
    /// Logical ball position. A held ball is at its holder's position;
    /// the drawing code offsets it so it doesn't cover the number.
    public var ball: PitchPoint
    public var holder: PlayerRef?

    public init(home: [HomeSlot], away: [AwaySlot], ball: PitchPoint, holder: PlayerRef?) {
        self.home = home
        self.away = away
        self.ball = ball
        self.holder = holder
    }

    /// A frame made directly from a board, for still pictures.
    public init(board: BoardState) {
        self.home = board.home
        self.away = board.away
        self.ball = board.ballPosition
        self.holder = board.holder
    }

    public func position(of ref: PlayerRef) -> PitchPoint? {
        switch ref {
        case .home(let id):
            return home.first(where: { $0.id == id })?.position
        case .away(let index):
            return away.indices.contains(index) ? away[index].position : nil
        }
    }

    public mutating func setPosition(of ref: PlayerRef, to point: PitchPoint) {
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
}

public enum PlaybackSpeed: Double, CaseIterable, Sendable {
    case half = 0.5
    case normal = 1
    case double = 2

    public var multiplier: Double { rawValue }

    public var label: String {
        switch self {
        case .half: return "0.5×"
        case .normal: return "1×"
        case .double: return "2×"
        }
    }

    /// 0.5× → 1× → 2× → back to 0.5×.
    public var next: PlaybackSpeed {
        switch self {
        case .half: return .normal
        case .normal: return .double
        case .double: return .half
        }
    }
}

/// The smoothstep easing curve, 3t² − 2t³, with `t` kept within 0...1.
public func smoothstep(_ t: Double) -> Double {
    let c = min(max(t, 0), 1)
    return c * c * (3 - 2 * c)
}

/// The frames of a sequence (or a range of its steps) over time, at normal speed.
public struct PlaybackTimeline: Sendable {
    struct Segment: Sendable {
        let stepNumber: Int      // numbered from 1
        let step: Step
        let before: BoardState
        let after: BoardState
        let start: Double
        let duration: Double
    }

    /// A short pause after every step except the last.
    public static let pauseBetweenSteps = 0.4

    let segments: [Segment]
    public let startBoard: BoardState
    public let endBoard: BoardState
    /// The number of the first step played (numbered from 1).
    public let firstStepNumber: Int
    /// Total length in seconds at normal speed.
    public let duration: Double

    /// `steps` is a range of step numbers (from 1). By default all usable steps are played.
    /// Stepping forward to step k plays `k...k`.
    public init(sequence: TacticsSequence, steps range: ClosedRange<Int>? = nil) {
        let boards = sequence.boards()
        let usable = boards.count - 1
        let lower = max(range?.lowerBound ?? 1, 1)
        let upper = min(range?.upperBound ?? usable, usable)

        var built: [Segment] = []
        var time = 0.0
        if lower <= upper {
            for number in lower...upper {
                let before = boards[number - 1]
                let after = boards[number]
                let step = sequence.steps[number - 1]
                let length = PlaybackTimeline.stepDuration(step, from: before, to: after)
                built.append(Segment(stepNumber: number, step: step, before: before,
                                     after: after, start: time, duration: length))
                time += length
                if number < upper { time += PlaybackTimeline.pauseBetweenSteps }
            }
        }

        self.segments = built
        self.duration = time
        self.firstStepNumber = lower
        if lower <= upper {
            self.startBoard = boards[lower - 1]
            self.endBoard = boards[upper]
        } else {
            let index = min(max(lower - 1, 0), usable)
            self.startBoard = boards[index]
            self.endBoard = boards[index]
        }
    }

    /// The frame at `time` seconds (timeline time, i.e. already scaled by speed).
    /// Before zero it shows the start; after the total length it shows the end.
    public func frame(at time: Double) -> Frame {
        if time <= 0 || segments.isEmpty { return Frame(board: startBoard) }
        if time >= duration { return Frame(board: endBoard) }
        guard let segment = segments.last(where: { $0.start <= time }) else {
            return Frame(board: startBoard)
        }
        let local = time - segment.start
        if local >= segment.duration { return Frame(board: segment.after) }
        let eased = smoothstep(local / segment.duration)
        return PlaybackTimeline.interpolate(segment, eased)
    }

    /// The step number to show at `time`: goes up by one as each step begins.
    /// Before the first step it is one less than the first step's number.
    public func stepNumber(at time: Double) -> Int {
        var number = firstStepNumber - 1
        for segment in segments where time > segment.start {
            number = segment.stepNumber
        }
        return number
    }

    // MARK: Timings

    static func stepDuration(_ step: Step, from before: BoardState, to after: BoardState) -> Double {
        let format = before.format
        switch step {
        case .move(let piece, _):
            switch piece {
            case .player(let ref):
                let from = before.position(of: ref) ?? PitchPoint.centre
                let to = after.position(of: ref) ?? from
                return bounded(format.distanceMetres(from: from, to: to) / 5, 0.6, 2.5)
            case .ball:
                let metres = format.distanceMetres(from: before.ballPosition, to: after.ballPosition)
                return bounded(metres / 12, 0.4, 1.5)
            }
        case .pass:
            let metres = format.distanceMetres(from: before.ballPosition, to: after.ballPosition)
            return bounded(metres / 12, 0.4, 1.5)
        case .shoot:
            let metres = format.distanceMetres(from: before.ballPosition, to: after.ballPosition)
            return bounded(metres / 20, 0.3, 1.0)
        }
    }

    private static func bounded(_ value: Double, _ low: Double, _ high: Double) -> Double {
        min(max(value, low), high)
    }

    // MARK: Interpolation

    /// Within a step only the moving piece changes, plus the ball if the mover has it.
    private static func interpolate(_ segment: Segment, _ eased: Double) -> Frame {
        var frame = Frame(board: segment.before)

        switch segment.step {
        case .move(let piece, _):
            switch piece {
            case .player(let ref):
                guard let from = segment.before.position(of: ref),
                      let to = segment.after.position(of: ref) else { return frame }
                let point = from.interpolated(to: to, eased)
                frame.setPosition(of: ref, to: point)
                if segment.before.holder == ref {
                    frame.ball = point   // a dribble: the ball goes with the player
                }
            case .ball:
                frame.holder = nil
                frame.ball = segment.before.ballPosition
                    .interpolated(to: segment.after.ballPosition, eased)
            }
        case .pass, .shoot:
            frame.holder = nil
            frame.ball = segment.before.ballPosition
                .interpolated(to: segment.after.ballPosition, eased)
        }
        return frame
    }
}

/// Turns real time into timeline time. The current time is always passed in,
/// so the clock can be tested without waiting.
public struct PlaybackClock: Sendable {
    public private(set) var speed: PlaybackSpeed
    public private(set) var isRunning: Bool
    private var accumulated: Double
    private var lastTick: Double

    public init(speed: PlaybackSpeed = .normal) {
        self.speed = speed
        self.isRunning = false
        self.accumulated = 0
        self.lastTick = 0
    }

    /// Starts running from `timelineTime` (default: the beginning).
    public mutating func start(at now: Double, from timelineTime: Double = 0) {
        accumulated = timelineTime
        lastTick = now
        isRunning = true
    }

    public mutating func pause(at now: Double) {
        guard isRunning else { return }
        accumulated = time(at: now)
        isRunning = false
    }

    public mutating func resume(at now: Double) {
        guard !isRunning else { return }
        lastTick = now
        isRunning = true
    }

    /// Changing speed never makes the position jump.
    public mutating func setSpeed(_ newSpeed: PlaybackSpeed, at now: Double) {
        if isRunning {
            accumulated = time(at: now)
            lastTick = now
        }
        speed = newSpeed
    }

    /// Timeline time: real time elapsed × speed.
    public func time(at now: Double) -> Double {
        guard isRunning else { return accumulated }
        return accumulated + max(now - lastTick, 0) * speed.multiplier
    }
}

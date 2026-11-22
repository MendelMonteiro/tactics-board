import SwiftUI
import TacticsCore

/// The step leading to the current one, shown as a line on the pitch.
struct StepArrow: Equatable {
    enum Kind { case passOrShot, run }
    var from: PitchPoint
    var to: PitchPoint
    var kind: Kind
}

/// Draws the pitch, the pieces and any arrows. The same drawing is used on the board and,
/// scaled down, in the sequence list previews.
enum PitchRenderer {
    static func draw(
        _ context: inout GraphicsContext,
        size: CGSize,
        format: MatchFormat,
        frame: Frame,
        squad: [UUID: SquadPlayer],
        arrow: StepArrow? = nil,
        preview: TouchPreview? = nil,
        selection: Piece? = nil,
        highlightedHolder: PlayerRef? = nil
    ) {
        let layout = PitchLayout(format: format, in: size)

        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Theme.pitch))
        drawMarkings(&context, layout: layout)

        if let arrow = arrow {
            let from = layout.screenPoint(for: arrow.from)
            let to = layout.screenPoint(for: arrow.to)
            switch arrow.kind {
            case .passOrShot: drawArrow(&context, from: from, to: to)
            case .run: drawDotted(&context, from: from, to: to)
            }
        }

        // Opposition first, then home, then the ball on top.
        for (index, slot) in frame.away.enumerated() {
            let point = layout.screenPoint(for: slot.position)
            let ref = PlayerRef.away(index)
            drawToken(&context, at: point, color: Theme.away, number: slot.number, name: nil,
                      ring: ringColor(ref, selection: selection, holder: highlightedHolder))
        }
        for slot in frame.home {
            let point = layout.screenPoint(for: slot.position)
            let ref = PlayerRef.home(slot.id)
            let info = squad[slot.id]
            drawToken(&context, at: point, color: Theme.home, number: info?.number ?? 0,
                      name: info?.name,
                      ring: ringColor(ref, selection: selection, holder: highlightedHolder))
        }

        drawBall(&context, at: layout.drawnBallPoint(for: frame), opacity: 1,
                 ring: selection == .ball)

        if let preview = preview {
            switch preview {
            case .dragging:
                break   // the dragged piece is already drawn under the finger
            case .pass(let from, let to, _), .shot(let from, let to):
                let start = layout.screenPoint(for: from)
                let end = layout.screenPoint(for: to)
                drawArrow(&context, from: start, to: end)
                drawBall(&context, at: end, opacity: 0.55, ring: false)
            }
        }
    }

    // MARK: Markings

    private static func drawMarkings(_ context: inout GraphicsContext, layout: PitchLayout) {
        let markings = layout.markings
        let white = GraphicsContext.Shading.color(.white)
        let width: CGFloat = 3

        context.stroke(Path(markings.outline), with: white, lineWidth: width)

        var halfway = Path()
        halfway.move(to: markings.halfwayTop)
        halfway.addLine(to: markings.halfwayBottom)
        context.stroke(halfway, with: white, lineWidth: width)

        let centre = markings.centreCircleCentre
        let radius = markings.centreCircleRadius
        let circle = CGRect(x: centre.x - radius, y: centre.y - radius,
                            width: radius * 2, height: radius * 2)
        context.stroke(Path(ellipseIn: circle), with: white, lineWidth: width)
        let spot = CGRect(x: centre.x - 4, y: centre.y - 4, width: 8, height: 8)
        context.fill(Path(ellipseIn: spot), with: white)

        for area in markings.penaltyAreas {
            context.stroke(Path(area), with: white, lineWidth: width)
        }
        for goal in markings.goals {
            context.fill(Path(goal), with: .color(Color.white.opacity(0.25)))
            context.stroke(Path(goal), with: white, lineWidth: width)
        }
    }

    // MARK: Arrows

    /// A yellow dashed arrow with a solid head.
    private static func drawArrow(_ context: inout GraphicsContext, from a: CGPoint, to b: CGPoint) {
        guard hypot(b.x - a.x, b.y - a.y) > 4 else { return }
        var line = Path()
        line.move(to: a)
        line.addLine(to: b)
        context.stroke(
            line,
            with: .color(Theme.arrow),
            style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [12, 9]))

        let angle = atan2(b.y - a.y, b.x - a.x)
        let headLength: CGFloat = 22
        let spread: CGFloat = 0.45
        var head = Path()
        head.move(to: b)
        head.addLine(to: CGPoint(x: b.x - headLength * cos(angle - spread),
                                 y: b.y - headLength * sin(angle - spread)))
        head.addLine(to: CGPoint(x: b.x - headLength * cos(angle + spread),
                                 y: b.y - headLength * sin(angle + spread)))
        head.closeSubpath()
        context.fill(head, with: .color(Theme.arrow))
    }

    /// A white dotted line, for a run or a ball move.
    private static func drawDotted(_ context: inout GraphicsContext, from a: CGPoint, to b: CGPoint) {
        guard hypot(b.x - a.x, b.y - a.y) > 4 else { return }
        var line = Path()
        line.move(to: a)
        line.addLine(to: b)
        context.stroke(
            line,
            with: .color(.white),
            style: StrokeStyle(lineWidth: 5, lineCap: .round, dash: [1, 10]))
    }

    // MARK: Pieces

    private static func ringColor(_ ref: PlayerRef, selection: Piece?, holder: PlayerRef?) -> Color? {
        if selection == .player(ref) { return Theme.arrow }
        if holder == ref { return Theme.arrow }
        return nil
    }

    private static func drawToken(
        _ context: inout GraphicsContext,
        at point: CGPoint,
        color: Color,
        number: Int,
        name: String?,
        ring: Color?
    ) {
        let d = PitchLayout.tokenDiameter
        let rect = CGRect(x: point.x - d / 2, y: point.y - d / 2, width: d, height: d)

        if let ring = ring {
            context.stroke(Path(ellipseIn: rect.insetBy(dx: -6, dy: -6)),
                           with: .color(ring), lineWidth: 4)
        }
        context.fill(Path(ellipseIn: rect), with: .color(color))
        context.stroke(Path(ellipseIn: rect.insetBy(dx: 1.5, dy: 1.5)),
                       with: .color(.white), lineWidth: 3)

        let numberText = Text("\(number)")
            .font(.system(size: 24, weight: .bold))
            .foregroundColor(.white)
        context.draw(context.resolve(numberText), at: point, anchor: .center)

        if let name = name, !name.isEmpty {
            let labelPoint = CGPoint(x: point.x, y: point.y + d / 2 + 4)
            let shadow = context.resolve(
                Text(name).font(.system(size: 15, weight: .bold)).foregroundColor(.black))
            for offset in [CGPoint(x: -1, y: 0), CGPoint(x: 1, y: 0),
                           CGPoint(x: 0, y: -1), CGPoint(x: 0, y: 1)] {
                context.draw(shadow,
                             at: CGPoint(x: labelPoint.x + offset.x, y: labelPoint.y + offset.y),
                             anchor: .top)
            }
            let label = context.resolve(
                Text(name).font(.system(size: 15, weight: .bold)).foregroundColor(.white))
            context.draw(label, at: labelPoint, anchor: .top)
        }
    }

    private static func drawBall(
        _ context: inout GraphicsContext,
        at point: CGPoint,
        opacity: Double,
        ring: Bool
    ) {
        let d: CGFloat = 28
        let rect = CGRect(x: point.x - d / 2, y: point.y - d / 2, width: d, height: d)
        if ring {
            context.stroke(Path(ellipseIn: rect.insetBy(dx: -6, dy: -6)),
                           with: .color(Theme.arrow), lineWidth: 4)
        }
        context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(opacity)))
        context.stroke(Path(ellipseIn: rect), with: .color(Theme.ballOutline.opacity(opacity)),
                       lineWidth: 3)
        let dot = CGRect(x: point.x - 4.5, y: point.y - 4.5, width: 9, height: 9)
        context.fill(Path(ellipseIn: dot), with: .color(Theme.ballOutline.opacity(opacity)))
    }
}

/// The pitch as a SwiftUI view.
struct PitchCanvas: View {
    let format: MatchFormat
    let frame: Frame
    let squad: [UUID: SquadPlayer]
    var arrow: StepArrow?
    var preview: TouchPreview?
    var selection: Piece?
    var highlightedHolder: PlayerRef?

    var body: some View {
        Canvas { context, size in
            PitchRenderer.draw(
                &context, size: size, format: format, frame: frame, squad: squad,
                arrow: arrow, preview: preview, selection: selection,
                highlightedHolder: highlightedHolder)
        }
    }
}

/// A small picture of a sequence's starting setup, using the same drawing scaled down.
struct SequencePreview: View {
    let sequence: TacticsSequence
    let squad: [UUID: SquadPlayer]

    private static let reference = CGSize(width: 1180, height: 820)

    var body: some View {
        Canvas { context, size in
            let reference = SequencePreview.reference
            let scale = min(size.width / reference.width, size.height / reference.height)
            context.scaleBy(x: scale, y: scale)
            PitchRenderer.draw(
                &context, size: reference, format: sequence.format,
                frame: Frame(board: sequence.setup), squad: squad)
        }
        .aspectRatio(SequencePreview.reference.width / SequencePreview.reference.height,
                     contentMode: .fit)
    }
}

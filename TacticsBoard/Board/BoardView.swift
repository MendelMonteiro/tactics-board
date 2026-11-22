import SwiftUI
import TacticsCore

/// Finds the sequence for a route and shows the board, saving every change straight away.
struct BoardLoader: View {
    @EnvironmentObject private var library: LibraryModel
    let route: BoardRoute

    var body: some View {
        if let sequence = library.sequence(id: route.sequenceID) {
            BoardView(
                sequence: sequence,
                startInEdit: route.startInEdit,
                persist: { library.saveSequence($0) })
        } else {
            Text("That sequence no longer exists.")
                .toolbar(.hidden, for: .navigationBar)
        }
    }
}

/// Layout A: the pitch fills the screen, with a thin top bar and a thin bottom bar.
struct BoardView: View {
    @EnvironmentObject private var library: LibraryModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: BoardViewModel

    init(sequence: TacticsSequence, startInEdit: Bool, persist: @escaping (TacticsSequence) -> Void) {
        _model = StateObject(
            wrappedValue: BoardViewModel(sequence: sequence, startInEdit: startInEdit, persist: persist))
    }

    var body: some View {
        ZStack {
            Theme.pitch.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                pitchArea
                bottomBar
            }
        }
        .overlay(alignment: .bottom) { hintBubble }
        .toolbar(.hidden, for: .navigationBar)
        .alert(
            model.pendingRange.map { replacePrompt(for: $0) } ?? "",
            isPresented: Binding(
                get: { model.pendingRange != nil },
                set: { shown in if !shown { model.cancelPending() } }
            ),
            actions: {
                Button("Replace", role: .destructive) { model.confirmPending() }
                Button("Cancel", role: .cancel) { model.cancelPending() }
            }
        )
        .libraryAlert(library)
        .onDisappear { model.stopPlayback() }
    }

    private var nowSeconds: Double { Date().timeIntervalSinceReferenceDate }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 16) {
            Button {
                model.stopPlayback()
                dismiss()
            } label: {
                Label("Back", systemImage: "chevron.left")
            }
            .buttonStyle(BarButtonStyle())

            Text(model.name)
                .font(.headline)
                .lineLimit(1)
            Text(model.format.displayName)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))

            Spacer()

            Button(model.isEditing ? "Done" : "Edit") {
                if model.isEditing {
                    model.leaveEdit()
                } else {
                    model.enterEdit()
                }
            }
            .buttonStyle(BarButtonStyle(isSelected: model.isEditing))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 56)
        .background(Theme.barBackground)
    }

    // MARK: Pitch

    private var pitchArea: some View {
        GeometryReader { geo in
            let layout = PitchLayout(format: model.format, in: geo.size)
            TimelineView(.animation(paused: !model.isPlaybackRunning)) { context in
                let now = context.date.timeIntervalSinceReferenceDate
                let preview = model.preview(layout: layout)
                PitchCanvas(
                    format: model.format,
                    frame: model.displayFrame(at: now, preview: preview),
                    squad: library.squadByID,
                    arrow: model.stepArrow,
                    preview: preview,
                    selection: model.isEditing && model.tool == .move ? model.selection : nil,
                    highlightedHolder: model.highlightedHolder)
                    .onChange(of: context.date) { _, newDate in
                        model.tick(now: newDate.timeIntervalSinceReferenceDate)
                    }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        model.touchChanged(
                            location: value.location,
                            startLocation: value.startLocation,
                            layout: layout)
                    }
                    .onEnded { value in
                        model.touchEnded(
                            location: value.location,
                            startLocation: value.startLocation,
                            layout: layout,
                            now: nowSeconds)
                    }
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var hintBubble: some View {
        if let hint = model.hint {
            Text(hint)
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(Capsule().fill(Color.black.opacity(0.75)))
                .padding(.bottom, 84)
                .allowsHitTesting(false)
                .transition(.opacity)
        }
    }

    // MARK: Bottom bar

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if model.isEditing {
                editTools
            }
            stepLabel
            stepDots
            transport
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .frame(height: 64)
        .background(Theme.barBackground)
    }

    private var editTools: some View {
        HStack(spacing: 8) {
            toolButton("Move", icon: "arrow.up.and.down.and.arrow.left.and.right", tool: .move)
            toolButton("Pass", icon: "arrow.right", tool: .pass)
            toolButton("Shoot", icon: "scope", tool: .shoot)
            Button {
                model.undo()
            } label: {
                Label("Undo", systemImage: "arrow.uturn.backward")
            }
            .buttonStyle(BarButtonStyle())
            .disabled(!model.canUndo || model.isPlaybackActive)
            .opacity(model.canUndo && !model.isPlaybackActive ? 1 : 0.4)
        }
    }

    private func toolButton(_ title: String, icon: String, tool: EditTool) -> some View {
        let needsBall = tool != .move
        let enabled = !model.isPlaybackActive && (!needsBall || model.canPass)
        return Button {
            model.selectTool(tool)
        } label: {
            Label(title, systemImage: icon)
        }
        .buttonStyle(BarButtonStyle(isSelected: model.tool == tool))
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private var stepLabel: some View {
        Text("Step \(model.shownStep) of \(model.stepCount)")
            .font(.footnote.monospacedDigit())
            .foregroundStyle(.white.opacity(0.85))
            .fixedSize()
    }

    /// The dots shrink and scroll sideways, so the bar never overflows on smaller iPads.
    private var stepDots: some View {
        GeometryReader { geo in
            let count = model.stepCount + 1
            let slot = min(36, max(14, geo.size.width / CGFloat(count)))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(0..<count, id: \.self) { index in
                        Button {
                            model.jump(to: index)
                        } label: {
                            Circle()
                                .fill(index <= model.shownStep ? Color.white : Color.white.opacity(0.25))
                                .frame(width: slot * 0.5, height: slot * 0.5)
                                .frame(width: slot, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(minWidth: geo.size.width)
            }
        }
        .frame(height: 44)
    }

    private var transport: some View {
        HStack(spacing: 8) {
            Button {
                model.stepBack()
            } label: {
                Image(systemName: "backward.frame.fill")
            }
            .buttonStyle(BarButtonStyle())
            .disabled(model.shownStep == 0)
            .opacity(model.shownStep == 0 ? 0.4 : 1)

            Button {
                model.togglePlay(now: nowSeconds)
            } label: {
                Image(systemName: model.isPlaybackRunning ? "pause.fill" : "play.fill")
                    .frame(width: 28)
            }
            .buttonStyle(BarButtonStyle(isSelected: model.isPlaybackActive))
            .disabled(model.stepCount == 0)
            .opacity(model.stepCount == 0 ? 0.4 : 1)

            Button {
                model.stepForward(now: nowSeconds)
            } label: {
                Image(systemName: "forward.frame.fill")
            }
            .buttonStyle(BarButtonStyle())
            .disabled(model.shownStep >= model.stepCount)
            .opacity(model.shownStep >= model.stepCount ? 0.4 : 1)

            Button {
                model.cycleSpeed(now: nowSeconds)
            } label: {
                Text(model.speed.label)
                    .monospacedDigit()
                    .frame(width: 34)
            }
            .buttonStyle(BarButtonStyle())
        }
    }
}

# Tactics Board: rebuild brief for Claude

> **For Claude:** You're rebuilding an iPad app that already exists and is in use on
> another machine. This file contains no code on purpose: it describes what to build and
> how it must behave, and you write the code. It holds:
> - Part A: the brief, in the coach's words,
> - Part B: changes made during and after the first build,
> - Part C: the approved design,
> - Part D: the implementation plan, in plain English,
> - Part E: the coach's install guide.
>
> **Where Part B conflicts with Part C or D, Part B wins.** Those are decisions the coach
> has already accepted. Don't re-brainstorm. Read B, then C, then D.
>
> Suggested flow:
> 1. Create the repo.
> 2. Save Part C as the design document and Part D as the plan, both under docs/superpowers.
> 3. Implement the plan task by task, writing tests first (superpowers:executing-plans if
>    available). Fold in each Part B item when you reach the task it touches.
> 4. Finish with one whole-project review.
>
> The coach builds this for their son's football team and keeps it local: no remote, no
> PRs. Use they/them for the coach.

## Part A: The brief, in the coach's words

- "An interactive tactical football board where I can select the number of players on each
  side and then move them around… name each player and give them a number… represent both
  teams… create sequences where I show a pass between players and players moving and
  shooting… then replay this sequence… to show the team before and during the match."
- The app targets the iPad, so the kids can see the pitch, the circles and the ball.
- It supports 5, 7, 9 and 11-a-side. The team currently plays 7-a-side, so that's the default.
- A step is one of: select a player or the ball and move it to a point, pass to a player or
  into space, or shoot.
- Steps are discrete and never overlap.
- Steps have no labels. Sequences are named.
- The pitch looks the same when setting up and when replaying.
- The squad is entered once and reused. The opposition is numbered circles in another colour.
- Layout A: the pitch fills the screen, with a thin bottom bar.
- Must work offline. Must not be fiddly.
- Saved sequences open in view mode, with Edit and Done buttons.
- Steps are only added at the end. Adding while showing an earlier step asks
  "Replace steps K+1–N?".

## Part B: Changes after the plan (these win over C and D)

### B1. Environment and project setup

- **The Xcode project is written by hand.** XcodeGen couldn't be installed, so don't use it.
  - Use the modern project format, where the app's source folder is synchronised
    automatically, so new files are picked up without editing the project.
  - Reference the core package as a local package, and link its library into the app.
  - Settings that matter:
    - the bundle identifier is com.mendelmonteiro.TacticsBoard and is fixed, because
      changing it would lose the coach's saved data on the iPad,
    - iPad only, iOS 17 or later, Swift 6,
    - landscape left and right only, and full screen,
    - a generated Info.plist with the display name "Tactics Board",
    - the app icon set is called AppIcon,
    - automatic signing.
  - Settings can also come from a shared configuration file, Config/Base.xcconfig. It
    optionally includes a local, git-ignored file where a development team could be set.
    Commit a template of that local file with the team left empty. In practice the coach
    picks their team in Xcode's Signing & Capabilities tab.
- **Use Xcode's toolchain.** The Mac may still point at the Command Line Tools, which lack
  the Swift Testing macros. Point individual commands at Xcode rather than asking the coach
  to change the system-wide setting.
- **Sandbox workarounds.** These are needed if Claude's own command sandbox blocks the build
  tools' sandboxes.
  - Two helper scripts live in scripts/: one runs the core tests and one builds the app for
    a generic iPad simulator into a build folder inside the repo.
  - The test script turns off the Swift package manager's sandbox.
  - The build script turns off the package-manifest and plugin sandboxes, and the
    compiler's plugin sandbox. Without the compiler setting, the Observable macro fails
    with a "malformed response" error.
  - The iPad simulator usually can't be started from inside the sandbox. Build to check
    instead, and let the coach run the app.
- **Git ignores:** the build folder, Xcode user data, the local configuration file, the
  .superpowers folder, derived data and the .swiftpm folder.
- **Swift 6 typed errors:** a function that rethrows loses the specific error type, so catch
  the specific library error by its case. A test's "require" check can't wrap a mutating
  call, so call it first and check the result.

### B2. Decisions made while building (keep these)

- **Move tool.** Dragging a piece moves it. Tapping a piece selects it; tapping it again
  deselects it. Tapping another player switches the selection. With a piece selected,
  tapping the ball or the grass moves the piece there.
- **Pass and shoot.** While the finger is down, show the pass or shot arrow and a ghost
  ball. The piece under the finger right now decides what's previewed.
- **The held ball** is drawn beside its holder, 0.45 × the token diameter away. Touches are
  matched to where it's drawn, and the ball wins ties.
- **Pitch fit.** The pitch is scaled to fit, with room left for the goals at both ends.
- **Undo** is refused in view mode.
- **Damaged steps.** When a sequence is opened, any steps from the first invalid one onwards
  are dropped.
- **Damaged file.** A data file that can't be decoded is moved aside, renamed with
  ".corrupt-" and a timestamp, and the coach sees a one-time notice at launch.
- **Signing.** The team is chosen in Xcode, not in the configuration file. That's acceptable.
- **Touch logic.** Turning a touch into an edit (which piece, which tool, tap or drag) lives
  in the core package as plain logic with its own tests, not in the screen code.

### B3. Fixes from the final review (all must be present, each with a test)

1. **Pass tap on the holder.** With Pass selected, tapping the player who has the ball
   doesn't record a pass to themselves. It shows the hint "Now tap a teammate or an open
   space.".
2. **Pass receiver.** The receiver is whoever is under the finger when it lifts, not where it
   touched down. Dragging from the passer to a teammate works.
3. **Setup pickup.** During setup, dragging a player onto a loose ball gives them the ball.
   This matters because new sequences start with the ball loose on the centre spot.
4. **Pickup reach.** The reach for picking up a loose ball is 3.5% of the pitch length,
   replacing the fixed 1.5 m, so it is about a token's width in every format.
5. **Stale gestures.** The edit gesture starts fresh for every new touch.
6. **Tapping the selected piece.** With Move selected, tapping the already-selected piece
   deselects it. It doesn't record a zero-length move.
7. **Safe loading.** Loading returns an empty library only when the file doesn't exist.
   - If the file exists but can't be read, saving is blocked and the coach is told.
   - If it can't be decoded, it's moved aside and the coach is told. If the move fails,
     saving is blocked instead.

   A failed move must never lead to the original file being overwritten.
8. **Open at the start.** Saved sequences open in view mode on the setup, before step 1.
   Pressing Edit jumps to the last step.
9. **Save errors on the board.** The board screen shows the "Not saved" alert too, not just
   the list.
10. **Bottom bar.** The step dots shrink and scroll sideways, so the bar never overflows on
    smaller iPads.

### B4. Small issues deliberately left (don't fix unless asked)

- The replace confirmation is worded oddly for setup changes.
- Undo isn't limited to the last step.
- A name can be hidden under the bottom bar when a player is on the bottom touchline.
- The squad number field doesn't refresh after a number is pulled back into 1–99.
- A hand-edited file with the same player twice crashes the app.
- The board is recalculated on every redraw (fine for short sequences).
- Names are 15 pt and may be small to read from 2 m.
- The pass arrowhead hides under the receiving player.
- "Step 0 of N" could say "Start".

### B5. After the plan: app icon

- A single 1024 × 1024 opaque PNG in the AppIcon set, drawn by a small Swift script in
  scripts/ using Core Graphics, so it can be regenerated.
- The design:
  - pitch green #2E7D32 with lighter mown stripes #388E3C in eighths,
  - a white outline 90 px in from the edge, a halfway line and a centre circle of
    radius 150 px,
  - two blue (#1565C0) player circles and one red (#C62828), each of radius 95 px with a
    white ring and a soft shadow,
  - a dashed yellow (#FFEB3B) pass arrow with a solid head between the two blue players,
  - a white ball with black dots next to the receiving player.

### B6. What the finished project looks like

- **Core package:** 85 tests, all passing. It covers formats, the board rules, sequences
  and the editor, playback, pitch layout, the library and its storage, and touch handling.
  There is a separate test file for the review fixes.
- **App:** the app entry point, the shared library model, the sequence list, the squad
  screen, the new-sequence screen, the colour theme, and a board folder with the board
  screen, the pitch drawing, the player and ball layer, the step arrow and the gesture
  handling.
- **Docs:** the coach's install guide (Part E).

---

# Part C: Approved design (spec)

# Tactics Board: Design

Date: 2026-11-21
Status: Draft for approval

## Intent

An iPad app for a parent who coaches their son's youth football team. They use it
before and during matches (in the dressing room, on the touchline, at
half-time) to show the kids moves on a pitch: where players stand, who passes
to whom, who runs where, and who shoots. The kids watch a sequence play out as
animation on the screen.

What success looks like: the coach opens the app, taps a saved sequence, and
within seconds the kids see clear circles moving on a pitch. Building a
sequence at home before a match should feel quick and not fiddly.

## Goals

- Show a football pitch, with circles for the players of both teams and a ball.
- Support 5-a-side, 7-a-side, 9-a-side and 11-a-side. 7-a-side matters most,
  because the team plays it now.
- Hold a squad of the coach's own players, each with a name and a shirt number,
  entered once and reused in every sequence.
- Show the opposition as numbered circles in a different colour, with no names.
- Build a **sequence**: a starting setup plus an ordered list of steps.
- Replay a sequence as an animation, with pause and step forward and back.
- Save multiple named sequences on the iPad.

## Anti-goals (failure even if it technically works)

- **Needs the internet.** Everything must work fully offline. All data stays on
  the device. (Stated by the coach.)
- **Fiddly.** Big touch targets, few taps, nothing that needs precise fingers.
  (Stated by the coach.)
- **Hard to read at a glance.** Circles, numbers and the ball must be big and
  high-contrast enough to read outdoors from a couple of metres away. (My call.)
- **Accidental edits during replay.** A child touching the screen during Play
  must not change the sequence. During replay, touches only pause or resume.
  (My call.)
- **Slow to get to Play.** Launching the app goes straight to the list of
  sequences, and a sequence is one tap from Play. (My call.)

## Non-goals (version 1)

- Steps that happen at the same time. Each step completes before the next one
  begins. (Stated by the coach.)
- Text labels on steps. (Stated by the coach.)
- iPhone layout, portrait orientation, Mac. iPad landscape only.
- Sharing or exporting sequences, iCloud sync, multiple devices.
- Several squads or teams. There is one squad, the coach's own.
- Freehand drawing or annotation on the pitch.
- Opposition names.
- Sound, video export, player statistics.

## Platform (my call, accepted by the coach)

- Native iPad app in Swift and SwiftUI, built with Xcode on the coach's Mac.
  Xcode is not installed yet.
- Installed on the coach's own iPad from Xcode. With a free Apple ID the install
  expires after 7 days and must be reinstalled. A paid developer account makes
  it last a year. Version 1 assumes the free account, so no App Store, TestFlight
  or paid-only capabilities.
- Target a recent iPadOS (17 or later) so SwiftUI and SwiftData are available.
- Storage is local only. Whether that is SwiftData or Codable JSON files is left
  to the builder.
- The coach installs Xcode themselves. The plan must include a plain step-by-step
  guide covering: installing Xcode, signing in with an Apple ID, enabling
  Developer Mode on the iPad, building and running on the iPad, and
  reinstalling every 7 days. The bundle identifier stays fixed so a reinstall
  keeps saved data. (My call.)

## Core concepts

### Format

One of 5, 7, 9 or 11-a-side. The format sets:

- **Players per side.** 5, 7, 9 or 11, each including a goalkeeper.
- **Pitch proportions and markings.** Smaller formats use smaller-pitch
  proportions. Every format is drawn to fill the screen, so the circles stay the
  same size on screen. Use roughly standard youth dimensions: 5v5 about 37×27 m,
  7v7 about 55×37 m, 9v9 about 73×46 m, 11v11 105×68 m. Exact numbers and
  markings are left to the builder. (My call.)

Store positions in pitch-relative coordinates (0 to 1 on each axis) so drawing
does not depend on screen size.

### Squad

- One squad, owned by the coach. Each player has a name and a shirt number.
- The squad can be larger than any format (subs), up to at least 16 players.
- It is edited on its own screen: add, rename, change number, remove.
- **Shown as:** a blue circle with the number inside and the name underneath.

### Opposition

- Numbered red circles, one per position for the chosen format, with no names.
- Default numbers run 1 to N. Letting the coach edit them is left to the
  builder.

### Sequence

- Has a **name** (for example "Goal kick, play out left"), a **format**, a
  **starting setup** and an **ordered list of steps**.
- **Starting setup:** which squad players are on the pitch (exactly one per
  slot in the format), where every player on both teams stands, and where the
  ball is (at a player's feet or on a spot).
- **Steps:** each step is exactly one action, and steps play strictly one after
  another.

### Actions

| Action | How the coach adds it | What happens on replay |
|---|---|---|
| **Move** | Select a player (either team) or the ball, then drag or tap a destination point. | It travels in a straight line to that point. |
| **Pass** | Select the player who has the ball, then tap a teammate **or an empty spot**. | The ball travels there. If it reaches a teammate, that player now has the ball. If it goes into space, the ball rests on that spot. |
| **Shoot** | Select the player who has the ball, then tap a point in or near the goal. | The ball travels there. A brief goal highlight is left to the builder. |

Possession rules (my call):

- The ball belongs to at most one player at a time. When a player who has the
  ball moves, the ball moves with them (a dribble).
- A loose ball belongs to whoever is moved onto it, or the coach can move the
  ball itself.
- Pass and Shoot are available only when a player has the ball.
- Passing to an opposition player (an interception) is allowed. The ball goes to
  that player.

## Screens

### 1. Sequence list (the launch screen)

- A grid of saved sequences, each a small pitch preview showing the starting
  setup, with its name and format.
- Tapping one opens it on the main screen, ready to play.
- Buttons for a new sequence and the squad. Rename, duplicate and delete come
  from a long press. (Duplicate is my call, for making variants of a move.)

### 2. New sequence

- Pick a name and a format.
- Pick which squad players start. A sensible default is the first N.
- Players of both teams start in a sensible default formation for that format.
  The coach drags them into position on the main screen before recording steps.

### 3. Main screen (layout A, chosen by the coach)

The iPad is held landscape and the **pitch fills almost the whole screen**. It
looks the same when setting up, building and replaying (stated by the coach).

- **Top bar (thin):** a back button to the sequence list, the sequence name and
  the format.
- **Bottom bar (thin):**
  - Left: **Move**, **Pass**, **Shoot**, **Undo**
  - Middle: progress shown as dots (for example "step 1 of 3, ● ○ ○")
  - Right: **back one step**, **Play/Pause**, **forward one step**
The screen has two modes (agreed with the coach):

- **View mode (default).** A saved sequence always opens in view mode.
  Touches can only play, pause, step forward and back, and jump to a step dot.
  Nothing on the pitch can be dragged and the edit tools are hidden. An
  **Edit** button in the top bar switches to edit mode. A new sequence opens
  straight into edit mode.
- **Edit mode.** The bottom bar shows **Move**, **Pass**, **Shoot** and
  **Undo**, and a **Done** button returns to view mode. Changes save
  automatically.

- **While editing:**
  - Before any steps exist, dragging a circle sets its starting position.
  - With steps present, the latest step is drawn on the pitch: a yellow dashed
    arrow for a pass or shot, a white dotted line for a run or ball move.
  - Undo removes the last step. Tapping a step dot jumps the pitch to the state
    after that step.
  - **Changing an earlier step (agreed with the coach):** steps are only ever
    added at the end. If the coach jumps to step K of N (K < N) and adds a step,
    the app asks "Replace steps K+1–N?". Confirming discards those steps and
    appends the new one. Cancelling changes nothing. Steps in the middle cannot
    be inserted or edited, so the step list is a simple stack and later steps
    never need re-validating.
- **While replaying (Play, in either mode):**
  - Play resets to the starting setup and then animates each step in order.
  - Arrows and lines are hidden, so only the circles and the ball move.
  - Touching the pitch pauses or resumes. Nothing can be edited.
  - When the animation finishes, the screen stays on the final state in the
    mode it was in before Play.
  - Pace should be easy for kids to follow: a pass moves faster than a run, with
    a short pause between steps. Exact timings are left to the builder, and a
    speed control (for example 0.5×, 1×, 2×) is my call.

### 4. Squad

- A list of players with names and numbers: add, edit and delete.
- Duplicate numbers trigger a warning but are not blocked. (My call.)
- Sequences refer to squad players by identity, so renaming or renumbering a
  player updates them in every sequence. Removing a player who appears in a
  saved sequence is blocked, with a message listing the sequences that use
  them. (My call.)

## Visual style

- Green pitch with white markings. Blue for the coach's team, red for the
  opposition, and a white ball with a dark outline. Fixed colours in version 1.
- Large circles with bold numbers and readable names. The coach's team names sit
  under the circles.
- Mockup reference (from brainstorming): a full-screen pitch, a thin bottom tool
  bar, and a 7v7 example with a pass into space and a forward's run.

## Left to the builder

- Storage technology (SwiftData or JSON files).
- Exact pitch dimensions and markings per format, and default formations.
- Animation timings and easing.
- Exact gestures for selecting a player and choosing a destination, provided
  they are not fiddly: large hit areas, and moving a circle snaps it to the
  nearest legal state.
- What happens to existing steps if the coach edits the starting setup after
  recording steps (for example, block it or replay steps from the new
  positions).
- App icon and name.

---

# Part D: Implementation plan

> **For agentic workers:** implement this task by task (superpowers:executing-plans or
> superpowers:subagent-driven-development). For each task: write the listed tests first,
> watch them fail, write the code, watch them pass, then commit. The plan names behaviours
> and values, not code. Choose your own names and signatures.

**Goal:** an offline iPad app where a youth coach places both teams on a pitch, records a
sequence of moves, passes and shots, and replays it as an animation.

**Architecture:** all the rules and state live in a pure Swift package called TacticsCore:
formats, the board rules, the sequence editor, playback timing, pitch geometry, touch
handling and saving. The package is tested on its own, without Xcode. A thin SwiftUI iPad
app called TacticsBoard draws the core's state and turns touches into core commands. Apart
from drawing and gestures, the app contains no logic the tests can't reach.

**Tech stack:** Swift 6, SwiftUI, Swift Testing, and JSON files for storage. No third-party
dependencies. The Xcode project is written by hand (see Part B1).

## Global constraints

- **Platform:** iPadOS 17 or later, iPad only, landscape only (both ways round), full screen.
- **Offline:** no networking, no network permissions, no analytics. All data stays on the
  iPad.
- **Bundle identifier:** fixed at com.mendelmonteiro.TacticsBoard and never changed, so the
  7-day reinstalls keep the data.
- **Signing:** a free Apple ID only, so no features that need a paid account (no iCloud,
  push notifications or app groups).
- **Colours:**
  - pitch #2E7D32 with white markings,
  - home #1565C0, opposition #C62828,
  - ball white with a dark outline,
  - pass and shot arrows #FFEB3B dashed, runs white dotted.
- **Token sizes:** player circles are the same on-screen size in every format: 52 pt across,
  with a 40 pt touch radius. Numbers are bold and at least 20 pt. Home names are at least
  13 pt, under the circle.
- **Formats:** 5, 7, 9 and 11 players per side, including the goalkeeper. Pitch length ×
  width in metres: 5-a-side 37 × 27, 7-a-side 55 × 37, 9-a-side 73 × 46, 11-a-side
  105 × 68.
- **Steps** run strictly one after another and have no text labels. Sequences have names.
- **Commits:** commit after every task. The repo is created in Task 1.

## Risks to check in review

1. **A corrupt or unreadable data file at launch:** the app still opens, the bad file is
   kept, and it's never overwritten (Task 5, refined by Part B3.7).
2. **A squad smaller than the chosen format:** creating the sequence is refused with an
   explanation. No crash and no half-filled pitch (Task 5).
3. **A piece dragged or tapped off the pitch or onto its edge:** positions are kept on the
   pitch, so no circle is ever lost off-screen (Tasks 1 and 6).
4. **The app killed straight after an edit:** every change is saved immediately and safely,
   so reopening shows the last change (Task 5, checked by hand in Task 10).
5. **A pass or shot by someone without the ball:** the rules reject it, and the Pass and
   Shoot tools are disabled (Task 2).

## Project layout

- In the repo root: the git ignore file, docs (the design, the plan and the install
  guide), a Config folder with the shared build settings and the local-settings template,
  a scripts folder, and the Xcode project.
- **TacticsCore package:** one source file per area: formats, board, sequence, sequence
  editor, playback, pitch layout, library, library storage, and touch handling. Each has a
  matching test file.
- **TacticsBoard app:**
  - the app entry point,
  - the shared library model,
  - the sequence list,
  - the new-sequence screen,
  - the squad screen,
  - the colour theme,
  - the asset catalogue, with the app icon,
  - a Board folder with the board screen, the pitch drawing, the tokens layer, the step
    arrow overlay and the gestures.

---

### Task 1: Package set-up, formats and pitch points

**What to build:**
- **A pitch point:** a position in pitch-relative units.
  - Across the length, 0 is the home goal line and 1 is the away goal line.
  - Across the width, 0 is the top touchline.
  - Both values are always kept within 0–1, including when loaded from a file.
- **A format:** 5, 7, 9 or 11-a-side. Each format knows:
  - its number of players per side,
  - its pitch size in metres,
  - its goal width: 3.66 m for 5 and 7-a-side, 4.88 m for 9-a-side, 7.32 m for 11-a-side,
  - its home formation, with the goalkeeper always first,
  - its away formation, the home one mirrored end to end,
  - the distance in metres between two pitch points.

**Home formations:** positions are given as (along the length, across the width). Copy them
exactly.
- 5-a-side: (0.05, 0.5) (0.22, 0.3) (0.22, 0.7) (0.35, 0.5) (0.45, 0.5)
- 7-a-side: (0.05, 0.5) (0.2, 0.25) (0.2, 0.5) (0.2, 0.75) (0.35, 0.3) (0.35, 0.7) (0.45, 0.5)
- 9-a-side: (0.05, 0.5) (0.2, 0.25) (0.2, 0.5) (0.2, 0.75) (0.33, 0.2) (0.33, 0.5)
  (0.33, 0.8) (0.45, 0.35) (0.45, 0.65)
- 11-a-side: (0.05, 0.5) (0.2, 0.15) (0.2, 0.38) (0.2, 0.62) (0.2, 0.85) (0.33, 0.15)
  (0.33, 0.38) (0.33, 0.62) (0.33, 0.85) (0.45, 0.38) (0.45, 0.62)

**Set-up:**
- Create the repo and the git ignore file.
- Create the core package for iOS 17 and macOS 14, with a library and a test target.

**Tests first:**
- Every format's home and away formations have exactly as many positions as there are
  players per side.
- In 7-a-side, the first away position (the keeper) is at (0.95, 0.5).
- The 7-a-side pitch is 55 × 37 m, and the 11-a-side pitch is 105 × 68 m.
- The point (−0.2, 1.4) is kept on the pitch as (0, 1).
- In 7-a-side, the distance from (0, 0.5) to (1, 0.5) is 55 m.

**Commit:** "formats, pitch points and default formations".

---

### Task 2: Board rules

**What to build:**
- **A player reference:** either a home player, identified by their squad id, or an
  opposition player, identified by their position in the opposition list.
- **The ball:** either held by a player or loose at a point.
- **A step:** one of three kinds.
  - Move a player or the ball to a point.
  - Pass from a player to another player, or into space at a point.
  - Shoot from a player towards a tapped point.
- **Step errors:**
  - the player is unknown,
  - the passer or shooter doesn't have the ball,
  - a player passes to themselves.
- **A board state:** the format, the home players and their positions, the opposition
  players with their shirt numbers and positions, and the ball. A board state can:
  - give any player's position,
  - give the ball's position (a held ball is with its holder),
  - apply a step to produce a new board state, without changing the original, or give a
    step error,
  - work out where a shot ends up.

**Rules:**
- **Moving a player:** the player goes to the target.
  - If the player has the ball, they keep it (a dribble).
  - If the ball is loose and the target is within pickup reach of it, the player now has
    it. Pickup reach was 1.5 m at first; Part B3.4 makes it 3.5% of the pitch length.
- **Moving the ball:** the ball becomes loose at the target. If a player is within pickup
  reach, the nearest one gets it instead.
- **Passing to a player:** the passer must have the ball. The receiver can be on either
  team, so interceptions work. The receiver then has the ball.
- **Passing into space:** the passer must have the ball. It becomes loose at the point.
- **Shooting:** the shooter must have the ball. It becomes loose in the nearest goal mouth:
  - the goal at the home end if the tap is in the home half, otherwise the away end,
  - across the width, kept within the goal mouth (half the goal width either side of the
    middle).

**Tests first:** use a 7-a-side board in the default formations, with seven new squad ids
and the opposition numbered 1–7.
- **Dribble:** home player 7 has the ball and moves to (0.8, 0.5). The ball is then at
  (0.8, 0.5).
- **Pickup:** the ball is loose at (0.5, 0.5). Moving home player 7 to (0.505, 0.5) gives
  them the ball.
- **No pickup:** with the ball still loose at (0.5, 0.5), moving home player 7 to (0.7, 0.5)
  leaves the ball where it was.
- **Pass to a teammate:** possession moves to the teammate.
- **Pass into space:** the ball ends up loose at the target.
- **Interception:** a pass to the fourth opposition player gives them the ball.
- **No ball, no pass:** a pass without the ball is rejected.
- **No ball, no shot:** a shot while the ball is loose is rejected.
- **Pass to self:** rejected.
- **Unknown player:** a tenth opposition player in 7-a-side is rejected as unknown.
- **Shot target:** a shot tapped at (0.9, 0.0) ends at (1, 0.5 − 1.83 ÷ 37).
- **Ball placed next to a player:** that player gets possession.

**Commit:** "board rules for move, pass, shoot and possession".

---

### Task 3: Sequences and the editor

**What to build:**
- **A sequence:** an id, a name, a starting setup (a board state) and a list of steps. It
  can list its board states in order: the setup first, then the state after each step.
  - If a step loaded from a file is invalid, the list stops just before it.
  - The sequence reports how many of its steps are usable.
- **An editor:** a sequence plus a mode (view or edit) and a cursor (which step is shown).
  It can:
  - give the board at the cursor,
  - say whether pass and shoot are possible (someone has the ball at the cursor),
  - enter and leave edit mode,
  - jump to a step,
  - propose an edit (either "add a step" or "drag a piece to a point"),
  - confirm or cancel a pending edit,
  - undo.

**Rules:**
- **View mode** refuses every edit and undo. Only jumping and looking are allowed, to guard
  against little fingers.
- **Checking:** an added step is checked against the board at the cursor first. An invalid
  step is refused with the reason.
- **At the end:** if the cursor is on the last step, the new step is added and the cursor
  moves forward.
- **Earlier on:** otherwise the editor asks for confirmation. It names the later steps that
  would be thrown away, numbered from 1, so the screen can ask "Replace steps 3–5?". The
  edit waits as pending.
- **Confirming** drops the steps after the cursor and applies the pending edit. Cancelling
  changes nothing.
- **Dragging a piece:**
  - on the setup with no steps, it changes the setup directly,
  - on the setup with steps, it asks to replace all of them,
  - on any later step, it's recorded as a move step.

  This means the screen can always send a drag the same way.
- **Moving the ball in the setup** uses the same pickup rule as the board rules.
- **Undo** removes the last step and moves the cursor to the end. With no steps it does
  nothing.
- **Starting position:** the cursor starts at the end. Part B3.8 changes this so view mode
  starts on the setup.

**Tests first:**
- In view mode, both editing and undo are refused.
- Adding a step at the end gives 1 step with the cursor on it.
- With 5 steps and the cursor on step 2, adding a step asks to replace steps 3–5.
- Confirming that leaves 3 steps, with the cursor on step 3.
- Cancelling leaves 5 steps, with the cursor on step 2 and nothing pending.
- A pass with no ball is refused as invalid.
- Dragging a piece with no steps changes the setup.
- Dragging a piece on the setup with 3 steps asks to replace steps 1–3.
- On step 1 of 1, a drag is recorded as a second step, a move.
- Undo removes the last step.
- Jumping to step 99 lands on the last step, and jumping to −1 lands on the setup.
- With the steps (valid, a pass without the ball, valid), the sequence has only 2 board
  states.
- A sequence survives saving to JSON and loading back unchanged.

**Commit:** "sequences and the view/edit editor with replace confirmation".

---

### Task 4: Playback

**What to build:**
- **A frame:** where every piece is drawn at one instant, plus who has the ball, if anyone.
  A frame can also be made directly from a board state, for still pictures.
- **A playback timeline:** built from a sequence and an optional range of steps. By default
  it plays all the steps; stepping forward plays just one. It knows:
  - its total length in seconds at normal speed,
  - the frame at any moment, showing the start before time zero and the end after the
    total length,
  - the step number to show at any moment.
- **Playback speeds:** half, normal and double.
- **A playback clock:** turns real time into timeline time. The current time is passed in,
  so the clock can be tested. It can start, pause, resume and change speed, and it reports
  timeline time (real time × speed) and whether it's running.

**Timings at normal speed:** each step's length is the distance divided by the speed, kept
within limits:
- a player running: 5 m/s, between 0.6 and 2.5 seconds,
- the ball moved or passed: 12 m/s, between 0.4 and 1.5 seconds,
- a shot: 20 m/s, between 0.3 and 1.0 seconds,
- a 0.4-second pause after every step except the last.

**Movement:** movement eases in and out, using the smoothstep curve (3t² − 2t³). Within a
step, only the moving piece changes, plus the ball if the mover has it.

**Tests first:**
- **Run time:** a 7-a-side run of 0.2 of the pitch length (11 m) takes 2.2 seconds.
- **Short runs:** a tiny run still takes 0.6 seconds.
- **Passes are faster:** over the same distance, a pass is quicker than a run.
- **Pauses:** two steps of lengths a and b give a total of a + 0.4 + b.
- **Start and end:** the frame at time zero is the setup, and the frame at the end is the
  final board.
- **Dribbles:** halfway through a dribble, the ball is with the running player.
- **Passes:** at the midpoint of a pass, the ball is exactly halfway.
- **Step numbers:** the step number shown goes up by one per step.
- **Clock pause:** pausing the clock freezes time.
- **Clock speed:** at double speed, time passes twice as fast.
- **Speed change:** changing speed doesn't make the position jump.

**Commit:** "playback timeline, easing and a pausable clock".

---

### Task 5: Squad, library and saving

**What to build:**
- **A squad player:** an id, a name and a shirt number. Numbers are kept within 1–99.
- **A library:** the squad and the saved sequences. It can:
  - add, update and look up players,
  - remove a player, refused while any sequence uses them, with the names of those
    sequences,
  - list shirt numbers used more than once, for a warning,
  - make a new sequence from a name, a format and a list of starters:
    - it's refused if there are fewer starters than the format needs, giving the number
      needed and the number available,
    - it places the first starters in the format's formation,
    - it numbers the opposition from 1,
    - it puts a loose ball on the centre spot,
    - a blank name becomes "Untitled",
    - it adds the new sequence to the library,
  - save a sequence, replacing any existing one with the same id,
  - duplicate a sequence with a new id and the name "<name> copy",
  - delete a sequence.
- **Library storage:** one JSON file, library.json, in a given folder.
  - A missing file means an empty library.
  - A file that can't be decoded is renamed with ".corrupt-" and a date-time stamp, and
    loading gives an empty library. Part B3.7 refines this.
  - Saving writes the whole file in one safe (atomic) step.

**Tests first.** For the library:
- Sequences store players by id, so after renaming a player, looking them up shows the new
  name.
- Removing a player used in "Goal kick" is refused, naming "Goal kick".
- Removing an unused player works.
- Two players numbered 7 are reported as the duplicate number 7.
- Making a 7-a-side sequence with 6 starters is refused: 7 needed, 6 available.
- A new sequence uses the formation and puts the ball on the centre spot.
- A blank name becomes "Untitled".
- Duplicating a sequence copies its steps and gives it a new id.
- The squad supports at least 16 players.

For storage (each test uses a fresh temporary folder):
- A missing file loads as an empty library.
- Save then load gives the same library, including a sequence with a move, a pass and a
  shot.
- Given a file containing "not json", loading gives an empty library, and a corrupt-named
  copy still holds "not json".
- Add a player, save, load, add a step, save, load: the library is the same each time.

**Commit:** "squad rules, sequence library and crash-safe saving".

---

### Task 6: Pitch layout, touch search and markings

**What to build:**
- **A pitch layout** for a format inside a screen area, with a 16 pt margin. It scales the
  pitch to fit, with the length running left to right, and centres it. It can:
  - give the pitch's area on screen,
  - convert a pitch point to a screen point,
  - convert a screen point back to a pitch point, kept on the pitch so a drop off the
    pitch lands on the edge,
  - find the nearest piece within the touch radius (40 pt). If the ball and a player are
    equally near, the ball wins, so the coach can always grab a ball at a player's feet,
  - give the pitch markings.
- **Pitch markings:**
  - the outline, the halfway line and the centre circle (radius 0.09 × the width),
  - penalty areas, 0.16 × the length deep and 0.6 × the width wide,
  - goals drawn outside the goal lines, the format's goal width across and 2% of the
    length deep.
- This works on both macOS and iOS.

**Tests first:**
- In 7-a-side inside a 1180 × 820 area, the pitch keeps its 55 : 37 shape (within 0.01).
- Converting a point to the screen and back gives the same point.
- A drop far off the left edge lands on the left edge.
- The touch search finds the nearest piece within the radius.
- The touch search finds nothing beyond the radius.
- When the ball and a player are equally near, the touch search picks the ball.
- 11-a-side has two penalty areas and two goals.

**Commit:** "pitch layout, touch search and markings".

---

### Task 7: Install guide, Xcode project and app shell

This task needs Xcode installed. Check that it is. If it isn't, ask the coach to finish
installing it.

**What to build:**
- **The Xcode project, by hand,** as described in Part B1.
- **The two helper scripts:** one for the core tests and one for the app build.
- **A shared library model** for the app. It holds the library, loaded at launch, and every
  change goes through it and is saved straight away. A save failure is shown as an alert.
  The data lives in the app's Application Support folder, which is created if missing.
- **The sequence list,** the first screen:
  - a grid of cards, each with a small picture of the setup (a placeholder until Task 9),
    the name and the format,
  - a New sequence button and a Squad button (stubs until Task 8),
  - a long press on a card offers Rename, Duplicate and Delete, and Delete asks for
    confirmation.
- **The install guide** (Part E), written for someone who isn't an iOS developer.

**Check:** the app builds for the iPad simulator, and the core tests still pass. Run the app
in the simulator only if the sandbox allows it.

**Commit:** "Xcode project, install guide and sequence list".

---

### Task 8: Squad and new-sequence screens

**What to build:**
- **The squad screen:** a list of rows, each with a number field and a name field.
  - Add players, and swipe to delete.
  - Duplicate numbers show an orange warning under the list.
  - A blocked delete shows: "Used in: Goal kick, Corner left. Remove them from those
    sequences first."
- **The new-sequence screen:**
  - a name, a format picker (5, 7, 9, 11, defaulting to 7) and a list of starters with
    ticks,
  - the first N squad players are ticked already,
  - Create is disabled until exactly N are ticked,
  - if the squad has fewer than N players, it says "Add at least N players to your squad"
    with a button that opens the squad screen,
  - once created, the new sequence opens on the board in edit mode.
- Replace the stubs in the list.

**Check:** it builds. If the simulator is available, add 8 players, create a 7-a-side
sequence, relaunch, and check that both are still there.

**Commit:** "squad and new-sequence screens".

---

### Task 9: Board screen, drawing and view-mode playback

**What to build:**
- **The board screen:** opens a sequence in view or edit mode.
- **The pitch drawing:** draws the markings.
- **The tokens layer:**
  - draws a frame's players and ball,
  - home players have their numbers and names, the opposition just numbers,
  - sizes come from the global constraints,
  - a held ball is drawn beside its holder, 0.45 × the token diameter towards the way
    they're attacking (right for home, left for away), so it never covers the number.
- **List previews:** the list's card previews use the same drawing, scaled down.

**Layout A:**
- **Top bar:** Back, the sequence name, the format ("7-a-side") and an Edit button.
- **Bottom bar:**
  - left: the tools, empty in view mode,
  - middle: step dots, filled up to the current step, and tapping a dot jumps there,
  - right: back one step (instant), play or pause, forward one step (animated), and a
    speed toggle (0.5×, 1×, 2×).
- **Play** starts from the setup and animates the whole sequence. Touching the pitch pauses
  and resumes it. At the end, the board rests on the last step. No arrows show during play.
- **The pitch** fills the space between the bars.

**Check:** it builds. If the simulator is available, play a sample sequence with a pass into
space, a run and a shot. Check the circles are readable, nothing can be dragged, and a tap
pauses.

**Commit:** "board drawing and view-mode playback".

---

### Task 10: Edit mode

**What to build:**
- **Tools:** Edit shows Move (the default), Pass, Shoot and Undo, and turns into Done.
  - Pass and Shoot are disabled when nobody has the ball.
  - Undo is disabled when there are no steps.
- **Move:** drag any piece, and it follows the finger. On release, the drag goes to the
  editor, which decides whether it's a setup change or a move step. Part B2 adds the tap
  behaviour.
- **Pass:** the player with the ball is highlighted. Tap a player to pass to them, or empty
  grass to pass into space. Part B3.1 and B3.2 refine this.
- **Shoot:** tap anywhere towards a goal. A ghost ball shows where the shot will end before
  it's committed.
- **After each step,** the tool goes back to Move.
- **Confirmation:** when the editor asks for confirmation, show "Replace steps a–b?" with
  Replace and Cancel. If it's a single step, say "Replace step a?".
- **The step arrow** shows only the step leading to the current one:
  - a yellow dashed arrow for a pass or shot,
  - a white dotted line for a move.

  It's hidden during play.
- **Saving:** every change is saved straight away.
- **Rejected steps:** a refused step shows a short hint, never a blocking alert.

**Check:** it builds and the core tests pass. If the simulator is available:
1. Create a 7-a-side sequence and drag three players into place.
2. Record: number 6 passes into space, number 9 runs onto the ball, number 9 shoots.
3. Press Done, then Play.
4. Jump to step 1, press Edit and add a move. Check that "Replace steps 2–3?" appears.
   Cancel, and check that nothing changed.
5. Make an edit, force-quit the app, reopen it, and check the edit is still there.

**Commit:** "edit mode with move, pass, shoot, undo and replace confirmation".

---

### Task 11: On the coach's iPad

1. The coach follows the install guide on their iPad. Help with any errors.
2. Check these with the coach:
   - from about 2 m away, the numbers and names can be read,
   - the app works in airplane mode,
   - a child tapping during play only pauses it,
   - building a 4-step sequence doesn't feel fiddly.
3. Update the install guide with anything learned, and commit.

---

# Part E: Coach install guide

# Putting Tactics Board on your iPad

You need your Mac, your iPad, a cable to connect them, and an Apple ID. You do not
need a paid developer account.

## One-time setup

1. **Install Xcode** from the Mac App Store. Open it once and accept the licence.
   If it asks which platforms to install, tick **iOS**.
2. **Add your Apple ID to Xcode.** Go to **Xcode → Settings → Accounts**, click
   **+**, choose **Apple ID** and sign in. A team called
   "*Your Name* (Personal Team)" appears.
3. **Open the project.** Double-click TacticsBoard.xcodeproj in the
   tactics-board folder. Wait for the progress bar at the top to finish. It
   prepares the TacticsCore package the first time.
4. **Choose your team for signing.**
   1. Click the blue **TacticsBoard** icon at the top of the left sidebar.
   2. Select the **TacticsBoard** target, then open the
      **Signing & Capabilities** tab.
   3. Tick **Automatically manage signing**. Under **Team**, pick your
      Personal Team.

   If Xcode says the bundle identifier is unavailable, tell Claude. Don't change
   it yourself, because changing it later would lose your saved sequences.
5. **Turn on Developer Mode on the iPad.**
   1. Connect the iPad to the Mac with the cable and tap **Trust** on the iPad.
   2. On the iPad, go to **Settings → Privacy & Security → Developer Mode**, and
      switch it on.
   3. The iPad restarts. Confirm **Turn On** when it comes back.

   If Developer Mode isn't listed, do step 6 once first, then come back.
6. **Run the app.** In Xcode's toolbar at the top, click the device menu (it
   says something like "iPad Air (11-inch)") and pick **your iPad** from the
   list. Press the **▶ Run** button.
7. **Trust yourself as a developer (first time only).** The first launch is
   blocked with "Untrusted Developer". On the iPad, go to
   **Settings → General → VPN & Device Management**, tap your Apple ID and tap
   **Trust**. Then open Tactics Board from the home screen.

The app is now on your iPad and works without Wi-Fi.

## Every 7 days

With a free Apple ID, the app stops opening after 7 days. To fix it, plug the
iPad in, open the project in Xcode and press **▶ Run** again. **Your squad and
sequences are kept.**

With a paid Apple Developer account ($99/year), this becomes once a year.

## If something goes wrong

| Message | What to do |
|---|---|
| "Untrusted Developer" | See step 7. |
| "The app is no longer available" or it won't open | It's been 7 days, so press Run again. |
| "Developer Mode disabled" | See step 5. |
| "No account for team" or a signing error | Repeat step 4 and pick your Personal Team. |
| iPad isn't in the device list | Unlock the iPad, re-plug the cable and tap Trust. |

# Tactics Board

An offline iPad app for a youth football coach: place both teams on a pitch, record a
sequence of moves, passes and shots, and replay it as an animation.

The full brief is in [`docs/TACTICS-BOARD-REBUILD.md`](docs/TACTICS-BOARD-REBUILD.md).

## What is here so far

- `TacticsCore/` is a pure Swift package with all the rules and logic (spec Tasks 1–6 and
  the touch logic from Part B): formats, board rules, sequences and the editor, playback,
  the library and its crash-safe storage, pitch layout and touch handling. It has its own
  tests and needs no Xcode project.
- `.github/workflows/ci.yml` runs `swift test` on a macOS runner for every push.

Still to come: the SwiftUI app (Tasks 7–10), an Xcode project, and an unsigned `.ipa`
build job for sideloading.

## Running the tests

On GitHub: push, then open the **Actions** tab. On a Mac:

    cd TacticsCore
    swift test

## Notes

- Signing details (a team ID, certificates) must never be committed. `Config/Local.xcconfig`
  is git-ignored for that reason.
- Use made-up player names in any sample data. This is a children's team.

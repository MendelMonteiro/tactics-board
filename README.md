# Tactics Board

An offline iPad app for a youth football coach: place both teams on a pitch, record a
sequence of moves, passes and shots, and replay it as an animation.

The full brief is in [`docs/TACTICS-BOARD-REBUILD.md`](docs/TACTICS-BOARD-REBUILD.md).

## Layout

- `TacticsCore/` is a pure Swift package with all the rules and logic, tested on its own.
- `TacticsBoard/` is the SwiftUI iPad app. It only draws state and turns touches into
  core commands.
- `project.yml` is the XcodeGen definition. CI generates `TacticsBoard.xcodeproj` from it.
- `scripts/make_icon.py` redraws the app icon (needs Pillow).

## CI (GitHub Actions)

Every push runs three jobs:

1. **TacticsCore tests** (`swift test`)
2. **Build app (iPad simulator)**, which checks the app compiles
3. **Unsigned IPA**, which uploads `TacticsBoard.ipa` as a downloadable artifact

## Getting the app onto an iPad (free Apple ID, from Windows)

1. Open the repo's **Actions** tab, open the latest green run, and download the
   **TacticsBoard-unsigned-ipa** artifact. Unzip it to get `TacticsBoard.ipa`.
2. On the iPad: **Settings → Privacy & Security → Developer Mode → On** (it restarts).
3. On the PC, install **Sideloadly** (sideloadly.io). It needs iTunes and iCloud from
   Apple's website, not the Microsoft Store versions.
4. Connect the iPad, drag `TacticsBoard.ipa` into Sideloadly, enter your Apple ID and press
   **Start**.
5. On the iPad: **Settings → General → VPN & Device Management →** your Apple ID **→ Trust**.

With a free Apple ID the app stops opening after 7 days. Repeat steps 4–5 (or let AltStore
refresh it) to renew it. Your squad and sequences are kept as long as the app's bundle
identifier doesn't change. Check this once after your first reinstall.

## Notes

- Signing details (a team ID, certificates) must never be committed. `Config/Local.xcconfig`
  is git-ignored for that reason.
- Use made-up player names in any sample data. This is a children's team.

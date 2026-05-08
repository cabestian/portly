# Portly

A tiny macOS menu-bar app that lists active local HTTP servers and lets
you open them in your browser with a single click.

## Why

When you're juggling several dev servers (`next dev`, `cargo run`, vault
routers, side projects), figuring out which port is which becomes a chore.
Portly scans local TCP listeners, probes them for HTTP, and surfaces a
clickable list:

```
Next.js Dashboard      :4280
Cockpit                :3000
Vault Router           :7777
postgres               :5432    (informational only, not clickable)
```

## Build

Requirements: macOS 14 (Sonoma) or later, Xcode Command Line Tools (no
full Xcode install needed), Homebrew.

```bash
git clone https://github.com/maximelhuillier/portly.git
cd portly
./scripts/build.sh
open build/Portly.app
```

The build script compiles the app with `swiftc` and ad-hoc signs it. The
icon appears in the menu bar (no Dock icon — `LSUIElement` is on).

To install permanently, copy `build/Portly.app` to `/Applications/`.

## How it works

- `lsof -nP -iTCP -sTCP:LISTEN` lists local TCP listeners.
- Each port is GET-probed at `http://127.0.0.1:<port>/` (300 ms timeout).
  Any HTTP response makes the entry clickable.
- For HTTP entries, the `<title>` is fetched (first 2 KB) and used as
  the display name. Otherwise we fall back to the working-directory
  basename or the process command name.
- Snapshots are written to `~/Library/Application Support/Portly/`.

## Architecture

- `PortScanCore/` — Swift Package, pure logic, fully unit-tested with
  [Swift Testing](https://github.com/apple/swift-testing).
- `PortlyApp/` — AppKit menu-bar host running the scan loop.

## Testing

```bash
cd PortScanCore && swift test
```

The core tests run under Command Line Tools alone — no full Xcode needed.

## Limitations

- Sandbox is **off** so the app can run `lsof`. Mac App Store distribution
  is not possible.
- Only TCP listeners on `127.0.0.1`, `::1`, or `*` are surfaced.
- HTTP only — Postgres / Redis / etc. show up as informational rows but
  are not clickable.
- **No desktop widget.** A WidgetKit medium widget was implemented and
  works in code, but macOS `chronod` only registers widgets signed with
  an Apple Developer ID (notarised). Ad-hoc signed extensions are
  silently ignored, so widgets are off the table without a paid
  Developer account. The widget code lives in git history (commit
  `ae36a75`) and can be revived if a Developer ID is available.

## License

MIT — see [LICENSE](LICENSE).

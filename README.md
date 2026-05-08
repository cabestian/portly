# Portly

A tiny macOS menu-bar app + WidgetKit widget that lists active local HTTP
servers and lets you open them in your browser with a single click.

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

## Install (development build)

Requirements: macOS 14 (Sonoma) or later, Xcode 15+, Homebrew.

```bash
brew install xcodegen
git clone https://github.com/maximelhuillier/portly.git
cd portly
xcodegen generate
open Portly.xcodeproj
```

In Xcode, select the `PortlyApp` scheme and run. The icon appears in the
menu bar (no Dock icon — `LSUIElement` is on).

To add the widget: Notification Center → Edit Widgets → search "Portly".

## How it works

- `lsof -nP -iTCP -sTCP:LISTEN` lists local TCP listeners.
- Each port is GET-probed at `http://127.0.0.1:<port>/` (300 ms timeout). Any
  HTTP response makes the entry clickable.
- For HTTP entries, the `<title>` is fetched (first 2 KB) and used as the
  display name. Otherwise we fall back to the working-directory basename or
  the process command name.
- The app writes a JSON snapshot into the App Group every 15 s; the widget
  reads it.

## Architecture

- `PortScanCore/` — Swift Package, pure logic, fully unit-tested with
  [Swift Testing](https://github.com/apple/swift-testing).
- `PortlyApp/` — AppKit menu-bar host running the scan loop.
- `PortlyWidget/` — WidgetKit extension (medium family), App Intents.

## Testing

The core can be tested without a full Xcode install — Swift 6+ ships with
swift-testing under Command Line Tools.

```bash
cd PortScanCore && swift test
```

## Limitations

- Sandbox is **off** so the app can run `lsof`. As a result, Mac App Store
  distribution is not on the table.
- Only TCP listeners on `127.0.0.1`, `::1`, or `*` are surfaced.
- HTTP only — Postgres / Redis / etc. show up as informational rows but are
  not clickable.

## License

MIT — see [LICENSE](LICENSE).

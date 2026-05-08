# Portly — Design Spec

**Date:** 2026-05-07
**Status:** Validated (brainstorm), pending implementation plan

---

## 1. Goal

Provide a near-zero-friction way to see all active local HTTP servers on a Mac
and open any of them in the default browser with a single click. Two surfaces:

1. **Menu bar item** — always visible, click to drop down a list of ports.
2. **Desktop / Notification Center widget** — glanceable, with interactive rows
   that open URLs directly via App Intents.

Out of scope for v1: remote port discovery (SSH tunnels), Unix sockets,
notifications on new servers, persisted favourites, global keyboard shortcuts.

## 2. Architecture

A single Xcode project with three targets:

| Target | Type | Responsibility |
|---|---|---|
| `PortScanCore` | Swift Package (local) | Pure logic: scan TCP listeners, probe HTTP, resolve friendly names. No UI. Testable in isolation. |
| `PortlyApp` | macOS app (AppKit + SwiftUI) | Menu bar `NSStatusItem`, dropdown list, preferences. Owns the scan loop. |
| `PortlyWidget` | Widget Extension (WidgetKit) | Small + medium widget. Reads cached snapshot. Rows are App Intents. |

`PortlyApp` and `PortlyWidget` share state through an **App Group**
(`group.app.portly`). The app writes a JSON snapshot
(`snapshot.json`) into the group container after each scan; the widget reads
it via its `TimelineProvider`. The widget never scans on its own (widget
runtime budget is tight, and we want a single source of truth).

```
┌──────────────────────┐         ┌────────────────────┐
│  PortlyApp (menu)    │ writes  │  App Group         │
│  scan loop, UI       ├────────▶│  snapshot.json     │
└──────────────────────┘         └─────────┬──────────┘
                                           │ reads
                                           ▼
                                 ┌────────────────────┐
                                 │  PortlyWidget      │
                                 │  TimelineProvider  │
                                 └────────────────────┘
```

Bundle identifiers:
- App: `app.portly`
- Widget: `app.portly.widget`

## 3. Scan and resolution

### 3.1 Listener discovery

The app shells out to:

```
lsof -nP -iTCP -sTCP:LISTEN -F pcnPL
```

Why `lsof` and not native APIs: native socket enumeration on macOS requires
private SPI or a privileged helper. `lsof` ships with macOS, prints
parse-friendly `-F` records, and is well understood. The buffer is small
(typically under 50 KB) so the subprocess cost is negligible.

The `-F pcnPL` format yields one record per file descriptor with these tagged
fields:
- `p<pid>` — process id
- `c<command>` — command name (truncated to 15 chars by lsof)
- `L<user>` — user name
- `P<protocol>` — `TCP`
- `n<address:port>` — listener address

The parser groups records by process and emits one `Listener` per unique
`address:port`. Listeners on `127.0.0.1`, `::1`, and `*` (any-interface) are
kept; explicitly remote-only binds are dropped.

### 3.2 HTTP probe (default mode)

For each unique port, fire a `URLRequest` with method `HEAD` against
`http://127.0.0.1:<port>/` with a 300 ms timeout. Probes run concurrently in
a `TaskGroup`. If the request returns any HTTP response (any status code,
including 4xx/5xx), the listener is marked `isHTTP = true`. Connection
refused, TLS handshake errors, or timeouts mark it `isHTTP = false`.

Default UI mode shows only `isHTTP = true` listeners. A "Show all listeners"
toggle in the menu surfaces the full list with non-HTTP entries grouped under
a "Services" section (greyed out, non-clickable).

### 3.3 Friendly name resolution

Resolved per listener, in priority order. First non-empty value wins.

1. **HTTP `<title>`** — for HTTP listeners only. Issue a `GET` with
   `Range: bytes=0-2048` and a 500 ms timeout. Parse with a regex
   (`<title>([^<]+)</title>`, case-insensitive). Trim and decode HTML entities.
2. **Process working directory basename** — `lsof -p <pid> -d cwd -F n`,
   take the last path component. Example:
   `/Users/.../next-app/dashboard` → `dashboard`.
3. **Command name** — from the original lsof output (`node`, `cargo`,
   `postgres`).

The displayed string is `displayName · :<port>`, e.g.
`Next.js Dashboard · :4280`.

### 3.4 Refresh cadence

- **Menu open:** scan every 3 s (kicked off when the popover becomes key,
  cancelled when it closes).
- **Background:** scan every 15 s. This keeps `snapshot.json` fresh enough
  for the widget without burning CPU.
- **Manual:** ⌘R while the popover has focus forces an immediate scan.

A scan is cheap (one `lsof` + N parallel HEAD requests) but we keep it off
the main thread and de-duplicate concurrent triggers.

### 3.5 Data model

```swift
struct PortEntry: Codable, Identifiable {
    let port: UInt16
    let pid: Int32
    let command: String           // "node"
    let cwd: String?              // "/Users/.../dashboard"
    let title: String?            // "Next.js Dashboard"
    let isHTTP: Bool
    var id: UInt16 { port }
    var displayName: String {
        title ?? cwd.flatMap { ($0 as NSString).lastPathComponent } ?? command
    }
}

struct Snapshot: Codable {
    let scannedAt: Date
    let entries: [PortEntry]
}
```

Snapshot is JSON-serialised and atomically written to
`<appGroup>/snapshot.json` after each scan.

## 4. UI

### 4.1 Menu bar (PortlyApp)

`NSStatusItem` with the `network` SF Symbol. Click toggles an `NSPopover`
containing a SwiftUI list:

```
┌──────────────────────────────────┐
│ Next.js Dashboard         :4280  │  ← clickable
│   node · ~/next-app/dashboard│     (subtitle, grey)
├──────────────────────────────────┤
│ Cockpit                   :3000  │
│   cargo · ~/cockpit              │
├──────────────────────────────────┤
│ ─ Services (4) ─                 │  ← only when "Show all" is on
│ postgres                  :5432  │  (greyed, non-clickable)
├──────────────────────────────────┤
│ ⌥ Show all listeners      [·]   │
│ ⚙ Preferences…                   │
│ ✕ Quit                            │
└──────────────────────────────────┘
```

Interactions:
- **Click HTTP row** → `NSWorkspace.shared.open(URL("http://localhost:<port>"))`
  via the user's preferred browser.
- **Option-click** → copy the URL to the pasteboard instead of opening.
- **Hover** → tooltip with PID and full command.
- **⌘R** → manual refresh.
- **Toggle "Show all listeners"** → re-render with non-HTTP services visible.

### 4.2 Preferences

Minimal v1:
- Browser target: System default / Chrome / Safari / Firefox.
- Launch at login: bound to `SMAppService.mainApp`.

Stored in `UserDefaults` (suite = app group).

### 4.3 Widget (PortlyWidget)

Two families: `systemSmall` and `systemMedium`.

**Small (2×2):** The 3 most-recent HTTP entries, two-line each
(name + `:port`). Tap target = whole widget = launches the app (small widgets
support only one tap target).

**Medium (4×2):** Up to 5 HTTP entries. Each row is a `Button(intent:)` using
this App Intent:

```swift
struct OpenLocalPortIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Local Port"
    @Parameter var port: Int
    func perform() async throws -> some IntentResult {
        let url = URL(string: "http://localhost:\(port)")!
        await NSWorkspace.shared.open(url)
        return .result()
    }
}
```

`TimelineProvider` returns a single entry whose validity is 30 s. After 30 s
the widget asks for a new timeline and re-reads the snapshot. If the snapshot
is older than 60 s (the app might be quit), the widget shows a faded state
labelled "Portly is not running".

Empty state: "No local servers detected".

## 5. Testing

Unit tests target `PortScanCore`. UI tests are out of scope for v1 (cost vs.
value).

| Suite | What it covers |
|---|---|
| `LsofParserTests` | Parses fixture lsof output: normal IPv4, IPv6, multi-FD same process, process without cwd, malformed line. |
| `HTTPProbeTests` | Spins up an embedded `NWListener` HTTP server in `setUp`, asserts `isHTTP = true` and title extraction. Negative case: a raw TCP listener that never speaks HTTP, asserts `isHTTP = false` after timeout. |
| `NameResolverTests` | Table-driven: title beats cwd beats command. Each level handled in isolation. |
| `SnapshotEncodingTests` | Round-trip a `Snapshot` through JSON, compare. |

Target ≥ 80 % line coverage on `PortScanCore`.

## 6. Build, signing, distribution

- **Toolchain:** Xcode 15+, Swift 5.9+.
- **Deployment target:** macOS 14 (Sonoma) — required for interactive widgets
  via App Intents.
- **Sandbox:** disabled (`com.apple.security.app-sandbox = false`). Required
  to spawn `lsof`. Hardened runtime stays on.
- **App Group:** `group.app.portly` enabled on both targets.
- **Signing:** ad-hoc for personal use during dev. Developer ID + notarisation
  added later if/when distributed publicly.
- **Launch at login:** `SMAppService.mainApp.register()` (modern API,
  user-controllable from System Settings).

Mac App Store distribution is incompatible with the unsandboxed `lsof`
approach. Acceptable trade-off for v1; if the App Store becomes a goal we'll
need a privileged helper (`SMAppService.daemon`) and revisit listener
discovery.

## 7. Definition of done (v1)

- [ ] Menu-bar icon appears on launch; clicking opens the popover.
- [ ] HTTP listeners on `127.0.0.1` are detected within 3 s of starting.
- [ ] Clicking a row opens `http://localhost:<port>` in the configured browser.
- [ ] Option-click copies the URL.
- [ ] "Show all listeners" toggle reveals non-HTTP services in a separate
      section.
- [ ] Medium widget shows up to 5 HTTP rows, each opens its URL when tapped.
- [ ] Small widget shows the top 3, tap launches the app.
- [ ] Launch at login works through System Settings.
- [ ] `PortScanCore` tests are green; coverage ≥ 80 %.
- [ ] `README.md` documents install + first run.

## 8. Open questions (deferred)

These are explicitly punted for v1:

1. **App icon and SF Symbol choice.** Default to `network`; refine later.
2. **Widget background style** (solid vs. accented). Use system default.
3. **Localisation.** English only for v1. French strings considered for v2.
4. **Crash reporting / telemetry.** None in v1. Public release would want a
   minimal opt-in metric (e.g., daily-active counter) — out of scope here.

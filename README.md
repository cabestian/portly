# Portly

A tiny macOS menu-bar app + WidgetKit widget that lists active local HTTP servers
and lets you open them in your browser with a single click.

## Why

When you're juggling several dev servers (`next dev`, `cargo run`, vault routers,
side projects), figuring out which port is which becomes a chore. Portly scans
local TCP listeners, probes them for HTTP, and surfaces a tidy clickable list:

```
Next.js Dashboard      :4280
Cockpit                :3000
Vault Router           :7777
postgres               :5432    (informational only)
```

## Status

Pre-alpha. Design spec lives in [`docs/spec-2026-05-07-portly-design.md`](docs/spec-2026-05-07-portly-design.md).
Code coming next.

## Requirements

- macOS 14 (Sonoma) or later — required for interactive WidgetKit widgets
- Xcode 15+

## License

MIT — see [LICENSE](LICENSE).

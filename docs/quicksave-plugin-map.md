# Quicksave Plugin Map

Quicksave should become plugin material for Surface, not the app shell.

Source repo:

```text
/Users/snbafana/Documents/personal/Scratch/projects/mac-quicksave
```

Useful future blocks:

- `quicksave.captures`: recent captures, latest clipboard save, unrouted captures.
- `quicksave.obsidian`: daily note exists, append latest, failed append retry.
- `quicksave.notes`: context notes and note sidecars.
- `quicksave.status`: inbox path, vault path, last append status.

Files to reuse later:

- `src/core/clipboard-capture.swift`: capture engine for a future captures provider.
- `src/core/context-note-writer.swift`: sidecar note logic for a future notes provider.
- `src/core/obsidian-daily-notes.swift`: daily-note append engine for a future Obsidian provider.
- `src/core/file-naming.swift`: filename helpers.
- `src/core/settings.swift`: useful config shape, but likely replaced by Surface config.

Files to avoid as architecture:

- `src/app/delegate.swift`: old menu-bar host and hotkey wiring.
- `src/app/note-panel.swift`: old single-purpose note UI.
- `src/cli/main.swift`: useful behavior reference, not the Surface command model.

Boundary:

Surface owns overlay, layout, block editing, and provider lifecycle. Quicksave owns capture and Obsidian behavior when imported as a provider.

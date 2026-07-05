# Surface Plugin Research

Heartbeat-style research folder for plugin ideas that fit Surface's current block model.

Files:

- `heartbeat-ledger.md`: cycle log, scope, stop conditions, and next heartbeat prompts.
- `source-ledger.tsv`: source inventory with links and what each source suggests.
- `plugin-ideas.md`: ranked plugin ideas with implementation notes.
- `queue.md`: follow-up research and implementation queue.

This is intentionally repo-local. New plugin ideas should graduate from here into `plugins/<id>/source`, `plugins/<id>/tests`, `plugins/Blocks.swift`, `Package.swift`, and `tools/block-preview/support/BlockPreviewSupport.swift`.

# Milestone 0 Studio backups

These dated exports are rollback snapshots of the active Roblox Studio place
before and after the pre-horror baseline work. They are intentionally retained
alongside the source repository.

- `*_pre-horror_*` files are the untouched rollback point captured before the
  schema/source changes.
- `*_milestone-0-verified_*` files are the synchronized state captured after
  compilation, edit/runtime audits, and responsive UI smoke testing passed.
- Each set separates the complete environment, 25 active runtime/config
  sources, three interactive door models, and 11 player scripts so restoration
  can be narrow rather than all-or-nothing.

Checksums and the exact Studio-to-local source map are in
`../../MILESTONE0_BASELINE.md`.

Never import a backup over the live place without first opening it in a blank
local Studio session and confirming its contents.

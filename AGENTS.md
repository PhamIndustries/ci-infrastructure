# Agent instructions

## Decisions log (DECISIONS.md)

Keep `DECISIONS.md` at the repo root (git root); create it if missing with a `# Decisions` header. Same format the Anvil harness enforces.

- Record every non-trivial decision when it is made: architecture, dependencies, model or config defaults, rejected alternatives, reversals, and anything Vu decides in chat (tag those `(Vu)`).
- One line per entry, under 300 characters, newest at the bottom, dates in PT:
  `- YYYY-MM-DD: <decision> — <why / context>; rejected: <alternatives>; consequence: <what changes>; ref <commit/PR>`
  Drop the parts that do not apply. Append with `printf '%s\n' "- $(date +%F): ..." >> DECISIONS.md`.
- Never rewrite, reorder or delete past entries. To change one, append a new entry: `supersedes YYYY-MM-DD <short name>`.
- Before proposing a change, run `tail -n 30 DECISIONS.md` (and grep it for the topic); treat entries as settled unless Vu changes them, and cite any entry your change would contradict.
- Commit the entry together with the change it describes. Do not read `DECISIONS-archive.md` unless Vu asks.

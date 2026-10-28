# Agent instructions — ci-infrastructure

**Current line count: 9 (must stay ≤ 100 lines)**

This repo defines fleet CI (`python-uv-ci.yml`, `docs/AGENT_CI.md`, `docs/DEPLOY.md`). Callers pin a commit SHA: cut a tag, then bump each caller's SHA in its own repo (Vu names them).

## Shared rules

Follow the shared agent rules in `~/Projects/anvil/config/AGENTS.md` (checkout, git/push, CI, secrets, live systems, approvals, logs, docs, `DECISIONS.md` format). Rules in this file add to them; where they differ, the stricter rule wins.

# Plan: fold into `PhamIndustries/ci-infrastructure` (monorepo)

**Status:** plan only — not executed.  
**Goal:** one GitHub repo for fleet CI + agent handoff docs, instead of a standalone `ci-templates` checkout.

## Answer: yes, with one hard constraint

GitHub **reusable workflows must live at the repo root**:

```text
.github/workflows/python-uv-ci.yml
```

They cannot sit under `ci-templates/.github/workflows/` inside a monorepo and still be called with `uses: …`. Subfolders are fine for **docs / examples / agent guides**; the workflow file stays top-level.

## Proposed layout

```text
PhamIndustries/ci-infrastructure/
  .github/workflows/
    python-uv-ci.yml          # reusable workflow (SoT)
  docs/                       # AGENT_CI, DEPLOY, REPO_CI, FLEET, …
  examples/                   # ci-unit.sh, deploy.sh, ci.yml, …
  agent/                      # optional: agent-only handoff / checklists
                              #   (or keep AGENT_CI.md under docs/ — either works)
  README.md
```

Local checkout: `~/Projects/ci-infrastructure` (replace `~/Projects/ci-templates`).

## What callers change

Today (orch + dash only, as of this plan):

```yaml
uses: PhamIndustries/ci-templates/.github/workflows/python-uv-ci.yml@v1
```

After:

```yaml
uses: PhamIndustries/ci-infrastructure/.github/workflows/python-uv-ci.yml@v1
```

Also update: `examples/ci.yml`, README/`AGENT_CI`/`REPO_CI` pins, orch `docs/AGENT_CI.md` + `docs/DEPLOY.md` mirrors, AGENTS.md one-liners.

## Migration checklist (when executing)

1. **Create** empty `PhamIndustries/ci-infrastructure` (public, same visibility as today).
2. **Copy** (or `git filter-repo` / subtree) current `ci-templates` tree into it; keep history if practical.
3. **Optional** `agent/` folder — move agent-facing entry docs there *or* leave under `docs/` and add `agent/README.md` → pointer to `docs/AGENT_CI.md`.
4. Tag **`v1`** on `ci-infrastructure` at the first good commit.
5. **PR fleet pins** — `rag-orchestrator`, `rag-dashboard` (then others as they adopt CI).
6. Confirm a green Actions run resolving `uses: …/ci-infrastructure/…@v1`.
7. **Retire `ci-templates`:** README → “moved to ci-infrastructure”; archive the repo after ~1 week (or leave a stub workflow that fails with a clear message — prefer archive + doc link).
8. Local: `mv ~/Projects/ci-templates ~/Projects/ci-infrastructure` (or fresh clone); update any hard-coded `/Users/vupham/Projects/ci-templates` paths in design docs.

## Non-goals

- Nesting multiple **GitHub repos** under a folder (GitHub has no repo folders).
- Moving the **org Actions runner** or product LaunchAgents (unrelated).
- Putting reusable workflows under a subpackage path.

## Rename alternative (lighter)

`gh repo rename ci-infrastructure` on the existing repo keeps history and avoids a second remote, but still requires every `uses: PhamIndustries/ci-templates/…` → `…/ci-infrastructure/…`. Prefer rename if the only aim is the name; prefer a new monorepo only if you will merge **other** infra repos later.

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-20 | Feasible; plan-only. Reusable workflow stays at monorepo root `.github/workflows/`. |

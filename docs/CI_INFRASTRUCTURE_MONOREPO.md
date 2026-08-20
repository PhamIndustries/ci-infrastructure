# `PhamIndustries/ci-infrastructure` monorepo

**Status:** **executed 2026-08-20.**  
Former SoT repo: `PhamIndustries/ci-templates` (retired / redirect stub).

## Layout

```text
PhamIndustries/ci-infrastructure/
  .github/workflows/
    python-uv-ci.yml          # reusable workflow (SoT) — MUST stay at repo root
  docs/                       # AGENT_CI, DEPLOY, REPO_CI, FLEET, …
  examples/                   # ci-unit.sh, deploy.sh, ci.yml, …
  agent/                      # agent entry → docs/AGENT_CI.md
  README.md
```

Local checkout: `~/Projects/ci-infrastructure`

## Callers

```yaml
uses: PhamIndustries/ci-infrastructure/.github/workflows/python-uv-ci.yml@v1
```

## Constraint (unchanged)

Reusable workflows cannot live under a subfolder and still be invoked with `uses:`. Docs/examples/agent guides may nest; `.github/workflows/python-uv-ci.yml` stays top-level.

## Decision log

| Date | Decision |
|------|----------|
| 2026-08-20 | Feasible; plan-only. Reusable workflow stays at monorepo root `.github/workflows/`. |
| 2026-08-20 | **Executed:** history pushed to `ci-infrastructure`; orch/dash pins flipped; `ci-templates` stubbed. |

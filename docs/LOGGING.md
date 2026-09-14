# Fleet logging standard

**SoT for first-party Skynet services** (Python APIs, providers, orch, shell, scrapers).  
Vendor processes (Open WebUI, Ollama, Qdrant) keep their native format; wrap them only with launchd file capture.

Copy [examples/logger.py](../examples/logger.py) and [examples/log_parser.py](../examples/log_parser.py) into each product repo. Do **not** add a shared runtime package.

## Line format

Console (INFO+):

```text
2026-09-13 23:45:01 | INFO     | rag-orch | rag_orch.api | listening on :8787
```

Rotating file (DEBUG+) inserts `func:lineno` after the logger name:

```text
2026-09-13 23:45:01 | INFO     | rag-orch | rag_orch.api | serve:88 | listening on :8787
```

| Field | Rule |
|-------|------|
| timestamp | `%Y-%m-%d %H:%M:%S` |
| level | 8-char left-aligned (`INFO    `, `WARNING `) |
| service | stable fleet id (column 3) — see table below |
| logger | Python `logger.name` |
| message | free text; optional `key=value` tokens (`flow_run_id=`, `request_id=`) |

Set `SKYNET_SERVICE` in the launchd wrapper, or pass `service=` to `setup_logger`.

## Service ids

| Service | `service=` |
|---------|------------|
| rag-orch control | `rag-orch` |
| rag-dashboard shell | `rag-dash` |
| autoforge | `autoforge` |
| lds-docs-scraper | `lds-docs` |
| domain-rag API | `domain-rag` |
| domain-rag provider | `domain-rag-provider` |
| wiki-rag API | `wiki-rag` |
| photo-search | `photo-search` |
| medical-rag API | `medical-rag` |
| medical-rag provider | `medical-rag-provider` |

## Parser + dashboard consoles

`parse_line` / `parse_lines` never raise. Unmatched (vendor) lines become `LogRecord(parsed=False, raw=...)`.

The dashboard shell renders `consoles[].lines` with the **same** parser (`console_columns`) so every pane shows ts / level / service / message. Providers should emit the standard line; raw vendor tails still display as a single message column.

## Directories (this pass)

First-party launchd stdout/err: **`~/Projects/<repo>/logs/`**  
(`orch-launchd.*.log`, `provider-launchd.*.log`, `<service>.launchd.*.log`).

Do **not** write application logs under `~/KBs/<product>/logs/` anymore (that tree is data + Qdrant storage). Qdrant vendor logs may live as `~/Projects/<repo>/logs/qdrant.launchd.*.log`.

App `RotatingFileHandler`: 10 MB × 5 next to those launchd files.

Do **not** rsync logs to NAS.

## Tests (required in every first-party Python repo)

| Layer | What |
|-------|------|
| Unit | `setup_logger` line matches `parse_line`; golden fixtures for console + file + vendor |
| Integration | live serve path (or subprocess) emits ≥1 parsed line on stdout |

Reference tests: `tests/test_logger.py`, `tests/test_log_parser.py` in this repo.

## Do / don’t

| Do | Don’t |
|----|--------|
| Copy the examples and keep the format byte-stable | Invent JSON logging in v1 |
| Parse unmatched lines as raw | Drop vendor lines from consoles |
| Rotate launchd files (newsyslog or `rotate-agent-safe-logs.sh`) | Full-read multi-10 MB logs in agent sessions |
| Keep OWUI/Ollama/Qdrant native | Rewrite vendor formatters |

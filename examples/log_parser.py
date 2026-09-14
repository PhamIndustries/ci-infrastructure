"""Parse Skynet unified-text log lines.

First-party format (console):
    2026-09-13 23:45:01 | INFO     | rag-orch | rag_orch.api | listening on :8787

First-party format (file):
    2026-09-13 23:45:01 | INFO     | rag-orch | rag_orch.api | serve:88 | listening on :8787

Vendor / unmatched lines round-trip as LogRecord(parsed=False, raw=...).

SoT: PhamIndustries/ci-infrastructure docs/LOGGING.md
Copy into product repos next to logger.py. Dashboard consoles use the same parser.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from typing import Iterable, List, Optional

# ts | LEVEL | service | logger | [func:line | ] message
_LINE_RE = re.compile(
    r"^(?P<ts>\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2})"
    r" \| (?P<level>[A-Z]+)\s*"
    r" \| (?P<service>[^|]+?)"
    r" \| (?P<logger>[^|]+?)"
    r" \|(?: (?P<func>[^|:]+):(?P<lineno>\d+) \|)?"
    r" (?P<message>.*)$"
)

KV_RE = re.compile(r"\b([a-zA-Z_][a-zA-Z0-9_]*)=([^\s]+)")


@dataclass
class LogRecord:
    raw: str
    parsed: bool
    ts: Optional[str] = None
    level: Optional[str] = None
    service: Optional[str] = None
    logger: Optional[str] = None
    func: Optional[str] = None
    lineno: Optional[int] = None
    message: Optional[str] = None
    extra: dict = field(default_factory=dict)

    def display_message(self) -> str:
        if self.parsed and self.message is not None:
            return self.message
        return self.raw.rstrip("\n")


def _kv_suffix(message: str) -> dict:
    extra = {}
    for m in KV_RE.finditer(message or ""):
        extra[m.group(1)] = m.group(2)
    return extra


def parse_line(line: str) -> LogRecord:
    """Parse one line. Never raises. Unmatched → parsed=False."""
    raw = line.rstrip("\n")
    if not raw:
        return LogRecord(raw=raw, parsed=False)
    m = _LINE_RE.match(raw)
    if not m:
        return LogRecord(raw=raw, parsed=False)
    gd = m.groupdict()
    lineno_s = gd.get("lineno")
    message = gd.get("message") or ""
    return LogRecord(
        raw=raw,
        parsed=True,
        ts=gd["ts"],
        level=(gd["level"] or "").strip(),
        service=(gd["service"] or "").strip(),
        logger=(gd["logger"] or "").strip(),
        func=(gd.get("func") or None),
        lineno=int(lineno_s) if lineno_s else None,
        message=message,
        extra=_kv_suffix(message),
    )


def parse_lines(text: str | Iterable[str]) -> List[LogRecord]:
    if isinstance(text, str):
        lines = text.splitlines()
    else:
        lines = list(text)
    return [parse_line(ln) for ln in lines]


def console_columns(record: LogRecord) -> dict:
    """Shape used by dashboard pane consoles (ts / level / service / message)."""
    if not record.parsed:
        return {
            "ts": "",
            "level": "",
            "service": "",
            "message": record.display_message(),
            "parsed": False,
        }
    return {
        "ts": record.ts or "",
        "level": record.level or "",
        "service": record.service or "",
        "message": record.display_message(),
        "parsed": True,
        "logger": record.logger or "",
    }

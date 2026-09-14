"""Unit tests for examples/log_parser.py (stdlib unittest — no pytest required)."""

from __future__ import annotations

import sys
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "examples"))

from log_parser import console_columns, parse_line, parse_lines  # noqa: E402


CONSOLE = "2026-09-13 23:45:01 | INFO     | rag-orch | rag_orch.api | listening on :8787"
FILE = (
    "2026-09-13 23:45:01 | INFO     | rag-orch | rag_orch.api | serve:88 | "
    "listening on :8787 flow_run_id=abc"
)
VENDOR = 'INFO:     127.0.0.1:54321 - "GET /health HTTP/1.1" 200 OK'


class ParseLineTests(unittest.TestCase):
    def test_console_line(self) -> None:
        rec = parse_line(CONSOLE)
        self.assertTrue(rec.parsed)
        self.assertEqual(rec.ts, "2026-09-13 23:45:01")
        self.assertEqual(rec.level, "INFO")
        self.assertEqual(rec.service, "rag-orch")
        self.assertEqual(rec.logger, "rag_orch.api")
        self.assertIsNone(rec.func)
        self.assertEqual(rec.message, "listening on :8787")

    def test_file_line_with_func_and_kv(self) -> None:
        rec = parse_line(FILE)
        self.assertTrue(rec.parsed)
        self.assertEqual(rec.func, "serve")
        self.assertEqual(rec.lineno, 88)
        self.assertEqual(rec.extra.get("flow_run_id"), "abc")

    def test_warning_level_padding(self) -> None:
        line = "2026-09-13 23:45:01 | WARNING  | lds-docs | scraper.gc | stalled"
        rec = parse_line(line)
        self.assertTrue(rec.parsed)
        self.assertEqual(rec.level, "WARNING")
        self.assertEqual(rec.service, "lds-docs")

    def test_vendor_unparsed(self) -> None:
        rec = parse_line(VENDOR)
        self.assertFalse(rec.parsed)
        self.assertEqual(rec.display_message(), VENDOR)

    def test_empty(self) -> None:
        rec = parse_line("")
        self.assertFalse(rec.parsed)

    def test_trailing_newline(self) -> None:
        rec = parse_line(CONSOLE + "\n")
        self.assertTrue(rec.parsed)
        self.assertEqual(rec.message, "listening on :8787")


class ParseLinesAndColumnsTests(unittest.TestCase):
    def test_mixed_block(self) -> None:
        recs = parse_lines(CONSOLE + "\n" + VENDOR + "\n")
        self.assertEqual(len(recs), 2)
        self.assertTrue(recs[0].parsed)
        self.assertFalse(recs[1].parsed)

    def test_console_columns_parsed(self) -> None:
        cols = console_columns(parse_line(CONSOLE))
        self.assertTrue(cols["parsed"])
        self.assertEqual(cols["ts"], "2026-09-13 23:45:01")
        self.assertEqual(cols["level"], "INFO")
        self.assertEqual(cols["service"], "rag-orch")
        self.assertEqual(cols["message"], "listening on :8787")

    def test_console_columns_raw(self) -> None:
        cols = console_columns(parse_line(VENDOR))
        self.assertFalse(cols["parsed"])
        self.assertEqual(cols["message"], VENDOR)
        self.assertEqual(cols["ts"], "")


if __name__ == "__main__":
    unittest.main()

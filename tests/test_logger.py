"""Unit tests for examples/logger.py — format must match log_parser."""

from __future__ import annotations

import io
import logging
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "examples"))

from log_parser import parse_line  # noqa: E402
from logger import setup_logger  # noqa: E402


class LoggerFormatTests(unittest.TestCase):
    def tearDown(self) -> None:
        for name in list(logging.Logger.manager.loggerDict):
            if name.startswith("ci-infra-test"):
                lg = logging.getLogger(name)
                for h in list(lg.handlers):
                    lg.removeHandler(h)
                    h.close()

    def test_console_line_parses(self) -> None:
        buf = io.StringIO()
        name = "ci-infra-test.console"
        log = setup_logger(name, service="rag-orch", log_dir=None)
        # Replace stdout handler stream with buffer.
        for h in log.handlers:
            if isinstance(h, logging.StreamHandler) and not isinstance(
                h, logging.FileHandler
            ):
                h.stream = buf
        log.info("listening on :8787")
        line = buf.getvalue().strip()
        rec = parse_line(line)
        self.assertTrue(rec.parsed, msg=line)
        self.assertEqual(rec.service, "rag-orch")
        self.assertEqual(rec.logger, name)
        self.assertEqual(rec.level, "INFO")
        self.assertEqual(rec.message, "listening on :8787")
        self.assertRegex(rec.ts or "", r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")

    def test_file_line_includes_func_lineno(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            name = "ci-infra-test.file"
            log = setup_logger(name, service="medical-rag", log_dir=tmp)
            for h in log.handlers:
                if isinstance(h, logging.StreamHandler) and not isinstance(
                    h, logging.FileHandler
                ):
                    h.setLevel(logging.CRITICAL)
            log.warning("index not ready")
            path = Path(tmp) / "ci-infra-test-file.log"
            self.assertTrue(path.is_file(), msg=list(Path(tmp).iterdir()))
            line = path.read_text(encoding="utf-8").strip().splitlines()[-1]
            rec = parse_line(line)
            self.assertTrue(rec.parsed, msg=line)
            self.assertEqual(rec.service, "medical-rag")
            self.assertEqual(rec.level, "WARNING")
            self.assertEqual(rec.message, "index not ready")
            self.assertIsNotNone(rec.func)
            self.assertIsInstance(rec.lineno, int)

    def test_idempotent(self) -> None:
        name = "ci-infra-test.once"
        a = setup_logger(name, service="wiki-rag", log_dir=None)
        n = len(a.handlers)
        b = setup_logger(name, service="wiki-rag", log_dir=None)
        self.assertIs(a, b)
        self.assertEqual(len(b.handlers), n)


if __name__ == "__main__":
    unittest.main()

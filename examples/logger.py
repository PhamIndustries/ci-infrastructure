"""Skynet fleet logger — copy into a product repo as utils/logger.py (or equivalent).

Console (INFO+):
    2026-09-13 23:45:01 | INFO     | rag-orch | rag_orch.api | listening on :8787

File (DEBUG+, rotating) inserts func:lineno after the logger name.

SoT: PhamIndustries/ci-infrastructure docs/LOGGING.md
"""

from __future__ import annotations

import logging
import os
import sys
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Optional, Union

DATEFMT = "%Y-%m-%d %H:%M:%S"
CONSOLE_FMT = "%(asctime)s | %(levelname)-8s | %(service)s | %(name)s | %(message)s"
FILE_FMT = (
    "%(asctime)s | %(levelname)-8s | %(service)s | %(name)s | "
    "%(funcName)s:%(lineno)d | %(message)s"
)
MAX_BYTES = 10 * 1024 * 1024
BACKUP_COUNT = 5


class ServiceFilter(logging.Filter):
    """Stamp every record with a stable fleet service id (column 3)."""

    def __init__(self, service: str) -> None:
        super().__init__()
        self.service = str(service or "unknown").strip() or "unknown"

    def filter(self, record: logging.LogRecord) -> bool:
        if not getattr(record, "service", None):
            record.service = self.service
        return True


def setup_logger(
    name: str,
    *,
    service: Optional[str] = None,
    log_dir: Union[str, Path, None] = Path("logs"),
    console_level: int = logging.INFO,
    file_level: int = logging.DEBUG,
) -> logging.Logger:
    """Configure stdout + optional rotating file. Idempotent per logger name."""
    svc = (service or os.environ.get("SKYNET_SERVICE") or name).strip() or name
    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)
    logger.propagate = False

    if logger.handlers:
        # Ensure existing handlers still stamp `service` (re-setup after fork).
        if not any(isinstance(f, ServiceFilter) for h in logger.handlers for f in h.filters):
            filt = ServiceFilter(svc)
            for h in logger.handlers:
                h.addFilter(filt)
        return logger

    filt = ServiceFilter(svc)

    console = logging.StreamHandler(sys.stdout)
    console.setLevel(console_level)
    console.setFormatter(logging.Formatter(CONSOLE_FMT, datefmt=DATEFMT))
    console.addFilter(filt)
    logger.addHandler(console)

    if log_dir is not None:
        path = Path(log_dir)
        path.mkdir(parents=True, exist_ok=True)
        file_handler = RotatingFileHandler(
            path / f"{name.replace('.', '-')}.log",
            maxBytes=MAX_BYTES,
            backupCount=BACKUP_COUNT,
            encoding="utf-8",
        )
        file_handler.setLevel(file_level)
        file_handler.setFormatter(logging.Formatter(FILE_FMT, datefmt=DATEFMT))
        file_handler.addFilter(filt)
        logger.addHandler(file_handler)

    return logger

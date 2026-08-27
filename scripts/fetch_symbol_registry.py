"""
Track NSE symbol fetch success/failure across runs and maintain an exclude list.

Symbols are excluded when they fail FETCH_EXCLUDE_AFTER consecutive fetches
(no Yahoo data or fewer than MIN_BARS). Successful fetch resets the counter.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
STATE_PATH = SCRIPT_DIR / "nse_fetch_state.json"
EXCLUDED_PATH = SCRIPT_DIR / "nse_excluded_symbols.txt"

FETCH_EXCLUDE_AFTER = 3  # consecutive failed fetch runs


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def load_state() -> dict:
    if not STATE_PATH.is_file():
        return {"excluded": [], "failures": {}}
    try:
        data = json.loads(STATE_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return {"excluded": [], "failures": {}}
    data.setdefault("excluded", [])
    data.setdefault("failures", {})
    return data


def save_state(state: dict) -> None:
    STATE_PATH.write_text(json.dumps(state, indent=2, sort_keys=True), encoding="utf-8")
    excluded = sorted(set(state.get("excluded", [])))
    EXCLUDED_PATH.write_text(
        "\n".join(excluded) + ("\n" if excluded else ""),
        encoding="utf-8",
    )


def load_excluded() -> set[str]:
    state = load_state()
    return set(state.get("excluded", []))


def filter_symbols(symbols: list[str]) -> list[str]:
    excluded = load_excluded()
    return [s for s in symbols if s not in excluded]


def record_success(symbol: str) -> None:
    state = load_state()
    failures = state.setdefault("failures", {})
    if symbol in failures:
        del failures[symbol]
    excluded = set(state.get("excluded", []))
    if symbol in excluded:
        excluded.discard(symbol)
        state["excluded"] = sorted(excluded)
    save_state(state)


def record_failure(symbol: str, reason: str = "no_data") -> bool:
    """
    Increment failure count. Returns True if symbol was newly excluded.
    """
    state = load_state()
    failures = state.setdefault("failures", {})
    entry = failures.get(symbol, {"consecutive": 0, "reason": reason})
    entry["consecutive"] = int(entry.get("consecutive", 0)) + 1
    entry["reason"] = reason
    entry["last_attempt"] = _now_iso()
    failures[symbol] = entry

    newly_excluded = False
    excluded = set(state.get("excluded", []))
    if entry["consecutive"] >= FETCH_EXCLUDE_AFTER and symbol not in excluded:
        excluded.add(symbol)
        state["excluded"] = sorted(excluded)
        newly_excluded = True

    save_state(state)
    return newly_excluded


def force_exclude(symbols: list[str], reason: str = "audit_no_data") -> int:
    """Immediately exclude symbols (e.g. delisted / no Yahoo history)."""
    state = load_state()
    excluded = set(state.get("excluded", []))
    failures = state.setdefault("failures", {})
    added = 0
    for sym in symbols:
        sym = sym.strip().upper()
        if not sym or sym in excluded:
            continue
        excluded.add(sym)
        failures[sym] = {
            "consecutive": FETCH_EXCLUDE_AFTER,
            "reason": reason,
            "last_attempt": _now_iso(),
        }
        added += 1
    state["excluded"] = sorted(excluded)
    save_state(state)
    return added


def summary() -> str:
    state = load_state()
    excluded = state.get("excluded", [])
    failures = state.get("failures", {})
    pending = [
        s for s, f in failures.items()
        if s not in excluded and int(f.get("consecutive", 0)) > 0
    ]
    lines = [
        f"Excluded symbols: {len(excluded)}",
        f"Pending failures (not yet excluded): {len(pending)}",
    ]
    if excluded:
        lines.append("Excluded: " + ", ".join(excluded[:20]) + (" ..." if len(excluded) > 20 else ""))
    return "\n".join(lines)

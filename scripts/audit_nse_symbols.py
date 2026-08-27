"""
One-time / periodic audit: probe all NSE symbols and exclude those with no usable Yahoo data.
"""

from __future__ import annotations

import argparse
import time

from fetch_nse_data import NSE_SYMBOLS, fetch_batch
from fetch_symbol_registry import force_exclude, load_excluded, summary
import config


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit NSE symbols and exclude consistent failures")
    parser.add_argument("--timeframe", default="1d", choices=["1d", "1wk", "1mo"])
    parser.add_argument("--batch-size", type=int, default=25)
    parser.add_argument("--delay", type=float, default=1.5)
    parser.add_argument("--limit", type=int, default=None)
    args = parser.parse_args()

    period = config.FETCH_RANGE.get(args.timeframe, "2y")
    symbols = NSE_SYMBOLS[: args.limit] if args.limit else list(NSE_SYMBOLS)
    already = load_excluded()
    to_probe = [s for s in symbols if s not in already]

    print(f"Auditing {len(to_probe)} symbols ({len(already)} already excluded)...")
    print(f"Timeframe={args.timeframe} period={period} min_bars={config.MIN_BARS}\n")

    no_data: list[str] = []
    ok = 0

    for i in range(0, len(to_probe), args.batch_size):
        batch = to_probe[i : i + args.batch_size]
        yahoo = [f"{s}.NS" for s in batch]
        fetched = fetch_batch(yahoo, args.timeframe, period)
        for sym, ysym in zip(batch, yahoo):
            if ysym in fetched:
                ok += 1
            else:
                no_data.append(sym)
        print(f"  batch {i // args.batch_size + 1}: ok={ok} no_data={len(no_data)}")
        if i + args.batch_size < len(to_probe):
            time.sleep(args.delay)

    added = force_exclude(no_data, reason="audit_no_data")
    print(f"\nAudit complete.")
    print(f"  With data : {ok}")
    print(f"  No data   : {len(no_data)}")
    print(f"  Newly excluded: {added}")
    print(summary())


if __name__ == "__main__":
    main()

"""
Validate Chandelier Exit against Screener/new_combined_strategy.py.

Compares calculate_ce_signals() (reference) with rsi_ce_backtest.chandelier_direction()
(StockX Flutter-aligned implementation).
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import pandas as pd
import yfinance as yf

SCRIPT_DIR = Path(__file__).resolve().parent
SCREENER_DIR = SCRIPT_DIR.parent.parent.parent / "Screener" / "Screener"
sys.path.insert(0, str(SCREENER_DIR))

from new_combined_strategy import calculate_ce_signals  # noqa: E402
from rsi_ce_backtest import chandelier_direction  # noqa: E402


def load_symbols(limit: int, symbols_file: Path | None) -> list[str]:
    if symbols_file and symbols_file.exists():
        lines = symbols_file.read_text(encoding="utf-8").splitlines()
        syms = [s.strip().upper() for s in lines if s.strip()]
    else:
        csv_path = SCRIPT_DIR / "nse_symbols.csv"
        syms = [s.strip().upper() for s in csv_path.read_text(encoding="utf-8").splitlines() if s.strip()]
    return [s if s.endswith(".NS") else f"{s}.NS" for s in syms[:limit]]


def fetch_df(symbol: str, period: str) -> pd.DataFrame | None:
    df = yf.download(symbol, period=period, interval="1d", auto_adjust=True, progress=False)
    if df is None or df.empty:
        return None
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = df.columns.get_level_values(0)
    return df.dropna()


def signal_age_bars(dir_series: pd.Series) -> int:
    if dir_series is None or dir_series.empty:
        return -1
    current = int(dir_series.iloc[-1])
    age = 0
    for i in range(len(dir_series) - 2, -1, -1):
        if int(dir_series.iloc[i]) == current:
            age += 1
        else:
            break
    return age


def last_flip_date(dir_series: pd.Series) -> str | None:
    if dir_series is None or len(dir_series) < 2:
        return None
    current = int(dir_series.iloc[-1])
    target = "BUY" if current == 1 else "SELL"
    for i in range(len(dir_series) - 1, 0, -1):
        prev = int(dir_series.iloc[i - 1])
        cur = int(dir_series.iloc[i])
        if cur != prev:
            flip = "BUY" if cur == 1 else "SELL"
            if flip == target:
                return str(dir_series.index[i].date())
    return str(dir_series.index[0].date())


def test_symbol(symbol: str, period: str) -> dict:
    df = fetch_df(symbol, period)
    if df is None or len(df) < 60:
        return {"symbol": symbol, "status": "skip", "reason": "insufficient data"}

    ce = calculate_ce_signals(df)
    ref_signal = ce.get("ce_signal", "NEUTRAL")
    ref_days = ce.get("days_since_ce")

    h = df["High"].astype(float).values
    l = df["Low"].astype(float).values
    c = df["Close"].astype(float).values
    stockx_dir = chandelier_direction(h, l, c)
    if pd.isna(stockx_dir[-1]):
        return {"symbol": symbol, "status": "skip", "reason": "no stockx CE value"}

    stockx_signal = "CE BUY" if stockx_dir[-1] == 1 else "CE SELL"
    dir_series = ce.get("dir_series")
    ref_age = signal_age_bars(dir_series) if dir_series is not None else None
    stockx_age = 0
    for i in range(len(stockx_dir) - 2, -1, -1):
        if stockx_dir[i] == stockx_dir[-1]:
            stockx_age += 1
        else:
            break

    flip_ref = last_flip_date(dir_series) if dir_series is not None else None

    match = ref_signal == stockx_signal
    return {
        "symbol": symbol,
        "status": "ok" if match else "mismatch",
        "ref_signal": ref_signal,
        "stockx_signal": stockx_signal,
        "ref_days_since": ref_days,
        "ref_bar_age": ref_age,
        "stockx_bar_age": stockx_age,
        "last_flip": flip_ref,
        "last_close": round(float(c[-1]), 2),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Validate CE vs Screener reference")
    parser.add_argument("--limit", type=int, default=80, help="Number of symbols to test")
    parser.add_argument("--period", default="1y", help="yfinance period")
    parser.add_argument("--symbols", type=Path, default=None, help="Optional symbol list file")
    parser.add_argument(
        "--include",
        nargs="*",
        default=["BEPL", "RELIANCE", "TATASTEEL", "INFY", "HDFCBANK"],
        help="Always include these symbols",
    )
    args = parser.parse_args()

    symbols = load_symbols(args.limit, args.symbols)
    for raw in args.include:
        sym = raw.upper()
        if not sym.endswith(".NS"):
            sym = f"{sym}.NS"
        if sym not in symbols:
            symbols.insert(0, sym)

    print(f"Testing CE on {len(symbols)} symbols (period={args.period})...\n")

    results = []
    for i, sym in enumerate(symbols, 1):
        r = test_symbol(sym, args.period)
        results.append(r)
        if r["status"] == "mismatch":
            print(f"  MISMATCH {sym}: ref={r['ref_signal']} stockx={r['stockx_signal']}")
        elif r["status"] == "skip":
            print(f"  SKIP {sym}: {r.get('reason', '')}")
        if i % 20 == 0:
            print(f"  ... {i}/{len(symbols)}")

    ok = [r for r in results if r["status"] == "ok"]
    bad = [r for r in results if r["status"] == "mismatch"]
    skipped = [r for r in results if r["status"] == "skip"]

    print("\n" + "=" * 60)
    print(f"PASS: {len(ok)}  MISMATCH: {len(bad)}  SKIP: {len(skipped)}")
    print("=" * 60)

    buys = [r for r in ok if r["ref_signal"] == "CE BUY"]
    sells = [r for r in ok if r["ref_signal"] == "CE SELL"]
    print(f"\nSignals (matched): CE BUY={len(buys)}  CE SELL={len(sells)}")

    fresh = [r for r in ok if r["stockx_bar_age"] is not None and r["stockx_bar_age"] <= 3]
    print(f"Fresh CE (<=3 bars): {len(fresh)}")

    print("\nSample matched stocks (signal | bar age | last flip | close):")
    for r in ok[:15]:
        print(
            f"  {r['symbol']:16} {r['ref_signal']:8} "
            f"age={r['stockx_bar_age']:3}d  flip={r['last_flip']}  close={r['last_close']}"
        )

    if bad:
        print("\nMismatches detail:")
        for r in bad:
            print(f"  {r['symbol']}: {r['ref_signal']} vs {r['stockx_signal']}")

    out_dir = SCRIPT_DIR / "backtest_output" / "ce_validation"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_csv = out_dir / "ce_validation_results.csv"
    pd.DataFrame(results).to_csv(out_csv, index=False)
    print(f"\nFull results: {out_csv}")

    if bad:
        sys.exit(1)


if __name__ == "__main__":
    main()

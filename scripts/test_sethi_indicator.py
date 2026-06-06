"""
Validate Sethi entry rules against backtest trades in equity_curve.csv.

Uses the same entry logic as nse_full_market_backtest.py (matches Flutter sethi_indicator).
"""

from __future__ import annotations

import argparse
from pathlib import Path

import pandas as pd
import yfinance as yf

import config
from nse_full_market_backtest import generate_signals, prepare_indicators

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_CSV = SCRIPT_DIR / "backtest_output" / "equity_curve.csv"


def load_backtest_samples(csv_path: Path, max_symbols: int) -> pd.DataFrame:
    trades = pd.read_csv(csv_path)
    trades["Signal Date"] = pd.to_datetime(trades["Signal Date"]).dt.date
    # One row per symbol (first signal in log)
    samples = trades.drop_duplicates(subset=["Symbol"], keep="first").head(max_symbols)
    return samples[["Symbol", "Signal Date", "Entry Date"]]


def sethi_active_on_date(df: pd.DataFrame, signal_date) -> tuple[bool, str]:
    ts = pd.Timestamp(signal_date)
    if ts not in df.index:
        # align to nearest prior trading day in index
        prior = df.index[df.index <= ts]
        if len(prior) == 0:
            return False, "date not in price history"
        ts = prior[-1]

    row = df.loc[ts]
    if row.ndim > 1:
        row = row.iloc[0]

    signals = generate_signals(df)
    if ts in signals.index:
        return True, "backtest entry rules PASS on signal date"

    # Diagnose which rule failed
    reasons = []
    if pd.isna(row.get("20D_HIGH")) or row["Close"] <= row["20D_HIGH"]:
        reasons.append("close <= 20D high")
    if pd.isna(row.get("50DMA")) or row["Close"] <= row["50DMA"]:
        reasons.append("close <= 50 DMA")
    if pd.isna(row.get("50DMA")) or pd.isna(row.get("200DMA")) or row["50DMA"] <= row["200DMA"]:
        reasons.append("50 DMA <= 200 DMA")
    if pd.isna(row.get("VOL20")) or row["Volume"] <= 1.5 * row["VOL20"]:
        reasons.append("volume <= 1.5x 20D avg")
    if pd.isna(row.get("RSI")) or not (60 <= row["RSI"] <= 80):
        reasons.append(f"RSI={row.get('RSI', float('nan')):.1f} not in 60-80")
    if row["Close"] < 50:
        reasons.append("price < 50")
    if pd.isna(row.get("AVG_VALUE")) or row["AVG_VALUE"] < 1e7:
        reasons.append("avg value < 1 crore")

    detail = "; ".join(reasons) if reasons else "rules failed (unknown)"
    return False, detail


def fetch_df(yahoo_symbol: str) -> pd.DataFrame | None:
    period = config.FETCH_RANGE.get("1d", "2y")
    raw = yf.download(
        yahoo_symbol,
        period=period,
        progress=False,
        auto_adjust=False,
        threads=False,
    )
    if raw.empty or len(raw) < 220:
        return None
    if isinstance(raw.columns, pd.MultiIndex):
        raw.columns = raw.columns.get_level_values(0)
    return prepare_indicators(raw)


def main():
    parser = argparse.ArgumentParser(description="Test Sethi vs backtest equity_curve.csv")
    parser.add_argument("--csv", type=Path, default=DEFAULT_CSV)
    parser.add_argument("-n", type=int, default=10, help="Number of distinct symbols to test")
    args = parser.parse_args()

    if not args.csv.is_file():
        print(f"Missing {args.csv} — run nse_full_market_backtest.py first.")
        return

    samples = load_backtest_samples(args.csv, args.n)
    print(f"Sethi validation ({len(samples)} stocks from {args.csv.name})")
    print(f"Price window: {config.FETCH_RANGE.get('1d', '2y')} (Yahoo)\n")
    print(f"{'Symbol':<18} {'Signal Date':<12} {'Match':<6} Details")
    print("-" * 72)

    passed = 0
    for _, row in samples.iterrows():
        sym = row["Symbol"]
        sig_date = row["Signal Date"]
        df = fetch_df(sym)
        if df is None:
            print(f"{sym:<18} {sig_date!s:<12} {'SKIP':<6} insufficient Yahoo data")
            continue

        ok, detail = sethi_active_on_date(df, sig_date)
        if ok:
            passed += 1
        last = df.iloc[-1]
        live = generate_signals(df)
        live_ok = len(live) > 0 and live.index[-1] == df.index[-1]
        live_tag = " | LIVE bar: BUY" if live_ok else " | LIVE bar: no setup"

        print(f"{sym:<18} {sig_date!s:<12} {'OK' if ok else 'FAIL':<6} {detail}{live_tag}")

    print("-" * 72)
    print(f"Historical signal date match: {passed}/{len(samples)}")


if __name__ == "__main__":
    main()

"""
Screener-style long backtest (no shorts).

Entry:  Sethi + Supertrend BUY + CE BUY on signal bar, Nifty above 200 DMA.
        Pick top N signals per day by volume (screener rank, not all matches).
        Enter next open.

Exit:   -5% stop | trail after +20% (5% below peak) | CE SELL | end of data

Position: 7% rolling equity, max 3 new entries per day.
"""

from __future__ import annotations

import argparse
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd
import yfinance as yf

import config
from rsi_ce_backtest import (
    MIN_BARS,
    chandelier_direction,
    load_symbols,
    yf_to_arrays,
)
from sethi_st_ce_backtest import sethi_buy_series, supertrend_direction
from st_ce_rsi_managed_backtest import (
    INITIAL_STOP_PCT,
    TRAIL_ACTIVATE_PCT,
    TRAIL_OFFSET_PCT,
    simulate_exit_path,
)

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "backtest_output" / "screener_style_run"

INITIAL_CAPITAL = 500_000.0
POSITION_PCT = 0.07
MAX_POSITIONS_PER_DAY = 3
TOP_SIGNALS_PER_DAY = 3
NIFTY_TICKER = "^NSEI"


def load_nifty_bull_map(period: str) -> dict[date, bool]:
    raw = yf.download(NIFTY_TICKER, period=period, progress=False, auto_adjust=False, threads=False)
    if raw.empty:
        return {}
    if isinstance(raw.columns, pd.MultiIndex):
        raw.columns = raw.columns.get_level_values(0)
    close = raw["Close"].astype(float)
    dma200 = close.rolling(200).mean()
    bull: dict[date, bool] = {}
    for ts, c in close.items():
        d = pd.Timestamp(ts).date()
        m = dma200.loc[ts]
        if np.isfinite(c) and np.isfinite(m):
            bull[d] = bool(c > m)
    return bull


def collect_signals(
    o: np.ndarray,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    v: np.ndarray,
    symbol: str,
    dates: pd.DatetimeIndex,
    nifty_bull: dict[date, bool],
) -> list[dict]:
    sethi = sethi_buy_series(o, h, l, c, v)
    st = supertrend_direction(h, l, c)
    ce = chandelier_direction(h, l, c)
    n = len(c)
    out: list[dict] = []
    i = MIN_BARS

    while i < n - 2:
        sig_date = pd.Timestamp(dates[i]).date()
        if not nifty_bull.get(sig_date, False):
            i += 1
            continue
        if sethi[i] != 1.0 or st[i] != 1.0 or ce[i] != 1.0:
            i += 1
            continue

        entry_i = i + 1
        entry_px = float(o[entry_i])
        if entry_px <= 0 or not np.isfinite(entry_px):
            i += 1
            continue

        out.append(
            {
                "symbol": symbol,
                "signal_i": i,
                "entry_i": entry_i,
                "entry_px": entry_px,
                "signal_date": sig_date,
                "volume": float(v[i]) if np.isfinite(v[i]) else 0.0,
            }
        )
        i = entry_i + 1

    return out


def rank_top_per_day(candidates: list[dict]) -> list[dict]:
    if not candidates:
        return []
    df = pd.DataFrame(candidates)
    df = df.sort_values(["signal_date", "volume"], ascending=[True, False])
    picked = df.groupby("signal_date", as_index=False).head(TOP_SIGNALS_PER_DAY)
    return picked.to_dict("records")


def build_trades(
    picked: list[dict],
    o: np.ndarray,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    ce: np.ndarray,
    symbol: str,
    dates: pd.DatetimeIndex,
) -> list[dict]:
    trades: list[dict] = []
    for p in picked:
        if p["symbol"] != symbol:
            continue
        result = simulate_exit_path(o, h, l, c, ce, p["entry_i"], p["entry_px"], dates)
        if result is None:
            continue
        exit_i, exit_px, reason = result
        if not np.isfinite(exit_px) or exit_px <= 0:
            continue
        entry_px = p["entry_px"]
        ret = (exit_px - entry_px) / entry_px * 100
        trades.append(
            {
                "Symbol": symbol,
                "Signal Date": p["signal_date"].isoformat(),
                "Entry Date": pd.Timestamp(dates[p["entry_i"]]).strftime("%Y-%m-%d"),
                "Entry Price": round(entry_px, 4),
                "Exit Date": pd.Timestamp(dates[exit_i]).strftime("%Y-%m-%d"),
                "Exit Price": round(exit_px, 4),
                "Exit Reason": reason,
                "Return %": round(ret, 2),
                "Hold Days": (pd.Timestamp(dates[exit_i]) - pd.Timestamp(dates[p["entry_i"]])).days,
                "Signal Volume": round(p["volume"], 0),
            }
        )
    return trades


def size_trades(raw: list[dict], initial: float, position_pct: float, max_per_day: int) -> pd.DataFrame:
    if not raw:
        return pd.DataFrame()
    df = pd.DataFrame(raw)
    df["Entry Date"] = pd.to_datetime(df["Entry Date"])
    df = df.sort_values("Entry Date")
    equity = initial
    rows = []
    per_day: dict = {}
    for _, r in df.iterrows():
        d = r["Entry Date"].date()
        if per_day.get(d, 0) >= max_per_day:
            continue
        entry = float(r["Entry Price"])
        exit_px = float(r["Exit Price"])
        if not np.isfinite(entry) or not np.isfinite(exit_px) or entry <= 0:
            continue
        alloc = equity * position_pct
        shares = int(alloc // entry)
        if shares < 1:
            continue
        invested = shares * entry
        pnl = (exit_px - entry) * shares
        ret_pct = pnl / invested * 100 if invested else 0
        equity += pnl
        per_day[d] = per_day.get(d, 0) + 1
        rows.append(
            {
                **r.to_dict(),
                "Equity at Entry": round(equity - pnl, 2),
                "Shares": shares,
                "PnL": round(pnl, 2),
                "Return on position %": round(ret_pct, 2),
            }
        )
    return pd.DataFrame(rows)


def main() -> None:
    parser = argparse.ArgumentParser(description="Screener-style long backtest (no shorts)")
    parser.add_argument("--symbols-csv", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--output-dir", type=Path, default=OUTPUT_DIR)
    args = parser.parse_args()

    symbols = load_symbols(args.symbols_csv, args.limit)
    period = config.FETCH_RANGE.get("1d", "2y")
    out = args.output_dir
    out.mkdir(parents=True, exist_ok=True)

    print(f"Loading Nifty regime ({NIFTY_TICKER})...")
    nifty_bull = load_nifty_bull_map(period)
    bull_days = sum(1 for v in nifty_bull.values() if v)
    print(f"  Nifty bull days: {bull_days} / {len(nifty_bull)}")

    all_candidates: list[dict] = []
    symbol_data: dict[str, tuple] = {}
    processed = 0

    for idx, sym in enumerate(symbols, 1):
        try:
            raw = yf.download(sym, period=period, progress=False, auto_adjust=False, threads=False)
            if raw.empty or len(raw) < MIN_BARS:
                continue
            arr, dates = yf_to_arrays(raw)
            o, h, l, c, v = arr[:, 0], arr[:, 1], arr[:, 2], arr[:, 3], arr[:, 4]
            ce = chandelier_direction(h, l, c)
            symbol_data[sym] = (o, h, l, c, ce, dates)
            all_candidates.extend(collect_signals(o, h, l, c, v, sym, dates, nifty_bull))
            processed += 1
        except Exception:
            continue
        if idx % 200 == 0:
            print(f"[{idx}/{len(symbols)}] candidates={len(all_candidates)}")

    print(f"Raw signals: {len(all_candidates)} | Ranking top {TOP_SIGNALS_PER_DAY}/day...")
    picked = rank_top_per_day(all_candidates)
    print(f"Picked signals: {len(picked)}")

    raw_trades: list[dict] = []
    picked_by_sym: dict[str, list[dict]] = {}
    for p in picked:
        picked_by_sym.setdefault(p["symbol"], []).append(p)

    for sym, picks in picked_by_sym.items():
        if sym not in symbol_data:
            continue
        o, h, l, c, ce, dates = symbol_data[sym]
        raw_trades.extend(build_trades(picks, o, h, l, c, ce, sym, dates))

    sized = size_trades(raw_trades, INITIAL_CAPITAL, POSITION_PCT, MAX_POSITIONS_PER_DAY)

    trades_path = out / "screener_style_trades.csv"
    sum_path = out / "screener_style_summary.txt"
    sized.to_csv(trades_path, index=False)

    if sized.empty:
        summary = "No trades generated.\n"
    else:
        pnl = sized["PnL"].sum()
        n = len(sized)
        wins = (sized["PnL"] > 0).sum()
        reasons = sized["Exit Reason"].value_counts()
        reason_lines = "\n".join(f"    {k}: {v}" for k, v in reasons.items())
        final = INITIAL_CAPITAL + pnl
        summary = (
            f"Screener-style LONG (no shorts)\n"
            f"Universe: {len(symbols)} ({processed} with data) | period={period}\n"
            f"Entry: Sethi + ST BUY + CE BUY, Nifty > 200 DMA\n"
            f"Rank: top {TOP_SIGNALS_PER_DAY} by volume per signal day\n"
            f"Exit: -{INITIAL_STOP_PCT*100:.0f}% stop | trail +{TRAIL_ACTIVATE_PCT*100:.0f}% "
            f"(offset {TRAIL_OFFSET_PCT*100:.0f}%) | CE SELL\n"
            f"Position: {POSITION_PCT*100:.0f}% equity, max {MAX_POSITIONS_PER_DAY}/day\n\n"
            f"Raw signals: {len(all_candidates)}\n"
            f"After rank: {len(picked)}\n"
            f"Trades sized: {n}\n"
            f"Win rate: {100*wins/n:.1f}%\n"
            f"Total PnL: INR {pnl:,.2f}\n"
            f"Final equity: INR {final:,.2f}\n"
            f"Return: {(final/INITIAL_CAPITAL-1)*100:.2f}%\n"
            f"Avg hold: {sized['Hold Days'].mean():.1f} days\n\n"
            f"Exit reasons:\n{reason_lines}\n\nFile: {trades_path}\n"
        )

    sum_path.write_text(summary, encoding="utf-8")
    print(summary)


if __name__ == "__main__":
    main()

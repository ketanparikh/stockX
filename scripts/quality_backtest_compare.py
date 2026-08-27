"""
Compare backtest results with vs without app quality filters.

Strategies (2y NSE universe):
  1. Sethi breakout + managed exits
  2. Screener-style (Sethi + ST + CE, Nifty filter, top 3/day)

Quality gate (matches app defaults):
  Mcap > 15,000 Cr (current Yahoo snapshot) · Vol > 1.5x 20D avg · Close > EMA20 & EMA50
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from datetime import date
from pathlib import Path

import numpy as np
import pandas as pd
import yfinance as yf

import config
from rsi_ce_backtest import MIN_BARS, chandelier_direction, load_symbols, size_trades_long, yf_to_arrays
from rsi_ce_backtest import bull_cross, rsi_wilder_series, RSI_FAST, RSI_SLOW
from sethi_st_ce_backtest import sethi_buy_series, supertrend_direction
from st_ce_rsi_managed_backtest import (
    INITIAL_CAPITAL,
    INITIAL_STOP_PCT,
    POSITION_PCT,
    TRAIL_ACTIVATE_PCT,
    TRAIL_OFFSET_PCT,
    entry_signal,
    simulate_exit_path,
)
from stock_quality_filter import QualityParams, fetch_market_caps, passes_at_bar

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "backtest_output" / "quality_compare"

# Screener-style constants
SCREENER_INITIAL = 500_000.0
SCREENER_POSITION_PCT = 0.07
SCREENER_MAX_PER_DAY = 3
TOP_SIGNALS_PER_DAY = 3
NIFTY_TICKER = "^NSEI"


@dataclass
class RunResult:
    name: str
    trades: int
    win_rate: float
    pnl: float
    final_equity: float
    return_pct: float
    avg_hold: float
    raw_signals: int | None = None
    after_filter: int | None = None


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


def simulate_st_ce_rsi_long(
    o: np.ndarray,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    v: np.ndarray,
    symbol: str,
    dates: pd.DatetimeIndex,
    quality: QualityParams | None,
    market_cap_inr: float | None,
) -> list[dict]:
    rf = rsi_wilder_series(c, RSI_FAST)
    rs = rsi_wilder_series(c, RSI_SLOW)
    st = supertrend_direction(h, l, c)
    ce = chandelier_direction(h, l, c)
    n = len(c)
    trades: list[dict] = []
    i = max(RSI_SLOW, MIN_BARS)

    while i < n - 2:
        if not entry_signal(st, ce, rf, rs, i):
            i += 1
            continue
        if quality is not None and not passes_at_bar(c, v, i, quality, market_cap_inr):
            i += 1
            continue

        entry_i = i + 1
        entry_px = float(o[entry_i])
        if entry_px <= 0 or not np.isfinite(entry_px):
            i += 1
            continue

        result = simulate_exit_path(o, h, l, c, ce, entry_i, entry_px, dates)
        if result is None:
            i += 1
            continue

        exit_i, exit_px, reason = result
        if not np.isfinite(exit_px) or exit_px <= 0:
            i = exit_i + 1
            continue

        ret = (exit_px - entry_px) / entry_px * 100
        trades.append(
            {
                "Symbol": symbol,
                "Signal Date": dates[i].strftime("%Y-%m-%d"),
                "Entry Date": dates[entry_i].strftime("%Y-%m-%d"),
                "Entry Price": round(entry_px, 4),
                "Exit Date": dates[exit_i].strftime("%Y-%m-%d"),
                "Exit Price": round(exit_px, 4),
                "Exit Reason": reason,
                "Return %": round(ret, 2),
                "Hold Days": (dates[exit_i] - dates[entry_i]).days,
            }
        )
        i = exit_i + 1

    return trades


def simulate_sethi_long(
    o: np.ndarray,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    v: np.ndarray,
    symbol: str,
    dates: pd.DatetimeIndex,
    quality: QualityParams | None,
    market_cap_inr: float | None,
) -> list[dict]:
    sethi = sethi_buy_series(o, h, l, c, v)
    ce = chandelier_direction(h, l, c)
    n = len(c)
    trades: list[dict] = []
    i = MIN_BARS

    while i < n - 2:
        if sethi[i] != 1.0:
            i += 1
            continue
        if quality is not None and not passes_at_bar(c, v, i, quality, market_cap_inr):
            i += 1
            continue

        entry_i = i + 1
        entry_px = float(o[entry_i])
        if entry_px <= 0 or not np.isfinite(entry_px):
            i += 1
            continue

        result = simulate_exit_path(o, h, l, c, ce, entry_i, entry_px, dates)
        if result is None:
            i += 1
            continue

        exit_i, exit_px, reason = result
        if not np.isfinite(exit_px) or exit_px <= 0:
            i = exit_i + 1
            continue

        ret = (exit_px - entry_px) / entry_px * 100
        trades.append(
            {
                "Symbol": symbol,
                "Signal Date": dates[i].strftime("%Y-%m-%d"),
                "Entry Date": dates[entry_i].strftime("%Y-%m-%d"),
                "Entry Price": round(entry_px, 4),
                "Exit Date": dates[exit_i].strftime("%Y-%m-%d"),
                "Exit Price": round(exit_px, 4),
                "Exit Reason": reason,
                "Return %": round(ret, 2),
                "Hold Days": (dates[exit_i] - dates[entry_i]).days,
            }
        )
        i = exit_i + 1

    return trades


def collect_screener_signals(
    o: np.ndarray,
    h: np.ndarray,
    l: np.ndarray,
    c: np.ndarray,
    v: np.ndarray,
    symbol: str,
    dates: pd.DatetimeIndex,
    nifty_bull: dict[date, bool],
    quality: QualityParams | None,
    market_cap_inr: float | None,
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
        if quality is not None and not passes_at_bar(c, v, i, quality, market_cap_inr):
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
    return df.groupby("signal_date", as_index=False).head(TOP_SIGNALS_PER_DAY).to_dict("records")


def build_screener_trades(
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
            }
        )
    return trades


def size_screener_trades(raw: list[dict]) -> pd.DataFrame:
    if not raw:
        return pd.DataFrame()
    df = pd.DataFrame(raw)
    df["Entry Date"] = pd.to_datetime(df["Entry Date"])
    df = df.sort_values("Entry Date")
    equity = SCREENER_INITIAL
    rows = []
    per_day: dict = {}
    for _, r in df.iterrows():
        d = r["Entry Date"].date()
        if per_day.get(d, 0) >= SCREENER_MAX_PER_DAY:
            continue
        entry = float(r["Entry Price"])
        exit_px = float(r["Exit Price"])
        if not np.isfinite(entry) or not np.isfinite(exit_px) or entry <= 0:
            continue
        alloc = equity * SCREENER_POSITION_PCT
        shares = int(alloc // entry)
        if shares < 1:
            continue
        invested = shares * entry
        pnl = (exit_px - entry) * shares
        equity += pnl
        per_day[d] = per_day.get(d, 0) + 1
        rows.append({**r.to_dict(), "PnL": round(pnl, 2)})
    return pd.DataFrame(rows)


def summarize(name: str, sized: pd.DataFrame, initial: float, **extra) -> RunResult:
    if sized.empty:
        return RunResult(name, 0, 0.0, 0.0, initial, 0.0, 0.0, **extra)
    pnl = float(sized["PnL"].sum())
    n = len(sized)
    wins = int((sized["PnL"] > 0).sum())
    final = initial + pnl
    return RunResult(
        name=name,
        trades=n,
        win_rate=100.0 * wins / n,
        pnl=pnl,
        final_equity=final,
        return_pct=(final / initial - 1) * 100,
        avg_hold=float(sized["Hold Days"].mean()),
        **extra,
    )


def main() -> None:
    parser = argparse.ArgumentParser(description="Quality filter backtest comparison")
    parser.add_argument("--symbols-csv", type=Path, default=None)
    parser.add_argument("--limit", type=int, default=None)
    parser.add_argument("--skip-mcap", action="store_true", help="Candle-only quality (no mcap gate)")
    parser.add_argument("--vol-mult", type=float, default=1.5)
    args = parser.parse_args()

    symbols = load_symbols(args.symbols_csv, args.limit)
    period = config.FETCH_RANGE.get("1d", "2y")
    out = OUTPUT_DIR
    out.mkdir(parents=True, exist_ok=True)

    quality = QualityParams(
        volume_multiplier=args.vol_mult,
        use_market_cap=not args.skip_mcap,
    )

    print(f"Loading market caps for {len(symbols)} symbols...")
    market_caps = fetch_market_caps(symbols) if quality.use_market_cap else {}
    large_cap_count = sum(
        1 for s in symbols if market_caps.get(s, 0) >= quality.min_market_cap_crore * 1e7
    )
    print(f"  Market caps fetched: {len(market_caps)} | >=15K Cr: {large_cap_count}")

    print(f"Loading Nifty regime ({NIFTY_TICKER})...")
    nifty_bull = load_nifty_bull_map(period)

    symbol_data: dict[str, tuple] = {}
    sethi_base: list[dict] = []
    sethi_quality: list[dict] = []
    stce_rsi_base: list[dict] = []
    stce_rsi_quality: list[dict] = []
    screener_base: list[dict] = []
    screener_quality: list[dict] = []

    for idx, sym in enumerate(symbols, 1):
        try:
            raw = yf.download(sym, period=period, progress=False, auto_adjust=False, threads=False)
            if raw.empty or len(raw) < MIN_BARS:
                continue
            arr, dates = yf_to_arrays(raw)
            o, h, l, c, v = arr[:, 0], arr[:, 1], arr[:, 2], arr[:, 3], arr[:, 4]
            ce = chandelier_direction(h, l, c)
            symbol_data[sym] = (o, h, l, c, ce, dates)
            cap = market_caps.get(sym)

            sethi_base.extend(simulate_sethi_long(o, h, l, c, v, sym, dates, None, cap))
            sethi_quality.extend(
                simulate_sethi_long(o, h, l, c, v, sym, dates, quality, cap)
            )

            stce_rsi_base.extend(
                simulate_st_ce_rsi_long(o, h, l, c, v, sym, dates, None, cap)
            )
            stce_rsi_quality.extend(
                simulate_st_ce_rsi_long(o, h, l, c, v, sym, dates, quality, cap)
            )

            screener_base.extend(
                collect_screener_signals(o, h, l, c, v, sym, dates, nifty_bull, None, cap)
            )
            screener_quality.extend(
                collect_screener_signals(o, h, l, c, v, sym, dates, nifty_bull, quality, cap)
            )
        except Exception:
            continue
        if idx % 200 == 0:
            print(f"[{idx}/{len(symbols)}] downloaded")

    # Sethi sized
    sethi_base_sized = size_trades_long(sethi_base, INITIAL_CAPITAL, POSITION_PCT)
    sethi_qual_sized = size_trades_long(sethi_quality, INITIAL_CAPITAL, POSITION_PCT)
    stce_base_sized = size_trades_long(stce_rsi_base, INITIAL_CAPITAL, POSITION_PCT)
    stce_qual_sized = size_trades_long(stce_rsi_quality, INITIAL_CAPITAL, POSITION_PCT)

    # Screener ranked + trades
    screener_base_picked = rank_top_per_day(screener_base)
    screener_qual_picked = rank_top_per_day(screener_quality)

    def screener_trades_from_picked(picked: list[dict]) -> list[dict]:
        by_sym: dict[str, list[dict]] = {}
        for p in picked:
            by_sym.setdefault(p["symbol"], []).append(p)
        trades: list[dict] = []
        for sym, picks in by_sym.items():
            if sym not in symbol_data:
                continue
            o, h, l, c, ce, dates = symbol_data[sym]
            trades.extend(build_screener_trades(picks, o, h, l, c, ce, sym, dates))
        return trades

    screener_base_sized = size_screener_trades(screener_trades_from_picked(screener_base_picked))
    screener_qual_sized = size_screener_trades(screener_trades_from_picked(screener_qual_picked))

    results = [
        summarize("ST+CE+RSI (baseline)", stce_base_sized, INITIAL_CAPITAL),
        summarize("ST+CE+RSI + quality", stce_qual_sized, INITIAL_CAPITAL),
        summarize("Sethi managed (baseline)", sethi_base_sized, INITIAL_CAPITAL),
        summarize("Sethi managed + quality", sethi_qual_sized, INITIAL_CAPITAL),
        summarize(
            "Screener-style (baseline)",
            screener_base_sized,
            SCREENER_INITIAL,
            raw_signals=len(screener_base),
            after_filter=len(screener_base_picked),
        ),
        summarize(
            "Screener-style + quality",
            screener_qual_sized,
            SCREENER_INITIAL,
            raw_signals=len(screener_quality),
            after_filter=len(screener_qual_picked),
        ),
    ]

    stce_base_sized.to_csv(out / "st_ce_rsi_baseline_trades.csv", index=False)
    stce_qual_sized.to_csv(out / "st_ce_rsi_quality_trades.csv", index=False)
    sethi_base_sized.to_csv(out / "sethi_baseline_trades.csv", index=False)
    sethi_qual_sized.to_csv(out / "sethi_quality_trades.csv", index=False)
    screener_base_sized.to_csv(out / "screener_baseline_trades.csv", index=False)
    screener_qual_sized.to_csv(out / "screener_quality_trades.csv", index=False)

    lines = [
        "Quality filter backtest comparison (2y NSE universe)",
        f"Period: {period} | Symbols: {len(symbols)} ({len(symbol_data)} with data)",
        f"Quality gate: {quality.label()}",
        "Note: market cap uses current Yahoo snapshot (not historical).",
        "",
        f"{'Strategy':<32} {'Trades':>7} {'Win%':>7} {'PnL (INR)':>14} {'Return%':>9} {'AvgHold':>8}",
        "-" * 82,
    ]
    for r in results:
        extra = ""
        if r.raw_signals is not None and r.after_filter is not None:
            extra = f"  (signals {r.raw_signals} -> ranked {r.after_filter})"
        elif r.raw_signals is not None:
            extra = f"  (signals {r.raw_signals})"
        lines.append(
            f"{r.name:<32} {r.trades:>7} {r.win_rate:>6.1f}% "
            f"{r.pnl:>14,.0f} {r.return_pct:>8.1f}% {r.avg_hold:>7.1f}d{extra}"
        )

    lines.extend(
        [
            "",
            "Delta (with quality - baseline):",
        ]
    )
    pairs = [(results[i], results[i + 1]) for i in range(0, len(results), 2)]
    for base, qual in pairs:
        d_trades = qual.trades - base.trades
        d_pnl = qual.pnl - base.pnl
        d_wr = qual.win_rate - base.win_rate
        lines.append(
            f"  {base.name.split('(')[0].strip():<28} "
            f"trades {d_trades:+d} | PnL {d_pnl:+,.0f} INR | win rate {d_wr:+.1f}pp"
        )

    report = "\n".join(lines) + "\n"
    (out / "quality_compare_summary.txt").write_text(report, encoding="utf-8")
    print(report)


if __name__ == "__main__":
    main()

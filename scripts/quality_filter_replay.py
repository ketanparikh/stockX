"""
Replay app quality filters on existing backtest trade CSVs.

Uses saved trades (with PnL) and checks whether each signal bar would pass
the quality gate at entry time (volume + EMA are point-in-time; mcap optional).
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd
import yfinance as yf

import config
from rsi_ce_backtest import yf_to_arrays
from stock_quality_filter import QualityParams, fetch_market_caps, passes_at_bar

SCRIPT_DIR = Path(__file__).resolve().parent
OUTPUT_DIR = SCRIPT_DIR / "backtest_output" / "quality_replay"

DATASETS = [
    (
        "ST+CE+RSI managed",
        SCRIPT_DIR / "backtest_output" / "st_ce_rsi_managed_run" / "st_ce_rsi_managed_trades.csv",
        500_000.0,
    ),
    (
        "Screener (Sethi+ST+CE)",
        SCRIPT_DIR / "backtest_output" / "screener_style_run" / "screener_style_trades.csv",
        500_000.0,
    ),
    (
        "Sethi managed",
        SCRIPT_DIR / "backtest_output" / "sethi_managed_run" / "sethi_managed_trades.csv",
        500_000.0,
    ),
]


def load_candles(symbol: str, period: str) -> tuple[np.ndarray, np.ndarray, pd.DatetimeIndex] | None:
    try:
        raw = yf.download(symbol, period=period, progress=False, auto_adjust=False, threads=False)
        if raw.empty:
            return None
        arr, dates = yf_to_arrays(raw)
        c, v = arr[:, 3], arr[:, 4]
        return c, v, dates
    except Exception:
        return None


def signal_bar_index(dates: pd.DatetimeIndex, signal_date: str) -> int | None:
    target = pd.Timestamp(signal_date)
    hits = np.where(dates.normalize() == target.normalize())[0]
    if len(hits) == 0:
        # fallback: nearest prior bar
        prior = np.where(dates.normalize() <= target.normalize())[0]
        if len(prior) == 0:
            return None
        return int(prior[-1])
    return int(hits[0])


def replay_dataset(
    name: str,
    csv_path: Path,
    initial: float,
    params: QualityParams,
    market_caps: dict[str, float],
    period: str,
) -> dict:
    df = pd.read_csv(csv_path)
    if df.empty:
        return {"name": name, "error": "empty"}

    symbols = df["Symbol"].unique().tolist()
    cache: dict[str, tuple[np.ndarray, np.ndarray, pd.DatetimeIndex] | None] = {}
    for sym in symbols:
        cache[sym] = load_candles(sym, period)

    passes: list[bool] = []
    for _, row in df.iterrows():
        sym = row["Symbol"]
        data = cache.get(sym)
        if data is None:
            passes.append(False)
            continue
        c, v, dates = data
        idx = signal_bar_index(dates, str(row["Signal Date"]))
        if idx is None:
            passes.append(False)
            continue
        cap = market_caps.get(sym)
        passes.append(passes_at_bar(c, v, idx, params, cap))

    df = df.copy()
    df["Quality Pass"] = passes

    all_pnl = float(df["PnL"].sum())
    all_n = len(df)
    all_wins = int((df["PnL"] > 0).sum())

    filt = df[df["Quality Pass"]]
    f_pnl = float(filt["PnL"].sum()) if not filt.empty else 0.0
    f_n = len(filt)
    f_wins = int((filt["PnL"] > 0).sum()) if not filt.empty else 0

    return {
        "name": name,
        "all_trades": all_n,
        "all_win_rate": 100.0 * all_wins / all_n if all_n else 0,
        "all_pnl": all_pnl,
        "all_return": (initial + all_pnl) / initial - 1,
        "filt_trades": f_n,
        "filt_win_rate": 100.0 * f_wins / f_n if f_n else 0,
        "filt_pnl": f_pnl,
        "filt_return": (initial + f_pnl) / initial - 1 if f_n else 0,
        "pass_rate": 100.0 * f_n / all_n if all_n else 0,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Replay quality filter on saved backtests")
    parser.add_argument("--skip-mcap", action="store_true")
    parser.add_argument("--vol-mult", type=float, default=1.5)
    args = parser.parse_args()

    period = config.FETCH_RANGE.get("1d", "2y")
    params = QualityParams(volume_multiplier=args.vol_mult, use_market_cap=not args.skip_mcap)
    out = OUTPUT_DIR
    out.mkdir(parents=True, exist_ok=True)

    all_symbols: set[str] = set()
    for _, path, _ in DATASETS:
        if path.is_file():
            all_symbols.update(pd.read_csv(path)["Symbol"].unique())

    market_caps: dict[str, float] = {}
    if params.use_market_cap:
        print(f"Fetching market caps for {len(all_symbols)} traded symbols...")
        market_caps = fetch_market_caps(sorted(all_symbols))

    lines = [
        "Quality filter replay on existing backtests",
        f"Gate: {params.label()}",
        f"Mcap note: {'current Yahoo snapshot' if params.use_market_cap else 'disabled'}",
        "",
        f"{'Strategy':<26} {'Trades':>7} {'Win%':>7} {'PnL':>12} | {'+Quality':>7} {'Win%':>7} {'PnL':>12} {'Pass%':>6}",
        "-" * 95,
    ]

    results = []
    for name, path, initial in DATASETS:
        if not path.is_file():
            lines.append(f"{name:<26}  (missing {path.name})")
            continue
        print(f"Replaying {name}...")
        r = replay_dataset(name, path, initial, params, market_caps, period)
        results.append(r)
        lines.append(
            f"{r['name']:<26} {r['all_trades']:>7} {r['all_win_rate']:>6.1f}% "
            f"{r['all_pnl']:>11,.0f} | {r['filt_trades']:>7} {r['filt_win_rate']:>6.1f}% "
            f"{r['filt_pnl']:>11,.0f} {r['pass_rate']:>5.1f}%"
        )
        d_pnl = r["filt_pnl"] - r["all_pnl"]
        d_wr = r["filt_win_rate"] - r["all_win_rate"]
        lines.append(
            f"  Delta: trades {r['filt_trades'] - r['all_trades']:+d} | "
            f"PnL {d_pnl:+,.0f} INR | win rate {d_wr:+.1f}pp"
        )

    report = "\n".join(lines) + "\n"
    (out / "quality_replay_summary.txt").write_text(report, encoding="utf-8")
    print(report)


if __name__ == "__main__":
    main()

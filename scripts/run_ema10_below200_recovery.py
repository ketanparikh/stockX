"""Reconstruct Shilpa / RR Kabel 10-30-48 crosses vs EMA200, then A/B the universe."""
from __future__ import annotations

import time
from datetime import datetime, timezone
from pathlib import Path

import numpy as np
import pandas as pd
from supabase import create_client

import config
from ema10_cross_backtest import FAST, LOOKBACK, MID_FAST, MID_SLOW, MIN_BARS, TREND, _cross_flags
from rsi_ce_backtest import INITIAL_CAPITAL, POSITION_PCT, size_trades_long
from stock_quality_filter import ema

SCRIPT_DIR = Path(__file__).resolve().parent
OUT = SCRIPT_DIR / "backtest_output" / "ema10_below200_recovery"
PAGE = 25
FOCUS = {"SHILPAMED", "RRKABEL"}


def _arrays(row: dict):
    t, o, h, l, c = row["t"], row["o"], row["h"], row["l"], row["c"]
    n = min(len(t), len(o), len(h), len(l), len(c))
    if n < MIN_BARS:
        return None
    dates = pd.to_datetime(
        [datetime.fromtimestamp(x / 1000, tz=timezone.utc) for x in t[:n]]
    ).tz_localize(None)
    return (
        np.array(o[:n], dtype=float),
        np.array(c[:n], dtype=float),
        pd.DatetimeIndex(dates),
        row["symbol"],
    )


def _series(close: np.ndarray, lookback: int = LOOKBACK):
    e10 = ema(close, FAST)
    e30 = ema(close, MID_FAST)
    e48 = ema(close, MID_SLOW)
    e200 = ema(close, TREND)
    up30, down30 = _cross_flags(e10, e30)
    up48, down48 = _cross_flags(e10, e48)
    n = len(close)
    is_entry_any = np.zeros(n, dtype=bool)
    is_entry_above = np.zeros(n, dtype=bool)
    is_entry_below = np.zeros(n, dtype=bool)
    is_exit = np.zeros(n, dtype=bool)
    intact_any = np.zeros(n, dtype=bool)
    intact_above = np.zeros(n, dtype=bool)
    intact_below = np.zeros(n, dtype=bool)
    below_exit = np.zeros(n, dtype=bool)
    dist = np.full(n, np.nan)
    for i in range(TREND, n):
        a10, a30, a48, a200, px = e10[i], e30[i], e48[i], e200[i], close[i]
        if not all(np.isfinite(x) for x in (a10, a30, a48, a200, px)):
            continue
        dist[i] = (px / a200 - 1.0) * 100.0
        stack10 = px > a10 and a10 > a30 and a10 > a48
        intact_any[i] = stack10
        intact_above[i] = stack10 and px > a200
        intact_below[i] = stack10 and px <= a200
        below_exit[i] = a10 < a30 and a10 < a48
        if stack10 and up30[i] >= 0 and up48[i] >= 0:
            completing = min(i - int(up30[i]), i - int(up48[i]))
            if completing <= lookback:
                is_entry_any[i] = True
                if px > a200:
                    is_entry_above[i] = True
                else:
                    is_entry_below[i] = True
        if below_exit[i] and down30[i] >= 0 and down48[i] >= 0:
            completing = min(i - int(down30[i]), i - int(down48[i]))
            if completing <= lookback:
                is_exit[i] = True
    return {
        "e10": e10,
        "e30": e30,
        "e48": e48,
        "e200": e200,
        "up30": up30,
        "up48": up48,
        "is_entry_any": is_entry_any,
        "is_entry_above": is_entry_above,
        "is_entry_below": is_entry_below,
        "is_exit": is_exit,
        "intact_any": intact_any,
        "intact_above": intact_above,
        "intact_below": intact_below,
        "dist": dist,
    }


def simulate(o, c, dates, is_entry, is_exit, intact, delay: int):
    n = len(c)
    trades: list[dict] = []
    signals = 0
    skipped = 0
    i = TREND
    last_close = float(c[-1])
    last_date = dates[-1]
    while i < n - 2 - delay:
        if not is_entry[i]:
            i += 1
            continue
        signals += 1
        confirm = i + delay
        if confirm >= n - 1:
            break
        if delay > 0 and not intact[confirm]:
            skipped += 1
            i = confirm + 1
            continue
        entry_i = confirm + 1
        if entry_i >= n:
            break
        entry_px = float(o[entry_i])
        if not np.isfinite(entry_px) or entry_px <= 0:
            i = entry_i + 1
            continue
        exit_i = None
        reason = "End of data"
        for j in range(entry_i + 1, n):
            if is_exit[j]:
                if j + 1 < n and np.isfinite(o[j + 1]) and o[j + 1] > 0:
                    exit_i = j + 1
                    reason = "EMA 10 below 30 & 48"
                break
        if exit_i is None:
            exit_i = n - 1
            exit_px = float(c[-1])
        else:
            exit_px = float(o[exit_i])
        ret = (exit_px / entry_px - 1.0) * 100.0
        to_date = (last_close / entry_px - 1.0) * 100.0
        hold = (dates[exit_i] - dates[entry_i]).days
        trades.append(
            {
                "Signal Date": dates[i].strftime("%Y-%m-%d"),
                "Entry Date": dates[entry_i].strftime("%Y-%m-%d"),
                "Entry Price": round(entry_px, 4),
                "Exit Date": dates[exit_i].strftime("%Y-%m-%d"),
                "Exit Price": round(exit_px, 4),
                "Exit Reason": reason,
                "Return %": round(ret, 2),
                "Hold Days": int(hold),
                "To Date %": round(to_date, 2),
                "As Of": last_date.strftime("%Y-%m-%d"),
            }
        )
        i = exit_i + 1 if reason != "End of data" else n
    return trades, signals, skipped


def focus_crosses(sym, o, c, dates, s):
    rows = []
    last = float(c[-1])
    for i in range(TREND, len(c)):
        if not s["is_entry_any"][i]:
            continue
        a10, a30, a48, a200, px = s["e10"][i], s["e30"][i], s["e48"][i], s["e200"][i], c[i]
        age30 = i - int(s["up30"][i])
        age48 = i - int(s["up48"][i])
        completing = min(age30, age48)
        # next open entry
        if i + 1 >= len(c):
            continue
        entry = float(o[i + 1])
        # ema-below exit
        exit_px = last
        exit_d = dates[-1]
        reason = "End of data"
        for j in range(i + 2, len(c)):
            if s["is_exit"][j]:
                if j + 1 < len(c):
                    exit_px = float(o[j + 1])
                    exit_d = dates[j + 1]
                    reason = "EMA below"
                break
        fwd20 = (float(c[min(i + 20, len(c) - 1)]) / px - 1) * 100
        fwd60 = (float(c[min(i + 60, len(c) - 1)]) / px - 1) * 100
        rows.append(
            {
                "Symbol": sym,
                "Cross Date": dates[i].strftime("%Y-%m-%d"),
                "Close": round(float(px), 2),
                "EMA10": round(float(a10), 2),
                "EMA30": round(float(a30), 2),
                "EMA48": round(float(a48), 2),
                "EMA200": round(float(a200), 2),
                "Close vs 200 %": round(float(s["dist"][i]), 2),
                "10 vs 200 %": round((float(a10) / float(a200) - 1) * 100, 2),
                "Close > 200": bool(px > a200),
                "10 > 200": bool(a10 > a200),
                "Age 10/30": int(age30),
                "Age 10/48": int(age48),
                "Completing age": int(completing),
                "App would take": bool(s["is_entry_above"][i]),
                "Entry next open": round(entry, 2),
                "Exit": reason,
                "Exit Date": exit_d.strftime("%Y-%m-%d"),
                "Rule ret %": round((exit_px / entry - 1) * 100, 2),
                "To date %": round((last / entry - 1) * 100, 2),
                "Fwd 20d %": round(fwd20, 2),
                "Fwd 60d %": round(fwd60, 2),
            }
        )
    return rows


def stats(sized: pd.DataFrame) -> dict:
    if sized is None or sized.empty:
        return {"n": 0, "wr": 0.0, "pf": 0.0, "pnl": 0.0, "mean": 0.0, "med": 0.0, "hold": 0.0, "todate": 0.0}
    pnl = float(sized["PnL"].sum())
    n = len(sized)
    wins = int((sized["PnL"] > 0).sum())
    win_pnl = float(sized.loc[sized["PnL"] > 0, "PnL"].sum())
    loss_pnl = float(sized.loc[sized["PnL"] < 0, "PnL"].sum())
    pf = abs(win_pnl / loss_pnl) if loss_pnl != 0 else 99.0
    return {
        "n": n,
        "wr": 100 * wins / n,
        "pf": pf,
        "pnl": pnl,
        "mean": float(sized["Return %"].mean()),
        "med": float(sized["Return %"].median()),
        "hold": float(sized["Hold Days"].mean()),
        "todate": float(sized["To Date %"].mean()),
        "todate_med": float(sized["To Date %"].median()),
        "eod_n": int((sized["Exit Reason"] == "End of data").sum()),
        "eod_mean": float(sized.loc[sized["Exit Reason"] == "End of data", "Return %"].mean())
        if (sized["Exit Reason"] == "End of data").any()
        else 0.0,
    }


def dist_bucket(x: float) -> str:
    if x > 15:
        return ">15% above"
    if x > 5:
        return "5–15% above"
    if x > 0:
        return "0–5% above"
    if x > -5:
        return "0–5% below"
    if x > -15:
        return "5–15% below"
    return ">15% below"


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    client = create_client(config.SUPABASE_URL, config.SUPABASE_ANON_KEY)
    rows: list[dict] = []
    start = 0
    while True:
        r = (
            client.table("stock_candles")
            .select("symbol,t,o,h,l,c")
            .eq("timeframe", "1d")
            .range(start, start + PAGE - 1)
            .execute()
        )
        batch = r.data or []
        if not batch:
            break
        rows.extend(batch)
        if len(rows) % 200 == 0:
            print(f"  loaded {len(rows)}", flush=True)
        start += PAGE
        time.sleep(0.08)

    prepared = []
    focus_rows = []
    signal_meta = []
    for i, row in enumerate(rows, 1):
        data = _arrays(row)
        if data is None:
            continue
        o, c, dates, sym = data
        s = _series(c)
        prepared.append((sym, o, c, dates, s))
        if i % 400 == 0:
            print(f"  indicators {i}/{len(rows)}", flush=True)
        if sym in FOCUS:
            focus_rows.extend(focus_crosses(sym, o, c, dates, s))
        for j in range(TREND, len(c)):
            if not s["is_entry_any"][j]:
                continue
            signal_meta.append(
                {
                    "Symbol": f"{sym}.NS",
                    "Date": dates[j].strftime("%Y-%m-%d"),
                    "Close vs 200 %": float(s["dist"][j]),
                    "Bucket": dist_bucket(float(s["dist"][j])),
                    "Close > 200": bool(s["is_entry_above"][j]),
                    "10 > 200": bool(s["e10"][j] > s["e200"][j]),
                }
            )
    print(f"ready {len(prepared)} symbols", flush=True)

    focus_df = pd.DataFrame(focus_rows)
    focus_df.to_csv(OUT / "shilpa_rrkabel_crosses.csv", index=False)
    print("\n=== FOCUS CROSSES ===")
    print(focus_df.to_string(index=False), flush=True)

    variants = []
    specs = [
        ("above200_d0", "is_entry_above", "intact_above", 0),
        ("above200_d1", "is_entry_above", "intact_above", 1),
        ("below200_d0", "is_entry_below", "intact_below", 0),
        ("below200_d1", "is_entry_below", "intact_below", 1),
        ("any_d0", "is_entry_any", "intact_any", 0),
        ("any_d1", "is_entry_any", "intact_any", 1),
    ]
    for name, entry_k, intact_k, delay in specs:
        raw = []
        sig_n = skip_n = 0
        for sym, o, c, dates, s in prepared:
            t, sig, sk = simulate(o, c, dates, s[entry_k], s["is_exit"], s[intact_k], delay)
            for tr in t:
                tr["Symbol"] = f"{sym}.NS"
            raw.extend(t)
            sig_n += sig
            skip_n += sk
        sized = size_trades_long(raw, INITIAL_CAPITAL, POSITION_PCT)
        sized.to_csv(OUT / f"{name}_trades.csv", index=False)
        stt = stats(sized)
        stt.update(name=name, signals=sig_n, skipped=skip_n)
        variants.append(stt)
        print(
            f"{name}: n={stt['n']} wr={stt['wr']:.1f}% pf={stt['pf']:.2f} "
            f"pnl={stt['pnl']:.0f} mean={stt['mean']:.2f}% todate_mean={stt['todate']:.2f}% "
            f"skip={skip_n}/{sig_n}",
            flush=True,
        )

    # Unsized per-trade quality by distance-to-200 bucket (delay 0, any entry, first signal only)
    bucket_raw = {k: [] for k in [
        ">15% above", "5–15% above", "0–5% above", "0–5% below", "5–15% below", ">15% below"
    ]}
    meta_by_key = {}
    for m in signal_meta:
        meta_by_key[(m["Symbol"], m["Date"])] = m
    any_trades = pd.read_csv(OUT / "any_d0_trades.csv")
    for _, tr in any_trades.iterrows():
        m = meta_by_key.get((tr["Symbol"], tr["Signal Date"]))
        if m is None:
            continue
        bucket_raw[m["Bucket"]].append(tr)

    lines = [
        "EMA10 10/30/48 cross split by close vs EMA200",
        f"Universe: {len(prepared)} | 2y daily | 10% equity max 10/day | capital 5L",
        "Exit: EMA10 below 30 & 48, else hold to last close (the Shilpa-style runner).",
        "",
    ]
    for v in variants:
        lines.append(
            f"{v['name']:14s} trades={v['n']:5d} WR={v['wr']:5.1f}% PF={v['pf']:.2f} "
            f"PnL={v['pnl']:12,.0f} mean={v['mean']:6.2f}% med={v['med']:6.2f}% "
            f"hold={v['hold']:.1f}d todate_mean={v['todate']:.2f}% "
            f"open={v['eod_n']} open_mean={v['eod_mean']:.1f}% skip={v['skipped']}/{v['signals']}"
        )
    lines.append("")
    lines.append("Unsized mean rule-return by close vs EMA200 at the signal (any_d0 book):")
    bucket_rows = []
    for b, lst in bucket_raw.items():
        if not lst:
            continue
        df = pd.DataFrame(lst)
        bucket_rows.append(
            {
                "Bucket": b,
                "Trades": len(df),
                "WR": round(100 * (df["Return %"] > 0).mean(), 1),
                "Mean %": round(df["Return %"].mean(), 2),
                "Med %": round(df["Return %"].median(), 2),
                "Mean to-date %": round(df["To Date %"].mean(), 2),
                "Med to-date %": round(df["To Date %"].median(), 2),
                "Hold": round(df["Hold Days"].mean(), 1),
                "Still open": int((df["Exit Reason"] == "End of data").sum()),
            }
        )
        lines.append(
            f"  {b:14s} n={len(df):4d} WR={100*(df['Return %']>0).mean():5.1f}% "
            f"mean={df['Return %'].mean():6.2f}% todate={df['To Date %'].mean():6.2f}%"
        )
    pd.DataFrame(bucket_rows).to_csv(OUT / "distance_buckets.csv", index=False)
    text = "\n".join(lines) + "\n"
    (OUT / "summary.txt").write_text(text, encoding="utf-8")
    print(text, flush=True)


if __name__ == "__main__":
    main()

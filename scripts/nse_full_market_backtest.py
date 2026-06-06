"""
NSE full-universe breakout backtest.

Uses the same symbol list as fetch_nse_data.py (StockX NSE universe).
"""

import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
import yfinance as yf

from fetch_nse_data import NSE_SYMBOLS

SCRIPT_DIR = Path(__file__).resolve().parent

# =========================
# STRATEGY PARAMETERS
# =========================
INITIAL_CAPITAL = 500000
INITIAL_STOP_PCT = 0.05          # -5% from entry until trailing activates
TRAIL_ACTIVATE_PCT = 0.20        # start trailing once profit reaches +20%
TRAIL_OFFSET_PCT = 0.05          # stop trails 5% below peak profit (20% -> 15%, 25% -> 20%, ...)
START_DATE = "2025-05-15"
END_DATE = "2026-05-15"
MIN_PRICE = 50
MIN_AVG_VALUE = 1e7  # INR 1 crore average traded value
# Each new position uses this fraction of equity at entry (10% per stock).
POSITION_SIZE_PCT = 0.10
# Max new positions per entry day (10 x 10% = 100% capital deployed).
MAX_POSITIONS_PER_DAY = 10

# =========================
# LOAD NSE SYMBOLS
# =========================
def load_symbols(csv_path: Path | None = None, limit: int | None = None) -> list[str]:
    """StockX universe from fetch_nse_data, or optional nse_symbols.csv override."""
    if csv_path is not None and csv_path.is_file():
        df = pd.read_csv(csv_path)
        base = df["Symbol"].dropna().astype(str).str.strip().unique().tolist()
    else:
        base = list(NSE_SYMBOLS)
    if limit is not None:
        base = base[:limit]
    return [f"{s}.NS" for s in base]


symbols: list[str] = []

# =========================
# INDICATORS
# =========================
def prepare_indicators(df):
    df = df.copy()
    df["20EMA"] = df["Close"].ewm(span=20).mean()
    df["50DMA"] = df["Close"].rolling(50).mean()
    df["200DMA"] = df["Close"].rolling(200).mean()
    df["20D_HIGH"] = df["High"].rolling(20).max().shift(1)
    df["VOL20"] = df["Volume"].rolling(20).mean()
    df["AVG_VALUE"] = (df["Close"] * df["Volume"]).rolling(20).mean()

    # RSI(14)
    delta = df["Close"].diff()
    gain = delta.clip(lower=0).rolling(14).mean()
    loss = (-delta.clip(upper=0)).rolling(14).mean()
    rs = gain / loss
    df["RSI"] = 100 - (100 / (1 + rs))
    return df

# =========================
# SIGNAL RULES
# =========================
def generate_signals(df):
    cond = (
        (df["Close"] > df["20D_HIGH"]) &
        (df["Close"] > df["50DMA"]) &
        (df["50DMA"] > df["200DMA"]) &
        (df["Volume"] > 1.5 * df["VOL20"]) &
        (df["RSI"].between(60, 80)) &
        (df["Close"] >= MIN_PRICE) &
        (df["AVG_VALUE"] >= MIN_AVG_VALUE)
    )
    return df[cond]

# =========================
# SIMULATE TRADE
# =========================
def _trade_exit_path(df, signal_idx):
    """Entry/exit prices and dates without position sizing."""
    if signal_idx + 1 >= len(df):
        return None

    entry_row = df.iloc[signal_idx + 1]
    entry_price = float(entry_row["Open"])
    entry_date = df.index[signal_idx + 1]

    if np.isnan(entry_price) or entry_price <= 0:
        return None

    initial_stop = entry_price * (1 - INITIAL_STOP_PCT)
    max_idx = len(df) - 1

    exit_date = None
    exit_price = None
    exit_reason = None
    trailing_active = False
    peak_profit_pct = 0.0

    for i in range(signal_idx + 1, max_idx + 1):
        row = df.iloc[i]
        high = float(row["High"])
        low = float(row["Low"])
        high_profit_pct = (high / entry_price) - 1.0

        if high_profit_pct >= TRAIL_ACTIVATE_PCT:
            trailing_active = True

        if trailing_active:
            peak_profit_pct = max(peak_profit_pct, high_profit_pct)
            trail_stop = entry_price * (1 + peak_profit_pct - TRAIL_OFFSET_PCT)
            if low <= trail_stop:
                exit_price = trail_stop
                exit_reason = "Trailing Stop"
                exit_date = df.index[i]
                break
        elif low <= initial_stop:
            exit_price = initial_stop
            exit_reason = "Stop Loss"
            exit_date = df.index[i]
            break

    # Close at last available bar only if stops never triggered (end of data range).
    if exit_date is None:
        exit_date = df.index[max_idx]
        exit_price = float(df.iloc[max_idx]["Close"])
        exit_reason = "End of Data"

    return {
        "symbol": df.attrs.get("symbol", ""),
        "signal_date": df.index[signal_idx].date(),
        "entry_date": entry_date.date(),
        "entry_price": entry_price,
        "exit_date": exit_date.date(),
        "exit_price": exit_price,
        "exit_reason": exit_reason,
    }


def _size_trade(path: dict, equity_at_entry: float) -> dict | None:
    """Allocate POSITION_SIZE_PCT of equity; compute shares and PnL."""
    allocation = equity_at_entry * POSITION_SIZE_PCT
    entry_price = path["entry_price"]
    shares = int(allocation // entry_price)
    if shares == 0:
        return None

    invested = shares * entry_price
    exit_price = path["exit_price"]
    pnl = (exit_price - entry_price) * shares
    ret = pnl / invested if invested > 0 else 0.0

    return {
        "Symbol": path["symbol"],
        "Signal Date": path["signal_date"],
        "Entry Date": path["entry_date"],
        "Entry Price": round(entry_price, 2),
        "Exit Date": path["exit_date"],
        "Exit Price": round(exit_price, 2),
        "Exit Reason": path["exit_reason"],
        "Equity at Entry": round(equity_at_entry, 2),
        "Allocation %": round(POSITION_SIZE_PCT * 100, 2),
        "Allocation (INR)": round(allocation, 2),
        "Invested (INR)": round(invested, 2),
        "Shares": shares,
        "Return %": round(ret * 100, 2),
        "PnL": round(pnl, 2),
    }


def apply_position_sizing(candidates: list[dict]) -> list[dict]:
    """
    Size trades in entry-date order: each position uses 10% of current equity.
    At most MAX_POSITIONS_PER_DAY new positions per calendar entry day.
    """
    candidates.sort(key=lambda c: (c["entry_date"], c["symbol"]))
    trades: list[dict] = []
    equity = float(INITIAL_CAPITAL)
    entries_today = 0
    current_entry_day = None

    for path in candidates:
        entry_day = path["entry_date"]
        if entry_day != current_entry_day:
            current_entry_day = entry_day
            entries_today = 0

        if entries_today >= MAX_POSITIONS_PER_DAY:
            continue

        sized = _size_trade(path, equity)
        if sized is None:
            continue

        trades.append(sized)
        equity += sized["PnL"]
        entries_today += 1

    return trades

# =========================
# MAIN BACKTEST
# =========================
def run_backtest(output_dir: Path):
    output_dir.mkdir(parents=True, exist_ok=True)
    candidates: list[dict] = []

    print(f"Universe: {len(symbols)} symbols  |  {START_DATE} to {END_DATE}")
    print(
        f"Sizing:     {POSITION_SIZE_PCT * 100:.0f}% of equity per entry "
        f"(max {MAX_POSITIONS_PER_DAY}/day)"
    )
    print(
        f"Exits:      -{INITIAL_STOP_PCT * 100:.0f}% initial stop; "
        f"trail {TRAIL_OFFSET_PCT * 100:.0f}% below peak after +{TRAIL_ACTIVATE_PCT * 100:.0f}%"
    )
    print(f"Output:     {output_dir}\n")

    for i, symbol in enumerate(symbols, 1):
        try:
            print(f"[{i}/{len(symbols)}] Processing {symbol}...", flush=True)
            df = yf.download(
                symbol,
                start=START_DATE,
                end=END_DATE,
                progress=False,
                auto_adjust=False,
                threads=False
            )

            if df.empty or len(df) < 220:
                continue

            if isinstance(df.columns, pd.MultiIndex):
                df.columns = df.columns.get_level_values(0)

            df.attrs["symbol"] = symbol
            df = prepare_indicators(df)
            signals = generate_signals(df)

            for signal_date in signals.index:
                idx = df.index.get_loc(signal_date)
                path = _trade_exit_path(df, idx)
                if path:
                    candidates.append(path)

        except Exception as e:
            print(f"Error processing {symbol}: {e}")

    print(f"\nSignals found: {len(candidates)}  |  Applying 10% position sizing...")
    sized_trades = apply_position_sizing(candidates)
    trades = pd.DataFrame(sized_trades)

    if trades.empty:
        print("No trades found.")
        return

    trades.sort_values("Entry Date", inplace=True)
    trades["Cumulative PnL"] = trades["PnL"].cumsum()
    trades["Equity"] = INITIAL_CAPITAL + trades["Cumulative PnL"]
    trades["Peak Equity"] = trades["Equity"].cummax()
    trades["Drawdown %"] = (
        (trades["Equity"] - trades["Peak Equity"])
        / trades["Peak Equity"] * 100
    )

    # Summary Metrics
    total_trades = len(trades)
    winners = (trades["PnL"] > 0).sum()
    losers = (trades["PnL"] < 0).sum()
    win_rate = winners / total_trades * 100
    total_pnl = trades["PnL"].sum()
    final_capital = INITIAL_CAPITAL + total_pnl
    max_drawdown = trades["Drawdown %"].min()

    avg_win = trades.loc[trades["PnL"] > 0, "PnL"].mean()
    avg_loss = trades.loc[trades["PnL"] < 0, "PnL"].mean()

    gross_profit = trades.loc[trades["PnL"] > 0, "PnL"].sum()
    gross_loss = abs(trades.loc[trades["PnL"] < 0, "PnL"].sum())
    profit_factor = gross_profit / gross_loss if gross_loss > 0 else np.inf

    print("\n===== BACKTEST SUMMARY =====")
    print(f"Period         : {START_DATE} to {END_DATE}")
    print(f"Position Size  : {POSITION_SIZE_PCT * 100:.0f}% of equity at each entry")
    print(f"Total Trades   : {total_trades}")
    print(f"Winners        : {winners}")
    print(f"Losers         : {losers}")
    print(f"Win Rate       : {win_rate:.2f}%")
    print(f"Average Win    : INR {avg_win:,.2f}")
    print(f"Average Loss   : INR {avg_loss:,.2f}")
    print(f"Profit Factor  : {profit_factor:.2f}")
    print(f"Total PnL      : INR {total_pnl:,.2f}")
    print(f"Final Capital  : INR {final_capital:,.2f}")
    print(f"Return         : {(final_capital / INITIAL_CAPITAL - 1) * 100:.2f}%")
    print(f"Max Drawdown   : {max_drawdown:.2f}%")

    xlsx_path = output_dir / "nse_full_market_backtest.xlsx"
    csv_path = output_dir / "equity_curve.csv"
    png_path = output_dir / "equity_curve.png"

    trades.to_excel(xlsx_path, index=False)
    trades.to_csv(csv_path, index=False)

    plt.figure(figsize=(10, 5))
    plt.plot(pd.to_datetime(trades["Entry Date"]), trades["Equity"])
    plt.title("Equity Curve")
    plt.xlabel("Date")
    plt.ylabel("Equity (INR)")
    plt.grid(True)
    plt.tight_layout()
    plt.savefig(png_path)

    print("\nGenerated files:")
    print(f"- {xlsx_path}")
    print(f"- {csv_path}")
    print(f"- {png_path}")


def main():
    global symbols
    parser = argparse.ArgumentParser(description="NSE full-market backtest (StockX universe)")
    parser.add_argument(
        "--symbols-csv",
        type=Path,
        default=None,
        help="Optional CSV with Symbol column (default: fetch_nse_data.NSE_SYMBOLS)",
    )
    parser.add_argument("--limit", type=int, default=None, help="Process first N symbols only")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=SCRIPT_DIR / "backtest_output",
        help="Directory for xlsx/csv/png outputs",
    )
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)

    csv = args.symbols_csv
    if csv is None:
        default_csv = SCRIPT_DIR / "nse_symbols.csv"
        if default_csv.is_file():
            csv = default_csv

    symbols = load_symbols(csv, args.limit)

    # Export universe snapshot for reference
    out_csv = SCRIPT_DIR / "nse_symbols.csv"
    pd.DataFrame({"Symbol": [s.replace(".NS", "") for s in symbols]}).to_csv(
        out_csv, index=False
    )
    print(f"Wrote universe ({len(symbols)} symbols) -> {out_csv}")

    run_backtest(args.output_dir)


if __name__ == "__main__":
    main()

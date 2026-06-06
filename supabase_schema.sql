-- ============================================================
--  StockX — Supabase schema
--  Paste into: Supabase → SQL Editor → Run
--  Safe to re-run: policies are dropped before recreate.
-- ============================================================

-- Stores OHLCV candle arrays for each stock + timeframe.
-- One row per (symbol, timeframe) combination.
CREATE TABLE IF NOT EXISTS stock_candles (
  id           BIGSERIAL    PRIMARY KEY,
  symbol       TEXT         NOT NULL,
  timeframe    TEXT         NOT NULL,           -- '1d' | '1wk' | '1mo'
  last_updated TIMESTAMPTZ  DEFAULT NOW(),
  t            BIGINT[]     NOT NULL,           -- timestamps  (ms since epoch)
  o            FLOAT8[]     NOT NULL,           -- open  prices
  h            FLOAT8[]     NOT NULL,           -- high  prices
  l            FLOAT8[]     NOT NULL,           -- low   prices
  c            FLOAT8[]     NOT NULL,           -- close prices
  v            FLOAT8[]     NOT NULL,           -- volume
  UNIQUE (symbol, timeframe)
);

-- Index for fast bulk reads by timeframe
CREATE INDEX IF NOT EXISTS idx_candles_tf
  ON stock_candles (timeframe);

-- ── Row Level Security ──────────────────────────────────────
ALTER TABLE stock_candles ENABLE ROW LEVEL SECURITY;

-- Allow full access using the anon key (personal / single-user app).
-- Tighten this if you add authentication later.
DROP POLICY IF EXISTS "anon_full_access" ON stock_candles;
CREATE POLICY "anon_full_access"
  ON stock_candles
  FOR ALL
  USING (true)
  WITH CHECK (true);

-- ── Screener result cache (per filter fingerprint + timeframe) ─────────────
-- Populated after a successful screener run; read on subsequent runs with
-- the same filter settings while [built_at] is fresh (see app TTL).
CREATE TABLE IF NOT EXISTS screener_filter_cache (
  filter_hash   TEXT         NOT NULL,
  timeframe     TEXT         NOT NULL,
  built_at      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
  payload       JSONB        NOT NULL,
  PRIMARY KEY (filter_hash, timeframe)
);

CREATE INDEX IF NOT EXISTS idx_screener_cache_built
  ON screener_filter_cache (built_at);

ALTER TABLE screener_filter_cache ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "anon_full_access_screener_cache" ON screener_filter_cache;
CREATE POLICY "anon_full_access_screener_cache"
  ON screener_filter_cache
  FOR ALL
  USING (true)
  WITH CHECK (true);

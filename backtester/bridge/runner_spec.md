# Bridge Runner Specification — MT4 EA Contract

## Overview

The bridge is a **file-based** job queue. Python (Streamlit app) writes job JSON files to `pending/`; the MT4 EA runner reads them, executes the indicator, and writes outputs to `done/`. Python never executes `.mq4` or `.ex4` files directly.

---

## Directory Layout

```
bridge/jobs/
├── pending/
│   └── <run_id>.json       ← written by Python app
└── done/
    └── <run_id>/
        ├── normalized_candles.csv
        ├── normalized_signals.csv
        └── job_result.json
```

---

## Job JSON Schema (`pending/<run_id>.json`)

```json
{
  "job_id": "<uuid4>",
  "created_at": "<ISO8601 UTC>",
  "indicator_id": "<uuid4>",
  "indicator_file": "<relative path from backtester/library/indicators/>",
  "candle_source_type": "ctf|csv",
  "candle_file": "<absolute path or null>",
  "config": {
    "symbols": ["EURUSD"],
    "date_range": {"from": null, "to": null}
  },
  "status": "pending"
}
```

---

## MT4 EA Responsibilities

1. **Poll** `bridge/jobs/pending/` for new `.json` files
2. **Read** job JSON — load `indicator_file` from `library/indicators/`
3. **Load candles** from `candle_file` (CSV/CTF path) or from MT4's own history if null
4. **Execute** the indicator against the candle data
5. **Write outputs** to `bridge/jobs/done/<job_id>/`:

### `normalized_candles.csv` schema
```
timestamp,symbol,timeframe,open,high,low,close,volume
2024-01-02,EURUSD,D1,1.1040,1.1075,1.1020,1.1060,22400
```

### `normalized_signals.csv` schema
```
timestamp,symbol,signal
2024-01-02,EURUSD,1
```
Signal values: `-1` (short), `0` (flat/no signal), `1` (long)

### `job_result.json` schema
```json
{"status": "done", "error": null}
```
On failure:
```json
{"status": "failed", "error": "Description of what went wrong"}
```

6. **Move** (or copy + delete) `pending/<job_id>.json` into `done/<job_id>/`

---

## Constraints

- Python **never** executes `.mq4` or `.ex4` files
- The EA must complete within a reasonable time before the app times out on polling
- Output CSV column names must match the schemas above exactly (case-sensitive)
- All timestamps must be `YYYY-MM-DD` format (D1 bars)
- Symbols must be from the allowed basket: `EURUSD, EURGBP, AUDNZD, AUDCAD, CHFJPY`

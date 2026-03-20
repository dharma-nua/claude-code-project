# NNFX Lite Pro 1 — Design Specification

**Version:** 1.0
**Date:** 2026-03-20
**Status:** Approved for implementation
**Phase:** 1 (C1 indicator testing in isolation)

---

## Summary

| Field | Value |
|---|---|
| Project name | NNFX Lite Pro 1 |
| Platform | MetaTrader 4 (MQL4) |
| Purpose | Test individual C1 confirmation indicators in isolation using NNFX money management rules |
| Components | 3 — Setup script, EA (brain), Panel indicator (UI) |
| Signal modes | 3 — Two-line cross, Zero-line cross, Histogram |
| Trade model | Virtual (no real OrderSend), single position, ATR-based SL/TP, 2% risk |
| Chart mechanism | Offline symbol with HST bar feeding (no ChartOpen) |
| Communication | GlobalVariable bridge between EA and Panel |
| Output | Trades CSV + Summary CSV |
| Scope exclusions | Baseline, C2, Volume filter, Exit indicator, multi-symbol, optimisation |

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [File and Folder Structure](#2-file-and-folder-structure)
3. [Component 1 — NNFXLiteSetup.mq4 (Script)](#3-component-1--nnfxlitesetupmq4-script)
4. [Component 2 — NNFXLitePro1.mq4 (Expert Advisor)](#4-component-2--nnfxlitepro1mq4-expert-advisor)
5. [Component 3 — NNFXLitePanel.mq4 (Indicator)](#5-component-3--nnfxlitepanelmq4-indicator)
6. [Include Files](#6-include-files)
7. [Offline Chart Build Mechanism](#7-offline-chart-build-mechanism)
8. [Signal Engine — 3 C1 Modes](#8-signal-engine--3-c1-modes)
9. [Virtual Trade Engine](#9-virtual-trade-engine)
10. [Control Panel and HUD](#10-control-panel-and-hud)
11. [GlobalVariable Bridge](#11-globalvariable-bridge)
12. [State Machine](#12-state-machine)
13. [Stats and CSV Export](#13-stats-and-csv-export)
14. [Extern Inputs Reference](#14-extern-inputs-reference)
15. [Phase 1 Scope Boundary](#15-phase-1-scope-boundary)
16. [Deployment and Usage Workflow](#16-deployment-and-usage-workflow)

---

## 1. Architecture Overview

The system is composed of three MQL4 programs that communicate via GlobalVariables and a shared HST file:

```
┌─────────────────────────────┐     GlobalVariables     ┌──────────────────────────────┐
│  NNFXLitePro1.mq4  (EA)    │◄───────────────────────►│  NNFXLitePanel.mq4 (Indi)   │
│  Attached to: real EURUSD   │                         │  Attached to: EURUSD_SIM     │
│  D1 chart                   │                         │  offline D1 chart            │
│                             │     HST file write      │                              │
│  - Reads real OHLC          │─────────────────────►   │  - Draws control panel       │
│  - Feeds bars to HST        │     + ChartRefresh      │  - Draws HUD                 │
│  - Runs signal engine       │                         │  - Sends commands via GV      │
│  - Manages virtual trades   │                         │  - Reads state/stats from GV  │
│  - Draws visuals on offline │                         │                              │
│  - Writes CSV on STOP       │                         │                              │
└─────────────────────────────┘                         └──────────────────────────────┘
         ▲
         │  One-time setup
┌────────┴────────────────────┐
│  NNFXLiteSetup.mq4 (Script)│
│  Creates EURUSD_SIM HST     │
│  file with valid header     │
└─────────────────────────────┘
```

### Why three components

| Concern | Solution |
|---|---|
| Offline chart cannot run an EA with timer reliably | EA lives on the real chart; indicator lives on the offline chart |
| OnChartEvent works in indicators but not in EAs running on foreign charts | Panel indicator catches button clicks on the offline chart |
| iCustom needs bars on the offline symbol to compute | EA feeds bars into the HST file and refreshes the offline chart before reading signals |
| No ChartOpen in MQL4 for offline charts | User opens the offline chart once manually; EA finds it via ChartFirst/ChartNext scan |

---

## 2. File and Folder Structure

```
MQL4/
├── Scripts/
│   └── NNFXLiteSetup.mq4              # One-time setup script
├── Experts/
│   └── NNFXLitePro1.mq4               # Main EA (brain)
├── Indicators/
│   └── NNFXLitePanel.mq4              # Offline chart panel + HUD
├── Include/
│   └── NNFXLite/
│       ├── bar_feeder.mqh              # HST file writing, chart refresh
│       ├── signal_engine.mqh           # 3 C1 signal modes, typed param dispatch
│       ├── trade_engine.mqh            # Virtual trade state, SL/TP, ATR sizing
│       ├── stats_engine.mqh            # Running accumulator
│       ├── csv_exporter.mqh            # Trades CSV + summary CSV
│       └── global_vars.mqh            # GlobalVariable name constants + helpers
└── Files/
    └── NNFXLitePro/                   # CSV output root (auto-created)
        └── <Symbol>_<Indicator>_<Start>_<End>/
            ├── trades.csv
            └── summary.csv
```

**HST file location** (managed by MT4, not in MQL4/Files):
```
<terminal_data>/history/<server>/EURUSD_SIM1440.hst
```

---

## 3. Component 1 — NNFXLiteSetup.mq4 (Script)

**Type:** Script (runs once on drop)
**Purpose:** Create the offline symbol's HST file so MT4 recognizes `EURUSD_SIM` as a valid symbol for offline charting.

### Behavior

1. Determine the offline symbol name: `SourceSymbol + "_SIM"` (e.g., `EURUSD_SIM`).
2. Build the HST file path: `<terminal_data>/history/<server>/<symbol><period>.hst` where period = `1440`.
3. If the HST file already exists, prompt a warning in the Experts log and skip (do not overwrite unless `ForceReset = true`).
4. Create the file with `FILE_BIN|FILE_WRITE` mode.
5. Write a valid MT4 HST v401 header (148 bytes).
6. Close the file.
7. Print instructions to the Experts log:
   ```
   [NNFXLiteSetup] Created EURUSD_SIM1440.hst successfully.
   [NNFXLiteSetup] NEXT STEPS:
   [NNFXLiteSetup]   1. In MT4: File > Open Offline > select EURUSD_SIM, D1 > Open
   [NNFXLiteSetup]   2. Attach NNFXLitePanel indicator to the offline chart
   [NNFXLiteSetup]   3. Open your real EURUSD D1 chart
   [NNFXLiteSetup]   4. Attach NNFXLitePro1 EA to the real chart
   ```

### HST v401 Header Structure (148 bytes)

| Offset | Size | Type | Field | Value |
|---|---|---|---|---|
| 0 | 4 | int | version | 401 |
| 4 | 64 | char[] | copyright | "NNFXLitePro1" (null-padded) |
| 68 | 12 | char[] | symbol | "EURUSD_SIM" (null-padded to 12) |
| 80 | 4 | int | period | 1440 |
| 84 | 4 | int | digits | Copied from MarketInfo(SourceSymbol, MODE_DIGITS) |
| 88 | 4 | int | timesign | 0 |
| 92 | 4 | int | last_sync | 0 |
| 96 | 52 | byte[] | unused | Zero-filled |

**Total header:** 148 bytes.

### Extern Inputs

| Name | Type | Default | Description |
|---|---|---|---|
| SourceSymbol | string | "EURUSD" | Base symbol to derive offline name from |
| ForceReset | bool | false | If true, overwrite existing HST file |

---

## 4. Component 2 — NNFXLitePro1.mq4 (Expert Advisor)

**Type:** Expert Advisor
**Attaches to:** Real symbol D1 chart (e.g., EURUSD D1)
**Purpose:** The brain — feeds bars, reads signals, manages trades, writes output.

### OnInit

1. Validate all extern inputs (indicator name not empty, date range valid, etc.). On failure, print error and return `INIT_FAILED`.
2. Resolve the offline chart ID by scanning `ChartFirst()` / `ChartNext()` for a chart whose symbol matches `SourceSymbol + "_SIM"` and has `NNFXLitePanel` running. Store as `g_offlineChartId`.
3. If no offline chart found, print error: "Offline chart not found. Run NNFXLiteSetup first, open the offline chart, and attach NNFXLitePanel." Return `INIT_FAILED`.
4. Calculate the bar index on the real chart for `TestStartDate` using `iBarShift(SourceSymbol, PERIOD_D1, TestStartDate)`. Store as `g_startBarIndex`.
5. Calculate the bar index for `TestEndDate`. Store as `g_endBarIndex`.
6. Calculate total bars: `g_totalBars = g_startBarIndex - g_endBarIndex + 1`. (Higher index = older bar in MT4.)
7. Set `g_cursorIndex = g_startBarIndex` (start from oldest bar, counting down toward 0).
8. Set `g_barCount = 0` (number of bars fed so far).
9. Initialize the HST file: truncate existing bar data, rewrite header, so each run starts clean.
10. Initialize GlobalVariables: `NNFXLP_STATE = 0` (STOPPED), `NNFXLP_SPEED = 3`, `NNFXLP_BAR_TOT = g_totalBars`, etc.
11. Start timer: `EventSetMillisecondTimer(SpeedLevels[g_currentSpeed])`.

### OnTimer

1. **Read command:** Check `GlobalVariableGet("NNFXLP_CMD")`.
   - CMD=1 (PLAY): Set state to PLAYING.
   - CMD=2 (PAUSE): Set state to PAUSED.
   - CMD=3 (STEP): Feed one bar, then set state to PAUSED.
   - CMD=4 (FASTER): Increase speed level (max 5), reset timer interval.
   - CMD=5 (SLOWER): Decrease speed level (min 1), reset timer interval.
   - CMD=6 (STOP): Flush CSV, set state to STOPPED, clean up.
   - After reading, set `NNFXLP_CMD = 0`.
2. **If state != PLAYING and not STEP:** Return immediately.
3. **Feed bar:** Call `BF_FeedBar()` from `bar_feeder.mqh`.
4. **Read signal:** Call `SE_GetSignal()` from `signal_engine.mqh`. Requires at least 2 bars fed before evaluating.
5. **Process trade:** Call `TE_ProcessBar()` from `trade_engine.mqh`.
6. **Update GlobalVariables:** Write current bar number, date, balance, trade state, stats.
7. **Advance cursor:** Decrement `g_cursorIndex`, increment `g_barCount`.
8. **Check completion:** If `g_cursorIndex < g_endBarIndex`, auto-stop: flush CSV, set state to STOPPED.

### OnDeinit

1. Delete all objects created on the offline chart.
2. Delete all GlobalVariables with prefix `NNFXLP_`.
3. Kill timer.

---

## 5. Component 3 — NNFXLitePanel.mq4 (Indicator)

**Type:** Custom Indicator
**Attaches to:** Offline `EURUSD_SIM` D1 chart
**Purpose:** User interface — control panel buttons and stats HUD.

### OnInit

1. Create all button and label objects for the control panel and HUD (see Section 10).
2. Start timer: `EventSetMillisecondTimer(500)` for HUD refresh polling.
3. Set `IndicatorShortName("NNFXLitePanel")` — this is how the EA identifies the offline chart.

### OnChartEvent

Handles `CHARTEVENT_OBJECT_CLICK` for each button:

| Button Object Name | Action |
|---|---|
| `NNFXLP_BTN_PLAY` | `GlobalVariableSet("NNFXLP_CMD", 1)` |
| `NNFXLP_BTN_PAUSE` | `GlobalVariableSet("NNFXLP_CMD", 2)` |
| `NNFXLP_BTN_STEP` | `GlobalVariableSet("NNFXLP_CMD", 3)` |
| `NNFXLP_BTN_FASTER` | `GlobalVariableSet("NNFXLP_CMD", 4)` |
| `NNFXLP_BTN_SLOWER` | `GlobalVariableSet("NNFXLP_CMD", 5)` |
| `NNFXLP_BTN_STOP` | `GlobalVariableSet("NNFXLP_CMD", 6)` |

After setting the GV, call `ObjectSetInteger(0, sparam, OBJPROP_STATE, false)` to un-depress the button.

### OnTimer (500ms)

1. Read all `NNFXLP_*` state/stats GlobalVariables.
2. Update HUD label text with current values.
3. Update speed indicator dots.
4. Update PLAY/PAUSE button appearance based on state.

### OnDeinit

1. Delete all objects with prefix `NNFXLP_`.
2. Kill timer.

---

## 6. Include Files

### 6.1 `bar_feeder.mqh`

**Responsibility:** Write bars to the offline HST file and refresh the offline chart.

**Key functions:**

| Function | Signature | Description |
|---|---|---|
| `BF_Init` | `bool BF_Init(string symbol, string simSymbol, int period, long offlineChartId)` | Store config, build HST path, truncate and rewrite header |
| `BF_FeedBar` | `bool BF_FeedBar(int cursorIndex)` | Read OHLC from real chart at cursorIndex, append to HST, refresh offline chart |
| `BF_GetHstPath` | `string BF_GetHstPath()` | Return the full HST file path |
| `BF_Cleanup` | `void BF_Cleanup()` | Close any open file handles |

**HST v401 bar record structure (60 bytes):**

| Offset | Size | Type | Field |
|---|---|---|---|
| 0 | 8 | long (int64) | time — bar open time as Unix timestamp |
| 8 | 8 | double | open |
| 16 | 8 | double | high |
| 24 | 8 | double | low |
| 32 | 8 | double | close |
| 40 | 8 | long (int64) | tick_volume |
| 48 | 4 | int (int32) | spread (write 0) |
| 52 | 8 | long (int64) | real_volume (write 0) |

Total: 60 bytes per bar record.

**Bar feed sequence per tick:**
1. `int handle = FileOpenHistory(hstFilename, FILE_BIN|FILE_WRITE|FILE_READ)`
2. `FileSeek(handle, 0, SEEK_END)`
3. Write 60-byte bar record: `FileWriteLong(time)`, `FileWriteDouble(open)`, `FileWriteDouble(high)`, `FileWriteDouble(low)`, `FileWriteDouble(close)`, `FileWriteLong(volume)`, `FileWriteInteger(0)`, `FileWriteLong(0)`
4. `FileClose(handle)`
5. `ChartSetSymbolPeriod(offlineChartId, simSymbol, PERIOD_D1)` — forces MT4 to re-read the HST file and refresh the chart

### 6.2 `signal_engine.mqh`

**Responsibility:** Evaluate C1 indicator signals on the offline symbol.

**Key functions:**

| Function | Signature | Description |
|---|---|---|
| `SE_Init` | `void SE_Init(string simSymbol, int mode, ...)` | Store signal configuration |
| `SE_GetSignal` | `int SE_GetSignal()` | Returns +1 (buy), -1 (sell), or 0 (no signal) |
| `SE_IndCall` | `double SE_IndCall(int bufferIndex, int shift)` | Typed param dispatch wrapper around iCustom |

**Typed param dispatch (`SE_IndCall`):**

The function builds an `iCustom` call with 0-8 typed parameters. Because MQL4 does not support variadic function calls or runtime argument lists, a switch-case on parameter count is required:

```
switch(g_paramCount)
{
    case 0: val = iCustom(sym, tf, indName, buf, shift); break;
    case 1: val = iCustom(sym, tf, indName, p1, buf, shift); break;
    case 2: val = iCustom(sym, tf, indName, p1, p2, buf, shift); break;
    ...
    case 8: val = iCustom(sym, tf, indName, p1, p2, p3, p4, p5, p6, p7, p8, buf, shift); break;
}
```

Parameters are parsed from `C1_ParamValues` and `C1_ParamTypes` CSV strings at init time. Each parameter is stored in a typed variable (`int`, `double`, `bool`, or `string`) and passed in the correct position.

**EMPTY_VALUE / NaN guard:** Every `iCustom` return value is checked:
```
if(val == EMPTY_VALUE || !MathIsValidNumber(val)) return 0;
```

### 6.3 `trade_engine.mqh`

**Responsibility:** Manage virtual trade lifecycle, SL/TP calculation, balance updates.

**Key types:**

```mql4
struct VirtualTrade
{
    bool     isOpen;
    int      dir;            // +1 buy, -1 sell
    datetime entryBar;       // datetime of signal bar
    double   entryPrice;     // bar[1] close
    double   slPrice;
    double   tpPrice;
    double   slPips;
    double   tpPips;
    double   lotSize;
    double   openBalance;    // balance at time of entry
};
```

**Key functions:**

| Function | Signature | Description |
|---|---|---|
| `TE_Init` | `void TE_Init(string simSymbol, double startBalance, double atrSlMult, double atrTpMult, double riskPct)` | Store config, set initial balance |
| `TE_ProcessBar` | `void TE_ProcessBar(int signal, long offlineChartId)` | Full bar processing: check SL/TP, check signal, open/close/reverse |
| `TE_GetBalance` | `double TE_GetBalance()` | Return current simulated balance |
| `TE_GetTrade` | `VirtualTrade TE_GetTrade()` | Return current trade struct |
| `TE_IsTradeOpen` | `bool TE_IsTradeOpen()` | Return trade open state |
| `TE_Cleanup` | `void TE_Cleanup(long offlineChartId)` | Remove all trade visuals from offline chart |

**ATR-based position sizing:**

```
atr         = iATR(simSymbol, PERIOD_D1, ATR_Period, 1)
slDistance   = atr * ATR_SL_Multiplier
tpDistance   = atr * ATR_TP_Multiplier
slPips       = slDistance / point     // where point = MarketInfo(sourceSymbol, MODE_POINT)
pipValue     = MarketInfo(sourceSymbol, MODE_TICKVALUE)
lotSize      = (balance * riskPct) / (slPips * pipValue)
lotSize      = NormalizeDouble(lotSize, 2)
lotSize      = MathMax(lotSize, MarketInfo(sourceSymbol, MODE_MINLOT))
```

**Entry price:** `iClose(simSymbol, PERIOD_D1, 1)` — the close of the just-completed bar. This approximates the NNFX "20 minutes before close" entry rule.

**Exit priority per bar (when trade is open):**

1. Check SL hit: BUY → `iLow(sim, D1, 1) <= slPrice`; SELL → `iHigh(sim, D1, 1) >= slPrice`
2. Check TP hit: BUY → `iHigh(sim, D1, 1) >= tpPrice`; SELL → `iLow(sim, D1, 1) <= tpPrice`
3. If neither hit: check for opposite signal → close current trade and immediately open reverse
4. If same-direction signal or no signal: hold

**Balance update on close:**

```
if(closeReason == SL)   pnl = -trade.slPips * pipValue * trade.lotSize
if(closeReason == TP)   pnl = +trade.tpPips * pipValue * trade.lotSize
if(closeReason == REV)  pnl = (exitPrice - entryPrice) * dir / point * pipValue * trade.lotSize
balance += pnl
```

**Visual objects on offline chart:**

| Object | Type | Description |
|---|---|---|
| `NNFXLP_ARROW_<n>` | OBJ_ARROW | Entry arrow at bar[1] time/close. Code 233 (up, green) for buy, 234 (down, red) for sell |
| `NNFXLP_SL` | OBJ_HLINE | Red dashed horizontal line at SL price. Created on entry, deleted on close |
| `NNFXLP_TP` | OBJ_HLINE | Green dashed horizontal line at TP price. Created on entry, deleted on close |
| `NNFXLP_RESULT_<n>` | OBJ_TEXT | Small label at close bar: "+38p" (green) or "-41p" (red) |

### 6.4 `stats_engine.mqh`

**Responsibility:** Accumulate running trade statistics.

**Key type:**

```mql4
struct RunningStats
{
    int    totalTrades;
    int    totalWins;
    int    totalLosses;
    double totalPipsWon;       // sum of winning trade pips (positive)
    double totalPipsLost;      // sum of losing trade pips (absolute positive)
    double profitFactor;       // totalPipsWon / totalPipsLost
    double winRate;            // totalWins / totalTrades * 100
    int    maxConsecWins;
    int    maxConsecLosses;
    int    curConsecWins;      // internal counter
    int    curConsecLosses;    // internal counter
    double peakBalance;
    double troughBalance;
    double maxDrawdownPct;     // (peak - trough) / peak * 100
    double startBalance;
    double finalBalance;
};
```

**Key functions:**

| Function | Signature | Description |
|---|---|---|
| `ST_Init` | `void ST_Init(double startBalance)` | Zero all counters, set starting balance |
| `ST_RecordTrade` | `void ST_RecordTrade(double pips, double balance, string closeReason)` | Update all running stats |
| `ST_GetStats` | `RunningStats ST_GetStats()` | Return current stats snapshot |

**Drawdown tracking:** After each trade close, compare current balance to `peakBalance`. If balance > peak, update peak and reset trough. If balance < trough, update trough and recalculate `maxDrawdownPct`.

### 6.5 `csv_exporter.mqh`

**Responsibility:** Write trade log and summary CSV files.

**Key functions:**

| Function | Signature | Description |
|---|---|---|
| `CSV_Init` | `void CSV_Init(string symbol, string indicatorName, string startDate, string endDate)` | Build output directory path, create directory |
| `CSV_RecordTrade` | `void CSV_RecordTrade(datetime date, int dir, double entry, double sl, double tp, double exit, string reason, double pips, double balance)` | Append one row to in-memory trade array |
| `CSV_Flush` | `void CSV_Flush(RunningStats stats)` | Write trades.csv and summary.csv to disk |

**Output directory:** `MQL4/Files/NNFXLitePro/<Symbol>_<IndicatorName>_<StartDate>_<EndDate>/`

If the directory already exists (repeat run), append a numeric suffix: `_2`, `_3`, etc. Multiple runs never overwrite.

**trades.csv format:**

```
Date,Direction,EntryPrice,SLPrice,TPPrice,ExitPrice,CloseReason,Pips,Balance
2023.01.15,BUY,1.08230,1.07400,1.09500,1.09500,TP,127.0,10254.00
2023.01.22,SELL,1.09100,1.09900,1.08200,1.09900,SL,-80.0,10092.00
```

**summary.csv format:**

```
Indicator,Symbol,StartDate,EndDate,TotalTrades,Wins,Losses,WinRate,TotalPipsWon,TotalPipsLost,ProfitFactor,MaxConsecWins,MaxConsecLosses,MaxDrawdownPct,StartBalance,FinalBalance
SSL_Channel,EURUSD,2020.01.01,2023.12.31,147,88,59,59.9,12450.0,8320.0,1.50,7,4,8.3,10000.00,11840.00
```

### 6.6 `global_vars.mqh`

**Responsibility:** Define GlobalVariable name constants and provide typed read/write helpers.

**Constants:**

```mql4
#define NNFXLP_CMD        "NNFXLP_CMD"
#define NNFXLP_STATE      "NNFXLP_STATE"
#define NNFXLP_SPEED      "NNFXLP_SPEED"
#define NNFXLP_BAR_CUR    "NNFXLP_BAR_CUR"
#define NNFXLP_BAR_TOT    "NNFXLP_BAR_TOT"
#define NNFXLP_DATE       "NNFXLP_DATE"
#define NNFXLP_BAL        "NNFXLP_BAL"
#define NNFXLP_WINS       "NNFXLP_WINS"
#define NNFXLP_LOSSES     "NNFXLP_LOSSES"
#define NNFXLP_PF         "NNFXLP_PF"
#define NNFXLP_TRADE      "NNFXLP_TRADE"
#define NNFXLP_ENTRY      "NNFXLP_ENTRY"
#define NNFXLP_SL         "NNFXLP_SL"
#define NNFXLP_TP         "NNFXLP_TP"
```

**Helper functions:**

```mql4
void   GV_SetInt(string name, int value)      { GlobalVariableSet(name, (double)value); }
int    GV_GetInt(string name)                  { return (int)GlobalVariableGet(name); }
void   GV_SetDouble(string name, double value) { GlobalVariableSet(name, value); }
double GV_GetDouble(string name)               { return GlobalVariableGet(name); }
void   GV_DeleteAll()                          // Deletes all GVs with prefix "NNFXLP_"
```

---

## 7. Offline Chart Build Mechanism

### One-Time Setup

1. User runs `NNFXLiteSetup.mq4` script on any chart.
2. Script creates `EURUSD_SIM1440.hst` in `<terminal_data>/history/<server>/` with a valid 148-byte HST v401 header and zero bar records.
3. User opens MT4 menu: File > Open Offline > selects `EURUSD_SIM, D1` > clicks Open.
4. User drags `NNFXLitePanel.mq4` onto the offline chart. The indicator sets its short name to `"NNFXLitePanel"`.
5. User opens a real `EURUSD D1` chart and attaches `NNFXLitePro1.mq4`.

### Bar Feeding Process (per timer tick)

```
1. Read OHLC from real chart:
   time  = iTime(SourceSymbol, PERIOD_D1, cursorIndex)
   open  = iOpen(SourceSymbol, PERIOD_D1, cursorIndex)
   high  = iHigh(SourceSymbol, PERIOD_D1, cursorIndex)
   low   = iLow(SourceSymbol, PERIOD_D1, cursorIndex)
   close = iClose(SourceSymbol, PERIOD_D1, cursorIndex)
   vol   = iVolume(SourceSymbol, PERIOD_D1, cursorIndex)

2. Open HST file:
   handle = FileOpenHistory(filename, FILE_BIN|FILE_WRITE|FILE_READ)

3. Seek to end:
   FileSeek(handle, 0, SEEK_END)

4. Write 60-byte bar record:
   FileWriteLong((long)time)            // 8 bytes — time as int64
   FileWriteDouble(open)                // 8 bytes
   FileWriteDouble(high)                // 8 bytes
   FileWriteDouble(low)                 // 8 bytes
   FileWriteDouble(close)               // 8 bytes
   FileWriteLong((long)vol)             // 8 bytes — tick_volume
   FileWriteInteger(0)                  // 4 bytes — spread (zero)
   FileWriteLong(0)                     // 8 bytes — real_volume (zero)

5. Close file:
   FileClose(handle)

6. Refresh offline chart:
   ChartSetSymbolPeriod(offlineChartId, "EURUSD_SIM", PERIOD_D1)
```

### Offline Chart Discovery

The EA finds the offline chart on init by iterating all open charts:

```mql4
long chartId = ChartFirst();
while(chartId >= 0)
{
    if(ChartSymbol(chartId) == simSymbol && ChartPeriod(chartId) == PERIOD_D1)
    {
        // Verify NNFXLitePanel is attached by checking indicator short name
        // via ChartIndicatorName(chartId, 0, i) loop
        g_offlineChartId = chartId;
        break;
    }
    chartId = ChartNext(chartId);
}
```

### Speed Levels

| Level | Timer Interval (ms) | Approx Bars/Sec | 3 Years (~750 bars) |
|---|---|---|---|
| 1 | 2000 | 0.5 | 25 minutes |
| 2 | 800 | 1.25 | 10 minutes |
| 3 | 300 | 3.3 | 3.8 minutes |
| 4 | 100 | 10 | 75 seconds |
| 5 | 30 | 33 | 23 seconds |

Speed changes call `EventKillTimer()` then `EventSetMillisecondTimer(newInterval)`.

---

## 8. Signal Engine — 3 C1 Modes

All signal reads use the offline symbol to ensure no lookahead:

```mql4
iCustom("EURUSD_SIM", PERIOD_D1, C1_IndicatorName, [typed params...], bufferIndex, shift)
```

Signals are evaluated at `shift=1` (last closed bar) and `shift=2` (bar before that) to detect crossovers.

### Mode 0 — Two-Line Cross

For indicators with two output lines (e.g., Stochastic, MACD signal/main, custom MA crossover).

```
fast1 = iCustom(sim, D1, ind, ..., C1_FastBuffer, 1)
fast2 = iCustom(sim, D1, ind, ..., C1_FastBuffer, 2)
slow1 = iCustom(sim, D1, ind, ..., C1_SlowBuffer, 1)
slow2 = iCustom(sim, D1, ind, ..., C1_SlowBuffer, 2)

BUY signal:  fast2 <= slow2 AND fast1 > slow1
SELL signal: fast2 >= slow2 AND fast1 < slow1
```

Handles 3+ line indicators: user selects which 2 buffer indices to compare; remaining buffers are ignored.

### Mode 1 — Zero-Line Cross (Custom Level)

For indicators that cross a reference level (e.g., RSI crossing 50, CCI crossing 0, custom oscillator).

```
sig1 = iCustom(sim, D1, ind, ..., C1_SignalBuffer, 1)
sig2 = iCustom(sim, D1, ind, ..., C1_SignalBuffer, 2)
level = C1_CrossLevel   // default 0.0

BUY signal:  sig2 <= level AND sig1 > level
SELL signal: sig2 >= level AND sig1 < level
```

### Mode 2 — Histogram

**Single buffer** (`C1_HistDualBuffer = false`):

```
hist1 = iCustom(sim, D1, ind, ..., C1_HistBuffer, 1)
hist2 = iCustom(sim, D1, ind, ..., C1_HistBuffer, 2)

BUY signal:  hist2 <= 0 AND hist1 > 0
SELL signal: hist2 >= 0 AND hist1 < 0
```

**Dual buffer** (`C1_HistDualBuffer = true`):

For MT4 indicators that paint buy/sell histogram bars on separate buffers (one buffer has values, the other has EMPTY_VALUE).

```
buy1  = iCustom(sim, D1, ind, ..., C1_HistBuyBuffer, 1)
buy2  = iCustom(sim, D1, ind, ..., C1_HistBuyBuffer, 2)
sell1 = iCustom(sim, D1, ind, ..., C1_HistSellBuffer, 1)
sell2 = iCustom(sim, D1, ind, ..., C1_HistSellBuffer, 2)

BUY signal:  buy1 > 0 AND (buy2 == EMPTY_VALUE OR buy2 <= 0)
SELL signal: sell1 > 0 AND (sell2 == EMPTY_VALUE OR sell2 <= 0)
```

### EMPTY_VALUE and NaN Guard

Every buffer read is validated before use:

```mql4
double val = iCustom(...);
if(val == EMPTY_VALUE || val >= DBL_MAX || !MathIsValidNumber(val))
    return 0;  // no signal
```

This prevents false signals from uninitialized indicator buffers at the start of the data range.

---

## 9. Virtual Trade Engine

### Trade Lifecycle

```
[No Trade] ──signal──► [Trade Open] ──SL/TP/Reverse──► [Trade Closed] ──► [No Trade]
                              │                                │
                              │         (reverse signal)       │
                              └───close + immediate reopen ◄───┘
```

### Entry Logic (called when no trade is open and signal != 0)

1. Receive signal direction from signal engine (+1 or -1).
2. Calculate ATR: `atr = iATR(simSymbol, PERIOD_D1, ATR_Period, 1)`.
3. Calculate SL distance: `slDist = atr * ATR_SL_Multiplier`.
4. Calculate TP distance: `tpDist = atr * ATR_TP_Multiplier`.
5. Set entry price: `entryPrice = iClose(simSymbol, PERIOD_D1, 1)`.
6. Set SL and TP:
   - BUY: `slPrice = entryPrice - slDist`, `tpPrice = entryPrice + tpDist`
   - SELL: `slPrice = entryPrice + slDist`, `tpPrice = entryPrice - tpDist`
7. Calculate lot size using 2% risk (or configured `RiskPercent`).
8. Populate the `VirtualTrade` struct.
9. Draw entry arrow and SL/TP lines on the offline chart.

### Exit Logic (called every bar when trade is open)

**Priority order — SL and TP checked before new signals:**

```
bar1High = iHigh(simSymbol, PERIOD_D1, 1)
bar1Low  = iLow(simSymbol, PERIOD_D1, 1)

// Step 1: Check SL
if(trade.dir == +1 && bar1Low <= trade.slPrice)  → close at SL, reason="SL"
if(trade.dir == -1 && bar1High >= trade.slPrice)  → close at SL, reason="SL"

// Step 2: Check TP (only if SL not hit)
if(trade.dir == +1 && bar1High >= trade.tpPrice)  → close at TP, reason="TP"
if(trade.dir == -1 && bar1Low <= trade.tpPrice)    → close at TP, reason="TP"

// Step 3: Check for opposite signal (only if neither SL nor TP hit)
if(signal != 0 && signal != trade.dir)
    → close at bar[1] close, reason="REVERSE_BUY" or "REVERSE_SELL"
    → immediately open new trade in signal direction
```

### Exit Price Determination

| Close Reason | Exit Price |
|---|---|
| SL | `trade.slPrice` |
| TP | `trade.tpPrice` |
| REVERSE_BUY / REVERSE_SELL | `iClose(simSymbol, PERIOD_D1, 1)` |

### P&L Calculation

```mql4
double point = MarketInfo(SourceSymbol, MODE_POINT);
double pipValue = MarketInfo(SourceSymbol, MODE_TICKVALUE);

// Pips result
double pips = (exitPrice - trade.entryPrice) * trade.dir / point;

// Dollar result
double pnl = pips * pipValue * trade.lotSize;

// Update balance
g_balance += pnl;
```

---

## 10. Control Panel and HUD

All UI elements are drawn by `NNFXLitePanel.mq4` on the offline chart using `ObjectCreate`.

### Object Naming Convention

All objects use the prefix `NNFXLP_` to enable bulk cleanup.

### Control Panel Layout (top-left corner)

```
┌──────────────────────────────────────┐
│  NNFX LITE PRO 1           [■ STOP] │
│  ◄◄ SLOWER   ► PLAY   FASTER ►►     │
│         ■ PAUSE    ↩ STEP            │
│  Speed: ●●●○○  (3/5)                │
└──────────────────────────────────────┘
```

**Object definitions:**

| Object Name | Type | Properties |
|---|---|---|
| `NNFXLP_LBL_TITLE` | OBJ_LABEL | "NNFX LITE PRO 1", font Consolas 11, color White |
| `NNFXLP_BTN_STOP` | OBJ_BUTTON | "STOP", 60x22, bg Red, text White |
| `NNFXLP_BTN_SLOWER` | OBJ_BUTTON | "<<", 40x22, bg DarkSlateGray, text White |
| `NNFXLP_BTN_PLAY` | OBJ_BUTTON | "PLAY" / "PLAY", 60x22, bg ForestGreen, text White |
| `NNFXLP_BTN_FASTER` | OBJ_BUTTON | ">>", 40x22, bg DarkSlateGray, text White |
| `NNFXLP_BTN_PAUSE` | OBJ_BUTTON | "PAUSE", 60x22, bg DarkOrange, text White |
| `NNFXLP_BTN_STEP` | OBJ_BUTTON | "STEP", 50x22, bg SteelBlue, text White |
| `NNFXLP_LBL_SPEED` | OBJ_LABEL | "Speed: ●●●○○ (3/5)", font Consolas 9, color Silver |

All buttons use `CORNER_LEFT_UPPER`, `OBJPROP_XDISTANCE` / `OBJPROP_YDISTANCE` for pixel positioning.

### HUD Layout (below control panel)

```
┌──────────────────────────────────────┐
│  Date:    2023.04.12                 │
│  Bar:     147 / 520                  │
│  Balance: $11,240.00                 │
│  Trade:   LONG  entry 1.0823        │
│           SL 1.0740  TP 1.0950      │
│  Stats:   W:23  L:14  WR:62.2%      │
│           PF: 1.84                   │
└──────────────────────────────────────┘
```

**Object definitions:**

| Object Name | Type | Content Source (GlobalVariable) |
|---|---|---|
| `NNFXLP_HUD_DATE` | OBJ_LABEL | `NNFXLP_DATE` — formatted as `yyyy.MM.dd` |
| `NNFXLP_HUD_BAR` | OBJ_LABEL | `NNFXLP_BAR_CUR` / `NNFXLP_BAR_TOT` |
| `NNFXLP_HUD_BAL` | OBJ_LABEL | `NNFXLP_BAL` — formatted as `$xx,xxx.xx` |
| `NNFXLP_HUD_TRADE` | OBJ_LABEL | `NNFXLP_TRADE`, `NNFXLP_ENTRY` |
| `NNFXLP_HUD_SLTP` | OBJ_LABEL | `NNFXLP_SL`, `NNFXLP_TP` |
| `NNFXLP_HUD_STATS` | OBJ_LABEL | `NNFXLP_WINS`, `NNFXLP_LOSSES` — derived WR |
| `NNFXLP_HUD_PF` | OBJ_LABEL | `NNFXLP_PF` |

All HUD labels: font Consolas 10, color Silver, CORNER_LEFT_UPPER.

---

## 11. GlobalVariable Bridge

### Complete Reference Table

| GlobalVariable Name | Direction | Type | Values | Description |
|---|---|---|---|---|
| `NNFXLP_CMD` | Panel → EA | int | 0=none, 1=play, 2=pause, 3=step, 4=faster, 5=slower, 6=stop | Command from panel button click |
| `NNFXLP_STATE` | EA → Panel | int | 0=stopped, 1=playing, 2=paused | Current state machine state |
| `NNFXLP_SPEED` | EA → Panel | int | 1-5 | Current speed level |
| `NNFXLP_BAR_CUR` | EA → Panel | int | 0 to totalBars | Current bar number (1-indexed) |
| `NNFXLP_BAR_TOT` | EA → Panel | int | positive int | Total bars in test range |
| `NNFXLP_DATE` | EA → Panel | datetime | Unix timestamp | Current bar datetime |
| `NNFXLP_BAL` | EA → Panel | double | positive | Current simulated balance |
| `NNFXLP_WINS` | EA → Panel | int | >= 0 | Total winning trades |
| `NNFXLP_LOSSES` | EA → Panel | int | >= 0 | Total losing trades |
| `NNFXLP_PF` | EA → Panel | double | >= 0 | Profit factor (totalPipsWon / totalPipsLost) |
| `NNFXLP_TRADE` | EA → Panel | int | 0=none, 1=long, -1=short | Current trade direction |
| `NNFXLP_ENTRY` | EA → Panel | double | price | Current trade entry price |
| `NNFXLP_SL` | EA → Panel | double | price | Current trade SL price |
| `NNFXLP_TP` | EA → Panel | double | price | Current trade TP price |

### Communication Protocol

**Panel writes a command:**
1. User clicks a button.
2. `OnChartEvent` fires with `CHARTEVENT_OBJECT_CLICK`.
3. Panel calls `GlobalVariableSet("NNFXLP_CMD", commandValue)`.
4. Panel un-depresses the button: `ObjectSetInteger(0, btnName, OBJPROP_STATE, false)`.

**EA reads and clears the command:**
1. On each `OnTimer` tick, EA reads `GlobalVariableGet("NNFXLP_CMD")`.
2. If value != 0, EA processes the command.
3. EA immediately clears: `GlobalVariableSet("NNFXLP_CMD", 0)`.

**EA updates state/stats:**
1. After processing each bar, EA writes all `NNFXLP_*` state and stats variables.

**Panel reads state/stats:**
1. On its own 500ms timer, Panel reads all `NNFXLP_*` variables and updates HUD labels.

---

## 12. State Machine

### States

| State | Value | Description |
|---|---|---|
| STOPPED | 0 | Initial state and end state. No bars feeding. CSV flushed on transition to STOPPED. |
| PLAYING | 1 | Bars feeding at current speed. Timer running. |
| PAUSED | 2 | Timer running but bars not advancing. Waiting for PLAY, STEP, or STOP. |

### Transitions

```
           ┌──────────────────────────────────┐
           │                                  │
     ┌─────▼─────┐    PLAY      ┌────────────┴──┐
     │  STOPPED   │─────────────►│   PLAYING     │
     │  (0)       │◄─────────────│   (1)         │
     └─────▲─────┘    STOP      └───┬────────┬──┘
           │                        │        │
           │         STOP      PAUSE│        │auto-complete
           │    ┌────────────┐      │        │(last bar reached)
           └────┤  PAUSED    │◄─────┘        │
                │  (2)       │               │
                └─────┬──────┘               │
                      │  PLAY                │
                      │  or STEP             │
                      └──────────────────────┘
```

### Transition Details

| From | Trigger | To | Side Effects |
|---|---|---|---|
| STOPPED | CMD=PLAY | PLAYING | Begin bar feeding from cursor position (cursor resets to TestStartDate on each EA OnInit — STOP does not reset cursor, only re-attaching the EA resets it) |
| PLAYING | CMD=PAUSE | PAUSED | Stop bar advancement, keep timer alive |
| PLAYING | CMD=STOP | STOPPED | Flush CSV, clean up visuals. Cursor position is NOT reset — re-attach EA to start fresh. |
| PLAYING | Last bar reached | STOPPED | Flush CSV, print completion message |
| PAUSED | CMD=PLAY | PLAYING | Resume bar feeding |
| PAUSED | CMD=STEP | PLAYING then PAUSED | Feed exactly one bar, process it, then immediately re-pause |
| PAUSED | CMD=STOP | STOPPED | Flush CSV, clean up |
| Any | CMD=FASTER | Same | Increase speed (max 5), reset timer |
| Any | CMD=SLOWER | Same | Decrease speed (min 1), reset timer |

---

## 13. Stats and CSV Export

### Running Stats Accumulator

Updated after every trade close via `ST_RecordTrade()`:

| Metric | Formula |
|---|---|
| totalTrades | Incremented on each close |
| totalWins | Incremented when pips > 0 |
| totalLosses | Incremented when pips <= 0 |
| totalPipsWon | `+= pips` when pips > 0 |
| totalPipsLost | `+= MathAbs(pips)` when pips <= 0 |
| profitFactor | `totalPipsWon / totalPipsLost` (999.0 if totalPipsLost == 0, meaning all wins) |
| winRate | `totalWins / totalTrades * 100` |
| maxConsecWins | `MathMax(maxConsecWins, curConsecWins)` |
| maxConsecLosses | `MathMax(maxConsecLosses, curConsecLosses)` |
| peakBalance | `MathMax(peakBalance, currentBalance)` |
| troughBalance | Lowest balance since last peak |
| maxDrawdownPct | `(peakBalance - troughBalance) / peakBalance * 100` |

### CSV Output

**Directory:** `MQL4/Files/NNFXLitePro/<Symbol>_<IndicatorName>_<StartDate>_<EndDate>/`

Date format in directory name: `yyyyMMdd` (e.g., `EURUSD_SSL_Channel_20200101_20231231`).

If directory exists, append `_2`, `_3`, etc.

**trades.csv:**

| Column | Type | Example |
|---|---|---|
| Date | string (yyyy.MM.dd) | 2023.04.12 |
| Direction | string | BUY / SELL |
| EntryPrice | double (5 digits) | 1.08230 |
| SLPrice | double (5 digits) | 1.07400 |
| TPPrice | double (5 digits) | 1.09500 |
| ExitPrice | double (5 digits) | 1.09500 |
| CloseReason | string | TP / SL / REVERSE_BUY / REVERSE_SELL |
| Pips | double (1 digit) | 127.0 |
| Balance | double (2 digits) | 10254.00 |

**summary.csv:**

| Column | Type |
|---|---|
| Indicator | string |
| Symbol | string |
| StartDate | string (yyyy.MM.dd) |
| EndDate | string (yyyy.MM.dd) |
| TotalTrades | int |
| Wins | int |
| Losses | int |
| WinRate | double (1 digit, %) |
| TotalPipsWon | double (1 digit) |
| TotalPipsLost | double (1 digit) |
| ProfitFactor | double (2 digits) |
| MaxConsecWins | int |
| MaxConsecLosses | int |
| MaxDrawdownPct | double (1 digit, %) |
| StartBalance | double (2 digits) |
| FinalBalance | double (2 digits) |

---

## 14. Extern Inputs Reference

### NNFXLiteSetup.mq4 (Script)

| Name | Type | Default | Description |
|---|---|---|---|
| `SourceSymbol` | string | "EURUSD" | Base symbol for offline chart name |
| `ForceReset` | bool | false | Overwrite existing HST file if true |

### NNFXLitePro1.mq4 (Expert Advisor)

| Name | Type | Default | Description |
|---|---|---|---|
| **General** | | | |
| `SourceSymbol` | string | "EURUSD" | Real chart symbol to read OHLC from |
| `TestStartDate` | datetime | D'2020.01.01' | First bar of test range |
| `TestEndDate` | datetime | D'2023.12.31' | Last bar of test range |
| `StartingBalance` | double | 10000.0 | Initial simulated account balance |
| `DefaultSpeed` | int | 3 | Starting speed level (1-5) |
| **C1 Indicator** | | | |
| `C1_IndicatorName` | string | "" | Indicator filename (without .ex4) |
| `C1_Mode` | int | 0 | Signal mode: 0=TwoLine, 1=ZeroLine, 2=Histogram |
| `C1_FastBuffer` | int | 0 | Mode 0: fast line buffer index |
| `C1_SlowBuffer` | int | 1 | Mode 0: slow line buffer index |
| `C1_SignalBuffer` | int | 0 | Mode 1: signal line buffer index |
| `C1_CrossLevel` | double | 0.0 | Mode 1: cross level (0=zero cross, 50=RSI midline) |
| `C1_HistBuffer` | int | 0 | Mode 2: histogram buffer index |
| `C1_HistDualBuffer` | bool | false | Mode 2: true if separate buy/sell buffers |
| `C1_HistBuyBuffer` | int | 0 | Mode 2 dual: positive/buy buffer index |
| `C1_HistSellBuffer` | int | 1 | Mode 2 dual: negative/sell buffer index |
| `C1_ParamValues` | string | "" | CSV of indicator param values: "14,0.5,true" |
| `C1_ParamTypes` | string | "" | CSV of indicator param types: "int,double,bool" |
| **Money Management** | | | |
| `RiskPercent` | double | 0.02 | Risk per trade as decimal (0.02 = 2%) |
| `ATR_Period` | int | 14 | ATR calculation period |
| `ATR_SL_Multiplier` | double | 1.5 | SL distance = ATR * this value |
| `ATR_TP_Multiplier` | double | 1.0 | TP distance = ATR * this value |

### NNFXLitePanel.mq4 (Indicator)

No extern inputs. All configuration is handled by the EA and communicated via GlobalVariables.

---

## 15. Phase 1 Scope Boundary

### In Scope

| Feature | Status |
|---|---|
| C1 indicator testing with 3 signal modes (two-line, zero-line, histogram) | Included |
| Virtual trade engine with ATR-based SL/TP | Included |
| 2% risk per trade, compounding balance | Included |
| Maximum 1 open trade at a time | Included |
| Close and reverse on opposite signal | Included |
| Offline chart bar feeding via HST file | Included |
| Floating control panel with Play/Pause/Step/Stop/Speed | Included |
| HUD with date, bar count, balance, trade info, stats | Included |
| 5 speed levels (2000ms to 30ms per bar) | Included |
| Trades CSV export | Included |
| Summary CSV export with profit factor | Included |
| Simulated balance with correct compounding | Included |

### Explicitly Out of Scope (Phase 2+)

| Feature | Reason |
|---|---|
| Baseline indicator | Phase 2 |
| C2 confirmation indicator | Phase 2 |
| Volume indicator filter | Phase 2 |
| Exit indicator | Phase 2 |
| Multi-symbol batch testing | Phase 2 |
| Optimisation / parameter sweeping | Phase 2 |
| News filter | Phase 2 |
| Spread filter | Phase 2 |

---

## 16. Deployment and Usage Workflow

### First-Time Setup

1. Copy files to the correct MT4 directories:
   - `NNFXLiteSetup.mq4` → `MQL4/Scripts/`
   - `NNFXLitePro1.mq4` → `MQL4/Experts/`
   - `NNFXLitePanel.mq4` → `MQL4/Indicators/`
   - `Include/NNFXLite/*.mqh` → `MQL4/Include/NNFXLite/`
2. Compile all three MQL4 files in MetaEditor.
3. In MT4, open any chart and run the `NNFXLiteSetup` script (drag from Navigator > Scripts).
4. After script completes, go to File > Open Offline > select `EURUSD_SIM, D1` > Open.
5. Drag `NNFXLitePanel` indicator onto the offline chart from Navigator > Indicators.
6. Open a real `EURUSD D1` chart.
7. Drag `NNFXLitePro1` EA onto the real chart. Configure extern inputs (indicator name, mode, params, date range).
8. Click PLAY on the panel.

### Subsequent Sessions

Steps 3 is skipped (setup already done). Start from step 4 if the offline chart was closed, or from step 6 if it is still open.

### Running a Test

1. Attach EA with desired C1 indicator configuration.
2. Click PLAY. Bars begin feeding at the configured speed.
3. Use FASTER/SLOWER to adjust speed. Use PAUSE to freeze, STEP to advance one bar.
4. Watch the offline chart for entry arrows, SL/TP lines, and result labels.
5. Monitor the HUD for running balance, win rate, and profit factor.
6. Click STOP when done (or let it auto-complete). CSV files are written to `MQL4/Files/NNFXLitePro/`.

### Testing a Different Indicator

1. Remove the EA from the real chart (right-click > Expert Advisors > Remove).
2. Re-attach with new C1 indicator settings.
3. Click PLAY. The HST file is reset on each EA init, so previous bars are cleared.

---

*End of specification.*

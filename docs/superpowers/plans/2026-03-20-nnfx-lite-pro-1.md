# NNFX Lite Pro 1 — Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a complete MT4 offline-chart backtesting simulator for NNFX C1 indicator testing with virtual trade execution, floating control panel, and CSV stats export.

**Architecture:** Three-component system: Setup Script (one-time offline symbol creation), Main EA (real chart, bar feeder + signal engine + virtual trade engine + stats), Panel Indicator (offline chart, floating control panel + HUD). Communication via GlobalVariables. No real OrderSend — all trades simulated in memory.

**Tech Stack:** MQL4, MT4 Terminal, MetaEditor compiler, offline HST chart mechanism, GlobalVariables IPC

---

## File Structure

```
backtester/bridge/mt4_runner/NNFXLitePro1/
├── NNFXLitePro1.mq4              # Main EA (attaches to real chart)
├── NNFXLiteSetup.mq4             # One-time setup script
├── NNFXLitePanel.mq4             # Panel indicator (attaches to offline chart)
└── include/
    └── NNFXLite/
        ├── global_vars.mqh       # GlobalVariable name constants + read/write helpers
        ├── bar_feeder.mqh        # HST file writing, chart refresh, speed control
        ├── signal_engine.mqh     # 3 C1 signal modes + typed param dispatch
        ├── trade_engine.mqh      # Virtual trade state, ATR sizing, visual objects
        ├── stats_engine.mqh      # Running accumulators (wins/losses/PF/drawdown)
        └── csv_exporter.mqh      # trades.csv + summary.csv writer
```

**MT4 deployment paths** (files are copied here by `deploy_nnfxlitepro.bat`):
- `MQL4/Experts/NNFXLitePro/NNFXLitePro1.mq4`
- `MQL4/Scripts/NNFXLitePro/NNFXLiteSetup.mq4`
- `MQL4/Indicators/NNFXLitePro/NNFXLitePanel.mq4`
- `MQL4/Include/NNFXLite/*.mqh`

**MT4 data path:** `C:\Users\win10pro\AppData\Roaming\MetaQuotes\Terminal\98A82F92176B73A2100FCD1F8ABD7255`

**Project repo path:** `C:\Users\win10pro\OneDrive\Desktop\claude code project\backtester\bridge\mt4_runner\NNFXLitePro1\`

---

## Task 1: Project Scaffold + global_vars.mqh

**Goal:** Create the folder structure, write `global_vars.mqh` with all GlobalVariable constants and helpers, and create a minimal `NNFXLitePro1.mq4` that compiles cleanly.

**Files:**
- `NNFXLitePro1/include/NNFXLite/global_vars.mqh` (new)
- `NNFXLitePro1/NNFXLitePro1.mq4` (new — minimal stub)
- `NNFXLitePro1/NNFXLiteSetup.mq4` (new — empty stub)
- `NNFXLitePro1/NNFXLitePanel.mq4` (new — empty stub)

**Steps:**

- [ ] 1. Create the project folder structure:
  ```
  backtester/bridge/mt4_runner/NNFXLitePro1/
  backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/
  ```

- [ ] 2. Write `NNFXLitePro1/include/NNFXLite/global_vars.mqh` with the complete GlobalVariable bridge:

```cpp
//+------------------------------------------------------------------+
//| global_vars.mqh — GlobalVariable name constants + helpers        |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_GLOBAL_VARS_MQH
#define NNFXLITE_GLOBAL_VARS_MQH

//+------------------------------------------------------------------+
//| GlobalVariable name constants — Panel <-> EA communication
//+------------------------------------------------------------------+
#define NNFXLP_CMD        "NNFXLP_CMD"       // Panel->EA: command
#define NNFXLP_STATE      "NNFXLP_STATE"     // EA->Panel: state
#define NNFXLP_SPEED      "NNFXLP_SPEED"     // EA->Panel: speed level 1-5
#define NNFXLP_BAR_CUR    "NNFXLP_BAR_CUR"  // EA->Panel: current bar number
#define NNFXLP_BAR_TOT    "NNFXLP_BAR_TOT"  // EA->Panel: total bars
#define NNFXLP_DATE       "NNFXLP_DATE"      // EA->Panel: current bar datetime
#define NNFXLP_BAL        "NNFXLP_BAL"       // EA->Panel: simulated balance
#define NNFXLP_WINS       "NNFXLP_WINS"      // EA->Panel: win count
#define NNFXLP_LOSSES     "NNFXLP_LOSSES"    // EA->Panel: loss count
#define NNFXLP_PF         "NNFXLP_PF"        // EA->Panel: profit factor
#define NNFXLP_TRADE      "NNFXLP_TRADE"     // EA->Panel: 0=none,1=long,-1=short
#define NNFXLP_ENTRY      "NNFXLP_ENTRY"     // EA->Panel: entry price
#define NNFXLP_SL         "NNFXLP_SL"        // EA->Panel: SL price
#define NNFXLP_TP         "NNFXLP_TP"        // EA->Panel: TP price

//+------------------------------------------------------------------+
//| State constants
//+------------------------------------------------------------------+
#define NNFXLP_STATE_STOPPED   0
#define NNFXLP_STATE_PLAYING   1
#define NNFXLP_STATE_PAUSED    2

//+------------------------------------------------------------------+
//| Command constants
//+------------------------------------------------------------------+
#define NNFXLP_CMD_NONE    0
#define NNFXLP_CMD_PLAY    1
#define NNFXLP_CMD_PAUSE   2
#define NNFXLP_CMD_STEP    3
#define NNFXLP_CMD_FASTER  4
#define NNFXLP_CMD_SLOWER  5
#define NNFXLP_CMD_STOP    6

//+------------------------------------------------------------------+
//| Speed levels — timer intervals in milliseconds
//+------------------------------------------------------------------+
int GV_SpeedIntervals[5] = {2000, 800, 300, 100, 30};

//+------------------------------------------------------------------+
//| GV helper functions
//+------------------------------------------------------------------+
void GV_SetInt(string name, int value)
{
    GlobalVariableSet(name, (double)value);
}

int GV_GetInt(string name)
{
    if(!GlobalVariableCheck(name)) return 0;
    return (int)GlobalVariableGet(name);
}

void GV_SetDouble(string name, double value)
{
    GlobalVariableSet(name, value);
}

double GV_GetDouble(string name)
{
    if(!GlobalVariableCheck(name)) return 0.0;
    return GlobalVariableGet(name);
}

//+------------------------------------------------------------------+
//| Delete all GlobalVariables with prefix "NNFXLP_"
//+------------------------------------------------------------------+
void GV_DeleteAll()
{
    int total = GlobalVariablesTotal();
    // Iterate backward because deletion changes indices
    for(int i = total - 1; i >= 0; i--)
    {
        string name = GlobalVariableName(i);
        if(StringFind(name, "NNFXLP_") == 0)
            GlobalVariableDel(name);
    }
}

//+------------------------------------------------------------------+
//| Initialize all GlobalVariables to default values
//+------------------------------------------------------------------+
void GV_InitAll(double startBalance, int totalBars, int defaultSpeed)
{
    GV_SetInt(NNFXLP_CMD,      NNFXLP_CMD_NONE);
    GV_SetInt(NNFXLP_STATE,    NNFXLP_STATE_STOPPED);
    GV_SetInt(NNFXLP_SPEED,    defaultSpeed);
    GV_SetInt(NNFXLP_BAR_CUR,  0);
    GV_SetInt(NNFXLP_BAR_TOT,  totalBars);
    GV_SetDouble(NNFXLP_DATE,  0.0);
    GV_SetDouble(NNFXLP_BAL,   startBalance);
    GV_SetInt(NNFXLP_WINS,     0);
    GV_SetInt(NNFXLP_LOSSES,   0);
    GV_SetDouble(NNFXLP_PF,    0.0);
    GV_SetInt(NNFXLP_TRADE,    0);
    GV_SetDouble(NNFXLP_ENTRY, 0.0);
    GV_SetDouble(NNFXLP_SL,    0.0);
    GV_SetDouble(NNFXLP_TP,    0.0);
}

#endif // NNFXLITE_GLOBAL_VARS_MQH
```

- [ ] 3. Write `NNFXLitePro1/NNFXLitePro1.mq4` — minimal EA stub:

```cpp
//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — Main EA (attaches to real chart)             |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict

#include <NNFXLite/global_vars.mqh>

//+------------------------------------------------------------------+
//| Extern inputs
//+------------------------------------------------------------------+
extern string   SourceSymbol      = "EURUSD";
extern string   SimSymbol         = "EURUSD_SIM";
extern datetime TestStartDate     = D'2021.01.01';
extern datetime TestEndDate       = D'2023.12.31';
extern double   StartingBalance   = 10000.0;
extern int      DefaultSpeed      = 3;
extern double   RiskPercent       = 0.02;
extern int      ATR_Period        = 14;
extern double   ATR_SL_Multiplier = 1.5;
extern double   ATR_TP_Multiplier = 1.0;
extern string   C1_IndicatorName  = "";
extern int      C1_Mode           = 0;
extern int      C1_FastBuffer     = 0;
extern int      C1_SlowBuffer     = 1;
extern int      C1_SignalBuffer   = 0;
extern double   C1_CrossLevel     = 0.0;
extern int      C1_HistBuffer     = 0;
extern bool     C1_HistDualBuffer = false;
extern int      C1_HistBuyBuffer  = 0;
extern int      C1_HistSellBuffer = 1;
extern string   C1_ParamValues    = "";
extern string   C1_ParamTypes     = "";

//+------------------------------------------------------------------+
int OnInit()
{
    Print("[NNFXLitePro1] EA initialized (stub). Source=", SourceSymbol,
          " Sim=", SimSymbol);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("[NNFXLitePro1] EA deinitialized.");
}

//+------------------------------------------------------------------+
void OnTick()
{
    // Timer-driven, not tick-driven. OnTick left empty intentionally.
}

//+------------------------------------------------------------------+
void OnTimer()
{
    // Main loop — wired in Task 9.
}
```

- [ ] 4. Write `NNFXLitePro1/NNFXLiteSetup.mq4` — minimal script stub:

```cpp
//+------------------------------------------------------------------+
//| NNFXLiteSetup.mq4 — Offline symbol creator (script)             |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict
#property show_inputs

extern string SourceSymbol = "EURUSD";
extern bool   ForceReset   = false;

//+------------------------------------------------------------------+
void OnStart()
{
    Print("[NNFXLiteSetup] Script started (stub). Source=", SourceSymbol);
}
```

- [ ] 5. Write `NNFXLitePro1/NNFXLitePanel.mq4` — minimal indicator stub:

```cpp
//+------------------------------------------------------------------+
//| NNFXLitePanel.mq4 — Control panel + HUD indicator               |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

#include <NNFXLite/global_vars.mqh>

//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorShortName("NNFXLitePanel");
    Print("[NNFXLitePanel] Indicator initialized (stub).");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("[NNFXLitePanel] Indicator deinitialized.");
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    return rates_total;
}
```

- [ ] 6. Create empty stub include files to complete the folder structure (each with just `#property strict` and include guard):
  - `NNFXLitePro1/include/NNFXLite/bar_feeder.mqh`
  - `NNFXLitePro1/include/NNFXLite/signal_engine.mqh`
  - `NNFXLitePro1/include/NNFXLite/trade_engine.mqh`
  - `NNFXLitePro1/include/NNFXLite/stats_engine.mqh`
  - `NNFXLitePro1/include/NNFXLite/csv_exporter.mqh`

  Each stub follows this pattern:
  ```cpp
  //+------------------------------------------------------------------+
  //| <filename> — <description>                                       |
  //| NNFX Lite Pro 1                                                   |
  //+------------------------------------------------------------------+
  #ifndef NNFXLITE_<GUARD>_MQH
  #define NNFXLITE_<GUARD>_MQH

  // Implemented in Task N

  #endif
  ```

- [ ] 7. Copy files to MT4 paths using `deploy_nnfxlitepro.bat` (written in Task 10, or copy manually for now):
  ```
  xcopy /Y NNFXLitePro1\NNFXLitePro1.mq4  "%MT4%\MQL4\Experts\NNFXLitePro\"
  xcopy /Y NNFXLitePro1\NNFXLiteSetup.mq4  "%MT4%\MQL4\Scripts\NNFXLitePro\"
  xcopy /Y NNFXLitePro1\NNFXLitePanel.mq4  "%MT4%\MQL4\Indicators\NNFXLitePro\"
  xcopy /Y /S NNFXLitePro1\include\NNFXLite\*  "%MT4%\MQL4\Include\NNFXLite\"
  ```
  Where `%MT4%` = `C:\Users\win10pro\AppData\Roaming\MetaQuotes\Terminal\98A82F92176B73A2100FCD1F8ABD7255`

**Verification:**
- [ ] 8. Open MetaEditor (F4 in MT4). Open `NNFXLitePro1.mq4`, press F7 — expect 0 errors, 0 warnings.
- [ ] 9. Open `NNFXLiteSetup.mq4`, press F7 — expect 0 errors, 0 warnings.
- [ ] 10. Open `NNFXLitePanel.mq4`, press F7 — expect 0 errors, 0 warnings.
- [ ] 11. Attach `NNFXLitePro1` to any chart. Check Experts log for `[NNFXLitePro1] EA initialized (stub)`.

**Commit:**
- [ ] 12. `git add backtester/bridge/mt4_runner/NNFXLitePro1/ && git commit -m "Add NNFXLitePro1 project scaffold with global_vars.mqh and stubs"`

---

## Task 2: NNFXLiteSetup.mq4 — Offline Symbol Creator

**Goal:** Write the one-time setup script that creates a valid MT4 HST v401 file for the offline symbol so the user can open it via File > Open Offline.

**Files:**
- `NNFXLitePro1/NNFXLiteSetup.mq4` (replace stub)

**Steps:**

- [ ] 1. Replace the stub `NNFXLiteSetup.mq4` with the full implementation:

```cpp
//+------------------------------------------------------------------+
//| NNFXLiteSetup.mq4 — Offline symbol HST creator (script)         |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict
#property show_inputs

extern string SourceSymbol = "EURUSD";
extern bool   ForceReset   = false;

//+------------------------------------------------------------------+
void OnStart()
{
    string simSymbol  = SourceSymbol + "_SIM";
    string hstFile    = simSymbol + "1440.hst";
    int    period     = 1440;  // D1
    int    digits     = (int)MarketInfo(SourceSymbol, MODE_DIGITS);

    Print("[NNFXLiteSetup] Creating offline symbol: ", simSymbol,
          " Period=D1 Digits=", digits);

    //--- Check if HST file already exists using FileOpenHistory READ mode
    int checkHandle = FileOpenHistory(hstFile, FILE_BIN | FILE_READ);
    if(checkHandle >= 0)
    {
        FileClose(checkHandle);
        if(!ForceReset)
        {
            Print("[NNFXLiteSetup] WARNING: ", hstFile,
                  " already exists. Set ForceReset=true to overwrite.");
            Print("[NNFXLiteSetup] Skipping creation. Existing file is intact.");
            PrintInstructions(simSymbol);
            return;
        }
        Print("[NNFXLiteSetup] ForceReset=true — overwriting existing file.");
    }

    //--- Create the HST file with v401 header
    int handle = FileOpenHistory(hstFile, FILE_BIN | FILE_WRITE);
    if(handle < 0)
    {
        Print("[NNFXLiteSetup] ERROR: Failed to create ", hstFile,
              " Error=", GetLastError());
        return;
    }

    //--- Write 148-byte HST v401 header

    // version (4 bytes)
    FileWriteInteger(handle, 401, LONG_VALUE);

    // copyright (64 bytes) — null-padded string
    string copyright = "NNFXLitePro1";
    uchar copyrightBytes[64];
    ArrayInitialize(copyrightBytes, 0);
    int copyLen = StringToCharArray(copyright, copyrightBytes, 0,
                                     MathMin(StringLen(copyright), 63));
    // Ensure null terminator and pad to 64 bytes
    for(int i = 0; i < 64; i++)
        FileWriteInteger(handle, copyrightBytes[i], CHAR_VALUE);

    // symbol (12 bytes) — null-padded string
    uchar symbolBytes[12];
    ArrayInitialize(symbolBytes, 0);
    int symLen = StringToCharArray(simSymbol, symbolBytes, 0,
                                    MathMin(StringLen(simSymbol), 11));
    for(int i = 0; i < 12; i++)
        FileWriteInteger(handle, symbolBytes[i], CHAR_VALUE);

    // period (4 bytes)
    FileWriteInteger(handle, period, LONG_VALUE);

    // digits (4 bytes)
    FileWriteInteger(handle, digits, LONG_VALUE);

    // timesign (4 bytes)
    FileWriteInteger(handle, 0, LONG_VALUE);

    // last_sync (4 bytes)
    FileWriteInteger(handle, 0, LONG_VALUE);

    // unused (13 x 4 = 52 bytes)
    for(int i = 0; i < 13; i++)
        FileWriteInteger(handle, 0, LONG_VALUE);

    FileFlush(handle);
    FileClose(handle);

    int fileSize = 148; // header only, 0 bars
    Print("[NNFXLiteSetup] Created ", hstFile, " successfully (",
          fileSize, " bytes header, 0 bars).");

    PrintInstructions(simSymbol);
}

//+------------------------------------------------------------------+
void PrintInstructions(string simSymbol)
{
    Print("[NNFXLiteSetup] ========================================");
    Print("[NNFXLiteSetup] NEXT STEPS:");
    Print("[NNFXLiteSetup]   1. In MT4: File > Open Offline > select ",
          simSymbol, ", D1 > Open");
    Print("[NNFXLiteSetup]   2. Attach NNFXLitePanel indicator to the offline chart");
    Print("[NNFXLiteSetup]   3. Open your real ", StringSubstr(simSymbol, 0,
          StringLen(simSymbol) - 4), " D1 chart");
    Print("[NNFXLiteSetup]   4. Attach NNFXLitePro1 EA to the real chart");
    Print("[NNFXLiteSetup] ========================================");
}
```

**Verification:**
- [ ] 2. Compile `NNFXLiteSetup.mq4` in MetaEditor — expect 0 errors, 0 warnings.
- [ ] 3. Open any chart in MT4. Drag `NNFXLiteSetup` from Navigator > Scripts. Accept defaults (SourceSymbol=EURUSD).
- [ ] 4. Check Experts log for `"Created EURUSD_SIM1440.hst successfully"`.
- [ ] 5. In MT4: File > Open Offline — verify `EURUSD_SIM, D1` appears in the list.
- [ ] 6. Open the offline chart — it should show an empty chart (no bars yet).

**Commit:**
- [ ] 7. `git add backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLiteSetup.mq4 && git commit -m "Add NNFXLiteSetup script to create offline HST v401 file"`

---

## Task 3: bar_feeder.mqh — HST Bar Writing + Chart Discovery

**Goal:** Write the bar feeder module that reads OHLC from the real chart, appends 60-byte records to the offline HST file, and refreshes the offline chart. Includes chart discovery and speed control.

**Files:**
- `NNFXLitePro1/include/NNFXLite/bar_feeder.mqh` (replace stub)

**Steps:**

- [ ] 1. Write `bar_feeder.mqh` with the complete bar feeding logic:

```cpp
//+------------------------------------------------------------------+
//| bar_feeder.mqh — HST bar writing + offline chart refresh         |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_BAR_FEEDER_MQH
#define NNFXLITE_BAR_FEEDER_MQH

#include <NNFXLite/global_vars.mqh>

//+------------------------------------------------------------------+
//| Bar feeder state
//+------------------------------------------------------------------+
string   BF_simSymbol;        // e.g. "EURUSD_SIM"
string   BF_realSymbol;       // e.g. "EURUSD"
long     BF_offlineChartId;   // chart ID of the offline chart
int      BF_cursorIndex;      // current shift on real chart (high=old, counting down)
int      BF_endBarIndex;      // end shift (lowest shift = newest bar in range)
int      BF_totalBars;        // total bars in test range
int      BF_barsFed;          // bars fed so far
int      BF_speedLevel;       // 1-5
int      BF_speedMs;          // current timer interval in ms
string   BF_hstFilename;      // just the filename for FileOpenHistory

//+------------------------------------------------------------------+
//| Discover the offline chart by scanning all open charts
//| Looks for a chart with simSymbol and NNFXLitePanel indicator
//| Returns chart ID or -1 if not found
//+------------------------------------------------------------------+
long BF_FindOfflineChart(string simSymbol)
{
    long chartId = ChartFirst();
    while(chartId >= 0)
    {
        if(ChartSymbol(chartId) == simSymbol &&
           ChartPeriod(chartId) == PERIOD_D1)
        {
            // Verify NNFXLitePanel is attached
            int indicatorCount = ChartIndicatorsTotal(chartId, 0);
            for(int i = 0; i < indicatorCount; i++)
            {
                string indName = ChartIndicatorName(chartId, 0, i);
                if(indName == "NNFXLitePanel")
                {
                    Print("[BF] Found offline chart ID=", chartId,
                          " with NNFXLitePanel attached");
                    return chartId;
                }
            }
            // If no NNFXLitePanel found on this chart, still keep searching
            Print("[BF] Found chart for ", simSymbol,
                  " but NNFXLitePanel not attached. Skipping.");
        }
        chartId = ChartNext(chartId);
    }
    return -1;
}

//+------------------------------------------------------------------+
//| Initialize bar feeder
//| Returns true if offline chart found and HST header written
//+------------------------------------------------------------------+
bool BF_Init(string realSymbol, string simSymbol,
             datetime startDate, datetime endDate, int defaultSpeed)
{
    BF_realSymbol     = realSymbol;
    BF_simSymbol      = simSymbol;
    BF_hstFilename    = simSymbol + "1440.hst";
    BF_barsFed        = 0;

    //--- Find the offline chart
    BF_offlineChartId = BF_FindOfflineChart(simSymbol);
    if(BF_offlineChartId < 0)
    {
        Print("[BF] ERROR: Offline chart not found for ", simSymbol,
              ". Run NNFXLiteSetup first, open the offline chart, ",
              "and attach NNFXLitePanel.");
        return false;
    }

    //--- Calculate bar indices using iBarShift on the real symbol
    //    Higher shift = older bar. startDate is older, so higher shift.
    int startShift = iBarShift(realSymbol, PERIOD_D1, startDate, false);
    int endShift   = iBarShift(realSymbol, PERIOD_D1, endDate, false);

    if(startShift < 0 || endShift < 0)
    {
        Print("[BF] ERROR: Could not find bar indices for date range. ",
              "Start=", TimeToStr(startDate), " End=", TimeToStr(endDate));
        return false;
    }

    // startShift should be > endShift (older bar has higher index)
    if(startShift <= endShift)
    {
        Print("[BF] ERROR: Start date must be before end date. ",
              "StartShift=", startShift, " EndShift=", endShift);
        return false;
    }

    BF_cursorIndex  = startShift;
    BF_endBarIndex  = endShift;
    BF_totalBars    = startShift - endShift + 1;

    Print("[BF] Date range: ", TimeToStr(startDate), " to ",
          TimeToStr(endDate));
    Print("[BF] Shift range: ", startShift, " down to ", endShift,
          " (", BF_totalBars, " bars)");

    //--- Set speed
    BF_SetSpeed(defaultSpeed);

    //--- Truncate HST file and rewrite header (clean start each run)
    if(!BF_RewriteHSTHeader())
    {
        Print("[BF] ERROR: Failed to rewrite HST header.");
        return false;
    }

    Print("[BF] Init complete. Ready to feed ", BF_totalBars, " bars.");
    return true;
}

//+------------------------------------------------------------------+
//| Truncate HST and write fresh 148-byte v401 header
//+------------------------------------------------------------------+
bool BF_RewriteHSTHeader()
{
    int handle = FileOpenHistory(BF_hstFilename, FILE_BIN | FILE_WRITE);
    if(handle < 0)
    {
        Print("[BF] ERROR: Cannot open HST file: ", BF_hstFilename,
              " Error=", GetLastError());
        return false;
    }

    int digits = (int)MarketInfo(BF_realSymbol, MODE_DIGITS);

    // version (4 bytes)
    FileWriteInteger(handle, 401, LONG_VALUE);

    // copyright (64 bytes)
    uchar copyrightBytes[64];
    ArrayInitialize(copyrightBytes, 0);
    string copyright = "NNFXLitePro1";
    StringToCharArray(copyright, copyrightBytes, 0,
                       MathMin(StringLen(copyright), 63));
    for(int i = 0; i < 64; i++)
        FileWriteInteger(handle, copyrightBytes[i], CHAR_VALUE);

    // symbol (12 bytes)
    uchar symbolBytes[12];
    ArrayInitialize(symbolBytes, 0);
    StringToCharArray(BF_simSymbol, symbolBytes, 0,
                       MathMin(StringLen(BF_simSymbol), 11));
    for(int i = 0; i < 12; i++)
        FileWriteInteger(handle, symbolBytes[i], CHAR_VALUE);

    // period (4 bytes)
    FileWriteInteger(handle, 1440, LONG_VALUE);

    // digits (4 bytes)
    FileWriteInteger(handle, digits, LONG_VALUE);

    // timesign (4 bytes)
    FileWriteInteger(handle, 0, LONG_VALUE);

    // last_sync (4 bytes)
    FileWriteInteger(handle, 0, LONG_VALUE);

    // unused (13 x 4 = 52 bytes)
    for(int i = 0; i < 13; i++)
        FileWriteInteger(handle, 0, LONG_VALUE);

    FileFlush(handle);
    FileClose(handle);
    return true;
}

//+------------------------------------------------------------------+
//| Feed the next bar from real chart to offline HST
//| Returns false when all bars have been fed (cursorIndex < endBarIndex)
//+------------------------------------------------------------------+
bool BF_FeedNextBar()
{
    if(BF_cursorIndex < BF_endBarIndex)
        return false;  // all bars fed

    //--- Read OHLC + volume from real chart at current cursor
    datetime barTime = iTime(BF_realSymbol, PERIOD_D1, BF_cursorIndex);
    double   barOpen  = iOpen(BF_realSymbol, PERIOD_D1, BF_cursorIndex);
    double   barHigh  = iHigh(BF_realSymbol, PERIOD_D1, BF_cursorIndex);
    double   barLow   = iLow(BF_realSymbol, PERIOD_D1, BF_cursorIndex);
    double   barClose = iClose(BF_realSymbol, PERIOD_D1, BF_cursorIndex);
    long     barVol   = iVolume(BF_realSymbol, PERIOD_D1, BF_cursorIndex);

    //--- Open HST file, seek to end, append 60-byte record
    int handle = FileOpenHistory(BF_hstFilename,
                                  FILE_BIN | FILE_WRITE | FILE_READ);
    if(handle < 0)
    {
        Print("[BF] ERROR: Cannot open HST for writing. Error=",
              GetLastError());
        return false;
    }

    FileSeek(handle, 0, SEEK_END);

    // Write 60-byte bar record (HST v401 format)
    FileWriteLong(handle, (long)barTime);    // time (8 bytes)
    FileWriteDouble(handle, barOpen);         // open (8 bytes)
    FileWriteDouble(handle, barHigh);         // high (8 bytes)
    FileWriteDouble(handle, barLow);          // low (8 bytes)
    FileWriteDouble(handle, barClose);        // close (8 bytes)
    FileWriteLong(handle, barVol);            // tick_volume (8 bytes)
    FileWriteInteger(handle, 0, LONG_VALUE);  // spread (4 bytes)
    FileWriteLong(handle, 0);                 // real_volume (8 bytes)

    FileFlush(handle);
    FileClose(handle);

    //--- Refresh the offline chart so it picks up the new bar
    ChartSetSymbolPeriod(BF_offlineChartId, BF_simSymbol, PERIOD_D1);

    BF_barsFed++;
    BF_cursorIndex--;  // move toward newer bars (lower shift)

    return true;
}

//+------------------------------------------------------------------+
//| Set speed level (1-5) and update timer interval
//+------------------------------------------------------------------+
void BF_SetSpeed(int level)
{
    if(level < 1) level = 1;
    if(level > 5) level = 5;
    BF_speedLevel = level;
    BF_speedMs    = GV_SpeedIntervals[level - 1];
}

//+------------------------------------------------------------------+
//| Accessors
//+------------------------------------------------------------------+
int BF_GetSpeedLevel()       { return BF_speedLevel; }
int BF_GetSpeedMs()          { return BF_speedMs; }
int BF_GetCurrentBarNum()    { return BF_barsFed; }
int BF_GetTotalBars()        { return BF_totalBars; }
long BF_GetOfflineChartId()  { return BF_offlineChartId; }

datetime BF_GetCurrentDate()
{
    // The last bar we fed was at cursorIndex+1 (since we decremented after feed)
    int lastFedShift = BF_cursorIndex + 1;
    if(lastFedShift > BF_cursorIndex + BF_barsFed) return 0;
    return iTime(BF_realSymbol, PERIOD_D1, lastFedShift);
}

#endif // NNFXLITE_BAR_FEEDER_MQH
```

- [ ] 2. Update `NNFXLitePro1.mq4` to include `bar_feeder.mqh` and call `BF_Init()` in `OnInit()` for testing:

  Add after the global_vars include:
  ```cpp
  #include <NNFXLite/bar_feeder.mqh>
  ```

  Add to `OnInit()` after the existing print:
  ```cpp
  if(!BF_Init(SourceSymbol, SimSymbol, TestStartDate, TestEndDate, DefaultSpeed))
  {
      Print("[NNFXLitePro1] INIT FAILED: bar feeder init failed.");
      return INIT_FAILED;
  }
  Print("[NNFXLitePro1] Bar feeder ready. Total bars=", BF_GetTotalBars(),
        " Speed=", BF_GetSpeedLevel(), " (", BF_GetSpeedMs(), "ms)");
  ```

- [ ] 3. Add a temporary test in `OnInit()` that feeds 5 bars and prints each to the Experts log (remove after verification):

  ```cpp
  // --- TEMP TEST: Feed 5 bars to verify bar_feeder works ---
  for(int i = 0; i < 5; i++)
  {
      if(!BF_FeedNextBar())
      {
          Print("[TEST] No more bars at iteration ", i);
          break;
      }
      Print("[TEST] Fed bar ", BF_GetCurrentBarNum(),
            " Date=", TimeToStr(BF_GetCurrentDate(), TIME_DATE),
            " Cursor=", BF_cursorIndex);
  }
  // --- END TEMP TEST ---
  ```

**Verification:**
- [ ] 4. Compile `NNFXLitePro1.mq4` in MetaEditor — expect 0 errors, 0 warnings.
- [ ] 5. Run `NNFXLiteSetup` to create the HST file. Open the offline chart. Attach `NNFXLitePanel` (stub). Open real EURUSD D1 chart. Attach `NNFXLitePro1`.
- [ ] 6. Check Experts log:
  - `[BF] Found offline chart ID=...`
  - `[BF] Date range: 2021.01.01 to 2023.12.31`
  - `[BF] Shift range: ... down to ... (N bars)`
  - `[TEST] Fed bar 1 Date=2021.01.04 ...`
  - `[TEST] Fed bar 2 Date=2021.01.05 ...` (dates should be in chronological order)
- [ ] 7. Check the offline chart — it should now show 5 bars.
- [ ] 8. Remove the temporary test code from `OnInit()`.

**Commit:**
- [ ] 9. `git add backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/bar_feeder.mqh backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4 && git commit -m "Add bar_feeder.mqh with HST writing, chart discovery, and speed control"`

---

## Task 4: signal_engine.mqh — 3 C1 Signal Modes

**Goal:** Write the signal engine with three C1 signal detection modes (two-line cross, zero-line cross, histogram) and typed parameter dispatch for iCustom calls.

**Files:**
- `NNFXLitePro1/include/NNFXLite/signal_engine.mqh` (replace stub)

**Steps:**

- [ ] 1. Write `signal_engine.mqh` with complete signal logic:

```cpp
//+------------------------------------------------------------------+
//| signal_engine.mqh — C1 signal detection with 3 modes             |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_SIGNAL_ENGINE_MQH
#define NNFXLITE_SIGNAL_ENGINE_MQH

//+------------------------------------------------------------------+
//| Signal mode constants
//+------------------------------------------------------------------+
#define SE_MODE_TWO_LINE   0
#define SE_MODE_ZERO_LINE  1
#define SE_MODE_HISTOGRAM  2

//+------------------------------------------------------------------+
//| Typed param constants
//+------------------------------------------------------------------+
#define SE_MAX_PARAMS 8
enum SE_PARAM_TYPE { SE_INT=0, SE_DOUBLE=1, SE_BOOL=2, SE_STRING=3 };

//+------------------------------------------------------------------+
//| Signal engine state
//+------------------------------------------------------------------+
string        g_SE_simSymbol;
string        g_SE_indName;
int           g_SE_mode;

// Mode 0 (Two-Line Cross)
int           g_SE_fastBuf;
int           g_SE_slowBuf;

// Mode 1 (Zero-Line Cross)
int           g_SE_signalBuf;
double        g_SE_crossLevel;

// Mode 2 (Histogram)
int           g_SE_histBuf;
bool          g_SE_histDual;
int           g_SE_histBuyBuf;
int           g_SE_histSellBuf;

// Typed params for iCustom
SE_PARAM_TYPE g_SE_paramTypes[SE_MAX_PARAMS];
double        g_SE_paramVals[SE_MAX_PARAMS];
string        g_SE_paramStrs[SE_MAX_PARAMS];
int           g_SE_paramCount;

//+------------------------------------------------------------------+
//| Initialize signal engine
//+------------------------------------------------------------------+
void SE_Init(string simSymbol, string indName, int mode,
             int fastBuf, int slowBuf,
             int signalBuf, double crossLevel,
             int histBuf, bool histDual, int histBuyBuf, int histSellBuf,
             string paramValues, string paramTypes)
{
    g_SE_simSymbol   = simSymbol;
    g_SE_indName     = indName;
    g_SE_mode        = mode;
    g_SE_fastBuf     = fastBuf;
    g_SE_slowBuf     = slowBuf;
    g_SE_signalBuf   = signalBuf;
    g_SE_crossLevel  = crossLevel;
    g_SE_histBuf     = histBuf;
    g_SE_histDual    = histDual;
    g_SE_histBuyBuf  = histBuyBuf;
    g_SE_histSellBuf = histSellBuf;
    g_SE_paramCount  = 0;

    // Initialize param arrays
    for(int i = 0; i < SE_MAX_PARAMS; i++)
    {
        g_SE_paramTypes[i] = SE_DOUBLE;
        g_SE_paramVals[i]  = 0.0;
        g_SE_paramStrs[i]  = "";
    }

    // Parse typed params from CSV strings
    if(paramValues != "" && paramTypes != "")
        SE_ParseParams(paramValues, paramTypes);

    Print("[SE] Init: indicator=", indName, " mode=", mode,
          " params=", g_SE_paramCount);
}

//+------------------------------------------------------------------+
//| Parse typed parameters from CSV strings
//+------------------------------------------------------------------+
bool SE_ParseParams(string valStr, string typeStr)
{
    string vals[];
    string types[];
    int vCount = StringSplit(valStr,  StringGetCharacter(",", 0), vals);
    int tCount = StringSplit(typeStr, StringGetCharacter(",", 0), types);

    if(vCount != tCount || vCount == 0 || vCount > SE_MAX_PARAMS)
    {
        Print("[SE] Param parse failed: count mismatch vals=",
              vCount, " types=", tCount);
        g_SE_paramCount = -1;
        return false;
    }

    for(int i = 0; i < vCount; i++)
    {
        StringTrimLeft(vals[i]);  StringTrimRight(vals[i]);
        StringTrimLeft(types[i]); StringTrimRight(types[i]);
        string typeToken = types[i];
        StringToLower(typeToken);

        if(typeToken == "int")
        {
            g_SE_paramTypes[i] = SE_INT;
            g_SE_paramVals[i]  = (double)StringToInteger(vals[i]);
        }
        else if(typeToken == "double")
        {
            g_SE_paramTypes[i] = SE_DOUBLE;
            g_SE_paramVals[i]  = StringToDouble(vals[i]);
        }
        else if(typeToken == "bool")
        {
            g_SE_paramTypes[i] = SE_BOOL;
            string bv = vals[i];
            StringToLower(bv);
            g_SE_paramVals[i] = (bv == "true" || bv == "1") ? 1.0 : 0.0;
        }
        else if(typeToken == "string")
        {
            g_SE_paramTypes[i] = SE_STRING;
            g_SE_paramStrs[i]  = vals[i];
            g_SE_paramVals[i]  = 0.0;
        }
        else
        {
            Print("[SE] Param parse failed: unknown type '", types[i],
                  "' at index ", i);
            g_SE_paramCount = -1;
            return false;
        }
    }

    g_SE_paramCount = vCount;
    Print("[SE] Parsed ", vCount, " params OK");
    return true;
}

//+------------------------------------------------------------------+
//| iCustom wrapper with typed param dispatch (switch on param count)
//| MQL4 requires positional args — no variadic calls possible
//+------------------------------------------------------------------+
double SE_IndCall(int bufferIndex, int shift)
{
    if(g_SE_indName == "")     return EMPTY_VALUE;
    if(g_SE_paramCount == -1)  return EMPTY_VALUE;

    string sym = g_SE_simSymbol;
    int    tf  = PERIOD_D1;
    string ind = g_SE_indName;
    int    buf = bufferIndex;
    int    sh  = shift;

    double v0 = (g_SE_paramCount > 0) ? g_SE_paramVals[0] : 0;
    double v1 = (g_SE_paramCount > 1) ? g_SE_paramVals[1] : 0;
    double v2 = (g_SE_paramCount > 2) ? g_SE_paramVals[2] : 0;
    double v3 = (g_SE_paramCount > 3) ? g_SE_paramVals[3] : 0;
    double v4 = (g_SE_paramCount > 4) ? g_SE_paramVals[4] : 0;
    double v5 = (g_SE_paramCount > 5) ? g_SE_paramVals[5] : 0;
    double v6 = (g_SE_paramCount > 6) ? g_SE_paramVals[6] : 0;
    double v7 = (g_SE_paramCount > 7) ? g_SE_paramVals[7] : 0;

    double result = EMPTY_VALUE;

    switch(g_SE_paramCount)
    {
        case 0: result = iCustom(sym, tf, ind,
                    buf, sh); break;
        case 1: result = iCustom(sym, tf, ind,
                    v0, buf, sh); break;
        case 2: result = iCustom(sym, tf, ind,
                    v0, v1, buf, sh); break;
        case 3: result = iCustom(sym, tf, ind,
                    v0, v1, v2, buf, sh); break;
        case 4: result = iCustom(sym, tf, ind,
                    v0, v1, v2, v3, buf, sh); break;
        case 5: result = iCustom(sym, tf, ind,
                    v0, v1, v2, v3, v4, buf, sh); break;
        case 6: result = iCustom(sym, tf, ind,
                    v0, v1, v2, v3, v4, v5, buf, sh); break;
        case 7: result = iCustom(sym, tf, ind,
                    v0, v1, v2, v3, v4, v5, v6, buf, sh); break;
        case 8: result = iCustom(sym, tf, ind,
                    v0, v1, v2, v3, v4, v5, v6, v7, buf, sh); break;
    }

    return result;
}

//+------------------------------------------------------------------+
//| Validate a buffer read — returns true if value is usable
//+------------------------------------------------------------------+
bool SE_IsValid(double val)
{
    if(val == EMPTY_VALUE)       return false;
    if(val >= DBL_MAX)           return false;
    if(!MathIsValidNumber(val))  return false;
    return true;
}

//+------------------------------------------------------------------+
//| Get signal: returns +1 (BUY), -1 (SELL), or 0 (no signal)
//| Reads from the offline symbol at shift 1 and 2
//+------------------------------------------------------------------+
int SE_GetSignal()
{
    if(g_SE_indName == "") return 0;

    switch(g_SE_mode)
    {
        case SE_MODE_TWO_LINE:   return SE_Signal_TwoLine();
        case SE_MODE_ZERO_LINE:  return SE_Signal_ZeroLine();
        case SE_MODE_HISTOGRAM:  return SE_Signal_Histogram();
        default:
            Print("[SE] ERROR: Unknown mode=", g_SE_mode);
            return 0;
    }
}

//+------------------------------------------------------------------+
//| Mode 0 — Two-Line Cross
//| BUY:  fast[2] <= slow[2] AND fast[1] > slow[1]
//| SELL: fast[2] >= slow[2] AND fast[1] < slow[1]
//+------------------------------------------------------------------+
int SE_Signal_TwoLine()
{
    double fast1 = SE_IndCall(g_SE_fastBuf, 1);
    double fast2 = SE_IndCall(g_SE_fastBuf, 2);
    double slow1 = SE_IndCall(g_SE_slowBuf, 1);
    double slow2 = SE_IndCall(g_SE_slowBuf, 2);

    if(!SE_IsValid(fast1) || !SE_IsValid(fast2) ||
       !SE_IsValid(slow1) || !SE_IsValid(slow2))
        return 0;

    // BUY: fast crossed above slow
    if(fast2 <= slow2 && fast1 > slow1)
        return +1;

    // SELL: fast crossed below slow
    if(fast2 >= slow2 && fast1 < slow1)
        return -1;

    return 0;
}

//+------------------------------------------------------------------+
//| Mode 1 — Zero-Line Cross (custom level)
//| BUY:  sig[2] <= level AND sig[1] > level
//| SELL: sig[2] >= level AND sig[1] < level
//+------------------------------------------------------------------+
int SE_Signal_ZeroLine()
{
    double sig1 = SE_IndCall(g_SE_signalBuf, 1);
    double sig2 = SE_IndCall(g_SE_signalBuf, 2);

    if(!SE_IsValid(sig1) || !SE_IsValid(sig2))
        return 0;

    double level = g_SE_crossLevel;

    if(sig2 <= level && sig1 > level)
        return +1;

    if(sig2 >= level && sig1 < level)
        return -1;

    return 0;
}

//+------------------------------------------------------------------+
//| Mode 2 — Histogram (single or dual buffer)
//+------------------------------------------------------------------+
int SE_Signal_Histogram()
{
    if(g_SE_histDual)
        return SE_Signal_HistogramDual();
    else
        return SE_Signal_HistogramSingle();
}

//+------------------------------------------------------------------+
//| Mode 2 (single) — Histogram zero cross
//| BUY:  hist[2] <= 0 AND hist[1] > 0
//| SELL: hist[2] >= 0 AND hist[1] < 0
//+------------------------------------------------------------------+
int SE_Signal_HistogramSingle()
{
    double hist1 = SE_IndCall(g_SE_histBuf, 1);
    double hist2 = SE_IndCall(g_SE_histBuf, 2);

    if(!SE_IsValid(hist1) || !SE_IsValid(hist2))
        return 0;

    if(hist2 <= 0 && hist1 > 0)
        return +1;

    if(hist2 >= 0 && hist1 < 0)
        return -1;

    return 0;
}

//+------------------------------------------------------------------+
//| Mode 2 (dual) — Separate buy/sell histogram buffers
//| BUY:  buyBuf[1] > 0 AND (buyBuf[2] == EMPTY_VALUE OR buyBuf[2] <= 0)
//| SELL: sellBuf[1] > 0 AND (sellBuf[2] == EMPTY_VALUE OR sellBuf[2] <= 0)
//+------------------------------------------------------------------+
int SE_Signal_HistogramDual()
{
    double buy1  = SE_IndCall(g_SE_histBuyBuf, 1);
    double buy2  = SE_IndCall(g_SE_histBuyBuf, 2);
    double sell1 = SE_IndCall(g_SE_histSellBuf, 1);
    double sell2 = SE_IndCall(g_SE_histSellBuf, 2);

    // For dual histogram, EMPTY_VALUE on shift 2 means "was not active"
    bool buy1Valid  = SE_IsValid(buy1) && buy1 > 0;
    bool buy2Empty  = (!SE_IsValid(buy2) || buy2 <= 0);
    bool sell1Valid = SE_IsValid(sell1) && sell1 > 0;
    bool sell2Empty = (!SE_IsValid(sell2) || sell2 <= 0);

    if(buy1Valid && buy2Empty)
        return +1;

    if(sell1Valid && sell2Empty)
        return -1;

    return 0;
}

#endif // NNFXLITE_SIGNAL_ENGINE_MQH
```

- [ ] 2. Add the include to `NNFXLitePro1.mq4`:
  ```cpp
  #include <NNFXLite/signal_engine.mqh>
  ```

- [ ] 3. Add `SE_Init()` call in `OnInit()` after `BF_Init()`:
  ```cpp
  SE_Init(SimSymbol, C1_IndicatorName, C1_Mode,
          C1_FastBuffer, C1_SlowBuffer,
          C1_SignalBuffer, C1_CrossLevel,
          C1_HistBuffer, C1_HistDualBuffer, C1_HistBuyBuffer, C1_HistSellBuffer,
          C1_ParamValues, C1_ParamTypes);
  ```

- [ ] 4. Add a temporary test loop in `OnInit()` that feeds 30 bars and calls `SE_GetSignal()` on each, printing the result (remove after verification):
  ```cpp
  // --- TEMP TEST: Feed 30 bars and check signals ---
  for(int i = 0; i < 30; i++)
  {
      if(!BF_FeedNextBar()) break;
      if(i < 2) continue; // need at least 2 bars for crossover detection
      int sig = SE_GetSignal();
      if(sig != 0)
          Print("[TEST] Bar ", i+1, " Signal=", (sig > 0 ? "BUY" : "SELL"));
  }
  // --- END TEMP TEST ---
  ```

**Verification:**
- [ ] 5. Compile — expect 0 errors, 0 warnings.
- [ ] 6. Attach EA with `C1_IndicatorName="MACD"`, `C1_Mode=0` (two-line cross), `C1_FastBuffer=0`, `C1_SlowBuffer=1`. Use default MACD params (ParamValues="12,26,9", ParamTypes="int,int,int").
- [ ] 7. Check Experts log: `[SE] Parsed 3 params OK` and BUY/SELL signals appearing at reasonable intervals.
- [ ] 8. Remove the temporary test code.

**Commit:**
- [ ] 9. `git add backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/signal_engine.mqh backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4 && git commit -m "Add signal_engine.mqh with 3 C1 modes and typed param dispatch"`

---

## Task 5: trade_engine.mqh — Virtual Trade State + ATR Sizing

**Goal:** Write the virtual trade engine that manages trade lifecycle (open/close), ATR-based SL/TP calculation, lot sizing, balance updates, and draws entry/exit visuals on the offline chart.

**Files:**
- `NNFXLitePro1/include/NNFXLite/trade_engine.mqh` (replace stub)

**Steps:**

- [ ] 1. Write `trade_engine.mqh` with complete virtual trade logic:

```cpp
//+------------------------------------------------------------------+
//| trade_engine.mqh — Virtual trade state + ATR sizing + visuals    |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_TRADE_ENGINE_MQH
#define NNFXLITE_TRADE_ENGINE_MQH

//+------------------------------------------------------------------+
//| Trade state
//+------------------------------------------------------------------+
bool     TE_isOpen;
int      TE_dir;            // +1 buy, -1 sell
datetime TE_entryBar;       // entry bar datetime
double   TE_entryPrice;
double   TE_slPrice;
double   TE_tpPrice;
double   TE_slPips;
double   TE_tpPips;
double   TE_lotSize;
double   TE_simBalance;     // current simulated balance

// Config
string   TE_sourceSymbol;   // real symbol for MarketInfo
string   TE_simSymbol;      // offline symbol for iATR/iClose
double   TE_atrSlMult;
double   TE_atrTpMult;
double   TE_riskPct;        // as decimal: 0.02 = 2%
int      TE_atrPeriod;
int      TE_tradeCount;     // increments on each trade for unique object names

//+------------------------------------------------------------------+
//| Initialize trade engine
//+------------------------------------------------------------------+
void TE_Init(string sourceSymbol, string simSymbol,
             double startBalance, double atrSlMult, double atrTpMult,
             double riskPct, int atrPeriod)
{
    TE_sourceSymbol = sourceSymbol;
    TE_simSymbol    = simSymbol;
    TE_simBalance   = startBalance;
    TE_atrSlMult    = atrSlMult;
    TE_atrTpMult    = atrTpMult;
    TE_riskPct      = riskPct;
    TE_atrPeriod    = atrPeriod;
    TE_isOpen       = false;
    TE_dir          = 0;
    TE_tradeCount   = 0;
    Print("[TE] Init: balance=", DoubleToStr(startBalance, 2),
          " ATR_SL=", atrSlMult, " ATR_TP=", atrTpMult,
          " Risk=", riskPct * 100, "%");
}

//+------------------------------------------------------------------+
//| Calculate ATR-based SL/TP prices
//| Returns true on success, fills slPrice/tpPrice/slPips/tpPips
//+------------------------------------------------------------------+
bool TE_CalcSLTP(int dir, double entryPrice,
                 double &slPrice, double &tpPrice,
                 double &slPips, double &tpPips)
{
    double atr = iATR(TE_simSymbol, PERIOD_D1, TE_atrPeriod, 1);
    if(atr <= 0 || !MathIsValidNumber(atr))
    {
        Print("[TE] WARNING: ATR invalid (", atr, "). Cannot calc SL/TP.");
        return false;
    }

    double slDist = atr * TE_atrSlMult;
    double tpDist = atr * TE_atrTpMult;
    double point  = MarketInfo(TE_sourceSymbol, MODE_POINT);
    if(point <= 0) point = 0.00001; // fallback for 5-digit broker

    if(dir == +1) // BUY
    {
        slPrice = entryPrice - slDist;
        tpPrice = entryPrice + tpDist;
    }
    else // SELL
    {
        slPrice = entryPrice + slDist;
        tpPrice = entryPrice - tpDist;
    }

    slPips = slDist / point;
    tpPips = tpDist / point;

    return true;
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage
//| lotSize = (balance * riskPct) / (slPips * pipValue)
//+------------------------------------------------------------------+
double TE_CalcLots(double slPips)
{
    double tickValue = MarketInfo(TE_sourceSymbol, MODE_TICKVALUE);
    double tickSize  = MarketInfo(TE_sourceSymbol, MODE_TICKSIZE);
    double point     = MarketInfo(TE_sourceSymbol, MODE_POINT);
    double minLot    = MarketInfo(TE_sourceSymbol, MODE_MINLOT);
    double maxLot    = MarketInfo(TE_sourceSymbol, MODE_MAXLOT);

    if(tickSize <= 0) tickSize = point;
    if(tickValue <= 0) tickValue = 1.0;
    if(minLot <= 0) minLot = 0.01;
    if(maxLot <= 0) maxLot = 100.0;

    // pipValue per 1.0 lot for 1 pip movement
    double pipValue = tickValue / tickSize * point;
    if(pipValue <= 0) pipValue = 1.0;

    double riskDollars = TE_simBalance * TE_riskPct;
    double lots = riskDollars / (slPips * pipValue);

    lots = NormalizeDouble(lots, 2);
    lots = MathMax(lots, minLot);
    lots = MathMin(lots, maxLot);

    return lots;
}

//+------------------------------------------------------------------+
//| Open a new virtual trade
//+------------------------------------------------------------------+
void TE_OpenTrade(int dir, long offlineChartId)
{
    double entryPrice = iClose(TE_simSymbol, PERIOD_D1, 1);
    datetime barTime  = iTime(TE_simSymbol, PERIOD_D1, 1);

    double slPrice, tpPrice, slPips, tpPips;
    if(!TE_CalcSLTP(dir, entryPrice, slPrice, tpPrice, slPips, tpPips))
    {
        Print("[TE] Cannot open trade — SL/TP calc failed.");
        return;
    }

    double lots = TE_CalcLots(slPips);

    TE_isOpen     = true;
    TE_dir        = dir;
    TE_entryBar   = barTime;
    TE_entryPrice = entryPrice;
    TE_slPrice    = slPrice;
    TE_tpPrice    = tpPrice;
    TE_slPips     = slPips;
    TE_tpPips     = tpPips;
    TE_lotSize    = lots;
    TE_tradeCount++;

    Print("[TE] OPEN ", (dir > 0 ? "BUY" : "SELL"),
          " #", TE_tradeCount,
          " Entry=", DoubleToStr(entryPrice, 5),
          " SL=", DoubleToStr(slPrice, 5),
          " TP=", DoubleToStr(tpPrice, 5),
          " Lots=", DoubleToStr(lots, 2));

    // Draw visuals on offline chart
    TE_DrawEntry(offlineChartId, barTime, entryPrice, slPrice, tpPrice, dir);
}

//+------------------------------------------------------------------+
//| Check for exit conditions. Returns pips result (0.0 = no exit)
//| closeReason is set to: "SL", "TP", "REVERSE_BUY", "REVERSE_SELL"
//+------------------------------------------------------------------+
double TE_CheckExit(int newSignal, string &closeReason, long offlineChartId)
{
    if(!TE_isOpen) return 0.0;

    double bar1High = iHigh(TE_simSymbol, PERIOD_D1, 1);
    double bar1Low  = iLow(TE_simSymbol, PERIOD_D1, 1);
    double point    = MarketInfo(TE_sourceSymbol, MODE_POINT);
    if(point <= 0) point = 0.00001;

    double exitPrice = 0.0;

    //--- Priority 1: Check SL
    if(TE_dir == +1 && bar1Low <= TE_slPrice)
    {
        exitPrice   = TE_slPrice;
        closeReason = "SL";
    }
    else if(TE_dir == -1 && bar1High >= TE_slPrice)
    {
        exitPrice   = TE_slPrice;
        closeReason = "SL";
    }

    //--- Priority 2: Check TP (only if SL not hit)
    if(exitPrice == 0.0)
    {
        if(TE_dir == +1 && bar1High >= TE_tpPrice)
        {
            exitPrice   = TE_tpPrice;
            closeReason = "TP";
        }
        else if(TE_dir == -1 && bar1Low <= TE_tpPrice)
        {
            exitPrice   = TE_tpPrice;
            closeReason = "TP";
        }
    }

    //--- Priority 3: Check opposite signal (only if neither SL nor TP hit)
    if(exitPrice == 0.0 && newSignal != 0 && newSignal != TE_dir)
    {
        exitPrice   = iClose(TE_simSymbol, PERIOD_D1, 1);
        closeReason = (newSignal > 0) ? "REVERSE_BUY" : "REVERSE_SELL";
    }

    //--- No exit
    if(exitPrice == 0.0) return 0.0;

    //--- Calculate pips result
    double pips = (exitPrice - TE_entryPrice) * TE_dir / point;

    //--- Calculate P&L and update balance
    double tickValue = MarketInfo(TE_sourceSymbol, MODE_TICKVALUE);
    double tickSize  = MarketInfo(TE_sourceSymbol, MODE_TICKSIZE);
    if(tickSize <= 0) tickSize = point;
    if(tickValue <= 0) tickValue = 1.0;
    double pipValuePerLot = tickValue / tickSize * point;
    double pnl = pips * pipValuePerLot * TE_lotSize;
    TE_simBalance += pnl;

    datetime closeBarTime = iTime(TE_simSymbol, PERIOD_D1, 1);

    Print("[TE] CLOSE ", (TE_dir > 0 ? "BUY" : "SELL"),
          " #", TE_tradeCount,
          " Reason=", closeReason,
          " Exit=", DoubleToStr(exitPrice, 5),
          " Pips=", DoubleToStr(pips, 1),
          " P&L=$", DoubleToStr(pnl, 2),
          " Balance=$", DoubleToStr(TE_simBalance, 2));

    // Draw close visuals
    TE_DrawClose(offlineChartId, closeBarTime, exitPrice, pips, TE_dir);

    // Reset trade state
    TE_isOpen = false;
    TE_dir    = 0;

    return pips;
}

//+------------------------------------------------------------------+
//| Draw entry arrow + SL/TP lines on offline chart
//+------------------------------------------------------------------+
void TE_DrawEntry(long chartId, datetime barTime,
                  double entryPrice, double slPrice, double tpPrice, int dir)
{
    string suffix = IntegerToString(TE_tradeCount);

    // Entry arrow
    string arrowName = "NNFXLP_ARROW_" + suffix;
    ObjectCreate(chartId, arrowName, OBJ_ARROW, 0, barTime, entryPrice);
    ObjectSetInteger(chartId, arrowName, OBJPROP_ARROWCODE,
                     (dir > 0) ? 233 : 234);
    ObjectSetInteger(chartId, arrowName, OBJPROP_COLOR,
                     (dir > 0) ? clrLime : clrRed);
    ObjectSetInteger(chartId, arrowName, OBJPROP_WIDTH, 2);

    // SL horizontal line
    string slName = "NNFXLP_SL";
    ObjectDelete(chartId, slName);
    ObjectCreate(chartId, slName, OBJ_HLINE, 0, 0, slPrice);
    ObjectSetInteger(chartId, slName, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(chartId, slName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(chartId, slName, OBJPROP_WIDTH, 1);

    // TP horizontal line
    string tpName = "NNFXLP_TP";
    ObjectDelete(chartId, tpName);
    ObjectCreate(chartId, tpName, OBJ_HLINE, 0, 0, tpPrice);
    ObjectSetInteger(chartId, tpName, OBJPROP_COLOR, clrLime);
    ObjectSetInteger(chartId, tpName, OBJPROP_STYLE, STYLE_DASH);
    ObjectSetInteger(chartId, tpName, OBJPROP_WIDTH, 1);

    ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| Draw close result: remove SL/TP lines, add result label
//+------------------------------------------------------------------+
void TE_DrawClose(long chartId, datetime closeBarTime,
                  double closePrice, double pips, int dir)
{
    // Remove SL/TP lines
    ObjectDelete(chartId, "NNFXLP_SL");
    ObjectDelete(chartId, "NNFXLP_TP");

    // Result text
    string suffix = IntegerToString(TE_tradeCount);
    string resName = "NNFXLP_RESULT_" + suffix;
    string resText = (pips >= 0 ? "+" : "") + DoubleToStr(pips, 0) + "p";
    color  resColor = (pips >= 0) ? clrLime : clrRed;

    ObjectCreate(chartId, resName, OBJ_TEXT, 0, closeBarTime, closePrice);
    ObjectSetString(chartId, resName, OBJPROP_TEXT, resText);
    ObjectSetString(chartId, resName, OBJPROP_FONT, "Consolas");
    ObjectSetInteger(chartId, resName, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(chartId, resName, OBJPROP_COLOR, resColor);

    ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| Clean up all trade visual objects from offline chart
//+------------------------------------------------------------------+
void TE_Cleanup(long chartId)
{
    // Delete all objects with NNFXLP_ prefix on the offline chart
    int total = ObjectsTotal(chartId);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(chartId, i);
        if(StringFind(name, "NNFXLP_ARROW_") == 0 ||
           StringFind(name, "NNFXLP_RESULT_") == 0 ||
           name == "NNFXLP_SL" || name == "NNFXLP_TP")
        {
            ObjectDelete(chartId, name);
        }
    }
    ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| Update GlobalVariables with current trade state
//+------------------------------------------------------------------+
void TE_UpdateGlobalVars()
{
    GV_SetInt(NNFXLP_TRADE, TE_isOpen ? TE_dir : 0);
    GV_SetDouble(NNFXLP_ENTRY, TE_isOpen ? TE_entryPrice : 0.0);
    GV_SetDouble(NNFXLP_SL,    TE_isOpen ? TE_slPrice : 0.0);
    GV_SetDouble(NNFXLP_TP,    TE_isOpen ? TE_tpPrice : 0.0);
    GV_SetDouble(NNFXLP_BAL,   TE_simBalance);
}

//+------------------------------------------------------------------+
//| Force-close an open trade at current market price
//| Used when the backtest is stopped or all bars are exhausted.
//| Returns pips result. Sets closeReason to "FORCE_CLOSE".
//+------------------------------------------------------------------+
double TE_ForceClose(string &closeReason, long offlineChartId)
{
    if(!TE_isOpen) return 0.0;

    double exitPrice = iClose(TE_simSymbol, PERIOD_D1, 0);
    double point     = MarketInfo(TE_sourceSymbol, MODE_POINT);
    if(point <= 0) point = 0.00001;

    //--- Calculate pips result
    double pips = (exitPrice - TE_entryPrice) * TE_dir / point;

    //--- Calculate P&L and update balance (same logic as TE_CheckExit)
    double tickValue = MarketInfo(TE_sourceSymbol, MODE_TICKVALUE);
    double tickSize  = MarketInfo(TE_sourceSymbol, MODE_TICKSIZE);
    if(tickSize <= 0) tickSize = point;
    if(tickValue <= 0) tickValue = 1.0;
    double pipValuePerLot = tickValue / tickSize * point;
    double pnl = pips * pipValuePerLot * TE_lotSize;
    TE_simBalance += pnl;

    closeReason = "FORCE_CLOSE";
    datetime closeBarTime = iTime(TE_simSymbol, PERIOD_D1, 0);

    Print("[TE] FORCE_CLOSE ", (TE_dir > 0 ? "BUY" : "SELL"),
          " #", TE_tradeCount,
          " Exit=", DoubleToStr(exitPrice, 5),
          " Pips=", DoubleToStr(pips, 1),
          " P&L=$", DoubleToStr(pnl, 2),
          " Balance=$", DoubleToStr(TE_simBalance, 2));

    // Draw close visuals
    TE_DrawClose(offlineChartId, closeBarTime, exitPrice, pips, TE_dir);

    // Reset trade state
    TE_isOpen = false;
    TE_dir    = 0;

    return pips;
}

#endif // NNFXLITE_TRADE_ENGINE_MQH
```

- [ ] 2. Add include to `NNFXLitePro1.mq4`:
  ```cpp
  #include <NNFXLite/trade_engine.mqh>
  ```

- [ ] 3. Add `TE_Init()` call in `OnInit()` after `SE_Init()`:
  ```cpp
  TE_Init(SourceSymbol, SimSymbol, StartingBalance,
          ATR_SL_Multiplier, ATR_TP_Multiplier, RiskPercent, ATR_Period);
  ```

- [ ] 4. Add a temporary test loop in `OnInit()` that feeds 30 bars, reads signals, and processes trades (remove after verification):
  ```cpp
  // --- TEMP TEST: 30 bars with trade engine ---
  long offId = BF_GetOfflineChartId();
  for(int i = 0; i < 30; i++)
  {
      if(!BF_FeedNextBar()) break;
      if(i < 2) continue;
      int sig = SE_GetSignal();

      if(TE_isOpen)
      {
          string reason = "";
          double pips = TE_CheckExit(sig, reason, offId);
          if(pips != 0.0)
          {
              // If reverse signal, open in new direction
              if(StringFind(reason, "REVERSE") == 0)
                  TE_OpenTrade((reason == "REVERSE_BUY" ? +1 : -1), offId);
          }
      }
      if(!TE_isOpen && sig != 0)
          TE_OpenTrade(sig, offId);
  }
  Print("[TEST] Final balance: $", DoubleToStr(TE_simBalance, 2));
  // --- END TEMP TEST ---
  ```

**Verification:**
- [ ] 5. Compile — expect 0 errors, 0 warnings.
- [ ] 6. Attach EA with MACD settings. Check Experts log for OPEN/CLOSE messages with correct prices and pips.
- [ ] 7. Check offline chart for entry arrows, SL/TP lines, and result labels.
- [ ] 8. Verify balance changes are reasonable (2% risk per trade).
- [ ] 9. Remove temporary test code.

**Commit:**
- [ ] 10. `git add backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/trade_engine.mqh backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4 && git commit -m "Add trade_engine.mqh with virtual trades, ATR SL/TP, and chart visuals"`

---

## Task 6: stats_engine.mqh — Running Accumulators

**Goal:** Write the stats engine that maintains running trade statistics: win/loss counts, profit factor, consecutive streaks, drawdown tracking.

**Files:**
- `NNFXLitePro1/include/NNFXLite/stats_engine.mqh` (replace stub)

**Steps:**

- [ ] 1. Write `stats_engine.mqh` with complete running statistics:

```cpp
//+------------------------------------------------------------------+
//| stats_engine.mqh — Running trade statistics accumulator          |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_STATS_ENGINE_MQH
#define NNFXLITE_STATS_ENGINE_MQH

#include <NNFXLite/global_vars.mqh>

//+------------------------------------------------------------------+
//| Stats state
//+------------------------------------------------------------------+
int    ST_totalTrades;
int    ST_wins;
int    ST_losses;
double ST_totalPipsWon;     // sum of winning pips
double ST_totalPipsLost;    // sum of losing pips (absolute)
double ST_profitFactor;     // totalPipsWon / totalPipsLost
double ST_winRate;          // wins/totalTrades * 100
int    ST_maxConsecWins;
int    ST_maxConsecLosses;
int    ST_curConsecWins;
int    ST_curConsecLosses;
double ST_peakBalance;
double ST_troughBalance;
double ST_maxDrawdownPct;
double ST_startBalance;
double ST_finalBalance;

//+------------------------------------------------------------------+
//| Initialize stats
//+------------------------------------------------------------------+
void ST_Init(double startBalance)
{
    ST_totalTrades    = 0;
    ST_wins           = 0;
    ST_losses         = 0;
    ST_totalPipsWon   = 0.0;
    ST_totalPipsLost  = 0.0;
    ST_profitFactor   = 0.0;
    ST_winRate        = 0.0;
    ST_maxConsecWins  = 0;
    ST_maxConsecLosses= 0;
    ST_curConsecWins  = 0;
    ST_curConsecLosses= 0;
    ST_peakBalance    = startBalance;
    ST_troughBalance  = startBalance;
    ST_maxDrawdownPct = 0.0;
    ST_startBalance   = startBalance;
    ST_finalBalance   = startBalance;

    Print("[ST] Init: startBalance=", DoubleToStr(startBalance, 2));
}

//+------------------------------------------------------------------+
//| Record a trade result — updates all running statistics
//| pips: positive = win, negative or zero = loss
//| newBalance: balance after this trade's P&L
//+------------------------------------------------------------------+
void ST_RecordTrade(double pips, double newBalance)
{
    ST_totalTrades++;
    ST_finalBalance = newBalance;

    if(pips > 0)
    {
        // Winner
        ST_wins++;
        ST_totalPipsWon += pips;
        ST_curConsecWins++;
        ST_curConsecLosses = 0;
        ST_maxConsecWins = MathMax(ST_maxConsecWins, ST_curConsecWins);
    }
    else
    {
        // Loser (pips <= 0)
        ST_losses++;
        ST_totalPipsLost += MathAbs(pips);
        ST_curConsecLosses++;
        ST_curConsecWins = 0;
        ST_maxConsecLosses = MathMax(ST_maxConsecLosses, ST_curConsecLosses);
    }

    // Update profit factor
    if(ST_totalPipsLost > 0)
        ST_profitFactor = ST_totalPipsWon / ST_totalPipsLost;
    else
        ST_profitFactor = 999.0;  // all wins, no losses

    // Update win rate
    if(ST_totalTrades > 0)
        ST_winRate = (double)ST_wins / (double)ST_totalTrades * 100.0;

    // Drawdown tracking
    if(newBalance > ST_peakBalance)
    {
        ST_peakBalance   = newBalance;
        ST_troughBalance = newBalance;  // reset trough on new peak
    }
    else if(newBalance < ST_troughBalance)
    {
        ST_troughBalance = newBalance;
        double ddPct = (ST_peakBalance - ST_troughBalance) /
                        ST_peakBalance * 100.0;
        ST_maxDrawdownPct = MathMax(ST_maxDrawdownPct, ddPct);
    }

    Print("[ST] Trade #", ST_totalTrades,
          " W:", ST_wins, " L:", ST_losses,
          " WR:", DoubleToStr(ST_winRate, 1), "%",
          " PF:", DoubleToStr(ST_profitFactor, 2),
          " DD:", DoubleToStr(ST_maxDrawdownPct, 1), "%",
          " Bal:$", DoubleToStr(newBalance, 2));
}

//+------------------------------------------------------------------+
//| Write stats to GlobalVariables for HUD display
//+------------------------------------------------------------------+
void ST_UpdateGlobalVars()
{
    GV_SetInt(NNFXLP_WINS,    ST_wins);
    GV_SetInt(NNFXLP_LOSSES,  ST_losses);
    GV_SetDouble(NNFXLP_PF,   ST_profitFactor);
}

//+------------------------------------------------------------------+
//| Accessors
//+------------------------------------------------------------------+
double ST_GetProfitFactor() { return ST_profitFactor; }
double ST_GetWinRate()      { return ST_winRate; }
int    ST_GetTotalTrades()  { return ST_totalTrades; }

#endif // NNFXLITE_STATS_ENGINE_MQH
```

- [ ] 2. Add include to `NNFXLitePro1.mq4`:
  ```cpp
  #include <NNFXLite/stats_engine.mqh>
  ```

- [ ] 3. Add `ST_Init()` call in `OnInit()` after `TE_Init()`:
  ```cpp
  ST_Init(StartingBalance);
  ```

- [ ] 4. Add a temporary test: feed 50 bars, process trades, record stats (remove after verification):
  ```cpp
  // --- TEMP TEST: 50 bars with stats ---
  long offId = BF_GetOfflineChartId();
  for(int i = 0; i < 50; i++)
  {
      if(!BF_FeedNextBar()) break;
      if(i < 2) continue;
      int sig = SE_GetSignal();
      if(TE_isOpen)
      {
          string reason = "";
          double pips = TE_CheckExit(sig, reason, offId);
          if(pips != 0.0)
          {
              ST_RecordTrade(pips, TE_simBalance);
              if(StringFind(reason, "REVERSE") == 0)
                  TE_OpenTrade((reason == "REVERSE_BUY" ? +1 : -1), offId);
          }
      }
      if(!TE_isOpen && sig != 0)
          TE_OpenTrade(sig, offId);
  }
  Print("[TEST] Final stats: W:", ST_wins, " L:", ST_losses,
        " PF:", DoubleToStr(ST_profitFactor, 2),
        " MaxDD:", DoubleToStr(ST_maxDrawdownPct, 1), "%");
  // --- END TEMP TEST ---
  ```

**Verification:**
- [ ] 5. Compile — expect 0 errors, 0 warnings.
- [ ] 6. Attach EA, check Experts log for `[ST] Trade #N` messages showing running stats after each trade.
- [ ] 7. Manually verify PF calculation: count wins and losses in log, compute pipsWon/pipsLost, confirm it matches logged PF.
- [ ] 8. Remove temporary test code.

**Commit:**
- [ ] 9. `git add backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/stats_engine.mqh backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4 && git commit -m "Add stats_engine.mqh with running accumulators and drawdown tracking"`

---

## Task 7: csv_exporter.mqh — Trades CSV + Summary CSV

**Goal:** Write the CSV export module that writes a trade log and summary file to `MQL4/Files/NNFXLitePro/`.

**Files:**
- `NNFXLitePro1/include/NNFXLite/csv_exporter.mqh` (replace stub)

**Steps:**

- [ ] 1. Write `csv_exporter.mqh` with trades and summary CSV output:

```cpp
//+------------------------------------------------------------------+
//| csv_exporter.mqh — Trades CSV + Summary CSV writer               |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_CSV_EXPORTER_MQH
#define NNFXLITE_CSV_EXPORTER_MQH

//+------------------------------------------------------------------+
//| CSV state
//+------------------------------------------------------------------+
string CSV_dirPath;         // directory path under MQL4/Files/
string CSV_tradesFile;      // full trades CSV path
string CSV_summaryFile;     // full summary CSV path
string CSV_indName;         // indicator name for summary
string CSV_symbol;          // symbol for summary
datetime CSV_startDate;
datetime CSV_endDate;
int    CSV_tradesHandle;    // file handle for trades CSV (kept open)
bool   CSV_isOpen;          // whether trades file is open

//+------------------------------------------------------------------+
//| Sanitize a string for use in file/directory names
//| Replace spaces and special chars with underscores
//+------------------------------------------------------------------+
string CSV_Sanitize(string s)
{
    string result = s;
    StringReplace(result, " ", "_");
    StringReplace(result, "/", "_");
    StringReplace(result, "\\", "_");
    StringReplace(result, ":", "_");
    StringReplace(result, ".", "_");
    return result;
}

//+------------------------------------------------------------------+
//| Format datetime as yyyyMMdd for filenames
//+------------------------------------------------------------------+
string CSV_DateStr(datetime dt)
{
    return TimeToStr(dt, TIME_DATE);  // returns yyyy.MM.dd
}

//+------------------------------------------------------------------+
//| Initialize CSV exporter — create output directory, open trades CSV
//+------------------------------------------------------------------+
void CSV_Init(string symbol, string indName, datetime startDate, datetime endDate)
{
    CSV_symbol    = symbol;
    CSV_indName   = indName;
    CSV_startDate = startDate;
    CSV_endDate   = endDate;
    CSV_isOpen    = false;

    // Build directory name: NNFXLitePro/<Symbol>_<Indicator>_<Start>_<End>
    string startStr = CSV_Sanitize(TimeToStr(startDate, TIME_DATE));
    string endStr   = CSV_Sanitize(TimeToStr(endDate, TIME_DATE));
    string dirName  = CSV_Sanitize(symbol) + "_" +
                      CSV_Sanitize(indName) + "_" +
                      startStr + "_" + endStr;

    CSV_dirPath = "NNFXLitePro\\" + dirName;

    // Check if directory exists, append suffix if needed
    string testPath = CSV_dirPath + "\\trades.csv";
    int testHandle = FileOpen(testPath, FILE_READ | FILE_TXT);
    if(testHandle >= 0)
    {
        FileClose(testHandle);
        // Directory already has results — find next available suffix
        int suffix = 2;
        while(suffix < 100)
        {
            string newDir = CSV_dirPath + "_" + IntegerToString(suffix);
            testPath = newDir + "\\trades.csv";
            testHandle = FileOpen(testPath, FILE_READ | FILE_TXT);
            if(testHandle < 0)
            {
                CSV_dirPath = newDir;
                break;
            }
            FileClose(testHandle);
            suffix++;
        }
    }

    CSV_tradesFile  = CSV_dirPath + "\\trades.csv";
    CSV_summaryFile = CSV_dirPath + "\\summary.csv";

    // Open trades CSV and write header
    CSV_tradesHandle = FileOpen(CSV_tradesFile,
                                 FILE_WRITE | FILE_CSV, ',');
    if(CSV_tradesHandle < 0)
    {
        Print("[CSV] ERROR: Cannot open trades file: ", CSV_tradesFile,
              " Error=", GetLastError());
        return;
    }

    CSV_isOpen = true;

    // Write header row
    FileWrite(CSV_tradesHandle,
              "Date", "Direction", "EntryPrice", "SLPrice", "TPPrice",
              "ExitPrice", "CloseReason", "Pips", "Balance");

    Print("[CSV] Init: output dir=", CSV_dirPath);
}

//+------------------------------------------------------------------+
//| Write one trade row to trades CSV
//+------------------------------------------------------------------+
void CSV_WriteTrade(datetime barDate, int dir, double entryPrice,
                    double slPrice, double tpPrice, double exitPrice,
                    string closeReason, double pips, double balance)
{
    if(!CSV_isOpen) return;

    string dirStr = (dir > 0) ? "BUY" : "SELL";
    string dateStr = TimeToStr(barDate, TIME_DATE);

    FileWrite(CSV_tradesHandle,
              dateStr,
              dirStr,
              DoubleToStr(entryPrice, 5),
              DoubleToStr(slPrice, 5),
              DoubleToStr(tpPrice, 5),
              DoubleToStr(exitPrice, 5),
              closeReason,
              DoubleToStr(pips, 1),
              DoubleToStr(balance, 2));
}

//+------------------------------------------------------------------+
//| Write summary CSV with all stats
//+------------------------------------------------------------------+
void CSV_WriteSummary(int totalTrades, int wins, int losses,
                      double winRate, double totalPipsWon, double totalPipsLost,
                      double profitFactor, int maxConsecWins, int maxConsecLosses,
                      double maxDrawdownPct, double startBalance, double finalBalance)
{
    int handle = FileOpen(CSV_summaryFile,
                           FILE_WRITE | FILE_CSV, ',');
    if(handle < 0)
    {
        Print("[CSV] ERROR: Cannot open summary file: ", CSV_summaryFile,
              " Error=", GetLastError());
        return;
    }

    // Header row
    FileWrite(handle,
              "Indicator", "Symbol", "StartDate", "EndDate",
              "TotalTrades", "Wins", "Losses", "WinRate",
              "TotalPipsWon", "TotalPipsLost", "ProfitFactor",
              "MaxConsecWins", "MaxConsecLosses", "MaxDrawdownPct",
              "StartBalance", "FinalBalance");

    // Data row
    FileWrite(handle,
              CSV_indName,
              CSV_symbol,
              TimeToStr(CSV_startDate, TIME_DATE),
              TimeToStr(CSV_endDate, TIME_DATE),
              IntegerToString(totalTrades),
              IntegerToString(wins),
              IntegerToString(losses),
              DoubleToStr(winRate, 1),
              DoubleToStr(totalPipsWon, 1),
              DoubleToStr(totalPipsLost, 1),
              DoubleToStr(profitFactor, 2),
              IntegerToString(maxConsecWins),
              IntegerToString(maxConsecLosses),
              DoubleToStr(maxDrawdownPct, 1),
              DoubleToStr(startBalance, 2),
              DoubleToStr(finalBalance, 2));

    FileClose(handle);
    Print("[CSV] Summary written to: ", CSV_summaryFile);
}

//+------------------------------------------------------------------+
//| Close trades CSV file handle
//+------------------------------------------------------------------+
void CSV_Close()
{
    if(CSV_isOpen && CSV_tradesHandle >= 0)
    {
        FileClose(CSV_tradesHandle);
        CSV_isOpen = false;
        Print("[CSV] Trades file closed: ", CSV_tradesFile);
    }
}

#endif // NNFXLITE_CSV_EXPORTER_MQH
```

- [ ] 2. Add include to `NNFXLitePro1.mq4`:
  ```cpp
  #include <NNFXLite/csv_exporter.mqh>
  ```

- [ ] 3. Add `CSV_Init()` call in `OnInit()`:
  ```cpp
  CSV_Init(SimSymbol, C1_IndicatorName, TestStartDate, TestEndDate);
  ```

- [ ] 4. Add a temporary test: feed 20 bars, process trades, write CSV on each close, then write summary and close (remove after verification):
  ```cpp
  // --- TEMP TEST: 20 bars with CSV ---
  long offId = BF_GetOfflineChartId();
  for(int i = 0; i < 20; i++)
  {
      if(!BF_FeedNextBar()) break;
      if(i < 2) continue;
      int sig = SE_GetSignal();
      if(TE_isOpen)
      {
          string reason = "";
          double pips = TE_CheckExit(sig, reason, offId);
          if(pips != 0.0)
          {
              ST_RecordTrade(pips, TE_simBalance);
              datetime closeDate = iTime(TE_simSymbol, PERIOD_D1, 1);
              CSV_WriteTrade(closeDate, TE_dir == 0 ? (pips > 0 ? +1 : -1) : TE_dir,
                             TE_entryPrice, TE_slPrice, TE_tpPrice,
                             (reason == "SL" ? TE_slPrice :
                              reason == "TP" ? TE_tpPrice :
                              iClose(TE_simSymbol, PERIOD_D1, 1)),
                             reason, pips, TE_simBalance);
              if(StringFind(reason, "REVERSE") == 0)
                  TE_OpenTrade((reason == "REVERSE_BUY" ? +1 : -1), offId);
          }
      }
      if(!TE_isOpen && sig != 0)
          TE_OpenTrade(sig, offId);
  }
  CSV_WriteSummary(ST_totalTrades, ST_wins, ST_losses, ST_winRate,
                   ST_totalPipsWon, ST_totalPipsLost, ST_profitFactor,
                   ST_maxConsecWins, ST_maxConsecLosses, ST_maxDrawdownPct,
                   ST_startBalance, ST_finalBalance);
  CSV_Close();
  // --- END TEMP TEST ---
  ```

**Verification:**
- [ ] 5. Compile — expect 0 errors, 0 warnings.
- [ ] 6. Attach EA. Check Experts log for `[CSV] Init: output dir=...` and `[CSV] Summary written to:...`.
- [ ] 7. Navigate to `MQL4/Files/NNFXLitePro/` inside your terminal data folder. Open `trades.csv` and `summary.csv` in a text editor. Verify header row and data rows match the trades logged in the Experts tab.
- [ ] 8. Remove temporary test code.

**Commit:**
- [ ] 9. `git add backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/csv_exporter.mqh backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4 && git commit -m "Add csv_exporter.mqh with trades and summary CSV output"`

---

## Task 8: NNFXLitePanel.mq4 — Floating Control Panel + HUD Indicator

**Goal:** Write the panel indicator that provides the floating control panel (Play/Pause/Step/Stop/Speed buttons) and the HUD display on the offline chart. Communicates with the main EA via GlobalVariables.

**Files:**
- `NNFXLitePro1/NNFXLitePanel.mq4` (replace stub)

**Steps:**

- [ ] 1. Replace `NNFXLitePanel.mq4` with the full implementation:

```cpp
//+------------------------------------------------------------------+
//| NNFXLitePanel.mq4 — Control panel + HUD indicator               |
//| Attaches to offline EURUSD_SIM D1 chart                          |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window

#include <NNFXLite/global_vars.mqh>

//+------------------------------------------------------------------+
//| UI layout constants (pixel positions from top-left corner)
//+------------------------------------------------------------------+
#define PANEL_X        10
#define PANEL_Y        20
#define BTN_H          22
#define BTN_GAP        4
#define ROW_H          (BTN_H + BTN_GAP)

// Row 1: Title + Stop
#define TITLE_X        PANEL_X
#define TITLE_Y        PANEL_Y
#define STOP_X         200
#define STOP_Y         PANEL_Y

// Row 2: Slower, Play, Faster
#define SLOWER_X       PANEL_X
#define SLOWER_Y       (PANEL_Y + ROW_H)
#define PLAY_X         (PANEL_X + 44)
#define PLAY_Y         (PANEL_Y + ROW_H)
#define FASTER_X       (PANEL_X + 108)
#define FASTER_Y       (PANEL_Y + ROW_H)

// Row 3: Pause, Step
#define PAUSE_X        (PANEL_X + 44)
#define PAUSE_Y        (PANEL_Y + ROW_H * 2)
#define STEP_X         (PANEL_X + 108)
#define STEP_Y         (PANEL_Y + ROW_H * 2)

// Row 4: Speed indicator
#define SPEED_X        PANEL_X
#define SPEED_Y        (PANEL_Y + ROW_H * 3)

// HUD rows (below control panel)
#define HUD_X          PANEL_X
#define HUD_Y_START    (PANEL_Y + ROW_H * 4 + 10)
#define HUD_LINE_H     18

//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorShortName("NNFXLitePanel");

    // Create control panel buttons
    CreateButton("NNFXLP_BTN_STOP",   "STOP",  STOP_X,   STOP_Y,   60, BTN_H, clrRed,          clrWhite);
    CreateButton("NNFXLP_BTN_SLOWER", "<<",    SLOWER_X, SLOWER_Y, 40, BTN_H, clrDarkSlateGray, clrWhite);
    CreateButton("NNFXLP_BTN_PLAY",   "PLAY",  PLAY_X,   PLAY_Y,   60, BTN_H, clrForestGreen,  clrWhite);
    CreateButton("NNFXLP_BTN_FASTER", ">>",    FASTER_X, FASTER_Y, 40, BTN_H, clrDarkSlateGray, clrWhite);
    CreateButton("NNFXLP_BTN_PAUSE",  "PAUSE", PAUSE_X,  PAUSE_Y,  60, BTN_H, clrDarkOrange,   clrWhite);
    CreateButton("NNFXLP_BTN_STEP",   "STEP",  STEP_X,   STEP_Y,   50, BTN_H, clrSteelBlue,    clrWhite);

    // Title label
    CreateLabel("NNFXLP_LBL_TITLE", "NNFX LITE PRO 1", TITLE_X, TITLE_Y,
                "Consolas", 11, clrWhite);

    // Speed label
    CreateLabel("NNFXLP_LBL_SPEED", "Speed: ---", SPEED_X, SPEED_Y,
                "Consolas", 9, clrSilver);

    // HUD labels
    int hudY = HUD_Y_START;
    CreateLabel("NNFXLP_HUD_DATE",  "Date:    ---",        HUD_X, hudY, "Consolas", 10, clrSilver);
    hudY += HUD_LINE_H;
    CreateLabel("NNFXLP_HUD_BAR",   "Bar:     0 / 0",     HUD_X, hudY, "Consolas", 10, clrSilver);
    hudY += HUD_LINE_H;
    CreateLabel("NNFXLP_HUD_BAL",   "Balance: $0.00",     HUD_X, hudY, "Consolas", 10, clrSilver);
    hudY += HUD_LINE_H;
    CreateLabel("NNFXLP_HUD_TRADE", "Trade:   ---",        HUD_X, hudY, "Consolas", 10, clrSilver);
    hudY += HUD_LINE_H;
    CreateLabel("NNFXLP_HUD_SLTP",  "         SL --- TP ---", HUD_X, hudY, "Consolas", 10, clrSilver);
    hudY += HUD_LINE_H;
    CreateLabel("NNFXLP_HUD_STATS", "Stats:   W:0 L:0 WR:0.0%", HUD_X, hudY, "Consolas", 10, clrSilver);
    hudY += HUD_LINE_H;
    CreateLabel("NNFXLP_HUD_PF",    "         PF: 0.00",  HUD_X, hudY, "Consolas", 10, clrSilver);

    // Start HUD refresh timer
    EventSetMillisecondTimer(500);

    Print("[NNFXLitePanel] Indicator initialized. Panel and HUD created.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();

    // Delete all objects with NNFXLP_ prefix
    int total = ObjectsTotal(0);
    for(int i = total - 1; i >= 0; i--)
    {
        string name = ObjectName(0, i);
        if(StringFind(name, "NNFXLP_") == 0)
            ObjectDelete(0, name);
    }

    Print("[NNFXLitePanel] Indicator deinitialized. All objects cleaned up.");
}

//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    return rates_total;
}

//+------------------------------------------------------------------+
//| Handle button clicks — send commands via GlobalVariable
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
    if(id != CHARTEVENT_OBJECT_CLICK) return;

    int cmd = NNFXLP_CMD_NONE;

    if(sparam == "NNFXLP_BTN_PLAY")    cmd = NNFXLP_CMD_PLAY;
    if(sparam == "NNFXLP_BTN_PAUSE")   cmd = NNFXLP_CMD_PAUSE;
    if(sparam == "NNFXLP_BTN_STEP")    cmd = NNFXLP_CMD_STEP;
    if(sparam == "NNFXLP_BTN_FASTER")  cmd = NNFXLP_CMD_FASTER;
    if(sparam == "NNFXLP_BTN_SLOWER")  cmd = NNFXLP_CMD_SLOWER;
    if(sparam == "NNFXLP_BTN_STOP")    cmd = NNFXLP_CMD_STOP;

    if(cmd != NNFXLP_CMD_NONE)
    {
        GV_SetInt(NNFXLP_CMD, cmd);
        // Un-depress the button
        ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
        ChartRedraw(0);
    }
}

//+------------------------------------------------------------------+
//| Timer: refresh HUD labels from GlobalVariables
//+------------------------------------------------------------------+
void OnTimer()
{
    // Read state from EA
    int    state   = GV_GetInt(NNFXLP_STATE);
    int    speed   = GV_GetInt(NNFXLP_SPEED);
    int    barCur  = GV_GetInt(NNFXLP_BAR_CUR);
    int    barTot  = GV_GetInt(NNFXLP_BAR_TOT);
    double dateDbl = GV_GetDouble(NNFXLP_DATE);
    double balance = GV_GetDouble(NNFXLP_BAL);
    int    trade   = GV_GetInt(NNFXLP_TRADE);
    double entry   = GV_GetDouble(NNFXLP_ENTRY);
    double sl      = GV_GetDouble(NNFXLP_SL);
    double tp      = GV_GetDouble(NNFXLP_TP);
    int    wins    = GV_GetInt(NNFXLP_WINS);
    int    losses  = GV_GetInt(NNFXLP_LOSSES);
    double pf      = GV_GetDouble(NNFXLP_PF);

    // Update HUD labels
    // Date
    string dateStr = (dateDbl > 0) ?
        TimeToStr((datetime)dateDbl, TIME_DATE) : "---";
    ObjectSetString(0, "NNFXLP_HUD_DATE", OBJPROP_TEXT,
                    "Date:    " + dateStr);

    // Bar counter
    ObjectSetString(0, "NNFXLP_HUD_BAR", OBJPROP_TEXT,
                    "Bar:     " + IntegerToString(barCur) +
                    " / " + IntegerToString(barTot));

    // Balance
    ObjectSetString(0, "NNFXLP_HUD_BAL", OBJPROP_TEXT,
                    "Balance: $" + DoubleToStr(balance, 2));

    // Trade info
    string tradeStr = "---";
    if(trade == +1)
        tradeStr = "LONG  entry " + DoubleToStr(entry, 5);
    else if(trade == -1)
        tradeStr = "SHORT entry " + DoubleToStr(entry, 5);
    ObjectSetString(0, "NNFXLP_HUD_TRADE", OBJPROP_TEXT,
                    "Trade:   " + tradeStr);

    // SL/TP
    string sltpStr = "SL --- TP ---";
    if(trade != 0)
        sltpStr = "SL " + DoubleToStr(sl, 5) +
                  "  TP " + DoubleToStr(tp, 5);
    ObjectSetString(0, "NNFXLP_HUD_SLTP", OBJPROP_TEXT,
                    "         " + sltpStr);

    // Stats
    int totalTrades = wins + losses;
    double winRate = (totalTrades > 0) ?
        (double)wins / (double)totalTrades * 100.0 : 0.0;
    ObjectSetString(0, "NNFXLP_HUD_STATS", OBJPROP_TEXT,
                    "Stats:   W:" + IntegerToString(wins) +
                    " L:" + IntegerToString(losses) +
                    " WR:" + DoubleToStr(winRate, 1) + "%");

    // Profit factor
    ObjectSetString(0, "NNFXLP_HUD_PF", OBJPROP_TEXT,
                    "         PF: " + DoubleToStr(pf, 2));

    // Speed indicator: filled/empty dots
    if(speed < 1) speed = 1;
    if(speed > 5) speed = 5;
    string speedStr = "Speed: ";
    for(int i = 1; i <= 5; i++)
        speedStr += (i <= speed) ? CharToStr(0x25CF) : CharToStr(0x25CB);
    speedStr += " (" + IntegerToString(speed) + "/5)";
    ObjectSetString(0, "NNFXLP_LBL_SPEED", OBJPROP_TEXT, speedStr);

    // Update PLAY button text based on state
    if(state == NNFXLP_STATE_PLAYING)
        ObjectSetString(0, "NNFXLP_BTN_PLAY", OBJPROP_TEXT, "PLAY");
    else
        ObjectSetString(0, "NNFXLP_BTN_PLAY", OBJPROP_TEXT, "PLAY");

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Helper: create a button object
//+------------------------------------------------------------------+
void CreateButton(string name, string text, int x, int y,
                  int width, int height, color bgColor, color txtColor)
{
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE,      width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE,      height);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    bgColor);
    ObjectSetInteger(0, name, OBJPROP_COLOR,      txtColor);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bgColor);
    ObjectSetString(0,  name, OBJPROP_TEXT,        text);
    ObjectSetString(0,  name, OBJPROP_FONT,        "Consolas");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,    9);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
}

//+------------------------------------------------------------------+
//| Helper: create a label object
//+------------------------------------------------------------------+
void CreateLabel(string name, string text, int x, int y,
                 string font, int fontSize, color textColor)
{
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
    ObjectSetString(0,  name, OBJPROP_TEXT,        text);
    ObjectSetString(0,  name, OBJPROP_FONT,        font);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,    fontSize);
    ObjectSetInteger(0, name, OBJPROP_COLOR,       textColor);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE,  false);
}
```

**Verification:**
- [ ] 2. Compile `NNFXLitePanel.mq4` — expect 0 errors, 0 warnings.
- [ ] 3. Run `NNFXLiteSetup` to create the HST file if not already done. Open offline chart (File > Open Offline > EURUSD_SIM D1).
- [ ] 4. Drag `NNFXLitePanel` onto the offline chart. Verify:
  - Title label "NNFX LITE PRO 1" appears top-left
  - All 6 buttons are visible: STOP, <<, PLAY, >>, PAUSE, STEP
  - HUD labels show default values (Date: ---, Balance: $0.00, etc.)
- [ ] 5. Click PLAY button. Open MT4 menu Tools > Global Variables. Verify `NNFXLP_CMD` is set to 1.
- [ ] 6. Click PAUSE, STEP, STOP — verify corresponding command values appear in GlobalVariables.

**Commit:**
- [ ] 7. `git add backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePanel.mq4 && git commit -m "Add NNFXLitePanel indicator with control buttons and HUD display"`

---

## Task 9: NNFXLitePro1.mq4 — Main EA Wiring

**Goal:** Wire all modules together in the main EA. Implement the OnInit, OnTimer (main loop), and OnDeinit functions that orchestrate bar feeding, signal reading, trade management, stats recording, CSV writing, and GlobalVariable communication.

**Files:**
- `NNFXLitePro1/NNFXLitePro1.mq4` (replace with full wiring)

**Steps:**

- [ ] 1. Replace `NNFXLitePro1.mq4` with the fully wired implementation:

```cpp
//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — Main EA (attaches to real chart)             |
//| Orchestrates: bar feeder, signal engine, trade engine,           |
//|               stats engine, CSV exporter                          |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict

#include <NNFXLite/global_vars.mqh>
#include <NNFXLite/bar_feeder.mqh>
#include <NNFXLite/signal_engine.mqh>
#include <NNFXLite/trade_engine.mqh>
#include <NNFXLite/stats_engine.mqh>
#include <NNFXLite/csv_exporter.mqh>

//+------------------------------------------------------------------+
//| Extern inputs
//+------------------------------------------------------------------+
extern string   SourceSymbol      = "EURUSD";
extern string   SimSymbol         = "EURUSD_SIM";
extern datetime TestStartDate     = D'2021.01.01';
extern datetime TestEndDate       = D'2023.12.31';
extern double   StartingBalance   = 10000.0;
extern int      DefaultSpeed      = 3;
extern double   RiskPercent       = 0.02;
extern int      ATR_Period        = 14;
extern double   ATR_SL_Multiplier = 1.5;
extern double   ATR_TP_Multiplier = 1.0;
// C1 Indicator configuration
extern string   C1_IndicatorName  = "";
extern int      C1_Mode           = 0;
extern int      C1_FastBuffer     = 0;
extern int      C1_SlowBuffer     = 1;
extern int      C1_SignalBuffer   = 0;
extern double   C1_CrossLevel     = 0.0;
extern int      C1_HistBuffer     = 0;
extern bool     C1_HistDualBuffer = false;
extern int      C1_HistBuyBuffer  = 0;
extern int      C1_HistSellBuffer = 1;
extern string   C1_ParamValues    = "";
extern string   C1_ParamTypes     = "";

//+------------------------------------------------------------------+
//| EA state
//+------------------------------------------------------------------+
int  g_state;           // NNFXLP_STATE_STOPPED / PLAYING / PAUSED
bool g_stepPending;     // true if STEP command was received

//+------------------------------------------------------------------+
int OnInit()
{
    Print("[NNFXLitePro1] ========================================");
    Print("[NNFXLitePro1] NNFX Lite Pro 1 — Initializing...");

    //--- Validate inputs
    if(C1_IndicatorName == "")
    {
        Print("[NNFXLitePro1] ERROR: C1_IndicatorName is empty. ",
              "Set the indicator name in EA inputs.");
        return INIT_FAILED;
    }

    if(TestStartDate >= TestEndDate)
    {
        Print("[NNFXLitePro1] ERROR: TestStartDate must be before TestEndDate.");
        return INIT_FAILED;
    }

    //--- 1. Initialize bar feeder (finds offline chart, sets up HST)
    if(!BF_Init(SourceSymbol, SimSymbol, TestStartDate, TestEndDate, DefaultSpeed))
    {
        Print("[NNFXLitePro1] INIT FAILED: bar feeder could not initialize.");
        return INIT_FAILED;
    }

    //--- 2. Initialize signal engine
    SE_Init(SimSymbol, C1_IndicatorName, C1_Mode,
            C1_FastBuffer, C1_SlowBuffer,
            C1_SignalBuffer, C1_CrossLevel,
            C1_HistBuffer, C1_HistDualBuffer, C1_HistBuyBuffer, C1_HistSellBuffer,
            C1_ParamValues, C1_ParamTypes);

    //--- 3. Initialize trade engine
    TE_Init(SourceSymbol, SimSymbol, StartingBalance,
            ATR_SL_Multiplier, ATR_TP_Multiplier, RiskPercent, ATR_Period);

    //--- 4. Initialize stats engine
    ST_Init(StartingBalance);

    //--- 5. Initialize CSV exporter
    CSV_Init(SimSymbol, C1_IndicatorName, TestStartDate, TestEndDate);

    //--- 6. Initialize GlobalVariables
    GV_InitAll(StartingBalance, BF_GetTotalBars(), DefaultSpeed);

    //--- 7. Set initial state
    g_state       = NNFXLP_STATE_STOPPED;
    g_stepPending = false;

    //--- 8. Start timer at configured speed
    EventSetMillisecondTimer(BF_GetSpeedMs());

    Print("[NNFXLitePro1] Init complete. Total bars=", BF_GetTotalBars(),
          " Speed=", BF_GetSpeedLevel(), " (", BF_GetSpeedMs(), "ms)");
    Print("[NNFXLitePro1] Indicator: ", C1_IndicatorName,
          " Mode=", C1_Mode);
    Print("[NNFXLitePro1] Waiting for PLAY command from panel...");
    Print("[NNFXLitePro1] ========================================");

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    CSV_Close();
    TE_Cleanup(BF_GetOfflineChartId());
    GV_DeleteAll();
    Print("[NNFXLitePro1] EA deinitialized. Reason=", reason);
}

//+------------------------------------------------------------------+
void OnTick()
{
    // Timer-driven, not tick-driven.
}

//+------------------------------------------------------------------+
//| Main loop — called on each timer tick
//+------------------------------------------------------------------+
void OnTimer()
{
    //=== 1. Read and process command from panel ===
    int cmd = GV_GetInt(NNFXLP_CMD);
    if(cmd != NNFXLP_CMD_NONE)
    {
        // Clear command immediately
        GV_SetInt(NNFXLP_CMD, NNFXLP_CMD_NONE);
        ProcessCommand(cmd);
    }

    //=== 2. If not playing (and no step pending), do nothing ===
    if(g_state != NNFXLP_STATE_PLAYING && !g_stepPending)
        return;

    //=== 3. Feed one bar ===
    bool moreBars = BF_FeedNextBar();

    if(!moreBars)
    {
        // All bars fed — auto-stop
        Print("[NNFXLitePro1] All bars fed. Backtest complete.");
        DoStop();
        return;
    }

    //=== 4. Update bar/date GlobalVariables ===
    GV_SetInt(NNFXLP_BAR_CUR, BF_GetCurrentBarNum());
    GV_SetDouble(NNFXLP_DATE, (double)BF_GetCurrentDate());

    //=== 5. Need at least 3 bars fed before evaluating signals ===
    //        (shift 1 and shift 2 must exist on the offline chart)
    if(BF_GetCurrentBarNum() >= 3)
    {
        int sig = SE_GetSignal();

        //=== 6. If trade is open, check for exit ===
        if(TE_isOpen)
        {
            // Capture trade data before CheckExit resets it
            int    priorDir    = TE_dir;
            double priorEntry  = TE_entryPrice;
            double priorSL     = TE_slPrice;
            double priorTP     = TE_tpPrice;

            string closeReason = "";
            double pips = TE_CheckExit(sig, closeReason, BF_GetOfflineChartId());

            if(pips != 0.0)
            {
                // Record stats
                ST_RecordTrade(pips, TE_simBalance);

                // Determine exit price
                double exitPrice;
                if(closeReason == "SL")      exitPrice = priorSL;
                else if(closeReason == "TP") exitPrice = priorTP;
                else                          exitPrice = iClose(SimSymbol, PERIOD_D1, 1);

                // Write trade to CSV
                datetime closeDate = iTime(SimSymbol, PERIOD_D1, 1);
                CSV_WriteTrade(closeDate, priorDir, priorEntry,
                               priorSL, priorTP, exitPrice,
                               closeReason, pips, TE_simBalance);

                // If reverse signal, open in new direction immediately
                if(StringFind(closeReason, "REVERSE") == 0)
                {
                    int newDir = (closeReason == "REVERSE_BUY") ? +1 : -1;
                    TE_OpenTrade(newDir, BF_GetOfflineChartId());
                }
            }
        }

        //=== 7. If no trade open and signal detected, open trade ===
        if(!TE_isOpen && sig != 0)
        {
            TE_OpenTrade(sig, BF_GetOfflineChartId());
        }
    }

    //=== 8. Update GlobalVariables with current state ===
    TE_UpdateGlobalVars();
    ST_UpdateGlobalVars();

    //=== 9. If STEP, immediately re-pause ===
    if(g_stepPending)
    {
        g_stepPending = false;
        g_state = NNFXLP_STATE_PAUSED;
        GV_SetInt(NNFXLP_STATE, NNFXLP_STATE_PAUSED);
    }
}

//+------------------------------------------------------------------+
//| Process a command from the panel
//+------------------------------------------------------------------+
void ProcessCommand(int cmd)
{
    switch(cmd)
    {
        case NNFXLP_CMD_PLAY:
            g_state = NNFXLP_STATE_PLAYING;
            GV_SetInt(NNFXLP_STATE, NNFXLP_STATE_PLAYING);
            Print("[NNFXLitePro1] >> PLAY (speed ", BF_GetSpeedLevel(), ")");
            break;

        case NNFXLP_CMD_PAUSE:
            g_state = NNFXLP_STATE_PAUSED;
            GV_SetInt(NNFXLP_STATE, NNFXLP_STATE_PAUSED);
            Print("[NNFXLitePro1] || PAUSE");
            break;

        case NNFXLP_CMD_STEP:
            g_stepPending = true;
            // Temporarily set to PLAYING so the main loop runs one iteration
            g_state = NNFXLP_STATE_PLAYING;
            GV_SetInt(NNFXLP_STATE, NNFXLP_STATE_PLAYING);
            Print("[NNFXLitePro1] |> STEP");
            break;

        case NNFXLP_CMD_FASTER:
        {
            int newLevel = MathMin(BF_GetSpeedLevel() + 1, 5);
            BF_SetSpeed(newLevel);
            GV_SetInt(NNFXLP_SPEED, newLevel);
            EventKillTimer();
            EventSetMillisecondTimer(BF_GetSpeedMs());
            Print("[NNFXLitePro1] >> FASTER: speed=", newLevel,
                  " (", BF_GetSpeedMs(), "ms)");
            break;
        }

        case NNFXLP_CMD_SLOWER:
        {
            int newLevel = MathMax(BF_GetSpeedLevel() - 1, 1);
            BF_SetSpeed(newLevel);
            GV_SetInt(NNFXLP_SPEED, newLevel);
            EventKillTimer();
            EventSetMillisecondTimer(BF_GetSpeedMs());
            Print("[NNFXLitePro1] << SLOWER: speed=", newLevel,
                  " (", BF_GetSpeedMs(), "ms)");
            break;
        }

        case NNFXLP_CMD_STOP:
            Print("[NNFXLitePro1] [] STOP");
            DoStop();
            break;
    }
}

//+------------------------------------------------------------------+
//| Stop the backtest: flush CSV, update state, print results
//+------------------------------------------------------------------+
void DoStop()
{
    // Force-close any open trade at current price
    if(TE_isOpen)
    {
        // Capture trade data before TE_ForceClose resets it
        int    priorDir   = TE_dir;
        double priorEntry = TE_entryPrice;
        double priorSL    = TE_slPrice;
        double priorTP    = TE_tpPrice;

        string closeReason = "";
        double pips = TE_ForceClose(closeReason, BF_GetOfflineChartId());

        ST_RecordTrade(pips, TE_simBalance);
        datetime closeDate = iTime(SimSymbol, PERIOD_D1, 0);
        double exitPrice = iClose(SimSymbol, PERIOD_D1, 0);
        CSV_WriteTrade(closeDate, priorDir, priorEntry,
                       priorSL, priorTP, exitPrice,
                       closeReason, pips, TE_simBalance);
    }

    // Write summary CSV
    CSV_WriteSummary(ST_totalTrades, ST_wins, ST_losses, ST_winRate,
                     ST_totalPipsWon, ST_totalPipsLost, ST_profitFactor,
                     ST_maxConsecWins, ST_maxConsecLosses, ST_maxDrawdownPct,
                     ST_startBalance, ST_finalBalance);
    CSV_Close();

    // Update state
    g_state = NNFXLP_STATE_STOPPED;
    GV_SetInt(NNFXLP_STATE, NNFXLP_STATE_STOPPED);
    TE_UpdateGlobalVars();
    ST_UpdateGlobalVars();

    Print("[NNFXLitePro1] ========================================");
    Print("[NNFXLitePro1] BACKTEST COMPLETE");
    Print("[NNFXLitePro1]   Bars processed: ", BF_GetCurrentBarNum(),
          " / ", BF_GetTotalBars());
    Print("[NNFXLitePro1]   Trades: ", ST_totalTrades,
          " (W:", ST_wins, " L:", ST_losses, ")");
    Print("[NNFXLitePro1]   Win Rate: ", DoubleToStr(ST_winRate, 1), "%");
    Print("[NNFXLitePro1]   Profit Factor: ",
          DoubleToStr(ST_profitFactor, 2));
    Print("[NNFXLitePro1]   Max Drawdown: ",
          DoubleToStr(ST_maxDrawdownPct, 1), "%");
    Print("[NNFXLitePro1]   Final Balance: $",
          DoubleToStr(ST_finalBalance, 2));
    Print("[NNFXLitePro1]   Results saved to MQL4/Files/NNFXLitePro/");
    Print("[NNFXLitePro1] ========================================");
}
```

**Verification:**
- [ ] 2. Compile `NNFXLitePro1.mq4` — expect 0 errors, 0 warnings.
- [ ] 3. Full end-to-end test workflow:
  1. Run NNFXLiteSetup on any chart (if not already done)
  2. Open offline chart (File > Open Offline > EURUSD_SIM D1)
  3. Attach NNFXLitePanel to the offline chart
  4. Open real EURUSD D1 chart
  5. Attach NNFXLitePro1 with: `C1_IndicatorName="MACD"`, `C1_Mode=0`, `C1_FastBuffer=0`, `C1_SlowBuffer=1`, `C1_ParamValues="12,26,9"`, `C1_ParamTypes="int,int,int"`, `TestStartDate=2022.01.01`, `TestEndDate=2022.12.31`
- [ ] 4. On the panel: click PLAY at speed 3. Verify:
  - Bars appear on the offline chart in chronological order
  - Entry arrows appear when signals fire
  - SL/TP lines appear and disappear correctly
  - Result labels (+Np / -Np) appear at trade closes
  - HUD updates: date, bar count, balance, trade info, stats
- [ ] 5. Click PAUSE — verify bars stop. Click STEP 3 times — verify exactly 3 bars advance.
- [ ] 6. Click FASTER twice (to speed 5) — click PLAY — verify faster bar feeding.
- [ ] 7. Click STOP (or let it auto-complete). Verify:
  - Experts log shows "BACKTEST COMPLETE" summary
  - CSV files appear in MQL4/Files/NNFXLitePro/ inside your terminal data folder

**Commit:**
- [ ] 8. `git add backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4 && git commit -m "Wire all modules in NNFXLitePro1 main EA with full timer loop"`

---

## Task 10: Integration Test + Deploy Script

**Goal:** Write the deploy batch script, run the full integration acceptance test, and create the final git tag.

**Files:**
- `NNFXLitePro1/deploy_nnfxlitepro.bat` (new)

**Steps:**

- [ ] 1. Write `deploy_nnfxlitepro.bat`:

```batch
@echo off
REM deploy_nnfxlitepro.bat — Deploy NNFXLitePro1 files to MT4 data path
REM Run from: backtester\bridge\mt4_runner\

set MT4=C:\Users\win10pro\AppData\Roaming\MetaQuotes\Terminal\98A82F92176B73A2100FCD1F8ABD7255

echo === NNFX Lite Pro 1 — Deploy to MT4 ===

REM Create target directories if they don't exist
if not exist "%MT4%\MQL4\Experts\NNFXLitePro" mkdir "%MT4%\MQL4\Experts\NNFXLitePro"
if not exist "%MT4%\MQL4\Scripts\NNFXLitePro" mkdir "%MT4%\MQL4\Scripts\NNFXLitePro"
if not exist "%MT4%\MQL4\Indicators\NNFXLitePro" mkdir "%MT4%\MQL4\Indicators\NNFXLitePro"
if not exist "%MT4%\MQL4\Include\NNFXLite" mkdir "%MT4%\MQL4\Include\NNFXLite"

REM Copy EA
xcopy /Y "NNFXLitePro1\NNFXLitePro1.mq4" "%MT4%\MQL4\Experts\NNFXLitePro\"
echo   [OK] NNFXLitePro1.mq4 -> Experts\NNFXLitePro\

REM Copy Setup Script
xcopy /Y "NNFXLitePro1\NNFXLiteSetup.mq4" "%MT4%\MQL4\Scripts\NNFXLitePro\"
echo   [OK] NNFXLiteSetup.mq4 -> Scripts\NNFXLitePro\

REM Copy Panel Indicator
xcopy /Y "NNFXLitePro1\NNFXLitePanel.mq4" "%MT4%\MQL4\Indicators\NNFXLitePro\"
echo   [OK] NNFXLitePanel.mq4 -> Indicators\NNFXLitePro\

REM Copy Include Files
xcopy /Y /S "NNFXLitePro1\include\NNFXLite\*" "%MT4%\MQL4\Include\NNFXLite\"
echo   [OK] Include files -> Include\NNFXLite\

echo.
echo === Deploy complete. Open MetaEditor (F4) and compile all files (F7). ===
echo.
pause
```

- [ ] 2. Run the deploy script to copy all files to MT4.

- [ ] 3. Open MetaEditor and compile all three MQL4 files. Confirm 0 errors, 0 warnings for each:
  - `MQL4/Experts/NNFXLitePro/NNFXLitePro1.mq4`
  - `MQL4/Scripts/NNFXLitePro/NNFXLiteSetup.mq4`
  - `MQL4/Indicators/NNFXLitePro/NNFXLitePanel.mq4`

- [ ] 4. **Integration acceptance test** — run through the full workflow:

  **Test 1: Initial setup and basic run**
  1. Open any chart. Run NNFXLiteSetup script. Check Experts log for success message.
  2. File > Open Offline > EURUSD_SIM D1 > Open.
  3. Drag NNFXLitePanel onto the offline chart. Verify buttons and HUD appear.
  4. Open real EURUSD D1 chart.
  5. Attach NNFXLitePro1 EA with settings:
     - `C1_IndicatorName = "MACD"`
     - `C1_Mode = 0`
     - `C1_FastBuffer = 0`, `C1_SlowBuffer = 1`
     - `C1_ParamValues = "12,26,9"`, `C1_ParamTypes = "int,int,int"`
     - `TestStartDate = 2022.01.01`, `TestEndDate = 2022.06.30`
  6. Verify Experts log: "Init complete. Total bars=~130"

  **Test 2: Playback controls**
  1. Click PLAY at speed 3. Watch bars appear on offline chart.
  2. After ~20 bars, click PAUSE. Verify chart frozen.
  3. Click STEP 3 times. Verify exactly 3 bars advance.
  4. Click FASTER twice (speed 5). Click PLAY. Verify fast bar feeding.
  5. Click SLOWER 3 times (speed 2). Verify slowdown.

  **Test 3: Trade visuals**
  1. While running, observe entry arrows appearing on the offline chart.
  2. Verify SL line (red dashed) and TP line (green dashed) appear on trade open.
  3. Verify lines disappear and result label appears on trade close.
  4. Verify HUD shows trade direction, entry, SL, TP during open trades.

  **Test 4: Completion and CSV**
  1. Let the run complete (or click STOP).
  2. Verify Experts log shows "BACKTEST COMPLETE" with summary stats.
  3. Navigate to `MQL4/Files/NNFXLitePro/` inside your terminal data folder.
  4. Open `trades.csv` — verify header row and trade data.
  5. Open `summary.csv` — verify header row and summary data match Experts log.

  **Test 5: Re-run with different settings**
  1. Remove EA from real chart.
  2. Re-attach with different indicator or date range.
  3. Verify HST file is reset (offline chart shows fresh bars from start).
  4. Verify new CSV files are created (not overwriting previous run).

- [ ] 5. Fix any issues found during acceptance testing. Recompile and retest.

- [ ] 6. Final commit and tag:

```bash
git add backtester/bridge/mt4_runner/NNFXLitePro1/
git commit -m "Add deploy script and complete NNFXLitePro1 Phase 1"
git tag NNFXLitePro1_Phase1_complete
```

- [ ] 7. Push to remote:
```bash
git push && git push --tags
```

---

## Summary

| Task | Component | Key Deliverable |
|------|-----------|-----------------|
| 1 | Scaffold | Folder structure, `global_vars.mqh`, 3 stubs |
| 2 | Setup | `NNFXLiteSetup.mq4` — HST v401 file creator |
| 3 | Bar feeder | `bar_feeder.mqh` — HST writing, chart refresh, speed |
| 4 | Signals | `signal_engine.mqh` — 3 C1 modes, typed param dispatch |
| 5 | Trades | `trade_engine.mqh` — virtual trades, ATR SL/TP, visuals |
| 6 | Stats | `stats_engine.mqh` — running accumulators, drawdown |
| 7 | CSV | `csv_exporter.mqh` — trades + summary CSV files |
| 8 | Panel | `NNFXLitePanel.mq4` — buttons, HUD, GV communication |
| 9 | Main EA | `NNFXLitePro1.mq4` — full wiring of all modules |
| 10 | Deploy | `deploy_nnfxlitepro.bat`, integration test, git tag |

**Estimated total tasks:** 10
**Each task gate:** Compile 0 errors + MT4 attach test + git commit
**Final gate:** Full integration acceptance test + `NNFXLitePro1_Phase1_complete` tag

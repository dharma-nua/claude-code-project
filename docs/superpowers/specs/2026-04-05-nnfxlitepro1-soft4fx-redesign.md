# NNFXLitePro1 v2 — Soft4FX-Style Single-EA Redesign

**Date:** 2026-04-05
**Status:** Approved — ready for implementation planning
**Approach:** Incremental merge (fallback to big-bang rewrite if needed)

---

## Goal

Merge the current 3-file setup (script + indicator + EA) into a single drag-and-drop EA, matching the Soft4FX UX: drag EA onto any chart → launcher screen → Start → simulation runs.

**Primary use case:** Quick iteration — rapidly test different C1 indicators back-to-back with minimal setup friction.

## Current Architecture (being replaced)

1. `NNFXLiteSetup.mq4` (script) — creates `EURUSD_SIM1440.hst`
2. `NNFXLitePanel.mq4` (indicator) — HUD + buttons on offline chart, reads GlobalVariables
3. `NNFXLitePro1.mq4` (EA) — bar feeding, signals, trades, writes GlobalVariables
4. `global_vars.mqh` — ~15 GlobalVariable name constants + helpers bridging EA ↔ Panel

**Problems:** 3-step manual setup, GlobalVariables bridge is fragile, user must manually open offline chart and attach indicator.

## New Architecture

### Single EA with 8 include files

```
NNFXLitePro1/
├── NNFXLitePro1.mq4          — single EA entry point (rewritten)
├── deploy.bat
└── include/NNFXLite/
    ├── launcher.mqh           — NEW: config screen UI on host chart
    ├── hst_builder.mqh        — NEW: HST v401 file creation (from Setup)
    ├── hud_manager.mqh        — NEW: HUD labels + buttons on remote chart (from Panel)
    ├── bar_feeder.mqh         — MODIFIED: remove GV dependency, remove FindOfflineChart
    ├── signal_engine.mqh      — unchanged
    ├── trade_engine.mqh       — unchanged
    ├── stats_engine.mqh       — unchanged
    └── csv_exporter.mqh       — unchanged
```

### Deleted files

- `NNFXLiteSetup.mq4` — code absorbed into `hst_builder.mqh`
- `NNFXLitePanel.mq4` — code absorbed into `hud_manager.mqh`
- `global_vars.mqh` — GlobalVariables bridge eliminated entirely

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Use case | Quick iteration | Fast C1 testing back-to-back |
| C1 config | Extern inputs + MT4 templates | Native `.tpl` presets, no custom UI needed |
| Launcher screen | Light config: pair, dates, balance | Frequently-changed params visible, rest in templates |
| Offline chart management | EA creates HST + `ChartOpen()` + draws HUD via chart ID | True single-EA, matches Soft4FX model |
| Host chart on Start | Minimized | Offline chart gets full focus |
| Button click handling | Polling `OBJPROP_STATE` on offline chart | Single-file, no bridge, 200ms poll timer |
| Bar feed timing | `GetTickCount()` elapsed check, multi-bar at high speeds | Decouples bar speed from poll timer |
| Session save/load | Skipped for v1 | Keep scope tight, add in v2 if needed |
| On sim end | CSV + Experts log, chart stays as-is | User controls flow manually |
| Approach | Incremental merge | Each step testable, proven code reused, fallback to big-bang available |

## Startup Flow

### State Machine

```
LAUNCHER → STARTING → PLAYING ⇄ PAUSED → STOPPED
```

- **LAUNCHER** — config screen on host chart, waiting for Start click
- **STARTING** — HST creation + ChartOpen + HUD init (transient, < 1 second)
- **PLAYING** — bar feeding active, HUD updating
- **PAUSED** — bar feeding stopped, buttons still responsive
- **STOPPED** — terminal state, CSV written, log printed

### Sequence (drag to first bar)

1. User drags EA onto any live chart → `OnInit()` fires
2. `OnInit()` sets `g_State = STATE_LAUNCHER`, calls `LAUNCH_Create()` to draw config screen
3. Launcher shows pair, start date, end date, balance as editable `OBJ_EDIT` fields (pre-filled from extern inputs), plus a "Start Simulation" button
4. User clicks Start → `g_State = STATE_STARTING`
5. `HST_Build(sourceSymbol)` creates the HST v401 file (header + seed bar)
6. `ChartOpen(simSymbol, PERIOD_D1)` opens the offline chart → EA stores `simChartId`
7. Host chart minimized via `ChartSetInteger(hostChartId, CHART_BRING_TO_TOP, false)`
8. `HUD_Create(simChartId)` draws labels + buttons on offline chart
9. `BF_Init(...)`, `SE_Init(...)`, `TE_Init(...)`, `ST_Init(...)`, `CE_Init(...)` initialize engines
10. `g_State = STATE_PLAYING`, `EventSetMillisecondTimer(200)` starts
11. Auto-play: simulation begins immediately, no separate PLAY click needed

## Timer Architecture

Fixed 200ms poll timer, independent of bar speed.

```
OnTimer() — fires every 200ms:
  1. Poll button OBJPROP_STATE on offline chart (always responsive)
  2. If state == PLAYING:
     elapsed = GetTickCount() - g_LastBarTime
     barsToFeed = max(1, elapsed / BF_GetSpeedMs())
     for i = 0 to barsToFeed-1:
         ProcessNextBar()
     g_LastBarTime = GetTickCount()
```

- At speed 1 (2000ms): feeds 1 bar every ~2s, buttons respond in ≤200ms
- At speed 5 (30ms): feeds ~6 bars per 200ms tick = ~30 bars/sec, matching original throughput
- Button response: always ≤200ms regardless of speed setting

## New Include File Specs

### launcher.mqh

- `LAUNCH_Create()` — draws config UI on host chart (OBJ_LABEL for labels, OBJ_EDIT for editable fields, OBJ_BUTTON for Start)
- `LAUNCH_Destroy()` — removes all launcher objects
- `LAUNCH_ReadConfig()` — reads values from OBJ_EDIT fields, returns struct/globals with pair, start date, end date, balance
- Fields pre-filled from extern inputs, user can override before clicking Start
- Object naming: `NNFXLP_LAUNCH_<TYPE>_<ID>`

### hst_builder.mqh

- `HST_Build(string sourceSymbol, string simSymbol)` — creates HST v401 file with header + 1 seed bar
- Returns `bool` success/failure
- Extracted directly from `NNFXLiteSetup::OnStart()` with ForceReset always true (EA always creates fresh HST)
- Pure function: no state, no dependencies beyond MarketInfo

### hud_manager.mqh

- `HUD_Create(long chartId)` — creates all labels + buttons on the specified chart
- `HUD_Update(long chartId, int barNum, int totalBars, datetime date, double balance, int speed, int wins, int losses, double pf, int tradeDir, double entry, double sl, double tp)` — refreshes all label text
- `HUD_Destroy(long chartId)` — removes all HUD objects
- `HUD_PollButtons(long chartId)` — checks each button's `OBJPROP_STATE`, returns command int (CMD_NONE, CMD_RESUME, CMD_PAUSE, CMD_STEP, CMD_FASTER, CMD_SLOWER, CMD_STOP), resets button state after read
- Object naming: `NNFXLP_HUD_<TYPE>_<ID>`
- Same visual layout as current NNFXLitePanel (labels + 6 buttons), but PLAY is replaced with RESUME (toggle with PAUSE). Buttons: RESUME, PAUSE, STEP, FASTER, SLOWER, STOP
- RESUME only enabled when state == PAUSED. PAUSE only enabled when state == PLAYING.

### bar_feeder.mqh (modifications)

- Remove `BF_FindOfflineChart()` function
- Remove `GV_SetInt(NNFXLP_REFRESH, 1)` from `BF_FeedNextBar()`
- Remove `#include <NNFXLite/global_vars.mqh>`
- `BF_FeedNextBar()` returns `bool` (success) — EA handles chart refresh externally via `ChartSetSymbolPeriod(simChartId, simSymbol, PERIOD_D1)`
- All other logic unchanged: HST writing, speed control, bar counting, date tracking

## EA Main File (NNFXLitePro1.mq4)

### Extern inputs

All existing externs remain (SourceSymbol, SimSymbol, TestStartDate, TestEndDate, StartingBalance, DefaultSpeed, RiskPercent, ATR params, C1 params). These serve as defaults for the launcher screen and as the full C1 configuration.

### Global state

```
int    g_State;          // STATE_LAUNCHER, STATE_STARTING, STATE_PLAYING, STATE_PAUSED, STATE_STOPPED
long   g_HostChartId;    // chart the EA is attached to
long   g_SimChartId;     // offline chart opened by EA
uint   g_LastBarTime;    // GetTickCount() of last bar feed
```

### OnInit()

- Store `g_HostChartId = ChartID()`
- Set `g_State = STATE_LAUNCHER`
- Call `LAUNCH_Create()` with extern defaults
- Start 200ms timer for launcher button polling

### OnTimer()

- If `STATE_LAUNCHER`: poll Start button on host chart
- If `STATE_STARTING`: run startup sequence (HST build, ChartOpen, HUD create, engine inits), transition to PLAYING
- If `STATE_PLAYING`: poll HUD buttons on offline chart, feed bars based on elapsed time
- If `STATE_PAUSED`: poll HUD buttons only (Step feeds 1 bar)
- If `STATE_STOPPED`: do nothing (timer killed)

### OnDeinit()

- If sim running: call `EndTest()` (force-close trade, write CSV)
- `HUD_Destroy(g_SimChartId)`
- `LAUNCH_Destroy()`
- Kill timer

## Out of Scope (v2 candidates)

- Session save/load
- Keyboard hotkeys for sim control
- Multi-pair simultaneous sims
- Data Center (Dukascopy download)
- "New Sim" button on sim end (currently: just stop, user restarts manually)

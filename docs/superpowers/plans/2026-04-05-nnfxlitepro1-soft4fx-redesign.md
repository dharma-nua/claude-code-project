# NNFXLitePro1 v2 — Soft4FX-Style Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge NNFXLitePro1's 3-file setup into a single drag-and-drop EA with launcher screen, automatic HST creation, and self-drawn HUD.

**Architecture:** Incremental merge — extract HST creation into `hst_builder.mqh`, HUD into `hud_manager.mqh`, add `launcher.mqh`, modify `bar_feeder.mqh` to remove GlobalVariables dependency, rewrite the EA main file to orchestrate everything. Five existing include files (`signal_engine`, `trade_engine`, `stats_engine`, `csv_exporter`, `bar_feeder` core logic) remain unchanged.

**Tech Stack:** MQL4, MT4 terminal, MetaEditor CLI compiler

**Spec:** `docs/superpowers/specs/2026-04-05-nnfxlitepro1-soft4fx-redesign.md`

**Base path:** `backtester/bridge/mt4_runner/NNFXLitePro1/`

**Compile command:**
```bash
"/c/Program Files (x86)/MetaTrader 4 IC Markets/metaeditor.exe" /compile:"C:\Users\win10pro\OneDrive\Desktop\claude code project\backtester\bridge\mt4_runner\NNFXLitePro1\NNFXLitePro1.mq4" /include:"C:\Users\win10pro\OneDrive\Desktop\claude code project\backtester\bridge\mt4_runner\NNFXLitePro1\include" /log
```

**Deploy:** `deploy.bat` copies compiled `.ex4` + includes to MT4 data path.

**Testing approach:** MQ4 has no unit test framework. Each task ends with a compile check (0 errors, 0 warnings). Manual acceptance testing in MT4 happens after all tasks are complete.

---

## File Map

| File | Action | Responsibility |
|------|--------|---------------|
| `include/NNFXLite/hst_builder.mqh` | CREATE | HST v401 file creation (extracted from NNFXLiteSetup.mq4) |
| `include/NNFXLite/hud_manager.mqh` | CREATE | HUD labels + buttons on remote chart, polling (extracted from NNFXLitePanel.mq4) |
| `include/NNFXLite/launcher.mqh` | CREATE | Config screen UI on host chart (pair, dates, balance, Start button) |
| `include/NNFXLite/bar_feeder.mqh` | MODIFY | Remove GV dependency, remove FindOfflineChart, remove GV refresh signal |
| `NNFXLitePro1.mq4` | REWRITE | Single EA entry point — state machine, timer, orchestration |
| `include/NNFXLite/global_vars.mqh` | DELETE | GlobalVariables bridge eliminated |
| `NNFXLiteSetup.mq4` | DELETE | Code absorbed into hst_builder.mqh |
| `NNFXLitePanel.mq4` | DELETE | Code absorbed into hud_manager.mqh |
| `include/NNFXLite/signal_engine.mqh` | UNCHANGED | |
| `include/NNFXLite/trade_engine.mqh` | UNCHANGED | |
| `include/NNFXLite/stats_engine.mqh` | UNCHANGED | |
| `include/NNFXLite/csv_exporter.mqh` | UNCHANGED | |

---

### Task 1: Create hst_builder.mqh

**Files:**
- Create: `include/NNFXLite/hst_builder.mqh`

Extract HST v401 file creation from `NNFXLiteSetup.mq4` into a standalone include. Pure function — no state, no GlobalVariables, no dependencies beyond MarketInfo.

- [ ] **Step 1: Create hst_builder.mqh with HST_Build function**

```mql4
//+------------------------------------------------------------------+
//| hst_builder.mqh — HST v401 file creation                         |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_HST_BUILDER_MQH
#define NNFXLITE_HST_BUILDER_MQH

//+------------------------------------------------------------------+
//| Create (or overwrite) an HST v401 file with header + 1 seed bar.
//| Returns true on success.
//| sourceSymbol = real symbol for MarketInfo (e.g. "EURUSD")
//| simSymbol    = offline symbol name (e.g. "EURUSD_SIM")
//+------------------------------------------------------------------+
bool HST_Build(string sourceSymbol, string simSymbol)
{
    string hstFile = simSymbol + "1440.hst";
    int    period  = 1440;  // D1
    int    digits  = (int)MarketInfo(sourceSymbol, MODE_DIGITS);

    Print("[HST] Creating offline symbol: ", simSymbol,
          " Period=D1 Digits=", digits);

    //--- Create/overwrite the HST file
    int handle = FileOpenHistory(hstFile, FILE_BIN | FILE_WRITE);
    if(handle < 0)
    {
        Print("[HST] ERROR: Failed to create ", hstFile,
              " Error=", GetLastError());
        return false;
    }

    //--- Write 148-byte HST v401 header ---

    // version (4 bytes)
    FileWriteInteger(handle, 401, LONG_VALUE);

    // copyright (64 bytes) — null-padded string
    string copyright = "NNFXLitePro1";
    uchar copyrightBytes[64];
    ArrayInitialize(copyrightBytes, 0);
    StringToCharArray(copyright, copyrightBytes, 0,
                      MathMin(StringLen(copyright), 63));
    for(int i = 0; i < 64; i++)
        FileWriteInteger(handle, copyrightBytes[i], CHAR_VALUE);

    // symbol (12 bytes) — null-padded
    uchar symbolBytes[12];
    ArrayInitialize(symbolBytes, 0);
    StringToCharArray(simSymbol, symbolBytes, 0,
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

    //--- Write 1 seed bar so MT4 lists the file in File > Open Offline
    datetime seedTime  = iTime(sourceSymbol, PERIOD_D1, 0);
    double   seedOpen  = iOpen(sourceSymbol, PERIOD_D1, 0);
    double   seedHigh  = iHigh(sourceSymbol, PERIOD_D1, 0);
    double   seedLow   = iLow(sourceSymbol, PERIOD_D1, 0);
    double   seedClose = iClose(sourceSymbol, PERIOD_D1, 0);
    long     seedVol   = iVolume(sourceSymbol, PERIOD_D1, 0);

    FileWriteLong(handle, (long)seedTime);        // time        8 bytes
    FileWriteDouble(handle, seedOpen);            // open        8 bytes
    FileWriteDouble(handle, seedHigh);            // high        8 bytes
    FileWriteDouble(handle, seedLow);             // low         8 bytes
    FileWriteDouble(handle, seedClose);           // close       8 bytes
    FileWriteLong(handle, seedVol);               // tick_volume 8 bytes
    FileWriteInteger(handle, 0, LONG_VALUE);      // spread      4 bytes
    FileWriteLong(handle, 0);                     // real_volume 8 bytes

    FileFlush(handle);
    FileClose(handle);

    Print("[HST] Created ", hstFile, " successfully (header + 1 seed bar).");
    return true;
}

#endif // NNFXLITE_HST_BUILDER_MQH
```

- [ ] **Step 2: Compile-check with a minimal stub EA**

Create a temporary test in `NNFXLitePro1.mq4` that only includes `hst_builder.mqh` and calls `HST_Build()` in `OnInit()` to verify compilation. The EA will be fully rewritten in Task 5, this is just a compile gate.

Replace the entire contents of `NNFXLitePro1.mq4` with:

```mql4
//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — TEMPORARY compile stub (Task 1)               |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property version   "2.00"
#property strict

#include <NNFXLite/hst_builder.mqh>

int OnInit()
{
    bool ok = HST_Build("EURUSD", "EURUSD_SIM");
    Print("[STUB] HST_Build returned: ", ok);
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}
void OnTick() {}
```

Run compile command. Expected: 0 errors, 0 warnings.

- [ ] **Step 3: Commit**

```bash
git add backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/hst_builder.mqh
git add backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4
git commit -m "Add hst_builder.mqh: extract HST v401 creation from NNFXLiteSetup"
```

---

### Task 2: Create hud_manager.mqh

**Files:**
- Create: `include/NNFXLite/hud_manager.mqh`

Extract HUD drawing from `NNFXLitePanel.mq4` into a standalone include. All ObjectCreate calls target a remote `chartId` parameter. Button polling replaces GlobalVariables. No more OnChartEvent — EA polls button OBJPROP_STATE.

- [ ] **Step 1: Create hud_manager.mqh**

```mql4
//+------------------------------------------------------------------+
//| hud_manager.mqh — HUD labels + buttons on a remote chart         |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_HUD_MANAGER_MQH
#define NNFXLITE_HUD_MANAGER_MQH

//+------------------------------------------------------------------+
//| Command constants (returned by HUD_PollButtons)
//+------------------------------------------------------------------+
#define HUD_CMD_NONE    0
#define HUD_CMD_RESUME  1
#define HUD_CMD_PAUSE   2
#define HUD_CMD_STEP    3
#define HUD_CMD_FASTER  4
#define HUD_CMD_SLOWER  5
#define HUD_CMD_STOP    6

//+------------------------------------------------------------------+
//| Layout constants
//+------------------------------------------------------------------+
#define HUD_PANEL_X       12
#define HUD_LBL_Y_TITLE   15
#define HUD_LBL_Y_STATE   38
#define HUD_LBL_Y_BAR     58
#define HUD_LBL_Y_BAL     78
#define HUD_LBL_Y_STATS   98
#define HUD_LBL_Y_TRADE   120
#define HUD_LBL_Y_PRICES  140
#define HUD_BTN_Y         165
#define HUD_BTN_W         58
#define HUD_BTN_H         20
#define HUD_BTN_GAP       62

//+------------------------------------------------------------------+
//| Object name constants
//+------------------------------------------------------------------+
#define HUD_LBL_TITLE   "NNFXLP_HUD_LBL_TITLE"
#define HUD_LBL_STATE   "NNFXLP_HUD_LBL_STATE"
#define HUD_LBL_BAR     "NNFXLP_HUD_LBL_BAR"
#define HUD_LBL_BAL     "NNFXLP_HUD_LBL_BAL"
#define HUD_LBL_STATS   "NNFXLP_HUD_LBL_STATS"
#define HUD_LBL_TRADE   "NNFXLP_HUD_LBL_TRADE"
#define HUD_LBL_PRICES  "NNFXLP_HUD_LBL_PRICES"

#define HUD_BTN_RESUME  "NNFXLP_HUD_BTN_RESUME"
#define HUD_BTN_PAUSE   "NNFXLP_HUD_BTN_PAUSE"
#define HUD_BTN_STEP    "NNFXLP_HUD_BTN_STEP"
#define HUD_BTN_FASTER  "NNFXLP_HUD_BTN_FASTER"
#define HUD_BTN_SLOWER  "NNFXLP_HUD_BTN_SLOWER"
#define HUD_BTN_STOP    "NNFXLP_HUD_BTN_STOP"

//+------------------------------------------------------------------+
//| Helper: create or update a label on a specific chart
//+------------------------------------------------------------------+
void HUD_Label(long chartId, string name, int x, int y,
               string text, color clr, int fontSize)
{
    if(ObjectFind(chartId, name) < 0)
    {
        ObjectCreate(chartId, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(chartId, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
        ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,  x);
        ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,  y);
        ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(chartId, name, OBJPROP_HIDDEN,     true);
        ObjectSetString(chartId,  name, OBJPROP_FONT,       "Consolas");
    }
    ObjectSetString(chartId,  name, OBJPROP_TEXT,      text);
    ObjectSetInteger(chartId, name, OBJPROP_COLOR,     clr);
    ObjectSetInteger(chartId, name, OBJPROP_FONTSIZE,  fontSize);
}

//+------------------------------------------------------------------+
//| Helper: create a button on a specific chart (idempotent)
//+------------------------------------------------------------------+
void HUD_Button(long chartId, string name, int x, int y, string text)
{
    if(ObjectFind(chartId, name) >= 0) return;
    ObjectCreate(chartId, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(chartId, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
    ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,  x);
    ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,  y);
    ObjectSetInteger(chartId, name, OBJPROP_XSIZE,      HUD_BTN_W);
    ObjectSetInteger(chartId, name, OBJPROP_YSIZE,      HUD_BTN_H);
    ObjectSetString(chartId,  name, OBJPROP_TEXT,       text);
    ObjectSetString(chartId,  name, OBJPROP_FONT,       "Consolas");
    ObjectSetInteger(chartId, name, OBJPROP_FONTSIZE,   8);
    ObjectSetInteger(chartId, name, OBJPROP_COLOR,      clrWhite);
    ObjectSetInteger(chartId, name, OBJPROP_BGCOLOR,    C'50,50,60');
    ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chartId, name, OBJPROP_HIDDEN,     false);
    ObjectSetInteger(chartId, name, OBJPROP_STATE,      false);
}

//+------------------------------------------------------------------+
//| Create all HUD objects on the specified chart
//+------------------------------------------------------------------+
void HUD_Create(long chartId)
{
    HUD_Label(chartId, HUD_LBL_TITLE,  HUD_PANEL_X, HUD_LBL_Y_TITLE,
              "NNFX Lite Pro 1", clrGold, 10);
    HUD_Label(chartId, HUD_LBL_STATE,  HUD_PANEL_X, HUD_LBL_Y_STATE,
              "State: PLAYING", clrLimeGreen, 9);
    HUD_Label(chartId, HUD_LBL_BAR,    HUD_PANEL_X, HUD_LBL_Y_BAR,
              "Bar: 0 / 0", clrSilver, 9);
    HUD_Label(chartId, HUD_LBL_BAL,    HUD_PANEL_X, HUD_LBL_Y_BAL,
              "Balance: ---", clrSilver, 9);
    HUD_Label(chartId, HUD_LBL_STATS,  HUD_PANEL_X, HUD_LBL_Y_STATS,
              "W:0  L:0  PF:---", clrSilver, 9);
    HUD_Label(chartId, HUD_LBL_TRADE,  HUD_PANEL_X, HUD_LBL_Y_TRADE,
              "Trade: NONE", clrDimGray, 9);
    HUD_Label(chartId, HUD_LBL_PRICES, HUD_PANEL_X, HUD_LBL_Y_PRICES,
              "E:---  SL:---  TP:---", clrDimGray, 9);

    int bx = HUD_PANEL_X;
    HUD_Button(chartId, HUD_BTN_RESUME, bx, HUD_BTN_Y, "RESUME"); bx += HUD_BTN_GAP;
    HUD_Button(chartId, HUD_BTN_PAUSE,  bx, HUD_BTN_Y, "PAUSE");  bx += HUD_BTN_GAP;
    HUD_Button(chartId, HUD_BTN_STEP,   bx, HUD_BTN_Y, "STEP");   bx += HUD_BTN_GAP;
    HUD_Button(chartId, HUD_BTN_FASTER, bx, HUD_BTN_Y, ">> FWD"); bx += HUD_BTN_GAP;
    HUD_Button(chartId, HUD_BTN_SLOWER, bx, HUD_BTN_Y, "<< SLW"); bx += HUD_BTN_GAP;
    HUD_Button(chartId, HUD_BTN_STOP,   bx, HUD_BTN_Y, "STOP");

    ChartRedraw(chartId);
    Print("[HUD] Created on chart ID=", chartId);
}

//+------------------------------------------------------------------+
//| Remove all HUD objects from the specified chart
//+------------------------------------------------------------------+
void HUD_Destroy(long chartId)
{
    if(chartId <= 0) return;
    string names[] = {
        HUD_LBL_TITLE, HUD_LBL_STATE, HUD_LBL_BAR,
        HUD_LBL_BAL,   HUD_LBL_STATS, HUD_LBL_TRADE, HUD_LBL_PRICES,
        HUD_BTN_RESUME, HUD_BTN_PAUSE, HUD_BTN_STEP,
        HUD_BTN_FASTER, HUD_BTN_SLOWER, HUD_BTN_STOP
    };
    for(int i = 0; i < ArraySize(names); i++)
        ObjectDelete(chartId, names[i]);
    ChartRedraw(chartId);
    Print("[HUD] Destroyed on chart ID=", chartId);
}

//+------------------------------------------------------------------+
//| Update all HUD labels with current sim state
//+------------------------------------------------------------------+
void HUD_Update(long chartId,
                int barNum, int totalBars, datetime date,
                double balance, int speed,
                int wins, int losses, double pf,
                int tradeDir, double entry, double sl, double tp)
{
    // Bar progress + date
    string barStr = "Bar: " + IntegerToString(barNum) + " / "
                  + IntegerToString(totalBars);
    if(date > 0) barStr += "   " + TimeToStr(date, TIME_DATE);
    HUD_Label(chartId, HUD_LBL_BAR, HUD_PANEL_X, HUD_LBL_Y_BAR,
              barStr, clrSilver, 9);

    // Balance + speed
    string balStr = "Balance: $" + DoubleToStr(balance, 2)
                  + "   Speed: " + IntegerToString(speed);
    HUD_Label(chartId, HUD_LBL_BAL, HUD_PANEL_X, HUD_LBL_Y_BAL,
              balStr, clrSilver, 9);

    // W / L / PF
    color pfColor = (pf >= 1.5) ? clrLimeGreen
                  : (pf >= 1.0 ? clrYellow : clrTomato);
    if(wins + losses == 0) pfColor = clrSilver;
    string statsStr = "W:" + IntegerToString(wins)
                    + "  L:" + IntegerToString(losses)
                    + "  PF:" + (wins + losses > 0
                                ? DoubleToStr(pf, 2) : "---");
    HUD_Label(chartId, HUD_LBL_STATS, HUD_PANEL_X, HUD_LBL_Y_STATS,
              statsStr, pfColor, 9);

    // Trade direction
    string tradeStr;
    color  tradeColor;
    if(tradeDir > 0)       { tradeStr = "Trade: BUY";  tradeColor = clrDodgerBlue; }
    else if(tradeDir < 0)  { tradeStr = "Trade: SELL"; tradeColor = clrTomato;     }
    else                   { tradeStr = "Trade: NONE"; tradeColor = clrDimGray;    }
    HUD_Label(chartId, HUD_LBL_TRADE, HUD_PANEL_X, HUD_LBL_Y_TRADE,
              tradeStr, tradeColor, 9);

    // Entry / SL / TP
    string priceStr;
    if(tradeDir != 0)
    {
        priceStr = "E:" + DoubleToStr(entry, 5)
                 + "  SL:" + DoubleToStr(sl, 5)
                 + "  TP:" + DoubleToStr(tp, 5);
    }
    else
    {
        priceStr = "E:---  SL:---  TP:---";
    }
    HUD_Label(chartId, HUD_LBL_PRICES, HUD_PANEL_X, HUD_LBL_Y_PRICES,
              priceStr, clrDimGray, 9);

    ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| Update the state label (called separately from HUD_Update since
//| state changes on button press, not just on bar feed)
//+------------------------------------------------------------------+
void HUD_SetState(long chartId, string stateText, color stateColor)
{
    HUD_Label(chartId, HUD_LBL_STATE, HUD_PANEL_X, HUD_LBL_Y_STATE,
              stateText, stateColor, 9);
    ChartRedraw(chartId);
}

//+------------------------------------------------------------------+
//| Poll all button states. Returns the first pressed command found,
//| or HUD_CMD_NONE if no button is pressed. Resets button state
//| after reading.
//+------------------------------------------------------------------+
int HUD_PollButtons(long chartId)
{
    if(chartId <= 0) return HUD_CMD_NONE;

    // Check each button — return first pressed
    if(ObjectGetInteger(chartId, HUD_BTN_RESUME, OBJPROP_STATE) != 0)
    {
        ObjectSetInteger(chartId, HUD_BTN_RESUME, OBJPROP_STATE, false);
        return HUD_CMD_RESUME;
    }
    if(ObjectGetInteger(chartId, HUD_BTN_PAUSE, OBJPROP_STATE) != 0)
    {
        ObjectSetInteger(chartId, HUD_BTN_PAUSE, OBJPROP_STATE, false);
        return HUD_CMD_PAUSE;
    }
    if(ObjectGetInteger(chartId, HUD_BTN_STEP, OBJPROP_STATE) != 0)
    {
        ObjectSetInteger(chartId, HUD_BTN_STEP, OBJPROP_STATE, false);
        return HUD_CMD_STEP;
    }
    if(ObjectGetInteger(chartId, HUD_BTN_FASTER, OBJPROP_STATE) != 0)
    {
        ObjectSetInteger(chartId, HUD_BTN_FASTER, OBJPROP_STATE, false);
        return HUD_CMD_FASTER;
    }
    if(ObjectGetInteger(chartId, HUD_BTN_SLOWER, OBJPROP_STATE) != 0)
    {
        ObjectSetInteger(chartId, HUD_BTN_SLOWER, OBJPROP_STATE, false);
        return HUD_CMD_SLOWER;
    }
    if(ObjectGetInteger(chartId, HUD_BTN_STOP, OBJPROP_STATE) != 0)
    {
        ObjectSetInteger(chartId, HUD_BTN_STOP, OBJPROP_STATE, false);
        return HUD_CMD_STOP;
    }

    return HUD_CMD_NONE;
}

#endif // NNFXLITE_HUD_MANAGER_MQH
```

- [ ] **Step 2: Update stub EA to compile-check hud_manager.mqh**

Replace `NNFXLitePro1.mq4` with:

```mql4
//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — TEMPORARY compile stub (Task 2)               |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property version   "2.00"
#property strict

#include <NNFXLite/hst_builder.mqh>
#include <NNFXLite/hud_manager.mqh>

int OnInit()
{
    // Compile check only — functions exist and signatures are correct
    // HST_Build("EURUSD", "EURUSD_SIM");
    // HUD_Create(ChartID());
    // HUD_Update(ChartID(), 0, 100, 0, 10000.0, 3, 0, 0, 0.0, 0, 0.0, 0.0, 0.0);
    // int cmd = HUD_PollButtons(ChartID());
    // HUD_SetState(ChartID(), "Test", clrWhite);
    // HUD_Destroy(ChartID());
    Print("[STUB] hud_manager.mqh compiled OK");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}
void OnTick() {}
```

Run compile command. Expected: 0 errors, 0 warnings.

- [ ] **Step 3: Commit**

```bash
git add backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/hud_manager.mqh
git add backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4
git commit -m "Add hud_manager.mqh: extract HUD labels + button polling from NNFXLitePanel"
```

---

### Task 3: Create launcher.mqh

**Files:**
- Create: `include/NNFXLite/launcher.mqh`

Config screen on the host chart: pair, start date, end date, balance as editable OBJ_EDIT fields, plus a Start Simulation button. Fields pre-filled from extern values passed in.

- [ ] **Step 1: Create launcher.mqh**

```mql4
//+------------------------------------------------------------------+
//| launcher.mqh — Config screen UI on host chart                    |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_LAUNCHER_MQH
#define NNFXLITE_LAUNCHER_MQH

//+------------------------------------------------------------------+
//| Layout constants
//+------------------------------------------------------------------+
#define LAUNCH_X         20
#define LAUNCH_Y_TITLE   30
#define LAUNCH_Y_FIRST   70
#define LAUNCH_ROW_H     32
#define LAUNCH_LBL_W     120
#define LAUNCH_EDIT_W    160
#define LAUNCH_EDIT_H    22
#define LAUNCH_BTN_Y     230
#define LAUNCH_BTN_W     180
#define LAUNCH_BTN_H     30

//+------------------------------------------------------------------+
//| Object names
//+------------------------------------------------------------------+
#define LAUNCH_LBL_TITLE    "NNFXLP_LAUNCH_LBL_TITLE"
#define LAUNCH_LBL_PAIR     "NNFXLP_LAUNCH_LBL_PAIR"
#define LAUNCH_LBL_START    "NNFXLP_LAUNCH_LBL_START"
#define LAUNCH_LBL_END      "NNFXLP_LAUNCH_LBL_END"
#define LAUNCH_LBL_BAL      "NNFXLP_LAUNCH_LBL_BAL"
#define LAUNCH_EDIT_PAIR    "NNFXLP_LAUNCH_EDIT_PAIR"
#define LAUNCH_EDIT_START   "NNFXLP_LAUNCH_EDIT_START"
#define LAUNCH_EDIT_END     "NNFXLP_LAUNCH_EDIT_END"
#define LAUNCH_EDIT_BAL     "NNFXLP_LAUNCH_EDIT_BAL"
#define LAUNCH_BTN_GO       "NNFXLP_LAUNCH_BTN_GO"

//+------------------------------------------------------------------+
//| Helper: create a label on the host chart
//+------------------------------------------------------------------+
void LAUNCH_Label(string name, int x, int y,
                  string text, color clr, int fontSize)
{
    long chartId = ChartID();
    if(ObjectFind(chartId, name) < 0)
    {
        ObjectCreate(chartId, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(chartId, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
        ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,  x);
        ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,  y);
        ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(chartId, name, OBJPROP_HIDDEN,     true);
        ObjectSetString(chartId,  name, OBJPROP_FONT,       "Consolas");
    }
    ObjectSetString(chartId,  name, OBJPROP_TEXT,      text);
    ObjectSetInteger(chartId, name, OBJPROP_COLOR,     clr);
    ObjectSetInteger(chartId, name, OBJPROP_FONTSIZE,  fontSize);
}

//+------------------------------------------------------------------+
//| Helper: create an editable text field
//+------------------------------------------------------------------+
void LAUNCH_Edit(string name, int x, int y, string defaultText)
{
    long chartId = ChartID();
    if(ObjectFind(chartId, name) >= 0) return;
    ObjectCreate(chartId, name, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(chartId, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
    ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE,  x);
    ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE,  y);
    ObjectSetInteger(chartId, name, OBJPROP_XSIZE,      LAUNCH_EDIT_W);
    ObjectSetInteger(chartId, name, OBJPROP_YSIZE,      LAUNCH_EDIT_H);
    ObjectSetString(chartId,  name, OBJPROP_TEXT,       defaultText);
    ObjectSetString(chartId,  name, OBJPROP_FONT,       "Consolas");
    ObjectSetInteger(chartId, name, OBJPROP_FONTSIZE,   10);
    ObjectSetInteger(chartId, name, OBJPROP_COLOR,      clrWhite);
    ObjectSetInteger(chartId, name, OBJPROP_BGCOLOR,    C'40,40,50');
    ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(chartId, name, OBJPROP_READONLY,   false);
}

//+------------------------------------------------------------------+
//| Create the launcher screen with defaults from extern inputs
//+------------------------------------------------------------------+
void LAUNCH_Create(string defaultPair, datetime defaultStart,
                   datetime defaultEnd, double defaultBalance)
{
    // Title
    LAUNCH_Label(LAUNCH_LBL_TITLE, LAUNCH_X, LAUNCH_Y_TITLE,
                 "NNFX Lite Pro 1 — New Simulation", clrGold, 12);

    // Row 1: Pair
    int rowY = LAUNCH_Y_FIRST;
    LAUNCH_Label(LAUNCH_LBL_PAIR, LAUNCH_X, rowY, "Pair:", clrSilver, 10);
    LAUNCH_Edit(LAUNCH_EDIT_PAIR, LAUNCH_X + LAUNCH_LBL_W, rowY,
                defaultPair);

    // Row 2: Start Date
    rowY += LAUNCH_ROW_H;
    LAUNCH_Label(LAUNCH_LBL_START, LAUNCH_X, rowY, "Start Date:", clrSilver, 10);
    LAUNCH_Edit(LAUNCH_EDIT_START, LAUNCH_X + LAUNCH_LBL_W, rowY,
                TimeToStr(defaultStart, TIME_DATE));

    // Row 3: End Date
    rowY += LAUNCH_ROW_H;
    LAUNCH_Label(LAUNCH_LBL_END, LAUNCH_X, rowY, "End Date:", clrSilver, 10);
    LAUNCH_Edit(LAUNCH_EDIT_END, LAUNCH_X + LAUNCH_LBL_W, rowY,
                TimeToStr(defaultEnd, TIME_DATE));

    // Row 4: Balance
    rowY += LAUNCH_ROW_H;
    LAUNCH_Label(LAUNCH_LBL_BAL, LAUNCH_X, rowY, "Balance:", clrSilver, 10);
    LAUNCH_Edit(LAUNCH_EDIT_BAL, LAUNCH_X + LAUNCH_LBL_W, rowY,
                DoubleToStr(defaultBalance, 2));

    // Start button
    long chartId = ChartID();
    if(ObjectFind(chartId, LAUNCH_BTN_GO) < 0)
    {
        ObjectCreate(chartId, LAUNCH_BTN_GO, OBJ_BUTTON, 0, 0, 0);
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_XDISTANCE,  LAUNCH_X);
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_YDISTANCE,  LAUNCH_BTN_Y);
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_XSIZE,      LAUNCH_BTN_W);
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_YSIZE,      LAUNCH_BTN_H);
        ObjectSetString(chartId,  LAUNCH_BTN_GO, OBJPROP_TEXT,       "START SIMULATION");
        ObjectSetString(chartId,  LAUNCH_BTN_GO, OBJPROP_FONT,       "Consolas");
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_FONTSIZE,   10);
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_COLOR,      clrWhite);
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_BGCOLOR,    C'30,120,30');
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_HIDDEN,     false);
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_STATE,      false);
    }

    ChartRedraw(chartId);
    Print("[LAUNCH] Created launcher screen.");
}

//+------------------------------------------------------------------+
//| Remove all launcher objects
//+------------------------------------------------------------------+
void LAUNCH_Destroy()
{
    long chartId = ChartID();
    string names[] = {
        LAUNCH_LBL_TITLE, LAUNCH_LBL_PAIR, LAUNCH_LBL_START,
        LAUNCH_LBL_END,   LAUNCH_LBL_BAL,
        LAUNCH_EDIT_PAIR,  LAUNCH_EDIT_START,
        LAUNCH_EDIT_END,   LAUNCH_EDIT_BAL,
        LAUNCH_BTN_GO
    };
    for(int i = 0; i < ArraySize(names); i++)
        ObjectDelete(chartId, names[i]);
    ChartRedraw(chartId);
    Print("[LAUNCH] Destroyed launcher screen.");
}

//+------------------------------------------------------------------+
//| Read config values from OBJ_EDIT fields.
//| Outputs via reference parameters.
//| Returns true if all fields parsed successfully.
//+------------------------------------------------------------------+
bool LAUNCH_ReadConfig(string &outPair, datetime &outStart,
                       datetime &outEnd, double &outBalance)
{
    long chartId = ChartID();

    outPair = ObjectGetString(chartId, LAUNCH_EDIT_PAIR, OBJPROP_TEXT);
    if(StringLen(outPair) == 0)
    {
        Print("[LAUNCH] ERROR: Pair field is empty.");
        return false;
    }

    string startStr = ObjectGetString(chartId, LAUNCH_EDIT_START, OBJPROP_TEXT);
    outStart = StringToTime(startStr);
    if(outStart <= 0)
    {
        Print("[LAUNCH] ERROR: Invalid start date '", startStr, "'");
        return false;
    }

    string endStr = ObjectGetString(chartId, LAUNCH_EDIT_END, OBJPROP_TEXT);
    outEnd = StringToTime(endStr);
    if(outEnd <= 0)
    {
        Print("[LAUNCH] ERROR: Invalid end date '", endStr, "'");
        return false;
    }

    string balStr = ObjectGetString(chartId, LAUNCH_EDIT_BAL, OBJPROP_TEXT);
    outBalance = StringToDouble(balStr);
    if(outBalance <= 0.0)
    {
        Print("[LAUNCH] ERROR: Invalid balance '", balStr, "'");
        return false;
    }

    Print("[LAUNCH] Config: Pair=", outPair,
          " Start=", TimeToStr(outStart, TIME_DATE),
          " End=", TimeToStr(outEnd, TIME_DATE),
          " Balance=", DoubleToStr(outBalance, 2));
    return true;
}

//+------------------------------------------------------------------+
//| Check if Start button was pressed. Returns true once, resets state.
//+------------------------------------------------------------------+
bool LAUNCH_PollStartButton()
{
    long chartId = ChartID();
    if(ObjectGetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_STATE) != 0)
    {
        ObjectSetInteger(chartId, LAUNCH_BTN_GO, OBJPROP_STATE, false);
        return true;
    }
    return false;
}

#endif // NNFXLITE_LAUNCHER_MQH
```

- [ ] **Step 2: Update stub EA to compile-check launcher.mqh**

Replace `NNFXLitePro1.mq4` with:

```mql4
//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — TEMPORARY compile stub (Task 3)               |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property version   "2.00"
#property strict

#include <NNFXLite/hst_builder.mqh>
#include <NNFXLite/hud_manager.mqh>
#include <NNFXLite/launcher.mqh>

int OnInit()
{
    Print("[STUB] All new includes compiled OK");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}
void OnTick() {}
```

Run compile command. Expected: 0 errors, 0 warnings.

- [ ] **Step 3: Commit**

```bash
git add backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/launcher.mqh
git add backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4
git commit -m "Add launcher.mqh: config screen with pair, dates, balance, Start button"
```

---

### Task 4: Modify bar_feeder.mqh

**Files:**
- Modify: `include/NNFXLite/bar_feeder.mqh`

Remove GlobalVariables dependency, remove `BF_FindOfflineChart()`, remove GV refresh signal from `BF_FeedNextBar()`.

- [ ] **Step 1: Remove the #include and GV dependency**

The file currently has no explicit `#include <NNFXLite/global_vars.mqh>` (it relies on the EA including it first), but it references `GV_SetInt(NNFXLP_REFRESH, 1)` in `BF_FeedNextBar()`. Remove that line.

In `bar_feeder.mqh`, find and remove:

```mql4
    GV_SetInt(NNFXLP_REFRESH, 1);  // signal panel to refresh offline chart
```

Replace with nothing (delete the line entirely).

- [ ] **Step 2: Remove BF_FindOfflineChart() function**

Delete the entire `BF_FindOfflineChart()` function (lines 26-53 of the current file):

```mql4
//+------------------------------------------------------------------+
long BF_FindOfflineChart(string simSymbol)
{
    long chartId = ChartFirst();
    Print("[BF] DEBUG: Looking for simSymbol='", simSymbol, "' ChartFirst()=", chartId);
    while(chartId >= 0)
    {
        string sym = ChartSymbol(chartId);
        int    per = ChartPeriod(chartId);
        Print("[BF] Chart ID=", chartId, " Symbol='", sym, "' Period=", per);
        if(sym == simSymbol && per == PERIOD_D1)
        {
            int indicatorCount = ChartIndicatorsTotal(chartId, 0);
            for(int i = 0; i < indicatorCount; i++)
            {
                string indName = ChartIndicatorName(chartId, 0, i);
                Print("[BF]   Indicator[", i, "]='", indName, "'");
                if(indName == "NNFXLitePanel")
                {
                    Print("[BF] Found offline chart ID=", chartId, " with NNFXLitePanel");
                    return chartId;
                }
            }
            Print("[BF] Found chart for ", simSymbol, " but NNFXLitePanel not attached.");
        }
        chartId = ChartNext(chartId);
    }
    return -1;
}
```

- [ ] **Step 3: Remove BF_offlineChartId state variable and getter**

Delete the state variable declaration:
```mql4
long     BF_offlineChartId;
```

Delete the getter function:
```mql4
long     BF_GetOfflineChartId()  { return BF_offlineChartId; }
```

- [ ] **Step 4: Compile-check**

The stub EA from Task 3 includes `bar_feeder.mqh` indirectly (it's not included yet, but Task 5 will). For now, add it to the stub:

Replace `NNFXLitePro1.mq4` with:

```mql4
//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — TEMPORARY compile stub (Task 4)               |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property version   "2.00"
#property strict

#include <NNFXLite/hst_builder.mqh>
#include <NNFXLite/bar_feeder.mqh>
#include <NNFXLite/hud_manager.mqh>
#include <NNFXLite/launcher.mqh>

int OnInit()
{
    Print("[STUB] All includes compiled OK (bar_feeder cleaned)");
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}
void OnTick() {}
```

Run compile command. Expected: 0 errors, 0 warnings.

- [ ] **Step 5: Commit**

```bash
git add backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/bar_feeder.mqh
git add backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4
git commit -m "Clean bar_feeder.mqh: remove GV dependency and FindOfflineChart"
```

---

### Task 5: Rewrite NNFXLitePro1.mq4 (the main EA)

**Files:**
- Rewrite: `NNFXLitePro1.mq4`

This is the core task — the new single-EA entry point with state machine, 200ms timer, button polling, and bar feeding.

- [ ] **Step 1: Write the complete EA**

Replace the entire contents of `NNFXLitePro1.mq4` with:

```mql4
//+------------------------------------------------------------------+
//| NNFXLitePro1.mq4 — Single-EA NNFX C1 backtester (v2)            |
//| Drag onto any live chart → launcher → Start → sim runs.          |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "2.00"
#property strict

//+------------------------------------------------------------------+
//| Includes
//+------------------------------------------------------------------+
#include <NNFXLite/hst_builder.mqh>
#include <NNFXLite/bar_feeder.mqh>
#include <NNFXLite/signal_engine.mqh>
#include <NNFXLite/trade_engine.mqh>
#include <NNFXLite/stats_engine.mqh>
#include <NNFXLite/csv_exporter.mqh>
#include <NNFXLite/hud_manager.mqh>
#include <NNFXLite/launcher.mqh>

//+------------------------------------------------------------------+
//| State constants
//+------------------------------------------------------------------+
#define STATE_LAUNCHER  0
#define STATE_STARTING  1
#define STATE_PLAYING   2
#define STATE_PAUSED    3
#define STATE_STOPPED   4

//+------------------------------------------------------------------+
//| Inputs
//+------------------------------------------------------------------+
extern string   SourceSymbol      = "EURUSD";
extern string   SimSymbol         = "EURUSD_SIM";
extern datetime TestStartDate     = D'2021.01.01';
extern datetime TestEndDate       = D'2023.12.31';
extern double   StartingBalance   = 10000.0;
extern int      DefaultSpeed      = 3;      // 1=slowest (2s) ... 5=fastest (30ms)
extern double   RiskPercent       = 0.02;
extern int      ATR_Period        = 14;
extern double   ATR_SL_Multiplier = 1.5;
extern double   ATR_TP_Multiplier = 1.0;
extern string   C1_IndicatorName  = "";
extern int      C1_Mode           = 0;     // 0=TwoLine 1=ZeroLine 2=Histogram
extern int      C1_FastBuffer     = 0;
extern int      C1_SlowBuffer     = 1;
extern int      C1_SignalBuffer   = 0;
extern double   C1_CrossLevel     = 0.0;
extern int      C1_HistBuffer     = 0;
extern bool     C1_HistDualBuffer = false;
extern int      C1_HistBuyBuffer  = 0;
extern int      C1_HistSellBuffer = 1;
extern string   C1_ParamValues    = "";    // e.g. "14,0.5,true"
extern string   C1_ParamTypes     = "";    // e.g. "int,double,bool"

//+------------------------------------------------------------------+
//| Global state
//+------------------------------------------------------------------+
int    g_State;
long   g_HostChartId;
long   g_SimChartId;
uint   g_LastBarTime;

// Config read from launcher (may override externs)
string   g_Pair;
datetime g_StartDate;
datetime g_EndDate;
double   g_Balance;

//+------------------------------------------------------------------+
int OnInit()
{
    if(DefaultSpeed < 1) DefaultSpeed = 1;
    if(DefaultSpeed > 5) DefaultSpeed = 5;

    g_HostChartId = ChartID();
    g_SimChartId  = 0;
    g_State       = STATE_LAUNCHER;

    LAUNCH_Create(SourceSymbol, TestStartDate, TestEndDate, StartingBalance);

    EventSetMillisecondTimer(200);

    Print("[NNFXLitePro1] v2 — Launcher ready. Configure and click START.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();

    if(g_State == STATE_PLAYING || g_State == STATE_PAUSED)
    {
        Print("[NNFXLitePro1] EA removed mid-sim — finalizing...");
        EndTest();
    }

    HUD_Destroy(g_SimChartId);
    LAUNCH_Destroy();

    Print("[NNFXLitePro1] EA deinitialized.");
}

//+------------------------------------------------------------------+
void OnTick() {}

//+------------------------------------------------------------------+
void OnTimer()
{
    switch(g_State)
    {
        case STATE_LAUNCHER:
            OnTimer_Launcher();
            break;
        case STATE_STARTING:
            OnTimer_Starting();
            break;
        case STATE_PLAYING:
            OnTimer_Playing();
            break;
        case STATE_PAUSED:
            OnTimer_Paused();
            break;
        // STATE_STOPPED: do nothing, timer should be killed
    }
}

//+------------------------------------------------------------------+
//| LAUNCHER state: poll Start button
//+------------------------------------------------------------------+
void OnTimer_Launcher()
{
    if(!LAUNCH_PollStartButton())
        return;

    // Read config from launcher fields
    if(!LAUNCH_ReadConfig(g_Pair, g_StartDate, g_EndDate, g_Balance))
    {
        Print("[NNFXLitePro1] Config validation failed — staying on launcher.");
        return;
    }

    Print("[NNFXLitePro1] Start clicked. Initializing sim...");
    g_State = STATE_STARTING;
}

//+------------------------------------------------------------------+
//| STARTING state: build HST, open chart, init engines, go to PLAYING
//+------------------------------------------------------------------+
void OnTimer_Starting()
{
    string simSymbol = g_Pair + "_SIM";

    //--- Step 1: Build HST file
    if(!HST_Build(g_Pair, simSymbol))
    {
        Print("[NNFXLitePro1] ERROR: HST build failed. Returning to launcher.");
        g_State = STATE_LAUNCHER;
        return;
    }

    //--- Step 2: Open offline chart
    g_SimChartId = ChartOpen(simSymbol, PERIOD_D1);
    if(g_SimChartId <= 0)
    {
        Print("[NNFXLitePro1] ERROR: ChartOpen failed for ", simSymbol,
              " Error=", GetLastError());
        g_State = STATE_LAUNCHER;
        return;
    }
    Print("[NNFXLitePro1] Offline chart opened. ID=", g_SimChartId);

    //--- Step 3: Minimize host chart, bring sim chart to front
    ChartSetInteger(g_HostChartId, CHART_BRING_TO_TOP, false);
    ChartSetInteger(g_SimChartId,  CHART_BRING_TO_TOP, true);

    //--- Step 4: Remove launcher UI
    LAUNCH_Destroy();

    //--- Step 5: Draw HUD on offline chart
    HUD_Create(g_SimChartId);

    //--- Step 6: Init bar feeder
    if(!BF_Init(g_Pair, simSymbol, g_StartDate, g_EndDate, DefaultSpeed))
    {
        Print("[NNFXLitePro1] ERROR: Bar feeder init failed.");
        HUD_Destroy(g_SimChartId);
        ChartClose(g_SimChartId);
        g_SimChartId = 0;
        LAUNCH_Create(SourceSymbol, TestStartDate, TestEndDate, StartingBalance);
        g_State = STATE_LAUNCHER;
        return;
    }
    Print("[NNFXLitePro1] Bar feeder ready. Bars=", BF_GetTotalBars(),
          " Speed=", BF_GetSpeedLevel(), " (", BF_GetSpeedMs(), "ms)");

    //--- Step 7: Init signal engine
    SE_Init(simSymbol, C1_IndicatorName, C1_Mode,
            C1_FastBuffer, C1_SlowBuffer,
            C1_SignalBuffer, C1_CrossLevel,
            C1_HistBuffer, C1_HistDualBuffer, C1_HistBuyBuffer, C1_HistSellBuffer,
            C1_ParamValues, C1_ParamTypes);

    //--- Step 8: Init trade engine
    TE_Init(simSymbol, g_Pair,
            ATR_Period, ATR_SL_Multiplier, ATR_TP_Multiplier, RiskPercent);

    //--- Step 9: Init stats engine
    ST_Init(g_Balance);

    //--- Step 10: Init CSV exporter
    if(!CE_Init(g_Pair, g_StartDate, g_EndDate))
        Print("[NNFXLitePro1] WARNING: CSV exporter init failed.");

    //--- Step 11: Go to PLAYING — auto-play
    g_LastBarTime = GetTickCount();
    g_State = STATE_PLAYING;

    HUD_SetState(g_SimChartId, "State: PLAYING", clrLimeGreen);

    Print("[NNFXLitePro1] Sim started. Auto-playing.");
}

//+------------------------------------------------------------------+
//| PLAYING state: poll buttons + feed bars
//+------------------------------------------------------------------+
void OnTimer_Playing()
{
    //--- Poll HUD buttons
    int cmd = HUD_PollButtons(g_SimChartId);
    if(cmd != HUD_CMD_NONE)
    {
        HandleCommand(cmd);
        if(g_State != STATE_PLAYING) return;
    }

    //--- Feed bars based on elapsed time
    uint now = GetTickCount();
    uint elapsed = now - g_LastBarTime;
    int speedMs = BF_GetSpeedMs();

    if(elapsed < (uint)speedMs) return;

    int barsToFeed = (int)(elapsed / speedMs);
    if(barsToFeed < 1) barsToFeed = 1;
    if(barsToFeed > 10) barsToFeed = 10;  // cap to avoid stalls

    for(int i = 0; i < barsToFeed; i++)
    {
        ProcessNextBar();
        if(g_State != STATE_PLAYING) break;  // EndTest may have changed state
    }

    g_LastBarTime = GetTickCount();
}

//+------------------------------------------------------------------+
//| PAUSED state: poll buttons only
//+------------------------------------------------------------------+
void OnTimer_Paused()
{
    int cmd = HUD_PollButtons(g_SimChartId);
    if(cmd != HUD_CMD_NONE)
        HandleCommand(cmd);
}

//+------------------------------------------------------------------+
//| Handle a command from HUD button polling
//+------------------------------------------------------------------+
void HandleCommand(int cmd)
{
    switch(cmd)
    {
        case HUD_CMD_RESUME:
            if(g_State == STATE_PAUSED)
            {
                g_State = STATE_PLAYING;
                g_LastBarTime = GetTickCount();
                HUD_SetState(g_SimChartId, "State: PLAYING", clrLimeGreen);
                Print("[NNFXLitePro1] RESUMED");
            }
            break;

        case HUD_CMD_PAUSE:
            if(g_State == STATE_PLAYING)
            {
                g_State = STATE_PAUSED;
                HUD_SetState(g_SimChartId, "State: PAUSED", clrYellow);
                Print("[NNFXLitePro1] PAUSED");
            }
            break;

        case HUD_CMD_STEP:
            if(g_State == STATE_PAUSED)
            {
                Print("[NNFXLitePro1] STEP");
                ProcessNextBar();
            }
            break;

        case HUD_CMD_FASTER:
            BF_SetSpeed(BF_GetSpeedLevel() + 1);
            Print("[NNFXLitePro1] Speed -> ", BF_GetSpeedLevel(),
                  " (", BF_GetSpeedMs(), "ms)");
            break;

        case HUD_CMD_SLOWER:
            BF_SetSpeed(BF_GetSpeedLevel() - 1);
            Print("[NNFXLitePro1] Speed -> ", BF_GetSpeedLevel(),
                  " (", BF_GetSpeedMs(), "ms)");
            break;

        case HUD_CMD_STOP:
            Print("[NNFXLitePro1] STOP — finalizing sim.");
            EndTest();
            break;
    }
}

//+------------------------------------------------------------------+
//| Feed one bar and process signals / exits
//+------------------------------------------------------------------+
void ProcessNextBar()
{
    if(!BF_FeedNextBar())
    {
        Print("[NNFXLitePro1] All bars fed — sim complete.");
        EndTest();
        return;
    }

    // Refresh offline chart to show the new bar
    string simSymbol = g_Pair + "_SIM";
    ChartSetSymbolPeriod(g_SimChartId, simSymbol, PERIOD_D1);

    int barNum = BF_GetCurrentBarNum();

    // Need at least 2 bars for crossover detection
    if(barNum < 2)
    {
        // Still update HUD with progress
        HUD_Update(g_SimChartId, barNum, BF_GetTotalBars(),
                   BF_GetCurrentDate(), ST_GetBalance(), BF_GetSpeedLevel(),
                   ST_GetWins(), ST_GetLosses(), ST_GetProfitFactor(),
                   0, 0.0, 0.0, 0.0);
        return;
    }

    //--- Check exit on open trade
    if(TE_InTrade())
    {
        int exitResult = TE_CheckExit();
        if(exitResult != 0)
        {
            int    dir   = TE_GetDirection();
            double entry = TE_GetEntry();
            double sl    = TE_GetSL();
            double tp    = TE_GetTP();
            double lots  = TE_GetLotSize();
            double pnl   = TE_GetLastPnL();
            string reason = (exitResult > 0 ? "TP" : "SL");

            ST_AddTrade(exitResult, pnl);
            CE_WriteTrade(barNum, BF_GetCurrentDate(),
                          dir, entry, sl, tp, reason,
                          lots, pnl, ST_GetBalance());
        }
    }

    //--- Check for new signal if flat
    if(!TE_InTrade())
    {
        int sig = SE_GetSignal();
        if(sig != 0)
            TE_OpenTrade(sig, ST_GetBalance());
    }

    //--- Update HUD
    HUD_Update(g_SimChartId, barNum, BF_GetTotalBars(),
               BF_GetCurrentDate(), ST_GetBalance(), BF_GetSpeedLevel(),
               ST_GetWins(), ST_GetLosses(), ST_GetProfitFactor(),
               TE_InTrade() ? TE_GetDirection() : 0,
               TE_InTrade() ? TE_GetEntry() : 0.0,
               TE_InTrade() ? TE_GetSL() : 0.0,
               TE_InTrade() ? TE_GetTP() : 0.0);
}

//+------------------------------------------------------------------+
//| Finalize: force-close open trade, write CSVs, mark stopped
//+------------------------------------------------------------------+
void EndTest()
{
    //--- Force-close any open trade
    if(TE_InTrade())
    {
        int    dir   = TE_GetDirection();
        double entry = TE_GetEntry();
        double sl    = TE_GetSL();
        double tp    = TE_GetTP();
        double lots  = TE_GetLotSize();

        TE_ForceClose();
        double pnl = TE_GetLastPnL();
        ST_AddTrade((pnl >= 0.0 ? 1 : -1), pnl);
        CE_WriteTrade(BF_GetCurrentBarNum(), BF_GetCurrentDate(),
                      dir, entry, sl, tp, "CLOSE",
                      lots, pnl, ST_GetBalance());
    }

    //--- Write summary CSV
    CE_FinishTest(ST_GetWins(), ST_GetLosses(),
                  g_Balance, ST_GetBalance(),
                  ST_GetGrossProfit(), ST_GetGrossLoss());

    //--- Mark stopped
    g_State = STATE_STOPPED;
    EventKillTimer();

    HUD_SetState(g_SimChartId, "State: STOPPED", clrDimGray);

    Print("[NNFXLitePro1] Sim finished.",
          " Trades=", ST_GetTotalTrades(),
          " Wins=", ST_GetWins(),
          " Losses=", ST_GetLosses(),
          " Balance=", DoubleToStr(ST_GetBalance(), 2),
          " PF=", DoubleToStr(ST_GetProfitFactor(), 3));
}
```

- [ ] **Step 2: Compile**

Run compile command. Expected: 0 errors, 0 warnings.

**Potential issues to watch for:**
- If `bar_feeder.mqh` still references any `GV_*` or `NNFXLP_*` symbols, the compile will fail — go back to Task 4 and clean them.
- If any of the unchanged includes (`signal_engine`, `trade_engine`, etc.) reference `global_vars.mqh`, those will need the `#include` removed too. Check compile errors and fix.

- [ ] **Step 3: Commit**

```bash
git add backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePro1.mq4
git commit -m "Rewrite NNFXLitePro1.mq4: single-EA with launcher, state machine, 200ms timer"
```

---

### Task 6: Delete old files

**Files:**
- Delete: `NNFXLiteSetup.mq4`
- Delete: `NNFXLitePanel.mq4`
- Delete: `include/NNFXLite/global_vars.mqh`

These are now dead code — their functionality has been absorbed into the new includes.

- [ ] **Step 1: Delete the files**

```bash
cd "C:/Users/win10pro/OneDrive/Desktop/claude code project"
git rm backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLiteSetup.mq4
git rm backtester/bridge/mt4_runner/NNFXLitePro1/NNFXLitePanel.mq4
git rm backtester/bridge/mt4_runner/NNFXLitePro1/include/NNFXLite/global_vars.mqh
```

- [ ] **Step 2: Compile to verify nothing depends on deleted files**

Run compile command. Expected: 0 errors, 0 warnings.

If compilation fails, one of the unchanged includes still has `#include <NNFXLite/global_vars.mqh>`. Remove it and retry.

- [ ] **Step 3: Commit**

```bash
git commit -m "Delete NNFXLiteSetup, NNFXLitePanel, global_vars: code absorbed into v2 includes"
```

---

### Task 7: Update deploy.bat

**Files:**
- Modify: `deploy.bat`

The deploy script needs to copy the 3 new include files and stop copying the deleted files.

- [ ] **Step 1: Read current deploy.bat**

Read `backtester/bridge/mt4_runner/NNFXLitePro1/deploy.bat` to understand current copy commands.

- [ ] **Step 2: Update deploy.bat**

Update the file copy list to:
- Add: `hst_builder.mqh`, `hud_manager.mqh`, `launcher.mqh`
- Remove: any references to `NNFXLiteSetup.mq4`, `NNFXLitePanel.mq4`, `global_vars.mqh`
- Keep: `bar_feeder.mqh`, `signal_engine.mqh`, `trade_engine.mqh`, `stats_engine.mqh`, `csv_exporter.mqh`

The exact edits depend on the current file contents — read first, then edit.

- [ ] **Step 3: Compile and test deploy**

Run compile command. Then run `deploy.bat` and verify it copies all files successfully.

- [ ] **Step 4: Commit**

```bash
git add backtester/bridge/mt4_runner/NNFXLitePro1/deploy.bat
git commit -m "Update deploy.bat: add new includes, remove deleted files"
```

---

### Task 8: Manual Acceptance Testing in MT4

No code changes in this task — this is the manual verification checklist.

- [ ] **Step 1: Deploy to MT4**

Run `deploy.bat` to copy files to the MT4 data path.

- [ ] **Step 2: Test launcher screen**

1. Open MT4
2. Open any live chart (e.g. EURUSD D1)
3. Drag NNFXLitePro1 EA onto the chart
4. Verify: launcher screen appears with Pair, Start Date, End Date, Balance fields
5. Verify: fields are pre-filled from extern inputs
6. Verify: fields are editable
7. Verify: "START SIMULATION" button is visible

- [ ] **Step 3: Test sim startup**

1. Click "START SIMULATION"
2. Verify: Experts log shows HST build success
3. Verify: offline chart opens automatically
4. Verify: host chart is no longer in front
5. Verify: HUD appears on offline chart (title, state, buttons)
6. Verify: state shows "PLAYING"
7. Verify: bars start feeding (bar counter incrementing)

- [ ] **Step 4: Test HUD buttons**

1. Click PAUSE — verify state changes to PAUSED, bars stop
2. Click STEP — verify one bar feeds
3. Click RESUME — verify state changes to PLAYING, bars resume
4. Click >> FWD — verify speed increases (check Experts log)
5. Click << SLW — verify speed decreases
6. Click STOP — verify sim stops, CSV written (check Experts log)

- [ ] **Step 5: Test error cases**

1. Remove EA from chart mid-sim — verify graceful shutdown (CSV written, no crash)
2. Enter invalid date range on launcher — verify error message in log, stays on launcher
3. Enter empty pair name — verify error message in log, stays on launcher

- [ ] **Step 6: Tag and push if all tests pass**

```bash
git tag v2.0_launcher_pass
git push --tags
```

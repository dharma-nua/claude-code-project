//+------------------------------------------------------------------+
//| ui_manager.mqh — Chart object UI, screen routing, layout        |
//| NNFX Sim EA Platform v2                                          |
//+------------------------------------------------------------------+
#ifndef NNFX_UI_MANAGER_MQH
#define NNFX_UI_MANAGER_MQH

//+------------------------------------------------------------------+
//| Layout constants
#define UI_X0         10      // Panel left edge
#define UI_Y0         30      // Panel top edge
#define UI_W          320     // Panel width
#define UI_ROW_H      24      // Row height
#define UI_BTN_H      22      // Button height
#define UI_EDIT_H     20      // Edit field height
#define UI_GAP        4       // Gap between elements
#define UI_PANEL_BG   C'20,20,30'
#define UI_BTN_BG     C'40,40,60'
#define UI_BTN_FG     clrWhite
#define UI_ACCENT     C'255,176,0'      // Amber
#define UI_ACCENT2    C'0,200,180'      // Teal
#define UI_LABEL_FG   C'200,200,200'
#define UI_FONT       "Consolas"
#define UI_FONT_SZ    9
#define UI_PREFIX     "NNFX_SIM."

// Screen IDs
#define SCREEN_LAUNCHER   0
#define SCREEN_NEWSIM     1
#define SCREEN_WORKSPACE  2
#define SCREEN_DATACENTER 3
#define SCREEN_HUD        4
#define SCREEN_STATS      5

int    g_UI_CurrentScreen  = -1;
bool   g_UI_Initialized    = false;

// Workspace state tracking
int    g_UI_SigType        = 0;   // 0=CROSS 1=ZERO 2=STATE
int    g_UI_StateBuyRule   = 0;   // STATE_RULE index
int    g_UI_StateSellRule  = 1;
string g_UI_StateRuleNames[4];

// Forward declarations for functions called from UI
void SM_Transition(int newState, string reason);
void Persistence_SavePreset(string name);
void Persistence_LoadPreset(string name);
bool IndEngine_ParseParams(string vals, string types);
string IndEngine_GetParamsStatus();
void IndEngine_SetConfig(string name, string paramValStr, string paramTypeStr,
                          int sigType, int fastBuf, int slowBuf,
                          double buyThresh, double sellThresh,
                          int stateBuyRule, int stateSellRule, double stateLevel);
bool IndEngine_Validate(string sym, int tf, int fromShift, int toShift, int &b, int &s);
void RE_ToggleAuto();
void TradeEngine_ManualBuy(string sym, double lots, double sl, double tp);
void TradeEngine_ManualSell(string sym, double lots, double sl, double tp);
void TradeEngine_CloseAll(string sym);
void ReportExporter_FlushAll();
void UI_StatsTabSwitch(string objName);

//+------------------------------------------------------------------+
void UI_Init()
{
    g_UI_StateRuleNames[0] = "TO_POSITIVE";
    g_UI_StateRuleNames[1] = "TO_NEGATIVE";
    g_UI_StateRuleNames[2] = "ABOVE_LEVEL";
    g_UI_StateRuleNames[3] = "BELOW_LEVEL";
    g_UI_Initialized = true;
}

//+------------------------------------------------------------------+
// Delete all NNFX_SIM objects
void UI_ClearAll()
{
    ObjectsDeleteAll(0, UI_PREFIX);
}

//+------------------------------------------------------------------+
// Helper: create background rectangle
void _UI_Rect(string name, int x, int y, int w, int h, color bg, color border)
{
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE,      w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE,      h);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    bg);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, border);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_BACK,       false);
}

//+------------------------------------------------------------------+
// Helper: create label
void _UI_Label(string name, int x, int y, int w, string text, color fg, int fsz)
{
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0,  name, OBJPROP_TEXT,      text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     fg);
    ObjectSetString(0,  name, OBJPROP_FONT,      UI_FONT);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  fsz);
}

//+------------------------------------------------------------------+
// Helper: create button
void _UI_Button(string name, int x, int y, int w, int h, string text, color bg, color fg)
{
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE,     w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE,     h);
    ObjectSetString(0,  name, OBJPROP_TEXT,      text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     fg);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,   bg);
    ObjectSetString(0,  name, OBJPROP_FONT,      UI_FONT);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  UI_FONT_SZ);
    ObjectSetInteger(0, name, OBJPROP_STATE,     false);
}

//+------------------------------------------------------------------+
// Helper: create edit field
void _UI_Edit(string name, int x, int y, int w, int h, string text, bool readOnly)
{
    if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE,     w);
    ObjectSetInteger(0, name, OBJPROP_YSIZE,     h);
    ObjectSetString(0,  name, OBJPROP_TEXT,      text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     clrWhite);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,   C'30,30,50');
    ObjectSetString(0,  name, OBJPROP_FONT,      UI_FONT);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  UI_FONT_SZ);
    ObjectSetInteger(0, name, OBJPROP_READONLY,  readOnly);
}

//+------------------------------------------------------------------+
// Get edit field text
string _UI_EditGet(string name)
{
    return ObjectGetString(0, name, OBJPROP_TEXT);
}

//+------------------------------------------------------------------+
// Set edit field text
void _UI_EditSet(string name, string text)
{
    ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| SCREEN 0: LAUNCHER                                               |
//+------------------------------------------------------------------+
void UI_DrawLauncher()
{
    int x = UI_X0, y = UI_Y0;
    int w = UI_W;

    // Panel background
    _UI_Rect(UI_PREFIX+"LAUNCHER.BG", x, y, w, 200, UI_PANEL_BG, UI_ACCENT);

    // Title
    _UI_Label(UI_PREFIX+"LAUNCHER.LBL.TITLE", x+8, y+8, w-16,
              "NNFX SIM EA v2.0", UI_ACCENT, 11);
    _UI_Label(UI_PREFIX+"LAUNCHER.LBL.SUBTITLE", x+8, y+26, w-16,
              "Simulation Platform", UI_LABEL_FG, UI_FONT_SZ);

    int by = y + 52;
    _UI_Button(UI_PREFIX+"LAUNCHER.BTN.NEW_SIM",   x+8,   by,    w-16, UI_BTN_H, "[ New Simulation ]",  UI_ACCENT,  clrBlack);
    by += UI_BTN_H + UI_GAP;
    _UI_Button(UI_PREFIX+"LAUNCHER.BTN.LOAD_SIM",  x+8,   by,    w-16, UI_BTN_H, "[ Load Session ]",    UI_BTN_BG,  UI_BTN_FG);
    by += UI_BTN_H + UI_GAP;
    _UI_Button(UI_PREFIX+"LAUNCHER.BTN.DATA_CENTER", x+8, by,    w-16, UI_BTN_H, "[ Data Center ]",     UI_BTN_BG,  UI_BTN_FG);
    by += UI_BTN_H + UI_GAP + 4;

    _UI_Label(UI_PREFIX+"LAUNCHER.LBL.RECENT_HDR", x+8, by, w-16, "Recent Sessions:", UI_LABEL_FG, UI_FONT_SZ);
    by += UI_ROW_H;
    for(int i = 0; i < 5; i++)
    {
        string lname = UI_PREFIX + "LAUNCHER.LBL.RECENT_" + IntegerToString(i);
        _UI_Label(lname, x+12, by + i * (UI_FONT_SZ + 4), w-16, "—", C'100,100,120', UI_FONT_SZ);
    }
}

//+------------------------------------------------------------------+
//| SCREEN 1: NEW SIM CONFIG                                         |
//+------------------------------------------------------------------+
void UI_DrawNewSim()
{
    int x = UI_X0, y = UI_Y0;
    int w = UI_W;
    int panelH = 380;
    _UI_Rect(UI_PREFIX+"NEWSIM.BG", x, y, w, panelH, UI_PANEL_BG, UI_ACCENT);

    _UI_Label(UI_PREFIX+"NEWSIM.LBL.TITLE", x+8, y+8, w-16, "New Simulation", UI_ACCENT, 11);

    int row = y + 32;
    int lw  = 120, ew = w - lw - 20;
    int ex  = x + lw + 4;

    // Symbol
    _UI_Label(UI_PREFIX+"NEWSIM.LBL.SYMBOL",   x+8, row+2, lw, "Symbol:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"NEWSIM.EDIT.SYMBOL",    ex,  row,  ew,  UI_EDIT_H, g_CFG_Symbol, false);
    row += UI_ROW_H;

    // Balance
    _UI_Label(UI_PREFIX+"NEWSIM.LBL.BALANCE",   x+8, row+2, lw, "Balance:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"NEWSIM.EDIT.BALANCE",    ex,  row,  ew,  UI_EDIT_H, DoubleToString(g_CFG_Balance, 2), false);
    row += UI_ROW_H;

    // Start Date
    _UI_Label(UI_PREFIX+"NEWSIM.LBL.START_DATE", x+8, row+2, lw, "Start Date:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"NEWSIM.EDIT.START_DATE", ex,  row,  ew,  UI_EDIT_H, g_CFG_StartDate, false);
    row += UI_ROW_H;

    // End Date
    _UI_Label(UI_PREFIX+"NEWSIM.LBL.END_DATE",   x+8, row+2, lw, "End Date:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"NEWSIM.EDIT.END_DATE",   ex,  row,  ew,  UI_EDIT_H, g_CFG_EndDate, false);
    row += UI_ROW_H;

    // Spread Mode
    _UI_Label(UI_PREFIX+"NEWSIM.LBL.SPREAD_MODE", x+8, row+2, lw, "Spread Mode:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"NEWSIM.EDIT.SPREAD_MODE",  ex,  row,  ew,  UI_EDIT_H, IntegerToString(g_CFG_SpreadMode), false);
    row += UI_ROW_H;

    // Fixed Spread Pips
    _UI_Label(UI_PREFIX+"NEWSIM.LBL.FIXED_SPREAD", x+8, row+2, lw, "Fixed Spread:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"NEWSIM.EDIT.FIXED_SPREAD",  ex,  row,  ew,  UI_EDIT_H, DoubleToString(g_CFG_FixedSpreadPips, 2), false);
    row += UI_ROW_H;

    // Commission
    _UI_Label(UI_PREFIX+"NEWSIM.LBL.COMMISSION", x+8, row+2, lw, "Commission RT:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"NEWSIM.EDIT.COMMISSION",  ex,  row,  ew,  UI_EDIT_H, DoubleToString(g_CFG_CommissionRT, 2), false);
    row += UI_ROW_H;

    // Leverage
    _UI_Label(UI_PREFIX+"NEWSIM.LBL.LEVERAGE",   x+8, row+2, lw, "Leverage:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"NEWSIM.EDIT.LEVERAGE",    ex,  row,  ew,  UI_EDIT_H, IntegerToString(g_CFG_Leverage), false);
    row += UI_ROW_H + 4;

    // Buttons row
    int bw = (w - 24) / 4;
    _UI_Button(UI_PREFIX+"NEWSIM.BTN.START",       x+8,         row, bw,    UI_BTN_H, "Start",       UI_ACCENT,  clrBlack);
    _UI_Button(UI_PREFIX+"NEWSIM.BTN.SAVE_PRESET", x+8+bw+4,   row, bw,    UI_BTN_H, "Save",        UI_BTN_BG,  UI_BTN_FG);
    _UI_Button(UI_PREFIX+"NEWSIM.BTN.LOAD_PRESET", x+8+bw*2+8, row, bw,    UI_BTN_H, "Load",        UI_BTN_BG,  UI_BTN_FG);
    _UI_Button(UI_PREFIX+"NEWSIM.BTN.BACK",        x+8+bw*3+12, row, bw-4, UI_BTN_H, "Back",        C'60,20,20', clrRed);
}

//+------------------------------------------------------------------+
//| SCREEN 2: WORKSPACE (Indicator Config)                           |
//+------------------------------------------------------------------+
void UI_DrawWorkspace()
{
    int x = UI_X0, y = UI_Y0;
    int w = UI_W;
    int panelH = 460;
    _UI_Rect(UI_PREFIX+"WORKSPACE.BG", x, y, w, panelH, UI_PANEL_BG, UI_ACCENT2);

    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.TITLE", x+8, y+8, w-16, "Indicator Workspace", UI_ACCENT2, 11);

    int row = y + 32;
    int lw  = 120, ew = w - lw - 20;
    int ex  = x + lw + 4;

    // Indicator Name
    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.IND_NAME", x+8, row+2, lw, "Indicator:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.IND_NAME",  ex,  row, ew, UI_EDIT_H, g_CFG_C1Name, false);
    row += UI_ROW_H;

    // Params values
    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.IND_PARAMS", x+8, row+2, lw, "Params:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.IND_PARAMS",  ex,  row, ew, UI_EDIT_H, g_CFG_C1Params, false);
    row += UI_ROW_H;

    // Param types
    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.IND_PARAM_TYPES", x+8, row+2, lw, "Param Types:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.IND_PARAM_TYPES",  ex,  row, ew, UI_EDIT_H, g_CFG_C1ParamTypes, false);
    row += UI_ROW_H;

    // Params status label
    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.PARAMS_STATUS", x+8, row, w-16, "Params OK", C'0,200,100', UI_FONT_SZ);
    row += UI_ROW_H;

    // Signal type buttons
    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.SIG_TYPE", x+8, row+2, lw, "Signal Type:", UI_LABEL_FG, UI_FONT_SZ);
    int bw3 = (ew - 8) / 3;
    color cCross  = (g_UI_SigType == 0) ? UI_ACCENT  : UI_BTN_BG;
    color cZero   = (g_UI_SigType == 1) ? UI_ACCENT  : UI_BTN_BG;
    color cState  = (g_UI_SigType == 2) ? UI_ACCENT  : UI_BTN_BG;
    _UI_Button(UI_PREFIX+"WORKSPACE.BTN.SIG_TYPE_CROSS", ex,          row, bw3,   UI_BTN_H, "CROSS",  cCross, clrBlack);
    _UI_Button(UI_PREFIX+"WORKSPACE.BTN.SIG_TYPE_ZERO",  ex+bw3+4,   row, bw3,   UI_BTN_H, "ZERO",   cZero,  clrBlack);
    _UI_Button(UI_PREFIX+"WORKSPACE.BTN.SIG_TYPE_STATE", ex+bw3*2+8, row, bw3-4, UI_BTN_H, "STATE",  cState, clrBlack);
    row += UI_ROW_H;

    // Buffer fields
    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.FAST_BUF", x+8, row+2, lw, "Fast/Buy Buf:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.FAST_BUF",  ex,  row, 40, UI_EDIT_H, IntegerToString(g_CFG_FastBuf), false);
    row += UI_ROW_H;

    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.SLOW_BUF", x+8, row+2, lw, "Slow/Sell Buf:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.SLOW_BUF",  ex,  row, 40, UI_EDIT_H, IntegerToString(g_CFG_SlowBuf), false);
    row += UI_ROW_H;

    // Thresholds (for ZERO_CROSS mode)
    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.THRESHOLD", x+8, row+2, lw, "Buy Threshold:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.THRESHOLD",  ex,  row, ew, UI_EDIT_H, DoubleToString(g_CFG_BuyThresh, 4), false);
    row += UI_ROW_H;

    // STATE_CHANGE expansion (visible when state mode)
    if(g_UI_SigType == 2)
    {
        _UI_Label(UI_PREFIX+"WORKSPACE.LBL.STATE_RULE_BUY", x+8, row+2, lw, "Buy Rule:", UI_LABEL_FG, UI_FONT_SZ);
        _UI_Button(UI_PREFIX+"WORKSPACE.BTN.STATE_RULE_BUY", ex, row, ew, UI_BTN_H,
                   g_UI_StateRuleNames[g_UI_StateBuyRule], UI_BTN_BG, UI_ACCENT);
        row += UI_ROW_H;

        _UI_Label(UI_PREFIX+"WORKSPACE.LBL.STATE_RULE_SELL", x+8, row+2, lw, "Sell Rule:", UI_LABEL_FG, UI_FONT_SZ);
        _UI_Button(UI_PREFIX+"WORKSPACE.BTN.STATE_RULE_SELL", ex, row, ew, UI_BTN_H,
                   g_UI_StateRuleNames[g_UI_StateSellRule], UI_BTN_BG, UI_ACCENT);
        row += UI_ROW_H;

        _UI_Label(UI_PREFIX+"WORKSPACE.LBL.STATE_LEVEL", x+8, row+2, lw, "State Level:", UI_LABEL_FG, UI_FONT_SZ);
        _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.STATE_LEVEL", ex, row, ew, UI_EDIT_H, DoubleToString(g_CFG_StateLevel, 4), false);
        row += UI_ROW_H;
    }

    // SL/TP/MM fields
    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.SL_MODE", x+8, row+2, lw, "SL Mode(0/1):", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.SL_MODE",  ex,  row, 40, UI_EDIT_H, IntegerToString(g_CFG_SLMode), false);
    row += UI_ROW_H;

    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.ATR_MULT", x+8, row+2, lw, "ATR Mult:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.ATR_MULT",  ex,  row, 60, UI_EDIT_H, DoubleToString(g_CFG_ATRMult, 2), false);
    row += UI_ROW_H;

    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.RR", x+8, row+2, lw, "Risk:Reward:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.RR",  ex,  row, 60, UI_EDIT_H, DoubleToString(g_CFG_RR, 2), false);
    row += UI_ROW_H;

    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.RISK_PCT", x+8, row+2, lw, "Risk %:", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"WORKSPACE.EDIT.RISK_PCT",  ex,  row, 60, UI_EDIT_H, DoubleToString(g_CFG_RiskPct, 2), false);
    row += UI_ROW_H + 4;

    // Action buttons
    int bwh = (w - 20) / 2 - 2;
    _UI_Button(UI_PREFIX+"WORKSPACE.BTN.VALIDATE",    x+8,         row, bwh, UI_BTN_H, "Validate",      UI_BTN_BG,  UI_ACCENT);
    _UI_Button(UI_PREFIX+"WORKSPACE.BTN.LOCK_LAUNCH", x+8+bwh+4,  row, bwh, UI_BTN_H, "Lock & Launch", UI_ACCENT,  clrBlack);
    row += UI_BTN_H + 4;
    _UI_Button(UI_PREFIX+"WORKSPACE.BTN.BACK",        x+8,         row, 80, UI_BTN_H, "Back",          C'60,20,20', clrRed);

    // Validate status
    _UI_Label(UI_PREFIX+"WORKSPACE.LBL.VALIDATE_STATUS", x+8, row, w-16, "", C'0,200,100', UI_FONT_SZ);
}

//+------------------------------------------------------------------+
//| SCREEN 3: DATA CENTER                                            |
//+------------------------------------------------------------------+
void UI_DrawDataCenter()
{
    int x = UI_X0, y = UI_Y0;
    int w = UI_W;
    _UI_Rect(UI_PREFIX+"DATACENTER.BG", x, y, w, 200, UI_PANEL_BG, UI_ACCENT);

    _UI_Label(UI_PREFIX+"DATACENTER.LBL.TITLE", x+8, y+8, w-16, "Data Center", UI_ACCENT, 11);

    int row = y + 32;
    for(int i = 0; i < 5; i++)
    {
        string lname = UI_PREFIX + "DATACENTER.LBL.SYM_STATUS_" + IntegerToString(i);
        _UI_Label(lname, x+12, row + i * (UI_FONT_SZ + 6), w-16, "—", UI_LABEL_FG, UI_FONT_SZ);
    }

    int brow = y + 140;
    int bw   = (w - 32) / 3;
    _UI_Button(UI_PREFIX+"DATACENTER.BTN.IMPORT",  x+8,         brow, bw, UI_BTN_H, "Import",  UI_BTN_BG, UI_BTN_FG);
    _UI_Button(UI_PREFIX+"DATACENTER.BTN.REINDEX", x+8+bw+8,   brow, bw, UI_BTN_H, "Reindex", UI_BTN_BG, UI_BTN_FG);
    _UI_Button(UI_PREFIX+"DATACENTER.BTN.CLEAR",   x+8+bw*2+16, brow, bw, UI_BTN_H, "Clear",   C'60,20,20', clrRed);

    brow += UI_BTN_H + 8;
    _UI_Button(UI_PREFIX+"DATACENTER.BTN.BACK", x+8, brow, 80, UI_BTN_H, "Back", C'60,20,20', clrRed);
}

//+------------------------------------------------------------------+
//| SCREEN 4: HUD (Simulation Running)                               |
//+------------------------------------------------------------------+
void UI_DrawHUD()
{
    int x  = UI_X0, y = UI_Y0;
    int w  = UI_W;
    int h  = 330;
    _UI_Rect(UI_PREFIX+"HUD.BG", x, y, w, h, UI_PANEL_BG, UI_ACCENT2);

    _UI_Label(UI_PREFIX+"HUD.LBL.TITLE", x+8, y+8, w-16, "Simulation HUD", UI_ACCENT2, 11);

    // Sim info labels
    int row = y + 28;
    _UI_Label(UI_PREFIX+"HUD.LBL.TIME",   x+8,   row, 200, "Time: —",    UI_LABEL_FG, UI_FONT_SZ);
    _UI_Label(UI_PREFIX+"HUD.LBL.EQUITY", x+8,   row+14, 200, "Equity: —",  UI_LABEL_FG, UI_FONT_SZ);
    _UI_Label(UI_PREFIX+"HUD.LBL.PNL",   x+160, row+14, 160, "P&L: —",    UI_LABEL_FG, UI_FONT_SZ);
    _UI_Label(UI_PREFIX+"HUD.LBL.SHIFT", x+160, row, 160, "Shift: —",  UI_LABEL_FG, UI_FONT_SZ);
    row += 32;

    // Playback controls row 1
    int bw5 = (w - 20) / 5 - 1;
    _UI_Button(UI_PREFIX+"HUD.BTN.PREV",     x+8,           row, bw5, UI_BTN_H, "|<",      UI_BTN_BG,  UI_BTN_FG);
    _UI_Button(UI_PREFIX+"HUD.BTN.PLAY",     x+8+bw5+2,    row, bw5, UI_BTN_H, "PLAY",    C'0,120,0', clrWhite);
    _UI_Button(UI_PREFIX+"HUD.BTN.PAUSE",    x+8+bw5*2+4,  row, bw5, UI_BTN_H, "PAUSE",   C'120,80,0', clrWhite);
    _UI_Button(UI_PREFIX+"HUD.BTN.NEXT",     x+8+bw5*3+6,  row, bw5, UI_BTN_H, ">|",      UI_BTN_BG,  UI_BTN_FG);
    _UI_Button(UI_PREFIX+"HUD.BTN.AUTO_TOGGLE", x+8+bw5*4+8, row, bw5-2, UI_BTN_H, "AUTO", UI_BTN_BG, UI_ACCENT);
    row += UI_BTN_H + UI_GAP;

    // Speed row
    int bw2 = (w - 20) / 2 - 2;
    _UI_Button(UI_PREFIX+"HUD.BTN.SPEED_DN", x+8,        row, bw2, UI_BTN_H, "Speed -", UI_BTN_BG, UI_BTN_FG);
    _UI_Button(UI_PREFIX+"HUD.BTN.SPEED_UP", x+8+bw2+4, row, bw2, UI_BTN_H, "Speed +", UI_BTN_BG, UI_BTN_FG);
    row += UI_BTN_H + UI_GAP + 4;

    // Trade input fields
    int lw = 60, ew = 60, efx = x + lw + 4;
    _UI_Label(UI_PREFIX+"HUD.LBL.LOT", x+8,   row+2, lw, "Lot:",     UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"HUD.EDIT.LOT",  efx,   row, ew, UI_EDIT_H, "0.01", false);
    _UI_Label(UI_PREFIX+"HUD.LBL.SL",  x+140, row+2, lw, "SL(pips):", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"HUD.EDIT.SL",   x+200, row, 50, UI_EDIT_H, "0", false);
    row += UI_ROW_H;
    _UI_Label(UI_PREFIX+"HUD.LBL.TP",  x+8,   row+2, lw, "TP(pips):", UI_LABEL_FG, UI_FONT_SZ);
    _UI_Edit(UI_PREFIX+"HUD.EDIT.TP",   efx,   row, ew, UI_EDIT_H, "0", false);
    row += UI_ROW_H + 4;

    // Manual trade buttons
    int bw3 = (w - 20) / 3 - 2;
    _UI_Button(UI_PREFIX+"HUD.BTN.BUY",       x+8,         row, bw3, UI_BTN_H, "BUY",       C'0,100,0',  clrWhite);
    _UI_Button(UI_PREFIX+"HUD.BTN.SELL",      x+8+bw3+4,  row, bw3, UI_BTN_H, "SELL",      C'100,0,0',  clrWhite);
    _UI_Button(UI_PREFIX+"HUD.BTN.CLOSE_ALL", x+8+bw3*2+8, row, bw3, UI_BTN_H, "CLOSE ALL", C'80,0,80',  clrWhite);
    row += UI_BTN_H + UI_GAP + 4;

    // Locked indicator
    _UI_Label(UI_PREFIX+"HUD.LBL.LOCKED", x+8, row, w-16, "Config LOCKED — Snapshot saved", C'0,200,100', UI_FONT_SZ);
    row += UI_ROW_H;

    // Stats button
    _UI_Button(UI_PREFIX+"HUD.BTN.STATS", x+8, row, 100, UI_BTN_H, "Stats Panel", UI_BTN_BG, UI_ACCENT);
}

//+------------------------------------------------------------------+
//| SCREEN 5: STATS PANEL                                            |
//+------------------------------------------------------------------+
void UI_DrawStats()
{
    int x = UI_X0, y = UI_Y0;
    int w = UI_W;
    int h = 400;
    _UI_Rect(UI_PREFIX+"STATS.BG", x, y, w, h, UI_PANEL_BG, UI_ACCENT);

    _UI_Label(UI_PREFIX+"STATS.LBL.TITLE", x+8, y+8, w-16, "Statistics", UI_ACCENT, 11);

    // Tab buttons
    int row = y + 28;
    int bwt = (w - 20) / 4 - 2;
    _UI_Button(UI_PREFIX+"STATS.BTN.TAB_OPEN",    x+8,           row, bwt, UI_BTN_H, "Open",    UI_ACCENT,  clrBlack);
    _UI_Button(UI_PREFIX+"STATS.BTN.TAB_HISTORY", x+8+bwt+4,   row, bwt, UI_BTN_H, "History", UI_BTN_BG,  UI_BTN_FG);
    _UI_Button(UI_PREFIX+"STATS.BTN.TAB_STATS",   x+8+bwt*2+8, row, bwt, UI_BTN_H, "Stats",   UI_BTN_BG,  UI_BTN_FG);
    _UI_Button(UI_PREFIX+"STATS.BTN.TAB_GRAPH",   x+8+bwt*3+12, row, bwt, UI_BTN_H, "Graph",   UI_BTN_BG,  UI_BTN_FG);
    row += UI_BTN_H + 8;

    // Stats display
    int totalTrades, wins, losses;
    double winRate, totalPips, avgPips, maxDD, expectancy, totalCommission, avgSpread;
    StatsEngine_GetSummary(totalTrades, wins, losses, winRate, totalPips,
                            avgPips, maxDD, expectancy, totalCommission, avgSpread);

    string metrics[][2];
    int mCount = 10;
    ArrayResize(metrics, mCount);
    metrics[0][0] = "Total Trades:";  metrics[0][1] = IntegerToString(totalTrades);
    metrics[1][0] = "Wins/Losses:";   metrics[1][1] = IntegerToString(wins) + " / " + IntegerToString(losses);
    metrics[2][0] = "Win Rate:";      metrics[2][1] = DoubleToString(winRate, 1) + "%";
    metrics[3][0] = "Total Pips:";    metrics[3][1] = DoubleToString(totalPips, 2);
    metrics[4][0] = "Avg Pips/Trade:"; metrics[4][1] = DoubleToString(avgPips, 2);
    metrics[5][0] = "Max Drawdown:";  metrics[5][1] = DoubleToString(maxDD, 2) + "%";
    metrics[6][0] = "Expectancy:";    metrics[6][1] = DoubleToString(expectancy, 2) + " pips";
    metrics[7][0] = "Avg Spread:";    metrics[7][1] = DoubleToString(avgSpread, 2) + " pips";
    metrics[8][0] = "Total Commiss:"; metrics[8][1] = DoubleToString(totalCommission, 2);
    metrics[9][0] = "Session ID:";    metrics[9][1] = g_CFG_SessionId;

    int lw = 140;
    for(int i = 0; i < mCount; i++)
    {
        string lnL = UI_PREFIX + "STATS.LBL.M_KEY_" + IntegerToString(i);
        string lnV = UI_PREFIX + "STATS.LBL.M_VAL_" + IntegerToString(i);
        _UI_Label(lnL, x+8,    row + i * (UI_FONT_SZ + 6), lw,      metrics[i][0], UI_LABEL_FG, UI_FONT_SZ);
        _UI_Label(lnV, x+lw+4, row + i * (UI_FONT_SZ + 6), w-lw-20, metrics[i][1], UI_ACCENT,   UI_FONT_SZ);
    }
    row += mCount * (UI_FONT_SZ + 6) + 8;

    // Export buttons
    int bw3 = (w - 20) / 3 - 2;
    _UI_Button(UI_PREFIX+"STATS.BTN.EXPORT_TRADES",  x+8,         row, bw3, UI_BTN_H, "Trades CSV",  UI_BTN_BG, UI_ACCENT2);
    _UI_Button(UI_PREFIX+"STATS.BTN.EXPORT_SIGNALS", x+8+bw3+4,  row, bw3, UI_BTN_H, "Signals CSV", UI_BTN_BG, UI_ACCENT2);
    _UI_Button(UI_PREFIX+"STATS.BTN.EXPORT_SUMMARY", x+8+bw3*2+8, row, bw3, UI_BTN_H, "Summary CSV", UI_BTN_BG, UI_ACCENT2);
    row += UI_BTN_H + 8;

    _UI_Button(UI_PREFIX+"STATS.BTN.BACK", x+8, row, 80, UI_BTN_H, "Back", C'60,20,20', clrRed);
}

//+------------------------------------------------------------------+
void UI_ShowScreen(int screen)
{
    UI_ClearAll();
    g_UI_CurrentScreen = screen;

    switch(screen)
    {
        case SCREEN_LAUNCHER:   UI_DrawLauncher();   break;
        case SCREEN_NEWSIM:     UI_DrawNewSim();     break;
        case SCREEN_WORKSPACE:  UI_DrawWorkspace();  break;
        case SCREEN_DATACENTER: UI_DrawDataCenter(); break;
        case SCREEN_HUD:        UI_DrawHUD();        break;
        case SCREEN_STATS:      UI_DrawStats();      break;
    }
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
void UI_OnChartResize()
{
    if(g_UI_CurrentScreen >= 0)
        UI_ShowScreen(g_UI_CurrentScreen);
}

//+------------------------------------------------------------------+
// Update HUD labels with current sim state
void UI_UpdateHUD()
{
    if(g_UI_CurrentScreen != SCREEN_HUD) return;

    datetime t    = RE_GetCurrentTime();
    int      shift = RE_GetCurrentShift();
    double   eq   = g_TE_SimBalance;
    double   pnl  = eq - g_CFG_Balance;

    string timeStr  = (t > 0) ? TimeToString(t, TIME_DATE | TIME_MINUTES) : "—";
    string equityStr = DoubleToString(eq, 2);
    string pnlStr    = (pnl >= 0 ? "+" : "") + DoubleToString(pnl, 2);
    string shiftStr  = IntegerToString(shift);

    ObjectSetString(0, UI_PREFIX+"HUD.LBL.TIME",   OBJPROP_TEXT, "Time: " + timeStr);
    ObjectSetString(0, UI_PREFIX+"HUD.LBL.EQUITY", OBJPROP_TEXT, "Equity: " + equityStr);
    ObjectSetString(0, UI_PREFIX+"HUD.LBL.PNL",    OBJPROP_TEXT, "P&L: " + pnlStr);
    ObjectSetString(0, UI_PREFIX+"HUD.LBL.SHIFT",  OBJPROP_TEXT, "Shift: " + shiftStr);

    // Auto mode indicator on button
    string autoLabel = g_RE_AutoMode ? "AUTO ON" : "AUTO OFF";
    color  autoBg    = g_RE_AutoMode ? UI_ACCENT2 : UI_BTN_BG;
    ObjectSetString(0,  UI_PREFIX+"HUD.BTN.AUTO_TOGGLE", OBJPROP_TEXT,    autoLabel);
    ObjectSetInteger(0, UI_PREFIX+"HUD.BTN.AUTO_TOGGLE", OBJPROP_BGCOLOR, autoBg);

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
// Read config from NewSim edit fields into global g_CFG_*
void UI_NewSimReadFields()
{
    g_CFG_Symbol        = _UI_EditGet(UI_PREFIX+"NEWSIM.EDIT.SYMBOL");
    g_CFG_Balance       = StringToDouble(_UI_EditGet(UI_PREFIX+"NEWSIM.EDIT.BALANCE"));
    g_CFG_StartDate     = _UI_EditGet(UI_PREFIX+"NEWSIM.EDIT.START_DATE");
    g_CFG_EndDate       = _UI_EditGet(UI_PREFIX+"NEWSIM.EDIT.END_DATE");
    g_CFG_SpreadMode    = (int)StringToInteger(_UI_EditGet(UI_PREFIX+"NEWSIM.EDIT.SPREAD_MODE"));
    g_CFG_FixedSpreadPips = StringToDouble(_UI_EditGet(UI_PREFIX+"NEWSIM.EDIT.FIXED_SPREAD"));
    g_CFG_CommissionRT  = StringToDouble(_UI_EditGet(UI_PREFIX+"NEWSIM.EDIT.COMMISSION"));
    g_CFG_Leverage      = (int)StringToInteger(_UI_EditGet(UI_PREFIX+"NEWSIM.EDIT.LEVERAGE"));
}

//+------------------------------------------------------------------+
// Read config from Workspace edit fields
void UI_WorkspaceReadFields()
{
    g_CFG_C1Name       = _UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.IND_NAME");
    g_CFG_C1Params     = _UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.IND_PARAMS");
    g_CFG_C1ParamTypes = _UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.IND_PARAM_TYPES");
    g_CFG_FastBuf      = (int)StringToInteger(_UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.FAST_BUF"));
    g_CFG_SlowBuf      = (int)StringToInteger(_UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.SLOW_BUF"));
    g_CFG_BuyThresh    = StringToDouble(_UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.THRESHOLD"));
    g_CFG_SigType      = g_UI_SigType;
    g_CFG_StateBuyRule = g_UI_StateBuyRule;
    g_CFG_StateSellRule= g_UI_StateSellRule;
    g_CFG_SLMode       = (int)StringToInteger(_UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.SL_MODE"));
    g_CFG_ATRMult      = StringToDouble(_UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.ATR_MULT"));
    g_CFG_RR           = StringToDouble(_UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.RR"));
    g_CFG_RiskPct      = StringToDouble(_UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.RISK_PCT"));

    if(g_UI_SigType == 2)
        g_CFG_StateLevel = StringToDouble(_UI_EditGet(UI_PREFIX+"WORKSPACE.EDIT.STATE_LEVEL"));
}

//+------------------------------------------------------------------+
void UI_WorkspaceValidate()
{
    UI_WorkspaceReadFields();

    // Parse params
    bool paramsOK = true;
    string status = "Params OK (no inputs)";
    if(g_CFG_C1Params != "" && g_CFG_C1ParamTypes != "")
    {
        paramsOK = IndEngine_ParseParams(g_CFG_C1Params, g_CFG_C1ParamTypes);
        status   = IndEngine_GetParamsStatus();
    }

    // Update status label
    color sc = paramsOK ? C'0,200,100' : clrRed;
    ObjectSetString(0,  UI_PREFIX+"WORKSPACE.LBL.PARAMS_STATUS", OBJPROP_TEXT,  status);
    ObjectSetInteger(0, UI_PREFIX+"WORKSPACE.LBL.PARAMS_STATUS", OBJPROP_COLOR, sc);

    if(!paramsOK)
    {
        ObjectSetString(0, UI_PREFIX+"WORKSPACE.LBL.VALIDATE_STATUS", OBJPROP_TEXT, "VALIDATION FAILED");
        ObjectSetInteger(0, UI_PREFIX+"WORKSPACE.LBL.VALIDATE_STATUS", OBJPROP_COLOR, clrRed);
        return;
    }

    // Configure indicator engine
    IndEngine_SetConfig(g_CFG_C1Name, g_CFG_C1Params, g_CFG_C1ParamTypes,
                        g_CFG_SigType, g_CFG_FastBuf, g_CFG_SlowBuf,
                        g_CFG_BuyThresh, g_CFG_SellThresh,
                        g_CFG_StateBuyRule, g_CFG_StateSellRule, g_CFG_StateLevel);

    // Run validation over last 200 bars
    int buys = 0, sells = 0;
    string sym = (g_CFG_Symbol != "") ? g_CFG_Symbol : Symbol();
    IndEngine_Validate(sym, PERIOD_D1, 1, 200, buys, sells);

    string vStatus = StringFormat("Buys=%d Sells=%d in last 200 bars", buys, sells);
    ObjectSetString(0,  UI_PREFIX+"WORKSPACE.LBL.VALIDATE_STATUS", OBJPROP_TEXT,  vStatus);
    ObjectSetInteger(0, UI_PREFIX+"WORKSPACE.LBL.VALIDATE_STATUS", OBJPROP_COLOR, UI_ACCENT2);
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
void UI_WorkspaceSignalTypeSwitch(string objName)
{
    if(StringFind(objName, "CROSS") >= 0) g_UI_SigType = 0;
    else if(StringFind(objName, "ZERO") >= 0) g_UI_SigType = 1;
    else if(StringFind(objName, "STATE") >= 0) g_UI_SigType = 2;
    g_CFG_SigType = g_UI_SigType;
    UI_ShowScreen(SCREEN_WORKSPACE);
}

//+------------------------------------------------------------------+
void UI_WorkspaceStateRuleCycle(string objName)
{
    if(StringFind(objName, "STATE_RULE_BUY") >= 0)
        g_UI_StateBuyRule = (g_UI_StateBuyRule + 1) % 4;
    else if(StringFind(objName, "STATE_RULE_SELL") >= 0)
        g_UI_StateSellRule = (g_UI_StateSellRule + 1) % 4;
    g_CFG_StateBuyRule  = g_UI_StateBuyRule;
    g_CFG_StateSellRule = g_UI_StateSellRule;
    UI_ShowScreen(SCREEN_WORKSPACE);
}

//+------------------------------------------------------------------+
void UI_HUD_ToggleAuto()
{
    RE_ToggleAuto();
    UI_UpdateHUD();
}

//+------------------------------------------------------------------+
void UI_HUD_ManualBuy()
{
    double lots = StringToDouble(_UI_EditGet(UI_PREFIX+"HUD.EDIT.LOT"));
    double sl   = StringToDouble(_UI_EditGet(UI_PREFIX+"HUD.EDIT.SL"));
    double tp   = StringToDouble(_UI_EditGet(UI_PREFIX+"HUD.EDIT.TP"));
    TradeEngine_ManualBuy(Symbol(), lots, sl, tp);
    UI_UpdateHUD();
}

//+------------------------------------------------------------------+
void UI_HUD_ManualSell()
{
    double lots = StringToDouble(_UI_EditGet(UI_PREFIX+"HUD.EDIT.LOT"));
    double sl   = StringToDouble(_UI_EditGet(UI_PREFIX+"HUD.EDIT.SL"));
    double tp   = StringToDouble(_UI_EditGet(UI_PREFIX+"HUD.EDIT.TP"));
    TradeEngine_ManualSell(Symbol(), lots, sl, tp);
    UI_UpdateHUD();
}

//+------------------------------------------------------------------+
void UI_HUD_CloseAll()
{
    TradeEngine_CloseAll(Symbol());
    UI_UpdateHUD();
}

//+------------------------------------------------------------------+
void Persistence_SavePresetFromUI()
{
    UI_NewSimReadFields();
    Persistence_SavePreset("last_preset");
    Print("UI: Preset saved as 'last_preset'");
}

//+------------------------------------------------------------------+
void Persistence_LoadPresetToUI()
{
    if(Persistence_LoadPreset("last_preset"))
        UI_ShowScreen(SCREEN_NEWSIM);  // Redraw with loaded values
}

//+------------------------------------------------------------------+
void UI_StatsTabSwitch(string objName)
{
    // Redraw stats panel (tab content would go here)
    UI_ShowScreen(SCREEN_STATS);
}

#endif // NNFX_UI_MANAGER_MQH

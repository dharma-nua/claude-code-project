//+------------------------------------------------------------------+
//| NNFXLitePanel.mq4 — Control panel + HUD indicator               |
//| Attach to the EURUSD_SIM offline D1 chart.                       |
//| Reads GlobalVariables set by NNFXLitePro1 EA and renders HUD.   |
//| Buttons write GV commands that the EA reads in OnTimer.          |
//| NNFX Lite Pro 1                                                  |
//+------------------------------------------------------------------+
#property copyright "NNFX Lite Pro 1"
#property link      ""
#property version   "1.00"
#property strict
#property indicator_chart_window
#property indicator_buffers 0

#include <NNFXLite/global_vars.mqh>

//+------------------------------------------------------------------+
//| Layout constants
//+------------------------------------------------------------------+
#define PANEL_X       12
#define LBL_Y_TITLE   15
#define LBL_Y_STATE   38
#define LBL_Y_BAR     58
#define LBL_Y_BAL     78
#define LBL_Y_STATS   98
#define LBL_Y_TRADE   120
#define LBL_Y_PRICES  140
#define BTN_Y         165
#define BTN_W         58
#define BTN_H         20
#define BTN_GAP       62

//+------------------------------------------------------------------+
//| Object name constants
//+------------------------------------------------------------------+
#define OBJ_LBL_TITLE   "NNFXLP_LBL_TITLE"
#define OBJ_LBL_STATE   "NNFXLP_LBL_STATE"
#define OBJ_LBL_BAR     "NNFXLP_LBL_BAR"
#define OBJ_LBL_BAL     "NNFXLP_LBL_BAL"
#define OBJ_LBL_STATS   "NNFXLP_LBL_STATS"
#define OBJ_LBL_TRADE   "NNFXLP_LBL_TRADE"
#define OBJ_LBL_PRICES  "NNFXLP_LBL_PRICES"

#define OBJ_BTN_PLAY    "NNFXLP_BTN_PLAY"
#define OBJ_BTN_PAUSE   "NNFXLP_BTN_PAUSE"
#define OBJ_BTN_STEP    "NNFXLP_BTN_STEP"
#define OBJ_BTN_FASTER  "NNFXLP_BTN_FASTER"
#define OBJ_BTN_SLOWER  "NNFXLP_BTN_SLOWER"
#define OBJ_BTN_STOP    "NNFXLP_BTN_STOP"

//+------------------------------------------------------------------+
//| Helper: create or update a label
//+------------------------------------------------------------------+
void PanelLabel(string name, int x, int y, string text, color clr, int fontSize)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
        ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
        ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
        ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
        ObjectSetString(0,  name, OBJPROP_FONT,       "Consolas");
    }
    ObjectSetString(0,  name, OBJPROP_TEXT,      text);
    ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  fontSize);
}

//+------------------------------------------------------------------+
//| Helper: create a button (idempotent)
//+------------------------------------------------------------------+
void PanelButton(string name, int x, int y, string text)
{
    if(ObjectFind(0, name) >= 0) return;
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER,     CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE,  x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE,  y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE,      BTN_W);
    ObjectSetInteger(0, name, OBJPROP_YSIZE,      BTN_H);
    ObjectSetString(0,  name, OBJPROP_TEXT,       text);
    ObjectSetString(0,  name, OBJPROP_FONT,       "Consolas");
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE,   8);
    ObjectSetInteger(0, name, OBJPROP_COLOR,      clrWhite);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR,    C'50,50,60');
    ObjectSetInteger(0, name, OBJPROP_BORDERCOLOR,clrGray);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, name, OBJPROP_HIDDEN,     false);
    ObjectSetInteger(0, name, OBJPROP_STATE,      false);
}

//+------------------------------------------------------------------+
//| Create all panel objects
//+------------------------------------------------------------------+
void PanelCreate()
{
    PanelLabel(OBJ_LBL_TITLE,  PANEL_X, LBL_Y_TITLE,  "NNFX Lite Pro 1", clrGold,   10);
    PanelLabel(OBJ_LBL_STATE,  PANEL_X, LBL_Y_STATE,  "State: ---",       clrSilver,  9);
    PanelLabel(OBJ_LBL_BAR,    PANEL_X, LBL_Y_BAR,    "Bar: ---",         clrSilver,  9);
    PanelLabel(OBJ_LBL_BAL,    PANEL_X, LBL_Y_BAL,    "Balance: ---",     clrSilver,  9);
    PanelLabel(OBJ_LBL_STATS,  PANEL_X, LBL_Y_STATS,  "W:0  L:0  PF:---", clrSilver,  9);
    PanelLabel(OBJ_LBL_TRADE,  PANEL_X, LBL_Y_TRADE,  "Trade: NONE",      clrSilver,  9);
    PanelLabel(OBJ_LBL_PRICES, PANEL_X, LBL_Y_PRICES, "E:---  SL:---  TP:---", clrSilver, 9);

    int bx = PANEL_X;
    PanelButton(OBJ_BTN_PLAY,   bx, BTN_Y, "PLAY");   bx += BTN_GAP;
    PanelButton(OBJ_BTN_PAUSE,  bx, BTN_Y, "PAUSE");  bx += BTN_GAP;
    PanelButton(OBJ_BTN_STEP,   bx, BTN_Y, "STEP");   bx += BTN_GAP;
    PanelButton(OBJ_BTN_FASTER, bx, BTN_Y, ">> FWD"); bx += BTN_GAP;
    PanelButton(OBJ_BTN_SLOWER, bx, BTN_Y, "<< SLW"); bx += BTN_GAP;
    PanelButton(OBJ_BTN_STOP,   bx, BTN_Y, "STOP");
}

//+------------------------------------------------------------------+
//| Remove all panel objects
//+------------------------------------------------------------------+
void PanelDestroy()
{
    string names[] = {
        OBJ_LBL_TITLE, OBJ_LBL_STATE, OBJ_LBL_BAR,
        OBJ_LBL_BAL,   OBJ_LBL_STATS, OBJ_LBL_TRADE, OBJ_LBL_PRICES,
        OBJ_BTN_PLAY,  OBJ_BTN_PAUSE, OBJ_BTN_STEP,
        OBJ_BTN_FASTER,OBJ_BTN_SLOWER,OBJ_BTN_STOP
    };
    for(int i = 0; i < ArraySize(names); i++)
        ObjectDelete(0, names[i]);
}

//+------------------------------------------------------------------+
//| Refresh all labels from GVs
//+------------------------------------------------------------------+
void PanelUpdate()
{
    // EA not attached yet — GVs might not exist
    if(!GlobalVariableCheck(NNFXLP_STATE))
    {
        PanelLabel(OBJ_LBL_STATE,  PANEL_X, LBL_Y_STATE,  "State: waiting for EA", clrDimGray, 9);
        PanelLabel(OBJ_LBL_BAR,    PANEL_X, LBL_Y_BAR,    "",                       clrDimGray, 9);
        PanelLabel(OBJ_LBL_BAL,    PANEL_X, LBL_Y_BAL,    "",                       clrDimGray, 9);
        PanelLabel(OBJ_LBL_STATS,  PANEL_X, LBL_Y_STATS,  "",                       clrDimGray, 9);
        PanelLabel(OBJ_LBL_TRADE,  PANEL_X, LBL_Y_TRADE,  "",                       clrDimGray, 9);
        PanelLabel(OBJ_LBL_PRICES, PANEL_X, LBL_Y_PRICES, "",                       clrDimGray, 9);
        ChartRedraw(0);
        return;
    }

    // State
    int state = GV_GetInt(NNFXLP_STATE);
    string stateText;
    color  stateColor;
    switch(state)
    {
        case NNFXLP_STATE_PLAYING: stateText = "State: PLAYING"; stateColor = clrLimeGreen; break;
        case NNFXLP_STATE_PAUSED:  stateText = "State: PAUSED";  stateColor = clrYellow;    break;
        default:                   stateText = "State: STOPPED"; stateColor = clrDimGray;   break;
    }
    PanelLabel(OBJ_LBL_STATE, PANEL_X, LBL_Y_STATE, stateText, stateColor, 9);

    // Bar progress + date
    int      barCur = GV_GetInt(NNFXLP_BAR_CUR);
    int      barTot = GV_GetInt(NNFXLP_BAR_TOT);
    datetime date   = GV_GetDatetime(NNFXLP_DATE);
    string   barStr = "Bar: " + IntegerToString(barCur) + " / " + IntegerToString(barTot);
    if(date > 0) barStr += "   " + TimeToStr(date, TIME_DATE);
    PanelLabel(OBJ_LBL_BAR, PANEL_X, LBL_Y_BAR, barStr, clrSilver, 9);

    // Balance
    double bal    = GV_GetDouble(NNFXLP_BAL);
    int    speed  = GV_GetInt(NNFXLP_SPEED);
    string balStr = "Balance: $" + DoubleToStr(bal, 2) +
                    "   Speed: " + IntegerToString(speed);
    PanelLabel(OBJ_LBL_BAL, PANEL_X, LBL_Y_BAL, balStr, clrSilver, 9);

    // W / L / PF
    int    wins   = GV_GetInt(NNFXLP_WINS);
    int    losses = GV_GetInt(NNFXLP_LOSSES);
    double pf     = GV_GetDouble(NNFXLP_PF);
    color  pfColor = (pf >= 1.5) ? clrLimeGreen : (pf >= 1.0 ? clrYellow : clrTomato);
    if(wins + losses == 0) pfColor = clrSilver;
    string statsStr = "W:" + IntegerToString(wins) +
                      "  L:" + IntegerToString(losses) +
                      "  PF:" + (wins + losses > 0 ? DoubleToStr(pf, 2) : "---");
    PanelLabel(OBJ_LBL_STATS, PANEL_X, LBL_Y_STATS, statsStr, pfColor, 9);

    // Trade direction
    int    tradeDir = GV_GetInt(NNFXLP_TRADE);
    string tradeStr;
    color  tradeColor;
    if(tradeDir > 0)       { tradeStr = "Trade: BUY";  tradeColor = clrDodgerBlue; }
    else if(tradeDir < 0)  { tradeStr = "Trade: SELL"; tradeColor = clrTomato;     }
    else                   { tradeStr = "Trade: NONE"; tradeColor = clrDimGray;    }
    PanelLabel(OBJ_LBL_TRADE, PANEL_X, LBL_Y_TRADE, tradeStr, tradeColor, 9);

    // Entry / SL / TP
    string priceStr;
    if(tradeDir != 0)
    {
        double entry = GV_GetDouble(NNFXLP_ENTRY);
        double sl    = GV_GetDouble(NNFXLP_SL);
        double tp    = GV_GetDouble(NNFXLP_TP);
        priceStr = "E:" + DoubleToStr(entry, 5) +
                   "  SL:" + DoubleToStr(sl, 5) +
                   "  TP:" + DoubleToStr(tp, 5);
    }
    else
    {
        priceStr = "E:---  SL:---  TP:---";
    }
    PanelLabel(OBJ_LBL_PRICES, PANEL_X, LBL_Y_PRICES, priceStr, clrDimGray, 9);

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
int OnInit()
{
    IndicatorShortName("NNFXLitePanel");
    PanelCreate();
    PanelUpdate();
    EventSetMillisecondTimer(500);   // refresh HUD every 500ms
    Print("[NNFXLitePanel] Initialized.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    PanelDestroy();
    Print("[NNFXLitePanel] Deinitialized.");
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
    // Also refresh on each new bar (belt-and-suspenders with OnTimer)
    PanelUpdate();
    return rates_total;
}

//+------------------------------------------------------------------+
void OnTimer()
{
    PanelUpdate();
}

//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long   &lparam,
                  const double &dparam,
                  const string &sparam)
{
    if(id != CHARTEVENT_OBJECT_CLICK) return;

    int cmd = NNFXLP_CMD_NONE;

    if(sparam == OBJ_BTN_PLAY)    cmd = NNFXLP_CMD_PLAY;
    else if(sparam == OBJ_BTN_PAUSE)  cmd = NNFXLP_CMD_PAUSE;
    else if(sparam == OBJ_BTN_STEP)   cmd = NNFXLP_CMD_STEP;
    else if(sparam == OBJ_BTN_FASTER) cmd = NNFXLP_CMD_FASTER;
    else if(sparam == OBJ_BTN_SLOWER) cmd = NNFXLP_CMD_SLOWER;
    else if(sparam == OBJ_BTN_STOP)   cmd = NNFXLP_CMD_STOP;
    else return;

    // Unpress the button immediately
    ObjectSetInteger(0, sparam, OBJPROP_STATE, false);

    // Write command to GV — EA reads it on next OnTimer tick
    GV_SetInt(NNFXLP_CMD, cmd);

    Print("[NNFXLitePanel] Button pressed: ", sparam, " → CMD=", cmd);
    ChartRedraw(0);
}

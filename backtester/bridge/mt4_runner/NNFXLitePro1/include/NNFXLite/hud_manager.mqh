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

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

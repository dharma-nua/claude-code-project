//+------------------------------------------------------------------+
//| global_vars.mqh — GlobalVariable name constants + helpers        |
//| NNFX Lite Pro 1                                                   |
//+------------------------------------------------------------------+
#ifndef NNFXLITE_GLOBAL_VARS_MQH
#define NNFXLITE_GLOBAL_VARS_MQH

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

#define NNFXLP_STATE_STOPPED   0
#define NNFXLP_STATE_PLAYING   1
#define NNFXLP_STATE_PAUSED    2

#define NNFXLP_CMD_NONE    0
#define NNFXLP_CMD_PLAY    1
#define NNFXLP_CMD_PAUSE   2
#define NNFXLP_CMD_STEP    3
#define NNFXLP_CMD_FASTER  4
#define NNFXLP_CMD_SLOWER  5
#define NNFXLP_CMD_STOP    6

void GV_SetInt(string name, int value)    { GlobalVariableSet(name, (double)value); }
int  GV_GetInt(string name)               { if(!GlobalVariableCheck(name)) return 0; return (int)GlobalVariableGet(name); }
void GV_SetDouble(string name, double value) { GlobalVariableSet(name, value); }
double GV_GetDouble(string name)          { if(!GlobalVariableCheck(name)) return 0.0; return GlobalVariableGet(name); }

void GV_SetDatetime(string name, datetime value)
{
    GlobalVariableSet(name, (double)value);
}

datetime GV_GetDatetime(string name)
{
    if(!GlobalVariableCheck(name)) return 0;
    return (datetime)GlobalVariableGet(name);
}

void GV_DeleteAll()
{
    int total = GlobalVariablesTotal();
    for(int i = total - 1; i >= 0; i--)
    {
        string name = GlobalVariableName(i);
        if(StringFind(name, "NNFXLP_") == 0)
            GlobalVariableDel(name);
    }
}

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

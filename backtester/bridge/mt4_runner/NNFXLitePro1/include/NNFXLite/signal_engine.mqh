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

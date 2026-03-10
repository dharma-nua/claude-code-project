//+------------------------------------------------------------------+
//| indicator_engine.mqh — C1 Signal Engine with Typed Params       |
//| NNFX Sim EA Platform v2                                          |
//+------------------------------------------------------------------+
#ifndef NNFX_INDICATOR_ENGINE_MQH
#define NNFX_INDICATOR_ENGINE_MQH

//+------------------------------------------------------------------+
//| Signal type constants
#define SIG_CROSS        0
#define SIG_ZERO_CROSS   1
#define SIG_STATE_CHANGE 2

//+------------------------------------------------------------------+
//| STATE_CHANGE rule enum
enum STATE_RULE
{
    STATE_TO_POSITIVE    = 0,  // buffer[1] > 0 and buffer[2] <= 0
    STATE_TO_NEGATIVE    = 1,  // buffer[1] < 0 and buffer[2] >= 0
    STATE_TO_ABOVE_LEVEL = 2,  // buffer[1] > Level and buffer[2] <= Level
    STATE_TO_BELOW_LEVEL = 3   // buffer[1] < Level and buffer[2] >= Level
};

//+------------------------------------------------------------------+
//| Typed param enum
#define IE_MAX_PARAMS 8
enum IE_PARAM_TYPE { IE_INT=0, IE_DOUBLE=1, IE_BOOL=2, IE_STRING=3 };

//+------------------------------------------------------------------+
//| Global indicator config
string       g_IE_IndicatorName  = "";
int          g_IE_SigType        = SIG_CROSS;
int          g_IE_FastBuf        = 0;
int          g_IE_SlowBuf        = 1;
double       g_IE_BuyThresh      = 0.0;
double       g_IE_SellThresh     = 0.0;
STATE_RULE   g_IE_StateBuyRule   = STATE_TO_POSITIVE;
STATE_RULE   g_IE_StateSellRule  = STATE_TO_NEGATIVE;
double       g_IE_StateLevel     = 0.0;

IE_PARAM_TYPE g_IE_ParamTypes[IE_MAX_PARAMS];
double        g_IE_ParamVals[IE_MAX_PARAMS];
string        g_IE_ParamStrs[IE_MAX_PARAMS];
int           g_IE_ParamCount    = 0;   // -1 = parse failed

//+------------------------------------------------------------------+
void IndEngine_Init()
{
    g_IE_ParamCount = 0;
    for(int i = 0; i < IE_MAX_PARAMS; i++)
    {
        g_IE_ParamTypes[i] = IE_DOUBLE;
        g_IE_ParamVals[i]  = 0.0;
        g_IE_ParamStrs[i]  = "";
    }
}

//+------------------------------------------------------------------+
void IndEngine_SetConfig(string name, string paramValStr, string paramTypeStr,
                         int sigType, int fastBuf, int slowBuf,
                         double buyThresh, double sellThresh,
                         int stateBuyRule, int stateSellRule, double stateLevel)
{
    g_IE_IndicatorName  = name;
    g_IE_SigType        = sigType;
    g_IE_FastBuf        = fastBuf;
    g_IE_SlowBuf        = slowBuf;
    g_IE_BuyThresh      = buyThresh;
    g_IE_SellThresh     = sellThresh;
    g_IE_StateBuyRule   = (STATE_RULE)stateBuyRule;
    g_IE_StateSellRule  = (STATE_RULE)stateSellRule;
    g_IE_StateLevel     = stateLevel;

    if(paramValStr != "" && paramTypeStr != "")
        IndEngine_ParseParams(paramValStr, paramTypeStr);
    else
        g_IE_ParamCount = 0;
}

//+------------------------------------------------------------------+
// Parse typed params from CSV strings
// Returns true on success, false on parse failure
bool IndEngine_ParseParams(string valStr, string typeStr)
{
    string vals[];
    string types[];
    int vCount = StringSplit(valStr,  ',', vals);
    int tCount = StringSplit(typeStr, ',', types);

    if(vCount != tCount || vCount == 0 || vCount > IE_MAX_PARAMS)
    {
        Print("IndEngine: param parse failed: count mismatch vals=", vCount, " types=", tCount);
        g_IE_ParamCount = -1;
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
            g_IE_ParamTypes[i] = IE_INT;
            g_IE_ParamVals[i]  = (double)StringToInteger(vals[i]);
        }
        else if(typeToken == "double")
        {
            g_IE_ParamTypes[i] = IE_DOUBLE;
            g_IE_ParamVals[i]  = StringToDouble(vals[i]);
        }
        else if(typeToken == "bool")
        {
            g_IE_ParamTypes[i] = IE_BOOL;
            string bv = vals[i];
            StringToLower(bv);
            g_IE_ParamVals[i] = (bv == "true" || bv == "1") ? 1.0 : 0.0;
        }
        else if(typeToken == "string")
        {
            g_IE_ParamTypes[i] = IE_STRING;
            g_IE_ParamStrs[i]  = vals[i];
            g_IE_ParamVals[i]  = 0.0;
        }
        else
        {
            Print("IndEngine: param parse failed: type mismatch at pos ", i, " token='", types[i], "'");
            g_IE_ParamCount = -1;
            return false;
        }
    }

    g_IE_ParamCount = vCount;
    return true;
}

//+------------------------------------------------------------------+
// Build human-readable status string for workspace UI
string IndEngine_GetParamsStatus()
{
    if(g_IE_ParamCount == -1) return "Params FAILED: parse error";
    if(g_IE_ParamCount == 0)  return "Params OK (no inputs)";
    return "Params OK (" + IntegerToString(g_IE_ParamCount) + " inputs)";
}

//+------------------------------------------------------------------+
// Call iCustom with typed params via switch dispatch
// P(i) returns string param if type is STRING, else double value
double IndCall(string sym, int tf, int buffer, int shift)
{
    if(g_IE_IndicatorName == "") return EMPTY_VALUE;
    if(g_IE_ParamCount == -1)   return EMPTY_VALUE;

    // Helper: we pass doubles for int/bool/double, strings for string type
    // MQL4 iCustom accepts mixed types in same call

    #define _P(i) ((g_IE_ParamTypes[i] == IE_STRING) ? (double)0 : g_IE_ParamVals[i])
    // For string params we need a separate branch — handled in switch below

    double v0 = (g_IE_ParamCount > 0) ? g_IE_ParamVals[0] : 0;
    double v1 = (g_IE_ParamCount > 1) ? g_IE_ParamVals[1] : 0;
    double v2 = (g_IE_ParamCount > 2) ? g_IE_ParamVals[2] : 0;
    double v3 = (g_IE_ParamCount > 3) ? g_IE_ParamVals[3] : 0;
    double v4 = (g_IE_ParamCount > 4) ? g_IE_ParamVals[4] : 0;
    double v5 = (g_IE_ParamCount > 5) ? g_IE_ParamVals[5] : 0;
    double v6 = (g_IE_ParamCount > 6) ? g_IE_ParamVals[6] : 0;
    double v7 = (g_IE_ParamCount > 7) ? g_IE_ParamVals[7] : 0;

    string s0 = (g_IE_ParamCount > 0 && g_IE_ParamTypes[0] == IE_STRING) ? g_IE_ParamStrs[0] : "";
    string s1 = (g_IE_ParamCount > 1 && g_IE_ParamTypes[1] == IE_STRING) ? g_IE_ParamStrs[1] : "";
    string s2 = (g_IE_ParamCount > 2 && g_IE_ParamTypes[2] == IE_STRING) ? g_IE_ParamStrs[2] : "";
    string s3 = (g_IE_ParamCount > 3 && g_IE_ParamTypes[3] == IE_STRING) ? g_IE_ParamStrs[3] : "";

    // Count how many string params there are
    int strCount = 0;
    for(int i = 0; i < g_IE_ParamCount; i++)
        if(g_IE_ParamTypes[i] == IE_STRING) strCount++;

    double result = EMPTY_VALUE;

    // If no string params, use pure double dispatch
    if(strCount == 0)
    {
        switch(g_IE_ParamCount)
        {
            case 0: result = iCustom(sym, tf, g_IE_IndicatorName,
                        buffer, shift); break;
            case 1: result = iCustom(sym, tf, g_IE_IndicatorName,
                        v0, buffer, shift); break;
            case 2: result = iCustom(sym, tf, g_IE_IndicatorName,
                        v0, v1, buffer, shift); break;
            case 3: result = iCustom(sym, tf, g_IE_IndicatorName,
                        v0, v1, v2, buffer, shift); break;
            case 4: result = iCustom(sym, tf, g_IE_IndicatorName,
                        v0, v1, v2, v3, buffer, shift); break;
            case 5: result = iCustom(sym, tf, g_IE_IndicatorName,
                        v0, v1, v2, v3, v4, buffer, shift); break;
            case 6: result = iCustom(sym, tf, g_IE_IndicatorName,
                        v0, v1, v2, v3, v4, v5, buffer, shift); break;
            case 7: result = iCustom(sym, tf, g_IE_IndicatorName,
                        v0, v1, v2, v3, v4, v5, v6, buffer, shift); break;
            case 8: result = iCustom(sym, tf, g_IE_IndicatorName,
                        v0, v1, v2, v3, v4, v5, v6, v7, buffer, shift); break;
            default: break;
        }
    }
    else
    {
        // String param dispatch — handle first string param at position 0 or 1
        // Common case: string param in first position
        if(g_IE_ParamCount == 1 && g_IE_ParamTypes[0] == IE_STRING)
            result = iCustom(sym, tf, g_IE_IndicatorName, s0, buffer, shift);
        else if(g_IE_ParamCount == 2 && g_IE_ParamTypes[0] == IE_STRING)
            result = iCustom(sym, tf, g_IE_IndicatorName, s0, v1, buffer, shift);
        else if(g_IE_ParamCount == 2 && g_IE_ParamTypes[1] == IE_STRING)
            result = iCustom(sym, tf, g_IE_IndicatorName, v0, s1, buffer, shift);
        else if(g_IE_ParamCount == 3 && g_IE_ParamTypes[0] == IE_STRING)
            result = iCustom(sym, tf, g_IE_IndicatorName, s0, v1, v2, buffer, shift);
        else if(g_IE_ParamCount == 4 && g_IE_ParamTypes[0] == IE_STRING)
            result = iCustom(sym, tf, g_IE_IndicatorName, s0, v1, v2, v3, buffer, shift);
        else
        {
            // Fallback: treat everything as double
            switch(g_IE_ParamCount)
            {
                case 1: result = iCustom(sym, tf, g_IE_IndicatorName, v0, buffer, shift); break;
                case 2: result = iCustom(sym, tf, g_IE_IndicatorName, v0, v1, buffer, shift); break;
                case 3: result = iCustom(sym, tf, g_IE_IndicatorName, v0, v1, v2, buffer, shift); break;
                case 4: result = iCustom(sym, tf, g_IE_IndicatorName, v0, v1, v2, v3, buffer, shift); break;
                default: break;
            }
        }
    }
    #undef _P
    return result;
}

//+------------------------------------------------------------------+
// Guard helper: returns true if value is usable
bool _IE_ValOK(double v, int buf, int shift)
{
    if(v == EMPTY_VALUE)
    {
        Print("IndEngine: EMPTY_VALUE at buf=", buf, " shift=", shift);
        return false;
    }
    if(!MathIsValidNumber(v))
    {
        Print("IndEngine: invalid number at buf=", buf, " shift=", shift);
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
// Get C1 signal: returns +1 (buy), -1 (sell), 0 (none)
int IndEngine_GetSignal(string sym, int tf, int shift)
{
    if(g_IE_IndicatorName == "")  return 0;
    if(g_IE_ParamCount == -1)     return 0;

    if(g_IE_SigType == SIG_CROSS)
    {
        double fast1 = IndCall(sym, tf, g_IE_FastBuf, shift);
        double slow1 = IndCall(sym, tf, g_IE_SlowBuf, shift);
        double fast2 = IndCall(sym, tf, g_IE_FastBuf, shift + 1);
        double slow2 = IndCall(sym, tf, g_IE_SlowBuf, shift + 1);

        if(!_IE_ValOK(fast1, g_IE_FastBuf, shift)   || !_IE_ValOK(slow1, g_IE_SlowBuf, shift) ||
           !_IE_ValOK(fast2, g_IE_FastBuf, shift+1) || !_IE_ValOK(slow2, g_IE_SlowBuf, shift+1))
            return 0;

        if(fast2 <= slow2 && fast1 > slow1) return  1;  // BUY: crossover up
        if(fast2 >= slow2 && fast1 < slow1) return -1;  // SELL: crossover down
        return 0;
    }

    if(g_IE_SigType == SIG_ZERO_CROSS)
    {
        double v1 = IndCall(sym, tf, g_IE_FastBuf, shift);
        double v2 = IndCall(sym, tf, g_IE_FastBuf, shift + 1);

        if(!_IE_ValOK(v1, g_IE_FastBuf, shift) || !_IE_ValOK(v2, g_IE_FastBuf, shift+1))
            return 0;

        double bt = g_IE_BuyThresh;
        double st = g_IE_SellThresh;

        if(bt == 0.0 && st == 0.0)
        {
            if(v2 <= 0.0 && v1 > 0.0) return  1;
            if(v2 >= 0.0 && v1 < 0.0) return -1;
        }
        else
        {
            if(v1 >= bt && bt != 0.0)  return  1;
            if(v1 <= st && st != 0.0)  return -1;
        }
        return 0;
    }

    if(g_IE_SigType == SIG_STATE_CHANGE)
    {
        double buf1 = IndCall(sym, tf, g_IE_FastBuf, shift);
        double buf2 = IndCall(sym, tf, g_IE_FastBuf, shift + 1);

        if(!_IE_ValOK(buf1, g_IE_FastBuf, shift) || !_IE_ValOK(buf2, g_IE_FastBuf, shift+1))
            return 0;

        double Level = g_IE_StateLevel;
        int buySignal  = 0;
        int sellSignal = 0;

        // Evaluate buy rule
        switch(g_IE_StateBuyRule)
        {
            case STATE_TO_POSITIVE:
                if(buf1 > 0.0 && buf2 <= 0.0) buySignal = 1; break;
            case STATE_TO_NEGATIVE:
                if(buf1 < 0.0 && buf2 >= 0.0) buySignal = 1; break;
            case STATE_TO_ABOVE_LEVEL:
                if(buf1 > Level && buf2 <= Level) buySignal = 1; break;
            case STATE_TO_BELOW_LEVEL:
                if(buf1 < Level && buf2 >= Level) buySignal = 1; break;
        }

        // Evaluate sell rule
        switch(g_IE_StateSellRule)
        {
            case STATE_TO_POSITIVE:
                if(buf1 > 0.0 && buf2 <= 0.0) sellSignal = 1; break;
            case STATE_TO_NEGATIVE:
                if(buf1 < 0.0 && buf2 >= 0.0) sellSignal = 1; break;
            case STATE_TO_ABOVE_LEVEL:
                if(buf1 > Level && buf2 <= Level) sellSignal = 1; break;
            case STATE_TO_BELOW_LEVEL:
                if(buf1 < Level && buf2 >= Level) sellSignal = 1; break;
        }

        // Debug logging
        Print(StringFormat("IndEngine STATE_CHANGE: buf1=%.6f buf2=%.6f Level=%.6f buyRule=%d sellRule=%d buy=%d sell=%d",
              buf1, buf2, Level, (int)g_IE_StateBuyRule, (int)g_IE_StateSellRule, buySignal, sellSignal));

        if(buySignal)  return  1;
        if(sellSignal) return -1;
        return 0;
    }

    return 0;
}

//+------------------------------------------------------------------+
// Validate indicator over a range of bars, count signals
bool IndEngine_Validate(string sym, int tf, int fromShift, int toShift,
                        int &buyCount, int &sellCount)
{
    buyCount  = 0;
    sellCount = 0;

    if(g_IE_IndicatorName == "")
    {
        Print("IndEngine_Validate: No indicator name set");
        return false;
    }
    if(g_IE_ParamCount == -1)
    {
        Print("IndEngine_Validate: Param parse failed");
        return false;
    }

    for(int s = fromShift; s <= toShift; s++)
    {
        int sig = IndEngine_GetSignal(sym, tf, s);
        if(sig ==  1) buyCount++;
        if(sig == -1) sellCount++;
    }

    Print(StringFormat("IndEngine_Validate: %s from=%d to=%d buys=%d sells=%d",
          g_IE_IndicatorName, fromShift, toShift, buyCount, sellCount));
    return true;
}

#endif // NNFX_INDICATOR_ENGINE_MQH

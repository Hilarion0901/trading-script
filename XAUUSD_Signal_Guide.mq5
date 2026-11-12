//+------------------------------------------------------------------+
//|                                       XAUUSD_Signal_Guide.mq5    |
//|  Indicateur visuel — interprete le graphique XAUUSD              |
//|                                                                  |
//|  M15 = tendance   M5 = zone / pullback   M1 = declencheur        |
//|  Fleches uniquement sur bougies CLOTUREES (pas de repeint)       |
//|                                                                  |
//|  Ce n'est PAS une garantie de gain. Un SL reste obligatoire.     |
//+------------------------------------------------------------------+
#property copyright   "XAUUSD Signal Guide"
#property version     "1.00"
#property description "Guide BUY/SELL XAUUSD — confluence M15>M5>M1, non repeint"
#property indicator_chart_window

#property indicator_buffers 5
#property indicator_plots   5

#property indicator_label1  "EMA 10"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

#property indicator_label2  "EMA 20"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

#property indicator_label3  "EMA 50"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMediumPurple
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "BUY"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_width4  3

#property indicator_label5  "SELL"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRed
#property indicator_width5  3

//==================================================================//
// INPUTS
//==================================================================//

input group "===== Indicateurs ====="
input int    InpEMAFast            = 10;
input int    InpEMAMedium          = 20;
input int    InpEMASlow            = 50;
input int    InpRSIPeriod          = 14;
input int    InpBBPeriod           = 20;
input double InpBBDeviation        = 2.0;
input int    InpATRPeriod          = 14;
input int    InpADXPeriod          = 14;
input double InpMinEMASpreadATR    = 0.12;

input group "===== Structure ====="
input int    InpSwingBars          = 2;
input int    InpSwingLookbackM15   = 40;
input int    InpSwingLookbackM5    = 50;
input int    InpSwingLookbackM1    = 40;
input int    InpSRLookback         = 60;
input double InpSRZonePoints       = 50.0;
input double InpPullbackATR        = 0.45;
input int    InpRetestMaxBars      = 12;
input double InpBOSBufferATR       = 0.05;
input double InpPinWickBodyRatio   = 2.0;
input double InpMaxBodyRatio       = 0.38;

input group "===== Score / filtres ====="
input int    InpMinScore           = 7;          // Score mini (max 16)
input bool   InpUseH1Bias          = true;       // H1 ne doit pas etre contraire
input bool   InpUseADX             = true;       // Eviter les ranges
input double InpADXMin             = 18.0;
input bool   InpAvoidExtended      = true;       // Pas de chase
input double InpMaxCandleATR       = 2.2;
input long   InpMaxSpreadPoints    = 50;         // 0 = off
input int    InpCooldownBars       = 5;          // Bougies mini entre 2 fleches
input double InpMinRR              = 1.3;
input double InpRRRatio            = 1.5;
input double InpSLATRMult          = 1.20;
input double InpSLBufferPoints     = 20.0;

input group "===== Session (heure serveur) ====="
input bool   InpUseSession         = true;
input int    InpSessionStartHour   = 8;
input int    InpSessionEndHour     = 21;

input group "===== Affichage ====="
input bool   InpShowEMA            = true;
input bool   InpShowArrows         = true;
input bool   InpShowPanel          = true;
input bool   InpShowLevels         = true;
input bool   InpShowTradeLevels    = true;
input int    InpHistoryBars        = 400;
input int    InpPanelX             = 12;
input int    InpPanelY             = 18;
input int    InpPanelMinWidth      = 340;
input double InpPanelFontScale     = 1.00;
input int    InpPanelFontSize      = 8;

input group "===== Alertes ====="
input bool   InpAlertPopup         = true;
input bool   InpAlertSound         = true;
input bool   InpAlertPush          = false;

//==================================================================//
// CONSTANTES / BUFFERS
//==================================================================//

#define OBJ_PREFIX   "XAU_SG_"
#define PANEL_TITLE  "GUIDE  XAUUSD"
#define MAX_ROWS     34
#define ROW_TEXT     0
#define ROW_SEP      1
#define ROW_TITLE    2

double EMA10Buffer[];
double EMA20Buffer[];
double EMA50Buffer[];
double BuyBuffer[];
double SellBuffer[];

int gH_E10 = INVALID_HANDLE, gH_E20 = INVALID_HANDLE, gH_E50 = INVALID_HANDLE;
int gH_ATR = INVALID_HANDLE, gH_ADX = INVALID_HANDLE;
int gH_M15_E10 = INVALID_HANDLE, gH_M15_E20 = INVALID_HANDLE, gH_M15_E50 = INVALID_HANDLE;
int gH_M5_E10  = INVALID_HANDLE, gH_M5_E20  = INVALID_HANDLE, gH_M5_E50  = INVALID_HANDLE;
int gH_M1_E10  = INVALID_HANDLE, gH_M1_E20  = INVALID_HANDLE, gH_M1_E50  = INVALID_HANDLE;
int gH_H1_E20  = INVALID_HANDLE, gH_H1_E50  = INVALID_HANDLE;
int gH_M15_RSI = INVALID_HANDLE, gH_M5_RSI = INVALID_HANDLE, gH_M1_RSI = INVALID_HANDLE;
int gH_M5_BB   = INVALID_HANDLE, gH_M5_ATR = INVALID_HANDLE;

double gATR[], gADX[];
double gM15_E10[], gM15_E20[], gM15_E50[];
double gM5_E10[],  gM5_E20[],  gM5_E50[];
double gM1_E10[],  gM1_E20[],  gM1_E50[];
double gH1_E20[],  gH1_E50[];
double gRSI15[], gRSI5[], gRSI1[];
double gBBMid[], gBBUp[], gBBLo[];
double gATRm5[];

bool   gDataReady    = false;
uint   gLastLoadTick = 0;
int    gLastBarCount = 0;

struct ZoneLevel
{
   double price;
   double lo;
   double hi;
   bool   valid;
};

struct BreakoutMemory
{
   int      dir;
   double   level;
   datetime breakTime;
};

struct SetupInfo
{
   int      dir;          // 1 BUY, -1 SELL, 0 aucun
   int      scoreBuy;
   int      scoreSell;
   int      maxScore;
   int      t15;
   int      t5;
   int      t1;
   int      h1;

   double   ema10;
   double   ema20;
   double   ema50;
   double   rsi15, rsi5, rsi1;
   double   vwap;
   double   atr;
   double   adx;
   double   pivot, r1, s1;

   ZoneLevel support;
   ZoneLevel resist;

   double   entry;
   double   sl;
   double   tp;
   double   rr;

   long     spreadPts;
   bool     spreadOk;
   bool     sessionOk;
   bool     adxOk;
   bool     pullback;
   bool     rejection;
   bool     retest;
   bool     rrOk;

   string   action;       // BUY / SELL / WAIT
   string   reason;
};

SetupInfo gClosed;
SetupInfo gLive;

BreakoutMemory gBO;

int      gSigDir   = 0;
int      gSigScore = 0;
datetime gSigTime  = 0;
double   gSigEntry = 0.0;
double   gSigSL    = 0.0;
double   gSigTP    = 0.0;
datetime gLastAlertTime = 0;

string gRowText[2][MAX_ROWS];
int    gRowSize[2][MAX_ROWS];
color  gRowColor[2][MAX_ROWS];
int    gRowKind[2][MAX_ROWS];
int    gRowCount[2];
int    gRowDrawn[2];
int    gCol;
double gPxPt     = 1.333;
int    gFontBase = 8;

//==================================================================//
// UTILS
//==================================================================//

double PointValue()
{
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return (pt > 0.0 ? pt : _Point);
}

double TickSize()
{
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   return (ts > 0.0 ? ts : PointValue());
}

double NormalizePrice(const double price)
{
   double ts = TickSize();
   if(ts <= 0.0)
      return NormalizeDouble(price, _Digits);
   return NormalizeDouble(MathRound(price / ts) * ts, _Digits);
}

double PointsToPrice(const double points)
{
   return points * PointValue();
}

bool ValidNum(const double v)
{
   return (v != 0.0 && MathIsValidNumber(v) && v != EMPTY_VALUE);
}

bool CopySeriesBuffer(const int handle, const int buf, const int count, double &dest[])
{
   if(handle == INVALID_HANDLE || count <= 0)
      return false;
   if(BarsCalculated(handle) < count)
      return false;
   ArraySetAsSeries(dest, true);
   return (CopyBuffer(handle, buf, 0, count, dest) == count);
}

int NeedBars(const ENUM_TIMEFRAMES tf, const int extra)
{
   double ratio = (double)PeriodSeconds(_Period) / (double)PeriodSeconds(tf);
   int need = (int)MathCeil(ratio * (InpHistoryBars + 5)) + extra;
   if(need < 250)  need = 250;
   if(need > 20000) need = 20000;
   int available = Bars(_Symbol, tf);
   if(available > 0 && need > available)
      need = available;
   return need;
}

int ClosedShift(const ENUM_TIMEFRAMES tf, const datetime barOpen)
{
   int sh = iBarShift(_Symbol, tf, barOpen, false);
   if(sh < 0)
      return -1;

   datetime tfOpen = iTime(_Symbol, tf, sh);
   if(tfOpen <= 0)
      return -1;

   datetime barClose = barOpen + PeriodSeconds(_Period);
   datetime tfClose  = tfOpen + PeriodSeconds(tf);

   if(barClose < tfClose)
      sh++;

   return sh;
}

string Pad(string text, const int length)
{
   while(StringLen(text) < length)
      text += " ";
   return text;
}

string TrendText(const int t)
{
   if(t > 0) return "HAUSSIER";
   if(t < 0) return "BAISSIER";
   return "NEUTRE";
}

color TrendClr(const int t, const color neutral)
{
   if(t > 0) return C'28,140,70';
   if(t < 0) return C'190,55,50';
   return neutral;
}

bool InSession(const datetime barTime)
{
   if(!InpUseSession)
      return true;

   MqlDateTime dt;
   TimeToStruct(barTime, dt);

   if(InpSessionStartHour <= InpSessionEndHour)
      return (dt.hour >= InpSessionStartHour && dt.hour < InpSessionEndHour);
   return (dt.hour >= InpSessionStartHour || dt.hour < InpSessionEndHour);
}

void ResetSetup(SetupInfo &s)
{
   SetupInfo empty;
   s = empty;
   s.action = "WAIT";
   s.reason = "Analyse...";
}

bool Near(const double a, const double b, const double tol)
{
   if(b <= 0.0)
      return false;
   return (MathAbs(a - b) <= tol);
}

bool PriceInZone(const double price, const ZoneLevel &z)
{
   if(!z.valid)
      return false;
   return (price >= z.lo && price <= z.hi);
}

//==================================================================//
// SWINGS / S-R
//==================================================================//

bool IsSwingHighTF(const ENUM_TIMEFRAMES tf, const int i, const int strength)
{
   double h = iHigh(_Symbol, tf, i);
   for(int k = 1; k <= strength; k++)
   {
      if(iHigh(_Symbol, tf, i - k) >= h) return false;
      if(iHigh(_Symbol, tf, i + k) >= h) return false;
   }
   return true;
}

bool IsSwingLowTF(const ENUM_TIMEFRAMES tf, const int i, const int strength)
{
   double l = iLow(_Symbol, tf, i);
   for(int k = 1; k <= strength; k++)
   {
      if(iLow(_Symbol, tf, i - k) <= l) return false;
      if(iLow(_Symbol, tf, i + k) <= l) return false;
   }
   return true;
}

double LastSwingHigh(const ENUM_TIMEFRAMES tf, const int fromShift, const int lookback)
{
   int strength = MathMax(1, InpSwingBars);
   int bars = Bars(_Symbol, tf);
   int end = fromShift + lookback;
   if(end >= bars - strength - 1)
      end = bars - strength - 2;

   for(int i = fromShift + strength; i <= end; i++)
   {
      if(IsSwingHighTF(tf, i, strength))
         return iHigh(_Symbol, tf, i);
   }
   return 0.0;
}

double LastSwingLow(const ENUM_TIMEFRAMES tf, const int fromShift, const int lookback)
{
   int strength = MathMax(1, InpSwingBars);
   int bars = Bars(_Symbol, tf);
   int end = fromShift + lookback;
   if(end >= bars - strength - 1)
      end = bars - strength - 2;

   for(int i = fromShift + strength; i <= end; i++)
   {
      if(IsSwingLowTF(tf, i, strength))
         return iLow(_Symbol, tf, i);
   }
   return 0.0;
}

bool LastTwoSwings(
   const ENUM_TIMEFRAMES tf,
   const int fromShift,
   const int lookback,
   double &sh1, double &sh2,
   double &sl1, double &sl2
)
{
   sh1 = sh2 = sl1 = sl2 = 0.0;
   int strength = MathMax(1, InpSwingBars);
   int foundH = 0, foundL = 0;
   int bars = Bars(_Symbol, tf);
   int end = fromShift + lookback;
   if(end >= bars - strength - 1)
      end = bars - strength - 2;

   for(int i = fromShift + strength; i <= end; i++)
   {
      if(foundH < 2 && IsSwingHighTF(tf, i, strength))
      {
         if(foundH == 0) sh1 = iHigh(_Symbol, tf, i);
         else            sh2 = iHigh(_Symbol, tf, i);
         foundH++;
      }
      if(foundL < 2 && IsSwingLowTF(tf, i, strength))
      {
         if(foundL == 0) sl1 = iLow(_Symbol, tf, i);
         else            sl2 = iLow(_Symbol, tf, i);
         foundL++;
      }
      if(foundH >= 2 && foundL >= 2)
         break;
   }
   return (foundH >= 2 && foundL >= 2);
}

int StructureDir(const ENUM_TIMEFRAMES tf, const int shift, const int lookback)
{
   double sh1, sh2, sl1, sl2;
   if(!LastTwoSwings(tf, shift, lookback, sh1, sh2, sl1, sl2))
      return 0;
   if(sh1 > sh2 && sl1 > sl2) return 1;
   if(sh1 < sh2 && sl1 < sl2) return -1;
   return 0;
}

double RecentExtreme(const ENUM_TIMEFRAMES tf, const int fromShift, const int count, const bool findHigh)
{
   double best = (findHigh ? -DBL_MAX : DBL_MAX);
   int bars = Bars(_Symbol, tf);
   int n = MathMin(count, bars - fromShift - 1);
   for(int k = 0; k < n; k++)
   {
      if(findHigh)
      {
         double h = iHigh(_Symbol, tf, fromShift + k);
         if(h > best) best = h;
      }
      else
      {
         double l = iLow(_Symbol, tf, fromShift + k);
         if(l < best) best = l;
      }
   }
   if(best == -DBL_MAX || best == DBL_MAX)
      return 0.0;
   return best;
}

//==================================================================//
// VWAP / PIVOTS
//==================================================================//

double VWAPFromChart(
   const int i,
   const datetime &time[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[]
)
{
   if(i < 0)
      return 0.0;

   MqlDateTime dt;
   TimeToStruct(time[i], dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   double num = 0.0;
   double den = 0.0;
   int start = i;
   while(start > 0 && time[start - 1] >= dayStart)
      start--;

   for(int k = start; k <= i; k++)
   {
      double tp = (high[k] + low[k] + close[k]) / 3.0;
      double vol = (double)tick_volume[k];
      if(vol <= 0.0) vol = 1.0;
      num += tp * vol;
      den += vol;
   }
   if(den <= 0.0)
      return close[i];
   return num / den;
}

void PivotAt(const datetime barTime, double &pivot, double &r1, double &s1)
{
   pivot = r1 = s1 = 0.0;
   int sh = iBarShift(_Symbol, PERIOD_D1, barTime, false);
   if(sh < 0)
      sh = 0;
   int prev = sh + 1;
   double h = iHigh(_Symbol,  PERIOD_D1, prev);
   double l = iLow(_Symbol,   PERIOD_D1, prev);
   double c = iClose(_Symbol, PERIOD_D1, prev);
   if(!ValidNum(h) || !ValidNum(l) || !ValidNum(c) || h < l)
      return;
   pivot = (h + l + c) / 3.0;
   r1 = (2.0 * pivot) - l;
   s1 = (2.0 * pivot) - h;
}

//==================================================================//
// EVALUATION D'UNE BOUGIE CLOTUREE
//==================================================================//

int ScoreMax() { return 16; }

bool EvaluateBar(
   const int i,
   const int rates_total,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const int &spread[],
   const bool livePreview,
   SetupInfo &info
)
{
   ResetSetup(info);

   if(i < 20 || i >= rates_total)
      return false;

   datetime barTime = time[i];
   int s15 = ClosedShift(PERIOD_M15, barTime);
   int s5  = ClosedShift(PERIOD_M5,  barTime);
   int s1  = ClosedShift(PERIOD_M1,  barTime);
   int sh1 = ClosedShift(PERIOD_H1,  barTime);

   if(s15 < 1 || s5 < 1 || s1 < 1)
      return false;
   if(s15 >= ArraySize(gM15_E10) || s5 >= ArraySize(gM5_E10) || s1 >= ArraySize(gM1_E10))
      return false;

   info.ema10 = EMA10Buffer[i];
   info.ema20 = EMA20Buffer[i];
   info.ema50 = EMA50Buffer[i];
   info.atr   = (i < ArraySize(gATR) ? gATR[i] : 0.0);
   info.adx   = (i < ArraySize(gADX) ? gADX[i] : 0.0);
   info.vwap  = VWAPFromChart(i, time, high, low, close, tick_volume);

   double e10_15 = gM15_E10[s15], e20_15 = gM15_E20[s15], e50_15 = gM15_E50[s15];
   double e10_5  = gM5_E10[s5],   e20_5  = gM5_E20[s5],   e50_5  = gM5_E50[s5];
   double e10_1  = gM1_E10[s1],   e20_1  = gM1_E20[s1],   e50_1  = gM1_E50[s1];

   info.rsi15 = (s15 < ArraySize(gRSI15) ? gRSI15[s15] : 50.0);
   info.rsi5  = (s5  < ArraySize(gRSI5)  ? gRSI5[s5]  : 50.0);
   info.rsi1  = (s1  < ArraySize(gRSI1)  ? gRSI1[s1]  : 50.0);

   double close15 = iClose(_Symbol, PERIOD_M15, s15);
   double close5  = iClose(_Symbol, PERIOD_M5,  s5);
   double close1  = iClose(_Symbol, PERIOD_M1,  s1);
   double high5   = iHigh(_Symbol,  PERIOD_M5,  s5);
   double low5    = iLow(_Symbol,   PERIOD_M5,  s5);
   double open5   = iOpen(_Symbol,  PERIOD_M5,  s5);
   double high1   = iHigh(_Symbol,  PERIOD_M1,  s1);
   double low1    = iLow(_Symbol,   PERIOD_M1,  s1);
   double open1   = iOpen(_Symbol,  PERIOD_M1,  s1);
   double atr5    = (s5 < ArraySize(gATRm5) ? gATRm5[s5] : info.atr);
   if(atr5 <= 0.0)
      atr5 = info.atr;

   PivotAt(barTime, info.pivot, info.r1, info.s1);

   double minSep15 = (atr5 > 0.0 ? atr5 * InpMinEMASpreadATR * MathSqrt(3.0) : 0.0);
   double minSep5  = (atr5 > 0.0 ? atr5 * InpMinEMASpreadATR : 0.0);

   bool stackUp15 =
      e10_15 > e20_15 && e20_15 > e50_15 && close15 > e50_15 &&
      (e10_15 - e50_15) >= minSep15;
   bool stackDn15 =
      e10_15 < e20_15 && e20_15 < e50_15 && close15 < e50_15 &&
      (e50_15 - e10_15) >= minSep15;

   int struct15 = StructureDir(PERIOD_M15, s15, InpSwingLookbackM15);
   bool vwapUp = (info.vwap <= 0.0 || close15 >= info.vwap);
   bool vwapDn = (info.vwap <= 0.0 || close15 <= info.vwap);

   if(stackUp15 && struct15 >= 0 && vwapUp)      info.t15 = 1;
   else if(stackDn15 && struct15 <= 0 && vwapDn) info.t15 = -1;
   else if(stackUp15 && struct15 >= 0)           info.t15 = 1;
   else if(stackDn15 && struct15 <= 0)           info.t15 = -1;
   else                                          info.t15 = 0;

   if(e10_5 > e20_5 && e20_5 > e50_5 && close5 > e50_5 && (e10_5 - e50_5) >= minSep5)
      info.t5 = 1;
   else if(e10_5 < e20_5 && e20_5 < e50_5 && close5 < e50_5 && (e50_5 - e10_5) >= minSep5)
      info.t5 = -1;
   else if(e20_5 > e50_5 && close5 > e50_5)
      info.t5 = 1;
   else if(e20_5 < e50_5 && close5 < e50_5)
      info.t5 = -1;
   else
      info.t5 = 0;

   if(e10_1 > e20_1 && close1 > e20_1)      info.t1 = 1;
   else if(e10_1 < e20_1 && close1 < e20_1) info.t1 = -1;
   else                                     info.t1 = 0;

   info.h1 = 0;
   if(sh1 >= 0 && sh1 < ArraySize(gH1_E20) && sh1 < ArraySize(gH1_E50))
   {
      if(gH1_E20[sh1] > gH1_E50[sh1]) info.h1 = 1;
      if(gH1_E20[sh1] < gH1_E50[sh1]) info.h1 = -1;
   }

   double zone = PointsToPrice(InpSRZonePoints);
   double swingL = LastSwingLow(PERIOD_M5, s5 + 1, InpSwingLookbackM5);
   double swingH = LastSwingHigh(PERIOD_M5, s5 + 1, InpSwingLookbackM5);
   double recL   = RecentExtreme(PERIOD_M5, s5 + 1, InpSRLookback, false);
   double recH   = RecentExtreme(PERIOD_M5, s5 + 1, InpSRLookback, true);

   double sup = 0.0, supDist = DBL_MAX;
   double candsS[5];
   int ns = 0;
   if(swingL > 0.0) candsS[ns++] = swingL;
   if(recL > 0.0)   candsS[ns++] = recL;
   if(info.s1 > 0.0) candsS[ns++] = info.s1;
   if(info.pivot > 0.0 && info.pivot < close5) candsS[ns++] = info.pivot;
   if(info.vwap > 0.0 && info.vwap < close5) candsS[ns++] = info.vwap;
   for(int k = 0; k < ns; k++)
   {
      if(candsS[k] >= close5) continue;
      double d = close5 - candsS[k];
      if(d < supDist) { supDist = d; sup = candsS[k]; }
   }
   if(sup > 0.0)
   {
      info.support.price = sup;
      info.support.lo = sup - zone * 0.5;
      info.support.hi = sup + zone * 0.5;
      info.support.valid = true;
   }

   double res = 0.0, resDist = DBL_MAX;
   double candsR[5];
   int nr = 0;
   if(swingH > 0.0) candsR[nr++] = swingH;
   if(recH > 0.0)   candsR[nr++] = recH;
   if(info.r1 > 0.0) candsR[nr++] = info.r1;
   if(info.pivot > 0.0 && info.pivot > close5) candsR[nr++] = info.pivot;
   if(info.vwap > 0.0 && info.vwap > close5) candsR[nr++] = info.vwap;
   for(int k = 0; k < nr; k++)
   {
      if(candsR[k] <= close5) continue;
      double d = candsR[k] - close5;
      if(d < resDist) { resDist = d; res = candsR[k]; }
   }
   if(res > 0.0)
   {
      info.resist.price = res;
      info.resist.lo = res - zone * 0.5;
      info.resist.hi = res + zone * 0.5;
      info.resist.valid = true;
   }

   double o = open1, h = high1, l = low1, c = close1;
   double range = h - l;
   double body  = MathAbs(c - o);
   double upper = h - MathMax(o, c);
   double lower = MathMin(o, c) - l;
   bool hammer = false, shooting = false, engulfBuy = false, engulfSell = false;
   bool rejBuy = false, rejSell = false;

   if(range > 0.0)
   {
      bool smallBody = (body <= range * InpMaxBodyRatio);
      hammer = smallBody && (lower >= body * InpPinWickBodyRatio) &&
               (upper <= range * 0.30) && (c >= l + range * 0.55);
      shooting = smallBody && (upper >= body * InpPinWickBodyRatio) &&
                 (lower <= range * 0.30) && (c <= h - range * 0.55);
      rejBuy  = hammer || (lower >= range * 0.55 && c > o);
      rejSell = shooting || (upper >= range * 0.55 && c < o);
   }

   double po = iOpen(_Symbol, PERIOD_M1, s1 + 1);
   double pc = iClose(_Symbol, PERIOD_M1, s1 + 1);
   double prevBody = MathAbs(pc - po);
   if(prevBody > 0.0 && body > prevBody)
   {
      engulfBuy  = (pc < po) && (c > o) && (o <= pc) && (c >= po);
      engulfSell = (pc > po) && (c < o) && (o >= pc) && (c <= po);
   }

   double swH1 = LastSwingHigh(PERIOD_M1, s1 + 1, InpSwingLookbackM1);
   double swL1 = LastSwingLow(PERIOD_M1,  s1 + 1, InpSwingLookbackM1);
   double bos  = (atr5 > 0.0 ? atr5 * InpBOSBufferATR : PointsToPrice(5));
   bool breakHigh = (swH1 > 0.0 && c > swH1 + bos);
   bool breakLow  = (swL1 > 0.0 && c < swL1 - bos);

   double shA, shB, slA, slB;
   bool hl = false, lh = false;
   if(LastTwoSwings(PERIOD_M1, s1, InpSwingLookbackM1, shA, shB, slA, slB))
   {
      hl = (slA > slB);
      lh = (shA < shB);
   }

   bool hhhl = (struct15 > 0);
   bool lhll = (struct15 < 0);

   double bbMid = (s5 < ArraySize(gBBMid) ? gBBMid[s5] : 0.0);
   double bbUp  = (s5 < ArraySize(gBBUp)  ? gBBUp[s5]  : 0.0);
   double bbLo  = (s5 < ArraySize(gBBLo)  ? gBBLo[s5]  : 0.0);
   bool bbBuy = false, bbSell = false;
   if(bbUp > bbLo && bbLo > 0.0)
   {
      double w = bbUp - bbLo;
      bbBuy  = (low5 <= bbLo + w * 0.08) && (close5 > bbLo) && (close5 > open5) && (close5 < bbMid + w * 0.15);
      bbSell = (high5 >= bbUp - w * 0.08) && (close5 < bbUp) && (close5 < open5) && (close5 > bbMid - w * 0.15);
   }

   double bosM5 = (atr5 > 0.0 ? atr5 * InpBOSBufferATR : PointsToPrice(8));
   datetime t5 = iTime(_Symbol, PERIOD_M5, s5);
   bool breakoutBuy = false, breakoutSell = false;
   bool retestBuy = false, retestSell = false;

   if(!livePreview)
   {
      if(info.resist.valid && close5 > info.resist.hi + bosM5)
      {
         breakoutBuy = true;
         gBO.dir = 1;
         gBO.level = info.resist.price;
         gBO.breakTime = t5;
      }
      if(info.support.valid && close5 < info.support.lo - bosM5)
      {
         breakoutSell = true;
         gBO.dir = -1;
         gBO.level = info.support.price;
         gBO.breakTime = t5;
      }
      if(gBO.dir != 0 && gBO.breakTime > 0)
      {
         int age = iBarShift(_Symbol, PERIOD_M5, gBO.breakTime, false);
         if(age < 0 || age > InpRetestMaxBars + 8)
         {
            gBO.dir = 0;
            gBO.level = 0.0;
            gBO.breakTime = 0;
         }
         else if(age >= 1 && age <= InpRetestMaxBars)
         {
            bool touched = (low5 <= gBO.level + zone * 0.5 && high5 >= gBO.level - zone * 0.5);
            if(touched && gBO.dir == 1 && close5 >= gBO.level && (rejBuy || close5 > open5))
            {
               retestBuy = true;
               breakoutBuy = true;
            }
            if(touched && gBO.dir == -1 && close5 <= gBO.level && (rejSell || close5 < open5))
            {
               retestSell = true;
               breakoutSell = true;
            }
         }
      }
   }

   double tol = (atr5 > 0.0 ? atr5 * InpPullbackATR : PointsToPrice(30));
   bool nearEma =
      Near(close5, e10_5, tol) || Near(close5, e20_5, tol) || Near(close5, e50_5, tol);
   bool nearVWAP = Near(close5, info.vwap, tol);
   bool nearBB   = Near(close5, bbMid, tol) || Near(close5, bbLo, tol) || Near(close5, bbUp, tol);

   bool pullBuy =
      info.t15 > 0 &&
      (nearEma || PriceInZone(low5, info.support) || nearVWAP || nearBB) &&
      (close5 > e50_5 || close5 > e20_5);
   bool pullSell =
      info.t15 < 0 &&
      (nearEma || PriceInZone(high5, info.resist) || nearVWAP || nearBB) &&
      (close5 < e50_5 || close5 < e20_5);

   info.pullback  = (pullBuy || pullSell);
   info.rejection = (rejBuy || rejSell);
   info.retest    = (retestBuy || retestSell);

   bool extended = (InpAvoidExtended && atr5 > 0.0 && (high5 - low5) > atr5 * InpMaxCandleATR);

   info.maxScore = ScoreMax();
   info.scoreBuy = 0;
   info.scoreSell = 0;

   if(info.t15 > 0)                         info.scoreBuy  += 2;
   if(e10_5 > e20_5)                        info.scoreBuy  += 1;
   if(e20_5 > e50_5)                        info.scoreBuy  += 1;
   if(info.vwap > 0.0 && close1 > info.vwap) info.scoreBuy += 1;
   if(info.rsi1 > 50.0 && info.rsi5 >= 48.0) info.scoreBuy += 1;
   if(info.support.valid && (PriceInZone(low1, info.support) || PriceInZone(low5, info.support)))
                                            info.scoreBuy  += 2;
   if(rejBuy || hammer || engulfBuy)        info.scoreBuy  += 2;
   if(breakoutBuy)                          info.scoreBuy  += 2;
   if(retestBuy)                            info.scoreBuy  += 2;
   if(bbBuy)                                info.scoreBuy  += 1;
   if(hhhl || hl)                           info.scoreBuy  += 1;

   if(info.t15 < 0)                         info.scoreSell += 2;
   if(e10_5 < e20_5)                        info.scoreSell += 1;
   if(e20_5 < e50_5)                        info.scoreSell += 1;
   if(info.vwap > 0.0 && close1 < info.vwap) info.scoreSell += 1;
   if(info.rsi1 < 50.0 && info.rsi5 <= 52.0) info.scoreSell += 1;
   if(info.resist.valid && (PriceInZone(high1, info.resist) || PriceInZone(high5, info.resist)))
                                            info.scoreSell += 2;
   if(rejSell || shooting || engulfSell)    info.scoreSell += 2;
   if(breakoutSell)                         info.scoreSell += 2;
   if(retestSell)                           info.scoreSell += 2;
   if(bbSell)                               info.scoreSell += 1;
   if(lhll || lh)                           info.scoreSell += 1;

   info.sessionOk = InSession(barTime);
   info.spreadPts = (i < ArraySize(spread) ? (long)spread[i] : SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
   if(info.spreadPts <= 0)
      info.spreadPts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   info.spreadOk = (InpMaxSpreadPoints <= 0 || info.spreadPts <= InpMaxSpreadPoints);
   info.adxOk = (!InpUseADX || info.adx >= InpADXMin);

   bool h1OkBuy  = (!InpUseH1Bias || info.h1 >= 0);
   bool h1OkSell = (!InpUseH1Bias || info.h1 <= 0);

   bool paBuy  = rejBuy || hammer || engulfBuy || breakHigh || hl || retestBuy;
   bool paSell = rejSell || shooting || engulfSell || breakLow || lh || retestSell;
   bool emaM1Buy  = (e10_1 >= e20_1 || close1 > e20_1);
   bool emaM1Sell = (e10_1 <= e20_1 || close1 < e20_1);

   int signal = 0;
   if(info.t15 > 0 && info.t5 >= 0 && info.scoreBuy >= InpMinScore &&
      paBuy && emaM1Buy && info.rsi1 >= 48.0 && (pullBuy || retestBuy || breakoutBuy))
      signal = 1;
   if(info.t15 < 0 && info.t5 <= 0 && info.scoreSell >= InpMinScore &&
      paSell && emaM1Sell && info.rsi1 <= 52.0 && (pullSell || retestSell || breakoutSell))
      signal = -1;

   info.entry = close[i];
   double buffer = PointsToPrice(InpSLBufferPoints);
   if(signal > 0)
   {
      info.sl = info.entry;
      if(swL1 > 0.0) info.sl = MathMin(info.sl, swL1);
      if(info.support.valid) info.sl = MathMin(info.sl, info.support.lo);
      info.sl = MathMin(info.sl, low1);
      if(info.sl >= info.entry)
         info.sl = info.entry - atr5 * InpSLATRMult;
      info.sl -= buffer;
      info.tp = info.entry + MathAbs(info.entry - info.sl) * InpRRRatio;
   }
   else if(signal < 0)
   {
      info.sl = info.entry;
      if(swH1 > 0.0) info.sl = MathMax(info.sl, swH1);
      if(info.resist.valid) info.sl = MathMax(info.sl, info.resist.hi);
      info.sl = MathMax(info.sl, high1);
      if(info.sl <= info.entry)
         info.sl = info.entry + atr5 * InpSLATRMult;
      info.sl += buffer;
      info.tp = info.entry - MathAbs(info.sl - info.entry) * InpRRRatio;
   }

   info.sl = NormalizePrice(info.sl);
   info.tp = NormalizePrice(info.tp);
   double risk = MathAbs(info.entry - info.sl);
   double rew  = MathAbs(info.tp - info.entry);
   info.rr = (risk > 0.0 ? rew / risk : 0.0);
   info.rrOk = (info.rr + 1e-8 >= InpMinRR);

   if(signal != 0)
   {
      if(!info.sessionOk)      { info.reason = "Hors session"; signal = 0; }
      else if(!info.spreadOk)  { info.reason = "Spread trop eleve"; signal = 0; }
      else if(!info.adxOk)     { info.reason = "Marche trop plat (ADX)"; signal = 0; }
      else if(extended)        { info.reason = "Bougie trop etendue — ne pas chasser"; signal = 0; }
      else if(signal > 0 && !h1OkBuy)  { info.reason = "H1 contraire au BUY"; signal = 0; }
      else if(signal < 0 && !h1OkSell) { info.reason = "H1 contraire au SELL"; signal = 0; }
      else if(!info.rrOk)      { info.reason = "RR insuffisant"; signal = 0; }
   }

   info.dir = (livePreview ? 0 : signal);

   if(signal > 0)
   {
      info.action = "BUY";
      info.reason = "M15 haussier + zone M5 + confirmation M1";
   }
   else if(signal < 0)
   {
      info.action = "SELL";
      info.reason = "M15 baissier + zone M5 + confirmation M1";
   }
   else
   {
      info.action = "WAIT";
      if(StringLen(info.reason) == 0 || info.reason == "Analyse...")
      {
         if(info.t15 == 0)
            info.reason = "M15 neutre — ne pas trader";
         else if(info.t15 > 0 && info.t5 < 0)
            info.reason = "M5 contraire a M15";
         else if(info.t15 < 0 && info.t5 > 0)
            info.reason = "M5 contraire a M15";
         else if(info.t15 > 0 && info.scoreBuy < InpMinScore)
            info.reason = "Score BUY trop faible (" + IntegerToString(info.scoreBuy) + "/" + IntegerToString(InpMinScore) + ")";
         else if(info.t15 < 0 && info.scoreSell < InpMinScore)
            info.reason = "Score SELL trop faible (" + IntegerToString(info.scoreSell) + "/" + IntegerToString(InpMinScore) + ")";
         else if(info.t15 > 0 && !pullBuy && !retestBuy)
            info.reason = "Attendre un pullback / retest M5";
         else if(info.t15 < 0 && !pullSell && !retestSell)
            info.reason = "Attendre un pullback / retest M5";
         else
            info.reason = "Pas de confirmation M1 — WAIT";
      }
   }

   return true;
}

//==================================================================//
// PANEL
//==================================================================//

double PanelPxPerPoint()
{
   double dpi = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(dpi < 72.0) dpi = 96.0;
   double scale = InpPanelFontScale;
   if(scale < 0.50) scale = 0.50;
   if(scale > 2.00) scale = 2.00;
   return (dpi / 72.0) * scale;
}

int RowAdvancePx(const int kind, const int fontSize)
{
   if(kind == ROW_SEP)
      return (int)MathCeil(8.0 * gPxPt);
   return (int)MathCeil(fontSize * gPxPt * 1.55);
}

int TextWidthPx(const string text, const int fontSize)
{
   return (int)MathCeil(StringLen(text) * fontSize * gPxPt * 0.58) + 4;
}

void RowReset() { gRowCount[0] = 0; gRowCount[1] = 0; gCol = 0; }

void AddRow(const int kind, const string text, const int fontSize, const color clr)
{
   int n = gRowCount[gCol];
   if(n >= MAX_ROWS) return;
   gRowKind[gCol][n] = kind;
   gRowText[gCol][n] = text;
   gRowSize[gCol][n] = fontSize;
   gRowColor[gCol][n] = clr;
   gRowCount[gCol] = n + 1;
}

void Row(const string text, const int fontSize, const color clr) { AddRow(ROW_TEXT, text, fontSize, clr); }
void RowSep() { AddRow(ROW_SEP, "", 1, C'205,193,175'); }
void RowTitle(const string text)
{
   AddRow(ROW_TITLE, text, (int)MathMax(6, gFontBase - 1), C'148,136,118');
}
void NextColumn()
{
   if(gCol == 0) gCol = 1;
   else RowSep();
}

string RowName(const int col, const int index)
{
   return OBJ_PREFIX + "R_" + IntegerToString(col) + "_" + IntegerToString(index);
}
string SepName(const int col, const int index)
{
   return OBJ_PREFIX + "S_" + IntegerToString(col) + "_" + IntegerToString(index);
}

void DeleteObj(const string name)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

void CreateRect(const string name, const int x, const int y, const int w, const int h, const color bg, const color bd)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, bd);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SetLabel(const string name, const string text, const int x, const int y, const int fontSize, const color textColor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SetSeparator(const string name, const int x, const int y, const int width, const color clr)
{
   int th = (int)MathMax(1, MathRound(gPxPt * 0.7));
   CreateRect(name, x, y, MathMax(4, width), th, clr, clr);
}

color ActionClr(const string action)
{
   if(action == "BUY")  return C'28,140,70';
   if(action == "SELL") return C'190,55,50';
   return C'175,125,25';
}

color ScoreClr(const int score)
{
   if(score >= InpMinScore) return C'28,140,70';
   if(score >= InpMinScore - 2) return C'170,125,20';
   return C'120,100,90';
}

void BuildPanelRows()
{
   RowReset();
   int fs    = (int)MathMax(6, gFontBase);
   int fsBig = fs + 6;
   int fsSml = (int)MathMax(6, fs - 1);
   color txt = C'42,42,42';
   color dim = C'125,118,105';
   int lab = 11;

   if(!gDataReady)
   {
      Row("SYNCHRONISATION...", fs, C'175,125,25');
      Row("Ouvrez M1 / M5 / M15 / H1", fsSml, dim);
      return;
   }

   if(_Period != PERIOD_M1)
   {
      Row("Placez-le sur M1", fsSml, C'175,125,25');
      RowSep();
   }

   SetupInfo s = gClosed;
   color ac = ActionClr(s.action);

   Row("ACTION", fsSml, dim);
   Row("  " + s.action, fsBig, ac);
   Row(s.reason, fsSml, dim);
   RowSep();

   RowTitle("CONFIANCE");
   Row(Pad("BUY",  lab) + IntegerToString(s.scoreBuy)  + " / " + IntegerToString(s.maxScore), fs, ScoreClr(s.scoreBuy));
   Row(Pad("SELL", lab) + IntegerToString(s.scoreSell) + " / " + IntegerToString(s.maxScore), fs, ScoreClr(s.scoreSell));
   Row(Pad("MINI", lab) + IntegerToString(InpMinScore), fsSml, dim);
   RowSep();

   RowTitle("LECTURE");
   Row(Pad("M15", lab) + TrendText(s.t15), fs, TrendClr(s.t15, txt));
   Row(Pad("M5",  lab) + TrendText(s.t5),  fs, TrendClr(s.t5, txt));
   Row(Pad("M1",  lab) + TrendText(s.t1),  fs, TrendClr(s.t1, dim));
   Row(Pad("H1",  lab) + TrendText(s.h1),  fsSml, TrendClr(s.h1, dim));

   NextColumn();

   RowTitle("SI TU TRADES");
   if(s.action == "WAIT" || s.dir == 0)
   {
      Row("Pas de setup valide", fs, dim);
      Row("Ne pas entrer", fsSml, C'190,55,50');
   }
   else
   {
      Row(Pad("ENTREE", lab) + DoubleToString(s.entry, _Digits), fs, clrRoyalBlue);
      Row(Pad("SL",     lab) + DoubleToString(s.sl, _Digits), fs, clrCrimson);
      Row(Pad("TP",     lab) + DoubleToString(s.tp, _Digits), fs, C'0,130,75');
      Row(Pad("RR",     lab) + "1:" + DoubleToString(s.rr, 2), fs, txt);
   }
   RowSep();

   RowTitle("FILTRES");
   Row(Pad("SPREAD", lab) + IntegerToString((int)gLive.spreadPts) + " pts",
       fs, (gLive.spreadOk ? txt : clrRed));
   Row(Pad("ADX", lab) + DoubleToString(s.adx, 1) + "  " + (s.adxOk ? "OK" : "FAIBLE"),
       fs, (s.adxOk ? txt : C'175,125,25'));
   Row(Pad("SESSION", lab) + (gLive.sessionOk ? "OUI" : "NON"),
       fs, (gLive.sessionOk ? txt : C'175,125,25'));
   Row(Pad("ATR", lab) + DoubleToString(s.atr, _Digits), fs, txt);
   RowSep();

   RowTitle("NIVEAUX");
   Row(Pad("VWAP", lab) + DoubleToString(s.vwap, _Digits), fs, C'180,130,20');
   Row(Pad("SUP",  lab) + (s.support.valid ? DoubleToString(s.support.price, _Digits) : "--"),
       fs, C'40,120,80');
   Row(Pad("RES",  lab) + (s.resist.valid ? DoubleToString(s.resist.price, _Digits) : "--"),
       fs, C'170,70,70');
   RowSep();
   Row("SL obligatoire. Pas de garantie.", fsSml, dim);
}

void DrawPanel()
{
   if(!InpShowPanel)
   {
      ObjectsDeleteAll(0, OBJ_PREFIX + "R_", 0, -1);
      ObjectsDeleteAll(0, OBJ_PREFIX + "S_", 0, -1);
      DeleteObj(OBJ_PREFIX + "PANEL_BG");
      DeleteObj(OBJ_PREFIX + "PANEL_ACCENT");
      DeleteObj(OBJ_PREFIX + "HDR");
      DeleteObj(OBJ_PREFIX + "HDRSEP");
      return;
   }

   gPxPt = PanelPxPerPoint();
   int pad = (int)MathCeil(10.0 * gPxPt);
   int gap = (int)MathCeil(16.0 * gPxPt);
   int accent = (int)MathMax(5, MathRound(5.0 * gPxPt));

   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int maxW = (chartW > 0 ? chartW - InpPanelX - 8 : 0);
   int maxH = (chartH > 0 ? chartH - InpPanelY - 8 : 0);

   int colW[2], colH[2];
   int width = 0, height = 0, headerH = 0;

   for(int base = (int)MathMax(6, InpPanelFontSize); base >= 6; base--)
   {
      gFontBase = base;
      BuildPanelRows();
      for(int c = 0; c < 2; c++)
      {
         colW[c] = 0;
         colH[c] = 0;
         for(int i = 0; i < gRowCount[c]; i++)
         {
            if(gRowKind[c][i] != ROW_SEP)
            {
               int w = TextWidthPx(gRowText[c][i], gRowSize[c][i]);
               if(w > colW[c]) colW[c] = w;
            }
            colH[c] += RowAdvancePx(gRowKind[c][i], gRowSize[c][i]);
         }
      }
      int inner = colW[0];
      if(gRowCount[1] > 0)
         inner += gap + colW[1];
      int tw = TextWidthPx(PANEL_TITLE, gFontBase + 2);
      if(tw > inner) inner = tw;
      headerH = RowAdvancePx(ROW_TEXT, gFontBase + 2) + RowAdvancePx(ROW_SEP, 1);
      width  = accent + pad * 2 + inner;
      height = pad * 2 + headerH + (int)MathMax(colH[0], colH[1]);
      if(base == 6) break;
      if((maxW <= 0 || width <= maxW) && (maxH <= 0 || height <= maxH))
         break;
   }

   if(width < InpPanelMinWidth)
      width = InpPanelMinWidth;

   color accentClr = ActionClr(gClosed.action);
   CreateRect(OBJ_PREFIX + "PANEL_BG", InpPanelX, InpPanelY, width, height,
              C'245,238,225', C'178,164,140');
   CreateRect(OBJ_PREFIX + "PANEL_ACCENT", InpPanelX, InpPanelY, accent, height,
              accentClr, accentClr);

   int contentX = InpPanelX + accent + pad;
   SetLabel(OBJ_PREFIX + "HDR", PANEL_TITLE, contentX, InpPanelY + pad,
            gFontBase + 2, C'28,28,28');
   SetSeparator(OBJ_PREFIX + "HDRSEP", contentX,
                InpPanelY + pad + headerH - RowAdvancePx(ROW_SEP, 1) / 2,
                width - accent - pad * 2, C'196,182,162');

   int colX[2];
   colX[0] = contentX;
   colX[1] = contentX + colW[0] + gap;

   for(int c = 0; c < 2; c++)
   {
      int y = InpPanelY + pad + headerH;
      for(int i = 0; i < gRowCount[c]; i++)
      {
         int adv = RowAdvancePx(gRowKind[c][i], gRowSize[c][i]);
         if(gRowKind[c][i] == ROW_SEP)
         {
            DeleteObj(RowName(c, i));
            SetSeparator(SepName(c, i), colX[c], y + adv / 2, colW[c], gRowColor[c][i]);
         }
         else
         {
            DeleteObj(SepName(c, i));
            SetLabel(RowName(c, i), gRowText[c][i], colX[c], y, gRowSize[c][i], gRowColor[c][i]);
         }
         y += adv;
      }
      for(int i = gRowCount[c]; i < gRowDrawn[c]; i++)
      {
         DeleteObj(RowName(c, i));
         DeleteObj(SepName(c, i));
      }
      gRowDrawn[c] = gRowCount[c];
   }
}

//==================================================================//
// NIVEAUX GRAPHIQUES
//==================================================================//

void DrawHLine(const string id, const double price, const color clr, const int style, const int width, const string text)
{
   string name = OBJ_PREFIX + id;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
}

void DrawSegment(const string id, const datetime t1, const datetime t2, const double price, const color clr, const int style, const int width, const string text)
{
   string name = OBJ_PREFIX + id;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, text);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DrawChartLevels(const SetupInfo &info, const datetime lastBarTime)
{
   if(!InpShowLevels)
   {
      ObjectsDeleteAll(0, OBJ_PREFIX + "LV_", 0, -1);
      ObjectsDeleteAll(0, OBJ_PREFIX + "TR_", 0, -1);
      return;
   }

   if(info.vwap > 0.0)
      DrawHLine("LV_VWAP", info.vwap, C'210,160,40', STYLE_SOLID, 1,
                "VWAP " + DoubleToString(info.vwap, _Digits));
   if(info.pivot > 0.0)
      DrawHLine("LV_P", info.pivot, C'90,90,90', STYLE_DASH, 1, "P");
   if(info.r1 > 0.0)
      DrawHLine("LV_R1", info.r1, C'170,70,70', STYLE_DOT, 1, "R1");
   if(info.s1 > 0.0)
      DrawHLine("LV_S1", info.s1, C'40,120,80', STYLE_DOT, 1, "S1");
   if(info.support.valid)
      DrawHLine("LV_SUP", info.support.price, C'40,120,80', STYLE_SOLID, 1, "SUP");
   if(info.resist.valid)
      DrawHLine("LV_RES", info.resist.price, C'170,70,70', STYLE_SOLID, 1, "RES");

   if(!InpShowTradeLevels || gSigDir == 0 || gSigTime == 0)
   {
      DeleteObj(OBJ_PREFIX + "TR_ENTRY");
      DeleteObj(OBJ_PREFIX + "TR_SL");
      DeleteObj(OBJ_PREFIX + "TR_TP");
      return;
   }

   int barSec = PeriodSeconds(_Period);
   datetime t2 = gSigTime + barSec * 40;
   if(t2 < lastBarTime)
      t2 = lastBarTime + barSec * 4;

   DrawSegment("TR_ENTRY", gSigTime, t2, gSigEntry, clrRoyalBlue, STYLE_SOLID, 2,
               "ENTREE " + DoubleToString(gSigEntry, _Digits));
   DrawSegment("TR_SL", gSigTime, t2, gSigSL, clrCrimson, STYLE_DASHDOT, 2,
               "SL " + DoubleToString(gSigSL, _Digits));
   DrawSegment("TR_TP", gSigTime, t2, gSigTP, C'0,140,80', STYLE_DOT, 2,
               "TP " + DoubleToString(gSigTP, _Digits));
}

//==================================================================//
// INIT / DEINIT
//==================================================================//

int OnInit()
{
   SetIndexBuffer(0, EMA10Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, EMA20Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, EMA50Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, BuyBuffer,   INDICATOR_DATA);
   SetIndexBuffer(4, SellBuffer,  INDICATOR_DATA);

   ENUM_DRAW_TYPE emaDraw = (InpShowEMA ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, (int)emaDraw);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, (int)emaDraw);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, (int)emaDraw);

   ENUM_DRAW_TYPE arrowDraw = (InpShowArrows ? DRAW_ARROW : DRAW_NONE);
   PlotIndexSetInteger(3, PLOT_DRAW_TYPE, (int)arrowDraw);
   PlotIndexSetInteger(4, PLOT_DRAW_TYPE, (int)arrowDraw);
   PlotIndexSetInteger(3, PLOT_ARROW, 233);
   PlotIndexSetInteger(4, PLOT_ARROW, 234);

   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   ArraySetAsSeries(gATR, false);
   ArraySetAsSeries(gADX, false);

   gH_E10 = iMA(_Symbol, _Period, InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
   gH_E20 = iMA(_Symbol, _Period, InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
   gH_E50 = iMA(_Symbol, _Period, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
   gH_ATR = iATR(_Symbol, _Period, InpATRPeriod);
   gH_ADX = iADX(_Symbol, _Period, InpADXPeriod);

   gH_M15_E10 = iMA(_Symbol, PERIOD_M15, InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
   gH_M15_E20 = iMA(_Symbol, PERIOD_M15, InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
   gH_M15_E50 = iMA(_Symbol, PERIOD_M15, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
   gH_M5_E10  = iMA(_Symbol, PERIOD_M5,  InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
   gH_M5_E20  = iMA(_Symbol, PERIOD_M5,  InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
   gH_M5_E50  = iMA(_Symbol, PERIOD_M5,  InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
   gH_M1_E10  = iMA(_Symbol, PERIOD_M1,  InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
   gH_M1_E20  = iMA(_Symbol, PERIOD_M1,  InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
   gH_M1_E50  = iMA(_Symbol, PERIOD_M1,  InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
   gH_H1_E20  = iMA(_Symbol, PERIOD_H1,  InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
   gH_H1_E50  = iMA(_Symbol, PERIOD_H1,  InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);

   gH_M15_RSI = iRSI(_Symbol, PERIOD_M15, InpRSIPeriod, PRICE_CLOSE);
   gH_M5_RSI  = iRSI(_Symbol, PERIOD_M5,  InpRSIPeriod, PRICE_CLOSE);
   gH_M1_RSI  = iRSI(_Symbol, PERIOD_M1,  InpRSIPeriod, PRICE_CLOSE);
   gH_M5_BB   = iBands(_Symbol, PERIOD_M5, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   gH_M5_ATR  = iATR(_Symbol, PERIOD_M5, InpATRPeriod);

   if(
      gH_E10 == INVALID_HANDLE || gH_E20 == INVALID_HANDLE || gH_E50 == INVALID_HANDLE ||
      gH_ATR == INVALID_HANDLE || gH_ADX == INVALID_HANDLE ||
      gH_M15_E10 == INVALID_HANDLE || gH_M5_E10 == INVALID_HANDLE || gH_M1_E10 == INVALID_HANDLE ||
      gH_M15_RSI == INVALID_HANDLE || gH_M5_BB == INVALID_HANDLE
   )
   {
      Print("[GUIDE] Echec creation des indicateurs.");
      return INIT_FAILED;
   }

   ResetSetup(gClosed);
   ResetSetup(gLive);
   gBO.dir = 0;
   gBO.level = 0.0;
   gBO.breakTime = 0;

   IndicatorSetString(INDICATOR_SHORTNAME, "XAUUSD Signal Guide");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   return INIT_SUCCEEDED;
}

void ReleaseH(int &h)
{
   if(h != INVALID_HANDLE)
   {
      IndicatorRelease(h);
      h = INVALID_HANDLE;
   }
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, OBJ_PREFIX, 0, -1);
   ChartRedraw(0);

   ReleaseH(gH_E10); ReleaseH(gH_E20); ReleaseH(gH_E50);
   ReleaseH(gH_ATR); ReleaseH(gH_ADX);
   ReleaseH(gH_M15_E10); ReleaseH(gH_M15_E20); ReleaseH(gH_M15_E50);
   ReleaseH(gH_M5_E10);  ReleaseH(gH_M5_E20);  ReleaseH(gH_M5_E50);
   ReleaseH(gH_M1_E10);  ReleaseH(gH_M1_E20);  ReleaseH(gH_M1_E50);
   ReleaseH(gH_H1_E20);  ReleaseH(gH_H1_E50);
   ReleaseH(gH_M15_RSI); ReleaseH(gH_M5_RSI); ReleaseH(gH_M1_RSI);
   ReleaseH(gH_M5_BB); ReleaseH(gH_M5_ATR);
}

bool LoadMTF()
{
   int extra = InpSRLookback + InpSwingLookbackM1 + InpEMASlow + InpATRPeriod + 40;
   int n15 = NeedBars(PERIOD_M15, extra);
   int n5  = NeedBars(PERIOD_M5,  extra);
   int n1  = NeedBars(PERIOD_M1,  extra);
   int nh1 = NeedBars(PERIOD_H1,  extra);

   if(!CopySeriesBuffer(gH_M15_E10, 0, n15, gM15_E10)) return false;
   if(!CopySeriesBuffer(gH_M15_E20, 0, n15, gM15_E20)) return false;
   if(!CopySeriesBuffer(gH_M15_E50, 0, n15, gM15_E50)) return false;
   if(!CopySeriesBuffer(gH_M5_E10,  0, n5,  gM5_E10))  return false;
   if(!CopySeriesBuffer(gH_M5_E20,  0, n5,  gM5_E20))  return false;
   if(!CopySeriesBuffer(gH_M5_E50,  0, n5,  gM5_E50))  return false;
   if(!CopySeriesBuffer(gH_M1_E10,  0, n1,  gM1_E10))  return false;
   if(!CopySeriesBuffer(gH_M1_E20,  0, n1,  gM1_E20))  return false;
   if(!CopySeriesBuffer(gH_M1_E50,  0, n1,  gM1_E50))  return false;
   if(!CopySeriesBuffer(gH_H1_E20,  0, nh1, gH1_E20))  return false;
   if(!CopySeriesBuffer(gH_H1_E50,  0, nh1, gH1_E50))  return false;
   if(!CopySeriesBuffer(gH_M15_RSI, 0, n15, gRSI15))   return false;
   if(!CopySeriesBuffer(gH_M5_RSI,  0, n5,  gRSI5))    return false;
   if(!CopySeriesBuffer(gH_M1_RSI,  0, n1,  gRSI1))    return false;
   if(!CopySeriesBuffer(gH_M5_BB,   0, n5,  gBBMid))   return false;
   if(!CopySeriesBuffer(gH_M5_BB,   1, n5,  gBBUp))    return false;
   if(!CopySeriesBuffer(gH_M5_BB,   2, n5,  gBBLo))    return false;
   if(!CopySeriesBuffer(gH_M5_ATR,  0, n5,  gATRm5))   return false;
   return true;
}

//==================================================================//
// CALCUL
//==================================================================//

int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
{
   int minBars = InpEMASlow + InpATRPeriod + InpADXPeriod + 30;
   if(rates_total < minBars)
      return 0;

   ArraySetAsSeries(time, false);
   ArraySetAsSeries(open, false);
   ArraySetAsSeries(high, false);
   ArraySetAsSeries(low, false);
   ArraySetAsSeries(close, false);
   ArraySetAsSeries(tick_volume, false);
   ArraySetAsSeries(spread, false);

   if(
      BarsCalculated(gH_E10) < rates_total ||
      BarsCalculated(gH_E20) < rates_total ||
      BarsCalculated(gH_E50) < rates_total ||
      BarsCalculated(gH_ATR) < rates_total ||
      BarsCalculated(gH_ADX) < rates_total
   )
      return 0;

   if(CopyBuffer(gH_E10, 0, 0, rates_total, EMA10Buffer) != rates_total) return 0;
   if(CopyBuffer(gH_E20, 0, 0, rates_total, EMA20Buffer) != rates_total) return 0;
   if(CopyBuffer(gH_E50, 0, 0, rates_total, EMA50Buffer) != rates_total) return 0;
   if(CopyBuffer(gH_ATR, 0, 0, rates_total, gATR) != rates_total) return 0;
   if(CopyBuffer(gH_ADX, 0, 0, rates_total, gADX) != rates_total) return 0;

   bool needReload =
      (!gDataReady) ||
      (prev_calculated <= 0) ||
      (rates_total != gLastBarCount) ||
      ((GetTickCount() - gLastLoadTick) > 900);

   if(needReload)
   {
      gDataReady = LoadMTF();
      if(gDataReady)
      {
         gLastLoadTick = GetTickCount();
         gLastBarCount = rates_total;
      }
   }

   if(!gDataReady)
   {
      DrawPanel();
      ChartRedraw(0);
      return 0;
   }

   int historyBars = (int)MathMax(30, InpHistoryBars);
   int firstBar    = (int)MathMax(25, rates_total - 1 - historyBars);
   int lastClosed  = rates_total - 2;
   int start;

   if(prev_calculated <= 0)
   {
      ArrayInitialize(BuyBuffer, EMPTY_VALUE);
      ArrayInitialize(SellBuffer, EMPTY_VALUE);
      gSigDir = 0;
      gSigTime = 0;
      gSigScore = 0;
      gBO.dir = 0;
      gBO.level = 0.0;
      gBO.breakTime = 0;
      start = firstBar;
   }
   else
   {
      start = (int)MathMax(firstBar, prev_calculated - 4);
   }

   for(int k = start; k < rates_total; k++)
   {
      BuyBuffer[k]  = EMPTY_VALUE;
      SellBuffer[k] = EMPTY_VALUE;
   }

   SetupInfo info;
   datetime lastSigTime = gSigTime;

   if(prev_calculated <= 0)
      lastSigTime = 0;

   for(int i = start; i <= lastClosed; i++)
   {
      if(!EvaluateBar(i, rates_total, time, open, high, low, close, tick_volume, spread, false, info))
         continue;
      if(info.dir == 0)
         continue;

      if(lastSigTime > 0 && InpCooldownBars > 0 && time[i] != lastSigTime)
      {
         long elapsed = (long)(time[i] - lastSigTime);
         if(elapsed > 0 && elapsed < (long)InpCooldownBars * PeriodSeconds(_Period))
            continue;
      }

      if(info.dir == 1)
         BuyBuffer[i] = low[i] - info.atr * 0.55;
      else
         SellBuffer[i] = high[i] + info.atr * 0.55;

      gSigDir   = info.dir;
      gSigScore = (info.dir > 0 ? info.scoreBuy : info.scoreSell);
      gSigTime  = time[i];
      gSigEntry = info.entry;
      gSigSL    = info.sl;
      gSigTP    = info.tp;
      lastSigTime = time[i];

      if(i == lastClosed && time[i] != gLastAlertTime)
      {
         gLastAlertTime = time[i];
         string msg =
            _Symbol + " " + info.action +
            " | Score " + IntegerToString(gSigScore) + "/" + IntegerToString(info.maxScore) +
            " | E " + DoubleToString(info.entry, _Digits) +
            " | SL " + DoubleToString(info.sl, _Digits) +
            " | TP " + DoubleToString(info.tp, _Digits);

         if(InpAlertPopup) Alert(msg);
         if(InpAlertSound) PlaySound("alert.wav");
         if(InpAlertPush)  SendNotification(msg);
      }
   }

   if(lastClosed >= 25)
      EvaluateBar(lastClosed, rates_total, time, open, high, low, close, tick_volume, spread, false, gClosed);

   if(!EvaluateBar(rates_total - 1, rates_total, time, open, high, low, close, tick_volume, spread, true, gLive))
   {
      gLive.spreadPts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      gLive.spreadOk  = (InpMaxSpreadPoints <= 0 || gLive.spreadPts <= InpMaxSpreadPoints);
      gLive.sessionOk = InSession(TimeCurrent());
   }

   DrawChartLevels(gClosed, time[rates_total - 1]);
   DrawPanel();
   ChartRedraw(0);
   return rates_total;
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
      DrawPanel();
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                          XAUUSD_Scalping_EA.mq5  |
//|  Expert Advisor experimental — scalping XAUUSD                   |
//|                                                                  |
//|  Architecture                                                   |
//|  -----------                                                    |
//|  M15 = tendance principale (EMA 10/20/50 + structure + VWAP)    |
//|  M5  = zone / pullback / retest (S/R, EMA, Bollinger, VWAP)     |
//|  M1  = declencheur (price action + score de confluence)         |
//|                                                                  |
//|  Aucun signal isole (EMA, RSI, BB) ne suffit a ouvrir un trade. |
//|  Qualite > quantite. Systeme experimental a backtester.         |
//+------------------------------------------------------------------+
#property copyright   "XAUUSD Scalping EA"
#property version     "1.00"
#property description "Scalping XAUUSD M15>M5>M1 — confluence, scoring, risque"

#include <Trade/Trade.mqh>

//==================================================================//
// ENUMS
//==================================================================//

enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,          // Lot fixe
   LOT_RISK_PERCENT = 1    // Risque % du capital
};

enum ENUM_SL_MODE
{
   SL_STRUCTURE = 0,       // Swing / support / resistance
   SL_ATR       = 1,       // ATR
   SL_FIXED     = 2        // Distance fixe
};

enum ENUM_TP_MODE
{
   TP_FIXED  = 0,          // Distance fixe
   TP_RR     = 1,          // Risk / Reward
   TP_SR     = 2           // Prochain S/R
};

enum ENUM_TRAIL_MODE
{
   TRAIL_NONE  = 0,
   TRAIL_FIXED = 1,
   TRAIL_ATR   = 2,
   TRAIL_EMA   = 3
};

enum ENUM_PIVOT_PERIOD
{
   PIVOT_DAILY  = 0,
   PIVOT_WEEKLY = 1
};

enum ENUM_TREND
{
   TREND_BEAR    = -1,
   TREND_NEUTRAL =  0,
   TREND_BULL    =  1
};

//==================================================================//
// INPUTS — groupes lisibles dans MT5
//==================================================================//

input group "===== 1. General ====="
input long   InpMagic              = 250901;     // Magic Number
input int    InpSlippagePoints     = 30;         // Slippage (points)
input string InpTradeComment       = "XAU-EA";   // Commentaire ordre

input group "===== 2. Indicateurs ====="
input int    InpEMAFast            = 10;         // EMA rapide
input int    InpEMAMedium          = 20;         // EMA moyenne
input int    InpEMASlow            = 50;         // EMA lente
input int    InpRSIPeriod          = 14;         // RSI periode
input int    InpBBPeriod           = 20;         // Bollinger periode
input double InpBBDeviation        = 2.0;        // Bollinger deviation
input int    InpBBShift            = 0;          // Bollinger shift
input int    InpATRPeriod          = 14;         // ATR periode
input double InpMinEMASpreadATR    = 0.12;       // Separation mini EMA (x ATR)

input group "===== 3. Structure / Price Action ====="
input int    InpSwingBars          = 2;          // Force fractal (bougies)
input int    InpSwingLookbackM15   = 40;         // Lookback swings M15
input int    InpSwingLookbackM5    = 50;         // Lookback swings M5
input int    InpSwingLookbackM1    = 40;         // Lookback swings M1
input int    InpSRLookback         = 60;         // Lookback plus hauts/bas
input double InpSRZonePoints       = 50.0;       // Largeur zone S/R (points)
input double InpPullbackATR        = 0.45;       // Distance max pullback (x ATR)
input int    InpRetestMaxBars      = 12;         // Bougies max pour un retest
input double InpBOSBufferATR       = 0.05;       // Marge de cassure (x ATR)
input double InpPinWickBodyRatio   = 2.0;        // Meche mini / corps (pin bar)
input double InpMaxBodyRatio       = 0.38;       // Corps max / range (pin bar)

input group "===== 4. Pivots ====="
input ENUM_PIVOT_PERIOD InpPivotPeriod = PIVOT_DAILY; // Periode pivots
input bool   InpShowPivots         = true;       // Afficher pivots

input group "===== 5. Score de confluence ====="
input int    InpMinScore           = 7;          // Score minimum BUY/SELL
input int    InpW_M15Trend         = 2;          // Poids tendance M15
input int    InpW_M5EmaFast        = 1;          // Poids EMA10 > EMA20 M5
input int    InpW_M5EmaSlow        = 1;          // Poids EMA20 > EMA50 M5
input int    InpW_VWAP             = 1;          // Poids prix vs VWAP
input int    InpW_RSI              = 1;          // Poids RSI vs 50
input int    InpW_SR               = 2;          // Poids support/resistance
input int    InpW_Rejection        = 2;          // Poids rejet / pin / engulfing
input int    InpW_Breakout         = 2;          // Poids breakout
input int    InpW_Retest           = 2;          // Poids retest
input int    InpW_BB               = 1;          // Poids Bollinger
input int    InpW_Structure        = 1;          // Poids HH/HL ou LH/LL

input group "===== 6. Risque ====="
input ENUM_LOT_MODE InpLotMode     = LOT_RISK_PERCENT; // Mode lot
input double InpFixedLot           = 0.01;       // Lot fixe
input double InpRiskPercent        = 1.0;        // Risque % equity
input ENUM_SL_MODE  InpSLMode      = SL_STRUCTURE;     // Mode Stop Loss
input double InpSLFixedPoints      = 150.0;      // SL fixe (points)
input double InpSLATRMult          = 1.20;       // SL ATR (x ATR M5)
input double InpSLBufferPoints     = 20.0;       // Buffer SL (points)
input double InpMaxSLPoints        = 400.0;      // SL max (points, 0=off)
input ENUM_TP_MODE  InpTPMode      = TP_RR;      // Mode Take Profit
input double InpTPFixedPoints      = 150.0;      // TP fixe (points)
input double InpRRRatio            = 1.5;        // Risk/Reward (ex 1.5 = 1:1.5)
input double InpMinRR              = 1.2;        // RR minimum pour entrer
input double InpTPBufferPoints     = 15.0;       // Buffer avant S/R (points)

input group "===== 7. Break Even / Trailing ====="
input bool   InpBEEnabled          = true;       // Activer Break Even
input double InpBETriggerR         = 1.0;        // Declenchement BE (en R)
input double InpBEOffsetPoints     = 10.0;       // Offset BE (points)
input ENUM_TRAIL_MODE InpTrailMode = TRAIL_NONE; // Mode trailing
input double InpTrailStartR        = 1.2;        // Trailing apres X R
input double InpTrailFixedPoints   = 80.0;       // Trailing fixe (points)
input double InpTrailATRMult       = 1.0;        // Trailing ATR (x ATR)

input group "===== 8. Filtres marche ====="
input int    InpMaxSpreadPoints    = 50;         // Spread max (points)
input double InpMinATR             = 0.0;        // ATR M5 mini (0=off)
input double InpMaxATR             = 0.0;        // ATR M5 maxi (0=off)
input double InpMaxCandleATR       = 2.2;        // Bougie M5 max (x ATR)
input bool   InpAvoidExtendedEntry = true;       // Refuser chase apres extension

input group "===== 9. Limites de trading ====="
input int    InpMaxTradesPerDay    = 8;          // Trades max / jour
input int    InpMaxPositions       = 1;          // Positions simultanees
input int    InpMaxConsecutiveLoss = 3;          // Pertes consecutives max
input double InpDailyProfitTarget  = 0.0;        // Objectif journalier USD (0=off)
input double InpDailyLossLimit     = 0.0;        // Perte journaliere max USD (0=off)
input int    InpCooldownSeconds    = 180;        // Cooldown entre trades (sec)

input group "===== 10. Horaires (heure serveur) ====="
input bool   InpUseSessionFilter   = true;       // Filtrer les horaires
input int    InpSession1StartHour  = 8;          // Session 1 debut (h)
input int    InpSession1StartMin   = 0;          // Session 1 debut (min)
input int    InpSession1EndHour    = 12;         // Session 1 fin (h)
input int    InpSession1EndMin     = 0;          // Session 1 fin (min)
input bool   InpUseSession2        = true;       // Activer session 2
input int    InpSession2StartHour  = 13;         // Session 2 debut (h)
input int    InpSession2StartMin   = 30;         // Session 2 debut (min)
input int    InpSession2EndHour    = 18;         // Session 2 fin (h)
input int    InpSession2EndMin     = 0;          // Session 2 fin (min)

input group "===== 11. News (architecture) ====="
input bool   InpUseNewsFilter      = false;      // Filtre news (calendrier MT5)
input int    InpNewsBeforeMinutes  = 30;         // Minutes avant l'event
input int    InpNewsAfterMinutes   = 30;         // Minutes apres l'event
input bool   InpNewsHighOnly       = true;       // Uniquement importance haute
input bool   InpNewsInTester       = false;      // Appliquer aussi en backtest

input group "===== 12. Affichage ====="
input bool   InpShowDashboard      = true;       // Dashboard
input bool   InpShowLevels         = true;       // Pivots / S/R / VWAP
input bool   InpShowZones          = true;       // Zones support/resistance
input int    InpPanelX             = 12;         // Dashboard X
input int    InpPanelY             = 18;         // Dashboard Y
input int    InpPanelMinWidth      = 520;        // Largeur minimale
input double InpPanelFontScale     = 1.00;       // Densite texte (0.85-1.20)
input int    InpPanelFontSize      = 8;          // Taille de base

input group "===== 13. Alertes ====="
input bool   InpAlertPopup         = true;       // Popup Alert()
input bool   InpAlertSound         = true;       // Son
input bool   InpAlertPush          = false;      // Notification mobile
input bool   InpAlertBuy           = true;       // Alerte BUY
input bool   InpAlertSell          = true;       // Alerte SELL
input bool   InpAlertSetup         = false;      // Alerte setup (score proche)
input bool   InpAlertBlocked       = false;      // Alerte trade bloque
input bool   InpAlertDaily         = true;       // Alerte limite journaliere
input bool   InpAlertNews          = true;       // Alerte news

//==================================================================//
// CONSTANTES
//==================================================================//

#define OBJ_PREFIX    "XAU_EA_"
#define PANEL_TITLE   "SCALPING  XAUUSD  EA"
#define MAX_ROWS      36

#define ROW_TEXT      0
#define ROW_SEP       1
#define ROW_TITLE     2

#define STATUS_READY    0
#define STATUS_WAIT     1
#define STATUS_BLOCKED  2

//==================================================================//
// STRUCTURES
//==================================================================//

struct PivotLevels
{
   double pivot;
   double r1;
   double r2;
   double s1;
   double s2;
};

struct ZoneLevel
{
   double price;
   double lo;
   double hi;
   bool   valid;
   bool   important;
};

struct BreakoutMemory
{
   int      dir;          // 1 = resistance cassee, -1 = support casse
   double   level;
   datetime breakTime;
   int      breakBarM5;
   bool     retestDone;
};

struct ScoreCard
{
   int  buy;
   int  sell;
   int  maxScore;
   bool m15Buy;
   bool m15Sell;
   bool m5EmaFastBuy;
   bool m5EmaFastSell;
   bool m5EmaSlowBuy;
   bool m5EmaSlowSell;
   bool vwapBuy;
   bool vwapSell;
   bool rsiBuy;
   bool rsiSell;
   bool srBuy;
   bool srSell;
   bool rejectBuy;
   bool rejectSell;
   bool breakoutBuy;
   bool breakoutSell;
   bool retestBuy;
   bool retestSell;
   bool bbBuy;
   bool bbSell;
   bool structBuy;
   bool structSell;
};

struct MarketSnapshot
{
   datetime m1Time;

   int      trendM15;     // TREND_*
   int      biasM5;
   int      signalM1;     // 1 BUY, -1 SELL, 0 WAIT

   double   ema10_m15, ema20_m15, ema50_m15;
   double   ema10_m5,  ema20_m5,  ema50_m5;
   double   ema10_m1,  ema20_m1,  ema50_m1;

   double   rsiM15, rsiM5, rsiM1;
   double   vwap;
   double   atrM5, atrM1;

   double   bbMid, bbUpper, bbLower;

   double   closeM15, closeM5, closeM1;
   double   highM5, lowM5, openM5;
   double   highM1, lowM1, openM1;

   PivotLevels pivots;
   ZoneLevel   support;
   ZoneLevel   resist;

   bool     hhhl;
   bool     lhll;

   bool     pullbackBuy;
   bool     pullbackSell;
   bool     rejectionBuy;
   bool     rejectionSell;
   bool     hammer;
   bool     shooting;
   bool     engulfBuy;
   bool     engulfSell;
   bool     breakSwingHigh;
   bool     breakSwingLow;
   bool     higherLow;
   bool     lowerHigh;
   bool     breakoutBuy;
   bool     breakoutSell;
   bool     retestBuy;
   bool     retestSell;
   bool     bbBuy;
   bool     bbSell;
   bool     extendedM5;

   double   swingHighM1;
   double   swingLowM1;
   double   swingHighM5;
   double   swingLowM5;

   ScoreCard score;

   double   entry;
   double   sl;
   double   tp;
   double   lot;
   double   potentialProfit;
   double   potentialLoss;
   double   rr;

   int      status;       // READY / WAIT / BLOCKED
   string   reason;
};

struct DailyStats
{
   datetime day;
   int      trades;
   int      wins;
   int      losses;
   int      consecutiveLosses;
   double   realized;
   double   floating;
};

//==================================================================//
// GLOBALS
//==================================================================//

CTrade trade;

MarketSnapshot gSnap;
BreakoutMemory gBO;
DailyStats     gDay;

int gH_M15_E10 = INVALID_HANDLE, gH_M15_E20 = INVALID_HANDLE, gH_M15_E50 = INVALID_HANDLE;
int gH_M5_E10  = INVALID_HANDLE, gH_M5_E20  = INVALID_HANDLE, gH_M5_E50  = INVALID_HANDLE;
int gH_M1_E10  = INVALID_HANDLE, gH_M1_E20  = INVALID_HANDLE, gH_M1_E50  = INVALID_HANDLE;

int gH_M15_RSI = INVALID_HANDLE, gH_M5_RSI = INVALID_HANDLE, gH_M1_RSI = INVALID_HANDLE;
int gH_M5_BB   = INVALID_HANDLE, gH_M1_BB  = INVALID_HANDLE;
int gH_M5_ATR  = INVALID_HANDLE, gH_M1_ATR = INVALID_HANDLE;

datetime gLastM1Bar      = 0;
datetime gLastTradeTime  = 0;
ulong    gLastSetupId    = 0;
int      gLastAlertScore = 0;
datetime gLastNewsAlert  = 0;
datetime gLastDailyAlert = 0;

string gRowText[2][MAX_ROWS];
int    gRowSize[2][MAX_ROWS];
color  gRowColor[2][MAX_ROWS];
int    gRowKind[2][MAX_ROWS];
int    gRowCount[2];
int    gRowDrawn[2];
int    gCol;
double gPxPt    = 1.333;
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

double PriceToPoints(const double priceDist)
{
   double pt = PointValue();
   if(pt <= 0.0)
      return 0.0;
   return priceDist / pt;
}

int VolumeDigits()
{
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0)
      return 2;

   int d = 0;
   while(d < 8 && MathAbs(step - NormalizeDouble(step, d)) > 1e-12)
      d++;
   return d;
}

double NormalizeLot(double lot)
{
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(vmin <= 0.0)
      vmin = 0.01;
   if(vmax <= 0.0)
      vmax = 100.0;
   if(vstep <= 0.0)
      vstep = 0.01;

   lot = MathFloor(lot / vstep + 1e-12) * vstep;
   if(lot < vmin)
      lot = vmin;
   if(lot > vmax)
      lot = vmax;
   return NormalizeDouble(lot, VolumeDigits());
}

bool CopyBuf(const int handle, const int buf, const int count, double &dest[])
{
   if(handle == INVALID_HANDLE || count <= 0)
      return false;
   if(BarsCalculated(handle) < count)
      return false;

   ArraySetAsSeries(dest, true);
   return (CopyBuffer(handle, buf, 0, count, dest) == count);
}

bool ValidNum(const double v)
{
   return (v != 0.0 && MathIsValidNumber(v) && v != EMPTY_VALUE);
}

int ClosedShift(const ENUM_TIMEFRAMES tf, const datetime m1ClosedOpen)
{
   int sh = iBarShift(_Symbol, tf, m1ClosedOpen, false);
   if(sh < 0)
      return -1;

   datetime barOpen = iTime(_Symbol, tf, sh);
   if(barOpen <= 0)
      return -1;

   datetime m1Close = m1ClosedOpen + PeriodSeconds(PERIOD_M1);
   datetime tfClose = barOpen + PeriodSeconds(tf);

   if(m1Close < tfClose)
      sh++;

   return sh;
}

string TrendLabel(const int t)
{
   if(t > 0)
      return "HAUSSIER";
   if(t < 0)
      return "BAISSIER";
   return "NEUTRE";
}

string SignalLabel(const int s)
{
   if(s > 0)
      return "BUY";
   if(s < 0)
      return "SELL";
   return "WAIT";
}

color TrendClr(const int t, const color neutral)
{
   if(t > 0)
      return C'28,140,70';
   if(t < 0)
      return C'190,55,50';
   return neutral;
}

string Pad(string text, const int length)
{
   while(StringLen(text) < length)
      text += " ";
   return text;
}

ulong MakeSetupId(const int dir, const datetime t, const double level)
{
   long p = (long)MathRound(level / PointValue());
   return (ulong)((long)t ^ ((long)dir * 1000003) ^ (p * 9176));
}

void FireAlert(const bool enabled, const string msg)
{
   if(!enabled)
      return;

   if(InpAlertPopup)
      Alert(msg);
   if(InpAlertSound)
      PlaySound("alert.wav");
   if(InpAlertPush)
      SendNotification(msg);
}

void ResetSnapshot()
{
   MarketSnapshot empty;
   gSnap = empty;
   gSnap.reason = "";
   gSnap.status = STATUS_WAIT;
}

//==================================================================//
// INIT / DEINIT
//==================================================================//

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetAsyncMode(false);
   ApplyFilling();

   gH_M15_E10 = iMA(_Symbol, PERIOD_M15, InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
   gH_M15_E20 = iMA(_Symbol, PERIOD_M15, InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
   gH_M15_E50 = iMA(_Symbol, PERIOD_M15, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);

   gH_M5_E10  = iMA(_Symbol, PERIOD_M5, InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
   gH_M5_E20  = iMA(_Symbol, PERIOD_M5, InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
   gH_M5_E50  = iMA(_Symbol, PERIOD_M5, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);

   gH_M1_E10  = iMA(_Symbol, PERIOD_M1, InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
   gH_M1_E20  = iMA(_Symbol, PERIOD_M1, InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
   gH_M1_E50  = iMA(_Symbol, PERIOD_M1, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);

   gH_M15_RSI = iRSI(_Symbol, PERIOD_M15, InpRSIPeriod, PRICE_CLOSE);
   gH_M5_RSI  = iRSI(_Symbol, PERIOD_M5,  InpRSIPeriod, PRICE_CLOSE);
   gH_M1_RSI  = iRSI(_Symbol, PERIOD_M1,  InpRSIPeriod, PRICE_CLOSE);

   gH_M5_BB   = iBands(_Symbol, PERIOD_M5, InpBBPeriod, InpBBShift, InpBBDeviation, PRICE_CLOSE);
   gH_M1_BB   = iBands(_Symbol, PERIOD_M1, InpBBPeriod, InpBBShift, InpBBDeviation, PRICE_CLOSE);

   gH_M5_ATR  = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   gH_M1_ATR  = iATR(_Symbol, PERIOD_M1, InpATRPeriod);

   if(
      gH_M15_E10 == INVALID_HANDLE || gH_M15_E20 == INVALID_HANDLE || gH_M15_E50 == INVALID_HANDLE ||
      gH_M5_E10  == INVALID_HANDLE || gH_M5_E20  == INVALID_HANDLE || gH_M5_E50  == INVALID_HANDLE ||
      gH_M1_E10  == INVALID_HANDLE || gH_M1_E20  == INVALID_HANDLE || gH_M1_E50  == INVALID_HANDLE ||
      gH_M15_RSI == INVALID_HANDLE || gH_M5_RSI  == INVALID_HANDLE || gH_M1_RSI  == INVALID_HANDLE ||
      gH_M5_BB   == INVALID_HANDLE || gH_M1_BB   == INVALID_HANDLE ||
      gH_M5_ATR  == INVALID_HANDLE || gH_M1_ATR  == INVALID_HANDLE
   )
   {
      Print("[SCALPING] Echec creation des handles d'indicateurs.");
      return INIT_FAILED;
   }

   ResetSnapshot();
   ZeroMemory(gBO);
   ZeroMemory(gDay);
   gSnap.reason = "Initialisation";
   gSnap.status = STATUS_WAIT;

   ChartSetInteger(0, CHART_FOREGROUND, false);

   Print("[SCALPING] EA initialise | ", _Symbol, " | Magic ", InpMagic);
   Print("[SCALPING] Systeme experimental — backtester avant tout usage reel.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   PrintBacktestStats();

   ObjectsDeleteAll(0, OBJ_PREFIX, 0, -1);
   ChartRedraw(0);

   ReleaseH(gH_M15_E10); ReleaseH(gH_M15_E20); ReleaseH(gH_M15_E50);
   ReleaseH(gH_M5_E10);  ReleaseH(gH_M5_E20);  ReleaseH(gH_M5_E50);
   ReleaseH(gH_M1_E10);  ReleaseH(gH_M1_E20);  ReleaseH(gH_M1_E50);
   ReleaseH(gH_M15_RSI); ReleaseH(gH_M5_RSI);  ReleaseH(gH_M1_RSI);
   ReleaseH(gH_M5_BB);   ReleaseH(gH_M1_BB);
   ReleaseH(gH_M5_ATR);  ReleaseH(gH_M1_ATR);
}

void ReleaseH(int &h)
{
   if(h != INVALID_HANDLE)
   {
      IndicatorRelease(h);
      h = INVALID_HANDLE;
   }
}

void ApplyFilling()
{
   uint mode = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      trade.SetTypeFilling(ORDER_FILLING_IOC);
   else if((mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      trade.SetTypeFilling(ORDER_FILLING_FOK);
   else
      trade.SetTypeFilling(ORDER_FILLING_RETURN);
}

//==================================================================//
// TICK
//==================================================================//

void OnTick()
{
   ManagePositions();
   RefreshDailyStats();

   datetime m1Open = iTime(_Symbol, PERIOD_M1, 0);
   bool newM1 = (m1Open > 0 && m1Open != gLastM1Bar);

   if(!BuildSnapshot())
   {
      gSnap.status = STATUS_WAIT;
      gSnap.reason = "Synchronisation MTF...";
      UpdateDashboard();
      return;
   }

   if(newM1)
   {
      gLastM1Bar = m1Open;
      EvaluateAndTrade();
   }

   UpdateDashboard();
   DrawChartLevels();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
      UpdateDashboard();
}

//==================================================================//
// SNAPSHOT MULTI-TIMEFRAME
//==================================================================//

bool BuildSnapshot()
{
   const int n15 = 120;
   const int n5  = 160;
   const int n1  = 200;

   double e10_15[], e20_15[], e50_15[];
   double e10_5[],  e20_5[],  e50_5[];
   double e10_1[],  e20_1[],  e50_1[];
   double rsi15[], rsi5[], rsi1[];
   double bbMid[], bbUp[], bbLo[];
   double atr5[], atr1[];

   if(!CopyBuf(gH_M15_E10, 0, n15, e10_15)) return false;
   if(!CopyBuf(gH_M15_E20, 0, n15, e20_15)) return false;
   if(!CopyBuf(gH_M15_E50, 0, n15, e50_15)) return false;
   if(!CopyBuf(gH_M5_E10,  0, n5,  e10_5))  return false;
   if(!CopyBuf(gH_M5_E20,  0, n5,  e20_5))  return false;
   if(!CopyBuf(gH_M5_E50,  0, n5,  e50_5))  return false;
   if(!CopyBuf(gH_M1_E10,  0, n1,  e10_1))  return false;
   if(!CopyBuf(gH_M1_E20,  0, n1,  e20_1))  return false;
   if(!CopyBuf(gH_M1_E50,  0, n1,  e50_1))  return false;
   if(!CopyBuf(gH_M15_RSI, 0, n15, rsi15))  return false;
   if(!CopyBuf(gH_M5_RSI,  0, n5,  rsi5))   return false;
   if(!CopyBuf(gH_M1_RSI,  0, n1,  rsi1))   return false;
   if(!CopyBuf(gH_M5_BB,   0, n5,  bbMid))  return false;
   if(!CopyBuf(gH_M5_BB,   1, n5,  bbUp))   return false;
   if(!CopyBuf(gH_M5_BB,   2, n5,  bbLo))   return false;
   if(!CopyBuf(gH_M5_ATR,  0, n5,  atr5))   return false;
   if(!CopyBuf(gH_M1_ATR,  0, n1,  atr1))   return false;

   datetime m1Closed = iTime(_Symbol, PERIOD_M1, 1);
   if(m1Closed <= 0)
      return false;

   int s15 = ClosedShift(PERIOD_M15, m1Closed);
   int s5  = ClosedShift(PERIOD_M5,  m1Closed);
   int s1  = 1;

   if(s15 < 1 || s5 < 1)
      return false;
   if(s15 >= n15 - 5 || s5 >= n5 - 5)
      return false;

   ResetSnapshot();
   gSnap.m1Time = m1Closed;

   gSnap.ema10_m15 = e10_15[s15];
   gSnap.ema20_m15 = e20_15[s15];
   gSnap.ema50_m15 = e50_15[s15];
   gSnap.ema10_m5  = e10_5[s5];
   gSnap.ema20_m5  = e20_5[s5];
   gSnap.ema50_m5  = e50_5[s5];
   gSnap.ema10_m1  = e10_1[s1];
   gSnap.ema20_m1  = e20_1[s1];
   gSnap.ema50_m1  = e50_1[s1];

   gSnap.rsiM15 = rsi15[s15];
   gSnap.rsiM5  = rsi5[s5];
   gSnap.rsiM1  = rsi1[s1];

   gSnap.bbMid   = bbMid[s5];
   gSnap.bbUpper = bbUp[s5];
   gSnap.bbLower = bbLo[s5];
   gSnap.atrM5   = atr5[s5];
   gSnap.atrM1   = atr1[s1];

   gSnap.closeM15 = iClose(_Symbol, PERIOD_M15, s15);
   gSnap.closeM5  = iClose(_Symbol, PERIOD_M5,  s5);
   gSnap.closeM1  = iClose(_Symbol, PERIOD_M1,  s1);
   gSnap.highM5   = iHigh(_Symbol,  PERIOD_M5,  s5);
   gSnap.lowM5    = iLow(_Symbol,   PERIOD_M5,  s5);
   gSnap.openM5   = iOpen(_Symbol,  PERIOD_M5,  s5);
   gSnap.highM1   = iHigh(_Symbol,  PERIOD_M1,  s1);
   gSnap.lowM1    = iLow(_Symbol,   PERIOD_M1,  s1);
   gSnap.openM1   = iOpen(_Symbol,  PERIOD_M1,  s1);

   if(!ValidNum(gSnap.closeM1) || !ValidNum(gSnap.atrM5))
      return false;

   gSnap.vwap   = CalculateVWAP(m1Closed);
   gSnap.pivots = CalculatePivotLevels();

   gSnap.trendM15 = GetM15Trend(gSnap, s15);
   gSnap.biasM5   = GetM5Trend(gSnap, s5);

   DetectSupport(gSnap, s5);
   DetectResistance(gSnap, s5);
   DetectStructureM15(gSnap, s15);
   DetectPriceAction(gSnap, s1, s5);
   DetectBreakout(gSnap, s5);
   DetectRetest(gSnap, s5);
   DetectPullback(gSnap);
   DetectBollingerBias(gSnap);

   gSnap.extendedM5 = IsExtendedCandle(gSnap.highM5, gSnap.lowM5, gSnap.atrM5);

   CalculateBuyScore(gSnap);
   CalculateSellScore(gSnap);

   gSnap.signalM1 = GetM1Signal(gSnap);

   PrepareTradeLevels(gSnap);
   ApplyStatusFilters(gSnap);

   return true;
}

//==================================================================//
// TENDANCES
//==================================================================//

int GetM15Trend(const MarketSnapshot &s, const int shift)
{
   if(!ValidNum(s.ema10_m15) || !ValidNum(s.ema20_m15) || !ValidNum(s.ema50_m15))
      return TREND_NEUTRAL;

   double minSep = (s.atrM5 > 0.0 ? s.atrM5 * InpMinEMASpreadATR * MathSqrt(3.0) : 0.0);

   bool stackedUp =
      (s.ema10_m15 > s.ema20_m15) &&
      (s.ema20_m15 > s.ema50_m15) &&
      (s.closeM15 > s.ema50_m15) &&
      ((s.ema10_m15 - s.ema50_m15) >= minSep);

   bool stackedDn =
      (s.ema10_m15 < s.ema20_m15) &&
      (s.ema20_m15 < s.ema50_m15) &&
      (s.closeM15 < s.ema50_m15) &&
      ((s.ema50_m15 - s.ema10_m15) >= minSep);

   if(!stackedUp && !stackedDn)
      return TREND_NEUTRAL;

   int structDir = StructureDir(PERIOD_M15, shift, InpSwingLookbackM15);
   bool vwapOkUp = (s.vwap <= 0.0 || s.closeM15 >= s.vwap);
   bool vwapOkDn = (s.vwap <= 0.0 || s.closeM15 <= s.vwap);

   if(stackedUp && structDir >= 0 && vwapOkUp)
      return TREND_BULL;
   if(stackedDn && structDir <= 0 && vwapOkDn)
      return TREND_BEAR;

   if(stackedUp && structDir >= 0)
      return TREND_BULL;
   if(stackedDn && structDir <= 0)
      return TREND_BEAR;

   return TREND_NEUTRAL;
}

int GetM5Trend(const MarketSnapshot &s, const int shift)
{
   if(!ValidNum(s.ema10_m5) || !ValidNum(s.ema20_m5) || !ValidNum(s.ema50_m5))
      return TREND_NEUTRAL;

   double minSep = (s.atrM5 > 0.0 ? s.atrM5 * InpMinEMASpreadATR : 0.0);

   if(s.ema10_m5 > s.ema20_m5 && s.ema20_m5 > s.ema50_m5 &&
      s.closeM5 > s.ema50_m5 && (s.ema10_m5 - s.ema50_m5) >= minSep)
      return TREND_BULL;

   if(s.ema10_m5 < s.ema20_m5 && s.ema20_m5 < s.ema50_m5 &&
      s.closeM5 < s.ema50_m5 && (s.ema50_m5 - s.ema10_m5) >= minSep)
      return TREND_BEAR;

   if(s.ema20_m5 > s.ema50_m5 && s.closeM5 > s.ema50_m5)
      return TREND_BULL;
   if(s.ema20_m5 < s.ema50_m5 && s.closeM5 < s.ema50_m5)
      return TREND_BEAR;

   return TREND_NEUTRAL;
}

int GetM1Signal(const MarketSnapshot &s)
{
   if(s.trendM15 == TREND_BULL && s.biasM5 >= 0 && s.score.buy >= InpMinScore)
   {
      bool pa =
         s.rejectionBuy || s.hammer || s.engulfBuy ||
         s.breakSwingHigh || s.higherLow || s.retestBuy;
      bool emaOk = (s.ema10_m1 >= s.ema20_m1 || s.closeM1 > s.ema20_m1);
      bool rsiOk = (s.rsiM1 >= 48.0);
      if(pa && emaOk && rsiOk)
         return 1;
   }

   if(s.trendM15 == TREND_BEAR && s.biasM5 <= 0 && s.score.sell >= InpMinScore)
   {
      bool pa =
         s.rejectionSell || s.shooting || s.engulfSell ||
         s.breakSwingLow || s.lowerHigh || s.retestSell;
      bool emaOk = (s.ema10_m1 <= s.ema20_m1 || s.closeM1 < s.ema20_m1);
      bool rsiOk = (s.rsiM1 <= 52.0);
      if(pa && emaOk && rsiOk)
         return -1;
   }

   return 0;
}

int StructureDir(const ENUM_TIMEFRAMES tf, const int shift, const int lookback)
{
   double sh1 = 0.0, sh2 = 0.0, sl1 = 0.0, sl2 = 0.0;
   if(!LastTwoSwings(tf, shift, lookback, sh1, sh2, sl1, sl2))
      return 0;

   bool hh = (sh1 > sh2);
   bool hl = (sl1 > sl2);
   bool lh = (sh1 < sh2);
   bool ll = (sl1 < sl2);

   if(hh && hl)
      return 1;
   if(lh && ll)
      return -1;
   return 0;
}

//==================================================================//
// VWAP / PIVOTS
//==================================================================//

double CalculateVWAP(const datetime untilOpen)
{
   datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
   if(dayStart <= 0)
      dayStart = untilOpen - (untilOpen % PeriodSeconds(PERIOD_D1));

   int from = iBarShift(_Symbol, PERIOD_M1, dayStart, false);
   int to   = iBarShift(_Symbol, PERIOD_M1, untilOpen, false);
   if(from < 0 || to < 0 || from < to)
      return 0.0;

   double num = 0.0;
   double den = 0.0;

   int bars = from - to + 1;
   if(bars > 1500)
      bars = 1500;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M1, to, bars, rates);
   if(copied <= 0)
      return 0.0;

   for(int i = 0; i < copied; i++)
   {
      if(rates[i].time > untilOpen)
         continue;
      if(rates[i].time < dayStart)
         continue;

      double tp = (rates[i].high + rates[i].low + rates[i].close) / 3.0;
      double vol = (double)rates[i].tick_volume;
      if(vol <= 0.0)
         vol = 1.0;
      num += tp * vol;
      den += vol;
   }

   if(den <= 0.0)
      return 0.0;
   return num / den;
}

PivotLevels CalculatePivotLevels()
{
   PivotLevels p;
   ZeroMemory(p);

   ENUM_TIMEFRAMES tf = (InpPivotPeriod == PIVOT_WEEKLY ? PERIOD_W1 : PERIOD_D1);

   double h = iHigh(_Symbol,  tf, 1);
   double l = iLow(_Symbol,   tf, 1);
   double c = iClose(_Symbol, tf, 1);

   if(!ValidNum(h) || !ValidNum(l) || !ValidNum(c) || h < l)
      return p;

   p.pivot = (h + l + c) / 3.0;
   p.r1    = (2.0 * p.pivot) - l;
   p.s1    = (2.0 * p.pivot) - h;
   p.r2    = p.pivot + (h - l);
   p.s2    = p.pivot - (h - l);
   return p;
}

//==================================================================//
// SUPPORT / RESISTANCE
//==================================================================//

void DetectSupport(MarketSnapshot &s, const int s5)
{
   s.support.valid = false;

   double swing = LastSwingLow(PERIOD_M5, s5 + 1, InpSwingLookbackM5);
   double recent = RecentExtreme(PERIOD_M5, s5 + 1, InpSRLookback, false);

   double candidates[6];
   int n = 0;
   if(swing > 0.0)                 candidates[n++] = swing;
   if(recent > 0.0)                candidates[n++] = recent;
   if(s.pivots.s1 > 0.0)           candidates[n++] = s.pivots.s1;
   if(s.pivots.s2 > 0.0)           candidates[n++] = s.pivots.s2;
   if(s.pivots.pivot > 0.0)        candidates[n++] = s.pivots.pivot;
   if(s.vwap > 0.0 && s.vwap < s.closeM5) candidates[n++] = s.vwap;

   double best = 0.0;
   double bestDist = DBL_MAX;
   bool important = false;
   double zone = PointsToPrice(InpSRZonePoints);

   for(int i = 0; i < n; i++)
   {
      if(candidates[i] >= s.closeM5)
         continue;
      double d = s.closeM5 - candidates[i];
      if(d < bestDist)
      {
         bestDist = d;
         best = candidates[i];
      }
   }

   if(best <= 0.0)
      return;

   int hits = 0;
   for(int i = 0; i < n; i++)
   {
      if(MathAbs(candidates[i] - best) <= zone)
         hits++;
   }
   important = (hits >= 2);

   s.support.price     = best;
   s.support.lo        = best - zone * 0.5;
   s.support.hi        = best + zone * 0.5;
   s.support.valid     = true;
   s.support.important = important;
}

void DetectResistance(MarketSnapshot &s, const int s5)
{
   s.resist.valid = false;

   double swing  = LastSwingHigh(PERIOD_M5, s5 + 1, InpSwingLookbackM5);
   double recent = RecentExtreme(PERIOD_M5, s5 + 1, InpSRLookback, true);

   double candidates[6];
   int n = 0;
   if(swing > 0.0)                  candidates[n++] = swing;
   if(recent > 0.0)                 candidates[n++] = recent;
   if(s.pivots.r1 > 0.0)            candidates[n++] = s.pivots.r1;
   if(s.pivots.r2 > 0.0)            candidates[n++] = s.pivots.r2;
   if(s.pivots.pivot > 0.0)         candidates[n++] = s.pivots.pivot;
   if(s.vwap > 0.0 && s.vwap > s.closeM5) candidates[n++] = s.vwap;

   double best = 0.0;
   double bestDist = DBL_MAX;
   double zone = PointsToPrice(InpSRZonePoints);

   for(int i = 0; i < n; i++)
   {
      if(candidates[i] <= s.closeM5)
         continue;
      double d = candidates[i] - s.closeM5;
      if(d < bestDist)
      {
         bestDist = d;
         best = candidates[i];
      }
   }

   if(best <= 0.0)
      return;

   int hits = 0;
   for(int i = 0; i < n; i++)
   {
      if(MathAbs(candidates[i] - best) <= zone)
         hits++;
   }

   s.resist.price     = best;
   s.resist.lo        = best - zone * 0.5;
   s.resist.hi        = best + zone * 0.5;
   s.resist.valid     = true;
   s.resist.important = (hits >= 2);
}

bool PriceInZone(const double price, const ZoneLevel &z)
{
   if(!z.valid)
      return false;
   return (price >= z.lo && price <= z.hi);
}

double LastSwingHigh(const ENUM_TIMEFRAMES tf, const int fromShift, const int lookback)
{
   int strength = MathMax(1, InpSwingBars);
   int end = fromShift + lookback;
   int bars = Bars(_Symbol, tf);
   if(end >= bars - strength - 1)
      end = bars - strength - 2;

   for(int i = fromShift + strength; i <= end; i++)
   {
      if(IsSwingHigh(tf, i, strength))
         return iHigh(_Symbol, tf, i);
   }
   return 0.0;
}

double LastSwingLow(const ENUM_TIMEFRAMES tf, const int fromShift, const int lookback)
{
   int strength = MathMax(1, InpSwingBars);
   int end = fromShift + lookback;
   int bars = Bars(_Symbol, tf);
   if(end >= bars - strength - 1)
      end = bars - strength - 2;

   for(int i = fromShift + strength; i <= end; i++)
   {
      if(IsSwingLow(tf, i, strength))
         return iLow(_Symbol, tf, i);
   }
   return 0.0;
}

bool IsSwingHigh(const ENUM_TIMEFRAMES tf, const int i, const int strength)
{
   double h = iHigh(_Symbol, tf, i);
   for(int k = 1; k <= strength; k++)
   {
      if(iHigh(_Symbol, tf, i - k) >= h)
         return false;
      if(iHigh(_Symbol, tf, i + k) >= h)
         return false;
   }
   return true;
}

bool IsSwingLow(const ENUM_TIMEFRAMES tf, const int i, const int strength)
{
   double l = iLow(_Symbol, tf, i);
   for(int k = 1; k <= strength; k++)
   {
      if(iLow(_Symbol, tf, i - k) <= l)
         return false;
      if(iLow(_Symbol, tf, i + k) <= l)
         return false;
   }
   return true;
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
         if(h > best)
            best = h;
      }
      else
      {
         double l = iLow(_Symbol, tf, fromShift + k);
         if(l < best)
            best = l;
      }
   }

   if(best == -DBL_MAX || best == DBL_MAX)
      return 0.0;
   return best;
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
   int end = fromShift + lookback;
   int bars = Bars(_Symbol, tf);
   if(end >= bars - strength - 1)
      end = bars - strength - 2;

   for(int i = fromShift + strength; i <= end; i++)
   {
      if(foundH < 2 && IsSwingHigh(tf, i, strength))
      {
         if(foundH == 0) sh1 = iHigh(_Symbol, tf, i);
         else            sh2 = iHigh(_Symbol, tf, i);
         foundH++;
      }
      if(foundL < 2 && IsSwingLow(tf, i, strength))
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

void DetectStructureM15(MarketSnapshot &s, const int s15)
{
   double sh1, sh2, sl1, sl2;
   if(!LastTwoSwings(PERIOD_M15, s15, InpSwingLookbackM15, sh1, sh2, sl1, sl2))
      return;
   s.hhhl = (sh1 > sh2 && sl1 > sl2);
   s.lhll = (sh1 < sh2 && sl1 < sl2);
}

//==================================================================//
// PRICE ACTION (regles mathematiques, bougie M1 cloturee)
//==================================================================//

void DetectPriceAction(MarketSnapshot &s, const int s1, const int s5)
{
   double o = s.openM1;
   double h = s.highM1;
   double l = s.lowM1;
   double c = s.closeM1;
   double range = h - l;
   double body  = MathAbs(c - o);
   double upper = h - MathMax(o, c);
   double lower = MathMin(o, c) - l;

   if(range > 0.0)
   {
      bool smallBody = (body <= range * InpMaxBodyRatio);

      s.hammer =
         smallBody &&
         (lower >= body * InpPinWickBodyRatio) &&
         (upper <= range * 0.30) &&
         (c >= l + range * 0.55);

      s.shooting =
         smallBody &&
         (upper >= body * InpPinWickBodyRatio) &&
         (lower <= range * 0.30) &&
         (c <= h - range * 0.55);

      s.rejectionBuy  = s.hammer || (lower >= range * 0.55 && c > o);
      s.rejectionSell = s.shooting || (upper >= range * 0.55 && c < o);
   }

   double po = iOpen(_Symbol,  PERIOD_M1, s1 + 1);
   double pc = iClose(_Symbol, PERIOD_M1, s1 + 1);
   double prevBody = MathAbs(pc - po);
   if(prevBody > 0.0 && body > prevBody)
   {
      bool prevBear = (pc < po);
      bool prevBull = (pc > po);
      s.engulfBuy  = prevBear && (c > o) && (o <= pc) && (c >= po);
      s.engulfSell = prevBull && (c < o) && (o >= pc) && (c <= po);
   }

   s.swingHighM1 = LastSwingHigh(PERIOD_M1, s1 + 1, InpSwingLookbackM1);
   s.swingLowM1  = LastSwingLow(PERIOD_M1,  s1 + 1, InpSwingLookbackM1);
   s.swingHighM5 = LastSwingHigh(PERIOD_M5, s5 + 1, InpSwingLookbackM5);
   s.swingLowM5  = LastSwingLow(PERIOD_M5,  s5 + 1, InpSwingLookbackM5);

   double bos = (s.atrM1 > 0.0 ? s.atrM1 * InpBOSBufferATR : PointsToPrice(5));

   if(s.swingHighM1 > 0.0)
      s.breakSwingHigh = (c > s.swingHighM1 + bos);
   if(s.swingLowM1 > 0.0)
      s.breakSwingLow  = (c < s.swingLowM1 - bos);

   double sh1, sh2, sl1, sl2;
   if(LastTwoSwings(PERIOD_M1, s1, InpSwingLookbackM1, sh1, sh2, sl1, sl2))
   {
      s.higherLow = (sl1 > sl2);
      s.lowerHigh = (sh1 < sh2);
   }
}

bool DetectBullishRejection(const MarketSnapshot &s) { return s.rejectionBuy;  }
bool DetectBearishRejection(const MarketSnapshot &s) { return s.rejectionSell; }

bool IsExtendedCandle(const double high, const double low, const double atr)
{
   if(atr <= 0.0 || InpMaxCandleATR <= 0.0)
      return false;
   return ((high - low) > atr * InpMaxCandleATR);
}

//==================================================================//
// BREAKOUT + RETEST  (memoire M5, confirmation M1)
//==================================================================//

void DetectBreakout(MarketSnapshot &s, const int s5)
{
   double bos = (s.atrM5 > 0.0 ? s.atrM5 * InpBOSBufferATR : PointsToPrice(8));
   datetime t5 = iTime(_Symbol, PERIOD_M5, s5);

   if(s.resist.valid && s.closeM5 > s.resist.hi + bos)
   {
      s.breakoutBuy = true;
      if(gBO.dir != 1 || MathAbs(gBO.level - s.resist.price) > PointsToPrice(InpSRZonePoints))
      {
         gBO.dir        = 1;
         gBO.level      = s.resist.price;
         gBO.breakTime  = t5;
         gBO.breakBarM5 = s5;
         gBO.retestDone = false;
      }
   }

   if(s.support.valid && s.closeM5 < s.support.lo - bos)
   {
      s.breakoutSell = true;
      if(gBO.dir != -1 || MathAbs(gBO.level - s.support.price) > PointsToPrice(InpSRZonePoints))
      {
         gBO.dir        = -1;
         gBO.level      = s.support.price;
         gBO.breakTime  = t5;
         gBO.breakBarM5 = s5;
         gBO.retestDone = false;
      }
   }

   if(gBO.dir != 0 && gBO.breakTime > 0)
   {
      int age = iBarShift(_Symbol, PERIOD_M5, gBO.breakTime, false);
      if(age < 0 || age > InpRetestMaxBars + 8)
         ZeroMemory(gBO);
   }
}

void DetectRetest(MarketSnapshot &s, const int s5)
{
   if(gBO.dir == 0 || gBO.level <= 0.0)
      return;

   int age = iBarShift(_Symbol, PERIOD_M5, gBO.breakTime, false);
   if(age < 1 || age > InpRetestMaxBars)
      return;

   double zone = PointsToPrice(InpSRZonePoints);
   bool touched =
      (s.lowM5  <= gBO.level + zone * 0.5) &&
      (s.highM5 >= gBO.level - zone * 0.5);

   if(!touched)
      return;

   if(gBO.dir == 1 && s.closeM5 >= gBO.level && (s.rejectionBuy || s.closeM5 > s.openM5))
   {
      gBO.retestDone = true;
      s.retestBuy    = true;
      s.breakoutBuy  = true;
   }

   if(gBO.dir == -1 && s.closeM5 <= gBO.level && (s.rejectionSell || s.closeM5 < s.openM5))
   {
      gBO.retestDone = true;
      s.retestSell   = true;
      s.breakoutSell = true;
   }
}

void DetectPullback(MarketSnapshot &s)
{
   double tol = (s.atrM5 > 0.0 ? s.atrM5 * InpPullbackATR : PointsToPrice(30));

   bool nearEmaBuy =
      Near(s.closeM5, s.ema10_m5, tol) ||
      Near(s.closeM5, s.ema20_m5, tol) ||
      Near(s.closeM5, s.ema50_m5, tol);
   bool nearEmaSell = nearEmaBuy;

   bool nearVWAP = (s.vwap > 0.0 && Near(s.closeM5, s.vwap, tol));
   bool nearBB   = Near(s.closeM5, s.bbMid, tol) || Near(s.closeM5, s.bbLower, tol) || Near(s.closeM5, s.bbUpper, tol);

   s.pullbackBuy =
      (s.trendM15 == TREND_BULL) &&
      (nearEmaBuy || PriceInZone(s.lowM5, s.support) || nearVWAP || nearBB) &&
      (s.closeM5 > s.ema50_m5 || s.closeM5 > s.ema20_m5);

   s.pullbackSell =
      (s.trendM15 == TREND_BEAR) &&
      (nearEmaSell || PriceInZone(s.highM5, s.resist) || nearVWAP || nearBB) &&
      (s.closeM5 < s.ema50_m5 || s.closeM5 < s.ema20_m5);
}

bool Near(const double a, const double b, const double tol)
{
   if(b <= 0.0)
      return false;
   return (MathAbs(a - b) <= tol);
}

void DetectBollingerBias(MarketSnapshot &s)
{
   if(!ValidNum(s.bbMid) || !ValidNum(s.bbLower) || !ValidNum(s.bbUpper))
      return;

   double width = s.bbUpper - s.bbLower;
   if(width <= 0.0)
      return;

   // Confirmation seulement : rejet depuis bande + retour vers la moyenne.
   s.bbBuy =
      (s.lowM5 <= s.bbLower + width * 0.08) &&
      (s.closeM5 > s.bbLower) &&
      (s.closeM5 > s.openM5) &&
      (s.closeM5 < s.bbMid + width * 0.15);

   s.bbSell =
      (s.highM5 >= s.bbUpper - width * 0.08) &&
      (s.closeM5 < s.bbUpper) &&
      (s.closeM5 < s.openM5) &&
      (s.closeM5 > s.bbMid - width * 0.15);
}

//==================================================================//
// SCORING
//==================================================================//

int ScoreMax()
{
   return (
      InpW_M15Trend + InpW_M5EmaFast + InpW_M5EmaSlow + InpW_VWAP +
      InpW_RSI + InpW_SR + InpW_Rejection + InpW_Breakout +
      InpW_Retest + InpW_BB + InpW_Structure
   );
}

void CalculateBuyScore(MarketSnapshot &s)
{
   ScoreCard sc = s.score;
   sc.maxScore = ScoreMax();
   sc.buy = 0;

   sc.m15Buy = (s.trendM15 == TREND_BULL);
   if(sc.m15Buy) sc.buy += InpW_M15Trend;

   sc.m5EmaFastBuy = (s.ema10_m5 > s.ema20_m5);
   if(sc.m5EmaFastBuy) sc.buy += InpW_M5EmaFast;

   sc.m5EmaSlowBuy = (s.ema20_m5 > s.ema50_m5);
   if(sc.m5EmaSlowBuy) sc.buy += InpW_M5EmaSlow;

   sc.vwapBuy = (s.vwap > 0.0 && s.closeM1 > s.vwap);
   if(sc.vwapBuy) sc.buy += InpW_VWAP;

   sc.rsiBuy = (s.rsiM1 > 50.0 && s.rsiM5 >= 48.0);
   if(sc.rsiBuy) sc.buy += InpW_RSI;

   sc.srBuy = (s.support.valid && (PriceInZone(s.lowM1, s.support) || PriceInZone(s.lowM5, s.support) || s.support.important));
   if(sc.srBuy) sc.buy += InpW_SR;

   sc.rejectBuy = (DetectBullishRejection(s) || s.hammer || s.engulfBuy);
   if(sc.rejectBuy) sc.buy += InpW_Rejection;

   sc.breakoutBuy = s.breakoutBuy;
   if(sc.breakoutBuy) sc.buy += InpW_Breakout;

   sc.retestBuy = s.retestBuy;
   if(sc.retestBuy) sc.buy += InpW_Retest;

   sc.bbBuy = s.bbBuy;
   if(sc.bbBuy) sc.buy += InpW_BB;

   sc.structBuy = (s.hhhl || s.higherLow);
   if(sc.structBuy) sc.buy += InpW_Structure;

   s.score = sc;
}

void CalculateSellScore(MarketSnapshot &s)
{
   ScoreCard sc = s.score;
   sc.maxScore = ScoreMax();
   sc.sell = 0;

   sc.m15Sell = (s.trendM15 == TREND_BEAR);
   if(sc.m15Sell) sc.sell += InpW_M15Trend;

   sc.m5EmaFastSell = (s.ema10_m5 < s.ema20_m5);
   if(sc.m5EmaFastSell) sc.sell += InpW_M5EmaFast;

   sc.m5EmaSlowSell = (s.ema20_m5 < s.ema50_m5);
   if(sc.m5EmaSlowSell) sc.sell += InpW_M5EmaSlow;

   sc.vwapSell = (s.vwap > 0.0 && s.closeM1 < s.vwap);
   if(sc.vwapSell) sc.sell += InpW_VWAP;

   sc.rsiSell = (s.rsiM1 < 50.0 && s.rsiM5 <= 52.0);
   if(sc.rsiSell) sc.sell += InpW_RSI;

   sc.srSell = (s.resist.valid && (PriceInZone(s.highM1, s.resist) || PriceInZone(s.highM5, s.resist) || s.resist.important));
   if(sc.srSell) sc.sell += InpW_SR;

   sc.rejectSell = (DetectBearishRejection(s) || s.shooting || s.engulfSell);
   if(sc.rejectSell) sc.sell += InpW_Rejection;

   sc.breakoutSell = s.breakoutSell;
   if(sc.breakoutSell) sc.sell += InpW_Breakout;

   sc.retestSell = s.retestSell;
   if(sc.retestSell) sc.sell += InpW_Retest;

   sc.bbSell = s.bbSell;
   if(sc.bbSell) sc.sell += InpW_BB;

   sc.structSell = (s.lhll || s.lowerHigh);
   if(sc.structSell) sc.sell += InpW_Structure;

   s.score = sc;
}

//==================================================================//
// RISQUE : LOT / SL / TP
//==================================================================//

double CalculateLotSize(const double entry, const double sl)
{
   if(InpLotMode == LOT_FIXED)
      return NormalizeLot(InpFixedLot);

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = equity * InpRiskPercent / 100.0;
   double dist = MathAbs(entry - sl);
   double tickSize  = TickSize();
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   if(riskMoney <= 0.0 || dist <= 0.0 || tickSize <= 0.0 || tickValue <= 0.0)
      return NormalizeLot(InpFixedLot);

   double ticks = dist / tickSize;
   double lot   = riskMoney / (ticks * tickValue);
   return NormalizeLot(lot);
}

double MoneyFromDistance(const double dist, const double lot)
{
   double tickSize  = TickSize();
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0.0 || tickValue <= 0.0 || dist <= 0.0 || lot <= 0.0)
      return 0.0;
   return (dist / tickSize) * tickValue * lot;
}

double CalculateStopLoss(const int dir, const MarketSnapshot &s, const double entry)
{
   double buffer = PointsToPrice(InpSLBufferPoints);
   double sl = 0.0;

   if(InpSLMode == SL_FIXED)
   {
      double d = PointsToPrice(InpSLFixedPoints);
      sl = (dir > 0 ? entry - d : entry + d);
   }
   else if(InpSLMode == SL_ATR)
   {
      double d = s.atrM5 * InpSLATRMult;
      if(d <= 0.0)
         d = PointsToPrice(InpSLFixedPoints);
      sl = (dir > 0 ? entry - d : entry + d);
   }
   else
   {
      if(dir > 0)
      {
         sl = entry;
         if(s.swingLowM1 > 0.0)
            sl = MathMin(sl, s.swingLowM1);
         if(s.support.valid)
            sl = MathMin(sl, s.support.lo);
         if(s.lowM1 > 0.0)
            sl = MathMin(sl, s.lowM1);
         if(sl >= entry)
            sl = entry - s.atrM5 * InpSLATRMult;
         sl -= buffer;
      }
      else
      {
         sl = entry;
         if(s.swingHighM1 > 0.0)
            sl = MathMax(sl, s.swingHighM1);
         if(s.resist.valid)
            sl = MathMax(sl, s.resist.hi);
         if(s.highM1 > 0.0)
            sl = MathMax(sl, s.highM1);
         if(sl <= entry)
            sl = entry + s.atrM5 * InpSLATRMult;
         sl += buffer;
      }
   }

   return NormalizePrice(sl);
}

double CalculateTakeProfit(const int dir, const MarketSnapshot &s, const double entry, const double sl)
{
   double risk = MathAbs(entry - sl);
   double tp   = 0.0;

   if(InpTPMode == TP_FIXED)
   {
      double d = PointsToPrice(InpTPFixedPoints);
      tp = (dir > 0 ? entry + d : entry - d);
   }
   else if(InpTPMode == TP_RR)
   {
      double d = risk * InpRRRatio;
      tp = (dir > 0 ? entry + d : entry - d);
   }
   else
   {
      double buf = PointsToPrice(InpTPBufferPoints);
      if(dir > 0)
      {
         if(s.resist.valid && s.resist.lo > entry)
            tp = s.resist.lo - buf;
         else if(s.pivots.r1 > entry)
            tp = s.pivots.r1 - buf;
         else
            tp = entry + risk * InpRRRatio;
      }
      else
      {
         if(s.support.valid && s.support.hi < entry)
            tp = s.support.hi + buf;
         else if(s.pivots.s1 > 0.0 && s.pivots.s1 < entry)
            tp = s.pivots.s1 + buf;
         else
            tp = entry - risk * InpRRRatio;
      }

      if(risk > 0.0)
      {
         double rr = MathAbs(tp - entry) / risk;
         if(rr < InpMinRR)
            tp = (dir > 0 ? entry + risk * InpMinRR : entry - risk * InpMinRR);
      }
   }

   return NormalizePrice(tp);
}

void PrepareTradeLevels(MarketSnapshot &s)
{
   int dir = 0;
   if(s.score.buy >= InpMinScore && s.score.buy >= s.score.sell)
      dir = 1;
   else if(s.score.sell >= InpMinScore && s.score.sell > s.score.buy)
      dir = -1;

   if(s.signalM1 != 0)
      dir = s.signalM1;

   if(dir == 0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   s.entry = (dir > 0 ? ask : bid);
   s.sl    = CalculateStopLoss(dir, s, s.entry);
   s.tp    = CalculateTakeProfit(dir, s, s.entry, s.sl);
   s.lot   = CalculateLotSize(s.entry, s.sl);

   double risk = MathAbs(s.entry - s.sl);
   double rew  = MathAbs(s.tp - s.entry);
   s.rr = (risk > 0.0 ? rew / risk : 0.0);
   s.potentialLoss   = MoneyFromDistance(risk, s.lot);
   s.potentialProfit = MoneyFromDistance(rew,  s.lot);
}

//==================================================================//
// FILTRES
//==================================================================//

bool CheckSpread()
{
   long spr = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(InpMaxSpreadPoints <= 0)
      return true;
   return (spr <= InpMaxSpreadPoints);
}

bool CheckTradingHours()
{
   if(!InpUseSessionFilter)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int now = dt.hour * 60 + dt.min;

   int s1a = InpSession1StartHour * 60 + InpSession1StartMin;
   int s1b = InpSession1EndHour   * 60 + InpSession1EndMin;
   if(InRangeMin(now, s1a, s1b))
      return true;

   if(InpUseSession2)
   {
      int s2a = InpSession2StartHour * 60 + InpSession2StartMin;
      int s2b = InpSession2EndHour   * 60 + InpSession2EndMin;
      if(InRangeMin(now, s2a, s2b))
         return true;
   }
   return false;
}

bool InRangeMin(const int now, const int a, const int b)
{
   if(a == b)
      return true;
   if(a < b)
      return (now >= a && now < b);
   return (now >= a || now < b);
}

bool CheckNews()
{
   if(!InpUseNewsFilter)
      return true;

   if((MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) && !InpNewsInTester)
      return true;

   datetime now = TimeCurrent();
   datetime from = now - (datetime)InpNewsBeforeMinutes * 60;
   datetime to   = now + (datetime)InpNewsAfterMinutes  * 60;

   MqlCalendarValue values[];
   int n = CalendarValueHistory(values, from, to, "US", NULL);
   if(n < 0)
      return true;

   for(int i = 0; i < n; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(values[i].event_id, ev))
         continue;

      if(InpNewsHighOnly && ev.importance < CALENDAR_IMPORTANCE_HIGH)
         continue;

      if(!NewsEventRelevant(ev.name))
         continue;

      datetime t = (datetime)values[i].time;
      if(t >= from && t <= to)
      {
         if(InpAlertNews && gLastNewsAlert != t)
         {
            gLastNewsAlert = t;
            FireAlert(true, "[SCALPING] NEWS FILTER | " + ev.name);
         }
         return false;
      }
   }
   return true;
}

bool NewsEventRelevant(const string name)
{
   string u = name;
   StringToUpper(u);
   return (
      StringFind(u, "FOMC") >= 0 ||
      StringFind(u, "CPI") >= 0 ||
      StringFind(u, "NFP") >= 0 ||
      StringFind(u, "NONFARM") >= 0 ||
      StringFind(u, "NON-FARM") >= 0 ||
      StringFind(u, "PAYROLL") >= 0 ||
      StringFind(u, "PCE") >= 0 ||
      StringFind(u, "FED") >= 0 ||
      StringFind(u, "INTEREST RATE") >= 0 ||
      StringFind(u, "FEDERAL FUNDS") >= 0 ||
      StringFind(u, "UNEMPLOYMENT") >= 0 ||
      StringFind(u, "GDP") >= 0
   );
}

int CountOurPositions()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      n++;
   }
   return n;
}

void RefreshDailyStats()
{
   datetime dayStart = iTime(_Symbol, PERIOD_D1, 0);
   if(dayStart <= 0)
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      dt.hour = 0; dt.min = 0; dt.sec = 0;
      dayStart = StructToTime(dt);
   }

   if(gDay.day != dayStart)
   {
      ZeroMemory(gDay);
      gDay.day = dayStart;
   }

   gDay.realized = 0.0;
   gDay.trades   = 0;
   gDay.wins     = 0;
   gDay.losses   = 0;
   gDay.consecutiveLosses = 0;

   if(!HistorySelect(dayStart, TimeCurrent()))
      return;

   int cons = 0;
   bool consBroken = false;

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      double p =
         HistoryDealGetDouble(ticket, DEAL_PROFIT) +
         HistoryDealGetDouble(ticket, DEAL_SWAP) +
         HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      gDay.realized += p;
      gDay.trades++;
      if(p >= 0.0)
         gDay.wins++;
      else
         gDay.losses++;

      if(!consBroken)
      {
         if(p < 0.0)
            cons++;
         else
            consBroken = true;
      }
   }

   gDay.consecutiveLosses = cons;

   gDay.floating = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      gDay.floating +=
         PositionGetDouble(POSITION_PROFIT) +
         PositionGetDouble(POSITION_SWAP);
   }
}

bool CheckDailyLimits(string &why)
{
   if(InpMaxTradesPerDay > 0 && gDay.trades >= InpMaxTradesPerDay)
   {
      why = "Max trades / jour atteint";
      return false;
   }
   if(InpMaxConsecutiveLoss > 0 && gDay.consecutiveLosses >= InpMaxConsecutiveLoss)
   {
      why = "Pertes consecutives max";
      return false;
   }

   double pnl = gDay.realized + gDay.floating;

   if(InpDailyProfitTarget > 0.0 && pnl >= InpDailyProfitTarget)
   {
      why = "Objectif journalier atteint";
      return false;
   }
   if(InpDailyLossLimit > 0.0 && pnl <= -MathAbs(InpDailyLossLimit))
   {
      why = "Perte journaliere max";
      return false;
   }
   return true;
}

bool CheckVolatility(const MarketSnapshot &s, string &why)
{
   if(InpMinATR > 0.0 && s.atrM5 < InpMinATR)
   {
      why = "ATR trop faible (marche calme)";
      return false;
   }
   if(InpMaxATR > 0.0 && s.atrM5 > InpMaxATR)
   {
      why = "ATR trop eleve (volatilite extreme)";
      return false;
   }
   if(InpAvoidExtendedEntry && s.extendedM5)
   {
      why = "Bougie M5 trop etendue";
      return false;
   }
   return true;
}

bool CheckRisk(const MarketSnapshot &s, const int dir, string &why)
{
   if(s.lot <= 0.0)
   {
      why = "Lot invalide";
      return false;
   }

   double slPts = PriceToPoints(MathAbs(s.entry - s.sl));
   double tpPts = PriceToPoints(MathAbs(s.tp - s.entry));

   if(InpMaxSLPoints > 0.0 && slPts > InpMaxSLPoints)
   {
      why = "SL trop grand";
      return false;
   }
   if(tpPts < 10.0)
   {
      why = "TP trop proche";
      return false;
   }
   if(s.rr + 1e-8 < InpMinRR)
   {
      why = "RR insuffisant (" + DoubleToString(s.rr, 2) + ")";
      return false;
   }

   int stops = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stops * PointValue();
   if(minDist > 0.0)
   {
      if(MathAbs(s.entry - s.sl) < minDist || MathAbs(s.tp - s.entry) < minDist)
      {
         why = "SL/TP sous stops_level";
         return false;
      }
   }

   if(dir > 0 && s.sl >= s.entry)
   {
      why = "SL BUY invalide";
      return false;
   }
   if(dir < 0 && s.sl <= s.entry)
   {
      why = "SL SELL invalide";
      return false;
   }
   return true;
}

void ApplyStatusFilters(MarketSnapshot &s)
{
   string why = "";

   if(!CheckTradingHours())
   {
      s.status = STATUS_BLOCKED;
      s.reason = "Hors horaires de trading";
      return;
   }
   if(!CheckSpread())
   {
      s.status = STATUS_BLOCKED;
      s.reason = "Spread trop eleve (" + IntegerToString((int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)) + " pts)";
      return;
   }
   if(!CheckNews())
   {
      s.status = STATUS_BLOCKED;
      s.reason = "Filtre news actif";
      return;
   }
   if(!CheckDailyLimits(why))
   {
      s.status = STATUS_BLOCKED;
      s.reason = why;
      if(InpAlertDaily && gLastDailyAlert != gDay.day)
      {
         gLastDailyAlert = gDay.day;
         FireAlert(true, "[SCALPING] LIMITE JOURNALIERE | " + why);
      }
      return;
   }
   if(CountOurPositions() >= InpMaxPositions)
   {
      s.status = STATUS_BLOCKED;
      s.reason = "Position deja ouverte";
      return;
   }
   if(InpCooldownSeconds > 0 && gLastTradeTime > 0 &&
      (TimeCurrent() - gLastTradeTime) < InpCooldownSeconds)
   {
      s.status = STATUS_BLOCKED;
      s.reason = "Cooldown actif";
      return;
   }
   if(!CheckVolatility(s, why))
   {
      s.status = STATUS_BLOCKED;
      s.reason = why;
      return;
   }
   if(s.trendM15 == TREND_NEUTRAL)
   {
      s.status = STATUS_WAIT;
      s.reason = "M15 neutre — pas de trade";
      return;
   }
   if(s.signalM1 == 0)
   {
      s.status = STATUS_WAIT;
      if(s.trendM15 == TREND_BULL && s.score.buy < InpMinScore)
         s.reason = "Score BUY " + IntegerToString(s.score.buy) + "/" + IntegerToString(s.score.maxScore) + " < " + IntegerToString(InpMinScore);
      else if(s.trendM15 == TREND_BEAR && s.score.sell < InpMinScore)
         s.reason = "Score SELL " + IntegerToString(s.score.sell) + "/" + IntegerToString(s.score.maxScore) + " < " + IntegerToString(InpMinScore);
      else if(s.biasM5 != 0 && s.biasM5 != s.trendM15)
         s.reason = "M5 contradictoire avec M15";
      else if(s.trendM15 == TREND_BULL && !s.pullbackBuy && !s.retestBuy)
         s.reason = "Attente pullback / retest M5";
      else
         s.reason = "Attente confirmation M1";
      return;
   }

   if(!CheckRisk(s, s.signalM1, why))
   {
      s.status = STATUS_BLOCKED;
      s.reason = why;
      return;
   }

   if(s.signalM1 > 0 && !s.pullbackBuy && !s.retestBuy && !s.breakoutBuy)
   {
      s.status = STATUS_WAIT;
      s.reason = "Pas de zone M5 (pullback/retest)";
      return;
   }
   if(s.signalM1 < 0 && !s.pullbackSell && !s.retestSell && !s.breakoutSell)
   {
      s.status = STATUS_WAIT;
      s.reason = "Pas de zone M5 (pullback/retest)";
      return;
   }

   s.status = STATUS_READY;
   s.reason = (s.signalM1 > 0 ? "Setup BUY valide" : "Setup SELL valide");
}

//==================================================================//
// ENTREES
//==================================================================//

void EvaluateAndTrade()
{
   if(gSnap.status != STATUS_READY || gSnap.signalM1 == 0)
   {
      if(gSnap.status == STATUS_BLOCKED && InpAlertBlocked)
      {
         static datetime lastBlk = 0;
         if(gSnap.m1Time != lastBlk)
         {
            lastBlk = gSnap.m1Time;
            FireAlert(true, "[SCALPING] BLOQUE | " + gSnap.reason);
         }
      }

      if(InpAlertSetup)
      {
         int best = MathMax(gSnap.score.buy, gSnap.score.sell);
         if(best >= InpMinScore - 1 && best < InpMinScore && best != gLastAlertScore)
         {
            gLastAlertScore = best;
            FireAlert(true, "[SCALPING] SETUP PROCHE | BUY " +
                      IntegerToString(gSnap.score.buy) + " SELL " +
                      IntegerToString(gSnap.score.sell));
         }
      }
      return;
   }

   ulong setupId = MakeSetupId(
      gSnap.signalM1,
      (gBO.breakTime > 0 ? gBO.breakTime : gSnap.m1Time),
      (gSnap.signalM1 > 0
         ? (gSnap.support.valid ? gSnap.support.price : gSnap.closeM5)
         : (gSnap.resist.valid  ? gSnap.resist.price  : gSnap.closeM5))
   );

   if(setupId == gLastSetupId)
   {
      gSnap.status = STATUS_WAIT;
      gSnap.reason = "Setup deja trade";
      Print("[SCALPING] NO TRADE — setup identique (anti-doublon)");
      return;
   }

   if(gSnap.signalM1 > 0)
      OpenBuy(gSnap, setupId);
   else
      OpenSell(gSnap, setupId);
}

void LogDecision(const int dir, const MarketSnapshot &s, const bool executed, const string extra)
{
   string side = (dir > 0 ? "BUY" : "SELL");
   PrintFormat(
      "[SCALPING] M15=%s M5=%s M1=%s  %s SCORE=%d/%d  %s",
      TrendLabel(s.trendM15),
      TrendLabel(s.biasM5),
      SignalLabel(s.signalM1),
      side,
      (dir > 0 ? s.score.buy : s.score.sell),
      s.score.maxScore,
      extra
   );

   if(dir > 0)
   {
      PrintFormat(
         "[SCALPING] Support=%s Rejet=%s Breakout=%s Retest=%s BB=%s HL=%s Spread=%d",
         (s.score.srBuy ? "oui" : "non"),
         (s.score.rejectBuy ? "oui" : "non"),
         (s.score.breakoutBuy ? "oui" : "non"),
         (s.score.retestBuy ? "oui" : "non"),
         (s.score.bbBuy ? "oui" : "non"),
         (s.score.structBuy ? "oui" : "non"),
         (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)
      );
   }
   else
   {
      PrintFormat(
         "[SCALPING] Resist=%s Rejet=%s Breakout=%s Retest=%s BB=%s LH=%s Spread=%d",
         (s.score.srSell ? "oui" : "non"),
         (s.score.rejectSell ? "oui" : "non"),
         (s.score.breakoutSell ? "oui" : "non"),
         (s.score.retestSell ? "oui" : "non"),
         (s.score.bbSell ? "oui" : "non"),
         (s.score.structSell ? "oui" : "non"),
         (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD)
      );
   }

   if(executed)
      Print("[SCALPING] ", side, " EXECUTED | Lot ", DoubleToString(s.lot, 2),
            " SL ", DoubleToString(s.sl, _Digits),
            " TP ", DoubleToString(s.tp, _Digits),
            " RR 1:", DoubleToString(s.rr, 2),
            " Pot+ ", DoubleToString(s.potentialProfit, 2), " USD");
   else
      Print("[SCALPING] ", side, " REJECTED | ", extra);
}

bool OpenBuy(const MarketSnapshot &s, const ulong setupId)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl  = CalculateStopLoss(1, s, ask);
   double tp  = CalculateTakeProfit(1, s, ask, sl);
   double lot = CalculateLotSize(ask, sl);

   MarketSnapshot tmp = s;
   tmp.entry = ask;
   tmp.sl = sl;
   tmp.tp = tp;
   tmp.lot = lot;
   tmp.rr = (MathAbs(ask - sl) > 0.0 ? MathAbs(tp - ask) / MathAbs(ask - sl) : 0.0);
   tmp.potentialLoss   = MoneyFromDistance(MathAbs(ask - sl), lot);
   tmp.potentialProfit = MoneyFromDistance(MathAbs(tp - ask), lot);

   string why;
   if(!CheckRisk(tmp, 1, why))
   {
      LogDecision(1, tmp, false, why);
      return false;
   }
   if(!CheckSpread())
   {
      LogDecision(1, tmp, false, "Spread");
      return false;
   }

   string cmt = InpTradeComment + " B" + IntegerToString(tmp.score.buy);
   if(!trade.Buy(lot, _Symbol, ask, sl, tp, cmt))
   {
      LogDecision(1, tmp, false, "OrderSend " + IntegerToString(trade.ResultRetcode()) + " " + trade.ResultRetcodeDescription());
      return false;
   }

   gLastSetupId   = setupId;
   gLastTradeTime = TimeCurrent();
   LogDecision(1, tmp, true, "Spread OK Risk OK RR OK");
   FireAlert(InpAlertBuy,
             _Symbol + " BUY | Score " + IntegerToString(tmp.score.buy) + "/" +
             IntegerToString(tmp.score.maxScore) +
             " | Lot " + DoubleToString(lot, 2) +
             " | SL " + DoubleToString(sl, _Digits) +
             " | TP " + DoubleToString(tp, _Digits));
   return true;
}

bool OpenSell(const MarketSnapshot &s, const ulong setupId)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl  = CalculateStopLoss(-1, s, bid);
   double tp  = CalculateTakeProfit(-1, s, bid, sl);
   double lot = CalculateLotSize(bid, sl);

   MarketSnapshot tmp = s;
   tmp.entry = bid;
   tmp.sl = sl;
   tmp.tp = tp;
   tmp.lot = lot;
   tmp.rr = (MathAbs(bid - sl) > 0.0 ? MathAbs(tp - bid) / MathAbs(bid - sl) : 0.0);
   tmp.potentialLoss   = MoneyFromDistance(MathAbs(bid - sl), lot);
   tmp.potentialProfit = MoneyFromDistance(MathAbs(tp - bid), lot);

   string why;
   if(!CheckRisk(tmp, -1, why))
   {
      LogDecision(-1, tmp, false, why);
      return false;
   }
   if(!CheckSpread())
   {
      LogDecision(-1, tmp, false, "Spread");
      return false;
   }

   string cmt = InpTradeComment + " S" + IntegerToString(tmp.score.sell);
   if(!trade.Sell(lot, _Symbol, bid, sl, tp, cmt))
   {
      LogDecision(-1, tmp, false, "OrderSend " + IntegerToString(trade.ResultRetcode()) + " " + trade.ResultRetcodeDescription());
      return false;
   }

   gLastSetupId   = setupId;
   gLastTradeTime = TimeCurrent();
   LogDecision(-1, tmp, true, "Spread OK Risk OK RR OK");
   FireAlert(InpAlertSell,
             _Symbol + " SELL | Score " + IntegerToString(tmp.score.sell) + "/" +
             IntegerToString(tmp.score.maxScore) +
             " | Lot " + DoubleToString(lot, 2) +
             " | SL " + DoubleToString(sl, _Digits) +
             " | TP " + DoubleToString(tp, _Digits));
   return true;
}

//==================================================================//
// GESTION DES POSITIONS
//==================================================================//

void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;

      ManageBreakEven(ticket);
      ManageTrailingStop(ticket);
   }
}

double PositionRiskPrice(const ulong ticket)
{
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl   = PositionGetDouble(POSITION_SL);
   if(sl <= 0.0)
      return 0.0;
   return MathAbs(open - sl);
}

void ManageBreakEven(const ulong ticket)
{
   if(!InpBEEnabled)
      return;

   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl   = PositionGetDouble(POSITION_SL);
   double tp   = PositionGetDouble(POSITION_TP);
   long   type = PositionGetInteger(POSITION_TYPE);

   double risk = PositionRiskPrice(ticket);
   if(risk <= 0.0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double offset = PointsToPrice(InpBEOffsetPoints);
   double trigger = risk * InpBETriggerR;

   if(type == POSITION_TYPE_BUY)
   {
      if(bid - open < trigger)
         return;
      double newSL = NormalizePrice(open + offset);
      if(newSL <= sl)
         return;
      if(newSL >= bid)
         return;
      trade.PositionModify(ticket, newSL, tp);
   }
   else
   {
      if(open - ask < trigger)
         return;
      double newSL = NormalizePrice(open - offset);
      if(sl > 0.0 && newSL >= sl)
         return;
      if(newSL <= ask)
         return;
      trade.PositionModify(ticket, newSL, tp);
   }
}

void ManageTrailingStop(const ulong ticket)
{
   if(InpTrailMode == TRAIL_NONE)
      return;

   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl   = PositionGetDouble(POSITION_SL);
   double tp   = PositionGetDouble(POSITION_TP);
   long   type = PositionGetInteger(POSITION_TYPE);

   double risk = PositionRiskPrice(ticket);
   if(risk <= 0.0)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   double profit = (type == POSITION_TYPE_BUY ? bid - open : open - ask);
   if(profit < risk * InpTrailStartR)
      return;

   double trailDist = PointsToPrice(InpTrailFixedPoints);

   if(InpTrailMode == TRAIL_ATR && gSnap.atrM5 > 0.0)
      trailDist = gSnap.atrM5 * InpTrailATRMult;
   else if(InpTrailMode == TRAIL_EMA && gSnap.ema20_m1 > 0.0)
   {
      if(type == POSITION_TYPE_BUY)
      {
         double newSL = NormalizePrice(gSnap.ema20_m1);
         if(newSL > sl && newSL < bid)
            trade.PositionModify(ticket, newSL, tp);
         return;
      }
      double newSLs = NormalizePrice(gSnap.ema20_m1);
      if((sl <= 0.0 || newSLs < sl) && newSLs > ask)
         trade.PositionModify(ticket, newSLs, tp);
      return;
   }

   if(trailDist <= 0.0)
      return;

   if(type == POSITION_TYPE_BUY)
   {
      double newSL = NormalizePrice(bid - trailDist);
      if(newSL > sl && newSL < bid)
         trade.PositionModify(ticket, newSL, tp);
   }
   else
   {
      double newSL = NormalizePrice(ask + trailDist);
      if((sl <= 0.0 || newSL < sl) && newSL > ask)
         trade.PositionModify(ticket, newSL, tp);
   }
}

//==================================================================//
// STATS BACKTEST
//==================================================================//

void PrintBacktestStats()
{
   if(!MQLInfoInteger(MQL_TESTER))
      return;

   if(!HistorySelect(0, TimeCurrent()))
      return;

   int trades = 0, buys = 0, sells = 0, wins = 0, losses = 0;
   double grossWin = 0.0, grossLoss = 0.0, profit = 0.0;
   double sumWin = 0.0, sumLoss = 0.0;
   int maxCons = 0, cons = 0;
   double peak = 0.0, dd = 0.0, eq = 0.0;

   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0)
         continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      if((long)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic)
         continue;
      if((int)HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT)
         continue;

      double p =
         HistoryDealGetDouble(ticket, DEAL_PROFIT) +
         HistoryDealGetDouble(ticket, DEAL_SWAP) +
         HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      long dtype = HistoryDealGetInteger(ticket, DEAL_TYPE);
      trades++;
      if(dtype == DEAL_TYPE_SELL)
         buys++;
      else
         sells++;

      profit += p;
      eq += p;
      if(eq > peak)
         peak = eq;
      if(peak - eq > dd)
         dd = peak - eq;

      if(p >= 0.0)
      {
         wins++;
         grossWin += p;
         sumWin += p;
         cons = 0;
      }
      else
      {
         losses++;
         grossLoss += -p;
         sumLoss += -p;
         cons++;
         if(cons > maxCons)
            maxCons = cons;
      }
   }

   double wr = (trades > 0 ? 100.0 * wins / trades : 0.0);
   double pf = (grossLoss > 0.0 ? grossWin / grossLoss : 0.0);

   Print("========== STATS BACKTEST XAUUSD EA ==========");
   PrintFormat("Trades=%d  BUY(cloture SELL deal)=%d  SELL=%d", trades, buys, sells);
   PrintFormat("WinRate=%.1f%%  ProfitFactor=%.2f  Profit=%.2f  DD=%.2f", wr, pf, profit, dd);
   PrintFormat("Gain moy=%.2f  Perte moy=%.2f  Pertes consec max=%d",
               (wins > 0 ? sumWin / wins : 0.0),
               (losses > 0 ? sumLoss / losses : 0.0),
               maxCons);
   Print("================================================");
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

void DrawZoneRect(const string id, const double lo, const double hi, const color clr)
{
   string name = OBJ_PREFIX + id;
   datetime t1 = TimeCurrent() - PeriodSeconds(PERIOD_H1) * 6;
   datetime t2 = TimeCurrent() + PeriodSeconds(PERIOD_M15) * 8;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, hi, t2, lo);

   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, hi);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, lo);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DrawChartLevels()
{
   if(MQLInfoInteger(MQL_OPTIMIZATION))
      return;

   if(!InpShowLevels)
   {
      ObjectsDeleteAll(0, OBJ_PREFIX + "LV_", 0, -1);
      ObjectsDeleteAll(0, OBJ_PREFIX + "ZN_", 0, -1);
      return;
   }

   if(gSnap.vwap > 0.0)
      DrawHLine("LV_VWAP", gSnap.vwap, C'210,160,40', STYLE_SOLID, 2,
                "VWAP " + DoubleToString(gSnap.vwap, _Digits));

   if(InpShowPivots && gSnap.pivots.pivot > 0.0)
   {
      DrawHLine("LV_P",  gSnap.pivots.pivot, C'90,90,90',   STYLE_DASH, 1, "P");
      DrawHLine("LV_R1", gSnap.pivots.r1,    C'170,70,70',  STYLE_DOT,  1, "R1");
      DrawHLine("LV_R2", gSnap.pivots.r2,    C'140,50,50',  STYLE_DOT,  1, "R2");
      DrawHLine("LV_S1", gSnap.pivots.s1,    C'40,120,80',  STYLE_DOT,  1, "S1");
      DrawHLine("LV_S2", gSnap.pivots.s2,    C'30,100,65',  STYLE_DOT,  1, "S2");
   }

   if(InpShowZones)
   {
      if(gSnap.support.valid)
         DrawZoneRect("ZN_SUP", gSnap.support.lo, gSnap.support.hi, C'200,230,210');
      if(gSnap.resist.valid)
         DrawZoneRect("ZN_RES", gSnap.resist.lo, gSnap.resist.hi, C'240,210,205');
   }
}

//==================================================================//
// DASHBOARD
//==================================================================//

double PanelPxPerPoint()
{
   double dpi = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(dpi < 72.0)
      dpi = 96.0;
   double scale = InpPanelFontScale;
   if(scale < 0.50) scale = 0.50;
   if(scale > 2.00) scale = 2.00;
   return (dpi / 72.0) * scale;
}

int RowAdvancePx(const int kind, const int fontSize)
{
   if(kind == ROW_SEP)
      return (int)MathCeil(8.0 * gPxPt);
   return (int)MathCeil(fontSize * gPxPt * 1.52);
}

int TextWidthPx(const string text, const int fontSize)
{
   return (int)MathCeil(StringLen(text) * fontSize * gPxPt * 0.58) + 4;
}

void RowReset()
{
   gRowCount[0] = 0;
   gRowCount[1] = 0;
   gCol = 0;
}

void AddRow(const int kind, const string text, const int fontSize, const color clr)
{
   int n = gRowCount[gCol];
   if(n >= MAX_ROWS)
      return;
   gRowKind[gCol][n]  = kind;
   gRowText[gCol][n]  = text;
   gRowSize[gCol][n]  = fontSize;
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
   if(gCol == 0)
      gCol = 1;
   else
      RowSep();
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

color ScoreClr(const int score, const int minScore)
{
   if(score >= minScore)
      return C'28,140,70';
   if(score >= minScore - 2)
      return C'170,125,20';
   return C'120,100,90';
}

string StatusText(const int st)
{
   if(st == STATUS_READY)
      return "READY";
   if(st == STATUS_BLOCKED)
      return "BLOCKED";
   return "WAIT";
}

color StatusClr(const int st)
{
   if(st == STATUS_READY)
      return C'28,140,70';
   if(st == STATUS_BLOCKED)
      return C'190,55,50';
   return C'175,125,25';
}

void BuildPanelRows()
{
   RowReset();

   int fs    = (int)MathMax(6, gFontBase);
   int fsBig = fs + 2;
   int fsSml = (int)MathMax(6, fs - 1);
   color txt = C'42,42,42';
   color dim = C'125,118,105';
   int lab = 11;

   Row(Pad("STATUT", lab) + StatusText(gSnap.status), fsBig, StatusClr(gSnap.status));
   Row(gSnap.reason, fsSml, dim);
   RowSep();

   RowTitle("MULTI-TIMEFRAME");
   Row(Pad("M15", lab) + TrendLabel(gSnap.trendM15), fs, TrendClr(gSnap.trendM15, txt));
   Row(Pad("M5",  lab) + TrendLabel(gSnap.biasM5),   fs, TrendClr(gSnap.biasM5, txt));
   Row(Pad("M1",  lab) + SignalLabel(gSnap.signalM1), fs, TrendClr(gSnap.signalM1, C'130,110,0'));
   RowSep();

   RowTitle("SCORE");
   Row(Pad("BUY",  lab) + IntegerToString(gSnap.score.buy)  + " / " + IntegerToString(gSnap.score.maxScore),
       fs, ScoreClr(gSnap.score.buy, InpMinScore));
   Row(Pad("SELL", lab) + IntegerToString(gSnap.score.sell) + " / " + IntegerToString(gSnap.score.maxScore),
       fs, ScoreClr(gSnap.score.sell, InpMinScore));
   Row(Pad("MINI", lab) + IntegerToString(InpMinScore), fsSml, dim);
   RowSep();

   RowTitle("INDICATEURS");
   Row(Pad("EMA10", lab) + DoubleToString(gSnap.ema10_m5, _Digits), fs, C'20,130,180');
   Row(Pad("EMA20", lab) + DoubleToString(gSnap.ema20_m5, _Digits), fs, C'180,140,20');
   Row(Pad("EMA50", lab) + DoubleToString(gSnap.ema50_m5, _Digits), fs, C'120,90,170');
   Row(Pad("RSI15", lab) + DoubleToString(gSnap.rsiM15, 1), fs, txt);
   Row(Pad("RSI5",  lab) + DoubleToString(gSnap.rsiM5,  1), fs, txt);
   Row(Pad("RSI1",  lab) + DoubleToString(gSnap.rsiM1,  1), fs, txt);
   Row(Pad("VWAP",  lab) + DoubleToString(gSnap.vwap, _Digits), fs, C'180,130,20');

   NextColumn();

   RowTitle("PIVOTS / S-R");
   Row(Pad("PIVOT", lab) + DoubleToString(gSnap.pivots.pivot, _Digits), fs, txt);
   Row(Pad("R1",    lab) + DoubleToString(gSnap.pivots.r1, _Digits), fs, C'170,70,70');
   Row(Pad("R2",    lab) + DoubleToString(gSnap.pivots.r2, _Digits), fs, C'140,50,50');
   Row(Pad("S1",    lab) + DoubleToString(gSnap.pivots.s1, _Digits), fs, C'40,120,80');
   Row(Pad("S2",    lab) + DoubleToString(gSnap.pivots.s2, _Digits), fs, C'30,100,65');
   Row(Pad("SUP",   lab) + (gSnap.support.valid ? DoubleToString(gSnap.support.price, _Digits) : "--"),
       fs, C'40,120,80');
   Row(Pad("RES",   lab) + (gSnap.resist.valid ? DoubleToString(gSnap.resist.price, _Digits) : "--"),
       fs, C'170,70,70');
   RowSep();

   RowTitle("RISQUE");
   long spr = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   Row(Pad("SPREAD", lab) + IntegerToString((int)spr) + " pts",
       fs, (CheckSpread() ? txt : C'190,55,50'));
   Row(Pad("ATR M5", lab) + DoubleToString(gSnap.atrM5, _Digits), fs, txt);
   Row(Pad("RISQUE", lab) + DoubleToString(InpRiskPercent, 2) + " %", fs, txt);
   Row(Pad("LOT",    lab) + DoubleToString(gSnap.lot, VolumeDigits()), fs, txt);
   Row(Pad("POT +",  lab) + DoubleToString(gSnap.potentialProfit, 2) + " USD", fs, C'28,140,70');
   Row(Pad("POT -",  lab) + DoubleToString(gSnap.potentialLoss, 2) + " USD", fs, C'190,55,50');
   Row(Pad("RR",     lab) + "1:" + DoubleToString(gSnap.rr, 2), fs, txt);
   RowSep();

   RowTitle("JOUR");
   Row(Pad("TRADES", lab) + IntegerToString(gDay.trades), fs, txt);
   Row(Pad("P/L",    lab) + DoubleToString(gDay.realized + gDay.floating, 2) + " USD",
       fs, ((gDay.realized + gDay.floating) >= 0.0 ? C'28,140,70' : C'190,55,50'));
   Row(Pad("PERTES", lab) + IntegerToString(gDay.consecutiveLosses) + " consec.", fsSml, dim);
}

void UpdateDashboard()
{
   if(MQLInfoInteger(MQL_OPTIMIZATION) || !InpShowDashboard)
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
   int gap = (int)MathCeil(18.0 * gPxPt);
   int accent = (int)MathMax(4, MathRound(4.0 * gPxPt));

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
               if(w > colW[c])
                  colW[c] = w;
            }
            colH[c] += RowAdvancePx(gRowKind[c][i], gRowSize[c][i]);
         }
      }

      int inner = colW[0] + gap + colW[1];
      int tw = TextWidthPx(PANEL_TITLE, gFontBase + 2);
      if(tw > inner)
         inner = tw;

      headerH =
         RowAdvancePx(ROW_TEXT, gFontBase + 2) +
         RowAdvancePx(ROW_SEP, 1);

      width  = accent + pad * 2 + inner;
      height = pad * 2 + headerH + (int)MathMax(colH[0], colH[1]);

      if(base == 6)
         break;
      bool fitW = (maxW <= 0 || width  <= maxW);
      bool fitH = (maxH <= 0 || height <= maxH);
      if(fitW && fitH)
         break;
   }

   if(width < InpPanelMinWidth)
      width = InpPanelMinWidth;

   color accentClr = StatusClr(gSnap.status);

   CreateRect(OBJ_PREFIX + "PANEL_BG", InpPanelX, InpPanelY, width, height,
              C'245,238,225', C'178,164,140');
   CreateRect(OBJ_PREFIX + "PANEL_ACCENT", InpPanelX, InpPanelY, accent, height,
              accentClr, accentClr);

   int contentX = InpPanelX + accent + pad;

   SetLabel(OBJ_PREFIX + "HDR", PANEL_TITLE, contentX, InpPanelY + pad,
            gFontBase + 2, C'28,28,28');
   SetSeparator(OBJ_PREFIX + "HDRSEP",
                contentX,
                InpPanelY + pad + headerH - RowAdvancePx(ROW_SEP, 1) / 2,
                width - accent - pad * 2,
                C'196,182,162');

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

   ChartRedraw(0);
}

//+------------------------------------------------------------------+

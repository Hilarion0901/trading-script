//+------------------------------------------------------------------+
//|                  XAUUSD SCALPING V3.3                            |
//|                                                                  |
//|  M15 = Direction                                                 |
//|  M5  = Zone / Retest                                             |
//|  M1  = Confirmation / BOS                                        |
//|                                                                  |
//|  EMA 10 / 20 / 50   +   ATR 14   +   ADX                         |
//|  Support / Resistance / Swings                                   |
//|  Signaux calcules sur bougies CLOTUREES (non repeints)           |
//+------------------------------------------------------------------+

#property copyright "Custom"
#property version   "3.30"
#property description "XAUUSD Scalping M15-M5-M1 - signaux non repeints + niveaux graphiques"
#property indicator_chart_window

//==================================================================//
// INDICATOR PLOTS
//==================================================================//

#property indicator_buffers 5
#property indicator_plots   5

// EMA 10
#property indicator_label1  "EMA 10"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

// EMA 20
#property indicator_label2  "EMA 20"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

// EMA 50
#property indicator_label3  "EMA 50"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMediumPurple
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

// BUY arrow
#property indicator_label4  "BUY"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_width4  3

// SELL arrow
#property indicator_label5  "SELL"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRed
#property indicator_width5  3

//==================================================================//
// INPUTS
//==================================================================//

input group "===== EMA / ATR / ADX ====="
input int    EMA10_Period          = 10;
input int    EMA20_Period          = 20;
input int    EMA50_Period          = 50;
input int    ATR_Period            = 14;
input int    ADX_Period            = 14;

input group "===== Structure ====="
input int    SwingBars             = 3;      // Force du fractal (bougies de chaque cote)
input int    LookbackBars          = 50;     // Bougies M5 pour Support / Resistance
input int    Swing_Lookback_M1     = 60;     // Bougies M1 pour le dernier swing
input double Retest_ATR_Distance   = 0.35;   // Tolerance de retest (x ATR)
input int    Retest_Lookback_Bars  = 6;      // Bougies max depuis le touche de zone
input bool   Retest_On_EMA         = true;   // Accepter un pullback sur EMA20/50
input double BOS_Buffer_ATR        = 0.05;   // Marge de cassure (x ATR)

input group "===== Filtres de precision ====="
input bool   Require_M1_EMA_Align  = false;  // Exiger aussi l'alignement EMA M1
input bool   Use_H1_Bias           = true;   // Biais H1 (EMA20/50) non contraire
input bool   Use_ADX_Filter        = true;   // Rejeter les marches sans tendance
input double ADX_Min               = 20.0;
input double Min_EMA_Spread_ATR    = 0.10;   // Ecartement mini EMA10/EMA50 (x ATR)
input bool   Require_Candle_Confirm= true;   // Bougie de signal directionnelle
input double Min_Body_Ratio        = 0.50;   // Corps / range mini
input double Min_ATR               = 0.0;    // 0 = desactive
input double Max_ATR               = 0.0;    // 0 = desactive (volatilite extreme)
input long   Max_Spread_Points     = 60;     // 0 = desactive
input int    Cooldown_Bars         = 5;      // Bougies mini entre 2 signaux
input int    Min_Score             = 70;     // Score mini pour valider (0-100)

input group "===== Risque ====="
input double SL_ATR_Mult           = 1.20;   // SL mini en ATR
input double TP1_RR                = 1.0;
input double TP2_RR                = 2.0;
input double Min_RR_To_Level       = 1.30;   // Espace mini vers le niveau oppose

input group "===== Session (heure serveur) ====="
input bool   Use_Session_Filter    = true;
input int    Session_Start_Hour    = 8;
input int    Session_End_Hour      = 21;

input group "===== Affichage ====="
input bool   Show_EMA              = true;
input bool   Show_Signals          = true;
input bool   Show_Panel            = true;
input bool   Show_Levels           = true;   // Lignes S/R + swings
input bool   Show_Zones            = true;   // Zones de retest
input bool   Show_Trade_Levels     = true;   // Entree / SL / TP du dernier signal
input int    Signal_History_Bars   = 300;    // Profondeur d'historique des fleches

input group "===== Panneau ====="
input int    Panel_X               = 15;
input int    Panel_Y               = 20;
input int    Panel_Width           = 260;    // Largeur MINIMALE (auto-ajustee)
input bool   Panel_Two_Columns     = true;   // Deux colonnes = moins haut
input double Panel_Font_Scale      = 1.00;   // Densite : 0.85 serre, 1.20 aere
input int    Panel_Font_Size       = 8;      // Taille de base du texte

input group "===== Alertes ====="
input bool   Enable_Alerts         = true;
input bool   Enable_Sound          = true;
input bool   Enable_Push           = false;

//==================================================================//
// CONSTANTS
//==================================================================//

#define OBJ_PREFIX  "XAU33_"
#define PANEL_TITLE "XAUUSD  SCALPING V3.3"

//==================================================================//
// BUFFERS
//==================================================================//

double EMA10Buffer[];
double EMA20Buffer[];
double EMA50Buffer[];

double BuyBuffer[];
double SellBuffer[];

//==================================================================//
// HANDLES
//==================================================================//

int EMA10Handle = INVALID_HANDLE;
int EMA20Handle = INVALID_HANDLE;
int EMA50Handle = INVALID_HANDLE;
int ATRHandle   = INVALID_HANDLE;
int ADXHandle   = INVALID_HANDLE;

int M15_EMA10 = INVALID_HANDLE;
int M15_EMA20 = INVALID_HANDLE;
int M15_EMA50 = INVALID_HANDLE;

int M5_EMA10 = INVALID_HANDLE;
int M5_EMA20 = INVALID_HANDLE;
int M5_EMA50 = INVALID_HANDLE;

int M1_EMA10 = INVALID_HANDLE;
int M1_EMA20 = INVALID_HANDLE;
int M1_EMA50 = INVALID_HANDLE;

int H1_EMA20 = INVALID_HANDLE;
int H1_EMA50 = INVALID_HANDLE;

//==================================================================//
// WORK ARRAYS
//==================================================================//

// Timeframe courant, indexation identique aux bougies (0 = plus ancienne)
double gATR[];
double gADX[];

// Multi-timeframe, indexation serie (0 = bougie en cours)
double gM15_E10[], gM15_E20[], gM15_E50[];
double gM5_E10[],  gM5_E20[],  gM5_E50[];
double gM1_E10[],  gM1_E20[],  gM1_E50[];
double gH1_E20[],  gH1_E50[];

double gM5_High[], gM5_Low[];
double gM1_High[], gM1_Low[];

bool gDataReady    = false;
uint gLastLoadTick = 0;
int  gLastBarCount = 0;

//==================================================================//
// SETUP INFO
//==================================================================//

struct SetupInfo
{
   int      dir;           // 1 = BUY, -1 = SELL, 0 = aucun
   int      cand;          // direction candidate (tendance MTF)
   int      score;         // 0 - 100

   double   atr;
   double   adx;
   double   ema10;
   double   ema20;
   double   ema50;

   int      biasH1;
   int      t15;
   int      t5;
   int      t1;

   double   support;      // structure M5 la plus proche
   double   resistance;
   double   rangeLow;     // extremes du range M5 (objectifs)
   double   rangeHigh;
   double   swingHigh;    // dernier swing M1 (BOS)
   double   swingLow;

   double   entry;
   double   sl;
   double   tp1;
   double   tp2;
   double   risk;

   long     spreadPts;

   bool     retest;
   bool     bos;
   bool     candle;
   bool     adxOk;
   bool     volOk;
   bool     spreadOk;
   bool     sessionOk;
   bool     rrOk;
};

SetupInfo gClosed;   // derniere bougie cloturee
SetupInfo gLive;     // bougie en formation (apercu)

// Dernier signal confirme
int      gSigDir   = 0;
int      gSigScore = 0;
datetime gSigTime  = 0;
double   gSigEntry = 0.0;
double   gSigSL    = 0.0;
double   gSigTP1   = 0.0;
double   gSigTP2   = 0.0;

datetime gLastAlertTime = 0;

//==================================================================//
// PANEL ROWS
//==================================================================//

#define MAX_ROWS   40

#define ROW_TEXT   0
#define ROW_SEP    1
#define ROW_TITLE  2

string gRowText[2][MAX_ROWS];
int    gRowSize[2][MAX_ROWS];
color  gRowColor[2][MAX_ROWS];
int    gRowKind[2][MAX_ROWS];

int    gRowCount[2] = {0, 0};
int    gRowDrawn[2] = {0, 0};
int    gCol         = 0;

// Pixels par point de police : MT5 agrandit les polices selon le DPI
// de l'ecran alors que la taille du cadre est en pixels. Sans cette
// mise a l'echelle, les lignes se chevauchent sur ecran haute densite.
double gPxPt = 1.333;

// Taille de police reellement utilisee : reduite automatiquement si le
// panneau ne tient pas dans la fenetre du graphique.
int gFontBase = 8;

double PanelPxPerPoint()
{
   double dpi = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI);

   if(dpi < 72.0)
      dpi = 96.0;

   double scale = Panel_Font_Scale;

   if(scale < 0.50)
      scale = 0.50;

   if(scale > 2.00)
      scale = 2.00;

   return (dpi / 72.0) * scale;
}

int RowAdvancePx(int kind, int fontSize)
{
   if(kind == ROW_SEP)
      return (int)MathCeil(9.0 * gPxPt);

   // 1.55 em : hauteur de ligne + interligne
   return (int)MathCeil(fontSize * gPxPt * 1.55);
}

int TextWidthPx(string text, int fontSize)
{
   // Consolas : largeur de glyphe proche de 0.58 em
   return (int)MathCeil(StringLen(text) * fontSize * gPxPt * 0.58) + 4;
}

void RowReset()
{
   gRowCount[0] = 0;
   gRowCount[1] = 0;
   gCol         = 0;
}

void AddRow(int kind, string text, int fontSize, color clr)
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

void Row(string text, int fontSize, color clr)
{
   AddRow(ROW_TEXT, text, fontSize, clr);
}

void RowSep()
{
   AddRow(ROW_SEP, "", 1, C'206,194,176');
}

void RowTitle(string text)
{
   AddRow(
      ROW_TITLE,
      text,
      (int)MathMax(6, gFontBase - 1),
      C'150,138,120'
   );
}

// Passe dans la colonne de droite, ou continue dessous si le
// panneau est configure en une seule colonne.
void NextColumn()
{
   if(Panel_Two_Columns && gCol == 0)
   {
      gCol = 1;
      return;
   }

   RowSep();
}

//==================================================================//
// HELPERS
//==================================================================//

string Pad(string text, int length)
{
   string result = text;

   while(StringLen(result) < length)
      result += " ";

   return result;
}

string TrendText(int trend)
{
   if(trend == 1)
      return "BUY";

   if(trend == -1)
      return "SELL";

   return "WAIT";
}

string YesNo(bool value)
{
   return (value ? "OUI" : "NON");
}

color TrendColor(int trend, color neutral)
{
   if(trend == 1)
      return clrGreen;

   if(trend == -1)
      return clrRed;

   return neutral;
}

//==================================================================//
// COPY HELPERS
//==================================================================//

// Nombre de bougies necessaires sur "tf" pour couvrir l'historique analyse
int NeedBars(ENUM_TIMEFRAMES tf, int extra)
{
   double ratio =
      (double)PeriodSeconds(_Period) / (double)PeriodSeconds(tf);

   int need = (int)MathCeil(ratio * (Signal_History_Bars + 5)) + extra;

   if(need < 250)
      need = 250;

   if(need > 20000)
      need = 20000;

   int available = Bars(_Symbol, tf);

   if(available > 0 && need > available)
      need = available;

   return need;
}

// Copie un buffer d'indicateur en indexation serie (0 = bougie en cours)
bool CopySeriesBuffer(int handle, int count, double &dest[])
{
   if(handle == INVALID_HANDLE || count <= 0)
      return false;

   if(BarsCalculated(handle) < count)
      return false;

   ArraySetAsSeries(dest, true);

   return (CopyBuffer(handle, 0, 0, count, dest) == count);
}

// ATR du graphique ramene a l'echelle d'un autre timeframe
// (la volatilite croit approximativement en racine du temps).
double AtrScaled(double atrChart, ENUM_TIMEFRAMES tf)
{
   double ratio =
      (double)PeriodSeconds(tf) / (double)PeriodSeconds(_Period);

   if(ratio <= 0.0)
      return atrChart;

   return atrChart * MathSqrt(ratio);
}

// Decalage de la derniere bougie DISPONIBLE sur "tf" a l'instant refTime.
// Pour un timeframe superieur au graphique, on saute la bougie en
// formation afin de ne jamais utiliser une information future.
int MTFShift(ENUM_TIMEFRAMES tf, datetime refTime)
{
   int shift = iBarShift(_Symbol, tf, refTime, false);

   if(shift < 0)
      return -1;

   if(PeriodSeconds(tf) > PeriodSeconds(_Period))
      shift += 1;

   return shift;
}

//==================================================================//
// TREND FROM MTF ARRAYS
//==================================================================//

int TrendFromArrays(
   const double &a10[],
   const double &a20[],
   const double &a50[],
   int shift,
   double atrRef
)
{
   if(shift < 0)
      return 0;

   if(
      shift >= ArraySize(a10) ||
      shift >= ArraySize(a20) ||
      shift >= ArraySize(a50)
   )
   {
      return 0;
   }

   double ema10 = a10[shift];
   double ema20 = a20[shift];
   double ema50 = a50[shift];

   if(ema10 <= 0.0 || ema20 <= 0.0 || ema50 <= 0.0)
      return 0;

   // Ecartement minimum : evite les faux signaux en marche plate
   double minSpread = 0.0;

   if(atrRef > 0.0 && Min_EMA_Spread_ATR > 0.0)
      minSpread = atrRef * Min_EMA_Spread_ATR;

   if(ema10 > ema20 && ema20 > ema50 && (ema10 - ema50) >= minSpread)
      return 1;

   if(ema10 < ema20 && ema20 < ema50 && (ema50 - ema10) >= minSpread)
      return -1;

   return 0;
}

int BiasFromPair(
   const double &fast[],
   const double &slow[],
   int shift
)
{
   if(shift < 0 || shift >= ArraySize(fast) || shift >= ArraySize(slow))
      return 0;

   double f = fast[shift];
   double s = slow[shift];

   if(f <= 0.0 || s <= 0.0)
      return 0;

   if(f > s)
      return 1;

   if(f < s)
      return -1;

   return 0;
}

//==================================================================//
// LEVELS
//==================================================================//

double RangeHigh(const double &highs[], int startShift, int count)
{
   int size = ArraySize(highs);

   if(startShift < 0 || size <= 0 || count <= 0)
      return 0.0;

   double best = -DBL_MAX;

   for(int k = 0; k < count; k++)
   {
      int index = startShift + k;

      if(index >= size)
         break;

      if(highs[index] > best)
         best = highs[index];
   }

   if(best == -DBL_MAX)
      return 0.0;

   return best;
}

double RangeLow(const double &lows[], int startShift, int count)
{
   int size = ArraySize(lows);

   if(startShift < 0 || size <= 0 || count <= 0)
      return 0.0;

   double best = DBL_MAX;

   for(int k = 0; k < count; k++)
   {
      int index = startShift + k;

      if(index >= size)
         break;

      if(lows[index] < best)
         best = lows[index];
   }

   if(best == DBL_MAX)
      return 0.0;

   return best;
}

// Swing le PLUS RECENT disponible a partir de startShift (aucune
// bougie plus recente que startShift n'est utilisee).
double RecentSwingHigh(const double &highs[], int startShift, int maxBars)
{
   int size = ArraySize(highs);

   if(startShift < 0 || size <= 0)
      return 0.0;

   for(
      int k = startShift + SwingBars;
      k < startShift + maxBars;
      k++
   )
   {
      if(k + SwingBars >= size)
         break;

      bool isSwing = true;

      for(int j = 1; j <= SwingBars; j++)
      {
         if(highs[k] <= highs[k - j] || highs[k] <= highs[k + j])
         {
            isSwing = false;
            break;
         }
      }

      if(isSwing)
         return highs[k];
   }

   return 0.0;
}

double RecentSwingLow(const double &lows[], int startShift, int maxBars)
{
   int size = ArraySize(lows);

   if(startShift < 0 || size <= 0)
      return 0.0;

   for(
      int k = startShift + SwingBars;
      k < startShift + maxBars;
      k++
   )
   {
      if(k + SwingBars >= size)
         break;

      bool isSwing = true;

      for(int j = 1; j <= SwingBars; j++)
      {
         if(lows[k] >= lows[k - j] || lows[k] >= lows[k + j])
         {
            isSwing = false;
            break;
         }
      }

      if(isSwing)
         return lows[k];
   }

   return 0.0;
}

//==================================================================//
// SESSION
//==================================================================//

bool InSession(datetime barTime)
{
   if(!Use_Session_Filter)
      return true;

   MqlDateTime dt;
   TimeToStruct(barTime, dt);

   if(Session_Start_Hour <= Session_End_Hour)
      return (dt.hour >= Session_Start_Hour && dt.hour < Session_End_Hour);

   // Session a cheval sur minuit
   return (dt.hour >= Session_Start_Hour || dt.hour < Session_End_Hour);
}

//==================================================================//
// EVALUATE ONE BAR
//==================================================================//

bool EvaluateBar(
   const int i,
   const int rates_total,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const int &spread[],
   const bool liveBar,
   SetupInfo &info
)
{
   ZeroMemory(info);

   if(i < 1 || i >= rates_total)
      return false;

   if(i >= ArraySize(gATR))
      return false;

   info.atr = gATR[i];

   if(info.atr <= 0.0)
      return false;

   info.adx   = (i < ArraySize(gADX) ? gADX[i] : 0.0);
   info.ema10 = EMA10Buffer[i];
   info.ema20 = EMA20Buffer[i];
   info.ema50 = EMA50Buffer[i];

   //==============================================================//
   // INSTANT DE REFERENCE
   //==============================================================//

   datetime refTime;

   if(liveBar)
      refTime = TimeCurrent();
   else
      refTime = time[i] + PeriodSeconds(_Period) - 1;

   //==============================================================//
   // TENDANCES MULTI-TIMEFRAME
   //==============================================================//

   int s15 = MTFShift(PERIOD_M15, refTime);
   int s5  = MTFShift(PERIOD_M5,  refTime);
   int s1  = MTFShift(PERIOD_M1,  refTime);
   int sh1 = MTFShift(PERIOD_H1,  refTime);

   info.t15 = TrendFromArrays(
      gM15_E10, gM15_E20, gM15_E50, s15,
      AtrScaled(info.atr, PERIOD_M15)
   );

   info.t5 = TrendFromArrays(
      gM5_E10, gM5_E20, gM5_E50, s5,
      AtrScaled(info.atr, PERIOD_M5)
   );

   info.t1 = TrendFromArrays(
      gM1_E10, gM1_E20, gM1_E50, s1,
      AtrScaled(info.atr, PERIOD_M1)
   );

   info.biasH1 = BiasFromPair(gH1_E20, gH1_E50, sh1);

   //==============================================================//
   // NIVEAUX
   //==============================================================//

   // Extremes du range : servent d'objectif / d'espace disponible
   info.rangeLow  = RangeLow(gM5_Low,   s5, LookbackBars);
   info.rangeHigh = RangeHigh(gM5_High, s5, LookbackBars);

   // Structure exploitable : dernier swing M5 (et non l'extreme du
   // range, ou le prix ne revient jamais en tendance).
   info.support    = RecentSwingLow(gM5_Low,   s5, LookbackBars);
   info.resistance = RecentSwingHigh(gM5_High, s5, LookbackBars);

   if(info.support <= 0.0)
      info.support = info.rangeLow;

   if(info.resistance <= 0.0)
      info.resistance = info.rangeHigh;

   info.swingHigh = RecentSwingHigh(gM1_High, s1, Swing_Lookback_M1);
   info.swingLow  = RecentSwingLow(gM1_Low,   s1, Swing_Lookback_M1);

   //==============================================================//
   // DIRECTION CANDIDATE
   //==============================================================//

   int cand = 0;

   if(info.t15 == 1 && info.t5 == 1)
      cand = 1;
   else if(info.t15 == -1 && info.t5 == -1)
      cand = -1;

   info.cand = cand;

   //==============================================================//
   // RETEST : la zone a ete touchee recemment puis defendue
   //==============================================================//

   bool retestUp = false;
   bool retestDn = false;

   double tolerance = info.atr * Retest_ATR_Distance;

   int retestBars = (int)MathMax(1, Retest_Lookback_Bars);

   bool touchedSupport = false;
   bool touchedResist  = false;
   bool touchedEmaLow  = false;
   bool touchedEmaHigh = false;

   for(int k = 0; k < retestBars; k++)
   {
      int index = i - k;

      if(index < 0)
         break;

      if(info.support > 0.0 && low[index] <= info.support + tolerance)
         touchedSupport = true;

      if(info.resistance > 0.0 && high[index] >= info.resistance - tolerance)
         touchedResist = true;

      // Pullback dans la bande EMA20 / EMA50
      if(info.ema20 > 0.0 && low[index] <= info.ema20)
         touchedEmaLow = true;

      if(info.ema20 > 0.0 && high[index] >= info.ema20)
         touchedEmaHigh = true;
   }

   // Zone touchee PUIS defendue par la cloture
   if(touchedSupport && close[i] > info.support)
      retestUp = true;

   if(
      Retest_On_EMA &&
      touchedEmaLow &&
      info.ema20 > 0.0 &&
      info.ema50 > 0.0 &&
      close[i] > info.ema20 &&
      close[i] > info.ema50
   )
   {
      retestUp = true;
   }

   if(touchedResist && close[i] < info.resistance)
      retestDn = true;

   if(
      Retest_On_EMA &&
      touchedEmaHigh &&
      info.ema20 > 0.0 &&
      info.ema50 > 0.0 &&
      close[i] < info.ema20 &&
      close[i] < info.ema50
   )
   {
      retestDn = true;
   }

   //==============================================================//
   // BOS : cassure FRAICHE du dernier swing M1
   //==============================================================//

   bool bosUp = false;
   bool bosDn = false;

   double bosMargin = info.atr * BOS_Buffer_ATR;

   if(info.swingHigh > 0.0)
   {
      bool broken = (close[i] > info.swingHigh + bosMargin);
      bool wasInside = (close[i - 1] <= info.swingHigh + bosMargin);

      bosUp = (broken && wasInside);
   }

   if(info.swingLow > 0.0)
   {
      bool broken = (close[i] < info.swingLow - bosMargin);
      bool wasInside = (close[i - 1] >= info.swingLow - bosMargin);

      bosDn = (broken && wasInside);
   }

   //==============================================================//
   // BOUGIE DE CONFIRMATION
   //==============================================================//

   double range = high[i] - low[i];
   double body  = MathAbs(close[i] - open[i]);

   double bodyRatio = 0.0;

   if(range > 0.0)
      bodyRatio = body / range;

   double middle = (high[i] + low[i]) / 2.0;

   bool candleUp =
      (close[i] > open[i]) &&
      (bodyRatio >= Min_Body_Ratio) &&
      (close[i] > middle);

   bool candleDn =
      (close[i] < open[i]) &&
      (bodyRatio >= Min_Body_Ratio) &&
      (close[i] < middle);

   //==============================================================//
   // FILTRES DE MARCHE
   //==============================================================//

   info.adxOk = (!Use_ADX_Filter || info.adx >= ADX_Min);

   info.volOk = true;

   if(Min_ATR > 0.0 && info.atr < Min_ATR)
      info.volOk = false;

   if(Max_ATR > 0.0 && info.atr > Max_ATR)
      info.volOk = false;

   if(liveBar)
      info.spreadPts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   else
      info.spreadPts = (long)spread[i];

   info.spreadOk = true;

   if(Max_Spread_Points > 0 && info.spreadPts > 0)
      info.spreadOk = (info.spreadPts <= Max_Spread_Points);

   info.sessionOk = InSession(time[i]);

   //==============================================================//
   // ENTREE / SL / TP
   //==============================================================//

   info.entry = close[i];

   double protectLow  = low[i];
   double protectHigh = high[i];

   for(int k = 0; k < retestBars; k++)
   {
      int index = i - k;

      if(index < 0)
         break;

      if(low[index] < protectLow)
         protectLow = low[index];

      if(high[index] > protectHigh)
         protectHigh = high[index];
   }

   bool rrUp = false;
   bool rrDn = false;

   if(cand > 0)
   {
      double slStruct = protectLow - info.atr * 0.20;
      double slAtr    = info.entry - info.atr * SL_ATR_Mult;

      info.sl   = MathMin(slStruct, slAtr);
      info.risk = info.entry - info.sl;

      if(info.risk > 0.0)
      {
         info.tp1 = info.entry + info.risk * TP1_RR;
         info.tp2 = info.entry + info.risk * TP2_RR;

         // Espace disponible avant le haut du range
         if(info.rangeHigh <= info.entry)
            rrUp = true;
         else
            rrUp = ((info.rangeHigh - info.entry) >= info.risk * Min_RR_To_Level);
      }
   }
   else if(cand < 0)
   {
      double slStruct = protectHigh + info.atr * 0.20;
      double slAtr    = info.entry + info.atr * SL_ATR_Mult;

      info.sl   = MathMax(slStruct, slAtr);
      info.risk = info.sl - info.entry;

      if(info.risk > 0.0)
      {
         info.tp1 = info.entry - info.risk * TP1_RR;
         info.tp2 = info.entry - info.risk * TP2_RR;

         if(info.rangeLow >= info.entry)
            rrDn = true;
         else
            rrDn = ((info.entry - info.rangeLow) >= info.risk * Min_RR_To_Level);
      }
   }

   //==============================================================//
   // SCORE
   //==============================================================//

   int score = 0;

   if(cand != 0)
      score += 25;

   if(!Use_H1_Bias)
      score += 10;
   else if(cand != 0 && info.biasH1 == cand)
      score += 10;

   if(info.adxOk)
      score += 15;

   if((cand > 0 && retestUp) || (cand < 0 && retestDn))
      score += 15;

   if((cand > 0 && bosUp) || (cand < 0 && bosDn))
      score += 20;

   if(!Require_Candle_Confirm)
      score += 10;
   else if((cand > 0 && candleUp) || (cand < 0 && candleDn))
      score += 10;

   if((cand > 0 && rrUp) || (cand < 0 && rrDn))
      score += 5;

   info.score = score;

   //==============================================================//
   // CONDITIONS OBLIGATOIRES
   //==============================================================//

   bool baseOk =
      (cand != 0) &&
      info.adxOk &&
      info.volOk &&
      info.spreadOk &&
      info.sessionOk;

   if(baseOk && Require_M1_EMA_Align && info.t1 != cand)
      baseOk = false;

   if(baseOk && Use_H1_Bias && info.biasH1 == -cand)
      baseOk = false;

   bool buySetup =
      baseOk &&
      (cand > 0) &&
      retestUp &&
      bosUp &&
      rrUp &&
      (!Require_Candle_Confirm || candleUp);

   bool sellSetup =
      baseOk &&
      (cand < 0) &&
      retestDn &&
      bosDn &&
      rrDn &&
      (!Require_Candle_Confirm || candleDn);

   info.dir = 0;

   if(buySetup && score >= Min_Score)
      info.dir = 1;

   if(sellSetup && score >= Min_Score)
      info.dir = -1;

   //==============================================================//
   // ETAT AFFICHE
   //==============================================================//

   if(cand > 0)
   {
      info.retest = retestUp;
      info.bos    = bosUp;
      info.candle = candleUp;
      info.rrOk   = rrUp;
   }
   else if(cand < 0)
   {
      info.retest = retestDn;
      info.bos    = bosDn;
      info.candle = candleDn;
      info.rrOk   = rrDn;
   }
   else
   {
      info.retest = (retestUp || retestDn);
      info.bos    = (bosUp || bosDn);
      info.candle = (candleUp || candleDn);
      info.rrOk   = false;
   }

   return true;
}

//==================================================================//
// CHART OBJECTS
//==================================================================//

void DeleteObjectSafe(string name)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

void DrawLevelLine(
   string name,
   double price,
   color  clr,
   ENUM_LINE_STYLE style,
   int    width,
   string text
)
{
   if(price <= 0.0)
   {
      DeleteObjectSafe(OBJ_PREFIX + name);
      return;
   }

   string fullName = OBJ_PREFIX + name;

   if(ObjectFind(0, fullName) < 0)
      ObjectCreate(0, fullName, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, fullName, OBJPROP_PRICE, price);
   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, fullName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, fullName, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, fullName, OBJPROP_BACK, true);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, fullName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, fullName, OBJPROP_TEXT, text);
   ObjectSetString(0, fullName, OBJPROP_TOOLTIP, text);
}

void DrawLevelText(
   string name,
   datetime anchorTime,
   double price,
   color clr,
   string text
)
{
   if(price <= 0.0)
   {
      DeleteObjectSafe(OBJ_PREFIX + name);
      return;
   }

   string fullName = OBJ_PREFIX + name;

   if(ObjectFind(0, fullName) < 0)
      ObjectCreate(0, fullName, OBJ_TEXT, 0, anchorTime, price);

   ObjectMove(0, fullName, 0, anchorTime, price);

   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, fullName, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, fullName, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
   ObjectSetInteger(0, fullName, OBJPROP_BACK, false);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, fullName, OBJPROP_HIDDEN, true);
   ObjectSetString(0, fullName, OBJPROP_FONT, "Arial");
   ObjectSetString(0, fullName, OBJPROP_TEXT, text);
}

void DrawZone(
   string name,
   datetime t1,
   datetime t2,
   double p1,
   double p2,
   color clr
)
{
   if(p1 <= 0.0 || p2 <= 0.0)
   {
      DeleteObjectSafe(OBJ_PREFIX + name);
      return;
   }

   string fullName = OBJ_PREFIX + name;

   if(ObjectFind(0, fullName) < 0)
      ObjectCreate(0, fullName, OBJ_RECTANGLE, 0, t1, p1, t2, p2);

   ObjectMove(0, fullName, 0, t1, p1);
   ObjectMove(0, fullName, 1, t2, p2);

   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, fullName, OBJPROP_FILL, true);
   ObjectSetInteger(0, fullName, OBJPROP_BACK, true);
   ObjectSetInteger(0, fullName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, fullName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, fullName, OBJPROP_HIDDEN, true);
}

void DrawTradeSegment(
   string name,
   datetime t1,
   datetime t2,
   double price,
   color clr,
   ENUM_LINE_STYLE style,
   int width,
   string text
)
{
   if(price <= 0.0)
   {
      DeleteObjectSafe(OBJ_PREFIX + name);
      DeleteObjectSafe(OBJ_PREFIX + name + "_T");
      return;
   }

   string fullName = OBJ_PREFIX + name;

   if(ObjectFind(0, fullName) < 0)
      ObjectCreate(0, fullName, OBJ_TREND, 0, t1, price, t2, price);

   ObjectMove(0, fullName, 0, t1, price);
   ObjectMove(0, fullName, 1, t2, price);

   ObjectSetInteger(0, fullName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, fullName, OBJPROP_STYLE, style);
   ObjectSetInteger(0, fullName, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, fullName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, fullName, OBJPROP_BACK, false);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, fullName, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, fullName, OBJPROP_HIDDEN, true);

   DrawLevelText(name + "_T", t2, price, clr, text);
}

void RemoveLevelObjects()
{
   string names[] =
   {
      "SUP", "SUP_T", "RES", "RES_T",
      "RGH", "RGH_T", "RGL", "RGL_T",
      "SWH", "SWH_T", "SWL", "SWL_T",
      "ZONE_SUP", "ZONE_RES"
   };

   for(int i = 0; i < ArraySize(names); i++)
      DeleteObjectSafe(OBJ_PREFIX + names[i]);
}

void RemoveTradeObjects()
{
   string names[] =
   {
      "ENTRY", "ENTRY_T",
      "SL", "SL_T",
      "TP1", "TP1_T",
      "TP2", "TP2_T"
   };

   for(int i = 0; i < ArraySize(names); i++)
      DeleteObjectSafe(OBJ_PREFIX + names[i]);
}

//==================================================================//
// DRAW LEVELS ON CHART
//==================================================================//

void DrawChartLevels(
   const SetupInfo &info,
   const datetime lastBarTime
)
{
   int    barSeconds = PeriodSeconds(_Period);
   datetime rightEdge = lastBarTime + barSeconds * 8;
   datetime leftEdge  = lastBarTime - barSeconds * 80;

   if(!Show_Levels)
   {
      RemoveLevelObjects();
   }
   else
   {
      DrawLevelLine(
         "SUP",
         info.support,
         C'40,140,90',
         STYLE_SOLID,
         2,
         "Support M5 " + DoubleToString(info.support, _Digits)
      );

      DrawLevelLine(
         "RES",
         info.resistance,
         C'190,70,60',
         STYLE_SOLID,
         2,
         "Resistance M5 " + DoubleToString(info.resistance, _Digits)
      );

      DrawLevelLine(
         "RGH",
         info.rangeHigh,
         C'150,120,110',
         STYLE_DOT,
         1,
         "Haut de range M5 " + DoubleToString(info.rangeHigh, _Digits)
      );

      DrawLevelLine(
         "RGL",
         info.rangeLow,
         C'110,140,130',
         STYLE_DOT,
         1,
         "Bas de range M5 " + DoubleToString(info.rangeLow, _Digits)
      );

      DrawLevelLine(
         "SWH",
         info.swingHigh,
         C'130,130,150',
         STYLE_DASH,
         1,
         "Swing High M1 " + DoubleToString(info.swingHigh, _Digits)
      );

      DrawLevelLine(
         "SWL",
         info.swingLow,
         C'130,130,150',
         STYLE_DASH,
         1,
         "Swing Low M1 " + DoubleToString(info.swingLow, _Digits)
      );

      DrawLevelText(
         "SUP_T",
         rightEdge,
         info.support,
         C'40,140,90',
         "SUPPORT " + DoubleToString(info.support, _Digits)
      );

      DrawLevelText(
         "RES_T",
         rightEdge,
         info.resistance,
         C'190,70,60',
         "RESISTANCE " + DoubleToString(info.resistance, _Digits)
      );

      DrawLevelText(
         "RGH_T",
         rightEdge,
         info.rangeHigh,
         C'150,120,110',
         "RANGE H " + DoubleToString(info.rangeHigh, _Digits)
      );

      DrawLevelText(
         "RGL_T",
         rightEdge,
         info.rangeLow,
         C'110,140,130',
         "RANGE L " + DoubleToString(info.rangeLow, _Digits)
      );

      DrawLevelText(
         "SWH_T",
         rightEdge,
         info.swingHigh,
         C'130,130,150',
         "BOS+ " + DoubleToString(info.swingHigh, _Digits)
      );

      DrawLevelText(
         "SWL_T",
         rightEdge,
         info.swingLow,
         C'130,130,150',
         "BOS- " + DoubleToString(info.swingLow, _Digits)
      );

      if(Show_Zones && info.atr > 0.0)
      {
         double tolerance = info.atr * Retest_ATR_Distance;

         if(info.support > 0.0)
         {
            DrawZone(
               "ZONE_SUP",
               leftEdge,
               rightEdge,
               info.support - tolerance * 0.5,
               info.support + tolerance,
               C'205,235,215'
            );
         }

         if(info.resistance > 0.0)
         {
            DrawZone(
               "ZONE_RES",
               leftEdge,
               rightEdge,
               info.resistance - tolerance,
               info.resistance + tolerance * 0.5,
               C'245,215,210'
            );
         }
      }
      else
      {
         DeleteObjectSafe(OBJ_PREFIX + "ZONE_SUP");
         DeleteObjectSafe(OBJ_PREFIX + "ZONE_RES");
      }
   }

   //==============================================================//
   // NIVEAUX DE TRADE DU DERNIER SIGNAL
   //==============================================================//

   if(!Show_Trade_Levels || gSigDir == 0 || gSigTime == 0)
   {
      RemoveTradeObjects();
      return;
   }

   datetime tStart = gSigTime;
   datetime tEnd   = gSigTime + barSeconds * 40;

   if(tEnd < lastBarTime)
      tEnd = lastBarTime + barSeconds * 4;

   DrawTradeSegment(
      "ENTRY",
      tStart,
      tEnd,
      gSigEntry,
      clrRoyalBlue,
      STYLE_SOLID,
      2,
      "ENTREE " + DoubleToString(gSigEntry, _Digits)
   );

   DrawTradeSegment(
      "SL",
      tStart,
      tEnd,
      gSigSL,
      clrCrimson,
      STYLE_DASHDOT,
      2,
      "SL " + DoubleToString(gSigSL, _Digits)
   );

   DrawTradeSegment(
      "TP1",
      tStart,
      tEnd,
      gSigTP1,
      C'0,140,80',
      STYLE_DOT,
      2,
      "TP1 " + DoubleToString(gSigTP1, _Digits)
   );

   DrawTradeSegment(
      "TP2",
      tStart,
      tEnd,
      gSigTP2,
      C'0,110,60',
      STYLE_DOT,
      2,
      "TP2 " + DoubleToString(gSigTP2, _Digits)
   );
}

//==================================================================//
// PANEL
//==================================================================//

void CreatePanelBackground(int width, int height)
{
   string name = OBJ_PREFIX + "PANEL_BG";

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, Panel_X);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, Panel_Y);

   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);

   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'245,238,225');
   ObjectSetInteger(0, name, OBJPROP_COLOR, C'180,165,140');
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);

   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);

   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void SetLabel(
   string name,
   string text,
   int x,
   int y,
   int fontSize,
   color textColor
)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);

   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);

   // Police a largeur fixe : les colonnes restent alignees
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetString(0, name, OBJPROP_TEXT, text);

   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);

   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

// Trait de separation fin, dessine comme un rectangle de 1 a 2 pixels
void SetSeparator(string name, int x, int y, int width, color clr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   int thickness = (int)MathMax(1, MathRound(gPxPt * 0.7));

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);

   ObjectSetInteger(0, name, OBJPROP_XSIZE, (int)MathMax(4, width));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, thickness);

   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);

   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);

   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

string RowName(int col, int index)
{
   return OBJ_PREFIX + "R_" + IntegerToString(col) + "_" +
          IntegerToString(index);
}

string SepName(int col, int index)
{
   return OBJ_PREFIX + "S_" + IntegerToString(col) + "_" +
          IntegerToString(index);
}

void RemovePanelObjects()
{
   DeleteObjectSafe(OBJ_PREFIX + "PANEL_BG");
   DeleteObjectSafe(OBJ_PREFIX + "HDR");
   DeleteObjectSafe(OBJ_PREFIX + "HDRSEP");

   for(int c = 0; c < 2; c++)
   {
      for(int i = 0; i < MAX_ROWS; i++)
      {
         DeleteObjectSafe(RowName(c, i));
         DeleteObjectSafe(SepName(c, i));
      }

      gRowDrawn[c] = 0;
   }
}

color ScoreColor(int score)
{
   if(score >= 85)
      return clrGreen;

   if(score >= Min_Score)
      return C'120,140,0';

   if(score >= 50)
      return C'170,120,0';

   return C'120,100,90';
}

void BuildPanelRows()
{
   RowReset();

   int fs    = (int)MathMax(6, gFontBase);
   int fsBig = fs + 3;
   int fsSml = (int)MathMax(6, fs - 1);

   color textColor = C'45,45,45';
   color dimColor  = C'125,118,105';
   color warnColor = C'175,120,0';

   int lab = 10;   // largeur de la colonne des libelles

   if(!gDataReady)
   {
      Row("SYNCHRONISATION...", fs, warnColor);
      Row("Ouvrez M1 / M5 / M15 / H1", fsSml, dimColor);
      return;
   }

   if(
      _Period != PERIOD_M1 &&
      _Period != PERIOD_M5 &&
      _Period != PERIOD_M15
   )
   {
      Row("TF conseille : M1 / M5 / M15", fsSml, warnColor);
      RowSep();
   }

   //==============================================================//
   // SIGNAL
   //==============================================================//

   Row(Pad("SIGNAL", lab) + TrendText(gClosed.dir), fsBig,
       TrendColor(gClosed.dir, C'130,110,0'));

   Row(Pad("SCORE", lab) + IntegerToString(gClosed.score) + " / " +
       IntegerToString(Min_Score), fs, ScoreColor(gClosed.score));

   Row(Pad("APERCU", lab) + TrendText(gLive.cand) + "   " +
       IntegerToString(gLive.score) + " %", fsSml, dimColor);

   RowSep();

   //==============================================================//
   // TENDANCE
   //==============================================================//

   RowTitle("TENDANCE");

   Row(Pad("H1", lab) + TrendText(gClosed.biasH1), fs,
       TrendColor(gClosed.biasH1, dimColor));

   Row(Pad("M15", lab) + TrendText(gClosed.t15), fs,
       TrendColor(gClosed.t15, textColor));

   Row(Pad("M5", lab) + TrendText(gClosed.t5), fs,
       TrendColor(gClosed.t5, textColor));

   Row(Pad("M1", lab) + TrendText(gClosed.t1), fs,
       TrendColor(gClosed.t1, dimColor));

   RowSep();

   //==============================================================//
   // CONFIRMATION
   //==============================================================//

   RowTitle("CONFIRMATION");

   Row(Pad("RETEST", lab) + YesNo(gClosed.retest), fs,
       (gClosed.retest ? clrGreen : dimColor));

   Row(Pad("BOS M1", lab) + YesNo(gClosed.bos), fs,
       (gClosed.bos ? clrGreen : dimColor));

   Row(Pad("BOUGIE", lab) + YesNo(gClosed.candle), fs,
       (gClosed.candle ? clrGreen : dimColor));

   Row(Pad("ESPACE", lab) + YesNo(gClosed.rrOk), fs,
       (gClosed.rrOk ? clrGreen : dimColor));

   NextColumn();

   //==============================================================//
   // MARCHE
   //==============================================================//

   RowTitle("MARCHE");

   Row(Pad("ATR", lab) + DoubleToString(gClosed.atr, _Digits), fs,
       textColor);

   Row(Pad("ADX", lab) + DoubleToString(gClosed.adx, 1) + "   " +
       YesNo(gClosed.adxOk), fs,
       (gClosed.adxOk ? textColor : warnColor));

   Row(Pad("SPREAD", lab) + IntegerToString((int)gLive.spreadPts) + " pts",
       fs, (gLive.spreadOk ? textColor : clrRed));

   Row(Pad("SESSION", lab) + YesNo(gLive.sessionOk), fs,
       (gLive.sessionOk ? textColor : warnColor));

   RowSep();

   //==============================================================//
   // NIVEAUX
   //==============================================================//

   RowTitle("NIVEAUX  M5");

   Row(Pad("RESIST", lab) + DoubleToString(gClosed.resistance, _Digits),
       fs, C'170,65,55');

   Row(Pad("SUPPORT", lab) + DoubleToString(gClosed.support, _Digits),
       fs, C'45,110,75');

   RowSep();

   //==============================================================//
   // DERNIER SIGNAL
   //==============================================================//

   RowTitle("DERNIER SIGNAL");

   if(gSigDir == 0)
   {
      Row("Aucun signal confirme", fsSml, dimColor);
      return;
   }

   color sigColor = (gSigDir == 1 ? clrGreen : clrRed);

   Row(Pad("TRADE", lab) + TrendText(gSigDir) + "  " +
       TimeToString(gSigTime, TIME_MINUTES) + "  " +
       IntegerToString(gSigScore) + " %", fs, sigColor);

   Row(Pad("ENTREE", lab) + DoubleToString(gSigEntry, _Digits), fs,
       clrRoyalBlue);

   Row(Pad("SL", lab) + DoubleToString(gSigSL, _Digits), fs, clrCrimson);

   Row(Pad("TP1", lab) + DoubleToString(gSigTP1, _Digits), fs,
       C'0,130,75');

   Row(Pad("TP2", lab) + DoubleToString(gSigTP2, _Digits), fs,
       C'0,130,75');

   Row(Pad("RISQUE", lab) + DoubleToString(MathAbs(gSigEntry - gSigSL),
       _Digits), fsSml, dimColor);
}

void DrawPanel()
{
   if(!Show_Panel)
   {
      RemovePanelObjects();
      return;
   }

   gPxPt = PanelPxPerPoint();

   int pad = (int)MathCeil(10.0 * gPxPt);
   int gap = (int)MathCeil(12.0 * gPxPt);

   // Place disponible dans la fenetre du graphique
   int chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   int maxWidth  = (chartW > 0 ? chartW - Panel_X - 10 : 0);
   int maxHeight = (chartH > 0 ? chartH - Panel_Y - 10 : 0);

   int colWidth[2];
   int colHeight[2];

   int width        = 0;
   int height       = 0;
   int headerHeight = 0;

   //==============================================================//
   // MESURE : le panneau s'adapte au contenu, au DPI, puis reduit
   // la police tant qu'il ne tient pas dans la fenetre.
   //==============================================================//

   for(int base = (int)MathMax(6, Panel_Font_Size); base >= 6; base--)
   {
      gFontBase = base;

      BuildPanelRows();

      for(int c = 0; c < 2; c++)
      {
         colWidth[c]  = 0;
         colHeight[c] = 0;

         for(int i = 0; i < gRowCount[c]; i++)
         {
            if(gRowKind[c][i] != ROW_SEP)
            {
               int w = TextWidthPx(gRowText[c][i], gRowSize[c][i]);

               if(w > colWidth[c])
                  colWidth[c] = w;
            }

            colHeight[c] += RowAdvancePx(gRowKind[c][i], gRowSize[c][i]);
         }
      }

      int innerWidth = colWidth[0];

      if(gRowCount[1] > 0)
         innerWidth += gap + colWidth[1];

      int titleWidth = TextWidthPx(PANEL_TITLE, gFontBase + 1);

      if(titleWidth > innerWidth)
         innerWidth = titleWidth;

      headerHeight =
         RowAdvancePx(ROW_TEXT, gFontBase + 1) +
         RowAdvancePx(ROW_SEP, 1);

      width  = pad * 2 + innerWidth;
      height =
         pad * 2 + headerHeight +
         (int)MathMax(colHeight[0], colHeight[1]);

      if(base == 6)
         break;

      bool fitsWidth  = (maxWidth  <= 0 || width  <= maxWidth);
      bool fitsHeight = (maxHeight <= 0 || height <= maxHeight);

      if(fitsWidth && fitsHeight)
         break;
   }

   if(width < Panel_Width)
      width = Panel_Width;

   CreatePanelBackground(width, height);

   //==============================================================//
   // EN-TETE
   //==============================================================//

   SetLabel(
      OBJ_PREFIX + "HDR",
      PANEL_TITLE,
      Panel_X + pad,
      Panel_Y + pad,
      gFontBase + 1,
      C'25,25,25'
   );

   SetSeparator(
      OBJ_PREFIX + "HDRSEP",
      Panel_X + pad,
      Panel_Y + pad + headerHeight - RowAdvancePx(ROW_SEP, 1) / 2,
      width - pad * 2,
      C'196,182,162'
   );

   //==============================================================//
   // TRACE
   //==============================================================//

   int colX[2];

   colX[0] = Panel_X + pad;
   colX[1] = Panel_X + pad + colWidth[0] + gap;

   for(int c = 0; c < 2; c++)
   {
      int y = Panel_Y + pad + headerHeight;

      for(int i = 0; i < gRowCount[c]; i++)
      {
         int advance = RowAdvancePx(gRowKind[c][i], gRowSize[c][i]);

         if(gRowKind[c][i] == ROW_SEP)
         {
            DeleteObjectSafe(RowName(c, i));

            SetSeparator(
               SepName(c, i),
               colX[c],
               y + advance / 2,
               colWidth[c],
               gRowColor[c][i]
            );
         }
         else
         {
            DeleteObjectSafe(SepName(c, i));

            SetLabel(
               RowName(c, i),
               gRowText[c][i],
               colX[c],
               y,
               gRowSize[c][i],
               gRowColor[c][i]
            );
         }

         y += advance;
      }
   }

   for(int c = 0; c < 2; c++)
   {
      for(int i = gRowCount[c]; i < gRowDrawn[c]; i++)
      {
         DeleteObjectSafe(RowName(c, i));
         DeleteObjectSafe(SepName(c, i));
      }

      gRowDrawn[c] = gRowCount[c];
   }
}

//==================================================================//
// INIT
//==================================================================//

int OnInit()
{
   SetIndexBuffer(0, EMA10Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, EMA20Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, EMA50Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, SellBuffer, INDICATOR_DATA);

   // Les EMA sont toujours calculees (la logique en a besoin),
   // seul l'affichage est optionnel.
   ENUM_DRAW_TYPE emaDraw = (Show_EMA ? DRAW_LINE : DRAW_NONE);

   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, (int)emaDraw);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, (int)emaDraw);
   PlotIndexSetInteger(2, PLOT_DRAW_TYPE, (int)emaDraw);

   ENUM_DRAW_TYPE arrowDraw = (Show_Signals ? DRAW_ARROW : DRAW_NONE);

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

   EMA10Handle = iMA(_Symbol, _Period, EMA10_Period, 0, MODE_EMA, PRICE_CLOSE);
   EMA20Handle = iMA(_Symbol, _Period, EMA20_Period, 0, MODE_EMA, PRICE_CLOSE);
   EMA50Handle = iMA(_Symbol, _Period, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);
   ATRHandle   = iATR(_Symbol, _Period, ATR_Period);
   ADXHandle   = iADX(_Symbol, _Period, ADX_Period);

   M15_EMA10 = iMA(_Symbol, PERIOD_M15, EMA10_Period, 0, MODE_EMA, PRICE_CLOSE);
   M15_EMA20 = iMA(_Symbol, PERIOD_M15, EMA20_Period, 0, MODE_EMA, PRICE_CLOSE);
   M15_EMA50 = iMA(_Symbol, PERIOD_M15, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);

   M5_EMA10 = iMA(_Symbol, PERIOD_M5, EMA10_Period, 0, MODE_EMA, PRICE_CLOSE);
   M5_EMA20 = iMA(_Symbol, PERIOD_M5, EMA20_Period, 0, MODE_EMA, PRICE_CLOSE);
   M5_EMA50 = iMA(_Symbol, PERIOD_M5, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);

   M1_EMA10 = iMA(_Symbol, PERIOD_M1, EMA10_Period, 0, MODE_EMA, PRICE_CLOSE);
   M1_EMA20 = iMA(_Symbol, PERIOD_M1, EMA20_Period, 0, MODE_EMA, PRICE_CLOSE);
   M1_EMA50 = iMA(_Symbol, PERIOD_M1, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);

   H1_EMA20 = iMA(_Symbol, PERIOD_H1, EMA20_Period, 0, MODE_EMA, PRICE_CLOSE);
   H1_EMA50 = iMA(_Symbol, PERIOD_H1, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);

   if(
      EMA10Handle == INVALID_HANDLE ||
      EMA20Handle == INVALID_HANDLE ||
      EMA50Handle == INVALID_HANDLE ||
      ATRHandle   == INVALID_HANDLE ||
      ADXHandle   == INVALID_HANDLE
   )
   {
      Print("Erreur lors de la creation des indicateurs principaux.");
      return INIT_FAILED;
   }

   if(
      M15_EMA10 == INVALID_HANDLE || M15_EMA20 == INVALID_HANDLE ||
      M15_EMA50 == INVALID_HANDLE || M5_EMA10  == INVALID_HANDLE ||
      M5_EMA20  == INVALID_HANDLE || M5_EMA50  == INVALID_HANDLE ||
      M1_EMA10  == INVALID_HANDLE || M1_EMA20  == INVALID_HANDLE ||
      M1_EMA50  == INVALID_HANDLE || H1_EMA20  == INVALID_HANDLE ||
      H1_EMA50  == INVALID_HANDLE
   )
   {
      Print("Erreur lors de la creation des indicateurs multi-timeframe.");
      return INIT_FAILED;
   }

   ZeroMemory(gClosed);
   ZeroMemory(gLive);

   gSigDir   = 0;
   gSigTime  = 0;
   gSigScore = 0;

   IndicatorSetString(INDICATOR_SHORTNAME, "XAUUSD Scalping V3.3");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

   return INIT_SUCCEEDED;
}

//==================================================================//
// LOAD MULTI-TIMEFRAME DATA
//==================================================================//

bool LoadMTFData()
{
   int extra =
      LookbackBars + Swing_Lookback_M1 + EMA50_Period + ATR_Period + 50;

   int n15 = NeedBars(PERIOD_M15, extra);
   int n5  = NeedBars(PERIOD_M5,  extra);
   int n1  = NeedBars(PERIOD_M1,  extra);
   int nh1 = NeedBars(PERIOD_H1,  extra);

   if(!CopySeriesBuffer(M15_EMA10, n15, gM15_E10)) return false;
   if(!CopySeriesBuffer(M15_EMA20, n15, gM15_E20)) return false;
   if(!CopySeriesBuffer(M15_EMA50, n15, gM15_E50)) return false;

   if(!CopySeriesBuffer(M5_EMA10, n5, gM5_E10)) return false;
   if(!CopySeriesBuffer(M5_EMA20, n5, gM5_E20)) return false;
   if(!CopySeriesBuffer(M5_EMA50, n5, gM5_E50)) return false;

   if(!CopySeriesBuffer(M1_EMA10, n1, gM1_E10)) return false;
   if(!CopySeriesBuffer(M1_EMA20, n1, gM1_E20)) return false;
   if(!CopySeriesBuffer(M1_EMA50, n1, gM1_E50)) return false;

   if(!CopySeriesBuffer(H1_EMA20, nh1, gH1_E20)) return false;
   if(!CopySeriesBuffer(H1_EMA50, nh1, gH1_E50)) return false;

   ArraySetAsSeries(gM5_High, true);
   ArraySetAsSeries(gM5_Low,  true);
   ArraySetAsSeries(gM1_High, true);
   ArraySetAsSeries(gM1_Low,  true);

   if(CopyHigh(_Symbol, PERIOD_M5, 0, n5, gM5_High) != n5) return false;
   if(CopyLow(_Symbol,  PERIOD_M5, 0, n5, gM5_Low)  != n5) return false;

   if(CopyHigh(_Symbol, PERIOD_M1, 0, n1, gM1_High) != n1) return false;
   if(CopyLow(_Symbol,  PERIOD_M1, 0, n1, gM1_Low)  != n1) return false;

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
   int minBars = EMA50_Period + ATR_Period + ADX_Period + 20;

   if(rates_total < minBars)
      return 0;

   // Indexation explicite : index 0 = bougie la plus ancienne,
   // rates_total - 1 = bougie en cours.
   ArraySetAsSeries(time,   false);
   ArraySetAsSeries(open,   false);
   ArraySetAsSeries(high,   false);
   ArraySetAsSeries(low,    false);
   ArraySetAsSeries(close,  false);
   ArraySetAsSeries(spread, false);

   //==============================================================//
   // DONNEES DU TIMEFRAME COURANT
   //==============================================================//

   if(
      BarsCalculated(EMA10Handle) < rates_total ||
      BarsCalculated(EMA20Handle) < rates_total ||
      BarsCalculated(EMA50Handle) < rates_total ||
      BarsCalculated(ATRHandle)   < rates_total ||
      BarsCalculated(ADXHandle)   < rates_total
   )
   {
      return 0;
   }

   if(CopyBuffer(EMA10Handle, 0, 0, rates_total, EMA10Buffer) != rates_total)
      return 0;

   if(CopyBuffer(EMA20Handle, 0, 0, rates_total, EMA20Buffer) != rates_total)
      return 0;

   if(CopyBuffer(EMA50Handle, 0, 0, rates_total, EMA50Buffer) != rates_total)
      return 0;

   if(CopyBuffer(ATRHandle, 0, 0, rates_total, gATR) != rates_total)
      return 0;

   if(CopyBuffer(ADXHandle, 0, 0, rates_total, gADX) != rates_total)
      return 0;

   //==============================================================//
   // DONNEES MULTI-TIMEFRAME
   //==============================================================//

   // Les series annexes sont volumineuses : on les recharge sur
   // nouvelle bougie, sur recalcul complet, ou au maximum 1x/seconde.
   bool needReload =
      (!gDataReady) ||
      (prev_calculated <= 0) ||
      (rates_total != gLastBarCount) ||
      ((GetTickCount() - gLastLoadTick) > 900);

   if(needReload)
   {
      gDataReady = LoadMTFData();

      if(gDataReady)
      {
         gLastLoadTick  = GetTickCount();
         gLastBarCount  = rates_total;
      }
   }

   if(!gDataReady)
   {
      DrawPanel();
      ChartRedraw(0);

      // Les series annexes ne sont pas pretes : nouvelle tentative
      // au prochain tick.
      return 0;
   }

   //==============================================================//
   // FENETRE DE CALCUL DES SIGNAUX
   //==============================================================//

   int historyBars = (int)MathMax(20, Signal_History_Bars);
   int firstBar    = (int)MathMax(1, rates_total - 1 - historyBars);

   int start;

   if(prev_calculated <= 0)
   {
      ArrayInitialize(BuyBuffer, EMPTY_VALUE);
      ArrayInitialize(SellBuffer, EMPTY_VALUE);

      gSigDir   = 0;
      gSigTime  = 0;
      gSigScore = 0;

      start = firstBar;
   }
   else
   {
      start = (int)MathMax(firstBar, prev_calculated - 3);
   }

   for(int k = start; k < rates_total; k++)
   {
      BuyBuffer[k]  = EMPTY_VALUE;
      SellBuffer[k] = EMPTY_VALUE;
   }

   //==============================================================//
   // SIGNAUX SUR BOUGIES CLOTUREES UNIQUEMENT
   //==============================================================//

   int lastClosed = rates_total - 2;

   SetupInfo info;

   for(int i = start; i <= lastClosed; i++)
   {
      if(
         !EvaluateBar(
            i, rates_total,
            time, open, high, low, close, spread,
            false, info
         )
      )
      {
         continue;
      }

      if(info.dir == 0)
         continue;

      // Delai minimum entre deux signaux.
      // Les dernieres bougies sont recalculees a chaque tick : on ne
      // filtre donc pas la bougie qui a genere le signal en cours,
      // sinon sa fleche disparaitrait.
      if(gSigTime > 0 && Cooldown_Bars > 0 && time[i] != gSigTime)
      {
         long elapsed = (long)(time[i] - gSigTime);

         if(elapsed > 0 && elapsed < (long)Cooldown_Bars * PeriodSeconds(_Period))
            continue;
      }

      if(info.dir == 1)
         BuyBuffer[i] = low[i] - info.atr * 0.60;
      else
         SellBuffer[i] = high[i] + info.atr * 0.60;

      gSigDir   = info.dir;
      gSigScore = info.score;
      gSigTime  = time[i];
      gSigEntry = info.entry;
      gSigSL    = info.sl;
      gSigTP1   = info.tp1;
      gSigTP2   = info.tp2;

      //===========================================================//
      // ALERTE : uniquement sur la derniere bougie cloturee
      //===========================================================//

      if(Enable_Alerts && i == lastClosed && time[i] != gLastAlertTime)
      {
         gLastAlertTime = time[i];

         string message =
            _Symbol + " " + EnumToString(_Period) + " | V3.3 | " +
            TrendText(info.dir) +
            " | Score " + IntegerToString(info.score) + "%" +
            " | E " + DoubleToString(info.entry, _Digits) +
            " | SL " + DoubleToString(info.sl, _Digits) +
            " | TP1 " + DoubleToString(info.tp1, _Digits);

         Alert(message);

         if(Enable_Sound)
            PlaySound("alert.wav");

         if(Enable_Push)
            SendNotification(message);
      }
   }

   //==============================================================//
   // ETAT AFFICHE : bougie cloturee + apercu en cours
   //==============================================================//

   if(lastClosed >= 1)
   {
      EvaluateBar(
         lastClosed, rates_total,
         time, open, high, low, close, spread,
         false, gClosed
      );
   }

   if(
      !EvaluateBar(
         rates_total - 1, rates_total,
         time, open, high, low, close, spread,
         true, gLive
      )
   )
   {
      gLive.spreadPts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      gLive.spreadOk  =
         (Max_Spread_Points <= 0 || gLive.spreadPts <= Max_Spread_Points);
      gLive.sessionOk = InSession(TimeCurrent());
   }

   //==============================================================//
   // GRAPHIQUE
   //==============================================================//

   DrawChartLevels(gClosed, time[rates_total - 1]);
   DrawPanel();

   ChartRedraw(0);

   return rates_total;
}

//==================================================================//
// DEINIT
//==================================================================//

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, OBJ_PREFIX, 0, -1);

   ChartRedraw(0);

   if(EMA10Handle != INVALID_HANDLE) IndicatorRelease(EMA10Handle);
   if(EMA20Handle != INVALID_HANDLE) IndicatorRelease(EMA20Handle);
   if(EMA50Handle != INVALID_HANDLE) IndicatorRelease(EMA50Handle);
   if(ATRHandle   != INVALID_HANDLE) IndicatorRelease(ATRHandle);
   if(ADXHandle   != INVALID_HANDLE) IndicatorRelease(ADXHandle);

   if(M15_EMA10 != INVALID_HANDLE) IndicatorRelease(M15_EMA10);
   if(M15_EMA20 != INVALID_HANDLE) IndicatorRelease(M15_EMA20);
   if(M15_EMA50 != INVALID_HANDLE) IndicatorRelease(M15_EMA50);

   if(M5_EMA10 != INVALID_HANDLE) IndicatorRelease(M5_EMA10);
   if(M5_EMA20 != INVALID_HANDLE) IndicatorRelease(M5_EMA20);
   if(M5_EMA50 != INVALID_HANDLE) IndicatorRelease(M5_EMA50);

   if(M1_EMA10 != INVALID_HANDLE) IndicatorRelease(M1_EMA10);
   if(M1_EMA20 != INVALID_HANDLE) IndicatorRelease(M1_EMA20);
   if(M1_EMA50 != INVALID_HANDLE) IndicatorRelease(M1_EMA50);

   if(H1_EMA20 != INVALID_HANDLE) IndicatorRelease(H1_EMA20);
   if(H1_EMA50 != INVALID_HANDLE) IndicatorRelease(H1_EMA50);
}
//+------------------------------------------------------------------+

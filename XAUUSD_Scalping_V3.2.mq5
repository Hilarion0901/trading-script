//+------------------------------------------------------------------+
//|                  XAUUSD SCALPING V3.2                            |
//|                                                                  |
//|  M15 = Direction                                                 |
//|  M5  = Zone / Retest                                             |
//|  M1  = Confirmation / BOS                                        |
//|                                                                  |
//|  EMA 10 / 20 / 50                                                |
//|  ATR 14                                                          |
//|  Support / Resistance                                            |
//|  Multi-Timeframe                                                 |
//|  BUY / SELL / WAIT                                               |
//+------------------------------------------------------------------+

#property copyright "Custom"
#property version   "3.20"
#property description "XAUUSD Scalping M15-M5-M1"
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

input int EMA10_Period = 10;
input int EMA20_Period = 20;
input int EMA50_Period = 50;

input int ATR_Period = 14;

// Structure
input int SwingBars = 3;
input int LookbackBars = 50;

// Retest distance relative to ATR
input double Retest_ATR_Distance = 0.30;

// Minimum ATR
input double Min_ATR = 0.0;

// Display
input bool Show_EMA = true;
input bool Show_Signals = true;
input bool Show_Panel = true;

// Alerts
input bool Enable_Alerts = true;
input bool Enable_Sound = true;

// Panel : coin haut-gauche du graphique
input int Panel_X = 15;
input int Panel_Y = 20;

// Panel size
input int Panel_Width = 330;
input int Panel_Height = 430;

//==================================================================//
// BUFFERS
//==================================================================//

double EMA10Buffer[];
double EMA20Buffer[];
double EMA50Buffer[];

double BuyBuffer[];
double SellBuffer[];

//==================================================================//
// HANDLES - CURRENT TIMEFRAME
//==================================================================//

int EMA10Handle = INVALID_HANDLE;
int EMA20Handle = INVALID_HANDLE;
int EMA50Handle = INVALID_HANDLE;
int ATRHandle   = INVALID_HANDLE;

//==================================================================//
// HANDLES - M15
//==================================================================//

int M15_EMA10 = INVALID_HANDLE;
int M15_EMA20 = INVALID_HANDLE;
int M15_EMA50 = INVALID_HANDLE;

//==================================================================//
// HANDLES - M5
//==================================================================//

int M5_EMA10 = INVALID_HANDLE;
int M5_EMA20 = INVALID_HANDLE;
int M5_EMA50 = INVALID_HANDLE;

//==================================================================//
// HANDLES - M1
//==================================================================//

int M1_EMA10 = INVALID_HANDLE;
int M1_EMA20 = INVALID_HANDLE;
int M1_EMA50 = INVALID_HANDLE;

//==================================================================//
// GLOBAL
//==================================================================//

datetime LastAlertTime = 0;

//==================================================================//
// GET EMA CURRENT VALUE
//==================================================================//

double GetEMAValue(int handle, int shift = 0)
{
   if(handle == INVALID_HANDLE)
      return 0.0;

   double value[1];

   if(CopyBuffer(handle, 0, shift, 1, value) != 1)
      return 0.0;

   return value[0];
}

//==================================================================//
// GET ATR CURRENT VALUE
//==================================================================//

double GetATRValue(int shift = 0)
{
   if(ATRHandle == INVALID_HANDLE)
      return 0.0;

   double value[1];

   if(CopyBuffer(ATRHandle, 0, shift, 1, value) != 1)
      return 0.0;

   return value[0];
}

//==================================================================//
// GET TREND
//==================================================================//

int GetTrend(
   int handle10,
   int handle20,
   int handle50
)
{
   // Utilisation de la dernière bougie clôturée
   // afin de réduire les changements de signal
   double ema10 = GetEMAValue(handle10, 1);
   double ema20 = GetEMAValue(handle20, 1);
   double ema50 = GetEMAValue(handle50, 1);

   if(
      ema10 == 0.0 ||
      ema20 == 0.0 ||
      ema50 == 0.0
   )
   {
      return 0;
   }

   // Haussier
   if(
      ema10 > ema20 &&
      ema20 > ema50
   )
   {
      return 1;
   }

   // Baissier
   if(
      ema10 < ema20 &&
      ema20 < ema50
   )
   {
      return -1;
   }

   // Neutre
   return 0;
}

//==================================================================//
// TREND TEXT
//==================================================================//

string TrendText(int trend)
{
   if(trend == 1)
      return "BUY";

   if(trend == -1)
      return "SELL";

   return "WAIT";
}

//==================================================================//
// DELETE OBJECT
//==================================================================//

void DeleteObjectSafe(string name)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

//==================================================================//
// CREATE PANEL BACKGROUND
//==================================================================//
void CreatePanel()
{
   string name = "XAU_V32_PANEL_BG";

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_RECTANGLE_LABEL,
         0,
         0,
         0
      );
   }

   // Coin HAUT-GAUCHE du graphique + ancre HAUT-GAUCHE du rectangle.
   // Avec CORNER_LEFT_LOWER, l'ancre par défaut (haut-gauche) faisait
   // grandir le rectangle vers le BAS, donc hors écran : seul un petit
   // carré beige restait visible en bas.
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, Panel_X);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, Panel_Y);

   ObjectSetInteger(0, name, OBJPROP_XSIZE, Panel_Width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, Panel_Height);

   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'245,238,225');
   ObjectSetInteger(0, name, OBJPROP_COLOR, C'180,165,140');
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);

   // Premier plan du graphique, mais derrière les labels (ZORDER 0)
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 0);

   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//==================================================================//
// CREATE / UPDATE LABEL
//==================================================================//

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
   {
      ObjectCreate(
         0,
         name,
         OBJ_LABEL,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);

   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);

   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);

   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);

   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//==================================================================//
// UPDATE PANEL
//==================================================================//
void UpdatePanel(
   int trendM15,
   int trendM5,
   int trendM1,
   string signal,
   double atr,
   double ema10,
   double ema20,
   double ema50,
   double support,
   double resistance,
   bool retest,
   bool bos
)
{
   if(!Show_Panel)
      return;

   CreatePanel();

   int left = Panel_X + 18;

   //==============================================================//
   // COLORS
   //==============================================================//

   color textColor = C'45,45,45';
   color separatorColor = C'185,175,160';

   color m15Color = textColor;
   color m5Color  = textColor;
   color m1Color  = textColor;

   if(trendM15 == 1)
      m15Color = clrGreen;

   if(trendM15 == -1)
      m15Color = clrRed;

   if(trendM5 == 1)
      m5Color = clrGreen;

   if(trendM5 == -1)
      m5Color = clrRed;

   if(trendM1 == 1)
      m1Color = clrGreen;

   if(trendM1 == -1)
      m1Color = clrRed;

   color signalColor = C'120,100,0';

   if(signal == "BUY")
      signalColor = clrGreen;

   if(signal == "SELL")
      signalColor = clrRed;

   color retestColor = textColor;

   if(retest)
      retestColor = clrGreen;

   color bosColor = textColor;

   if(bos)
      bosColor = clrGreen;

   //==============================================================//
   // VERTICAL POSITIONS (depuis le HAUT du panneau)
   //==============================================================//

   int y = Panel_Y + 14;
   int step = (int)MathMax(22, (Panel_Height - 36) / 16);

   int titleY       = y; y += step;
   int line1Y       = y; y += step;
   int m15Y         = y; y += step;
   int m5Y          = y; y += step;
   int m1Y          = y; y += step;
   int line2Y       = y; y += step;
   int signalY      = y; y += step;
   int retestY      = y; y += step;
   int bosY         = y; y += step;
   int line3Y       = y; y += step;
   int atrY         = y; y += step;
   int ema10Y       = y; y += step;
   int ema20Y       = y; y += step;
   int ema50Y       = y; y += step;
   int line4Y       = y; y += step;
   int supportY     = y; y += step;
   int resistanceY  = y;

   //==============================================================//
   // TITLE
   //==============================================================//

   SetLabel(
      "XAU_V32_TITLE",
      "XAUUSD  |  SCALPING V3.2",
      left,
      titleY,
      13,
      C'25,25,25'
   );

   SetLabel(
      "XAU_V32_LINE1",
      "──────────────────────────",
      left,
      line1Y,
      9,
      separatorColor
   );

   //==============================================================//
   // TIMEFRAMES
   //==============================================================//

   SetLabel(
      "XAU_V32_M15",
      "M15       " + TrendText(trendM15),
      left,
      m15Y,
      11,
      m15Color
   );

   SetLabel(
      "XAU_V32_M5",
      "M5        " + TrendText(trendM5),
      left,
      m5Y,
      11,
      m5Color
   );

   SetLabel(
      "XAU_V32_M1",
      "M1        " + TrendText(trendM1),
      left,
      m1Y,
      11,
      m1Color
   );

   SetLabel(
      "XAU_V32_LINE2",
      "──────────────────────────",
      left,
      line2Y,
      9,
      separatorColor
   );

   SetLabel(
      "XAU_V32_SIGNAL",
      "SIGNAL       " + signal,
      left,
      signalY,
      13,
      signalColor
   );

   SetLabel(
      "XAU_V32_RETEST",
      "RETEST       " + (retest ? "YES" : "NO"),
      left,
      retestY,
      10,
      retestColor
   );

   SetLabel(
      "XAU_V32_BOS",
      "BOS M1       " + (bos ? "YES" : "NO"),
      left,
      bosY,
      10,
      bosColor
   );

   SetLabel(
      "XAU_V32_LINE3",
      "──────────────────────────",
      left,
      line3Y,
      9,
      separatorColor
   );

   SetLabel(
      "XAU_V32_ATR",
      "ATR 14       " + DoubleToString(atr, _Digits),
      left,
      atrY,
      10,
      textColor
   );

   SetLabel(
      "XAU_V32_EMA10",
      "EMA 10       " + DoubleToString(ema10, _Digits),
      left,
      ema10Y,
      10,
      clrDeepSkyBlue
   );

   SetLabel(
      "XAU_V32_EMA20",
      "EMA 20       " + DoubleToString(ema20, _Digits),
      left,
      ema20Y,
      10,
      C'190,140,0'
   );

   SetLabel(
      "XAU_V32_EMA50",
      "EMA 50       " + DoubleToString(ema50, _Digits),
      left,
      ema50Y,
      10,
      C'120,80,170'
   );

   SetLabel(
      "XAU_V32_LINE4",
      "──────────────────────────",
      left,
      line4Y,
      9,
      separatorColor
   );

   SetLabel(
      "XAU_V32_SUPPORT",
      "SUPPORT      " + DoubleToString(support, _Digits),
      left,
      supportY,
      10,
      C'45,100,70'
   );

   SetLabel(
      "XAU_V32_RESISTANCE",
      "RESISTANCE   " + DoubleToString(resistance, _Digits),
      left,
      resistanceY,
      10,
      C'170,65,55'
   );

   ChartRedraw(0);
}

//==================================================================//
// FIND SUPPORT
//==================================================================//

double FindSupport(
   ENUM_TIMEFRAMES timeframe,
   int lookback
)
{
   MqlRates rates[];

   int copied = CopyRates(
      _Symbol,
      timeframe,
      1,
      lookback,
      rates
   );

   if(copied <= 0)
      return 0.0;

   double support = DBL_MAX;

   for(int i = 0; i < copied; i++)
   {
      if(rates[i].low < support)
         support = rates[i].low;
   }

   if(support == DBL_MAX)
      return 0.0;

   return support;
}

//==================================================================//
// FIND RESISTANCE
//==================================================================//

double FindResistance(
   ENUM_TIMEFRAMES timeframe,
   int lookback
)
{
   MqlRates rates[];

   int copied = CopyRates(
      _Symbol,
      timeframe,
      1,
      lookback,
      rates
   );

   if(copied <= 0)
      return 0.0;

   double resistance = -DBL_MAX;

   for(int i = 0; i < copied; i++)
   {
      if(rates[i].high > resistance)
         resistance = rates[i].high;
   }

   if(resistance == -DBL_MAX)
      return 0.0;

   return resistance;
}

//==================================================================//
// FIND SWING HIGH
//==================================================================//

double FindSwingHigh(
   ENUM_TIMEFRAMES timeframe,
   int bars
)
{
   MqlRates rates[];

   int copied = CopyRates(
      _Symbol,
      timeframe,
      1,
      bars,
      rates
   );

   if(copied <= SwingBars * 2)
      return 0.0;

   for(
      int i = SwingBars;
      i < copied - SwingBars;
      i++
   )
   {
      bool isSwing = true;

      for(int j = 1; j <= SwingBars; j++)
      {
         if(
            rates[i].high <= rates[i-j].high ||
            rates[i].high <= rates[i+j].high
         )
         {
            isSwing = false;
            break;
         }
      }

      if(isSwing)
         return rates[i].high;
   }

   return 0.0;
}

//==================================================================//
// FIND SWING LOW
//==================================================================//

double FindSwingLow(
   ENUM_TIMEFRAMES timeframe,
   int bars
)
{
   MqlRates rates[];

   int copied = CopyRates(
      _Symbol,
      timeframe,
      1,
      bars,
      rates
   );

   if(copied <= SwingBars * 2)
      return 0.0;

   for(
      int i = SwingBars;
      i < copied - SwingBars;
      i++
   )
   {
      bool isSwing = true;

      for(int j = 1; j <= SwingBars; j++)
      {
         if(
            rates[i].low >= rates[i-j].low ||
            rates[i].low >= rates[i+j].low
         )
         {
            isSwing = false;
            break;
         }
      }

      if(isSwing)
         return rates[i].low;
   }

   return 0.0;
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

   PlotIndexSetInteger(3, PLOT_ARROW, 233);
   PlotIndexSetInteger(4, PLOT_ARROW, 234);

   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(4, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   EMA10Handle = iMA(_Symbol, _Period, EMA10_Period, 0, MODE_EMA, PRICE_CLOSE);
   EMA20Handle = iMA(_Symbol, _Period, EMA20_Period, 0, MODE_EMA, PRICE_CLOSE);
   EMA50Handle = iMA(_Symbol, _Period, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);
   ATRHandle   = iATR(_Symbol, _Period, ATR_Period);

   M15_EMA10 = iMA(_Symbol, PERIOD_M15, EMA10_Period, 0, MODE_EMA, PRICE_CLOSE);
   M15_EMA20 = iMA(_Symbol, PERIOD_M15, EMA20_Period, 0, MODE_EMA, PRICE_CLOSE);
   M15_EMA50 = iMA(_Symbol, PERIOD_M15, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);

   M5_EMA10 = iMA(_Symbol, PERIOD_M5, EMA10_Period, 0, MODE_EMA, PRICE_CLOSE);
   M5_EMA20 = iMA(_Symbol, PERIOD_M5, EMA20_Period, 0, MODE_EMA, PRICE_CLOSE);
   M5_EMA50 = iMA(_Symbol, PERIOD_M5, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);

   M1_EMA10 = iMA(_Symbol, PERIOD_M1, EMA10_Period, 0, MODE_EMA, PRICE_CLOSE);
   M1_EMA20 = iMA(_Symbol, PERIOD_M1, EMA20_Period, 0, MODE_EMA, PRICE_CLOSE);
   M1_EMA50 = iMA(_Symbol, PERIOD_M1, EMA50_Period, 0, MODE_EMA, PRICE_CLOSE);

   if(
      EMA10Handle == INVALID_HANDLE ||
      EMA20Handle == INVALID_HANDLE ||
      EMA50Handle == INVALID_HANDLE ||
      ATRHandle   == INVALID_HANDLE
   )
   {
      Print("Erreur lors de la création des indicateurs principaux.");
      return INIT_FAILED;
   }

   IndicatorSetString(INDICATOR_SHORTNAME, "XAUUSD Scalping V3.2");

   if(Show_Panel)
      CreatePanel();

   return INIT_SUCCEEDED;
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
   if(rates_total < EMA50_Period + 10)
      return 0;

   if(Show_EMA)
   {
      CopyBuffer(EMA10Handle, 0, 0, rates_total, EMA10Buffer);
      CopyBuffer(EMA20Handle, 0, 0, rates_total, EMA20Buffer);
      CopyBuffer(EMA50Handle, 0, 0, rates_total, EMA50Buffer);
   }
   else
   {
      ArrayInitialize(EMA10Buffer, EMPTY_VALUE);
      ArrayInitialize(EMA20Buffer, EMPTY_VALUE);
      ArrayInitialize(EMA50Buffer, EMPTY_VALUE);
   }

   ArrayInitialize(BuyBuffer, EMPTY_VALUE);
   ArrayInitialize(SellBuffer, EMPTY_VALUE);

   double ema10 = GetEMAValue(EMA10Handle, 0);
   double ema20 = GetEMAValue(EMA20Handle, 0);
   double ema50 = GetEMAValue(EMA50Handle, 0);
   double atr   = GetATRValue(0);

   int trendM15 = GetTrend(M15_EMA10, M15_EMA20, M15_EMA50);
   int trendM5  = GetTrend(M5_EMA10, M5_EMA20, M5_EMA50);
   int trendM1  = GetTrend(M1_EMA10, M1_EMA20, M1_EMA50);

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   double supportM5    = FindSupport(PERIOD_M5, LookbackBars);
   double resistanceM5 = FindResistance(PERIOD_M5, LookbackBars);

   double swingHighM1 = FindSwingHigh(PERIOD_M1, LookbackBars);
   double swingLowM1  = FindSwingLow(PERIOD_M1, LookbackBars);

   bool bullishRetest = false;
   bool bearishRetest = false;

   if(supportM5 > 0 && atr > 0)
   {
      if(MathAbs(price - supportM5) <= atr * Retest_ATR_Distance)
         bullishRetest = true;
   }

   if(resistanceM5 > 0 && atr > 0)
   {
      if(MathAbs(price - resistanceM5) <= atr * Retest_ATR_Distance)
         bearishRetest = true;
   }

   bool retest = bullishRetest || bearishRetest;

   bool bullishBreak = false;
   bool bearishBreak = false;

   if(swingHighM1 > 0 && price > swingHighM1)
      bullishBreak = true;

   if(swingLowM1 > 0 && price < swingLowM1)
      bearishBreak = true;

   bool bos = bullishBreak || bearishBreak;

   string signal = "WAIT";

   bool buySetup =
      trendM15 == 1 &&
      trendM5  == 1 &&
      trendM1  == 1 &&
      bullishRetest &&
      bullishBreak &&
      (Min_ATR <= 0 || atr >= Min_ATR);

   bool sellSetup =
      trendM15 == -1 &&
      trendM5  == -1 &&
      trendM1  == -1 &&
      bearishRetest &&
      bearishBreak &&
      (Min_ATR <= 0 || atr >= Min_ATR);

   if(buySetup)
      signal = "BUY";

   if(sellSetup)
      signal = "SELL";

   if(Show_Signals && atr > 0)
   {
      if(signal == "BUY")
         BuyBuffer[0] = low[0] - atr * 0.50;

      if(signal == "SELL")
         SellBuffer[0] = high[0] + atr * 0.50;
   }

   if(Enable_Alerts && signal != "WAIT")
   {
      if(time[0] != LastAlertTime)
      {
         LastAlertTime = time[0];

         string message = _Symbol + " | Scalping V3.2 | " + signal;
         Alert(message);

         if(Enable_Sound)
            PlaySound("alert.wav");
      }
   }

   UpdatePanel(
      trendM15,
      trendM5,
      trendM1,
      signal,
      atr,
      ema10,
      ema20,
      ema50,
      supportM5,
      resistanceM5,
      retest,
      bos
   );

   return rates_total;
}

//==================================================================//
// DEINIT
//==================================================================//
void OnDeinit(const int reason)
{
   DeleteObjectSafe("XAU_V32_PANEL_BG");

   DeleteObjectSafe("XAU_V32_TITLE");
   DeleteObjectSafe("XAU_V32_LINE1");

   DeleteObjectSafe("XAU_V32_M15");
   DeleteObjectSafe("XAU_V32_M5");
   DeleteObjectSafe("XAU_V32_M1");

   DeleteObjectSafe("XAU_V32_LINE2");

   DeleteObjectSafe("XAU_V32_SIGNAL");
   DeleteObjectSafe("XAU_V32_RETEST");
   DeleteObjectSafe("XAU_V32_BOS");

   DeleteObjectSafe("XAU_V32_LINE3");

   DeleteObjectSafe("XAU_V32_ATR");

   DeleteObjectSafe("XAU_V32_EMA10");
   DeleteObjectSafe("XAU_V32_EMA20");
   DeleteObjectSafe("XAU_V32_EMA50");

   DeleteObjectSafe("XAU_V32_LINE4");

   DeleteObjectSafe("XAU_V32_SUPPORT");
   DeleteObjectSafe("XAU_V32_RESISTANCE");

   if(EMA10Handle != INVALID_HANDLE)
      IndicatorRelease(EMA10Handle);

   if(EMA20Handle != INVALID_HANDLE)
      IndicatorRelease(EMA20Handle);

   if(EMA50Handle != INVALID_HANDLE)
      IndicatorRelease(EMA50Handle);

   if(ATRHandle != INVALID_HANDLE)
      IndicatorRelease(ATRHandle);

   if(M15_EMA10 != INVALID_HANDLE)
      IndicatorRelease(M15_EMA10);

   if(M15_EMA20 != INVALID_HANDLE)
      IndicatorRelease(M15_EMA20);

   if(M15_EMA50 != INVALID_HANDLE)
      IndicatorRelease(M15_EMA50);

   if(M5_EMA10 != INVALID_HANDLE)
      IndicatorRelease(M5_EMA10);

   if(M5_EMA20 != INVALID_HANDLE)
      IndicatorRelease(M5_EMA20);

   if(M5_EMA50 != INVALID_HANDLE)
      IndicatorRelease(M5_EMA50);

   if(M1_EMA10 != INVALID_HANDLE)
      IndicatorRelease(M1_EMA10);

   if(M1_EMA20 != INVALID_HANDLE)
      IndicatorRelease(M1_EMA20);

   if(M1_EMA50 != INVALID_HANDLE)
      IndicatorRelease(M1_EMA50);
}
//+------------------------------------------------------------------+

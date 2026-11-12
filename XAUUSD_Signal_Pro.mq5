//+------------------------------------------------------------------+
//|                                       XAUUSD_Signal_Pro.mq5      |
//|  Indicateur visuel PRO — signaux BUY / SELL XAUUSD               |
//|                                                                  |
//|  3 modes de trading analyses en parallele :                      |
//|    SCALPING : tendance M15  zone M5   declencheur M1  biais H1   |
//|    INTRADAY : tendance H1   zone M15  declencheur M5  biais H4   |
//|    SWING    : tendance D1   zone H4   declencheur H1  biais W1   |
//|  Conseiller : indique quel mode convient au marche actuel        |
//|  (tendance, ADX, cout du spread, volatilite, session, resultats) |
//|                                                                  |
//|  Fleches uniquement sur bougies CLOTUREES (pas de repeint)       |
//|  Note de qualite A+ / A / B, TP plafonne avant le S/R oppose,    |
//|  SL borne en ATR, RSI anti-chase, statistiques TP/SL par mode.   |
//|                                                                  |
//|  Ce n'est PAS une garantie de gain. Un SL reste obligatoire.     |
//+------------------------------------------------------------------+
#property copyright   "XAUUSD Signal Pro"
#property version     "2.00"
#property description "Signaux BUY/SELL XAUUSD — Scalping / Intraday / Swing + conseiller de mode, non repeint"
#property indicator_chart_window

#property indicator_buffers 6
#property indicator_plots   5

#property indicator_label1  "EMA 10"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDeepSkyBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

#property indicator_label2  "EMA 20"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

#property indicator_label3  "EMA 50"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMediumPurple
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

#property indicator_label4  "BUY"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrLime
#property indicator_width4  4

#property indicator_label5  "SELL"
#property indicator_type5   DRAW_ARROW
#property indicator_color5  clrRed
#property indicator_width5  4

//==================================================================//
// ENUMS / INPUTS
//==================================================================//

enum ENUM_TRADE_MODE
{
   TM_AUTO     = 0,  // AUTO (le script choisit le mode)
   TM_SCALPING = 1,  // Scalping (M15 / M5 / M1)
   TM_INTRADAY = 2,  // Intraday (H1 / M15 / M5)
   TM_SWING    = 3   // Swing (D1 / H4 / H1)
};

enum ENUM_QUALITY
{
   QUAL_B     = 1,   // B et plus (plus de signaux)
   QUAL_A     = 2,   // A et plus (equilibre)
   QUAL_APLUS = 3    // A+ uniquement (tres selectif)
};

enum ENUM_PANEL_THEME
{
   THEME_DARK  = 0,  // Sombre
   THEME_LIGHT = 1   // Clair
};

enum ENUM_CHART_THEME
{
   CHART_THEME_NONE       = 0,  // Ne pas modifier le graphique
   CHART_THEME_GOLD_NIGHT = 1   // Gold Night (sombre, assorti au panneau)
};

input group "===== Mode de trading ====="
input ENUM_TRADE_MODE InpTradeMode = TM_AUTO;    // Mode suivi par le bandeau
input bool   InpEnableScalping     = true;       // Analyser le scalping
input bool   InpEnableIntraday     = true;       // Analyser l'intraday
input bool   InpEnableSwing        = true;       // Analyser le swing
input int    InpAdviceMinScore     = 45;         // Aptitude mini (%) pour conseiller un mode
input int    InpAdviceHysteresis   = 10;         // Ecart (%) requis pour changer de mode conseille
input int    InpAdviceConfirmBars  = 3;          // Bougies M1 de confirmation avant de changer de mode

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

input group "===== Structure (en bougies de chaque UT) ====="
input int    InpSwingBars          = 2;
input int    InpSwingLookbackTrend = 40;         // UT tendance
input int    InpSwingLookbackZone  = 50;         // UT zone
input int    InpSwingLookbackTrig  = 40;         // UT declencheur
input int    InpSRLookback         = 60;
input double InpSRZonePoints       = 50.0;       // Largeur mini de zone S/R (points)
input double InpZoneATR            = 0.20;       // Largeur de zone S/R (x ATR zone)
input double InpPullbackATR        = 0.45;
input int    InpRetestMaxBars      = 12;
input double InpBOSBufferATR       = 0.05;
input double InpPinWickBodyRatio   = 2.0;
input double InpMaxBodyRatio       = 0.38;

input group "===== Score / filtres ====="
input int    InpMinScore           = 7;          // Score mini (max 16)
input bool   InpUseBias            = true;       // UT biais ne doit pas etre contraire
input bool   InpUseADX             = true;       // Eviter les ranges (ADX de l'UT zone)
input double InpADXMin             = 18.0;
input bool   InpAvoidExtended      = true;       // Pas de chase
input double InpMaxCandleATR       = 2.2;
input long   InpMaxSpreadPoints    = 50;         // Spread maxi scalping (x2 intraday, x4 swing) — 0 = off
input int    InpCooldownBars       = 5;          // Bougies (UT declencheur) mini entre 2 signaux d'un mode
input int    InpSignalValidBars    = 3;          // Bougies (UT declencheur) ou l'entree reste "ACTIVE"
input double InpMinRR              = 1.3;
input double InpRRRatio            = 1.5;
input double InpSLATRMult          = 1.20;
input double InpSLBufferPoints     = 20.0;

input group "===== Precision ====="
input ENUM_QUALITY InpMinQuality   = QUAL_A;     // Qualite mini pour afficher un signal
input bool   InpRequireTriggerClose = true;      // Bougie de declenchement cloturee dans le sens du trade
input bool   InpCapTPAtLevel       = true;       // TP plafonne avant le prochain S/R oppose
input double InpMinSLATR           = 0.35;       // SL mini (x ATR zone) — anti bruit
input double InpMaxSLATR           = 2.50;       // SL maxi (x ATR zone) — 0 = off
input double InpRSIOverbought      = 72.0;       // RSI zone au-dessus : pas de BUY (0 = off)
input double InpRSIOversold        = 28.0;       // RSI zone en dessous : pas de SELL (0 = off)

input group "===== Session (heure serveur, scalping + intraday) ====="
input bool   InpUseSession         = true;
input int    InpSessionStartHour   = 8;
input int    InpSessionEndHour     = 21;

input group "===== Affichage ====="
input bool   InpShowEMA            = true;
input bool   InpShowArrows         = true;
input bool   InpArrowsFocusOnly    = false;      // Fleches du mode choisi uniquement (mode manuel)
input bool   InpShowSignalLabels   = true;       // Etiquette "SCALP BUY A+" sous les fleches
input bool   InpShowPanel          = true;
input bool   InpShowLevels         = true;
input bool   InpShowTradeLevels    = true;
input bool   InpShowTradeZones     = true;       // Zones colorees Entree->TP / Entree->SL
input int    InpHistoryBars        = 1000;
input int    InpBarsPerCall        = 100;        // Bougies d'historique analysees par passe (anti-gel)
input ENUM_PANEL_THEME InpTheme    = THEME_DARK;
input ENUM_CHART_THEME InpChartTheme = CHART_THEME_GOLD_NIGHT; // Theme du graphique (bougies, fond, grille)
input bool   InpRestoreChartTheme  = true;       // Remettre les couleurs d'origine au retrait
input int    InpPanelX             = 12;
input int    InpPanelY             = 24;
input double InpPanelScale         = 1.00;
input string InpFont               = "Segoe UI";
input string InpFontBold           = "Segoe UI Semibold";

input group "===== Niveaux cles ====="
input bool   InpShowMTFLevels      = true;       // Support / resistance de chaque unite de temps
input bool   InpLevelsM5           = true;
input bool   InpLevelsM15          = true;
input bool   InpLevelsH1           = true;
input bool   InpLevelsH4           = true;
input bool   InpLevelsD1           = true;
input int    InpMTFLevelLookback   = 150;        // Bougies scannees par UT
input bool   InpShowPrevDay        = true;       // PDH / PDL / cloture de la veille
input bool   InpShowPrevWeek       = true;       // PWH / PWL (semaine precedente)
input bool   InpShowPrevMonth      = true;       // PMH / PML (mois precedent)
input bool   InpShowRoundLevels    = true;       // Niveaux ronds institutionnels
input double InpRoundMajor         = 50.0;       // Pas des niveaux ronds majeurs ($)
input double InpRoundMinor         = 10.0;       // Pas des niveaux ronds mineurs ($, 0 = off)
input int    InpRoundCount         = 3;          // Niveaux majeurs affiches de chaque cote du prix
input bool   InpKeyLevelsInSignals = true;       // Utiliser ces niveaux comme S/R dans les signaux (zones, TP)

input group "===== Alertes ====="
input bool   InpAlertAllModes      = false;      // false = alerte du mode suivi uniquement
input bool   InpAlertPopup         = true;
input bool   InpAlertSound         = true;
input bool   InpAlertPush          = false;

//==================================================================//
// CONSTANTES / BUFFERS
//==================================================================//

#define OBJ_PREFIX   "XAU_SP_"
#define PANEL_PREFIX "XAU_SP_P_"
#define PANEL_TITLE  "XAUUSD  SIGNAL PRO"
#define PANEL_W      320
#define MAX_SIGNALS  600

#define NMODES       3
#define MODE_SCALP   0
#define MODE_INTRA   1
#define MODE_SWING   2

#define NTF          7

#define SETUP_NONE     0
#define SETUP_TREND    1
#define SETUP_BREAKOUT 2
#define SETUP_RETEST   3
#define SETUP_MEANREV  4
#define TF_M1        0
#define TF_M5        1
#define TF_M15       2
#define TF_H1        3
#define TF_H4        4
#define TF_D1        5
#define TF_W1        6

double EMA10Buffer[];
double EMA20Buffer[];
double EMA50Buffer[];
double BuyBuffer[];
double SellBuffer[];

int    gH_E10 = INVALID_HANDLE, gH_E20 = INVALID_HANDLE, gH_E50 = INVALID_HANDLE;
int    gH_ATR = INVALID_HANDLE;
double gATR[];

void ReleaseH(int &h)
{
   if(h != INVALID_HANDLE)
   {
      IndicatorRelease(h);
      h = INVALID_HANDLE;
   }
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

// Donnees d'une unite de temps (indicateurs + buffers en serie)
class CTFData
{
public:
   ENUM_TIMEFRAMES tf;
   bool   used;
   bool   ready;
   int    hE10, hE20, hE50, hRSI, hATR, hADX, hBB;
   double e10[], e20[], e50[], rsi[], atr[], adx[], bbMid[], bbUp[], bbLo[];

   CTFData()
   {
      tf = PERIOD_CURRENT; used = false; ready = false;
      hE10 = hE20 = hE50 = hRSI = hATR = hADX = hBB = INVALID_HANDLE;
   }

   bool Create(const ENUM_TIMEFRAMES t)
   {
      tf   = t;
      used = true;
      hE10 = iMA(_Symbol, tf, InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
      hE20 = iMA(_Symbol, tf, InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
      hE50 = iMA(_Symbol, tf, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
      hRSI = iRSI(_Symbol, tf, InpRSIPeriod, PRICE_CLOSE);
      hATR = iATR(_Symbol, tf, InpATRPeriod);
      hADX = iADX(_Symbol, tf, InpADXPeriod);
      hBB  = iBands(_Symbol, tf, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
      return (hE10 != INVALID_HANDLE && hE20 != INVALID_HANDLE && hE50 != INVALID_HANDLE &&
              hRSI != INVALID_HANDLE && hATR != INVALID_HANDLE && hADX != INVALID_HANDLE &&
              hBB  != INVALID_HANDLE);
   }

   bool Load(const int n)
   {
      if(!used) return false;
      ready =
         CopySeriesBuffer(hE10, 0, n, e10) &&
         CopySeriesBuffer(hE20, 0, n, e20) &&
         CopySeriesBuffer(hE50, 0, n, e50) &&
         CopySeriesBuffer(hRSI, 0, n, rsi) &&
         CopySeriesBuffer(hATR, 0, n, atr) &&
         CopySeriesBuffer(hADX, 0, n, adx) &&
         CopySeriesBuffer(hBB,  0, n, bbMid) &&
         CopySeriesBuffer(hBB,  1, n, bbUp) &&
         CopySeriesBuffer(hBB,  2, n, bbLo);
      return ready;
   }

   void Release()
   {
      ReleaseH(hE10); ReleaseH(hE20); ReleaseH(hE50);
      ReleaseH(hRSI); ReleaseH(hATR); ReleaseH(hADX); ReleaseH(hBB);
      used = false; ready = false;
   }
};

CTFData gTF[NTF];

struct ModeDef
{
   string          name;       // SCALPING
   string          tag;        // SCALP
   int             kTrend;     // index dans gTF
   int             kZone;
   int             kTrig;
   int             kBias;
   ENUM_TIMEFRAMES pivotTF;    // pivots du jour / de la semaine
   bool            useVWAP;
   bool            useSession;
   double          spreadMult;
   bool            enabled;
};

ModeDef gMode[NMODES];

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
   int      mode;
   int      dir;          // 1 BUY, -1 SELL, 0 aucun
   int      cdir;         // direction candidate (pour la checklist)
   int      grade;        // 0 aucun, 1 B, 2 A, 3 A+
   int      setup;        // SETUP_TREND / BREAKOUT / RETEST / MEANREV
   int      scoreBuy;
   int      scoreSell;
   int      maxScore;
   int      tT;           // tendance UT tendance
   int      tZ;           // tendance UT zone
   int      tG;           // tendance UT declencheur
   int      tB;           // tendance UT biais
   datetime trigTime;     // ouverture de la bougie de declenchement

   double   ema10;
   double   ema20;
   double   ema50;
   double   rsiT, rsiZ, rsiG;
   double   vwap;
   double   atr;          // ATR du graphique (placement des fleches)
   double   atrZ;         // ATR de l'UT zone
   double   adx;          // ADX de l'UT zone
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
   bool     rrOk;
   bool     slOk;
   bool     capped;

   bool     chkTrend;
   bool     chkZone;
   bool     chkTrigger;
   bool     chkScore;
   bool     chkBias;
   bool     chkRR;
   bool     chkRSI;

   string   action;       // BUY / SELL / WAIT
   string   reason;
};

struct SignalRec
{
   datetime time;         // bougie du graphique
   datetime trigTime;     // bougie de declenchement (UT du mode)
   int      mode;
   int      index;
   int      dir;
   int      grade;
   int      setup;
   int      score;
   double   entry;
   double   sl;
   double   tp;
   int      result;       // 0 en cours, 1 TP, -1 SL
   int      scanned;      // derniere bougie verifiee
   bool     late;         // prix deja parti (verrouille : ne revient pas a "actif")
};

struct ModeAdvice
{
   int    score;          // aptitude 0-100
   string plus;           // meilleur argument
   string minus;          // principal frein
};

SetupInfo      gClosed[NMODES];
BreakoutMemory gBO[NMODES];
ModeAdvice     gAdvice[NMODES];
int            gRecommended = -1;     // -1 = aucun mode favorable
int            gFocus       = MODE_SCALP;

SignalRec gSigs[];
int       gSigCount      = 0;
datetime  gLastEvalTime  = 0;
datetime  gLastAlertTime[NMODES];

bool   gDataReady    = false;
uint   gLastLoadTick = 0;
int    gLastBarCount = 0;
long   gSpreadNow    = 0;      // spread lisse (moyenne mobile) : evite les sauts a chaque tick
double gSpreadAvg    = 0.0;
int    gPendingRec   = -2;     // changement de mode conseille en attente de confirmation
int    gPendingCount = 0;
datetime gAdviceBar  = 0;
bool   gAdviceInit   = false;

// Objets du graphique mis a jour sur place (pas d'effacement global -> pas de scintillement)
string gKeep[];
int    gKeepCount = 0;

bool   gMinimized = false;
double gS   = 1.0;             // echelle pixels du panneau
double gFit = 1.0;             // reduction auto si le graphique est trop petit
bool   gFitValid = false;
int    gLastChartH = 0;
int    gLevelsFocus = -1;      // mode dont les niveaux sont affiches
bool   gDormant     = false;   // doublon de l'indicateur sur ce graphique : instance inactive
double gInstanceId  = 0.0;
bool   gCatchingUp = false;    // historique en cours d'analyse (par tranches)
int    gCatchTotal = 0;
int    gCatchDone  = 0;
datetime gKeyLevelsBar = 0;    // derniere bougie pour laquelle les niveaux cles ont ete traces
string gDrawn[];
int    gDrawnCount = 0;
string gPrev[];                // objets du panneau de la passe precedente
int    gPrevCount  = 0;
string gObjSig[];              // signature de chaque objet du panneau (cache)
int    gObjUpdates = 0;        // objets reellement modifies pendant la passe
bool   gDry = false;           // passe de mesure (pas de dessin)

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

string TFName(const ENUM_TIMEFRAMES tf)
{
   string s = EnumToString(tf);
   if(StringFind(s, "PERIOD_") == 0)
      s = StringSubstr(s, 7);
   return s;
}

ENUM_TIMEFRAMES TFOf(const int k)
{
   switch(k)
   {
      case TF_M1:  return PERIOD_M1;
      case TF_M5:  return PERIOD_M5;
      case TF_M15: return PERIOD_M15;
      case TF_H1:  return PERIOD_H1;
      case TF_H4:  return PERIOD_H4;
      case TF_D1:  return PERIOD_D1;
   }
   return PERIOD_W1;
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

// Derniere bougie de l'UT tf entierement CLOTUREE a la cloture de la bougie du graphique.
// Fonctionne que tf soit plus grande ou plus petite que l'UT du graphique.
int ClosedShift(const ENUM_TIMEFRAMES tf, const datetime barOpen)
{
   datetime barClose = barOpen + PeriodSeconds(_Period);
   int sh = iBarShift(_Symbol, tf, barClose - 1, false);
   if(sh < 0)
      return -1;

   datetime tfOpen = iTime(_Symbol, tf, sh);
   if(tfOpen <= 0)
      return -1;

   if(tfOpen + PeriodSeconds(tf) > barClose)
      sh++;

   return sh;
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
   // Remise a zero explicite (les structures locales ne sont pas initialisees en MQL5)
   s.mode = 0; s.dir = 0; s.cdir = 0; s.grade = 0; s.setup = SETUP_NONE;
   s.scoreBuy = 0; s.scoreSell = 0; s.maxScore = 0;
   s.tT = 0; s.tZ = 0; s.tG = 0; s.tB = 0; s.trigTime = 0;
   s.ema10 = 0.0; s.ema20 = 0.0; s.ema50 = 0.0;
   s.rsiT = 50.0; s.rsiZ = 50.0; s.rsiG = 50.0;
   s.vwap = 0.0; s.atr = 0.0; s.atrZ = 0.0; s.adx = 0.0;
   s.pivot = 0.0; s.r1 = 0.0; s.s1 = 0.0;
   s.support.price = 0.0; s.support.lo = 0.0; s.support.hi = 0.0; s.support.valid = false;
   s.resist.price  = 0.0; s.resist.lo  = 0.0; s.resist.hi  = 0.0; s.resist.valid  = false;
   s.entry = 0.0; s.sl = 0.0; s.tp = 0.0; s.rr = 0.0;
   s.spreadPts = 0;
   s.spreadOk = false; s.sessionOk = false; s.adxOk = false;
   s.rrOk = false; s.slOk = false; s.capped = false;
   s.chkTrend = false; s.chkZone = false; s.chkTrigger = false; s.chkScore = false;
   s.chkBias = false; s.chkRR = false; s.chkRSI = false;
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
// MODES
//==================================================================//

void SetMode(const int m, const string name, const string tag,
             const int kT, const int kZ, const int kG, const int kB,
             const ENUM_TIMEFRAMES pivotTF, const bool vwap, const bool session,
             const double spreadMult, const bool enabled)
{
   gMode[m].name       = name;
   gMode[m].tag        = tag;
   gMode[m].kTrend     = kT;
   gMode[m].kZone      = kZ;
   gMode[m].kTrig      = kG;
   gMode[m].kBias      = kB;
   gMode[m].pivotTF    = pivotTF;
   gMode[m].useVWAP    = vwap;
   gMode[m].useSession = session;
   gMode[m].spreadMult = spreadMult;
   gMode[m].enabled    = enabled;
}

void InitModes()
{
   // Un mode choisi manuellement est toujours analyse
   bool sc = InpEnableScalping || InpTradeMode == TM_SCALPING;
   bool in = InpEnableIntraday || InpTradeMode == TM_INTRADAY;
   bool sw = InpEnableSwing    || InpTradeMode == TM_SWING;
   if(!sc && !in && !sw)
      sc = true;

   SetMode(MODE_SCALP, "SCALPING", "SCALP", TF_M15, TF_M5,  TF_M1, TF_H1, PERIOD_D1, true,  true,  1.0, sc);
   SetMode(MODE_INTRA, "INTRADAY", "INTRA", TF_H1,  TF_M15, TF_M5, TF_H4, PERIOD_D1, true,  true,  2.0, in);
   SetMode(MODE_SWING, "SWING",    "SWING", TF_D1,  TF_H4,  TF_H1, TF_W1, PERIOD_W1, false, false, 4.0, sw);
}

bool ModeReady(const int m)
{
   return (gMode[m].enabled &&
           gTF[gMode[m].kTrend].ready && gTF[gMode[m].kZone].ready && gTF[gMode[m].kTrig].ready);
}

ENUM_TIMEFRAMES TrigTF(const int m) { return gTF[gMode[m].kTrig].tf; }

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

void PivotAt(const ENUM_TIMEFRAMES ptf, const datetime barTime, double &pivot, double &r1, double &s1)
{
   pivot = r1 = s1 = 0.0;
   int sh = iBarShift(_Symbol, ptf, barTime, false);
   if(sh < 0)
      sh = 0;
   int prev = sh + 1;
   double h = iHigh(_Symbol,  ptf, prev);
   double l = iLow(_Symbol,   ptf, prev);
   double c = iClose(_Symbol, ptf, prev);
   if(!ValidNum(h) || !ValidNum(l) || !ValidNum(c) || h < l)
      return;
   pivot = (h + l + c) / 3.0;
   r1 = (2.0 * pivot) - l;
   s1 = (2.0 * pivot) - h;
}

//==================================================================//
// EVALUATION D'UNE BOUGIE CLOTUREE POUR UN MODE
//==================================================================//

int ScoreMax() { return 16; }

string GradeText(const int g)
{
   if(g >= 3) return "A+";
   if(g == 2) return "A";
   if(g == 1) return "B";
   return "-";
}

string SetupName(const int t)
{
   switch(t)
   {
      case SETUP_TREND:    return "TREND-FOLLOWING";
      case SETUP_BREAKOUT: return "BREAKOUT";
      case SETUP_RETEST:   return "BREAKOUT + RETEST";
      case SETUP_MEANREV:  return "MEAN REVERSION";
   }
   return "-";
}

string SetupShort(const int t)
{
   switch(t)
   {
      case SETUP_TREND:    return "TREND";
      case SETUP_BREAKOUT: return "BREAK";
      case SETUP_RETEST:   return "RETEST";
      case SETUP_MEANREV:  return "MEAN REV";
   }
   return "";
}

string SetupDesc(const int t)
{
   switch(t)
   {
      case SETUP_TREND:    return "Pullback dans la tendance, entree avec le courant";
      case SETUP_BREAKOUT: return "Cassure d'un niveau, entree sur l'elan";
      case SETUP_RETEST:   return "Cassure puis retour tester le niveau casse";
      case SETUP_MEANREV:  return "Prix etire loin de sa moyenne, pari sur le retour";
   }
   return "";
}

//==================================================================//
// NIVEAUX CLES : PERIODES PRECEDENTES / NIVEAUX RONDS
//==================================================================//

// Plus haut / plus bas / cloture de la periode PRECEDENT celle qui contient t (non repeint)
bool PrevRange(const ENUM_TIMEFRAMES ptf, const datetime t, double &hi, double &lo, double &cl)
{
   hi = lo = cl = 0.0;
   int sh = iBarShift(_Symbol, ptf, t, false);
   if(sh < 0)
      return false;
   hi = iHigh(_Symbol,  ptf, sh + 1);
   lo = iLow(_Symbol,   ptf, sh + 1);
   cl = iClose(_Symbol, ptf, sh + 1);
   return (ValidNum(hi) && ValidNum(lo) && hi >= lo);
}

// Niveau rond majeur juste en dessous / au dessus du prix
double RoundBelow(const double price) { return (InpRoundMajor > 0.0 ? MathFloor(price / InpRoundMajor) * InpRoundMajor : 0.0); }
double RoundAbove(const double price) { return (InpRoundMajor > 0.0 ? MathCeil(price / InpRoundMajor) * InpRoundMajor : 0.0); }

// Ajoute les niveaux cles du mode comme candidats S/R
void AddKeyCandidates(const int m, const datetime barTime, const double ref, double &cands[], int &n)
{
   if(!InpKeyLevelsInSignals)
      return;
   double h, l, c;
   if(m != MODE_SWING)
   {
      if(PrevRange(PERIOD_D1, barTime, h, l, c)) { cands[n++] = h; cands[n++] = l; }
      if(PrevRange(PERIOD_W1, barTime, h, l, c)) { cands[n++] = h; cands[n++] = l; }
   }
   else
   {
      if(PrevRange(PERIOD_W1,  barTime, h, l, c)) { cands[n++] = h; cands[n++] = l; }
      if(PrevRange(PERIOD_MN1, barTime, h, l, c)) { cands[n++] = h; cands[n++] = l; }
   }
   double rb = RoundBelow(ref), ra = RoundAbove(ref);
   if(rb > 0.0) cands[n++] = rb;
   if(ra > 0.0 && ra != rb) cands[n++] = ra;
}

bool EvaluateBar(
   const int m,
   const int i,
   const int rates_total,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const int &spread[],
   SetupInfo &info
)
{
   ResetSetup(info);
   info.mode = m;

   if(i < 20 || i >= rates_total || !ModeReady(m))
      return false;

   int kT = gMode[m].kTrend, kZ = gMode[m].kZone, kG = gMode[m].kTrig, kB = gMode[m].kBias;
   ENUM_TIMEFRAMES tfT = gTF[kT].tf, tfZ = gTF[kZ].tf, tfG = gTF[kG].tf;

   datetime barTime = time[i];
   int sT = ClosedShift(tfT, barTime);
   int sZ = ClosedShift(tfZ, barTime);
   int sG = ClosedShift(tfG, barTime);
   int sB = (gTF[kB].ready ? ClosedShift(gTF[kB].tf, barTime) : -1);

   if(sT < 1 || sZ < 1 || sG < 1)
      return false;
   if(sT >= ArraySize(gTF[kT].e10) || sZ >= ArraySize(gTF[kZ].e10) || sG >= ArraySize(gTF[kG].e10))
      return false;

   info.trigTime = iTime(_Symbol, tfG, sG);
   info.ema10 = EMA10Buffer[i];
   info.ema20 = EMA20Buffer[i];
   info.ema50 = EMA50Buffer[i];
   info.atr   = (i < ArraySize(gATR) ? gATR[i] : 0.0);
   info.adx   = gTF[kZ].adx[sZ];
   info.vwap  = (gMode[m].useVWAP ? VWAPFromChart(i, time, high, low, close, tick_volume) : 0.0);

   double eT10 = gTF[kT].e10[sT], eT20 = gTF[kT].e20[sT], eT50 = gTF[kT].e50[sT];
   double eZ10 = gTF[kZ].e10[sZ], eZ20 = gTF[kZ].e20[sZ], eZ50 = gTF[kZ].e50[sZ];
   double eG10 = gTF[kG].e10[sG], eG20 = gTF[kG].e20[sG];

   info.rsiT = gTF[kT].rsi[sT];
   info.rsiZ = gTF[kZ].rsi[sZ];
   info.rsiG = gTF[kG].rsi[sG];

   double closeT = iClose(_Symbol, tfT, sT);
   double closeZ = iClose(_Symbol, tfZ, sZ);
   double highZ  = iHigh(_Symbol,  tfZ, sZ);
   double lowZ   = iLow(_Symbol,   tfZ, sZ);
   double openZ  = iOpen(_Symbol,  tfZ, sZ);
   double closeG = iClose(_Symbol, tfG, sG);
   double highG  = iHigh(_Symbol,  tfG, sG);
   double lowG   = iLow(_Symbol,   tfG, sG);
   double openG  = iOpen(_Symbol,  tfG, sG);
   double atrZ   = gTF[kZ].atr[sZ];
   if(atrZ <= 0.0)
      atrZ = info.atr;
   info.atrZ = atrZ;

   PivotAt(gMode[m].pivotTF, barTime, info.pivot, info.r1, info.s1);

   double tfRatio = MathMax(1.0, (double)PeriodSeconds(tfT) / (double)PeriodSeconds(tfZ));
   double minSepT = (atrZ > 0.0 ? atrZ * InpMinEMASpreadATR * MathSqrt(tfRatio) : 0.0);
   double minSepZ = (atrZ > 0.0 ? atrZ * InpMinEMASpreadATR : 0.0);

   // ---- Tendance (UT tendance)
   bool stackUpT = eT10 > eT20 && eT20 > eT50 && closeT > eT50 && (eT10 - eT50) >= minSepT;
   bool stackDnT = eT10 < eT20 && eT20 < eT50 && closeT < eT50 && (eT50 - eT10) >= minSepT;

   int structT = StructureDir(tfT, sT, InpSwingLookbackTrend);
   bool vwapUp = (info.vwap <= 0.0 || closeT >= info.vwap);
   bool vwapDn = (info.vwap <= 0.0 || closeT <= info.vwap);

   if(stackUpT && structT >= 0 && vwapUp)      info.tT = 1;
   else if(stackDnT && structT <= 0 && vwapDn) info.tT = -1;
   else if(stackUpT && structT >= 0)           info.tT = 1;
   else if(stackDnT && structT <= 0)           info.tT = -1;
   else                                        info.tT = 0;

   // ---- UT zone
   if(eZ10 > eZ20 && eZ20 > eZ50 && closeZ > eZ50 && (eZ10 - eZ50) >= minSepZ)
      info.tZ = 1;
   else if(eZ10 < eZ20 && eZ20 < eZ50 && closeZ < eZ50 && (eZ50 - eZ10) >= minSepZ)
      info.tZ = -1;
   else if(eZ20 > eZ50 && closeZ > eZ50)
      info.tZ = 1;
   else if(eZ20 < eZ50 && closeZ < eZ50)
      info.tZ = -1;
   else
      info.tZ = 0;

   // ---- UT declencheur
   if(eG10 > eG20 && closeG > eG20)      info.tG = 1;
   else if(eG10 < eG20 && closeG < eG20) info.tG = -1;
   else                                  info.tG = 0;

   // ---- UT biais
   info.tB = 0;
   if(sB >= 1 && sB < ArraySize(gTF[kB].e20) && sB < ArraySize(gTF[kB].e50))
   {
      if(gTF[kB].e20[sB] > gTF[kB].e50[sB]) info.tB = 1;
      if(gTF[kB].e20[sB] < gTF[kB].e50[sB]) info.tB = -1;
   }

   // ---- Supports / resistances (UT zone)
   double zone   = MathMax(PointsToPrice(InpSRZonePoints), atrZ * InpZoneATR);
   double swingL = LastSwingLow(tfZ,  sZ + 1, InpSwingLookbackZone);
   double swingH = LastSwingHigh(tfZ, sZ + 1, InpSwingLookbackZone);
   double recL   = RecentExtreme(tfZ, sZ + 1, InpSRLookback, false);
   double recH   = RecentExtreme(tfZ, sZ + 1, InpSRLookback, true);

   double sup = 0.0, supDist = DBL_MAX;
   double candsS[16];
   int ns = 0;
   if(swingL > 0.0) candsS[ns++] = swingL;
   if(recL > 0.0)   candsS[ns++] = recL;
   if(info.s1 > 0.0) candsS[ns++] = info.s1;
   if(info.pivot > 0.0 && info.pivot < closeZ) candsS[ns++] = info.pivot;
   if(info.vwap > 0.0 && info.vwap < closeZ) candsS[ns++] = info.vwap;
   AddKeyCandidates(m, barTime, closeZ, candsS, ns);   // PDH/PDL, PWH/PWL, niveaux ronds
   for(int k = 0; k < ns; k++)
   {
      if(candsS[k] >= closeZ) continue;
      double d = closeZ - candsS[k];
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
   double candsR[16];
   int nr = 0;
   if(swingH > 0.0) candsR[nr++] = swingH;
   if(recH > 0.0)   candsR[nr++] = recH;
   if(info.r1 > 0.0) candsR[nr++] = info.r1;
   if(info.pivot > 0.0 && info.pivot > closeZ) candsR[nr++] = info.pivot;
   if(info.vwap > 0.0 && info.vwap > closeZ) candsR[nr++] = info.vwap;
   AddKeyCandidates(m, barTime, closeZ, candsR, nr);
   for(int k = 0; k < nr; k++)
   {
      if(candsR[k] <= closeZ) continue;
      double d = candsR[k] - closeZ;
      if(d < resDist) { resDist = d; res = candsR[k]; }
   }
   if(res > 0.0)
   {
      info.resist.price = res;
      info.resist.lo = res - zone * 0.5;
      info.resist.hi = res + zone * 0.5;
      info.resist.valid = true;
   }

   // ---- Price action (UT declencheur)
   double o = openG, h = highG, l = lowG, c = closeG;
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

   double po = iOpen(_Symbol, tfG, sG + 1);
   double pc = iClose(_Symbol, tfG, sG + 1);
   double prevBody = MathAbs(pc - po);
   if(prevBody > 0.0 && body > prevBody)
   {
      engulfBuy  = (pc < po) && (c > o) && (o <= pc) && (c >= po);
      engulfSell = (pc > po) && (c < o) && (o >= pc) && (c <= po);
   }

   double swHG = LastSwingHigh(tfG, sG + 1, InpSwingLookbackTrig);
   double swLG = LastSwingLow(tfG,  sG + 1, InpSwingLookbackTrig);
   double bos  = (atrZ > 0.0 ? atrZ * InpBOSBufferATR : PointsToPrice(5));
   bool breakHigh = (swHG > 0.0 && c > swHG + bos);
   bool breakLow  = (swLG > 0.0 && c < swLG - bos);

   double shA, shB, slA, slB;
   bool hl = false, lh = false;
   if(LastTwoSwings(tfG, sG, InpSwingLookbackTrig, shA, shB, slA, slB))
   {
      hl = (slA > slB);
      lh = (shA < shB);
   }

   bool hhhl = (structT > 0);
   bool lhll = (structT < 0);

   // ---- Bollinger (UT zone)
   double bbMid = gTF[kZ].bbMid[sZ];
   double bbUp  = gTF[kZ].bbUp[sZ];
   double bbLo  = gTF[kZ].bbLo[sZ];
   bool bbBuy = false, bbSell = false;
   if(bbUp > bbLo && bbLo > 0.0)
   {
      double w = bbUp - bbLo;
      bbBuy  = (lowZ <= bbLo + w * 0.08) && (closeZ > bbLo) && (closeZ > openZ) && (closeZ < bbMid + w * 0.15);
      bbSell = (highZ >= bbUp - w * 0.08) && (closeZ < bbUp) && (closeZ < openZ) && (closeZ > bbMid - w * 0.15);
   }

   // ---- Cassure + retest (UT zone)
   double bosZ = (atrZ > 0.0 ? atrZ * InpBOSBufferATR : PointsToPrice(8));
   datetime tZopen = iTime(_Symbol, tfZ, sZ);
   bool breakoutBuy = false, breakoutSell = false;
   bool retestBuy = false, retestSell = false;

   if(info.resist.valid && closeZ > info.resist.hi + bosZ)
   {
      breakoutBuy = true;
      gBO[m].dir = 1;
      gBO[m].level = info.resist.price;
      gBO[m].breakTime = tZopen;
   }
   if(info.support.valid && closeZ < info.support.lo - bosZ)
   {
      breakoutSell = true;
      gBO[m].dir = -1;
      gBO[m].level = info.support.price;
      gBO[m].breakTime = tZopen;
   }
   if(gBO[m].dir != 0 && gBO[m].breakTime > 0)
   {
      // Age mesure depuis la bougie evaluee (et non depuis maintenant)
      int age = iBarShift(_Symbol, tfZ, gBO[m].breakTime, false) - sZ;
      if(age < 0 || age > InpRetestMaxBars + 8)
      {
         gBO[m].dir = 0;
         gBO[m].level = 0.0;
         gBO[m].breakTime = 0;
      }
      else if(age >= 1 && age <= InpRetestMaxBars)
      {
         bool touched = (lowZ <= gBO[m].level + zone * 0.5 && highZ >= gBO[m].level - zone * 0.5);
         if(touched && gBO[m].dir == 1 && closeZ >= gBO[m].level && (rejBuy || closeZ > openZ))
         {
            retestBuy = true;
            breakoutBuy = true;
         }
         if(touched && gBO[m].dir == -1 && closeZ <= gBO[m].level && (rejSell || closeZ < openZ))
         {
            retestSell = true;
            breakoutSell = true;
         }
      }
   }

   // ---- Pullback (UT zone)
   double tol = (atrZ > 0.0 ? atrZ * InpPullbackATR : PointsToPrice(30));
   bool nearEma  = Near(closeZ, eZ10, tol) || Near(closeZ, eZ20, tol) || Near(closeZ, eZ50, tol);
   bool nearVWAP = Near(closeZ, info.vwap, tol);
   bool nearBB   = Near(closeZ, bbMid, tol) || Near(closeZ, bbLo, tol) || Near(closeZ, bbUp, tol);

   bool pullBuy =
      info.tT > 0 &&
      (nearEma || PriceInZone(lowZ, info.support) || nearVWAP || nearBB) &&
      (closeZ > eZ50 || closeZ > eZ20);
   bool pullSell =
      info.tT < 0 &&
      (nearEma || PriceInZone(highZ, info.resist) || nearVWAP || nearBB) &&
      (closeZ < eZ50 || closeZ < eZ20);

   bool extended = (InpAvoidExtended && atrZ > 0.0 && (highZ - lowZ) > atrZ * InpMaxCandleATR);

   // ---- Score de confluence
   info.maxScore = ScoreMax();
   info.scoreBuy = 0;
   info.scoreSell = 0;

   if(info.tT > 0)                           info.scoreBuy  += 2;
   if(eZ10 > eZ20)                           info.scoreBuy  += 1;
   if(eZ20 > eZ50)                           info.scoreBuy  += 1;
   if(info.vwap > 0.0 && closeG > info.vwap) info.scoreBuy  += 1;
   if(info.rsiG > 50.0 && info.rsiZ >= 48.0) info.scoreBuy  += 1;
   if(info.support.valid && (PriceInZone(lowG, info.support) || PriceInZone(lowZ, info.support)))
                                             info.scoreBuy  += 2;
   if(rejBuy || hammer || engulfBuy)         info.scoreBuy  += 2;
   if(breakoutBuy)                           info.scoreBuy  += 2;
   if(retestBuy)                             info.scoreBuy  += 2;
   if(bbBuy)                                 info.scoreBuy  += 1;
   if(hhhl || hl)                            info.scoreBuy  += 1;

   if(info.tT < 0)                           info.scoreSell += 2;
   if(eZ10 < eZ20)                           info.scoreSell += 1;
   if(eZ20 < eZ50)                           info.scoreSell += 1;
   if(info.vwap > 0.0 && closeG < info.vwap) info.scoreSell += 1;
   if(info.rsiG < 50.0 && info.rsiZ <= 52.0) info.scoreSell += 1;
   if(info.resist.valid && (PriceInZone(highG, info.resist) || PriceInZone(highZ, info.resist)))
                                             info.scoreSell += 2;
   if(rejSell || shooting || engulfSell)     info.scoreSell += 2;
   if(breakoutSell)                          info.scoreSell += 2;
   if(retestSell)                            info.scoreSell += 2;
   if(bbSell)                                info.scoreSell += 1;
   if(lhll || lh)                            info.scoreSell += 1;

   // ---- Filtres
   info.sessionOk = (!gMode[m].useSession || InSession(barTime));
   info.spreadPts = (i < ArraySize(spread) ? (long)spread[i] : SymbolInfoInteger(_Symbol, SYMBOL_SPREAD));
   if(info.spreadPts <= 0)
      info.spreadPts = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   info.spreadOk = (InpMaxSpreadPoints <= 0 || info.spreadPts <= InpMaxSpreadPoints * gMode[m].spreadMult);
   info.adxOk = (!InpUseADX || info.adx >= InpADXMin);

   bool biasOkBuy  = (!InpUseBias || info.tB >= 0);
   bool biasOkSell = (!InpUseBias || info.tB <= 0);

   bool paBuy  = rejBuy || hammer || engulfBuy || breakHigh || hl || retestBuy;
   bool paSell = rejSell || shooting || engulfSell || breakLow || lh || retestSell;
   bool emaGBuy  = (eG10 >= eG20 || closeG > eG20);
   bool emaGSell = (eG10 <= eG20 || closeG < eG20);

   // Bougie de declenchement cloturee dans le sens du trade
   bool trigBuy  = (!InpRequireTriggerClose || hammer   || engulfBuy  || (range > 0.0 && c > o && c >= l + range * 0.5));
   bool trigSell = (!InpRequireTriggerClose || shooting || engulfSell || (range > 0.0 && c < o && c <= h - range * 0.5));

   bool zoneBuy  = (pullBuy  || retestBuy  || breakoutBuy);
   bool zoneSell = (pullSell || retestSell || breakoutSell);

   // Anti-chase : pas de BUY en surachat ni de SELL en survente sur l'UT zone
   bool rsiOkBuy  = (InpRSIOverbought <= 0.0 || info.rsiZ < InpRSIOverbought);
   bool rsiOkSell = (InpRSIOversold   <= 0.0 || info.rsiZ > InpRSIOversold);

   bool sigBuy  = (info.tT > 0 && info.tZ >= 0 && info.scoreBuy >= InpMinScore &&
                   paBuy && emaGBuy && info.rsiG >= 48.0 && zoneBuy);
   bool sigSell = (info.tT < 0 && info.tZ <= 0 && info.scoreSell >= InpMinScore &&
                   paSell && emaGSell && info.rsiG <= 52.0 && zoneSell);

   int signal = 0;
   if(sigBuy && !sigSell)      signal = 1;
   else if(sigSell && !sigBuy) signal = -1;

   // Direction candidate : utilisee pour la checklist et le plan meme en attente
   int cdir = signal;
   if(cdir == 0) cdir = info.tT;
   if(cdir == 0) cdir = (info.scoreBuy > info.scoreSell ? 1 : (info.scoreSell > info.scoreBuy ? -1 : 0));
   info.cdir = cdir;

   // ---- Niveaux
   info.entry = close[i];
   double buffer  = MathMax(PointsToPrice(InpSLBufferPoints), atrZ * 0.08);
   double minRisk = (atrZ > 0.0 ? atrZ * InpMinSLATR : 0.0);
   info.capped = false;
   if(cdir > 0)
   {
      info.sl = info.entry;
      if(swLG > 0.0) info.sl = MathMin(info.sl, swLG);
      if(info.support.valid) info.sl = MathMin(info.sl, info.support.lo);
      info.sl = MathMin(info.sl, lowG);
      if(info.sl >= info.entry)
         info.sl = info.entry - atrZ * InpSLATRMult;
      info.sl -= buffer;
      if(info.entry - info.sl < minRisk)
         info.sl = info.entry - minRisk;
      info.tp = info.entry + (info.entry - info.sl) * InpRRRatio;
      // TP plafonne juste avant la prochaine resistance
      if(InpCapTPAtLevel && info.resist.valid && info.resist.price > info.entry && info.resist.lo < info.tp)
      {
         info.tp = MathMax(info.entry, info.resist.lo);
         info.capped = true;
      }
   }
   else if(cdir < 0)
   {
      info.sl = info.entry;
      if(swHG > 0.0) info.sl = MathMax(info.sl, swHG);
      if(info.resist.valid) info.sl = MathMax(info.sl, info.resist.hi);
      info.sl = MathMax(info.sl, highG);
      if(info.sl <= info.entry)
         info.sl = info.entry + atrZ * InpSLATRMult;
      info.sl += buffer;
      if(info.sl - info.entry < minRisk)
         info.sl = info.entry + minRisk;
      info.tp = info.entry - (info.sl - info.entry) * InpRRRatio;
      // TP plafonne juste avant le prochain support
      if(InpCapTPAtLevel && info.support.valid && info.support.price < info.entry && info.support.hi > info.tp)
      {
         info.tp = MathMin(info.entry, info.support.hi);
         info.capped = true;
      }
   }

   info.sl = NormalizePrice(info.sl);
   info.tp = NormalizePrice(info.tp);
   double risk = MathAbs(info.entry - info.sl);
   double rew  = MathAbs(info.tp - info.entry);
   info.rr   = (risk > 0.0 ? rew / risk : 0.0);
   info.rrOk = (cdir != 0 && info.rr + 1e-8 >= InpMinRR);
   info.slOk = (cdir != 0 && risk > 0.0 && (atrZ <= 0.0 || InpMaxSLATR <= 0.0 || risk <= atrZ * InpMaxSLATR));

   // ---- Note de qualite
   int sc = (cdir > 0 ? info.scoreBuy : (cdir < 0 ? info.scoreSell : 0));
   bool strongPA = (cdir > 0 ? (hammer || engulfBuy || retestBuy) : (cdir < 0 ? (shooting || engulfSell || retestSell) : false));
   bool inZone =
      (cdir > 0 ? (retestBuy  || PriceInZone(lowG,  info.support) || PriceInZone(lowZ,  info.support)) :
      (cdir < 0 ? (retestSell || PriceInZone(highG, info.resist)  || PriceInZone(highZ, info.resist)) : false));
   int q = 0;
   if(sc >= InpMinScore + 3)              q++;
   if(cdir != 0 && info.tB == cdir)       q++;
   if(strongPA)                           q++;
   if(inZone)                             q++;
   if(info.adx >= InpADXMin + 7.0)        q++;
   if(info.rr >= 2.0)                     q++;
   info.grade = (cdir == 0 ? 0 : (q >= 4 ? 3 : (q >= 2 ? 2 : 1)));

   // ---- Type d'entree
   //  BREAKOUT + RETEST : niveau casse puis reteste
   //  BREAKOUT          : cassure fraiche d'un S/R de l'UT zone
   //  MEAN REVERSION    : prix etire (bande de Bollinger, loin du VWAP, RSI extreme) qui revient vers la moyenne
   //  TREND-FOLLOWING   : pullback (EMA / support) dans le sens de la tendance
   info.setup = SETUP_NONE;
   if(cdir > 0)
   {
      bool stretched = bbBuy || (info.vwap > 0.0 && atrZ > 0.0 && closeZ < info.vwap - atrZ * 1.2) || info.rsiZ < 35.0;
      if(retestBuy)        info.setup = SETUP_RETEST;
      else if(breakoutBuy) info.setup = SETUP_BREAKOUT;
      else if(stretched)   info.setup = SETUP_MEANREV;
      else                 info.setup = SETUP_TREND;
   }
   else if(cdir < 0)
   {
      bool stretched = bbSell || (info.vwap > 0.0 && atrZ > 0.0 && closeZ > info.vwap + atrZ * 1.2) || info.rsiZ > 65.0;
      if(retestSell)        info.setup = SETUP_RETEST;
      else if(breakoutSell) info.setup = SETUP_BREAKOUT;
      else if(stretched)    info.setup = SETUP_MEANREV;
      else                  info.setup = SETUP_TREND;
   }

   // ---- Checklist (direction candidate)
   info.chkTrend   = (cdir != 0 && info.tT == cdir && info.tZ * cdir >= 0);
   info.chkZone    = (cdir > 0 ? zoneBuy : (cdir < 0 ? zoneSell : false));
   info.chkTrigger = (cdir > 0 ? (paBuy && emaGBuy && trigBuy) : (cdir < 0 ? (paSell && emaGSell && trigSell) : false));
   info.chkScore   = (cdir != 0 && sc >= InpMinScore);
   info.chkBias    = (cdir > 0 ? biasOkBuy : (cdir < 0 ? biasOkSell : false));
   info.chkRSI     = (cdir > 0 ? rsiOkBuy : (cdir < 0 ? rsiOkSell : false));
   info.chkRR      = (info.rrOk && info.slOk);

   string nT = TFName(tfT), nZ = TFName(tfZ), nG = TFName(tfG), nB = TFName(gTF[kB].tf);
   string block = "";
   if(signal != 0)
   {
      if(!info.sessionOk)                    block = "Hors session";
      else if(!info.spreadOk)                block = "Spread trop eleve";
      else if(!info.adxOk)                   block = "Marche trop plat (ADX " + nZ + ")";
      else if(extended)                      block = "Bougie " + nZ + " trop etendue — ne pas chasser";
      else if(signal > 0 && !biasOkBuy)      block = nB + " contraire au BUY";
      else if(signal < 0 && !biasOkSell)     block = nB + " contraire au SELL";
      else if(signal > 0 && !rsiOkBuy)       block = "RSI " + nZ + " en surachat — BUY trop tardif";
      else if(signal < 0 && !rsiOkSell)      block = "RSI " + nZ + " en survente — SELL trop tardif";
      else if(signal > 0 && !trigBuy)        block = "Bougie " + nG + " pas cloturee haussiere";
      else if(signal < 0 && !trigSell)       block = "Bougie " + nG + " pas cloturee baissiere";
      else if(!info.slOk)                    block = "SL trop large (> " + DoubleToString(InpMaxSLATR, 1) + " ATR)";
      else if(!info.rrOk)
         block = (info.capped ? (signal > 0 ? "Resistance trop proche — pas de place" : "Support trop proche — pas de place")
                              : "RR insuffisant");
      else if(info.grade < (int)InpMinQuality)
         block = "Qualite " + GradeText(info.grade) + " < mini " + GradeText((int)InpMinQuality);
   }
   else if(sigBuy && sigSell)
      block = "Signaux contradictoires";

   if(block != "")
   {
      info.reason = block;
      signal = 0;
   }

   info.dir = signal;

   if(signal > 0)
   {
      info.action = "BUY";
      info.reason = nT + " haussier + zone " + nZ + " + declencheur " + nG;
   }
   else if(signal < 0)
   {
      info.action = "SELL";
      info.reason = nT + " baissier + zone " + nZ + " + declencheur " + nG;
   }
   else
   {
      info.action = "WAIT";
      if(StringLen(info.reason) == 0 || info.reason == "Analyse...")
      {
         if(info.tT == 0)
            info.reason = nT + " neutre — ne pas trader";
         else if(info.tT * info.tZ < 0)
            info.reason = nZ + " contraire a " + nT;
         else if(info.tT > 0 && info.scoreBuy < InpMinScore)
            info.reason = "Score BUY trop faible (" + IntegerToString(info.scoreBuy) + "/" + IntegerToString(InpMinScore) + ")";
         else if(info.tT < 0 && info.scoreSell < InpMinScore)
            info.reason = "Score SELL trop faible (" + IntegerToString(info.scoreSell) + "/" + IntegerToString(InpMinScore) + ")";
         else if(info.tT > 0 && !zoneBuy)
            info.reason = "Attendre un pullback / retest " + nZ;
         else if(info.tT < 0 && !zoneSell)
            info.reason = "Attendre un pullback / retest " + nZ;
         else
            info.reason = "Attendre la confirmation " + nG;
      }
   }

   return true;
}

//==================================================================//
// SIGNAUX : HISTORIQUE / RESULTATS
//==================================================================//

int LastSigIdx(const int m)
{
   for(int k = gSigCount - 1; k >= 0; k--)
      if(gSigs[k].mode == m)
         return k;
   return -1;
}

void ModeStats(const int m, int &n, int &wins, int &losses, double &netR)
{
   n = 0; wins = 0; losses = 0; netR = 0.0;
   for(int k = 0; k < gSigCount; k++)
   {
      if(gSigs[k].mode != m)
         continue;
      n++;
      double risk = MathAbs(gSigs[k].entry - gSigs[k].sl);
      double rew  = MathAbs(gSigs[k].tp - gSigs[k].entry);
      if(gSigs[k].result > 0)      { wins++;   if(risk > 0.0) netR += rew / risk; }
      else if(gSigs[k].result < 0) { losses++; netR -= 1.0; }
   }
}

// 0 = pas de signal ouvert, 1 = actif (entree possible), 2 = trop tard (prix deja parti), 3 = en cours (vieux)
int SignalState(const int m, int &idx)
{
   idx = LastSigIdx(m);
   if(idx < 0 || gSigs[idx].result != 0)
      return 0;

   long age = (long)(TimeCurrent() - (gSigs[idx].time + PeriodSeconds(_Period)));
   if(age > (long)InpSignalValidBars * PeriodSeconds(TrigTF(m)))
      return 3;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double way = MathAbs(gSigs[idx].tp - gSigs[idx].entry);
   double run = (bid - gSigs[idx].entry) * gSigs[idx].dir;
   if(gSigs[idx].late || (way > 0.0 && run > way * 0.5))
   {
      gSigs[idx].late = true;      // une fois "trop tard", reste "trop tard"
      return 2;
   }
   return 1;
}

//==================================================================//
// CONSEILLER : QUEL MODE DE TRADING MAINTENANT ?
//==================================================================//

// ATR de la derniere bougie cloturee / moyenne des 50 precedentes
double ATRRatio(const int k)
{
   int n = ArraySize(gTF[k].atr);
   if(!gTF[k].ready || n < 12)
      return 1.0;
   int cnt = MathMin(50, n - 2);
   double sum = 0.0;
   for(int j = 2; j < 2 + cnt; j++)
      sum += gTF[k].atr[j];
   double avg = sum / cnt;
   return (avg > 0.0 ? gTF[k].atr[1] / avg : 1.0);
}

void AddReason(string &dst, const string txt)
{
   if(StringLen(dst) == 0)
      dst = txt;
}

void ComputeAdvice()
{
   // Une seule mise a jour par minute : le conseil ne doit pas sauter a chaque tick
   datetime m1 = iTime(_Symbol, PERIOD_M1, 0);
   if(gAdviceInit && m1 == gAdviceBar)
      return;
   gAdviceBar = m1;
   int best = -1;
   double spreadPrice = PointsToPrice((double)gSpreadNow);

   for(int m = 0; m < NMODES; m++)
   {
      gAdvice[m].score = 0;
      gAdvice[m].plus  = "";
      gAdvice[m].minus = "";
      if(!ModeReady(m))
      {
         gAdvice[m].minus = (gMode[m].enabled ? "chargement des donnees" : "desactive");
         continue;
      }

      SetupInfo s = gClosed[m];
      string nT = TFName(gTF[gMode[m].kTrend].tf);
      string nB = TFName(gTF[gMode[m].kBias].tf);
      int sc = 0;

      // Tendance
      if(s.tT != 0)
      {
         sc += 30;
         AddReason(gAdvice[m].plus, "tendance " + nT + " nette");
         if(s.tB == s.tT) sc += 15;
         else AddReason(gAdvice[m].minus, nB + " pas aligne");
         if(s.tZ == s.tT) sc += 10;
      }
      else
         AddReason(gAdvice[m].minus, "tendance " + nT + " floue");

      // Force (ADX de l'UT zone)
      if(s.adx >= InpADXMin)
      {
         sc += 15;
         if(s.adx >= InpADXMin + 7.0)
         {
            sc += 5;
            AddReason(gAdvice[m].plus, "ADX fort (" + DoubleToString(s.adx, 0) + ")");
         }
      }
      else
         AddReason(gAdvice[m].minus, "range (ADX " + DoubleToString(s.adx, 0) + ")");

      // Cout : spread compare a l'ATR de l'UT declencheur
      int kG = gMode[m].kTrig;
      double atrG = (ArraySize(gTF[kG].atr) > 1 ? gTF[kG].atr[1] : 0.0);
      double cost = (atrG > 0.0 ? spreadPrice / atrG : 1.0);
      if(cost <= 0.08)
      {
         sc += 15;
         AddReason(gAdvice[m].plus, "spread faible");
      }
      else if(cost <= 0.15)
         sc += 5;
      else
      {
         sc -= 20;
         AddReason(gAdvice[m].minus, "spread trop cher (" + DoubleToString(cost * 100.0, 0) + "% ATR)");
      }

      // Volatilite (UT zone) : le scalping a besoin d'un marche ni mort ni en panique
      double vr = ATRRatio(gMode[m].kZone);
      if(m == MODE_SCALP)
      {
         if(vr < 0.7)      { sc -= 15; AddReason(gAdvice[m].minus, "marche trop calme"); }
         else if(vr > 2.2) { sc -= 25; AddReason(gAdvice[m].minus, "volatilite extreme (news ?)"); }
         else              { sc += 10; AddReason(gAdvice[m].plus, "volatilite saine"); }
      }
      else
      {
         if(vr > 2.5) { sc -= 10; AddReason(gAdvice[m].minus, "volatilite extreme"); }
         else           sc += 10;
      }

      // Session
      if(gMode[m].useSession && !InSession(TimeCurrent()))
      {
         sc -= 30;
         gAdvice[m].minus = "hors session";
      }

      // Resultats recents du mode sur l'historique affiche
      int n, w, l;
      double netR;
      ModeStats(m, n, w, l, netR);
      if(w + l >= 5)
      {
         if(netR > 0.0) { sc += 5; AddReason(gAdvice[m].plus, "historique positif"); }
         else           { sc -= 10; AddReason(gAdvice[m].minus, "historique negatif"); }
      }

      gAdvice[m].score = (int)MathMax(0, MathMin(100, sc));

      // A egalite, on prefere le mode le plus lent (moins de bruit, moins de frais)
      if(best < 0 || gAdvice[m].score >= gAdvice[best].score)
         best = m;
   }

   int raw = (best >= 0 && gAdvice[best].score >= InpAdviceMinScore ? best : -1);

   if(!gAdviceInit)
   {
      gRecommended = raw;
      gAdviceInit  = true;
   }
   else if(raw != gRecommended)
   {
      // Hysteresis : le nouveau mode doit etre nettement meilleur...
      bool stronger;
      if(gRecommended < 0)
         stronger = true;
      else if(raw < 0)
         stronger = (gAdvice[gRecommended].score < InpAdviceMinScore - 5);
      else
         stronger = (gAdvice[raw].score >= gAdvice[gRecommended].score + InpAdviceHysteresis);

      // ...et le rester plusieurs minutes d'affilee
      if(!stronger)                { gPendingRec = -2;  gPendingCount = 0; }
      else if(raw == gPendingRec)  gPendingCount++;
      else                         { gPendingRec = raw; gPendingCount = 1; }

      if(gPendingCount >= MathMax(1, InpAdviceConfirmBars))
      {
         gRecommended  = raw;
         gPendingRec   = -2;
         gPendingCount = 0;
      }
   }
   else
   {
      gPendingRec   = -2;
      gPendingCount = 0;
   }

   if(InpTradeMode == TM_SCALPING)      { gFocus = MODE_SCALP; return; }
   if(InpTradeMode == TM_INTRADAY)      { gFocus = MODE_INTRA; return; }
   if(InpTradeMode == TM_SWING)         { gFocus = MODE_SWING; return; }

   // AUTO : on ne quitte pas un mode qui a un signal actif ou un trade en cours
   int idx;
   int st = SignalState(gFocus, idx);
   if(ModeReady(gFocus) && (st == 1 || st == 3))
      return;
   if(gRecommended >= 0)                gFocus = gRecommended;
   else if(!ModeReady(gFocus) && best >= 0) gFocus = best;
}

//==================================================================//
// THEME / HELPERS PANNEAU
//==================================================================//

color gC_bg, gC_card, gC_border, gC_text, gC_dim, gC_track;
color gC_green, gC_red, gC_amber, gC_blue, gC_gold;

void SetTheme()
{
   if(InpTheme == THEME_LIGHT)
   {
      gC_bg     = C'248,246,241';
      gC_card   = C'255,255,255';
      gC_border = C'218,212,200';
      gC_text   = C'35,35,40';
      gC_dim    = C'120,118,110';
      gC_track  = C'232,228,220';
      gC_green  = C'22,140,70';
      gC_red    = C'200,50,45';
      gC_amber  = C'205,135,10';
      gC_blue   = C'40,100,220';
      gC_gold   = C'165,125,20';
   }
   else
   {
      gC_bg     = C'21,25,32';
      gC_card   = C'29,34,43';
      gC_border = C'50,57,70';
      gC_text   = C'228,232,238';
      gC_dim    = C'138,146,160';
      gC_track  = C'44,50,62';
      gC_green  = C'38,166,91';
      gC_red    = C'226,75,74';
      gC_amber  = C'232,165,35';
      gC_blue   = C'70,145,255';
      gC_gold   = C'214,178,70';
   }
}

//==================================================================//
// THEME DU GRAPHIQUE (pre-installe)
//==================================================================//

#define NCHART_PROPS 17

ENUM_CHART_PROPERTY_INTEGER gChartProps[NCHART_PROPS] =
{
   CHART_COLOR_BACKGROUND, CHART_COLOR_FOREGROUND, CHART_COLOR_GRID,
   CHART_COLOR_CHART_UP, CHART_COLOR_CHART_DOWN, CHART_COLOR_CANDLE_BULL, CHART_COLOR_CANDLE_BEAR,
   CHART_COLOR_CHART_LINE, CHART_COLOR_VOLUME, CHART_COLOR_BID, CHART_COLOR_ASK,
   CHART_COLOR_LAST, CHART_COLOR_STOP_LEVEL,
   CHART_MODE, CHART_SHOW_GRID, CHART_SHOW_PERIOD_SEP, CHART_SHIFT
};
long gChartSaved[NCHART_PROPS];
bool gChartThemed = false;

void SetChartProp(const ENUM_CHART_PROPERTY_INTEGER prop, const long value)
{
   ChartSetInteger(0, prop, value);
}

void ApplyChartTheme()
{
   if(InpChartTheme == CHART_THEME_NONE || gChartThemed)
      return;

   for(int k = 0; k < NCHART_PROPS; k++)
      gChartSaved[k] = ChartGetInteger(0, gChartProps[k]);
   gChartThemed = true;

   // Gold Night : fond nuit, bougies vert / rouge du panneau, accents or
   SetChartProp(CHART_COLOR_BACKGROUND,  C'16,19,25');
   SetChartProp(CHART_COLOR_FOREGROUND,  C'138,146,160');
   SetChartProp(CHART_COLOR_GRID,        C'34,39,49');
   SetChartProp(CHART_COLOR_CHART_UP,    C'38,166,91');
   SetChartProp(CHART_COLOR_CHART_DOWN,  C'226,75,74');
   SetChartProp(CHART_COLOR_CANDLE_BULL, C'38,166,91');
   SetChartProp(CHART_COLOR_CANDLE_BEAR, C'226,75,74');
   SetChartProp(CHART_COLOR_CHART_LINE,  C'214,178,70');
   SetChartProp(CHART_COLOR_VOLUME,      C'70,80,96');
   SetChartProp(CHART_COLOR_BID,         C'214,178,70');
   SetChartProp(CHART_COLOR_ASK,         C'110,118,132');
   SetChartProp(CHART_COLOR_LAST,        C'214,178,70');
   SetChartProp(CHART_COLOR_STOP_LEVEL,  C'226,75,74');
   SetChartProp(CHART_MODE,              CHART_CANDLES);
   SetChartProp(CHART_SHOW_GRID,         true);
   SetChartProp(CHART_SHOW_PERIOD_SEP,   false);
   SetChartProp(CHART_SHIFT,             true);    // marge a droite pour les niveaux TP/SL
}

// Remet les couleurs d'origine. Appele a chaque deinit (changement de TF / parametres inclus)
// pour que le prochain OnInit sauvegarde toujours les vraies couleurs de l'utilisateur.
void RestoreChartTheme()
{
   if(!gChartThemed || !InpRestoreChartTheme)
      return;
   for(int k = 0; k < NCHART_PROPS; k++)
      ChartSetInteger(0, gChartProps[k], gChartSaved[k]);
   gChartThemed = false;
}

// Melange de 2 couleurs (t = 0 -> a, t = 1 -> b). Format MQL : 0x00BBGGRR
color Mix(const color a, const color b, const double t)
{
   int ar = (int)(a & 0xFF), ag = (int)((a >> 8) & 0xFF), ab = (int)((a >> 16) & 0xFF);
   int br = (int)(b & 0xFF), bg = (int)((b >> 8) & 0xFF), bb = (int)((b >> 16) & 0xFF);
   int r  = (int)MathRound(ar + (br - ar) * t);
   int g  = (int)MathRound(ag + (bg - ag) * t);
   int bl = (int)MathRound(ab + (bb - ab) * t);
   return (color)(r | (g << 8) | (bl << 16));
}

int Px(const double v) { return (int)MathRound(v * gS); }

int FS(const int pt)
{
   double sc = MathMax(0.6, MathMin(2.0, InpPanelScale)) * gFit;
   return (int)MathMax(6, MathRound(pt * sc));
}

color DirClr(const int d)
{
   if(d > 0) return gC_green;
   if(d < 0) return gC_red;
   return gC_amber;
}

void MarkDrawn(const string name)
{
   if(gDrawnCount >= ArraySize(gDrawn))
      ArrayResize(gDrawn, gDrawnCount + 64);
   gDrawn[gDrawnCount++] = name;
}

// Supprime les objets du panneau dessines a la passe precedente mais plus a celle-ci.
// Compare deux petites listes (au lieu de parcourir tous les objets du graphique).
void PurgeStale()
{
   for(int k = 0; k < gPrevCount; k++)
   {
      if(k < gDrawnCount && gDrawn[k] == gPrev[k])
         continue;
      bool keep = false;
      for(int j = 0; j < gDrawnCount; j++)
         if(gDrawn[j] == gPrev[k]) { keep = true; break; }
      if(!keep)
         ObjectDelete(0, gPrev[k]);
   }
   if(ArraySize(gPrev) < gDrawnCount)
      ArrayResize(gPrev, gDrawnCount + 64);
   for(int k = 0; k < gDrawnCount; k++)
      gPrev[k] = gDrawn[k];
   gPrevCount = gDrawnCount;
}

// Cache par position de dessin : si l'objet n'a pas change depuis la passe precedente,
// on ne touche a rien (chaque ObjectSet* coute cher, surtout sous Wine / Mac)
bool CacheHit(const string sig)
{
   int k = gDrawnCount - 1;
   if(k >= ArraySize(gObjSig))
      ArrayResize(gObjSig, k + 64);
   if(gObjSig[k] == sig)
      return true;
   gObjSig[k] = sig;
   gObjUpdates++;
   return false;
}

void ResetPanelCache()
{
   ArrayResize(gObjSig, 0);
   gPrevCount = 0;
}

void DeleteObj(const string name)
{
   if(ObjectFind(0, name) >= 0)
      ObjectDelete(0, name);
}

void PRect(const string id, const int x, const int y, const int w, const int h, const color bg, const color bd)
{
   if(gDry) return;
   string name = PANEL_PREFIX + id;
   MarkDrawn(name);
   if(CacheHit(name + "|" + IntegerToString(Px(x)) + "|" + IntegerToString(Px(y)) + "|" + IntegerToString(Px(w)) + "|" +
               IntegerToString(Px(h)) + "|" + IntegerToString((int)bg) + "|" + IntegerToString((int)bd)))
      return;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpPanelX + Px(x));
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpPanelY + Px(y));
   ObjectSetInteger(0, name, OBJPROP_XSIZE, MathMax(1, Px(w)));
   ObjectSetInteger(0, name, OBJPROP_YSIZE, MathMax(1, Px(h)));
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, bd);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void PText(const string id, const string text, const int x, const int y, const int fs, const color clr,
           const string font, const ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
{
   if(gDry) return;
   string name = PANEL_PREFIX + id;
   MarkDrawn(name);
   if(CacheHit(name + "|" + text + "|" + IntegerToString(Px(x)) + "|" + IntegerToString(Px(y)) + "|" +
               IntegerToString(FS(fs)) + "|" + IntegerToString((int)clr) + "|" + font + "|" + IntegerToString((int)anchor)))
      return;
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpPanelX + Px(x));
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpPanelY + Px(y));
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FS(fs));
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void PIcon(const string id, const uchar code, const int x, const int y, const int fs, const color clr,
           const ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
{
   PText(id, CharToString(code), x, y, fs, clr, "Wingdings", anchor);
}

// Coupe le texte pour qu'il tienne dans maxW (unites du panneau)
string FitText(const string text, const string font, const int fs, const int maxW)
{
   if(gDry) return text;
   uint w = 0, h = 0;
   TextSetFont(font, -FS(fs) * 10);
   string t = text;
   TextGetSize(t, w, h);
   while((int)w > Px(maxW) && StringLen(t) > 4)
   {
      t = StringSubstr(t, 0, StringLen(t) - 4) + "...";
      TextGetSize(t, w, h);
   }
   return t;
}

int Section(const string id, const string title, const int y)
{
   int M = 12;
   PText(id, title, M, y, 7, gC_dim, InpFontBold);
   PRect(id + "_L", M, y + 16, PANEL_W - 2 * M, 1, gC_border, gC_border);
   return y + 24;
}

void Bar(const string id, const int x, const int y, const int w, const int h, const double frac, const color fill)
{
   PRect(id + "_T", x, y, w, h, gC_track, gC_track);
   PRect(id + "_F", x, y, (int)MathMax(1, MathRound(w * MathMax(0.0, MathMin(1.0, frac)))), h, fill, fill);
}

int Gauge(const string id, const string label, const int v, const int vmax, const color col, const int y)
{
   int M  = 12;
   int bx = M + 42;
   int bw = PANEL_W - 2 * M - 42 - 52;
   int bh = 8;
   int by = y + 5;
   bool ok = (v >= InpMinScore);

   PText(id + "_N", label, M, y, 8, (ok ? col : gC_text), InpFontBold);
   Bar(id, bx, by, bw, bh, (double)v / MathMax(1, vmax), (ok ? col : Mix(col, gC_track, 0.55)));
   int mx = bx + (int)MathRound(bw * (double)InpMinScore / MathMax(1, vmax));
   PRect(id + "_M", mx, by - 3, 2, bh + 6, gC_text, gC_text);
   PText(id + "_V", IntegerToString(v) + " / " + IntegerToString(vmax), PANEL_W - M, y,
         8, (ok ? col : gC_dim), InpFontBold, ANCHOR_RIGHT_UPPER);
   return y + 20;
}

void CheckItem(const string id, const string label, const bool ok, const int x, const int y)
{
   PIcon(id + "_I", (uchar)(ok ? 252 : 251), x, y, 9, (ok ? gC_green : gC_red));
   PText(id + "_T", label, x + 17, y + 1, 8, (ok ? gC_text : gC_dim), InpFont);
}

void KeyValue(const string id, const string key, const string val, const color vc, const int y)
{
   int M = 12;
   PText(id + "_K", key, M, y, 8, gC_dim, InpFont);
   PText(id + "_V", val, PANEL_W - M, y, 9, vc, InpFontBold, ANCHOR_RIGHT_UPPER);
}

string AgeText(const datetime sigBarTime)
{
   long sec = (long)(TimeCurrent() - (sigBarTime + PeriodSeconds(_Period)));
   if(sec < 60) return "< 1 min";
   if(sec < 3600) return IntegerToString(sec / 60) + " min";
   if(sec < 86400) return IntegerToString(sec / 3600) + " h " + IntegerToString((sec % 3600) / 60) + " min";
   return IntegerToString(sec / 86400) + " j " + IntegerToString((sec % 86400) / 3600) + " h";
}

string Countdown(const long sec)
{
   long s = (sec > 0 ? sec : 0);
   if(s >= 3600)
      return StringFormat("%d:%02d:%02d", (int)(s / 3600), (int)((s % 3600) / 60), (int)(s % 60));
   return StringFormat("%02d:%02d", (int)(s / 60), (int)(s % 60));
}

// Etat court d'un mode pour le tableau des modes
string ModeStateText(const int m, color &clr)
{
   clr = gC_dim;
   if(!gMode[m].enabled) return "desactive";
   if(!ModeReady(m))     return "chargement...";
   int idx;
   int st = SignalState(m, idx);
   if(st == 1)
   {
      clr = DirClr(gSigs[idx].dir);
      return (gSigs[idx].dir > 0 ? "BUY " : "SELL ") + GradeText(gSigs[idx].grade);
   }
   if(st == 2) { clr = gC_amber; return "trop tard"; }
   if(st == 3) { clr = DirClr(gSigs[idx].dir); return (gSigs[idx].dir > 0 ? "BUY" : "SELL") + " en cours"; }
   return "attendre";
}

//==================================================================//
// PONT AVEC L'EXECUTEUR (XAUUSD_Signal_Executor.mq5)
//
// Un indicateur ne peut pas passer d'ordre en MQL5. L'indicateur publie le
// signal actif dans des variables globales du terminal ; l'EA executeur,
// pose sur le meme graphique, intercepte le clic sur le bandeau, demande
// confirmation et ouvre la position avec SL / TP, puis publie le resultat.
//==================================================================//

string GVName(const string key) { return "XSP_" + _Symbol + "_" + key; }

bool   gPubInit  = false;
bool   gPubValid = false;
double gPubId    = 0.0;
uint   gPubTick  = 0;

// Anti-doublon : une seule instance active de l'indicateur par graphique
string OwnerKey() { return "XSP_" + _Symbol + "_OWNER_" + IntegerToString(ChartID()); }

void RemoveSelfIfDuplicate()
{
   static bool done = false;
   if(done)
      return;
   done = true;
   EventKillTimer();
   int w = ChartWindowFind();
   if(w < 0) w = 0;
   if(!ChartIndicatorDelete(0, w, "XAUUSD Signal Pro (doublon)"))
      Print("[SIGNAL PRO] Copie en double inactive : retirez-la manuellement (clic droit > Liste des indicateurs).");
}

// Secondes depuis la derniere cotation du symbole (marche ferme / connexion perdue si grand)
long QuoteAge()
{
   datetime last = (datetime)SymbolInfoInteger(_Symbol, SYMBOL_TIME);
   if(last <= 0)
      return 0;
   return (long)(TimeTradeServer() - last);
}

bool MarketLive() { return (QuoteAge() <= 30); }

bool TerminalConnected() { return (bool)TerminalInfoInteger(TERMINAL_CONNECTED); }

double GVGet(const string key)
{
   string n = GVName(key);
   return (GlobalVariableCheck(n) ? GlobalVariableGet(n) : 0.0);
}

bool ExecutorAlive()
{
   double hb = GVGet("ALIVE");
   return (hb > 0.0 && (double)TimeLocal() - hb <= 5.0);
}

// Identifiant unique d'un signal : heure de la bougie * 10 + mode
double SignalId(const int idx)
{
   return (double)gSigs[idx].time * 10.0 + gSigs[idx].mode;
}

void PublishSignal()
{
   int idx;
   int st = SignalState(gFocus, idx);
   bool   valid = (st == 1 && gDataReady);
   double id    = (valid ? SignalId(idx) : 0.0);

   // N'ecrit que si quelque chose a change (rafraichi au plus tard toutes les 30 s)
   if(gPubInit && valid == gPubValid && id == gPubId && GetTickCount() - gPubTick < 30000)
      return;
   gPubInit  = true;
   gPubValid = valid;
   gPubId    = id;
   gPubTick  = GetTickCount();

   if(!valid)
   {
      GlobalVariableSet(GVName("SIG_VALID"), 0.0);
      return;
   }
   SignalRec r = gSigs[idx];
   GlobalVariableSet(GVName("SIG_DIR"),   (double)r.dir);
   GlobalVariableSet(GVName("SIG_ENTRY"), r.entry);
   GlobalVariableSet(GVName("SIG_SL"),    r.sl);
   GlobalVariableSet(GVName("SIG_TP"),    r.tp);
   GlobalVariableSet(GVName("SIG_MODE"),  (double)r.mode);
   GlobalVariableSet(GVName("SIG_GRADE"), (double)r.grade);
   GlobalVariableSet(GVName("SIG_TYPE"),  (double)r.setup);
   GlobalVariableSet(GVName("SIG_ID"),    SignalId(idx));
   GlobalVariableSet(GVName("SIG_VALID"), 1.0);       // ecrit en dernier
}

// Signal deja execute par l'EA ?
bool SignalExecuted(const int idx)
{
   return (idx >= 0 && GVGet("RES_ID") == SignalId(idx) && GVGet("RES_CODE") > 0.0);
}

// Dernier resultat de l'executeur (affiche 20 s)
string ExecResultText(color &clr)
{
   clr = gC_dim;
   double t = GVGet("RES_TIME");
   if(t <= 0.0 || (double)TimeLocal() - t > 20.0)
      return "";
   int code = (int)GVGet("RES_CODE");
   int ret  = (int)GVGet("RES_RET");
   if(code > 0)
   {
      clr = gC_green;
      return "Position ouverte  #" + DoubleToString(GVGet("RES_TICKET"), 0) +
             "  (" + DoubleToString(GVGet("RES_LOT"), 2) + " lot)";
   }
   if(code == 0)
      return "Ordre annule";
   clr = gC_red;
   if(code == -1)
   {
      switch(ret)
      {
         case 1: return "Refuse : aucun signal actif";
         case 2: return "Refuse : signal deja execute";
         case 3: return "Refuse : le prix a deja depasse le SL ou le TP";
         case 4: return "Refuse : SL / TP trop proches du prix";
         case 5: return "Refuse : risque trop faible pour le lot mini";
         case 6: return "Refuse : trading auto desactive (bouton Algo Trading)";
         case 7: return "Refuse : marge insuffisante";
         case 8: return "Refuse : prix trop loin de l'entree du signal";
         case 9: return "Refuse : une position est deja ouverte";
      }
      return "Refuse";
   }
   return "Erreur serveur " + IntegerToString(ret);
}

//==================================================================//
// PANNEAU
//==================================================================//

int LayoutPanel()
{
   int W = PANEL_W;
   int M = 12;
   int y = 0;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int f = gFocus;
   ModeDef md = gMode[f];

   // ---- En-tete
   PRect("HDR", 0, 0, W, 30, gC_card, gC_border);
   PText("TITLE", PANEL_TITLE, M, 8, 9, gC_gold, InpFontBold);
   PText("TOGGLE", (gMinimized ? "[ + ]" : "[ - ]"), W - M, 8, 8, gC_dim, InpFontBold, ANCHOR_RIGHT_UPPER);
   PText("PRICE", DoubleToString(bid, _Digits), W - M - 40, 7, 10, gC_text, InpFontBold, ANCHOR_RIGHT_UPPER);
   y = 30;

   if(!gDataReady || !ModeReady(f))
   {
      PRect("BAN", M, y + 10, W - 2 * M, 50, gC_amber, gC_amber);
      PText("BAN_T", "SYNCHRONISATION...", M + 14, y + 18, 12, clrWhite, InpFontBold);
      PText("BAN_S", "Chargement M1 / M5 / M15 / H1 / H4 / D1 / W1", M + 14, y + 40, 7, clrWhite, InpFont);
      return y + 70;
   }

   if(gCatchingUp)
   {
      int pct = (gCatchTotal > 0 ? (int)MathRound(100.0 * gCatchDone / gCatchTotal) : 0);
      PRect("BAN", M, y + 10, W - 2 * M, 50, gC_blue, gC_blue);
      PText("BAN_T", "ANALYSE DE L'HISTORIQUE  " + IntegerToString(pct) + "%", M + 14, y + 18, 11, clrWhite, InpFontBold);
      Bar("BAN_P", M + 14, y + 44, W - 2 * M - 28, 6, pct / 100.0, clrWhite);
      return y + 70;
   }

   // Plus de cotation : le prevenir clairement au lieu de laisser un panneau fige
   long qa = QuoteAge();
   if(!TerminalConnected() || qa > 300)
   {
      bool off = !TerminalConnected();
      PRect("BAN", M, y + 10, W - 2 * M, 50, gC_dim, gC_dim);
      PText("BAN_T", (off ? "CONNEXION PERDUE" : "MARCHE FERME"), M + 14, y + 16, 14, clrWhite, InpFontBold);
      PText("BAN_S", (off ? "Verifier internet / le serveur du broker" :
                            "Aucune cotation depuis " + AgeText((datetime)(TimeCurrent() - qa - PeriodSeconds(_Period))) +
                            " — reprise a l'ouverture"), M + 14, y + 41, 7, clrWhite, InpFont);
      return y + 70;
   }

   int idx = -1;
   int st = SignalState(f, idx);
   bool fresh = (st == 1);
   int  sdir  = (idx >= 0 ? gSigs[idx].dir : 0);
   bool noMode = (InpTradeMode == TM_AUTO && gRecommended < 0);
   color ac   = (fresh ? DirClr(sdir) : gC_amber);

   if(gMinimized)
   {
      string mini = md.tag + "  " + (fresh ? (sdir > 0 ? "BUY " : "SELL ") + GradeText(gSigs[idx].grade) : "ATTENDRE");
      PRect("MINI", 0, y, W, 26, ac, ac);
      PText("MINI_T", mini, M, y + 5, 10, clrWhite, InpFontBold);
      PText("MINI_S", "Conseil : " + (gRecommended >= 0 ? gMode[gRecommended].name : "aucun"),
            W - M, y + 7, 8, clrWhite, InpFont, ANCHOR_RIGHT_UPPER);
      return y + 26;
   }

   SetupInfo s = gClosed[f];

   // ---- Bandeau d'action (mode suivi)
   y += 10;
   string big, sub;
   uchar icon;
   if(fresh)
   {
      big  = (sdir > 0 ? "ACHETER" : "VENDRE");
      sub  = md.name + "  |  " + SetupName(gSigs[idx].setup) + "  |  " + GradeText(gSigs[idx].grade) + "  |  " + AgeText(gSigs[idx].time);
      icon = (uchar)(sdir > 0 ? 233 : 234);
   }
   else
   {
      big  = "ATTENDRE";
      if(st == 2)       sub = md.name + "   |   signal deja parti — ne pas courir";
      else if(noMode)   sub = "Aucun mode favorable pour l'instant";
      else              sub = md.name + "   |   pas de signal valide maintenant";
      icon = 54;
   }
   bool alive    = ExecutorAlive();
   bool executed = (fresh && SignalExecuted(idx));
   int  banH     = 84;     // hauteur fixe : le panneau ne saute pas quand un signal apparait
   PRect("BAN", M, y, W - 2 * M, banH, ac, ac);
   PText("BAN_T", big, M + 14, y + 7, 20, clrWhite, InpFontBold);
   PText("BAN_S", FitText(sub, InpFont, 7, W - 2 * M - 70), M + 14, y + 45, 7, Mix(clrWhite, ac, 0.12), InpFont);
   PIcon("BAN_I", icon, W - M - 12, y + 10, 28, clrWhite, ANCHOR_RIGHT_UPPER);
   if(fresh)
   {
      // Bouton : clic gere par l'EA executeur (confirmation puis ordre avec SL / TP)
      string btn;
      color  bbg, btx;
      if(executed)   { btn = "POSITION OUVERTE";                          bbg = Mix(ac, clrBlack, 0.25); btx = clrWhite; }
      else if(alive) { btn = "CLIQUER POUR " + (sdir > 0 ? "ACHETER" : "VENDRE") + "  (SL + TP)"; bbg = clrWhite; btx = ac; }
      else           { btn = "Executeur absent : ajouter l'EA pour trader"; bbg = Mix(ac, clrBlack, 0.25); btx = Mix(clrWhite, ac, 0.3); }
      PRect("BAN_BTN", M + 10, y + 60, W - 2 * M - 20, 18, bbg, bbg);
      PText("BAN_BTN_T", btn, W / 2, y + 62, 7, btx, InpFontBold, ANCHOR_UPPER);
   }
   else
   {
      color bbg = Mix(ac, clrBlack, 0.18);
      PRect("BAN_BTN", M + 10, y + 60, W - 2 * M - 20, 18, bbg, bbg);
      PText("BAN_BTN_T", "Aucune position a prendre pour l'instant", W / 2, y + 62, 7, Mix(clrWhite, ac, 0.35), InpFont, ANCHOR_UPPER);
   }
   y += banH;

   // ---- Verdict : puis-je trader maintenant ?
   bool   spreadNow = (InpMaxSpreadPoints <= 0 || gSpreadNow <= InpMaxSpreadPoints * md.spreadMult);
   bool   canTrade  = (fresh && !executed && spreadNow);
   string why;
   if(fresh && executed)
      why = "Position deja ouverte sur ce signal — gerer le trade";
   else if(fresh && !spreadNow)
      why = "Spread trop eleve en ce moment (" + IntegerToString((int)gSpreadNow) + ") — patienter";
   else if(fresh)
      why = (alive ? "Clique sur le bandeau, ou entre pres de " : "Entrer pres de ") +
            DoubleToString(gSigs[idx].entry, _Digits) + " — SL obligatoire";
   else if(st == 3)
      why = "Trade " + (sdir > 0 ? "BUY" : "SELL") + " en cours — gerer la position";
   else if(st == 2)
      why = "Signal deja parti — attendre le prochain";
   else if(noMode && StringLen(gAdvice[f].minus) > 0)
      why = "Marche defavorable : " + gAdvice[f].minus;
   else
      why = s.reason;
   y += 8;
   color vc = (canTrade ? gC_green : gC_red);
   PText("Q", "PUIS-JE TRADER ?", M, y + 1, 8, gC_dim, InpFontBold);
   PRect("Q_P", M + 118, y, 40, 17, vc, vc);
   PText("Q_V", (canTrade ? "OUI" : "NON"), M + 138, y + 2, 8, clrWhite, InpFontBold, ANCHOR_UPPER);
   y += 22;
   PText("REASON", FitText(why, InpFont, 8, W - 2 * M), M, y, 8, gC_text, InpFont);
   y += 18;
   color rc;
   string res = ExecResultText(rc);
   if(StringLen(res) > 0)
      PText("EXEC", FitText(res, InpFontBold, 8, W - 2 * M), M, y, 8, rc, InpFontBold);
   y += 18;   // place reservee meme vide
   y += 4;

   // ---- Modes de trading + conseil
   y = Section("S_MODE", "MODE DE TRADING  " + (InpTradeMode == TM_AUTO ? "(AUTO)" : "(MANUEL)"), y);
   for(int m = 0; m < NMODES; m++)
   {
      string id = "MD" + IntegerToString(m);
      bool isRec   = (m == gRecommended);
      bool isFocus = (m == f);
      color nc = (isRec ? gC_gold : (gMode[m].enabled ? gC_text : gC_dim));
      PText(id + "_N", (isFocus ? "> " : "   ") + gMode[m].name, M, y, 8, nc, (isRec || isFocus ? InpFontBold : InpFont));
      int bx = M + 92, bw = 92;
      double fr = gAdvice[m].score / 100.0;
      color bc = (gAdvice[m].score >= InpAdviceMinScore ? gC_green : (gAdvice[m].score >= InpAdviceMinScore - 15 ? gC_amber : gC_red));
      Bar(id + "_B", bx, y + 5, bw, 7, fr, (gMode[m].enabled ? bc : gC_track));
      PText(id + "_P", (gMode[m].enabled ? IntegerToString(gAdvice[m].score) + "%" : "--"), bx + bw + 6, y, 8, gC_dim, InpFont);
      color sc;
      string stx = ModeStateText(m, sc);
      PText(id + "_S", stx, W - M, y, 8, sc, InpFontBold, ANCHOR_RIGHT_UPPER);
      y += 18;
   }
   string advice;
   color  advClr;
   if(gRecommended >= 0)
   {
      advice = "Conseil : " + gMode[gRecommended].name +
               (StringLen(gAdvice[gRecommended].plus) > 0 ? " — " + gAdvice[gRecommended].plus : "");
      advClr = gC_gold;
   }
   else
   {
      int b = 0;
      for(int m = 1; m < NMODES; m++) if(gAdvice[m].score > gAdvice[b].score) b = m;
      advice = "Conseil : rester a l'ecart" +
               (StringLen(gAdvice[b].minus) > 0 ? " — " + gAdvice[b].minus : "");
      advClr = gC_amber;
   }
   y += 2;
   PText("ADV", FitText(advice, InpFontBold, 8, W - 2 * M), M, y, 8, advClr, InpFontBold);
   y += 16;
   if(StringLen(gAdvice[f].minus) > 0 && gAdvice[f].minus != "desactive")
   {
      PText("ADV2", FitText(md.name + " : attention, " + gAdvice[f].minus, InpFont, 7, W - 2 * M), M, y, 7, gC_dim, InpFont);
   }
   y += 15;   // place reservee meme vide
   y += 6;

   // ---- Confluence (mode suivi)
   y = Section("S_CONF", "CONFLUENCE  " + md.name, y);
   y = Gauge("G_BUY",  "BUY",  s.scoreBuy,  MathMax(1, s.maxScore), gC_green, y);
   y = Gauge("G_SELL", "SELL", s.scoreSell, MathMax(1, s.maxScore), gC_red,   y);
   y += 6;

   // ---- Tendances (UT du mode suivi)
   y = Section("S_TF", "TENDANCES", y);
   string tfs[4];
   tfs[0] = TFName(gTF[md.kBias].tf)  + " biais";
   tfs[1] = TFName(gTF[md.kTrend].tf) + " tendance";
   tfs[2] = TFName(gTF[md.kZone].tf)  + " zone";
   tfs[3] = TFName(gTF[md.kTrig].tf)  + " signal";
   int tv[4];
   tv[0] = s.tB; tv[1] = s.tT; tv[2] = s.tZ; tv[3] = s.tG;
   int gap = 6;
   int cw  = (W - 2 * M - 3 * gap) / 4;
   for(int k = 0; k < 4; k++)
   {
      int x = M + k * (cw + gap);
      color tc = (tv[k] > 0 ? gC_green : (tv[k] < 0 ? gC_red : gC_dim));
      string id = "TF" + IntegerToString(k);
      PRect(id, x, y, cw, 40, Mix(gC_card, tc, 0.16), Mix(gC_border, tc, 0.45));
      PText(id + "_N", tfs[k], x + cw / 2, y + 5, 7, gC_dim, InpFontBold, ANCHOR_UPPER);
      PText(id + "_V", (tv[k] > 0 ? "HAUSSE" : (tv[k] < 0 ? "BAISSE" : "NEUTRE")),
            x + cw / 2, y + 20, 8, tc, InpFontBold, ANCHOR_UPPER);
   }
   y += 50;

   // ---- Checklist (mode suivi)
   string nT = TFName(gTF[md.kTrend].tf), nZ = TFName(gTF[md.kZone].tf);
   string nG = TFName(gTF[md.kTrig].tf),  nB = TFName(gTF[md.kBias].tf);
   string cd = (s.cdir > 0 ? "  —  BUY" : (s.cdir < 0 ? "  —  SELL" : ""));
   y = Section("S_CHK", "CHECKLIST" + cd, y);
   string labels[10];
   labels[0] = "Tendance " + nT + "/" + nZ; labels[1] = "Zone " + nZ;     labels[2] = "Declencheur " + nG;
   labels[3] = "Score mini";                labels[4] = nB + " aligne";   labels[5] = "RSI pas extreme";
   labels[6] = "SL / RR valides";           labels[7] = "ADX (tendance)"; labels[8] = "Spread";
   labels[9] = "Session";
   bool oks[10];
   oks[0] = s.chkTrend; oks[1] = s.chkZone; oks[2] = s.chkTrigger; oks[3] = s.chkScore;
   oks[4] = s.chkBias;  oks[5] = s.chkRSI;  oks[6] = s.chkRR;      oks[7] = s.adxOk;
   oks[8] = (InpMaxSpreadPoints <= 0 || gSpreadNow <= InpMaxSpreadPoints * md.spreadMult);
   oks[9] = (!md.useSession || InSession(TimeCurrent()));
   int colW = (W - 2 * M) / 2;
   for(int k = 0; k < 10; k++)
      CheckItem("CK" + IntegerToString(k), labels[k], oks[k], M + (k / 5) * colW, y + (k % 5) * 18);
   y += 5 * 18 + 6;

   // ---- Plan de trade (mode suivi)
   y = Section("S_PLAN", "PLAN DE TRADE  " + md.name, y);
   if(idx >= 0 && gSigs[idx].result == 0)
   {
      SignalRec r = gSigs[idx];
      string head = (r.dir > 0 ? "BUY" : "SELL") + "  " + GradeText(r.grade) + "   |   " +
                    TimeToString(r.time + PeriodSeconds(_Period), TIME_DATE | TIME_MINUTES) +
                    "   |   " + (fresh ? "ACTIF" : (st == 2 ? "TROP TARD" : "EN COURS"));
      PText("PL_H", FitText(head, InpFontBold, 8, W - 2 * M), M, y, 8, DirClr(r.dir), InpFontBold);
      y += 20;
      double risk = MathAbs(r.entry - r.sl);
      double rew  = MathAbs(r.tp - r.entry);
      double pnl  = (bid - r.entry) * r.dir;
      KeyValue("PL_Y", "Type d'entree", SetupName(r.setup), gC_gold, y);                  y += 16;
      PText("PL_YD", FitText(SetupDesc(r.setup), InpFont, 7, W - 2 * M), M, y, 7, gC_dim, InpFont); y += 18;
      KeyValue("PL_E", "Entree", DoubleToString(r.entry, _Digits), gC_blue, y);             y += 18;
      KeyValue("PL_S", "Stop Loss", DoubleToString(r.sl, _Digits) + "   (-" + DoubleToString(risk, 2) + ")", gC_red, y); y += 18;
      KeyValue("PL_T", "Take Profit", DoubleToString(r.tp, _Digits) + "   (+" + DoubleToString(rew, 2) + ")", gC_green, y); y += 18;
      KeyValue("PL_R", "Ratio R:R", "1 : " + DoubleToString(risk > 0.0 ? rew / risk : 0.0, 2), gC_text, y); y += 18;
      KeyValue("PL_P", "Latent", (pnl >= 0.0 ? "+" : "") + DoubleToString(pnl, 2) + " $/oz",
               (pnl >= 0.0 ? gC_green : gC_red), y);
      y += 22;
   }
   else
   {
      string last = "Aucun signal " + md.name + " sur l'historique";
      color  lc   = gC_dim;
      if(idx >= 0)
      {
         last = "Dernier : " + (gSigs[idx].dir > 0 ? "BUY " : "SELL ") + GradeText(gSigs[idx].grade) +
                " le " + TimeToString(gSigs[idx].time + PeriodSeconds(_Period), TIME_DATE | TIME_MINUTES) +
                "  ->  " + (gSigs[idx].result > 0 ? "TP" : "SL");
         lc   = (gSigs[idx].result > 0 ? gC_green : gC_red);
      }
      PText("PL_H", FitText(last, InpFont, 8, W - 2 * M), M, y, 8, lc, InpFont);
      y += 18;
      PText("PL_W", "Patience : attendre le prochain setup", M, y, 8, gC_dim, InpFont);
      y += 22;
   }

   // ---- Historique par mode
   y = Section("S_STAT", "HISTORIQUE (" + IntegerToString(InpHistoryBars) + " bougies " + TFName(_Period) + ")", y);
   for(int m = 0; m < NMODES; m++)
   {
      if(!gMode[m].enabled)
         continue;
      int n, w, l;
      double netR;
      ModeStats(m, n, w, l, netR);
      string id = "ST" + IntegerToString(m);
      int closed = w + l;
      PText(id + "_N", gMode[m].tag, M, y, 8, (m == f ? gC_gold : gC_text), InpFontBold);
      if(n == 0)
      {
         PText(id + "_A", "aucun signal", M + 60, y, 8, gC_dim, InpFont);
      }
      else
      {
         double wr = (closed > 0 ? 100.0 * w / closed : 0.0);
         PText(id + "_A", IntegerToString(n) + " sig   " + IntegerToString(w) + " TP / " + IntegerToString(l) + " SL",
               M + 60, y, 8, gC_text, InpFont);
         PText(id + "_W", (closed > 0 ? DoubleToString(wr, 0) + "%" : "--"), W - M - 58, y, 8,
               (closed > 0 && wr >= 50.0 ? gC_green : gC_dim), InpFontBold, ANCHOR_RIGHT_UPPER);
         PText(id + "_R", (netR >= 0.0 ? "+" : "") + DoubleToString(netR, 1) + " R", W - M, y, 8,
               (netR >= 0.0 ? gC_green : gC_red), InpFontBold, ANCHOR_RIGHT_UPPER);
      }
      y += 18;
   }
   y += 4;

   // ---- Pied
   PRect("FOOT_L", M, y, W - 2 * M, 1, gC_border, gC_border);
   y += 8;
   ENUM_TIMEFRAMES tg = gTF[md.kTrig].tf;
   datetime now   = TimeTradeServer();
   datetime openG = iTime(_Symbol, tg, 0);
   long left = (openG > 0 ? (long)(openG + PeriodSeconds(tg) - now) : 0);
   if(left > PeriodSeconds(tg)) left = PeriodSeconds(tg);
   PText("UPD", "Derniere cotation  " + TimeToString((datetime)SymbolInfoInteger(_Symbol, SYMBOL_TIME), TIME_SECONDS),
         M, y, 7, (QuoteAge() > 60 ? gC_amber : gC_dim), InpFont);
   y += 16;
   PText("CD", "Cloture bougie " + TFName(tg) + "  " + Countdown(left), M, y, 8,
         gC_text, InpFont);
   PText("SPR", "Spread " + IntegerToString((int)gSpreadNow), W - M, y, 8,
         (oks[8] ? gC_dim : gC_red), InpFont, ANCHOR_RIGHT_UPPER);
   y += 18;
   if(_Period != PERIOD_M1 && gMode[MODE_SCALP].enabled)
   {
      PText("TFW", "Conseil : graphique M1 pour suivre tous les modes", M, y, 8, gC_amber, InpFontBold);
      y += 18;
   }
   PText("DISC", "Aide a la decision, pas une garantie. SL obligatoire.", M, y, 7, gC_dim, InpFont);
   y += 20;
   return y;
}

// Retourne true si au moins un objet a change (=> ChartRedraw utile)
bool DrawPanel()
{
   if(!InpShowPanel)
   {
      if(gPrevCount > 0)
      {
         ObjectsDeleteAll(0, PANEL_PREFIX, 0, -1);
         ResetPanelCache();
         return true;
      }
      return false;
   }

   double dpi = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI);
   if(dpi < 72.0) dpi = 96.0;
   double base = (dpi / 96.0) * MathMax(0.6, MathMin(2.0, InpPanelScale));

   // Passe de mesure (unites du panneau). L'echelle n'est recalculee librement qu'au
   // chargement et au redimensionnement du graphique ; ensuite elle peut seulement
   // diminuer, pour que le panneau ne change pas de taille a chaque ligne qui apparait.
   gS   = base * gFit;
   gDry = true;
   gDrawnCount = 0;
   int h = LayoutPanel();
   int chartH = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   int avail  = chartH - InpPanelY - 8;
   if(chartH != gLastChartH)          // fenetre redimensionnee : on recalcule l'echelle
   {
      gLastChartH = chartH;
      gFitValid   = false;
   }
   double need = 1.0;
   if(chartH > 0 && avail > 0 && h > 0)
      need = MathMax(0.65, MathMin(1.0, (double)avail / (base * h)));
   if(!gFitValid || need < gFit)
      gFit = need;
   gFitValid = true;
   gS = base * gFit;

   gDry = false;
   gDrawnCount = 0;
   gObjUpdates = 0;
   int before  = gPrevCount;
   PRect("BG", 0, 0, PANEL_W, h, gC_bg, gC_border);   // cree en premier -> reste au fond
   LayoutPanel();
   bool changed = (gObjUpdates > 0 || gDrawnCount != before);
   PurgeStale();
   return changed;
}

//==================================================================//
// NIVEAUX / MARQUES GRAPHIQUES
//==================================================================//

// Suivi des objets dessines pendant une passe : on met a jour sur place et on ne supprime
// que ceux qui ne servent plus (au lieu de tout effacer puis tout redessiner)
void KeepReset() { gKeepCount = 0; }

void Keep(const string name)
{
   if(gKeepCount >= ArraySize(gKeep))
      ArrayResize(gKeep, gKeepCount + 64);
   gKeep[gKeepCount++] = name;
}

void KeepPurge(const string prefix)
{
   for(int k = ObjectsTotal(0, 0, -1) - 1; k >= 0; k--)
   {
      string n = ObjectName(0, k, 0, -1);
      if(StringFind(n, prefix) != 0)
         continue;
      bool keep = false;
      for(int j = 0; j < gKeepCount; j++)
         if(gKeep[j] == n) { keep = true; break; }
      if(!keep)
         ObjectDelete(0, n);
   }
}

void DrawHLine(const string id, const double price, const color clr, const int style, const int width, const string text)
{
   string name = OBJ_PREFIX + id;
   Keep(name);
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
   Keep(name);
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

void DrawBox(const string id, const datetime t1, const double p1, const datetime t2, const double p2, const color clr)
{
   string name = OBJ_PREFIX + id;
   Keep(name);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t1);
   ObjectSetInteger(0, name, OBJPROP_TIME, 1, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, p1);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 1, p2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DrawChartText(const string id, const datetime t, const double price, const string text,
                   const color clr, const int fs, const ENUM_ANCHOR_POINT anchor)
{
   string name = OBJ_PREFIX + id;
   Keep(name);
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_TIME, 0, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, 0, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, InpFontBold);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fs);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DrawChartLevels(const datetime lastBarTime)
{
   KeepReset();   // la liste de suivi ne doit pas grossir a chaque tick
   SetupInfo info = gClosed[gFocus];
   if(!InpShowLevels)
   {
      ObjectsDeleteAll(0, OBJ_PREFIX + "LV_", 0, -1);
   }
   else
   {
      if(info.vwap > 0.0)
         DrawHLine("LV_VWAP", info.vwap, C'210,160,40', STYLE_SOLID, 1, "VWAP " + DoubleToString(info.vwap, _Digits));
      else
         DeleteObj(OBJ_PREFIX + "LV_VWAP");
      if(info.pivot > 0.0)
         DrawHLine("LV_P", info.pivot, C'120,128,142', STYLE_DASH, 1, "P");
      if(info.r1 > 0.0)
         DrawHLine("LV_R1", info.r1, C'170,70,70', STYLE_DOT, 1, "R1");
      if(info.s1 > 0.0)
         DrawHLine("LV_S1", info.s1, C'40,120,80', STYLE_DOT, 1, "S1");
      if(info.support.valid)
         DrawHLine("LV_SUP", info.support.price, C'40,120,80', STYLE_SOLID, 1, "SUP " + gMode[gFocus].tag);
      else
         DeleteObj(OBJ_PREFIX + "LV_SUP");
      if(info.resist.valid)
         DrawHLine("LV_RES", info.resist.price, C'170,70,70', STYLE_SOLID, 1, "RES " + gMode[gFocus].tag);
      else
         DeleteObj(OBJ_PREFIX + "LV_RES");
   }

   // Plan du dernier signal encore ouvert du mode suivi
   int li = LastSigIdx(gFocus);
   if(!InpShowTradeLevels || li < 0 || gSigs[li].result != 0)
   {
      ObjectsDeleteAll(0, OBJ_PREFIX + "TR_", 0, -1);
      return;
   }

   SignalRec r = gSigs[li];
   int barSec = PeriodSeconds(_Period);
   datetime t2 = r.time + barSec * 40;
   if(t2 < lastBarTime)
      t2 = lastBarTime + barSec * 4;
   string tag = gMode[r.mode].tag + " ";

   DrawSegment("TR_ENTRY", r.time, t2, r.entry, clrRoyalBlue, STYLE_SOLID, 2, tag + "ENTREE " + DoubleToString(r.entry, _Digits));
   DrawSegment("TR_SL",    r.time, t2, r.sl,    clrCrimson,   STYLE_DASHDOT, 2, tag + "SL " + DoubleToString(r.sl, _Digits));
   DrawSegment("TR_TP",    r.time, t2, r.tp,    C'0,140,80',  STYLE_DOT, 2, tag + "TP " + DoubleToString(r.tp, _Digits));

   DrawChartText("TR_TXT_E", t2, r.entry, "  " + tag + "ENTREE " + DoubleToString(r.entry, _Digits), clrRoyalBlue, 8, ANCHOR_LEFT);
   DrawChartText("TR_TXT_S", t2, r.sl,    "  SL " + DoubleToString(r.sl, _Digits), clrCrimson, 8, ANCHOR_LEFT);
   DrawChartText("TR_TXT_T", t2, r.tp,    "  TP " + DoubleToString(r.tp, _Digits), C'0,140,80', 8, ANCHOR_LEFT);

   if(InpShowTradeZones)
   {
      color chartBg = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
      DrawBox("TR_ZTP", r.time, r.entry, t2, r.tp, Mix(chartBg, C'0,170,90', 0.22));
      DrawBox("TR_ZSL", r.time, r.entry, t2, r.sl, Mix(chartBg, C'220,40,40', 0.22));
   }
   else
   {
      DeleteObj(OBJ_PREFIX + "TR_ZTP");
      DeleteObj(OBJ_PREFIX + "TR_ZSL");
   }
}

void DrawSignalMarks(const double &high[], const double &low[], const int rates_total)
{
   KeepReset();
   if(!InpShowSignalLabels)
   {
      KeepPurge(OBJ_PREFIX + "SG_");
      return;
   }

   for(int k = 0; k < gSigCount; k++)
   {
      SignalRec r = gSigs[k];
      if(r.index < 0 || r.index >= rates_total)
         continue;
      double off = (r.index < ArraySize(gATR) ? gATR[r.index] : 0.0) * 1.25;
      string res = (r.result > 0 ? "  TP" : (r.result < 0 ? "  SL" : ""));
      string txt = gMode[r.mode].tag + " " + (r.dir > 0 ? "BUY " : "SELL ") + GradeText(r.grade) +
                   " | " + SetupShort(r.setup) + res;
      color  clr = (r.dir > 0 ? C'20,170,80' : C'225,60,60');
      string id  = "SG_" + IntegerToString(r.mode) + "_" + IntegerToString((long)r.time);
      if(r.dir > 0)
         DrawChartText(id, r.time, low[r.index] - off, txt, clr, 7, ANCHOR_UPPER);
      else
         DrawChartText(id, r.time, high[r.index] + off, txt, clr, 7, ANCHOR_LOWER);
   }
   KeepPurge(OBJ_PREFIX + "SG_");
}

//==================================================================//
// NIVEAUX CLES SUR LE GRAPHIQUE
//==================================================================//

// Swing le plus proche du prix et non casse depuis (resistance au-dessus / support en dessous)
bool NearestSwing(const ENUM_TIMEFRAMES tf, const bool above, const double price, double &level, datetime &t)
{
   int strength = MathMax(1, InpSwingBars);
   int bars = Bars(_Symbol, tf);
   int end  = MathMin(InpMTFLevelLookback, bars - strength - 2);
   double run = price;
   for(int i = 0; i < strength && i < bars; i++)     // bougies trop recentes pour un swing confirme
      run = (above ? MathMax(run, iHigh(_Symbol, tf, i)) : MathMin(run, iLow(_Symbol, tf, i)));

   for(int i = strength; i <= end; i++)
   {
      double v = (above ? iHigh(_Symbol, tf, i) : iLow(_Symbol, tf, i));
      bool hit = (above ? (v > run && IsSwingHighTF(tf, i, strength)) : (v < run && IsSwingLowTF(tf, i, strength)));
      if(hit)
      {
         level = v;
         t = iTime(_Symbol, tf, i);
         return true;
      }
      run = (above ? MathMax(run, v) : MathMin(run, v));
   }
   return false;
}

void DrawLevel(const string id, const datetime t1, const datetime t2, const double price,
               const color clr, const int style, const int width, const string label)
{
   DrawSegment(id, t1, t2, price, clr, style, width, label + " " + DoubleToString(price, _Digits));
   DrawChartText(id + "_T", t2, price, " " + label + "  " + DoubleToString(price, _Digits), clr, 7, ANCHOR_LEFT);
}

bool DrawKeyLevels(const datetime lastBarTime)
{
   // Recalcul uniquement a la cloture d'une bougie, a partir du dernier prix CLOTURE :
   // les niveaux ne bougent plus avec chaque tick
   if(lastBarTime == gKeyLevelsBar)
      return false;
   gKeyLevelsBar = lastBarTime;
   KeepReset();

   double   bid    = iClose(_Symbol, _Period, 1);
   if(bid <= 0.0)
      bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int      barSec = PeriodSeconds(_Period);
   datetime tEnd   = lastBarTime + barSec * 12;
   color    bg     = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);

   // ---- 1. Support / resistance de chaque unite de temps
   if(InpShowMTFLevels)
   {
      ENUM_TIMEFRAMES tfs[5] = {PERIOD_M5, PERIOD_M15, PERIOD_H1, PERIOD_H4, PERIOD_D1};
      bool   on[5];
      on[0] = InpLevelsM5; on[1] = InpLevelsM15; on[2] = InpLevelsH1; on[3] = InpLevelsH4; on[4] = InpLevelsD1;
      double force[5]  = {0.45, 0.60, 0.75, 0.90, 1.00};   // plus l'UT est grande, plus la ligne est visible
      int    styles[5] = {STYLE_DOT, STYLE_DOT, STYLE_DASH, STYLE_SOLID, STYLE_SOLID};
      int    widths[5] = {1, 1, 1, 2, 2};
      for(int k = 0; k < 5; k++)
      {
         if(!on[k])
            continue;
         double lv;
         datetime t;
         string tf = TFName(tfs[k]);
         if(NearestSwing(tfs[k], true, bid, lv, t))
            DrawLevel("KL_R_" + IntegerToString(k), t, tEnd, lv, Mix(bg, C'235,90,90', force[k]), styles[k], widths[k], "R " + tf);
         if(NearestSwing(tfs[k], false, bid, lv, t))
            DrawLevel("KL_S_" + IntegerToString(k), t, tEnd, lv, Mix(bg, C'60,200,120', force[k]), styles[k], widths[k], "S " + tf);
      }
   }

   // ---- 2. Plus hauts / plus bas des periodes precedentes
   double h, l, c;
   if(InpShowPrevDay && PrevRange(PERIOD_D1, lastBarTime, h, l, c))
   {
      datetime t0 = iTime(_Symbol, PERIOD_D1, iBarShift(_Symbol, PERIOD_D1, lastBarTime, false) + 1);
      color dc = C'255,165,50';
      DrawLevel("KL_PDH", t0, tEnd, h, dc, STYLE_SOLID, 2, "PDH");
      DrawLevel("KL_PDL", t0, tEnd, l, dc, STYLE_SOLID, 2, "PDL");
      DrawLevel("KL_PDC", t0, tEnd, c, Mix(bg, dc, 0.55), STYLE_DOT, 1, "PDC");
   }
   if(InpShowPrevWeek && PrevRange(PERIOD_W1, lastBarTime, h, l, c))
   {
      datetime t0 = iTime(_Symbol, PERIOD_W1, iBarShift(_Symbol, PERIOD_W1, lastBarTime, false) + 1);
      color wc = C'80,165,255';
      DrawLevel("KL_PWH", t0, tEnd, h, wc, STYLE_SOLID, 2, "PWH");
      DrawLevel("KL_PWL", t0, tEnd, l, wc, STYLE_SOLID, 2, "PWL");
   }
   if(InpShowPrevMonth && PrevRange(PERIOD_MN1, lastBarTime, h, l, c))
   {
      datetime t0 = iTime(_Symbol, PERIOD_MN1, iBarShift(_Symbol, PERIOD_MN1, lastBarTime, false) + 1);
      color mc = C'185,120,255';
      DrawLevel("KL_PMH", t0, tEnd, h, mc, STYLE_SOLID, 2, "PMH");
      DrawLevel("KL_PML", t0, tEnd, l, mc, STYLE_SOLID, 2, "PML");
   }

   // ---- 3. Niveaux ronds institutionnels (ordres en attente, options, stops groupes)
   if(InpShowRoundLevels && InpRoundMajor > 0.0)
   {
      color gold = C'214,178,70';
      double base = RoundBelow(bid);
      for(int k = -InpRoundCount + 1; k <= InpRoundCount; k++)
      {
         double lv = base + k * InpRoundMajor;
         if(lv <= 0.0) continue;
         string id = "KL_RM_" + IntegerToString((int)MathRound(lv));
         DrawHLine(id, lv, Mix(bg, gold, 0.55), STYLE_DASH, 1, "Niveau rond " + DoubleToString(lv, 0));
         DrawChartText(id + "_T", tEnd, lv, " INSTIT  " + DoubleToString(lv, 0), Mix(bg, gold, 0.85), 7, ANCHOR_LEFT);
      }
      if(InpRoundMinor > 0.0 && InpRoundMinor < InpRoundMajor)
      {
         for(double lv = base - InpRoundMajor; lv <= base + 2.0 * InpRoundMajor + 1e-6; lv += InpRoundMinor)
         {
            double r = lv / InpRoundMajor;
            if(lv <= 0.0 || MathAbs(r - MathRound(r)) < 1e-6)
               continue;
            DrawHLine("KL_Rm_" + IntegerToString((int)MathRound(lv * 10.0)), lv, Mix(bg, gold, 0.22), STYLE_DOT, 1,
                      "Niveau rond " + DoubleToString(lv, 0));
         }
      }
   }

   KeepPurge(OBJ_PREFIX + "KL_");
   return true;
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
   SetIndexBuffer(5, gATR,        INDICATOR_CALCULATIONS);

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

   // Une copie de l'indicateur tourne deja sur ce graphique (ajout manuel + ajout par l'EA,
   // modele charge deux fois...) : cette copie ne calcule rien et se retire
   MathSrand((uint)GetTickCount());
   gInstanceId = (double)TimeLocal() * 1000.0 + MathRand();
   string okey = OwnerKey();
   double ohb  = (GlobalVariableCheck(okey + "_HB") ? GlobalVariableGet(okey + "_HB") : 0.0);
   if(GlobalVariableCheck(okey) && (double)TimeLocal() - ohb <= 10.0)
   {
      gDormant = true;
      for(int k = 0; k < 5; k++)
         PlotIndexSetInteger(k, PLOT_DRAW_TYPE, DRAW_NONE);
      IndicatorSetString(INDICATOR_SHORTNAME, "XAUUSD Signal Pro (doublon)");
      Print("[SIGNAL PRO] Deja present sur ce graphique : cette copie est desactivee (evite le double calcul).");
      EventSetTimer(1);
      return INIT_SUCCEEDED;
   }
   GlobalVariableSet(okey, gInstanceId);
   GlobalVariableSet(okey + "_HB", (double)TimeLocal());

   ArraySetAsSeries(gATR, false);

   gH_E10 = iMA(_Symbol, _Period, InpEMAFast,   0, MODE_EMA, PRICE_CLOSE);
   gH_E20 = iMA(_Symbol, _Period, InpEMAMedium, 0, MODE_EMA, PRICE_CLOSE);
   gH_E50 = iMA(_Symbol, _Period, InpEMASlow,   0, MODE_EMA, PRICE_CLOSE);
   gH_ATR = iATR(_Symbol, _Period, InpATRPeriod);
   if(gH_E10 == INVALID_HANDLE || gH_E20 == INVALID_HANDLE || gH_E50 == INVALID_HANDLE || gH_ATR == INVALID_HANDLE)
   {
      Print("[SIGNAL PRO] Echec creation des indicateurs du graphique.");
      return INIT_FAILED;
   }

   // Indicateurs multi-UT : seulement les UT utilisees par les modes actives
   InitModes();
   bool need[NTF];
   for(int k = 0; k < NTF; k++)
      need[k] = false;
   for(int m = 0; m < NMODES; m++)
   {
      if(!gMode[m].enabled) continue;
      need[gMode[m].kTrend] = true;
      need[gMode[m].kZone]  = true;
      need[gMode[m].kTrig]  = true;
      need[gMode[m].kBias]  = true;
   }
   for(int k = 0; k < NTF; k++)
   {
      if(!need[k]) continue;
      if(!gTF[k].Create(TFOf(k)))
      {
         Print("[SIGNAL PRO] Echec creation des indicateurs ", TFName(TFOf(k)));
         return INIT_FAILED;
      }
   }

   SetTheme();
   ApplyChartTheme();
   for(int m = 0; m < NMODES; m++)
   {
      ResetSetup(gClosed[m]);
      gClosed[m].mode   = m;
      gBO[m].dir        = 0;
      gBO[m].level      = 0.0;
      gBO[m].breakTime  = 0;
      gAdvice[m].score  = 0;
      gAdvice[m].plus   = "";
      gAdvice[m].minus  = "";
      gLastAlertTime[m] = 0;
   }
   gFocus = MODE_SCALP;
   for(int m = 0; m < NMODES; m++)
      if(gMode[m].enabled) { gFocus = m; break; }
   if(InpTradeMode == TM_SCALPING) gFocus = MODE_SCALP;
   if(InpTradeMode == TM_INTRADAY) gFocus = MODE_INTRA;
   if(InpTradeMode == TM_SWING)    gFocus = MODE_SWING;

   gSigCount = 0;
   ArrayResize(gSigs, 0, MAX_SIGNALS);
   gLastEvalTime = 0;
   gKeyLevelsBar = 0;
   gFitValid     = false;
   gAdviceInit   = false;
   gPendingRec   = -2;
   gPendingCount = 0;
   gSpreadAvg    = 0.0;
   gLevelsFocus  = -1;
   gPubInit      = false;
   ResetPanelCache();

   IndicatorSetString(INDICATOR_SHORTNAME, "XAUUSD Signal Pro");
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   EventSetTimer(1);   // compte a rebours + prix du panneau
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(gDormant)
      return;              // la copie inactive ne touche pas aux objets de l'instance active

   string okey = OwnerKey();
   if(GlobalVariableCheck(okey) && GlobalVariableGet(okey) == gInstanceId)
   {
      GlobalVariableDel(okey);
      GlobalVariableDel(okey + "_HB");
   }
   ObjectsDeleteAll(0, OBJ_PREFIX, 0, -1);
   RestoreChartTheme();
   GlobalVariableSet(GVName("SIG_VALID"), 0.0);
   ChartRedraw(0);

   ReleaseH(gH_E10); ReleaseH(gH_E20); ReleaseH(gH_E50); ReleaseH(gH_ATR);
   for(int k = 0; k < NTF; k++)
      gTF[k].Release();
}

// Charge les UT ; un mode est utilisable des que ses 3 UT principales sont pretes
bool LoadMTF()
{
   int extra = InpSRLookback + InpSwingLookbackZone + InpEMASlow + InpATRPeriod + 40;
   for(int k = 0; k < NTF; k++)
   {
      if(gTF[k].used)
         gTF[k].Load(NeedBars(gTF[k].tf, extra));
   }
   bool any = false;
   for(int m = 0; m < NMODES; m++)
      if(ModeReady(m)) any = true;
   return any;
}

//==================================================================//
// SIGNAUX : AJOUT / RESULTATS
//==================================================================//

void AddSignal(const SetupInfo &info, const int i, const datetime t)
{
   if(gSigCount >= MAX_SIGNALS)
   {
      ArrayRemove(gSigs, 0, 1);
      gSigCount--;
   }
   ArrayResize(gSigs, gSigCount + 1, MAX_SIGNALS);
   gSigs[gSigCount].time     = t;
   gSigs[gSigCount].trigTime = info.trigTime;
   gSigs[gSigCount].mode     = info.mode;
   gSigs[gSigCount].index    = i;
   gSigs[gSigCount].dir      = info.dir;
   gSigs[gSigCount].grade    = info.grade;
   gSigs[gSigCount].setup    = info.setup;
   gSigs[gSigCount].score    = (info.dir > 0 ? info.scoreBuy : info.scoreSell);
   gSigs[gSigCount].entry    = info.entry;
   gSigs[gSigCount].sl       = info.sl;
   gSigs[gSigCount].tp       = info.tp;
   gSigs[gSigCount].result   = 0;
   gSigs[gSigCount].scanned  = i;
   gSigs[gSigCount].late     = false;
   gSigCount++;
}

// Verifie TP/SL sur les bougies [scanned+1, limit). Si SL et TP dans la meme bougie -> SL (prudent).
// La bougie en cours (rates_total-1) est verifiee mais jamais figee.
bool UpdateOutcomes(const int limit, const int rates_total, const double &high[], const double &low[])
{
   bool changed = false;
   for(int k = 0; k < gSigCount; k++)
   {
      if(gSigs[k].result != 0)
         continue;
      for(int b = gSigs[k].scanned + 1; b < limit && b < rates_total; b++)
      {
         bool hitSL = (gSigs[k].dir > 0 ? low[b]  <= gSigs[k].sl : high[b] >= gSigs[k].sl);
         bool hitTP = (gSigs[k].dir > 0 ? high[b] >= gSigs[k].tp : low[b]  <= gSigs[k].tp);
         if(hitSL)      { gSigs[k].result = -1; changed = true; break; }
         else if(hitTP) { gSigs[k].result =  1; changed = true; break; }
         if(b < rates_total - 1)
            gSigs[k].scanned = b;
      }
   }
   return changed;
}

// Bloque un signal deja vu, un doublon dans le meme sens ou un signal trop rapproche
string DuplicateBlock(const SetupInfo &info, const datetime barTime)
{
   int li = LastSigIdx(info.mode);
   if(li < 0)
      return "";
   if(gSigs[li].trigTime == info.trigTime)
      return "Signal deja donne sur cette bougie " + TFName(TrigTF(info.mode));
   if(gSigs[li].result == 0 && gSigs[li].dir == info.dir)
      return "Signal " + info.action + " deja en cours";
   long elapsed = (long)(barTime - gSigs[li].time);
   if(InpCooldownBars > 0 && elapsed > 0 && elapsed < (long)InpCooldownBars * PeriodSeconds(TrigTF(info.mode)))
      return "Cooldown apres le dernier signal";
   return "";
}

bool ShowArrowFor(const int m)
{
   if(!InpArrowsFocusOnly || InpTradeMode == TM_AUTO)
      return true;
   return (m == gFocus);
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
   if(gDormant)
      return rates_total;

   int minBars = InpEMASlow + InpATRPeriod + 30;
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
      BarsCalculated(gH_ATR) < rates_total
   )
      return 0;

   // Seulement les nouvelles bougies (avant : tout l'historique a chaque tick = tres lent)
   int toCopy = (prev_calculated <= 0 || prev_calculated > rates_total ? rates_total : rates_total - prev_calculated + 1);
   if(CopyBuffer(gH_E10, 0, 0, toCopy, EMA10Buffer) != toCopy) return 0;
   if(CopyBuffer(gH_E20, 0, 0, toCopy, EMA20Buffer) != toCopy) return 0;
   if(CopyBuffer(gH_E50, 0, 0, toCopy, EMA50Buffer) != toCopy) return 0;
   if(CopyBuffer(gH_ATR, 0, 0, toCopy, gATR) != toCopy) return 0;

   // Spread lisse : un pic d'un tick ne fait plus basculer le conseil ni le verdict
   double spRaw = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   gSpreadAvg = (gSpreadAvg <= 0.0 ? spRaw : gSpreadAvg + (spRaw - gSpreadAvg) * 0.05);
   gSpreadNow = (long)MathRound(gSpreadAvg);

   bool needReload =
      (!gDataReady) ||
      (prev_calculated <= 0) ||
      (rates_total != gLastBarCount) ||
      gCatchingUp ||
      ((GetTickCount() - gLastLoadTick) > 3000);

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

   // Recalcul complet (premier passage, historique recharge, changement de TF)
   if(prev_calculated <= 0 || gLastEvalTime == 0)
   {
      ArrayInitialize(BuyBuffer, EMPTY_VALUE);
      ArrayInitialize(SellBuffer, EMPTY_VALUE);
      gSigCount = 0;
      ArrayResize(gSigs, 0, MAX_SIGNALS);
      for(int m = 0; m < NMODES; m++)
      {
         gBO[m].dir = 0;
         gBO[m].level = 0.0;
         gBO[m].breakTime = 0;
      }
      gLastEvalTime = 0;
      ObjectsDeleteAll(0, OBJ_PREFIX + "SG_", 0, -1);
      start = firstBar;
      gCatchTotal = MathMax(1, lastClosed - firstBar + 1);
   }
   else
   {
      // Une bougie cloturee ne change plus : on n'evalue que les nouvelles
      start = lastClosed + 1;
      while(start > firstBar && time[start - 1] > gLastEvalTime)
         start--;
   }

   int clearFrom = (int)MathMax(0, MathMin(start, prev_calculated - 1));
   for(int k = clearFrom; k < rates_total; k++)
   {
      if(k >= start || k > lastClosed)
      {
         BuyBuffer[k]  = EMPTY_VALUE;
         SellBuffer[k] = EMPTY_VALUE;
      }
   }

   bool marksDirty = (prev_calculated <= 0);
   SetupInfo info;

   // Analyse par tranches : l'historique complet (bougies x 3 modes) est etale sur
   // plusieurs passes pour ne jamais geler le graphique
   // (seulement si le marche cote : sans tick, la tranche suivante n'arriverait jamais)
   int stopAt = lastClosed;
   if(MarketLive() && InpBarsPerCall > 0 && lastClosed - start + 1 > InpBarsPerCall)
      stopAt = start + InpBarsPerCall - 1;
   gCatchingUp = (stopAt < lastClosed);
   if(!gCatchingUp)
      gCatchTotal = 0;
   else
   {
      if(gCatchTotal < lastClosed - start + 1)
         gCatchTotal = lastClosed - start + 1;
      gCatchDone = MathMax(0, gCatchTotal - (lastClosed - stopAt));
   }

   for(int i = start; i <= stopAt; i++)
   {
      if(UpdateOutcomes(i, rates_total, high, low))
         marksDirty = true;

      bool pending = false;
      for(int m = 0; m < NMODES; m++)
      {
         if(!gMode[m].enabled)
            continue;
         if(!EvaluateBar(m, i, rates_total, time, open, high, low, close, tick_volume, spread, info))
         {
            if(i >= lastClosed - 1 && ModeReady(m))
               pending = true;      // donnees pas encore synchronisees : on reessaie au prochain tick
            continue;
         }

         // Bougie deja traitee (reprise apres donnees incompletes) : on redessine sans re-ajouter
         int li = LastSigIdx(m);
         if(info.dir != 0 && li >= 0 && gSigs[li].time == time[i])
         {
            if(ShowArrowFor(m))
            {
               if(info.dir > 0) BuyBuffer[i]  = low[i]  - info.atr * (0.55 + 0.6 * m);
               else             SellBuffer[i] = high[i] + info.atr * (0.55 + 0.6 * m);
            }
            if(i == lastClosed)
               gClosed[m] = info;
            continue;
         }

         if(info.dir != 0)
         {
            string block = DuplicateBlock(info, time[i]);
            if(block != "")
            {
               info.dir    = 0;
               info.action = "WAIT";
               info.reason = block;
            }
         }

         if(info.dir != 0)
         {
            if(ShowArrowFor(m))
            {
               if(info.dir > 0)
                  BuyBuffer[i] = low[i] - info.atr * (0.55 + 0.6 * m);
               else
                  SellBuffer[i] = high[i] + info.atr * (0.55 + 0.6 * m);
            }

            AddSignal(info, i, time[i]);
            marksDirty = true;

            bool alertOn = (InpAlertAllModes || m == gFocus);
            if(i == lastClosed && alertOn && time[i] != gLastAlertTime[m])
            {
               gLastAlertTime[m] = time[i];
               string msg =
                  _Symbol + " " + gMode[m].name + " " + info.action + " (" + GradeText(info.grade) + ")" +
                  " | Score " + IntegerToString(info.dir > 0 ? info.scoreBuy : info.scoreSell) +
                  "/" + IntegerToString(info.maxScore) +
                  " | E " + DoubleToString(info.entry, _Digits) +
                  " | SL " + DoubleToString(info.sl, _Digits) +
                  " | TP " + DoubleToString(info.tp, _Digits);

               if(InpAlertPopup) Alert(msg);
               if(InpAlertSound) PlaySound("alert.wav");
               if(InpAlertPush)  SendNotification(msg);
            }
         }

         if(i == lastClosed)
            gClosed[m] = info;
      }

      if(pending)
         break;
      gLastEvalTime = time[i];
   }

   // Bougie en cours : TP / SL touches en direct
   if(UpdateOutcomes(rates_total, rates_total, high, low))
      marksDirty = true;

   ComputeAdvice();
   PublishSignal();

   // Dessin seulement quand quelque chose a change (nouvelle bougie, signal, TP / SL, mode suivi).
   // Le panneau est sinon rafraichi par le timer (1 fois / s). Avant : tout a chaque tick.
   bool newBar  = (prev_calculated <= 0 || start <= lastClosed);
   bool redraw  = false;
   if(marksDirty)
   {
      DrawSignalMarks(high, low, rates_total);
      redraw = true;
   }
   if(newBar || marksDirty || gFocus != gLevelsFocus)
   {
      gLevelsFocus = gFocus;
      DrawChartLevels(time[rates_total - 1]);
      redraw = true;
   }
   if(DrawKeyLevels(time[rates_total - 1]))
      redraw = true;
   if(newBar || marksDirty)
      if(DrawPanel())
         redraw = true;
   if(redraw)
      ChartRedraw(0);
   return rates_total;
}

void OnTimer()
{
   if(gDormant)
   {
      RemoveSelfIfDuplicate();
      return;
   }
   // Signal de vie de cette instance (anti-doublon)
   GlobalVariableSet(OwnerKey() + "_HB", (double)TimeLocal());

   PublishSignal();      // l'etat "actif / trop tard" change avec le temps et le prix
   if(DrawPanel())       // ne redessine le graphique que si le panneau a change
      ChartRedraw(0);
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(gDormant)
      return;
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      DrawPanel();
      ChartRedraw(0);
   }
   else if(id == CHARTEVENT_OBJECT_CLICK &&
           (sparam == PANEL_PREFIX + "TOGGLE" || sparam == PANEL_PREFIX + "TITLE" || sparam == PANEL_PREFIX + "HDR"))
   {
      gMinimized = !gMinimized;
      gFitValid  = false;
      ObjectsDeleteAll(0, PANEL_PREFIX, 0, -1);
      ResetPanelCache();
      DrawPanel();
      ChartRedraw(0);
   }
}
//+------------------------------------------------------------------+

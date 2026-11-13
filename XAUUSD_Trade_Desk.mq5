//+------------------------------------------------------------------+
//|                                            XAUUSD_Trade_Desk.mq5 |
//|   Assistant de trading XAUUSD : SCALPING (M15 > M5) + INTRADAY   |
//|   (H1 > M15). Panneau en cartes, check-list, risque maitrise.    |
//+------------------------------------------------------------------+
//  PRINCIPE
//  - Uniquement dans le sens de la tendance (jamais de contre-tendance) :
//      biais (H1 / H4) + tendance (M15 / H1) + entree (M5 / M15).
//  - 2 strategies classiques, evaluees sur bougies CLOTUREES (non repeint) :
//      1) Pullback EMA : repli sur l'EMA rapide puis bougie de rejet.
//      2) Cassure + retest : cassure d'un plus haut/bas puis retour valide.
//  - Le risque passe avant le signal : lot calcule sur le SL, limite de
//    perte par jour, nombre maxi de trades, arret apres pertes consecutives,
//    filtre spread / session / news, passage a break-even.
//  - Mode MANUEL par defaut : l'EA n'ouvre rien sans clic + confirmation.
//    Le bouton TRADING AUTO du panneau (ou le parametre Execution) laisse
//    l'EA ouvrir seul les signaux valides, avec les memes garde-fous.
//
//  Aucune strategie ne garantit un gain. Tester en demo / Strategy Tester.
//+------------------------------------------------------------------+
#property copyright   "XAUUSD Trade Desk"
#property version     "1.00"
#property description "Assistant XAUUSD : scalping (M15>M5) + intraday (H1>M15), suivi de tendance"
#property description "Check-list, lot calcule sur le risque, limites journalieres, execution au clic"

#include <Trade/Trade.mqh>

#define OBJ_PREFIX  "XAU_TD_"
#define N_MODES     2
#define N_TF        4
#define N_CHK       7
#define BARS        64
#define PANEL_W     580
#define PANEL_H     566

#define CHK_TREND   0
#define CHK_BIAS    1
#define CHK_ADX     2
#define CHK_ZONE    3
#define CHK_CONFIRM 4
#define CHK_RSI     5
#define CHK_RISK    6

// Couleurs du panneau
#define COL_BG      C'16,20,28'
#define COL_HEAD    C'11,14,21'
#define COL_CARD    C'24,30,42'
#define COL_BOX     C'18,23,33'
#define COL_BORDER  C'42,52,70'
#define COL_TEXT    C'226,232,240'
#define COL_MUTED   C'130,142,160'
#define COL_GOLD    C'240,185,11'
#define COL_GREEN   C'38,194,129'
#define COL_RED     C'239,83,80'
#define COL_AMBER   C'245,166,35'
#define COL_BLUE    C'66,133,244'
#define COL_GREY    C'70,80,98'
#define COL_GREEN_D C'18,60,48'
#define COL_RED_D   C'74,30,32'
#define COL_GREY_D  C'38,46,60'

enum ENUM_EXEC_MODE
{
   EXEC_MANUAL = 0,   // Manuel : clic + confirmation sur le panneau
   EXEC_AUTO   = 1    // Automatique : l'EA ouvre les signaux valides
};

enum ENUM_LOT_MODE
{
   LOT_RISK  = 0,     // Lot calcule sur le risque (%)
   LOT_FIXED = 1      // Lot fixe
};

input group "===== General ====="
input ENUM_EXEC_MODE InpExecMode   = EXEC_MANUAL; // Execution au demarrage (bouton TRADING AUTO sur le panneau)
input bool   InpEnableScalping     = true;        // Mode SCALPING (M15 > M5)
input bool   InpEnableIntraday     = true;        // Mode INTRADAY (H1 > M15)
input long   InpMagic              = 20261112;    // Magic (scalping) ; intraday = magic + 1
input int    InpConfirmSeconds     = 6;           // Delai pour confirmer un clic (s)

input group "===== Risque ====="
input ENUM_LOT_MODE InpLotMode     = LOT_RISK;    // Calcul du lot
input double InpRiskPercent        = 0.5;         // Risque par trade (% du solde)
input double InpFixedLot           = 0.01;        // Lot fixe (si mode lot fixe)
input double InpMaxLot             = 1.0;         // Lot maxi (securite)
input bool   InpAllowMinLot        = false;       // Autoriser le lot mini meme s'il depasse le risque
input double InpMaxDailyLossPct    = 2.0;         // Perte maxi du jour (% du solde, 0 = off)
input int    InpMaxDailyTrades     = 4;           // Trades maxi par jour (0 = illimite)
input int    InpMaxConsecLosses    = 2;           // Arret apres N pertes consecutives (0 = off)
input int    InpMaxPositions       = 1;           // Positions simultanees maxi (0 = illimite)

input group "===== Filtres de marche ====="
input int    InpMaxSpreadPoints    = 45;          // Spread maxi (points, 0 = off)
input double InpMaxSpreadRiskPct   = 15.0;        // Spread maxi en % de la distance du SL (0 = off)
input bool   InpUseSession         = true;        // Filtre horaire (heure serveur) — bouton 24H/24 sur le panneau
input int    InpSessionStartHour   = 9;           // Debut de session
input int    InpSessionEndHour     = 20;          // Fin de session
input int    InpFridayStopHour     = 18;          // Vendredi : plus d'entree apres (0 = off)
input bool   InpUseNews            = true;        // Eviter les news USD a fort impact
input int    InpNewsBeforeMin      = 30;          // Minutes avant la news
input int    InpNewsAfterMin       = 30;          // Minutes apres la news

input group "===== Tendance ====="
input int    InpEMAFast            = 20;          // EMA rapide (zone de repli)
input int    InpEMAMid             = 50;          // EMA moyenne
input int    InpEMASlow            = 200;         // EMA lente
input bool   InpUseBias            = true;        // Le biais (H1 / H4) doit confirmer
input bool   InpUseADX             = true;        // Exiger une tendance assez forte (ADX)
input double InpADXMin             = 20.0;        // ADX mini (UT tendance)
input int    InpADXPeriod          = 14;
input int    InpRSIPeriod          = 14;
input double InpRSIOverbought      = 70.0;        // Pas de BUY au-dessus (anti-chase)
input double InpRSIOversold        = 30.0;        // Pas de SELL en dessous
input int    InpATRPeriod          = 14;

input group "===== Strategies ====="
input bool   InpUsePullback        = true;        // 1) Pullback EMA + rejet
input bool   InpUseRetest          = true;        // 2) Cassure + retest
input double InpTouchATR           = 0.10;        // Pullback : tolerance du contact EMA (x ATR)
input int    InpBreakLookback      = 20;          // Cassure : plus haut/bas des N bougies
input int    InpRetestMaxBars      = 8;           // Retest : bougies maxi apres la cassure
input double InpRetestATR          = 0.25;        // Retest : tolerance autour du niveau (x ATR)
input double InpMaxExtATR          = 1.0;         // Entree refusee si prix trop etire (x ATR)
input int    InpSignalValidBars    = 2;           // Bougies pendant lesquelles le signal reste valable
input int    InpCooldownBars       = 6;           // Bougies mini entre 2 signaux d'un meme mode

input group "===== SL / TP / gestion ====="
input int    InpSLSwingBars        = 5;           // SL derriere le creux/sommet des N bougies
input double InpSLBufferATR        = 0.30;        // Marge du SL (x ATR)
input double InpMinSLATR           = 0.80;        // SL mini (x ATR) — anti bruit
input double InpMaxSLATR           = 2.50;        // SL maxi (x ATR, 0 = off)
input double InpRRScalping         = 1.5;         // Ratio gain/risque scalping
input double InpRRIntraday         = 2.0;         // Ratio gain/risque intraday
input double InpMaxDriftR          = 0.35;        // Ecart maxi prix / entree du signal (x risque)
input bool   InpUseBreakEven       = true;        // Passer le SL a break-even
input double InpBEAtR              = 1.0;         // Break-even quand le gain atteint (x risque)
input int    InpBEOffsetPoints     = 10;          // Break-even : points au-dela du prix d'entree
input int    InpSlippagePoints     = 30;          // Glissement maxi (points)

input group "===== Affichage / alertes ====="
input bool   InpShowPanel          = true;
input bool   InpShowLevels         = true;        // Lignes Entree / SL / TP du signal + fleches
input int    InpPanelX             = 12;
input int    InpPanelY             = 24;
input double InpPanelScale         = 1.00;
input string InpFont               = "Segoe UI";
input string InpFontBold           = "Segoe UI Semibold";
input bool   InpAlertPopup         = true;
input bool   InpAlertSound         = true;
input bool   InpAlertPush          = false;       // Notification push (signal + trade ouvert)
input bool   InpMailOnTrade        = true;        // E-mail quand un trade est ouvert (Outils > Options > Email)

//==================================================================//
// DONNEES
//==================================================================//

// Donnees d'une unite de temps. Index 0 = derniere bougie CLOTUREE.
struct TFData
{
   ENUM_TIMEFRAMES tf;
   int      hFast, hMid, hSlow, hRSI, hADX, hATR;
   bool     ok;
   MqlRates r[];
   double   eFast[], eMid[], eSlow[], rsi[], adx[], atr[];
};

struct ModeState
{
   string   name;
   bool     enabled;
   int      iEntry, iTrend, iBias;
   double   rr;
   // contexte
   int      trend;            // +1 / -1 / 0
   int      bias;             // +1 / -1
   double   adx, rsi;
   int      chk[N_CHK];       // 0 = inconnu, 1 = ok, 2 = non
   string   setup;
   // signal
   bool     sigValid;
   bool     sigTaken;
   int      sigDir;
   string   sigStrat;
   double   sigEntry, sigSL, sigTP;
   datetime sigBar, sigExpire;
   datetime lastEvalBar, lastSigBar;
   datetime confirmUntil;     // heure locale
   string   lastAutoMsg;
};

CTrade    trade;
TFData    gTF[N_TF];
ModeState gM[N_MODES];

bool      gAuto = false;
bool      gUI   = true;
double    gScale = 1.0, gFontScale = 1.0;
datetime  gLastBar = 0;
datetime  gLastLoadTry = 0;

double    gDayClosed = 0.0, gDayStartBal = 0.0;
int       gDayTrades = 0, gConsecLoss = 0;
datetime  gLastDaily = 0;

datetime  gNewsTimes[];
datetime  gNewsLoaded = 0;

string    gGuard = "";
string    gMsg   = "";
datetime  gCloseConfirmUntil = 0;
datetime  gAutoConfirmUntil = 0;
bool      gAllHours = false;          // bouton 24H/24 : ignore les horaires de session
datetime  gHoursConfirmUntil = 0;
bool      gTester = false;
datetime  gLastModify = 0;

string    gCacheName[];
string    gCacheSig[];
bool      gDirty = false;

//==================================================================//
// OUTILS
//==================================================================//

double NormalizePrice(const double p)
{
   double ts = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(ts <= 0.0)
      return NormalizeDouble(p, _Digits);
   return NormalizeDouble(MathRound(p / ts) * ts, _Digits);
}

string TFName(const ENUM_TIMEFRAMES tf)
{
   return StringSubstr(EnumToString(tf), 7);
}

string PriceStr(const double p)
{
   return DoubleToString(p, _Digits);
}

bool IsOurMagic(const long mg)
{
   return (mg == InpMagic || mg == InpMagic + 1);
}

int CountPositions()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;
      n++;
   }
   return n;
}

// Profit flottant des positions de l'EA (mode = -1 : toutes)
double FloatingProfit(const int mode, bool &has)
{
   has = false;
   double p = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long mg = PositionGetInteger(POSITION_MAGIC);
      if(!IsOurMagic(mg)) continue;
      if(mode >= 0 && mg != InpMagic + mode) continue;
      has = true;
      p += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return p;
}

double NormalizeLot(double lot, bool &belowMin)
{
   belowMin = false;
   double vmin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double vstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(vstep <= 0.0) vstep = 0.01;

   lot = MathFloor(lot / vstep + 1e-9) * vstep;
   if(lot < vmin)
   {
      belowMin = true;
      lot = vmin;
   }
   if(InpMaxLot > 0.0 && lot > InpMaxLot)
      lot = MathFloor(InpMaxLot / vstep + 1e-9) * vstep;
   if(lot > vmax) lot = vmax;

   int digits = (int)MathMax(0, MathCeil(-MathLog10(vstep) - 1e-9));
   return NormalizeDouble(lot, digits);
}

double MoneyAt(const int dir, const double lot, const double from, const double to)
{
   double p = 0.0;
   ENUM_ORDER_TYPE type = (dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type, _Symbol, lot, from, to, p))
      return 0.0;
   return p;
}

// Lot pour risquer InpRiskPercent entre price et sl. 0 = impossible.
double CalcLot(const int dir, const double price, const double sl, bool &belowMin)
{
   belowMin = false;
   if(InpLotMode == LOT_FIXED)
   {
      bool dummy;
      return NormalizeLot(InpFixedLot, dummy);
   }
   double loss1 = MathAbs(MoneyAt(dir, 1.0, price, sl));
   if(loss1 <= 0.0)
      return 0.0;
   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   return NormalizeLot(riskMoney / loss1, belowMin);
}

// Bascule AUTO / MANUEL faite depuis le panneau : memorisee dans une variable
// globale du terminal pour survivre a un changement d'unite de temps.
string AutoKey()
{
   return "XTD_" + _Symbol + "_" + IntegerToString(InpMagic) + "_AUTO";
}

void SetAuto(const bool on)
{
   gAuto = on;
   gAutoConfirmUntil = 0;
   for(int k = 0; k < N_MODES; k++)
   {
      gM[k].confirmUntil = 0;
      gM[k].lastAutoMsg  = "";
   }
   if(!gTester)
      GlobalVariableSet(AutoKey(), (on ? 1.0 : 0.0));
   gMsg = (on ? "Mode AUTOMATIQUE : l'EA ouvre seul les signaux valides"
              : "Mode MANUEL : aucun trade sans clic + confirmation");
   Print("Trade Desk : ", gMsg);
}

// Bouton 24H/24 : autorise les entrees a toute heure (les autres garde-fous restent actifs)
string AllHoursKey()
{
   return "XTD_" + _Symbol + "_" + IntegerToString(InpMagic) + "_24H";
}

void SetAllHours(const bool on)
{
   gAllHours = on;
   gHoursConfirmUntil = 0;
   if(!gTester)
      GlobalVariableSet(AllHoursKey(), (on ? 1.0 : 0.0));
   gMsg = (on ? "24H/24 actif : entrees autorisees a toute heure (spread et news toujours filtres)"
              : StringFormat("Horaires de session retablis (%02dh-%02dh serveur)", InpSessionStartHour, InpSessionEndHour));
   Print("Trade Desk : ", gMsg);
}

//==================================================================//
// STATISTIQUES DU JOUR
//==================================================================//

datetime DayStart(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   return StructToTime(dt);
}

void RefreshDaily()
{
   datetime now = TimeCurrent();
   if(now <= 0) now = TimeTradeServer();
   gLastDaily = TimeLocal();

   datetime day0 = DayStart(now);
   double closed = 0.0;
   int trades = 0, consec = 0;

   // Fenetre elargie pour retrouver l'ouverture des positions cloturees aujourd'hui
   if(HistorySelect(day0 - 7 * 86400, now + 86400))
   {
      long ids[];
      int  nIds = 0;
      int  total = HistoryDealsTotal();

      for(int i = 0; i < total; i++)
      {
         ulong tk = HistoryDealGetTicket(i);
         if(tk == 0) continue;
         if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
         if(!IsOurMagic(HistoryDealGetInteger(tk, DEAL_MAGIC))) continue;

         ArrayResize(ids, nIds + 1, 32);
         ids[nIds++] = HistoryDealGetInteger(tk, DEAL_POSITION_ID);

         if((datetime)HistoryDealGetInteger(tk, DEAL_TIME) >= day0)
         {
            trades++;
            closed += HistoryDealGetDouble(tk, DEAL_COMMISSION);
         }
      }

      for(int i = 0; i < total; i++)
      {
         ulong tk = HistoryDealGetTicket(i);
         if(tk == 0) continue;
         if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN) continue;
         if((datetime)HistoryDealGetInteger(tk, DEAL_TIME) < day0) continue;

         long pid = HistoryDealGetInteger(tk, DEAL_POSITION_ID);
         bool ours = false;
         for(int j = 0; j < nIds; j++)
            if(ids[j] == pid) { ours = true; break; }
         if(!ours) continue;

         double p = HistoryDealGetDouble(tk, DEAL_PROFIT) + HistoryDealGetDouble(tk, DEAL_SWAP)
                  + HistoryDealGetDouble(tk, DEAL_COMMISSION);
         closed += p;
         if(p < 0.0) consec++;
         else if(p > 0.0) consec = 0;
      }
   }

   gDayClosed   = closed;
   gDayTrades   = trades;
   gConsecLoss  = consec;
   gDayStartBal = AccountInfoDouble(ACCOUNT_BALANCE) - closed;
   if(gDayStartBal <= 0.0)
      gDayStartBal = AccountInfoDouble(ACCOUNT_BALANCE);
}

double DayPnL()
{
   bool has;
   return gDayClosed + FloatingProfit(-1, has);
}

double DayLossPct()
{
   double pnl = DayPnL();
   if(pnl >= 0.0 || gDayStartBal <= 0.0)
      return 0.0;
   return -pnl / gDayStartBal * 100.0;
}

//==================================================================//
// FILTRES : SESSION / NEWS / GARDE-FOUS
//==================================================================//

bool InSession(string &why)
{
   why = "";
   if(!InpUseSession)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
   {
      why = "Week-end";
      return false;
   }
   if(gAllHours)
      return true;
   if(InpFridayStopHour > 0 && dt.day_of_week == 5 && dt.hour >= InpFridayStopHour)
   {
      why = "Vendredi soir : plus d'entree";
      return false;
   }

   bool in;
   if(InpSessionStartHour <= InpSessionEndHour)
      in = (dt.hour >= InpSessionStartHour && dt.hour < InpSessionEndHour);
   else
      in = (dt.hour >= InpSessionStartHour || dt.hour < InpSessionEndHour);

   if(!in)
      why = StringFormat("Hors session (%02dh-%02dh serveur)", InpSessionStartHour, InpSessionEndHour);
   return in;
}

void RefreshNews()
{
   if(!InpUseNews || MQLInfoInteger(MQL_TESTER))
      return;

   datetime now = TimeTradeServer();
   if(gNewsLoaded != 0 && now - gNewsLoaded < 600)
      return;
   gNewsLoaded = now;

   ArrayResize(gNewsTimes, 0);
   MqlCalendarValue vals[];
   CalendarValueHistory(vals, now - 3600, now + 86400, NULL, "USD");
   int n = ArraySize(vals);
   for(int i = 0; i < n; i++)
   {
      MqlCalendarEvent ev;
      if(!CalendarEventById(vals[i].event_id, ev)) continue;
      if(ev.importance != CALENDAR_IMPORTANCE_HIGH) continue;
      int k = ArraySize(gNewsTimes);
      ArrayResize(gNewsTimes, k + 1, 16);
      gNewsTimes[k] = vals[i].time;
   }
}

bool NewsBlocked()
{
   if(!InpUseNews)
      return false;
   datetime now = TimeTradeServer();
   int n = ArraySize(gNewsTimes);
   for(int i = 0; i < n; i++)
      if(now >= gNewsTimes[i] - InpNewsBeforeMin * 60 && now <= gNewsTimes[i] + InpNewsAfterMin * 60)
         return true;
   return false;
}

string NextNewsText()
{
   if(!InpUseNews)
      return "filtre off";
   if(MQLInfoInteger(MQL_TESTER))
      return "n/a (tester)";

   datetime now = TimeTradeServer();
   datetime best = 0;
   int n = ArraySize(gNewsTimes);
   for(int i = 0; i < n; i++)
      if(gNewsTimes[i] > now && (best == 0 || gNewsTimes[i] < best))
         best = gNewsTimes[i];
   if(best == 0)
      return "aucune (24h)";

   int mins = (int)((best - now) / 60);
   if(mins >= 120)
      return StringFormat("%s (%dh)", TimeToString(best, TIME_MINUTES), mins / 60);
   return StringFormat("%s (%d min)", TimeToString(best, TIME_MINUTES), mins);
}

// Raison qui interdit d'ouvrir un trade maintenant ("" = rien ne bloque)
string GuardReason()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
      return "Algo Trading desactive dans MT5";
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
      return "Trading algo non autorise pour cet EA";
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      return "Trading non autorise sur ce compte";

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk) || tk.ask <= 0.0 || tk.bid <= 0.0)
      return "Pas de cotation";

   string why;
   if(!InSession(why))
      return why;

   double spr = (tk.ask - tk.bid) / _Point;
   if(InpMaxSpreadPoints > 0 && spr > InpMaxSpreadPoints)
      return StringFormat("Spread trop eleve (%.0f pts)", spr);

   if(NewsBlocked())
      return "News USD importante proche";

   if(InpMaxDailyLossPct > 0.0 && DayLossPct() >= InpMaxDailyLossPct)
      return "Limite de perte du jour atteinte";
   if(InpMaxDailyTrades > 0 && gDayTrades >= InpMaxDailyTrades)
      return "Nombre maxi de trades du jour atteint";
   if(InpMaxConsecLosses > 0 && gConsecLoss >= InpMaxConsecLosses)
      return "Pertes consecutives : stop pour aujourd'hui";
   if(InpMaxPositions > 0 && CountPositions() >= InpMaxPositions)
      return "Position deja ouverte";

   return "";
}

//==================================================================//
// CHARGEMENT DES DONNEES
//==================================================================//

bool InitTF(TFData &d, const ENUM_TIMEFRAMES tf)
{
   d.tf    = tf;
   d.ok    = false;
   d.hFast = iMA(_Symbol, tf, InpEMAFast, 0, MODE_EMA, PRICE_CLOSE);
   d.hMid  = iMA(_Symbol, tf, InpEMAMid,  0, MODE_EMA, PRICE_CLOSE);
   d.hSlow = iMA(_Symbol, tf, InpEMASlow, 0, MODE_EMA, PRICE_CLOSE);
   d.hRSI  = iRSI(_Symbol, tf, InpRSIPeriod, PRICE_CLOSE);
   d.hADX  = iADX(_Symbol, tf, InpADXPeriod);
   d.hATR  = iATR(_Symbol, tf, InpATRPeriod);

   ArraySetAsSeries(d.r, true);
   ArraySetAsSeries(d.eFast, true);
   ArraySetAsSeries(d.eMid, true);
   ArraySetAsSeries(d.eSlow, true);
   ArraySetAsSeries(d.rsi, true);
   ArraySetAsSeries(d.adx, true);
   ArraySetAsSeries(d.atr, true);

   return (d.hFast != INVALID_HANDLE && d.hMid != INVALID_HANDLE && d.hSlow != INVALID_HANDLE &&
           d.hRSI != INVALID_HANDLE && d.hADX != INVALID_HANDLE && d.hATR != INVALID_HANDLE);
}

void ReleaseH(int &h)
{
   if(h != INVALID_HANDLE)
   {
      IndicatorRelease(h);
      h = INVALID_HANDLE;
   }
}

// Copie a partir du shift 1 : on ne lit jamais la bougie en cours.
bool LoadTF(TFData &d)
{
   d.ok = false;
   if(CopyRates(_Symbol, d.tf, 1, BARS, d.r) != BARS) return false;
   if(CopyBuffer(d.hFast, 0, 1, BARS, d.eFast) != BARS) return false;
   if(CopyBuffer(d.hMid,  0, 1, BARS, d.eMid)  != BARS) return false;
   if(CopyBuffer(d.hSlow, 0, 1, BARS, d.eSlow) != BARS) return false;
   if(CopyBuffer(d.hRSI,  0, 1, BARS, d.rsi)   != BARS) return false;
   if(CopyBuffer(d.hADX,  0, 1, BARS, d.adx)   != BARS) return false;
   if(CopyBuffer(d.hATR,  0, 1, BARS, d.atr)   != BARS) return false;
   if(d.eSlow[0] <= 0.0 || d.eSlow[0] == EMPTY_VALUE || d.atr[0] <= 0.0 || d.atr[0] == EMPTY_VALUE)
      return false;
   d.ok = true;
   return true;
}

bool LoadAll()
{
   bool ok = true;
   for(int i = 0; i < N_TF; i++)
      if(!LoadTF(gTF[i]))
         ok = false;
   return ok;
}

//==================================================================//
// STRATEGIES (bougies cloturees uniquement)
//==================================================================//

int TrendDir(const TFData &t)
{
   double c = t.r[0].close;
   if(c > t.eMid[0] && t.eMid[0] > t.eSlow[0] && t.eMid[0] > t.eMid[3]) return 1;
   if(c < t.eMid[0] && t.eMid[0] < t.eSlow[0] && t.eMid[0] < t.eMid[3]) return -1;
   return 0;
}

// 1) Pullback : EMA alignees, repli sur l'EMA rapide, bougie de rejet dans le sens
void SetupPullback(const TFData &e, const int dir, const double atr, bool &zone, bool &confirm)
{
   zone = false;
   confirm = false;
   if(!InpUsePullback)
      return;

   bool aligned = (dir > 0 ? e.eFast[0] > e.eMid[0] : e.eFast[0] < e.eMid[0]);
   if(!aligned)
      return;

   bool touched = false, held = true;
   for(int i = 0; i < 3; i++)
   {
      if(dir > 0)
      {
         if(e.r[i].low <= e.eFast[i] + InpTouchATR * atr) touched = true;
         if(e.r[i].close < e.eMid[i]) held = false;
      }
      else
      {
         if(e.r[i].high >= e.eFast[i] - InpTouchATR * atr) touched = true;
         if(e.r[i].close > e.eMid[i]) held = false;
      }
   }
   zone = (touched && held);
   if(!zone)
      return;

   double c = e.r[0].close, o = e.r[0].open;
   if(dir > 0)
      confirm = (c > o && c > e.eFast[0] && c > e.r[1].high && (c - e.eFast[0]) <= InpMaxExtATR * atr);
   else
      confirm = (c < o && c < e.eFast[0] && c < e.r[1].low && (e.eFast[0] - c) <= InpMaxExtATR * atr);
}

// 2) Cassure + retest : cloture au-dela du plus haut/bas des N bougies,
//    le niveau tient, le prix y revient puis repart dans le sens.
void SetupRetest(const TFData &e, const int dir, const double atr, bool &zone, bool &confirm)
{
   zone = false;
   confirm = false;
   if(!InpUseRetest)
      return;

   int n = ArraySize(e.r);
   for(int b = 1; b <= InpRetestMaxBars; b++)
   {
      if(b + InpBreakLookback >= n)
         break;

      double lv = (dir > 0 ? e.r[b + 1].high : e.r[b + 1].low);
      for(int j = b + 2; j <= b + InpBreakLookback; j++)
         lv = (dir > 0 ? MathMax(lv, e.r[j].high) : MathMin(lv, e.r[j].low));

      bool brk = (dir > 0 ? e.r[b].close > lv + 0.05 * atr : e.r[b].close < lv - 0.05 * atr);
      if(!brk)
         continue;

      bool held = true;
      for(int i = 0; i < b; i++)
         if(dir > 0 ? e.r[i].close < lv - 0.20 * atr : e.r[i].close > lv + 0.20 * atr)
            held = false;
      if(!held)
         continue;

      zone = true;   // cassure valide, on attend le retest

      bool retest = (dir > 0 ? e.r[0].low <= lv + InpRetestATR * atr : e.r[0].high >= lv - InpRetestATR * atr);
      if(!retest && b >= 2)
         retest = (dir > 0 ? e.r[1].low <= lv + InpRetestATR * atr : e.r[1].high >= lv - InpRetestATR * atr);
      if(!retest)
         return;

      double c = e.r[0].close, o = e.r[0].open;
      if(dir > 0)
         confirm = (c > lv && c > o && (c - lv) <= InpMaxExtATR * atr);
      else
         confirm = (c < lv && c < o && (lv - c) <= InpMaxExtATR * atr);
      return;
   }
}

// SL derriere le dernier creux/sommet + marge, borne en ATR ; TP = RR x risque
bool BuildLevels(const TFData &e, const int dir, const double atr, const double rr,
                 const double entry, double &sl, double &tp)
{
   double ext = (dir > 0 ? e.r[0].low : e.r[0].high);
   for(int i = 1; i < InpSLSwingBars && i < ArraySize(e.r); i++)
      ext = (dir > 0 ? MathMin(ext, e.r[i].low) : MathMax(ext, e.r[i].high));

   sl = (dir > 0 ? ext - InpSLBufferATR * atr : ext + InpSLBufferATR * atr);
   double risk = (dir > 0 ? entry - sl : sl - entry);
   if(risk < InpMinSLATR * atr)
   {
      risk = InpMinSLATR * atr;
      sl = (dir > 0 ? entry - risk : entry + risk);
   }
   tp = (dir > 0 ? entry + rr * risk : entry - rr * risk);
   sl = NormalizePrice(sl);
   tp = NormalizePrice(tp);

   if(InpMaxSLATR > 0.0 && risk > InpMaxSLATR * atr)
      return false;
   return true;
}

void EvaluateMode(const int k, const TFData &e, const TFData &t, const TFData &b)
{
   for(int i = 0; i < N_CHK; i++)
      gM[k].chk[i] = 0;
   gM[k].setup = "-";
   gM[k].trend = 0;

   if(!gM[k].enabled || !e.ok || !t.ok || !b.ok)
      return;

   double atr = e.atr[0];
   gM[k].trend = TrendDir(t);
   gM[k].bias  = (b.r[0].close > b.eSlow[0] ? 1 : -1);
   gM[k].adx   = t.adx[0];
   gM[k].rsi   = e.rsi[0];

   gM[k].chk[CHK_TREND] = (gM[k].trend != 0 ? 1 : 2);
   if(gM[k].trend == 0)
   {
      gM[k].setup = "Pas de tendance claire : on attend";
      gM[k].lastEvalBar = e.r[0].time;
      return;
   }

   int dir = gM[k].trend;
   gM[k].chk[CHK_BIAS] = ((!InpUseBias || gM[k].bias == dir) ? 1 : 2);
   gM[k].chk[CHK_ADX]  = ((!InpUseADX || gM[k].adx >= InpADXMin) ? 1 : 2);

   bool rsiOk = (dir > 0 ? (gM[k].rsi >= 45.0 && gM[k].rsi <= InpRSIOverbought)
                         : (gM[k].rsi <= 55.0 && gM[k].rsi >= InpRSIOversold));
   gM[k].chk[CHK_RSI] = (rsiOk ? 1 : 2);

   bool zA, cA, zB, cB;
   SetupPullback(e, dir, atr, zA, cA);
   SetupRetest(e, dir, atr, zB, cB);

   string strat = "";
   if(zA && cA)      strat = "Pullback EMA";
   else if(zB && cB) strat = "Cassure + retest";

   bool zone = (zA || zB);
   gM[k].chk[CHK_ZONE]    = (zone ? 1 : 2);
   gM[k].chk[CHK_CONFIRM] = (strat != "" ? 1 : 2);

   double entry = e.r[0].close, sl = 0.0, tp = 0.0;
   bool riskOk = BuildLevels(e, dir, atr, gM[k].rr, entry, sl, tp);
   gM[k].chk[CHK_RISK] = (riskOk ? 1 : 2);

   if(strat != "")      gM[k].setup = strat;
   else if(zone)        gM[k].setup = "Zone atteinte : attente de confirmation";
   else                 gM[k].setup = (dir > 0 ? "Attente d'un repli pour acheter" : "Attente d'un rebond pour vendre");

   bool all = (strat != "" && riskOk && rsiOk && gM[k].chk[CHK_BIAS] == 1 && gM[k].chk[CHK_ADX] == 1);

   datetime bt  = e.r[0].time;
   int      sec = PeriodSeconds(e.tf);
   if(all && bt > gM[k].lastEvalBar)
   {
      bool cooled = (gM[k].lastSigBar == 0 || (bt - gM[k].lastSigBar) >= InpCooldownBars * sec);
      datetime expire = bt + (1 + InpSignalValidBars) * sec;
      if(cooled && expire > TimeCurrent())
      {
         gM[k].sigValid   = true;
         gM[k].sigTaken   = false;
         gM[k].sigDir     = dir;
         gM[k].sigStrat   = strat;
         gM[k].sigEntry   = entry;
         gM[k].sigSL      = sl;
         gM[k].sigTP      = tp;
         gM[k].sigBar     = bt;
         gM[k].sigExpire  = expire;
         gM[k].lastSigBar = bt;
         gM[k].confirmUntil = 0;
         gM[k].lastAutoMsg  = "";
         OnNewSignal(k);
      }
   }
   gM[k].lastEvalBar = bt;
}

void OnNewSignal(const int k)
{
   string msg = StringFormat("Trade Desk %s : %s %s (%s)  Entree %s  SL %s  TP %s",
                             _Symbol, gM[k].name, (gM[k].sigDir > 0 ? "BUY" : "SELL"), gM[k].sigStrat,
                             PriceStr(gM[k].sigEntry), PriceStr(gM[k].sigSL), PriceStr(gM[k].sigTP));
   Print(msg);
   if(MQLInfoInteger(MQL_TESTER))
      return;
   if(InpAlertPopup)      Alert(msg);
   else if(InpAlertSound) PlaySound("alert.wav");
   if(InpAlertPush)       SendNotification(msg);

   if(gUI && InpShowLevels)
   {
      string name = OBJ_PREFIX + "ARW_" + IntegerToString(k) + "_" + IntegerToString((long)gM[k].sigBar);
      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, (gM[k].sigDir > 0 ? OBJ_ARROW_BUY : OBJ_ARROW_SELL), 0, gM[k].sigBar, gM[k].sigEntry);
         ObjectSetInteger(0, name, OBJPROP_COLOR, (gM[k].sigDir > 0 ? COL_GREEN : COL_RED));
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
         ObjectSetString(0, name, OBJPROP_TOOLTIP, gM[k].name + " " + gM[k].sigStrat);
         gDirty = true;
      }
   }
}

void ExpireSignals()
{
   MqlTick tk;
   bool hasTick = SymbolInfoTick(_Symbol, tk);
   datetime now = TimeCurrent();

   for(int k = 0; k < N_MODES; k++)
   {
      if(!gM[k].sigValid)
         continue;
      bool dead = (now >= gM[k].sigExpire);
      if(!dead && hasTick && !gM[k].sigTaken)
      {
         // Le marche a deja touche le SL ou le TP : le signal n'a plus de sens
         if(gM[k].sigDir > 0 && (tk.bid <= gM[k].sigSL || tk.bid >= gM[k].sigTP)) dead = true;
         if(gM[k].sigDir < 0 && (tk.ask >= gM[k].sigSL || tk.ask <= gM[k].sigTP)) dead = true;
      }
      if(dead)
      {
         gM[k].sigValid = false;
         gM[k].confirmUntil = 0;
      }
   }
}

//==================================================================//
// EXECUTION
//==================================================================//

// Prepare l'ordre au prix actuel. Retourne "" si tout est bon, sinon la raison du refus.
string PrepareOrder(const int k, double &price, double &sl, double &tp, double &lot)
{
   price = 0.0; sl = 0.0; tp = 0.0; lot = 0.0;
   if(!gM[k].sigValid || gM[k].sigTaken)
      return "Aucun signal actif";

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk) || tk.ask <= 0.0)
      return "Pas de cotation";

   int dir = gM[k].sigDir;
   price = (dir > 0 ? tk.ask : tk.bid);
   sl    = gM[k].sigSL;

   double planned = MathAbs(gM[k].sigEntry - gM[k].sigSL);
   double risk    = (dir > 0 ? price - sl : sl - price);
   if(risk <= 0.0 || planned <= 0.0)
      return "Signal depasse";
   if(MathAbs(price - gM[k].sigEntry) > InpMaxDriftR * planned)
      return "Prix trop eloigne de l'entree du signal";

   double spread = tk.ask - tk.bid;
   if(InpMaxSpreadRiskPct > 0.0 && spread > risk * InpMaxSpreadRiskPct / 100.0)
      return "Spread trop cher par rapport au SL";

   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(risk <= minDist)
      return "SL trop proche (stops level du broker)";

   tp = NormalizePrice(dir > 0 ? price + gM[k].rr * risk : price - gM[k].rr * risk);

   bool belowMin;
   lot = CalcLot(dir, price, sl, belowMin);
   if(lot <= 0.0)
      return "Calcul du lot impossible";
   if(belowMin && !InpAllowMinLot)
      return "Lot mini du broker > risque autorise";

   double margin = 0.0;
   ENUM_ORDER_TYPE type = (dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(OrderCalcMargin(type, _Symbol, lot, price, margin) && margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
      return "Marge libre insuffisante";

   return "";
}

// Previent par e-mail / push qu'un trade vient d'etre ouvert
void NotifyTradeOpened(const int k, const int dir, const double lot, const double price,
                       const double sl, const double tp)
{
   if(gTester)
      return;

   string ccy  = AccountInfoString(ACCOUNT_CURRENCY);
   string side = (dir > 0 ? "BUY" : "SELL");
   string subject = StringFormat("Trade Desk %s : %s %.2f lot (%s)", _Symbol, side, lot, gM[k].name);

   if(InpMailOnTrade)
   {
      if(TerminalInfoInteger(TERMINAL_EMAIL_ENABLED))
      {
         string body = StringFormat("Un trade vient d'etre ouvert (%s).\r\n\r\n", (gAuto ? "mode automatique" : "clic manuel"));
         body += "Symbole    : " + _Symbol + "\r\n";
         body += "Mode       : " + gM[k].name + "\r\n";
         body += "Strategie  : " + gM[k].sigStrat + "\r\n";
         body += "Sens       : " + side + "\r\n";
         body += StringFormat("Lot        : %.2f\r\n", lot);
         body += "Entree     : " + PriceStr(price) + "\r\n";
         body += "Stop loss  : " + PriceStr(sl) + "\r\n";
         body += "Take profit: " + PriceStr(tp) + "\r\n";
         body += StringFormat("Risque     : %.2f %s\r\n", MathAbs(MoneyAt(dir, lot, price, sl)), ccy);
         body += StringFormat("Gain vise  : %.2f %s\r\n", MoneyAt(dir, lot, price, tp), ccy);
         body += StringFormat("Solde      : %.2f %s\r\n", AccountInfoDouble(ACCOUNT_BALANCE), ccy);
         body += "Heure serveur : " + TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES) + "\r\n";
         body += StringFormat("Trades du jour : %d\r\n", gDayTrades + 1);
         if(!SendMail(subject, body))
            Print("Trade Desk : envoi de l'e-mail impossible, erreur ", GetLastError());
      }
      else
         Print("Trade Desk : e-mail non envoye, active-le dans MT5 (Outils > Options > Email)");
   }

   if(InpAlertPush && TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED))
      SendNotification(subject + "  Entree " + PriceStr(price) + "  SL " + PriceStr(sl) + "  TP " + PriceStr(tp));
}

// Retourne "" si l'ordre est passe, sinon la raison.
string ExecuteSignal(const int k)
{
   string g = GuardReason();
   if(g != "")
      return g;

   double price, sl, tp, lot;
   string why = PrepareOrder(k, price, sl, tp, lot);
   if(why != "")
      return why;

   int dir = gM[k].sigDir;
   trade.SetExpertMagicNumber(InpMagic + k);
   string comment = "TD " + gM[k].name;

   bool sent = (dir > 0 ? trade.Buy(lot, _Symbol, 0.0, sl, tp, comment)
                        : trade.Sell(lot, _Symbol, 0.0, sl, tp, comment));
   uint rc = trade.ResultRetcode();

   // Envoye ou refuse par le serveur : dans les deux cas on ne retente pas ce signal
   gM[k].sigTaken = true;
   gM[k].confirmUntil = 0;

   if(!sent || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL && rc != TRADE_RETCODE_PLACED))
      return StringFormat("Ordre refuse : %s (%d)", trade.ResultRetcodeDescription(), (int)rc);

   PrintFormat("Trade Desk : %s %s %.2f lot  SL %s  TP %s", gM[k].name, (dir > 0 ? "BUY" : "SELL"),
               lot, PriceStr(sl), PriceStr(tp));
   double fill = trade.ResultPrice();
   NotifyTradeOpened(k, dir, lot, (fill > 0.0 ? fill : price), sl, tp);
   RefreshDaily();
   return "";
}

void ManagePositions()
{
   if(!InpUseBreakEven)
      return;
   if(TimeLocal() - gLastModify < 2)
      return;

   double stops = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;

      long   type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      if(sl <= 0.0)
         continue;

      if(type == POSITION_TYPE_BUY && sl < open)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double newSL = NormalizePrice(open + InpBEOffsetPoints * _Point);
         if(bid - open >= InpBEAtR * (open - sl) && bid - newSL > stops)
         {
            gLastModify = TimeLocal();
            if(trade.PositionModify(tk, newSL, tp))
               gMsg = "SL passe a break-even";
         }
      }
      else if(type == POSITION_TYPE_SELL && sl > open)
      {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double newSL = NormalizePrice(open - InpBEOffsetPoints * _Point);
         if(open - ask >= InpBEAtR * (sl - open) && newSL - ask > stops)
         {
            gLastModify = TimeLocal();
            if(trade.PositionModify(tk, newSL, tp))
               gMsg = "SL passe a break-even";
         }
      }
   }
}

// Bouton BREAK-EVEN : securise toutes les positions deja en gain
void ForceBreakEven()
{
   int done = 0;
   double stops = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;

      long   type = PositionGetInteger(POSITION_TYPE);
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);

      if(type == POSITION_TYPE_BUY)
      {
         double newSL = NormalizePrice(open + InpBEOffsetPoints * _Point);
         if(SymbolInfoDouble(_Symbol, SYMBOL_BID) - newSL > stops && (sl <= 0.0 || sl < newSL))
            if(trade.PositionModify(tk, newSL, tp)) done++;
      }
      else
      {
         double newSL = NormalizePrice(open - InpBEOffsetPoints * _Point);
         if(newSL - SymbolInfoDouble(_Symbol, SYMBOL_ASK) > stops && (sl <= 0.0 || sl > newSL))
            if(trade.PositionModify(tk, newSL, tp)) done++;
      }
   }
   gMsg = (done > 0 ? StringFormat("Break-even applique sur %d position(s)", done)
                    : "Break-even : aucune position assez en gain");
}

void CloseAll()
{
   int done = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!IsOurMagic(PositionGetInteger(POSITION_MAGIC))) continue;
      if(trade.PositionClose(tk)) done++;
   }
   gMsg = StringFormat("%d position(s) fermee(s)", done);
}

//==================================================================//
// PANNEAU
//==================================================================//

int PX(const double v) { return (int)MathRound(v * gScale); }
int FS(const int v)    { return (int)MathMax(6, MathRound(v * gFontScale)); }

bool Changed(const string name, const string sig)
{
   int n = ArraySize(gCacheName);
   for(int i = 0; i < n; i++)
   {
      if(gCacheName[i] == name)
      {
         if(gCacheSig[i] == sig)
            return false;
         gCacheSig[i] = sig;
         return true;
      }
   }
   ArrayResize(gCacheName, n + 1, 128);
   ArrayResize(gCacheSig, n + 1, 128);
   gCacheName[n] = name;
   gCacheSig[n]  = sig;
   return true;
}

void Rect(const string id, const int x, const int y, const int w, const int h, const color bg, const color bd)
{
   string name = OBJ_PREFIX + id;
   int px = InpPanelX + PX(x), py = InpPanelY + PX(y), pw = MathMax(1, PX(w)), ph = MathMax(1, PX(h));
   if(!Changed(name, StringFormat("%d|%d|%d|%d|%d|%d", px, py, pw, ph, (int)bg, (int)bd)))
      return;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, px);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, py);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, pw);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, ph);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, bd);
   gDirty = true;
}

void Text(const string id, string txt, const int x, const int y, const int fs, const color clr,
          const bool bold = false, const ENUM_ANCHOR_POINT anchor = ANCHOR_LEFT_UPPER)
{
   if(txt == "")
      txt = " ";
   string name = OBJ_PREFIX + id;
   int px = InpPanelX + PX(x), py = InpPanelY + PX(y), f = FS(fs);
   if(!Changed(name, StringFormat("%s|%d|%d|%d|%d|%d|%d", txt, px, py, f, (int)clr, (int)bold, (int)anchor)))
      return;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, px);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, py);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, f);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_FONT, (bold ? InpFontBold : InpFont));
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   gDirty = true;
}

void Button(const string id, const string txt, const int x, const int y, const int w, const int h,
            const color bg, const color fg)
{
   string name = OBJ_PREFIX + id;
   int px = InpPanelX + PX(x), py = InpPanelY + PX(y), pw = PX(w), ph = PX(h), f = FS(8);
   if(!Changed(name, StringFormat("%s|%d|%d|%d|%d|%d|%d|%d", txt, px, py, pw, ph, f, (int)bg, (int)fg)))
      return;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, px);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, py);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, pw);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, ph);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, f);
   ObjectSetInteger(0, name, OBJPROP_COLOR, fg);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ObjectSetString(0, name, OBJPROP_FONT, InpFontBold);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   gDirty = true;
}

void HLine(const string id, const double price, const color clr, const ENUM_LINE_STYLE style, const string tip)
{
   string name = OBJ_PREFIX + id;
   if(!Changed(name, PriceStr(price) + "|" + IntegerToString((int)clr)))
      return;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
   gDirty = true;
}

void Remove(const string id)
{
   string name = OBJ_PREFIX + id;
   if(!Changed(name, "none"))
      return;
   if(ObjectFind(0, name) >= 0)
   {
      ObjectDelete(0, name);
      gDirty = true;
   }
}

void Tile(const string id, const int x, const int y, const int w, const string label, const string value, const color clr)
{
   Rect(id + "_b", x, y, w, 42, COL_CARD, COL_BORDER);
   Text(id + "_l", label, x + 10, y + 5, 7, COL_MUTED);
   Text(id + "_v", value, x + 10, y + 19, 10, clr, true);
}

void ComputeScale()
{
   double dpi = (double)TerminalInfoInteger(TERMINAL_SCREEN_DPI) / 96.0;
   if(dpi <= 0.0) dpi = 1.0;
   double scale = MathMax(0.5, InpPanelScale) * dpi;
   double fit = 1.0;
   long chartH = ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   long chartW = ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   double availH = (double)chartH - InpPanelY - 6;
   double availW = (double)chartW - InpPanelX - 6;
   if(availH > 150 && PANEL_H * scale > availH) fit = MathMin(fit, availH / (PANEL_H * scale));
   if(availW > 150 && PANEL_W * scale > availW) fit = MathMin(fit, availW / (PANEL_W * scale));
   fit = MathMax(0.55, fit);
   gScale     = scale * fit;
   gFontScale = MathMax(0.5, InpPanelScale) * fit;
}

string TrendWord(const int d)
{
   if(d > 0) return "HAUSSE";
   if(d < 0) return "BAISSE";
   return "NEUTRE";
}

void DrawModeCard(const int k, const int x, const int y, const int w, const string guard)
{
   string p = "M" + IntegerToString(k) + "_";
   int h = 286;
   Rect(p + "bg", x, y, w, h, COL_CARD, COL_BORDER);
   Text(p + "name", gM[k].name, x + 10, y + 8, 11, COL_TEXT, true);
   string tfs = TFName(gTF[gM[k].iBias].tf) + " > " + TFName(gTF[gM[k].iTrend].tf) + " > " + TFName(gTF[gM[k].iEntry].tf);
   Text(p + "tf", tfs, x + w - 10, y + 11, 8, COL_MUTED, false, ANCHOR_RIGHT_UPPER);

   bool ready = (gM[k].enabled && gTF[gM[k].iEntry].ok && gTF[gM[k].iTrend].ok && gTF[gM[k].iBias].ok);

   // Bandeau de tendance
   color bbg = COL_GREY_D, bfg = COL_MUTED;
   string btxt = "DONNEES EN COURS DE CHARGEMENT";
   if(!gM[k].enabled) btxt = "MODE DESACTIVE";
   else if(ready)
   {
      if(gM[k].trend > 0)      { bbg = COL_GREEN_D; bfg = COL_GREEN; btxt = "TENDANCE HAUSSIERE : ACHATS SEULEMENT"; }
      else if(gM[k].trend < 0) { bbg = COL_RED_D;   bfg = COL_RED;   btxt = "TENDANCE BAISSIERE : VENTES SEULEMENT"; }
      else                     { btxt = "PAS DE TENDANCE : ON NE TRADE PAS"; }
   }
   Rect(p + "bd", x + 10, y + 32, w - 20, 22, bbg, bbg);
   Text(p + "bt", btxt, x + w / 2, y + 43, 8, bfg, true, ANCHOR_CENTER);

   // Check-list
   string labels[N_CHK];
   string values[N_CHK];
   labels[CHK_TREND]   = "Tendance " + TFName(gTF[gM[k].iTrend].tf);
   labels[CHK_BIAS]    = "Biais " + TFName(gTF[gM[k].iBias].tf);
   labels[CHK_ADX]     = "Force de tendance (ADX)";
   labels[CHK_ZONE]    = "Zone d'entree";
   labels[CHK_CONFIRM] = "Bougie de confirmation";
   labels[CHK_RSI]     = "RSI " + TFName(gTF[gM[k].iEntry].tf);
   labels[CHK_RISK]    = "Taille du SL";

   for(int i = 0; i < N_CHK; i++)
      values[i] = "-";
   if(ready)
   {
      values[CHK_TREND] = TrendWord(gM[k].trend);
      values[CHK_BIAS]  = TrendWord(gM[k].bias);
      values[CHK_ADX]   = DoubleToString(gM[k].adx, 1);
      values[CHK_RSI]   = DoubleToString(gM[k].rsi, 1);
      for(int i = CHK_ZONE; i <= CHK_CONFIRM; i++)
         values[i] = (gM[k].chk[i] == 1 ? "OK" : (gM[k].chk[i] == 2 ? "non" : "-"));
      values[CHK_RISK]  = (gM[k].chk[CHK_RISK] == 1 ? "OK" : (gM[k].chk[CHK_RISK] == 2 ? "trop large" : "-"));
   }

   for(int i = 0; i < N_CHK; i++)
   {
      int ry = y + 62 + i * 18;
      int st = (ready ? gM[k].chk[i] : 0);
      color dot = (st == 1 ? COL_GREEN : (st == 2 ? COL_RED : COL_GREY));
      string q = p + "c" + IntegerToString(i);
      Rect(q + "d", x + 12, ry + 4, 7, 7, dot, dot);
      Text(q + "l", labels[i], x + 26, ry, 8, (st == 0 ? COL_MUTED : COL_TEXT));
      Text(q + "v", values[i], x + w - 12, ry, 8, (st == 1 ? COL_GREEN : (st == 2 ? COL_RED : COL_MUTED)),
           true, ANCHOR_RIGHT_UPPER);
   }

   // Bloc signal
   int sy = y + 192;
   Rect(p + "sb", x + 10, sy, w - 20, 54, COL_BOX, COL_BORDER);

   bool hasPos;
   double posProfit = FloatingProfit(k, hasPos);
   bool live = (gM[k].sigValid && !gM[k].sigTaken);

   string l1 = (ready ? gM[k].setup : "-"), l2 = " ", l3 = " ";
   color  c1 = COL_MUTED;
   string btnTxt = "EN ATTENTE D'UN SIGNAL";
   color  btnBg = COL_GREY_D, btnFg = COL_MUTED;

   if(hasPos)
   {
      l1 = "Position ouverte";
      c1 = COL_BLUE;
      l2 = StringFormat("Resultat flottant : %+.2f %s", posProfit, AccountInfoString(ACCOUNT_CURRENCY));
      l3 = (InpUseBreakEven ? StringFormat("Break-even auto a %.1fR", InpBEAtR) : "SL / TP poses a l'ouverture");
      btnTxt = "EN POSITION";
      btnBg = COL_GREY_D; btnFg = COL_BLUE;
   }
   else if(live)
   {
      int dir = gM[k].sigDir;
      double price, sl, tp, lot;
      string why = PrepareOrder(k, price, sl, tp, lot);
      c1 = (dir > 0 ? COL_GREEN : COL_RED);
      l1 = (dir > 0 ? "BUY  -  " : "SELL  -  ") + gM[k].sigStrat;
      if(tp <= 0.0) tp = gM[k].sigTP;
      if(price <= 0.0) price = gM[k].sigEntry;
      l2 = "Entree " + PriceStr(price) + "   SL " + PriceStr(gM[k].sigSL) + "   TP " + PriceStr(tp);
      if(lot > 0.0)
         l3 = StringFormat("Lot %.2f   Risque %.2f   Gain vise %+.2f", lot,
                           MathAbs(MoneyAt(dir, lot, price, gM[k].sigSL)), MoneyAt(dir, lot, price, tp));
      else
         l3 = why;

      string block = (guard != "" ? guard : why);
      if(block != "")
      {
         btnTxt = "BLOQUE : " + block;
         if(StringLen(btnTxt) > 38) btnTxt = StringSubstr(btnTxt, 0, 38);
         btnBg = COL_GREY_D; btnFg = COL_AMBER;
      }
      else if(gAuto)
      {
         btnTxt = "EXECUTION AUTOMATIQUE...";
         btnBg = COL_BLUE; btnFg = clrWhite;
      }
      else if(gM[k].confirmUntil > TimeLocal())
      {
         btnTxt = StringFormat("CONFIRMER %s ? (%ds)", (dir > 0 ? "L'ACHAT" : "LA VENTE"),
                               (int)(gM[k].confirmUntil - TimeLocal()));
         btnBg = COL_AMBER; btnFg = clrBlack;
      }
      else
      {
         btnTxt = StringFormat("%s  %.2f LOT", (dir > 0 ? "ACHETER" : "VENDRE"), lot);
         btnBg = (dir > 0 ? COL_GREEN : COL_RED); btnFg = clrWhite;
      }
   }
   else if(gM[k].sigValid && gM[k].sigTaken)
   {
      l1 = "Signal deja traite";
   }

   Text(p + "s1", l1, x + 18, sy + 5, 9, c1, true);
   Text(p + "s2", l2, x + 18, sy + 22, 8, COL_TEXT);
   Text(p + "s3", l3, x + 18, sy + 37, 8, COL_MUTED);
   Button("BTN_M" + IntegerToString(k), btnTxt, x + 10, y + 252, w - 20, 26, btnBg, btnFg);
}

void DrawSignalLines()
{
   for(int k = 0; k < N_MODES; k++)
   {
      string b = "LN" + IntegerToString(k);
      if(InpShowLevels && gM[k].sigValid && !gM[k].sigTaken)
      {
         HLine(b + "E", gM[k].sigEntry, COL_BLUE, STYLE_DASH, gM[k].name + " : entree");
         HLine(b + "S", gM[k].sigSL, COL_RED, STYLE_DOT, gM[k].name + " : stop loss");
         HLine(b + "T", gM[k].sigTP, COL_GREEN, STYLE_DOT, gM[k].name + " : take profit");
      }
      else
      {
         Remove(b + "E");
         Remove(b + "S");
         Remove(b + "T");
      }
   }
}

void UpdatePanel()
{
   if(!gUI)
      return;

   DrawSignalLines();

   if(InpShowPanel)
   {
      string ccy = AccountInfoString(ACCOUNT_CURRENCY);
      MqlTick tk;
      bool hasTick = SymbolInfoTick(_Symbol, tk);
      double spr = (hasTick ? (tk.ask - tk.bid) / _Point : 0.0);

      int pad = 12;
      int inner = PANEL_W - 2 * pad;

      Rect("bg", 0, 0, PANEL_W, PANEL_H, COL_BG, COL_BORDER);
      Rect("hd", 0, 0, PANEL_W, 48, COL_HEAD, COL_BORDER);
      Rect("hdl", 0, 0, 4, 48, COL_GOLD, COL_GOLD);
      Text("ttl", _Symbol + "  TRADE DESK", 16, 7, 12, COL_GOLD, true);
      Text("sub", "Scalping + Intraday  |  suivi de tendance  |  " +
                  (gAuto ? "execution AUTOMATIQUE" : "execution MANUELLE (clic)"), 16, 29, 7, COL_MUTED);

      // Etat global
      bool anyPos;
      FloatingProfit(-1, anyPos);
      int sigK = -1;
      for(int k = 0; k < N_MODES; k++)
         if(gM[k].sigValid && !gM[k].sigTaken) { sigK = k; break; }

      string stTxt = "EN ATTENTE";
      color  stBg = COL_GREY_D, stFg = COL_TEXT;
      if(anyPos)             { stTxt = "EN POSITION"; stBg = COL_BLUE; stFg = clrWhite; }
      else if(gGuard != "")  { stTxt = "ENTREES BLOQUEES"; stBg = COL_AMBER; stFg = clrBlack; }
      else if(sigK >= 0)     { stTxt = (gM[sigK].sigDir > 0 ? "SIGNAL BUY" : "SIGNAL SELL");
                               stBg = (gM[sigK].sigDir > 0 ? COL_GREEN : COL_RED); stFg = clrWhite; }
      else                   { stTxt = "PRET - ATTENTE SIGNAL"; }
      Rect("stb", PANEL_W - 172, 11, 160, 26, stBg, stBg);
      Text("stt", stTxt, PANEL_W - 92, 24, 8, stFg, true, ANCHOR_CENTER);

      // Ligne marche
      int gap = 8;
      int tw = (inner - 3 * gap) / 4;
      int y = 58;
      string why;
      bool inSes = InSession(why);
      Tile("t_px", pad, y, tw, "PRIX (BID)", (hasTick ? PriceStr(tk.bid) : "-"), COL_TEXT);
      Tile("t_sp", pad + (tw + gap), y, tw, "SPREAD (POINTS)", (hasTick ? DoubleToString(spr, 0) : "-"),
           ((InpMaxSpreadPoints > 0 && spr > InpMaxSpreadPoints) ? COL_RED : COL_GREEN));
      Tile("t_se", pad + 2 * (tw + gap), y, tw, "SESSION", (inSes ? ((gAllHours && InpUseSession) ? "24H/24" : "OUVERTE") : "FERMEE"),
           (inSes ? ((gAllHours && InpUseSession) ? COL_AMBER : COL_GREEN) : COL_AMBER));
      Tile("t_nw", pad + 3 * (tw + gap), y, tw, "PROCHAINE NEWS USD", NextNewsText(), (NewsBlocked() ? COL_RED : COL_TEXT));

      // Ligne compte
      y += 50;
      double pnl = DayPnL();
      double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
      Tile("t_ba", pad, y, tw, "SOLDE (" + ccy + ")", DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2), COL_TEXT);
      Tile("t_pl", pad + (tw + gap), y, tw, "RESULTAT DU JOUR", StringFormat("%+.2f", pnl),
           (pnl > 0.0 ? COL_GREEN : (pnl < 0.0 ? COL_RED : COL_TEXT)));
      Tile("t_tr", pad + 2 * (tw + gap), y, tw, "TRADES DU JOUR",
           (InpMaxDailyTrades > 0 ? StringFormat("%d / %d", gDayTrades, InpMaxDailyTrades) : IntegerToString(gDayTrades)),
           ((InpMaxDailyTrades > 0 && gDayTrades >= InpMaxDailyTrades) ? COL_AMBER : COL_TEXT));
      Tile("t_rk", pad + 3 * (tw + gap), y, tw, "RISQUE PAR TRADE",
           (InpLotMode == LOT_RISK ? StringFormat("%.2f%%  (%.2f)", InpRiskPercent, riskMoney)
                                   : StringFormat("lot fixe %.2f", InpFixedLot)), COL_TEXT);

      // Jauge de perte du jour
      y += 50;
      Rect("lb_bg", pad, y, inner, 26, COL_CARD, COL_BORDER);
      double used = 0.0;
      if(InpMaxDailyLossPct > 0.0)
         used = MathMin(1.0, DayLossPct() / InpMaxDailyLossPct);
      int barX = pad + 190, barW = inner - 190 - 96;
      Text("lb_l", "Limite de perte du jour", pad + 10, y + 6, 8, COL_MUTED);
      Rect("lb_t", barX, y + 9, barW, 8, COL_GREY_D, COL_GREY_D);
      color gc = (used >= 1.0 ? COL_RED : (used >= 0.6 ? COL_AMBER : COL_GREEN));
      Rect("lb_f", barX, y + 9, (int)MathMax(1, MathRound(barW * used)), 8, (used > 0.0 ? gc : COL_GREY_D), (used > 0.0 ? gc : COL_GREY_D));
      Text("lb_v", (InpMaxDailyLossPct > 0.0 ? StringFormat("%.0f%% de %.1f%%", used * 100.0, InpMaxDailyLossPct) : "off"),
           pad + inner - 10, y + 6, 8, (used >= 1.0 ? COL_RED : COL_TEXT), true, ANCHOR_RIGHT_UPPER);

      // Cartes des modes
      y += 34;
      int cw = (inner - pad) / 2;
      DrawModeCard(0, pad, y, cw, gGuard);
      DrawModeCard(1, pad + cw + pad, y, cw, gGuard);

      // Pied
      y += 286 + 10;
      Button("BTN_BE", "BREAK-EVEN", pad, y, 100, 26, COL_GREY_D, COL_TEXT);
      bool confirmClose = (gCloseConfirmUntil > TimeLocal());
      Button("BTN_CA", (confirmClose ? "CONFIRMER ?" : "TOUT FERMER"), pad + 108, y, 100, 26,
             (confirmClose ? COL_AMBER : COL_RED_D), (confirmClose ? clrBlack : COL_RED));

      // Interrupteur 24H/24 (ignore les horaires de session)
      string hTxt = "24H/24 : OFF";
      color  hBg = COL_GREY_D, hFg = COL_TEXT;
      if(gAllHours || !InpUseSession)
      {
         hTxt = "24H/24 : ON";
         hBg = COL_AMBER; hFg = clrBlack;
      }
      else if(gHoursConfirmUntil > TimeLocal())
      {
         hTxt = StringFormat("ACTIVER 24H/24 ? (%ds)", (int)(gHoursConfirmUntil - TimeLocal()));
         hBg = COL_AMBER; hFg = clrBlack;
      }
      Button("BTN_HR", hTxt, pad + 216, y, 160, 26, hBg, hFg);

      // Interrupteur AUTO / MANUEL
      string auTxt = "TRADING AUTO : OFF";
      color  auBg = COL_GREY_D, auFg = COL_TEXT;
      if(gAuto)
      {
         auTxt = (gTester ? "AUTO : ON (TESTER)" : "TRADING AUTO : ON");
         auBg = COL_BLUE; auFg = clrWhite;
      }
      else if(gAutoConfirmUntil > TimeLocal())
      {
         auTxt = StringFormat("ACTIVER L'AUTO ? (%ds)", (int)(gAutoConfirmUntil - TimeLocal()));
         auBg = COL_AMBER; auFg = clrBlack;
      }
      Button("BTN_AU", auTxt, pad + 384, y, inner - 384, 26, auBg, auFg);

      string info = (gGuard != "" ? "Blocage : " + gGuard : (gMsg != "" ? gMsg : "Aucun blocage : les signaux valides peuvent etre pris"));
      if(StringLen(info) > 70) info = StringSubstr(info, 0, 70);
      Text("ft_i", info, pad, y + 32, 8, (gGuard != "" ? COL_AMBER : COL_TEXT));
      if(gConsecLoss > 0)
         Text("ft_c", StringFormat("Pertes consecutives : %d", gConsecLoss), PANEL_W - pad, y + 33, 7, COL_AMBER, false, ANCHOR_RIGHT_UPPER);
      else
         Text("ft_c", " ", PANEL_W - pad, y + 33, 7, COL_AMBER, false, ANCHOR_RIGHT_UPPER);
      Text("ft_d", "Aucune strategie n'est garantie : testez en demo et respectez le risque.", pad, y + 50, 7, COL_MUTED);
   }

   if(gDirty)
   {
      ChartRedraw(0);
      gDirty = false;
   }
}

//==================================================================//
// BOUCLE PRINCIPALE
//==================================================================//

void Refresh()
{
   // Nouvelle bougie M5 (plus petite UT utilisee) -> on recharge et on reevalue
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   bool needLoad = (t != 0 && t != gLastBar);
   if(needLoad && TimeLocal() != gLastLoadTry)
   {
      gLastLoadTry = TimeLocal();
      if(LoadAll())
         gLastBar = t;
      for(int k = 0; k < N_MODES; k++)
         EvaluateMode(k, gTF[gM[k].iEntry], gTF[gM[k].iTrend], gTF[gM[k].iBias]);
   }

   ExpireSignals();
   gGuard = GuardReason();

   if(gAuto)
   {
      for(int k = 0; k < N_MODES; k++)
      {
         if(!gM[k].sigValid || gM[k].sigTaken)
            continue;
         string err = ExecuteSignal(k);
         if(err != "" && err != gM[k].lastAutoMsg)
         {
            gM[k].lastAutoMsg = err;
            gMsg = gM[k].name + " : " + err;
            Print("Trade Desk : ", gMsg);
         }
         else if(err == "")
            gMsg = gM[k].name + " : ordre ouvert";
      }
   }
}

void InitMode(const int k, const string name, const bool enabled, const int iEntry, const int iTrend,
              const int iBias, const double rr)
{
   gM[k].name = name;
   gM[k].enabled = enabled;
   gM[k].iEntry = iEntry;
   gM[k].iTrend = iTrend;
   gM[k].iBias = iBias;
   gM[k].rr = rr;
   gM[k].trend = 0;
   gM[k].bias = 0;
   gM[k].adx = 0.0;
   gM[k].rsi = 0.0;
   for(int i = 0; i < N_CHK; i++)
      gM[k].chk[i] = 0;
   gM[k].setup = "-";
   gM[k].sigValid = false;
   gM[k].sigTaken = false;
   gM[k].sigDir = 0;
   gM[k].sigStrat = "";
   gM[k].sigEntry = 0.0;
   gM[k].sigSL = 0.0;
   gM[k].sigTP = 0.0;
   gM[k].sigBar = 0;
   gM[k].sigExpire = 0;
   gM[k].lastEvalBar = 0;
   gM[k].lastSigBar = 0;
   gM[k].confirmUntil = 0;
   gM[k].lastAutoMsg = "";
}

int OnInit()
{
   if(InpEMAFast >= InpEMAMid || InpEMAMid >= InpEMASlow)
   {
      Print("Trade Desk : les EMA doivent verifier rapide < moyenne < lente");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpRiskPercent <= 0.0 || InpRiskPercent > 5.0)
   {
      Print("Trade Desk : risque par trade hors limites (0 - 5 %)");
      return INIT_PARAMETERS_INCORRECT;
   }
   if(InpBreakLookback + InpRetestMaxBars + 2 > BARS || InpSLSwingBars < 1 || InpRRScalping <= 0.0 || InpRRIntraday <= 0.0)
   {
      Print("Trade Desk : parametres de strategie incorrects");
      return INIT_PARAMETERS_INCORRECT;
   }

   bool tester = (bool)MQLInfoInteger(MQL_TESTER);
   gTester = tester;
   // Les clics ne fonctionnent pas dans le Strategy Tester : on y execute en automatique
   gAuto = (InpExecMode == EXEC_AUTO || tester);
   // Choix fait sur le panneau (bouton TRADING AUTO) : prioritaire tant que l'EA reste sur le graphique
   if(!tester && GlobalVariableCheck(AutoKey()))
      gAuto = (GlobalVariableGet(AutoKey()) > 0.5);
   gAutoConfirmUntil = 0;
   gAllHours = (!tester && GlobalVariableCheck(AllHoursKey()) && GlobalVariableGet(AllHoursKey()) > 0.5);
   gHoursConfirmUntil = 0;
   gUI   = (!MQLInfoInteger(MQL_OPTIMIZATION) && (!tester || MQLInfoInteger(MQL_VISUAL_MODE)));

   bool ok = true;
   ok = InitTF(gTF[0], PERIOD_M5)  && ok;
   ok = InitTF(gTF[1], PERIOD_M15) && ok;
   ok = InitTF(gTF[2], PERIOD_H1)  && ok;
   ok = InitTF(gTF[3], PERIOD_H4)  && ok;
   if(!ok)
   {
      Print("Trade Desk : creation des indicateurs impossible");
      return INIT_FAILED;
   }

   InitMode(0, "SCALPING", InpEnableScalping, 0, 1, 2, InpRRScalping);
   InitMode(1, "INTRADAY", InpEnableIntraday, 1, 2, 3, InpRRIntraday);

   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFillingBySymbol(_Symbol);

   if(StringFind(_Symbol, "XAU") < 0 && StringFind(_Symbol, "GOLD") < 0)
      Print("Trade Desk : reglages prevus pour XAUUSD, symbole actuel = ", _Symbol);

   ArrayResize(gCacheName, 0);
   ArrayResize(gCacheSig, 0);
   gLastBar = 0;
   gMsg = "";
   if(!tester && InpMailOnTrade && !TerminalInfoInteger(TERMINAL_EMAIL_ENABLED))
   {
      gMsg = "E-mail non configure dans MT5 : Outils > Options > Email";
      Print("Trade Desk : ", gMsg);
   }

   RefreshDaily();
   RefreshNews();
   ComputeScale();
   EventSetTimer(1);
   Refresh();
   UpdatePanel();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   // Parametres modifies, EA retire ou graphique ferme : le reglage "Execution" redevient la reference
   if(!gTester && (reason == REASON_PARAMETERS || reason == REASON_REMOVE || reason == REASON_CHARTCLOSE))
   {
      GlobalVariableDel(AutoKey());
      GlobalVariableDel(AllHoursKey());
   }
   for(int i = 0; i < N_TF; i++)
   {
      ReleaseH(gTF[i].hFast);
      ReleaseH(gTF[i].hMid);
      ReleaseH(gTF[i].hSlow);
      ReleaseH(gTF[i].hRSI);
      ReleaseH(gTF[i].hADX);
      ReleaseH(gTF[i].hATR);
   }
   ObjectsDeleteAll(0, OBJ_PREFIX);
   ChartRedraw(0);
}

void OnTick()
{
   ManagePositions();
   Refresh();
}

void OnTimer()
{
   if(TimeLocal() - gLastDaily >= 5)
      RefreshDaily();
   RefreshNews();
   Refresh();
   UpdatePanel();
}

void OnTrade()
{
   RefreshDaily();
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      double old = gScale;
      ComputeScale();
      if(old != gScale)
         UpdatePanel();
      return;
   }
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;
   if(StringFind(sparam, OBJ_PREFIX + "BTN_") != 0)
      return;

   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   datetime now = TimeLocal();

   if(sparam == OBJ_PREFIX + "BTN_BE")
   {
      ForceBreakEven();
   }
   else if(sparam == OBJ_PREFIX + "BTN_AU")
   {
      if(gTester)
         gMsg = "Strategy Tester : execution toujours automatique";
      else if(gAuto)
         SetAuto(false);                       // couper l'auto : immediat
      else if(gAutoConfirmUntil > now)
         SetAuto(true);                        // l'activer : 2e clic de confirmation
      else
         gAutoConfirmUntil = now + InpConfirmSeconds;
   }
   else if(sparam == OBJ_PREFIX + "BTN_HR")
   {
      if(!InpUseSession)
         gMsg = "Filtre horaire deja desactive dans les parametres";
      else if(gAllHours)
         SetAllHours(false);                   // revenir aux horaires : immediat
      else if(gHoursConfirmUntil > now)
         SetAllHours(true);                    // 24H/24 : 2e clic de confirmation
      else
         gHoursConfirmUntil = now + InpConfirmSeconds;
   }
   else if(sparam == OBJ_PREFIX + "BTN_CA")
   {
      if(CountPositions() == 0)
         gMsg = "Aucune position a fermer";
      else if(gCloseConfirmUntil > now)
      {
         gCloseConfirmUntil = 0;
         CloseAll();
      }
      else
         gCloseConfirmUntil = now + InpConfirmSeconds;
   }
   else
   {
      for(int k = 0; k < N_MODES; k++)
      {
         if(sparam != OBJ_PREFIX + "BTN_M" + IntegerToString(k))
            continue;
         if(gAuto || !gM[k].sigValid || gM[k].sigTaken)
            break;

         if(gM[k].confirmUntil > now)
         {
            string err = ExecuteSignal(k);
            gMsg = gM[k].name + " : " + (err == "" ? "ordre ouvert" : err);
            Print("Trade Desk : ", gMsg);
         }
         else
         {
            string g = GuardReason();
            if(g != "")
               gMsg = g;
            else
               gM[k].confirmUntil = now + InpConfirmSeconds;
         }
         break;
      }
   }

   gGuard = GuardReason();
   UpdatePanel();
   ChartRedraw(0);
}
//+------------------------------------------------------------------+

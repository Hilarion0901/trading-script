//+------------------------------------------------------------------+
//|                                   XAUUSD_Signal_Executor.mq5     |
//|  Expert Advisor compagnon de XAUUSD_Signal_Pro                   |
//|                                                                  |
//|  Un indicateur ne peut pas passer d'ordre en MQL5. Cet EA, pose  |
//|  sur le MEME graphique que l'indicateur, intercepte le clic sur  |
//|  le bandeau ACHETER / VENDRE du panneau, demande confirmation    |
//|  et ouvre la position avec le SL et le TP du signal.             |
//|                                                                  |
//|  Aucun trade automatique : rien n'est envoye sans clic.          |
//|  Echange avec l'indicateur via variables globales XSP_<symbole>_ |
//+------------------------------------------------------------------+
#property copyright   "XAUUSD Signal Executor"
#property version     "1.00"
#property description "Ouvre le trade du panneau XAUUSD Signal Pro au clic (SL + TP), avec confirmation"

#include <Trade/Trade.mqh>

enum ENUM_CONFIRM_MODE
{
   CONFIRM_CHART = 0,   // Boutons sur le graphique (recommande, surtout sur Mac)
   CONFIRM_POPUP = 1,   // Fenetre MessageBox (peut se cacher derriere MT5 sur Mac)
   CONFIRM_NONE  = 2    // Aucune confirmation (ordre direct au clic)
};

enum ENUM_LOT_MODE
{
   LOT_RISK  = 0,   // Risque en % du solde
   LOT_FIXED = 1    // Lot fixe
};

input group "===== Taille de position ====="
input ENUM_LOT_MODE InpLotMode     = LOT_RISK;
input double InpRiskPercent        = 0.5;    // Risque par trade (% du solde)
input double InpFixedLot           = 0.01;   // Lot si mode "Lot fixe"
input double InpMaxLot             = 1.0;    // Lot maxi (securite)
input bool   InpAllowMinLot        = false;  // Si le risque donne moins que le lot mini : prendre le lot mini

input group "===== Execution ====="
input ENUM_CONFIRM_MODE InpConfirmMode = CONFIRM_CHART;   // Confirmation avant chaque ordre
input int    InpConfirmSeconds     = 20;     // Delai pour confirmer (s), annulation automatique ensuite
input int    InpSlippagePoints     = 30;     // Glissement maxi (points)
input int    InpMaxEntryDriftPoints = 300;   // Ecart maxi prix actuel / entree du signal (points, 0 = off)
input int    InpMaxPositions       = 1;      // Positions maxi de cet EA sur le symbole (0 = illimite)
input ulong  InpMagic              = 260501;

input group "===== Indicateur ====="
input bool   InpAttachIndicator    = true;   // Ajouter XAUUSD Signal Pro au graphique s'il n'y est pas
input string InpIndicatorFile      = "XAUUSD_Signal_Pro";   // Nom du fichier dans MQL5/Indicators

#define IND_SHORTNAME "XAUUSD Signal Pro"
#define BANNER_PREFIX "XAU_SP_P_BAN"

#define BOX_PREFIX    "XSP_EX_"

CTrade gTrade;

// Ordre en attente de confirmation sur le graphique
struct PendingOrder
{
   bool     active;
   double   id;
   int      dir;
   double   lot;
   double   sl;
   double   tp;
   string   comment;
   datetime deadline;
};
PendingOrder gPend;
string gModeTag[3] = {"SCALP", "INTRA", "SWING"};
bool   gBusy = false;
bool     gAttachDone = false;
datetime gStartTime  = 0;

//==================================================================//
// VARIABLES GLOBALES PARTAGEES AVEC L'INDICATEUR
//==================================================================//

string GVName(const string key) { return "XSP_" + _Symbol + "_" + key; }

double GVGet(const string key)
{
   string n = GVName(key);
   return (GlobalVariableCheck(n) ? GlobalVariableGet(n) : 0.0);
}

// code : 1 ouvert, 0 annule, -1 refuse (ret = raison), -2 erreur serveur (ret = retcode)
void PublishResult(const int code, const int ret, const double id, const double ticket = 0.0, const double lot = 0.0)
{
   GlobalVariableSet(GVName("RES_CODE"),   (double)code);
   GlobalVariableSet(GVName("RES_RET"),    (double)ret);
   GlobalVariableSet(GVName("RES_TICKET"), ticket);
   GlobalVariableSet(GVName("RES_LOT"),    lot);
   GlobalVariableSet(GVName("RES_TIME"),   (double)TimeLocal());
   GlobalVariableSet(GVName("RES_ID"),     id);        // ecrit en dernier
   ChartRedraw(0);
}

void Refuse(const int reason, const double id, const string msg)
{
   Print("[EXECUTEUR] Refuse : ", msg);
   PublishResult(-1, reason, id);
}

//==================================================================//
// OUTILS
//==================================================================//

int CountPositions()
{
   int n = 0;
   for(int k = PositionsTotal() - 1; k >= 0; k--)
   {
      ulong t = PositionGetTicket(k);
      if(t == 0) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         n++;
   }
   return n;
}

double NormalizeLot(double lot)
{
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;

   lot = MathMin(lot, InpMaxLot);
   lot = MathMin(lot, vmax);
   lot = MathFloor(lot / step + 1e-9) * step;
   if(lot < vmin)
   {
      if(InpAllowMinLot || InpLotMode == LOT_FIXED)
         lot = vmin;
      else
         return 0.0;
   }
   int digits = (int)MathMax(0, MathCeil(-MathLog10(step) - 1e-9));
   return NormalizeDouble(lot, digits);
}

double CalcLot(const int dir, const double price, const double sl)
{
   if(InpLotMode == LOT_FIXED)
      return NormalizeLot(InpFixedLot);

   double loss1 = 0.0;
   ENUM_ORDER_TYPE type = (dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type, _Symbol, 1.0, price, sl, loss1))
      return 0.0;
   loss1 = MathAbs(loss1);
   if(loss1 <= 0.0)
      return 0.0;

   double riskMoney = AccountInfoDouble(ACCOUNT_BALANCE) * InpRiskPercent / 100.0;
   return NormalizeLot(riskMoney / loss1);
}

double MoneyAt(const int dir, const double lot, const double from, const double to)
{
   double p = 0.0;
   ENUM_ORDER_TYPE type = (dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type, _Symbol, lot, from, to, p))
      return 0.0;
   return p;
}

// Prix courant du bon cote du SL et du TP ?
bool PriceBetween(const int dir, const double price, const double sl, const double tp)
{
   if(dir > 0) return (price > sl && price < tp);
   return (price < sl && price > tp);
}

//==================================================================//
// EXECUTION DU SIGNAL AFFICHE
//==================================================================//

void ExecuteSignal()
{
   if(GVGet("SIG_VALID") < 0.5)
   {
      Refuse(1, 0.0, "aucun signal actif sur le panneau");
      return;
   }

   double id    = GVGet("SIG_ID");
   int    dir   = (int)GVGet("SIG_DIR");
   double entry = GVGet("SIG_ENTRY");
   double sl    = NormalizeDouble(GVGet("SIG_SL"), _Digits);
   double tp    = NormalizeDouble(GVGet("SIG_TP"), _Digits);
   int    mode  = (int)GVGet("SIG_MODE");
   int    grade = (int)GVGet("SIG_GRADE");
   string tag   = (mode >= 0 && mode < 3 ? gModeTag[mode] : "SIG");
   string gtxt  = (grade >= 3 ? "A+" : (grade == 2 ? "A" : "B"));
   int    stype = (int)GVGet("SIG_TYPE");
   string tname = (stype == 1 ? "Trend-following" : (stype == 2 ? "Breakout" :
                  (stype == 3 ? "Breakout + retest" : (stype == 4 ? "Mean reversion" : "-"))));
   string tcode = (stype == 1 ? "TF" : (stype == 2 ? "BO" : (stype == 3 ? "RT" : (stype == 4 ? "MR" : ""))));

   if(dir == 0 || sl <= 0.0 || tp <= 0.0)
   {
      Refuse(1, id, "signal incomplet");
      return;
   }
   if(GVGet("RES_ID") == id && GVGet("RES_CODE") > 0.0)
   {
      Refuse(2, id, "signal deja execute");
      return;
   }
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED) ||
      !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
   {
      Refuse(6, id, "trading algorithmique desactive");
      return;
   }
   if(InpMaxPositions > 0 && CountPositions() >= InpMaxPositions)
   {
      Refuse(9, id, "position deja ouverte");
      return;
   }

   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk))
   {
      Refuse(3, id, "pas de prix");
      return;
   }
   double price = (dir > 0 ? tk.ask : tk.bid);

   if(!PriceBetween(dir, price, sl, tp))
   {
      Refuse(3, id, "prix au-dela du SL ou du TP");
      return;
   }
   if(InpMaxEntryDriftPoints > 0 && MathAbs(price - entry) > InpMaxEntryDriftPoints * _Point)
   {
      Refuse(8, id, "prix trop loin de l'entree");
      return;
   }
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(MathAbs(price - sl) <= minDist || MathAbs(tp - price) <= minDist)
   {
      Refuse(4, id, "SL / TP sous le stop level du broker");
      return;
   }

   double lot = CalcLot(dir, price, sl);
   if(lot <= 0.0)
   {
      Refuse(5, id, "lot calcule inferieur au lot mini");
      return;
   }

   double margin = 0.0;
   if(OrderCalcMargin(dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, lot, price, margin) &&
      margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE))
   {
      Refuse(7, id, "marge insuffisante");
      return;
   }

   string cur  = AccountInfoString(ACCOUNT_CURRENCY);
   double risk = MathAbs(MoneyAt(dir, lot, price, sl));
   double gain = MathAbs(MoneyAt(dir, lot, price, tp));
   double rr   = (MathAbs(price - sl) > 0.0 ? MathAbs(tp - price) / MathAbs(price - sl) : 0.0);
   string comment = "SP " + tag + " " + (dir > 0 ? "BUY " : "SELL ") + gtxt + " " + tcode;

   if(InpConfirmMode == CONFIRM_NONE)
   {
      SendOrder(id, dir, lot, sl, tp, comment);
      return;
   }

   if(InpConfirmMode == CONFIRM_POPUP)
   {
      string msg =
         (dir > 0 ? "ACHAT (BUY)" : "VENTE (SELL)") + "  " + _Symbol + "   —   " + tag + "  qualite " + gtxt + "\n\n" +
         "Type d'entree :  " + tname + "\n" +
         "Lot :  " + DoubleToString(lot, 2) + "\n" +
         "Prix actuel :  " + DoubleToString(price, _Digits) + "\n" +
         "Stop Loss :  " + DoubleToString(sl, _Digits) + "   (risque  -" + DoubleToString(risk, 2) + " " + cur + ")\n" +
         "Take Profit :  " + DoubleToString(tp, _Digits) + "   (gain  +" + DoubleToString(gain, 2) + " " + cur + ")\n" +
         "Ratio :  1 : " + DoubleToString(rr, 2) + "\n\n" +
         "Ouvrir la position ?";
      if(MessageBox(msg, "XAUUSD Signal Pro — confirmation", MB_YESNO | MB_ICONQUESTION) != IDYES)
      {
         Print("[EXECUTEUR] Ordre annule par l'utilisateur.");
         PublishResult(0, 0, id);
         return;
      }
      SendOrder(id, dir, lot, sl, tp, comment);
      return;
   }

   // Confirmation sur le graphique : jamais de fenetre modale qui bloque le terminal
   gPend.active   = true;
   gPend.id       = id;
   gPend.dir      = dir;
   gPend.lot      = lot;
   gPend.sl       = sl;
   gPend.tp       = tp;
   gPend.comment  = comment;
   gPend.deadline = TimeLocal() + MathMax(5, InpConfirmSeconds);
   ShowConfirmBox(dir, tag, gtxt, tname, lot, price, sl, tp, risk, gain, rr, cur);
}

void SendOrder(const double id, const int dir, const double lot, const double sl, const double tp, const string comment)
{
   // Le prix a pu bouger depuis le clic
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk) || !PriceBetween(dir, (dir > 0 ? tk.ask : tk.bid), sl, tp))
   {
      Refuse(3, id, "prix au-dela du SL ou du TP au moment de l'envoi");
      return;
   }

   bool ok = (dir > 0 ? gTrade.Buy(lot, _Symbol, 0.0, sl, tp, comment)
                      : gTrade.Sell(lot, _Symbol, 0.0, sl, tp, comment));
   uint rc = gTrade.ResultRetcode();

   if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
   {
      Print("[EXECUTEUR] Position ouverte #", gTrade.ResultOrder(), "  ", comment,
            "  lot ", DoubleToString(lot, 2), "  SL ", DoubleToString(sl, _Digits), "  TP ", DoubleToString(tp, _Digits));
      PublishResult(1, (int)rc, id, (double)gTrade.ResultOrder(), lot);
   }
   else
   {
      Print("[EXECUTEUR] Echec ordre : ", rc, " ", gTrade.ResultRetcodeDescription());
      PublishResult(-2, (int)rc, id);
   }
}

//==================================================================//
// FENETRE DE CONFIRMATION DESSINEE SUR LE GRAPHIQUE
//==================================================================//

void BoxRect(const string id, const int x, const int y, const int w, const int h, const color bg, const color bd)
{
   string n = BOX_PREFIX + id;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, bd);
   ObjectSetInteger(0, n, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, n, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, n, OBJPROP_BACK, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void BoxText(const string id, const string text, const int x, const int y, const int fs, const color clr, const bool bold)
{
   string n = BOX_PREFIX + id;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, fs);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clr);
   ObjectSetString(0, n, OBJPROP_FONT, (bold ? "Segoe UI Semibold" : "Segoe UI"));
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
}

void BoxButton(const string id, const string text, const int x, const int y, const int w, const int h, const color bg)
{
   string n = BOX_PREFIX + id;
   if(ObjectFind(0, n) < 0)
      ObjectCreate(0, n, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, n, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, n, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, n, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, n, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, n, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, n, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_BORDER_COLOR, bg);
   ObjectSetInteger(0, n, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, n, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, n, OBJPROP_FONT, "Segoe UI Semibold");
   ObjectSetString(0, n, OBJPROP_TEXT, text);
   ObjectSetInteger(0, n, OBJPROP_STATE, false);
   ObjectSetInteger(0, n, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, n, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, n, OBJPROP_ZORDER, 10);
}

void ShowConfirmBox(const int dir, const string tag, const string gtxt, const string tname, const double lot,
                    const double price, const double sl, const double tp, const double risk, const double gain,
                    const double rr, const string cur)
{
   color dc = (dir > 0 ? C'38,166,91' : C'226,75,74');
   int w = 330, h = 214;
   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int x = MathMax(10, cw / 2 - w / 2);
   int y = 60;

   BoxRect("BG", x, y, w, h, C'21,25,32', dc);
   BoxRect("HD", x, y, w, 30, dc, dc);
   BoxText("T0", "CONFIRMER : " + (dir > 0 ? "ACHAT (BUY)" : "VENTE (SELL)") + "  " + tag + " " + gtxt,
           x + 12, y + 6, 10, clrWhite, true);
   int ly = y + 40;
   BoxText("L1", "Type d'entree :  " + tname, x + 14, ly, 9, C'214,178,70', false);                    ly += 20;
   BoxText("L2", "Lot :  " + DoubleToString(lot, 2) + "     Prix :  " + DoubleToString(price, _Digits),
           x + 14, ly, 9, C'228,232,238', false);                                                       ly += 20;
   BoxText("L3", "Stop Loss :  " + DoubleToString(sl, _Digits) + "   (-" + DoubleToString(risk, 2) + " " + cur + ")",
           x + 14, ly, 9, C'226,75,74', false);                                                         ly += 20;
   BoxText("L4", "Take Profit :  " + DoubleToString(tp, _Digits) + "   (+" + DoubleToString(gain, 2) + " " + cur + ")",
           x + 14, ly, 9, C'38,166,91', false);                                                         ly += 20;
   BoxText("L5", "Ratio :  1 : " + DoubleToString(rr, 2), x + 14, ly, 9, C'228,232,238', false);         ly += 22;
   BoxText("CD", "", x + 14, ly, 8, C'138,146,160', false);
   UpdateConfirmCountdown();

   BoxButton("OK", "CONFIRMER", x + 14, y + h - 44, 145, 32, dc);
   BoxButton("NO", "ANNULER",   x + w - 159, y + h - 44, 145, 32, C'70,78,92');
   ChartRedraw(0);
}

void UpdateConfirmCountdown()
{
   if(!gPend.active)
      return;
   long left = (long)(gPend.deadline - TimeLocal());
   if(left < 0) left = 0;
   ObjectSetString(0, BOX_PREFIX + "CD", OBJPROP_TEXT, "Annulation automatique dans " + IntegerToString(left) + " s");
}

void CloseConfirmBox()
{
   ObjectsDeleteAll(0, BOX_PREFIX, 0, -1);
   ChartRedraw(0);
}

void CancelPending(const string why)
{
   if(!gPend.active)
      return;
   gPend.active = false;
   CloseConfirmBox();
   Print("[EXECUTEUR] Ordre annule (", why, ").");
   PublishResult(0, 0, gPend.id);
}

void ConfirmPending()
{
   if(!gPend.active)
      return;
   gPend.active = false;
   CloseConfirmBox();
   SendOrder(gPend.id, gPend.dir, gPend.lot, gPend.sl, gPend.tp, gPend.comment);
}

//==================================================================//
// EVENEMENTS
//==================================================================//

// L'indicateur est-il deja sur ce graphique ? (liste des indicateurs + signal de vie de l'indicateur)
bool IndicatorPresent()
{
   int wins = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int w = 0; w < wins; w++)
      for(int k = ChartIndicatorsTotal(0, w) - 1; k >= 0; k--)
         if(StringFind(ChartIndicatorName(0, w, k), IND_SHORTNAME) == 0)
            return true;

   string okey = "XSP_" + _Symbol + "_OWNER_" + IntegerToString(ChartID());
   if(GlobalVariableCheck(okey + "_HB") && (double)TimeLocal() - GlobalVariableGet(okey + "_HB") <= 10.0)
      return true;
   return false;
}

// Appele quelques secondes apres le demarrage : laisse le temps a un indicateur ajoute
// a la main (ou par un modele) de s'enregistrer, pour ne jamais en ajouter une 2e copie
void AttachIndicator()
{
   if(!InpAttachIndicator || gAttachDone)
      return;
   gAttachDone = true;
   if(IndicatorPresent())
      return;
   int h = iCustom(_Symbol, _Period, InpIndicatorFile);
   if(h == INVALID_HANDLE || !ChartIndicatorAdd(0, 0, h))
      Print("[EXECUTEUR] Impossible d'ajouter ", InpIndicatorFile, " : ajoutez l'indicateur manuellement.");
   else
      Print("[EXECUTEUR] Indicateur ", IND_SHORTNAME, " ajoute au graphique.");
}

int OnInit()
{
   gTrade.SetExpertMagicNumber(InpMagic);
   gTrade.SetDeviationInPoints(InpSlippagePoints);
   gTrade.SetTypeFillingBySymbol(_Symbol);
   gTrade.SetMarginMode();
   gPend.active = false;

   gAttachDone = false;
   gStartTime  = TimeLocal();
   GlobalVariableSet(GVName("ALIVE"), (double)TimeLocal());
   EventSetTimer(1);
   Print("[EXECUTEUR] Pret. Cliquez sur le bandeau ACHETER / VENDRE du panneau pour trader.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   gPend.active = false;
   CloseConfirmBox();
   GlobalVariableDel(GVName("ALIVE"));
}

void OnTimer()
{
   // Signal de vie lu par l'indicateur (bouton actif / "executeur absent")
   GlobalVariableSet(GVName("ALIVE"), (double)TimeLocal());

   if(!gAttachDone && TimeLocal() - gStartTime >= 3)
      AttachIndicator();

   if(gPend.active)
   {
      if(TimeLocal() > gPend.deadline)
         CancelPending("delai de confirmation depasse");
      else
      {
         UpdateConfirmCountdown();
         ChartRedraw(0);
      }
   }
}

void OnTick()
{
   // Rien a faire a chaque tick : l'EA n'agit que sur clic (signal de vie gere par le timer)
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id != CHARTEVENT_OBJECT_CLICK)
      return;
   if(sparam == BOX_PREFIX + "OK") { ConfirmPending(); return; }
   if(sparam == BOX_PREFIX + "NO") { CancelPending("par l'utilisateur"); return; }
   if(StringFind(sparam, BANNER_PREFIX) != 0)
      return;
   if(gBusy || gPend.active)
      return;            // une confirmation est deja affichee
   gBusy = true;          // pas de double ordre sur double clic
   ExecuteSignal();
   gBusy = false;
}
//+------------------------------------------------------------------+

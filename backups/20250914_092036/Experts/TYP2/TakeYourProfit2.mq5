#include "typ_dualma_pro.mqh"
#include "typ_execfilters.mqh"
#property strict
#property description "Take Your Profit 2.0 вЂ” slim build (<=20 files)"
#property version   "3.1-rc2"

#include <Trade/Trade.mqh>
CTrade  TYPTrade;

// consolidated headers
#include "typ_core.mqh"        // globals, utils, newbar, news, portfolio, cross-bias (stub)
#include "typ_risk.mqh"        // risk & autolot
#include "typ_be.mqh"          // tiered BE
#include "typ_exit.mqh"        // server reduce-orders
#include "typ_parental.mqh"    // parental lock
#include "typ_strategies.mqh"  // DualMA (signature) + placeholders (triangle/fibo/div/resolver)

//=== Inputs (short list; extend later) ===
input string InpSymbols      = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,USDCHF,NZDUSD";
input ENUM_TIMEFRAMES InpTradeTF = PERIOD_H1;
input ENUM_TIMEFRAMES InpStructureTF = PERIOD_H4;

// Risk & staging
input bool   UseAutoLot = true;
input double Stage1_RiskPct = 0.30; // % equity
input double Stage2_RiskPct = 0.20;
input double Stage3_RiskPct = 0.15;
input ENUM_STAGE_RISK_MODE StageRiskMode = STAGE_PROMOTE_ON_BE;

// Parental lock
input bool UseParentalLock = true;

// Exit & partials
input ENUM_EXIT_MODE ExitMode = EXIT_SINGLE_PARTIALS_SERVER_LIMITS;
input double TP_Share1 = 0.40;
input double TP_Share2 = 0.40;
input double TP_Share3 = 0.20;

// BE: tiered
input bool   BE_Tiered = true;
input int    BE_T1_Points = 200;
input double BE_T1_R      = 0.30;
input int    BE_Offset_T1 = -30; // can be negative
input int    BE_Offset_T2 = 0;
input int    BE_Offset_T3 = 15;

// DualMA (signature)
input bool   UseDualMA = true;
input int    MA1_Period = 200;
input int    MA2_Period = 34;

// News guard (placeholder control)
input bool   UseNewsGuard = true;

// Drawing
input bool   DrawStructures = true;

// Globals
TYP_Portfolio    GPortfolio;
TYP_NewBar       GNewBar;
TYP_BEManager    GBE;
TYP_Exit         GExit;
TYP_ParentalLock GLock;
TYP_DualMA       GDualMA;

int OnInit()
{
  Print("TYP2 slim init v", (string)__DATE__, " ", (string)__TIME__);

  GPortfolio.Init(InpSymbols, InpTradeTF, InpStructureTF);

  GBE.Setup(BE_Tiered, BE_T1_Points, BE_T1_R, BE_Offset_T1, BE_Offset_T2, BE_Offset_T3);
  GExit.Setup(ExitMode, TP_Share1, TP_Share2, TP_Share3);
  GDualMA.Setup(UseDualMA, MA1_Period, MA2_Period, InpTradeTF);

  EventSetTimer(2);
  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){ EventKillTimer(); }

void OnTimer(){ if(UseNewsGuard) TYP_NewsGuard::Refresh(); }

void OnTick()
{
  string sym = _Symbol;
  if(!GPortfolio.SymbolAllowed(sym)) return;

  if(GNewBar.Check(sym, InpTradeTF))
  {
    // Guards are inside modules

    // --- Strategies produce candidates ---
    SignalCandidate best; ZeroMemory(best);
    if(UseDualMA) { GDualMA.Evaluate(sym, best); }

    // TODO: extend with resolver ranking when other modules are added

    if(best.valid)
    {
      double sl = best.sl, entry = best.entry;
      double risk_pct = Stage1_RiskPct;
      double lot = TYP_Risk::CalcAutoLot(sym, entry, sl, risk_pct);
      if(lot>0)
      {
        bool ok=false;
        if(best.dir==DIR_LONG) ok=TYPTrade.Buy(lot, sym, 0.0, sl, 0.0, "TYP2");
        else                   ok=TYPTrade.Sell(lot, sym, 0.0, sl, 0.0, "TYP2");
        if(ok)
        {
          GLock.NoteOurEntry(sym, lot, best.dir);
          GExit.PlaceReduceOrders(sym, best.dir, lot, best.tp1, best.tp2, best.tp3);
        }
      }
    }
  }

  GBE.Maintain(sym);
  GExit.Maintain(sym);
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &req,
                        const MqlTradeResult &res)
{
  if(UseParentalLock) GLock.Handle(trans, req, res);
}



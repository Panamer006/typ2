//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//+------------------------------------------------------------------+
#property version   "6.01"
#property strict

#include "Modules/typ_core.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"

//+------------------------------------------------------------------+
int OnInit()
{
  Print("TYP2 Skeleton Built by Cursor. Ready for development.");
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+
void OnTick() {}
//+------------------------------------------------------------------+
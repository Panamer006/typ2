//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//+------------------------------------------------------------------+
#property version   "6.0.0"
#property strict

// --- ПОДКЛЮЧАЕМ ВСЕ МОДУЛИ-ЗАГЛУШКИ ---
#include "Modules/typ_core.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  Print("TYP2 Skeleton Built by Cursor. Ready for development.");
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  //
}
//+------------------------------------------------------------------+

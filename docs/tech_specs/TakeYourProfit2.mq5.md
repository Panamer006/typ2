//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//+------------------------------------------------------------------+
#property version   "6.01"
#property strict

#include "Modules/typ_core.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"

// --- ГЛОБАЛЬНЫЕ ОБЪЕКТЫ ---
CRegimeEngine   g_RegimeEngine;
E_MarketRegime  g_currentRegime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  Print("TYP2 Skeleton Built. Initializing modules...");
  
  g_RegimeEngine.Initialize(_Symbol, PERIOD_H1);
  
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
  g_RegimeEngine.Update(_Symbol, PERIOD_H1);
  E_MarketRegime newRegime = g_RegimeEngine.GetCurrentRegime();

  if(newRegime != g_currentRegime) 
  {
    g_currentRegime = newRegime;
    Print("=== REGIME CHANGE === New Market Regime: ", EnumToString(g_currentRegime));
  }
}
//+------------------------------------------------------------------+
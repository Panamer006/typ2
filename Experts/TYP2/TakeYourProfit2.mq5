#property strict
#property description "Take Your Profit 2.0 - Clean Build v2.1.0"
#property version   "2.1.0"

#include <Trade/Trade.mqh>
CTrade trade;

#include "typ_core.mqh"
#include "typ_risk.mqh"

int OnInit()
{
  Print("TYP2 Clean Build Initialized. Ready for module integration.");
  EquityGuard::OnNewDay();
  return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){}
void OnTick(){}

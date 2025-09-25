//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//+------------------------------------------------------------------+
#property version   "6.02"
#property strict

#include "Modules/typ_core.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"

// --- INPUT ПАРАМЕТРЫ ---
input double InpMaxDailyDD = 5.0;
input bool InpGradualDD = true;
input int InpMaxOrders = 10;
input double InpMaxSpreadPips = 3.0;
input double InpBaseRiskPercent = 1.0;

// --- ГЛОБАЛЬНЫЕ ОБЪЕКТЫ ---
CRegimeEngine   g_RegimeEngine;
CRiskManager    g_RiskManager;
CExecGate       g_ExecGate;
E_MarketRegime  g_currentRegime;

//+------------------------------------------------------------------+
int OnInit()
{
  Print("TYP2 Initializing Modules...");
  
  g_RegimeEngine.Initialize(_Symbol, PERIOD_H1);
  g_RiskManager.Initialize(InpMaxDailyDD, InpGradualDD, InpMaxOrders);
  g_ExecGate.Initialize(InpMaxSpreadPips);
  
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+
void OnTick()
{
  g_RegimeEngine.Update(_Symbol, PERIOD_H1);
  g_RiskManager.OnTick();
  
  // --- Пример торговой логики с проверками ---
  // (Этот блок будет заменен реальными сигналами в будущем)
  static datetime last_trade_time = 0;
  if (TimeCurrent() - last_trade_time > 3600) // Simple timer to avoid frequent trades
  {
      string reason = "";
      if (g_RiskManager.IsRiskOK(reason)) 
      {
          if (g_ExecGate.IsExecutionAllowed(reason)) 
          {
              Print("All checks passed. Ready to trade.");
              // --- Final calculations ---
              double sl_pips = g_ExecGate.GetStopLossPips(g_currentRegime);
              double lot = g_RiskManager.CalculateLotSize(AccountInfoDouble(ACCOUNT_BALANCE), InpBaseRiskPercent, sl_pips);
              Print("Calculated SL (pips): ", sl_pips, ", Lot: ", lot);
              
              // --- Placeholder for trade execution ---
              // trade.Buy(lot, ...);
              
              last_trade_time = TimeCurrent();
          } else {
              Print("ExecGate Block: ", reason);
          }
      } else {
          Print("RiskManager Block: ", reason);
      }
  }
}
//+------------------------------------------------------------------+
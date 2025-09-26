//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//+------------------------------------------------------------------+
#property version   "6.04" // Версия обновлена
#property strict

#include "Modules/typ_core.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"
#include "Modules/typ_pm.mqh"

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
CPositionManager g_PosManager;
E_MarketRegime  g_currentRegime;

//+------------------------------------------------------------------+
int OnInit()
{
  Print("TYP2 Initializing Modules (Refactored)...");
  
  g_RegimeEngine.Initialize(_Symbol, PERIOD_H1);
  g_RiskManager.Initialize(InpMaxDailyDD, InpGradualDD, InpMaxOrders);
  g_ExecGate.Initialize(InpMaxSpreadPips);
  g_PosManager.Initialize(&g_RiskManager);
  
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+
void OnTick()
{
  g_RegimeEngine.Update(_Symbol, PERIOD_H1);
  g_RiskManager.OnTick();
  g_PosManager.OnTick(g_currentRegime);
  
  static datetime last_trade_time = 0;
  if (TimeCurrent() - last_trade_time > 3600)
  {
      string reason = "";
      if (g_RiskManager.IsRiskOK(reason) && g_RiskManager.IsParentalLockOK(reason)) // <<<--- ДОБАВЛЕНА ПРОВЕРКА
      {
          if (g_ExecGate.IsExecutionAllowed(reason)) 
          {
              Print("All checks passed. Ready to trade.");
              double sl_pips = g_ExecGate.GetStopLossPips(g_currentRegime);
              double lot = g_RiskManager.CalculateLotSize(AccountInfoDouble(ACCOUNT_BALANCE), InpBaseRiskPercent, sl_pips);
              
              // --- Placeholder for trade execution ---
              // ulong ticket = trade.Buy(...);
              // if(ticket > 0) {
              //    double initial_risk = ...;
              //    g_PosManager.AddNewPosition(ticket, initial_risk);
              // }
              
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
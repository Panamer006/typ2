# Техническое Задание: T2-SECURITY-FOUNDATION (v2 - Полная Версия)

## 1. Цель
Создать и интегрировать два фундаментальных модуля безопасности: `CRiskManager` и `CExecGate`.

---

## 2. Файл №1: `typ_risk.mqh` (CRiskManager)

**Действие:** Полностью перезаписать файл `MQL5/Experts/TYP2/TakeYourProfit2/Modules/typ_risk.mqh` следующим кодом.

```cpp
// --- typ_risk.mqh ---
#ifndef TYP_RISK_MQH
#define TYP_RISK_MQH

#include "typ_core.mqh"
#include <Arrays\ArrayObj.mqh>

// --- Структура для отслеживания состояния по каждому символу ---
class CSymbolState : public CObject {
public:
    string   symbol;
    datetime last_close_time;
    double   last_close_profit;
    int      sl_cluster_count;
    datetime sl_cluster_start_time;
    CSymbolState() : last_close_time(0), last_close_profit(0.0), sl_cluster_count(0), sl_cluster_start_time(0) {}
};

class CRiskManager {
private:
    // --- ПАРАМЕТРЫ ---
    double m_max_daily_dd_percent;
    bool   m_is_gradual_dd_reduction_enabled;
    int    m_max_total_open_orders;
    
    // --- СОСТОЯНИЕ КЛАССА ---
    double   m_equity_on_day_start;
    datetime m_current_day_start_time;
    bool     m_is_trading_blocked_by_dd;

public:
    CRiskManager() : m_max_daily_dd_percent(5.0), m_is_gradual_dd_reduction_enabled(true), m_max_total_open_orders(10),
                     m_equity_on_day_start(0), m_current_day_start_time(0), m_is_trading_blocked_by_dd(false) {}
    ~CRiskManager() {}

    void Initialize(double max_daily_dd, bool gradual_dd, int max_orders) {
        m_max_daily_dd_percent = max_daily_dd;
        m_is_gradual_dd_reduction_enabled = gradual_dd;
        m_max_total_open_orders = max_orders;
    }

    void OnTick() {
        datetime now = TimeCurrent();
        if (m_current_day_start_time == 0) { // First tick initialization
            m_current_day_start_time = now - (now % 86400);
            m_equity_on_day_start = AccountInfoDouble(ACCOUNT_EQUITY);
        }
        if (now >= m_current_day_start_time + 86400) {
            m_current_day_start_time = now - (now % 86400);
            m_equity_on_day_start = AccountInfoDouble(ACCOUNT_EQUITY);
            m_is_trading_blocked_by_dd = false;
        }
    }
    
    bool IsRiskOK(string &reason) {
        // --- Daily DD Check ---
        double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
        double dd_percent = (m_equity_on_day_start - current_equity) / m_equity_on_day_start * 100.0;
        if (dd_percent >= m_max_daily_dd_percent) {
            m_is_trading_blocked_by_dd = true;
        }
        if (m_is_trading_blocked_by_dd) {
            reason = "Daily DD limit reached";
            return false;
        }
        
        // --- Max Orders Check ---
        if (PositionsTotal() >= m_max_total_open_orders) {
            reason = "Max total orders limit reached";
            return false;
        }
        
        return true;
    }
    
    double CalculateLotSize(double balance, double risk_percent, double sl_pips) {
        if (sl_pips <= 0) return 0.01;
        double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
        double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
        double sl_money = sl_pips * tick_value / tick_size;
        double risk_money = balance * (risk_percent / 100.0);
        if (sl_money <= 0) return 0.01;
        
        return NormalizeDouble(risk_money / sl_money, 2);
    }
};
#endif

## 3. Файл №2: typ_execfilters.mqh (CExecGate)
Действие: Полностью перезаписать файл MQL5/Experts/TYP2/TakeYourProfit2/Modules/typ_execfilters.mqh следующим кодом.
code
C++
// --- typ_execfilters.mqh ---
#ifndef TYP_EXECFILTERS_MQH
#define TYP_EXECFILTERS_MQH

#include "typ_regime_engine.mqh"

class CExecGate {
private:
    // --- ПАРАМЕТРЫ ---
    double m_max_spread_pips;
    
    // --- СОСТОЯНИЕ КЛАССА ---
    int m_h_atr_sl; // H1 ATR for SL

public:
    CExecGate() : m_max_spread_pips(3.0), m_h_atr_sl(INVALID_HANDLE) {}
    ~CExecGate() {
        if (m_h_atr_sl != INVALID_HANDLE) IndicatorRelease(m_h_atr_sl);
    }

    void Initialize(double max_spread) {
        m_max_spread_pips = max_spread;
        m_h_atr_sl = iATR(_Symbol, PERIOD_H1, 14);
    }

    bool IsExecutionAllowed(string &reason) {
        // --- Spread Check ---
        double current_spread_pips = (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
        if (current_spread_pips > m_max_spread_pips) {
            reason = "Spread is too high";
            return false;
        }
        return true;
    }
    
    double GetStopLossPips(E_MarketRegime current_regime) {
        double atr_buffer[];
        if (CopyBuffer(m_h_atr_sl, 0, 0, 1, atr_buffer) <= 0) return 20.0; // Default SL
        
        double atr_pips = atr_buffer / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        
        // Simple logic for now: 1.5 * ATR
        return atr_pips * 1.5;
    }
};
#endif

##4. Файл №3: TakeYourProfit2.mq5 (Интеграция)
Действие: Полностью перезаписать главный файл MQL5/Experts/TYP2/TakeYourProfit2/TakeYourProfit2.mq5 следующим кодом.
code
C++
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
# Техническое Задание: T2-SECURITY-FOUNDATION

## 1. Цель
Создать два фундаментальных модуля безопасности:
1.  **CRiskManager (`typ_risk.mqh`):** Центральный модуль управления рисками.
2.  **CExecGate (`typ_execfilters.mqh`):** Модуль-фильтр рыночных условий.

---
## 2. Файл №1: `typ_risk.mqh` (CRiskManager)
**Действие:** Создать/перезаписать файл `MQL5/Experts/TYP2/TakeYourProfit2/Modules/typ_risk.mqh` следующим содержимым.
```cpp
// --- typ_risk.mqh ---
#ifndef TYP_RISK_MQH
#define TYP_RISK_MQH
#include "typ_core.mqh"
#include <Arrays\ArrayObj.mqh>
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
    double m_max_daily_dd_percent; bool m_is_gradual_dd_reduction_enabled; int m_max_positions_per_currency; int m_max_total_open_orders;
    double m_max_total_open_lots; double m_max_total_risk_percent; int m_cooldown_seconds_win; int m_cooldown_seconds_loss;
    int m_sl_cluster_limit; int m_sl_cluster_timespan_hours; bool m_is_eow_protocol_enabled; ENUM_DAY_OF_WEEK m_eow_day; int m_eow_hour; bool m_is_recovery_protocol_enabled;
    double m_equity_on_day_start; datetime m_current_day_start_time; bool m_is_trading_blocked_by_dd; double m_loss_for_recovery; CArrayObj* m_symbol_states;
public:
    CRiskManager() { m_symbol_states = new CArrayObj(); }
    ~CRiskManager() { if(CheckPointer(m_symbol_states) == POINTER_DYNAMIC) { delete m_symbol_states; } }
    void Initialize(double max_daily_dd, bool gradual_dd, int max_pos_currency, int max_total_orders, double max_total_lots, double max_total_risk, int cd_win, int cd_loss, int sl_limit, int sl_hours, bool eow_enabled, ENUM_DAY_OF_WEEK eow_day, int eow_hour, bool recovery_enabled) {
        m_max_daily_dd_percent = max_daily_dd; m_is_gradual_dd_reduction_enabled = gradual_dd; m_max_positions_per_currency = max_pos_currency; m_max_total_open_orders = max_total_orders;
        m_max_total_open_lots = max_total_lots; m_max_total_risk_percent = max_total_risk; m_cooldown_seconds_win = cd_win; m_cooldown_seconds_loss = cd_loss;
        m_sl_cluster_limit = sl_limit; m_sl_cluster_timespan_hours = sl_hours; m_is_eow_protocol_enabled = eow_enabled; m_eow_day = eow_day; m_eow_hour = eow_hour; m_is_recovery_protocol_enabled = recovery_enabled;
        m_equity_on_day_start = AccountInfoDouble(ACCOUNT_EQUITY); m_current_day_start_time = 0; m_is_trading_blocked_by_dd = false; m_loss_for_recovery = 0.0;
    }
    void OnTick() { datetime now = TimeCurrent(); if (now >= m_current_day_start_time + 86400) { m_current_day_start_time = now - (now % 86400); m_equity_on_day_start = AccountInfoDouble(ACCOUNT_EQUITY); m_is_trading_blocked_by_dd = false; m_loss_for_recovery = 0.0; } }
    void OnTradeClose(const string symbol, const double profit) { CSymbolState* state = GetSymbolState(symbol, true); if(state == NULL) return; state.last_close_time = TimeCurrent(); state.last_close_profit = profit; if (profit < 0) { if (TimeCurrent() - state.sl_cluster_start_time > m_sl_cluster_timespan_hours * 3600) { state.sl_cluster_start_time = TimeCurrent(); state.sl_cluster_count = 1; } else { state.sl_cluster_count++; } } }
    double GetRiskModifier(const string symbol, const double new_trade_risk_percent, const double new_trade_lot, string &reason) { double dd_modifier = GetDailyDDRiskModifier(reason); if (dd_modifier == 0.0) return 0.0; if (!IsEOWProtocolActive(reason)) return 0.0; if (!IsCurrencyExposureOK(symbol, reason)) return 0.0; if (!IsTotalExposureOK(new_trade_risk_percent, new_trade_lot, reason)) return 0.0; if (!IsCooldownOK(symbol, reason)) return 0.0; if (!IsStopLossClusterOK(symbol, reason)) return 0.0; return dd_modifier; }
    double CalculateLotSize(const double balance, const double risk_percent, const double sl_pips) { return 0.01; }
private:
    CSymbolState* GetSymbolState(const string symbol, bool create_if_not_exists) { for (int i = 0; i < m_symbol_states.Total(); i++) { CSymbolState* state = m_symbol_states.At(i); if (state.symbol == symbol) return state; } if (create_if_not_exists) { CSymbolState* new_state = new CSymbolState(); new_state.symbol = symbol; m_symbol_states.Add(new_state); return new_state; } return NULL; }
    double GetDailyDDRiskModifier(string &reason) { double current_equity = AccountInfoDouble(ACCOUNT_EQUITY); double dd = m_equity_on_day_start - current_equity; double dd_percent = (dd / m_equity_on_day_start) * 100.0; if (dd_percent >= m_max_daily_dd_percent) { m_is_trading_blocked_by_dd = true; if(m_loss_for_recovery == 0) m_loss_for_recovery = dd; } if (m_is_trading_blocked_by_dd) { reason = "Daily DD limit reached"; return 0.0; } if (m_is_recovery_protocol_enabled && m_loss_for_recovery > 0) { if (current_equity < m_equity_on_day_start - (m_loss_for_recovery / 2.0)) { reason = "Recovery Protocol active"; return 0.5; } else { m_loss_for_recovery = 0.0; } } if (m_is_gradual_dd_reduction_enabled && dd_percent >= m_max_daily_dd_percent * 0.5) { reason = "Gradual DD reduction active"; return 0.5; } return 1.0; }
    bool IsCurrencyExposureOK(const string symbol, string &reason) { return true; }
    bool IsTotalExposureOK(const double new_trade_risk_percent, double new_trade_lot, string &reason) { if (PositionsTotal() >= m_max_total_open_orders) { reason = "Max total orders limit reached"; return false; } return true; }
    bool IsCooldownOK(const string symbol, string &reason) { CSymbolState* state = GetSymbolState(symbol, false); if(state == NULL) return true; long elapsed = TimeCurrent() - state.last_close_time; long required_cooldown = (state.last_close_profit >= 0) ? m_cooldown_seconds_win : m_cooldown_seconds_loss; if (elapsed < required_cooldown) { reason = "Symbol is in cooldown"; return false; } return true; }
    bool IsStopLossClusterOK(const string symbol, string &reason) { CSymbolState* state = GetSymbolState(symbol, false); if(state == NULL) return true; if (state.sl_cluster_count >= m_sl_cluster_limit) { reason = "Stop loss cluster limit reached"; return false; } return true; }
    bool IsEOWProtocolActive(string &reason) { if (!m_is_eow_protocol_enabled) return true; MqlDateTime dt; TimeCurrent(dt); if (dt.day_of_week >= m_eow_day && dt.hour >= m_eow_hour) { reason = "End of Week protocol active"; return false; } return true; }
};
#endif
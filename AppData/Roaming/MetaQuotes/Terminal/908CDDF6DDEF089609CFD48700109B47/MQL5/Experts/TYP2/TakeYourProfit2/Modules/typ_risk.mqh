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
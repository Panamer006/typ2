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

    // Инициализирует фильтры исполнения и индикаторы
    void Initialize(double max_spread) {
        m_max_spread_pips = max_spread;
        m_h_atr_sl = iATR(_Symbol, PERIOD_H1, 14);
    }

    // Проверяет, разрешено ли исполнение сделок в текущих условиях
    bool IsExecutionAllowed(string &reason) {
        // --- Spread Check ---
        double current_spread_pips = (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) * SymbolInfoDouble(_Symbol, SYMBOL_POINT));
        if (current_spread_pips > m_max_spread_pips) {
            reason = "Spread is too high";
            return false;
        }
        return true;
    }
    
    // Рассчитывает размер стоп-лосса в пунктах на основе ATR
    double GetStopLossPips(E_MarketRegime current_regime) {
        double atr_buffer[];
        if (CopyBuffer(m_h_atr_sl, 0, 0, 1, atr_buffer) <= 0) return 20.0; // Default SL
        
        double atr_pips = atr_buffer[0] / SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        
        // Simple logic for now: 1.5 * ATR
        return atr_pips * 1.5;
    }
};
#endif
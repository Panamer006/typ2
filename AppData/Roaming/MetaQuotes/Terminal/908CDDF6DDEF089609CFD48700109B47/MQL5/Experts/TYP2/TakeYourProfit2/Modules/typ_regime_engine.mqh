// --- typ_regime_engine.mqh ---
#ifndef TYP_REGIME_ENGINE_MQH
#define TYP_REGIME_ENGINE_MQH

#include "typ_core.mqh"

// --- Публичный Enum для Режимов Рынка ---
enum E_MarketRegime {
    REGIME_TREND_MATURE,      // Зрелый, устоявшийся тренд
    REGIME_FLAT_QUIET,        // Тихий флэт, низкая волатильность
    REGIME_UNDEFINED          // Начальное состояние
};

class CRegimeEngine {
private:
    // --- Состояние ---
    E_MarketRegime  m_current_regime;
    datetime        m_last_update_time;

    // --- Хэндлы Индикаторов ---
    int             m_h_adx;

public:
    CRegimeEngine() : m_current_regime(REGIME_UNDEFINED), m_last_update_time(0), m_h_adx(INVALID_HANDLE) {}
   ~CRegimeEngine() {
        if (m_h_adx != INVALID_HANDLE) IndicatorRelease(m_h_adx);
    }

    void Initialize(const string symbol, const ENUM_TIMEFRAMES tf) {
        m_h_adx = iADX(symbol, tf, 14);
    }

    void Update(const string symbol, const ENUM_TIMEFRAMES tf) {
        datetime current_bar_time = (datetime)SeriesInfoInteger(symbol, tf, SERIES_LASTBAR_DATE);
        if(current_bar_time > m_last_update_time) {
            m_last_update_time = current_bar_time;
            CalculateRegime(symbol, tf); 
        }
    }

    E_MarketRegime GetCurrentRegime() const { return m_current_regime; }

private:
    void CalculateRegime(const string symbol, const ENUM_TIMEFRAMES tf) {
        // Временная простая логика для теста:
        double adx_buffer[];
        if (CopyBuffer(m_h_adx, 0, 1, 1, adx_buffer) > 0) {
            if (adx_buffer[0] > 25) {
                 m_current_regime = REGIME_TREND_MATURE;
            } else {
                 m_current_regime = REGIME_FLAT_QUIET;
            }
        }
    }
};

#endif
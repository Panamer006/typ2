// --- typ_regime_engine.mqh ---
#ifndef TYP_REGIME_ENGINE_MQH
#define TYP_REGIME_ENGINE_MQH

#include "typ_core.mqh"

// Enum для Режимов Рынка
enum E_MarketRegime {
    REGIME_TREND_MATURE,
    REGIME_FLAT_QUIET,
    REGIME_UNDEFINED
};

// Класс для определения текущего режима рынка
class CRegimeEngine {
private:
    // --- Пороги индикаторов ---
    double m_adx_trend_threshold; // Порог ADX для определения тренда

    // --- Состояние ---
    E_MarketRegime  m_current_regime;
    datetime        m_last_update_time;

    // --- Хэндлы Индикаторов ---
    int m_h_adx;
    // TODO: Добавить хэндлы для Choppiness, Donchian, Volume, RSI, MACD

public:
    // Конструктор: инициализирует параметры
    CRegimeEngine() : 
        m_adx_trend_threshold(25.0),
        m_current_regime(REGIME_UNDEFINED), 
        m_last_update_time(0), 
        m_h_adx(INVALID_HANDLE) 
    {}

    // Деструктор: освобождает ресурсы
   ~CRegimeEngine() {
        if (m_h_adx != INVALID_HANDLE) IndicatorRelease(m_h_adx);
    }

    // Инициализирует индикаторы для анализа режима рынка
    void Initialize(const string symbol, const ENUM_TIMEFRAMES tf) {
        m_h_adx = iADX(symbol, tf, 14);
        // TODO: Добавить инициализацию других индикаторов
    }

    // Обновляет состояние на каждом тике (если новый бар)
    void Update(const string symbol, const ENUM_TIMEFRAMES tf) {
        datetime current_bar_time = (datetime)SeriesInfoInteger(symbol, tf, SERIES_LASTBAR_DATE);
        if(current_bar_time > m_last_update_time) {
            m_last_update_time = current_bar_time;
            CalculateRegime(symbol, tf); 
        }
    }

    // Возвращает текущий режим рынка (не изменяет состояние)
    E_MarketRegime GetCurrentRegime() const { return m_current_regime; }

private:
    // Рассчитывает режим рынка
    void CalculateRegime(const string symbol, const ENUM_TIMEFRAMES tf) {
        double adx_buffer[];
        if (CopyBuffer(m_h_adx, 0, 1, 1, adx_buffer) > 0) {
            if (adx_buffer[0] > m_adx_trend_threshold) {
                 m_current_regime = REGIME_TREND_MATURE;
            } else {
                 m_current_regime = REGIME_FLAT_QUIET;
            }
        }
    }
};
#endif
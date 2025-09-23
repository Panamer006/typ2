// --- typ_regime_engine.mqh ---
#ifndef __TYP_REGIME_ENGINE_MQH__
#define __TYP_REGIME_ENGINE_MQH__

// --- Публичный Enum для Режимов Рынка ---
enum E_MarketRegime {
    // --- ТРЕНДОВЫЕ РЕЖИМЫ ---
    REGIME_TREND_YOUNG,       // Молодой, зарождающийся тренд
    REGIME_TREND_MATURE,      // Зрелый, устоявшийся тренд
    REGIME_TREND_WEAKENING,   // Ослабевающий тренд, возможен разворот

    // --- ФЛЭТОВЫЕ РЕЖИМЫ ---
    REGIME_FLAT_QUIET,        // Тихий флэт, низкая волатильность
    REGIME_FLAT_CHOPPY,       // "Пила", высокая волатильность в диапазоне

    // --- ЗАЩИТНЫЕ РЕЖИМЫ ---
    REGIME_UNSTABLE,          // Конфликт индикаторов, торговля запрещена
    REGIME_RISK_OFF,          // Макро-паника, запрет покупки рисковых активов
    
    // --- НАЧАЛЬНОЕ СОСТОЯНИЕ ---
    REGIME_UNDEFINED
};

class CRegimeEngine {
private:
    // --- Параметры ---
    string          m_symbol;
    ENUM_TIMEFRAMES m_tf;
    int             m_hysteresis_bars;

    // --- Состояние ---
    E_MarketRegime  m_current_regime;
    E_MarketRegime  m_potential_regime;
    int             m_hysteresis_counter;
    datetime        m_last_update_time;

    // --- Хэндлы Индикаторов ---
    int             m_h_adx;
    // ... (другие хэндлы будут добавлены в TODO)

public:
    CRegimeEngine() : m_hysteresis_bars(3),
                      m_current_regime(REGIME_UNDEFINED),
                      m_potential_regime(REGIME_UNDEFINED),
                      m_hysteresis_counter(0),
                      m_last_update_time(0),
                      m_h_adx(INVALID_HANDLE)
    {}
    ~CRegimeEngine() {
        if (m_h_adx != INVALID_HANDLE) IndicatorRelease(m_h_adx);
    }

    void Initialize(const string symbol, const ENUM_TIMEFRAMES tf);
    void Update();
    E_MarketRegime GetCurrentRegime() const { return m_current_regime; }

private:
    void CalculateRegime();
};

void CRegimeEngine::Initialize(const string symbol, const ENUM_TIMEFRAMES tf) {
    m_symbol = symbol;
    m_tf = tf;
    m_h_adx = iADX(m_symbol, m_tf, 14);
    // TODO: Добавить создание хэндлов для Choppiness, Donchian, Volume, RSI, MACD, ATR и S&P 500.
}

void CRegimeEngine::Update() {
    datetime current_bar_time = (datetime)SeriesInfoInteger(m_symbol, m_tf, SERIES_LASTBAR_DATE);
    if(current_bar_time > m_last_update_time) {
        m_last_update_time = current_bar_time;
        CalculateRegime(); 
    }
}

void CRegimeEngine::CalculateRegime() {
    // --- ЗАГЛУШКА ---
    // TODO: Реализовать полную логику определения режимов, как было утверждено:
    // 1. Проверка на RISK_OFF по S&P 500.
    // 2. Проверка на UNSTABLE по конфликту индикаторов.
    // 3. Проверка на TREND_WEAKENING по дивергенции.
    // 4. Определение основных режимов (TREND_YOUNG/MATURE, FLAT_QUIET/CHOPPY).
    // 5. Реализация гистерезиса.
    
    // Временная простая логика для теста:
    double adx_buffer[];
    if (CopyBuffer(m_h_adx, 0, 1, 1, adx_buffer) > 0) {
        if (adx_buffer[0] > 25) {
             m_potential_regime = REGIME_TREND_MATURE;
        } else {
             m_potential_regime = REGIME_FLAT_QUIET;
        }
    }
    
    // Простая логика гистерезиса
    static E_MarketRegime prev_potential_regime = REGIME_UNDEFINED;
    if (m_potential_regime == prev_potential_regime) m_hysteresis_counter++;
    else m_hysteresis_counter = 1;
    
    if (m_hysteresis_counter >= m_hysteresis_bars) {
        m_current_regime = m_potential_regime;
    }
    prev_potential_regime = m_potential_regime;
}

#endif // __TYP_REGIME_ENGINE_MQH__
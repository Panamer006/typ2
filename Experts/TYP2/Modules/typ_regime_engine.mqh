// --- typ_regime_engine.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Architect: Gemini
// Task: T2-CORE-REGIME :: Market Regime Engine

#property copyright "TYP2"

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
    REGIME_UNDEFINED          // Неопределенное состояние при инициализации
};

// --- Класс Движка Режимов ---
class CRegimeEngine {
private:
    // --- Параметры ---
    string          m_symbol;
    ENUM_TIMEFRAMES m_tf;
    int             m_hysteresis_bars;

    // --- Пороговые значения индикаторов (устранение магических чисел) ---
    double          m_adx_trend_threshold;      // ADX для определения тренда (22)
    double          m_adx_flat_threshold;       // ADX для определения флэта (18)
    double          m_adx_mature_threshold;     // ADX для зрелого тренда (40)
    double          m_adx_unstable_threshold;   // ADX для нестабильности (30)
    double          m_chop_trend_threshold;     // Choppiness для тренда (38)
    double          m_chop_flat_threshold;      // Choppiness для флэта (62)
    double          m_donchian_z_threshold;     // Donchian Z-Score порог (0.5)
    double          m_volume_z_threshold;       // Volume Z-Score порог (-1.0)

    // --- Состояние ---
    E_MarketRegime  m_current_regime;
    E_MarketRegime  m_potential_regime;
    int             m_hysteresis_counter;
    datetime        m_last_update_time;

    // --- Хэндлы Индикаторов ---
    int             m_h_adx;
    int             m_h_atr;
    int             m_h_rsi;
    int             m_h_macd_main;
    int             m_h_macd_signal;
    int             m_h_chop;               // Choppiness Index
    int             m_h_donchian_upper;     // Donchian Channel Upper
    int             m_h_donchian_lower;     // Donchian Channel Lower
    int             m_h_volume;             // Normalized Volume
    
    // --- Вспомогательные методы ---
    void CalculateRegime();
    double GetIndicatorValue(int handle, int buffer_index, int shift);
    double CalculateZScore(double current_value, int lookback_period, const double &data[]);
    bool IsMarketCrashing(string sp500_symbol);
    bool HasDivergence();
    double CalculateChoppinessIndex();
    double CalculateDonchianWidth();
    double CalculateNormalizedVolume();

public:
    /**
     * @brief Конструктор движка режимов рынка
     * 
     * Инициализирует все пороговые значения по умолчанию и устанавливает
     * начальное состояние всех хэндлов индикаторов
     */
    CRegimeEngine() : m_hysteresis_bars(3),
                      // Инициализация пороговых значений
                      m_adx_trend_threshold(22.0),
                      m_adx_flat_threshold(18.0),
                      m_adx_mature_threshold(40.0),
                      m_adx_unstable_threshold(30.0),
                      m_chop_trend_threshold(38.0),
                      m_chop_flat_threshold(62.0),
                      m_donchian_z_threshold(0.5),
                      m_volume_z_threshold(-1.0),
                      // Состояние
                      m_current_regime(REGIME_UNDEFINED),
                      m_potential_regime(REGIME_UNDEFINED),
                      m_hysteresis_counter(0),
                      m_last_update_time(0),
                      // Хэндлы индикаторов
                      m_h_adx(INVALID_HANDLE),
                      m_h_atr(INVALID_HANDLE),
                      m_h_rsi(INVALID_HANDLE),
                      m_h_macd_main(INVALID_HANDLE),
                      m_h_macd_signal(INVALID_HANDLE),
                      m_h_chop(INVALID_HANDLE),
                      m_h_donchian_upper(INVALID_HANDLE),
                      m_h_donchian_lower(INVALID_HANDLE),
                      m_h_volume(INVALID_HANDLE)
    {}

    /**
     * @brief Деструктор движка режимов рынка
     * 
     * Освобождает все созданные хэндлы индикаторов для предотвращения
     * утечек памяти
     */
    ~CRegimeEngine() {
        if(m_h_adx != INVALID_HANDLE) IndicatorRelease(m_h_adx);
        if(m_h_atr != INVALID_HANDLE) IndicatorRelease(m_h_atr);
        if(m_h_rsi != INVALID_HANDLE) IndicatorRelease(m_h_rsi);
        if(m_h_macd_main != INVALID_HANDLE) IndicatorRelease(m_h_macd_main);
        if(m_h_macd_signal != INVALID_HANDLE) IndicatorRelease(m_h_macd_signal);
        if(m_h_chop != INVALID_HANDLE) IndicatorRelease(m_h_chop);
        if(m_h_donchian_upper != INVALID_HANDLE) IndicatorRelease(m_h_donchian_upper);
        if(m_h_donchian_lower != INVALID_HANDLE) IndicatorRelease(m_h_donchian_lower);
        if(m_h_volume != INVALID_HANDLE) IndicatorRelease(m_h_volume);
    }

    // --- Публичные Методы ---
    
    /**
     * @brief Инициализация движка режимов
     * @param symbol Торговый символ для анализа
     * @param tf Таймфрейм для анализа
     */
    void Initialize(const string symbol, const ENUM_TIMEFRAMES tf);
    
    /**
     * @brief Обновление состояния движка (вызывается на каждом тике)
     * 
     * Выполняет полный расчет режима только при появлении нового бара
     * для оптимизации производительности
     */
    void Update();
    
    /**
     * @brief Получение текущего режима рынка
     * @return Текущий определенный режим рынка
     */
    E_MarketRegime GetCurrentRegime() const;
    
    /**
     * @brief Получение строкового представления текущего режима
     * @return Строковое описание режима для логов и панели
     */
    string GetCurrentRegimeString() const;
};

// --- Реализация Методов ---

//+------------------------------------------------------------------+
//| Инициализация движка режимов                                      |
//+------------------------------------------------------------------+
void CRegimeEngine::Initialize(const string symbol, const ENUM_TIMEFRAMES tf) {
    m_symbol = symbol;
    m_tf = tf;

    // --- Создаем хэндлы для индикаторов на указанном таймфрейме ---
    m_h_adx = iADX(m_symbol, m_tf, 14);
    if(m_h_adx == INVALID_HANDLE) {
        Print("Regime Engine ERROR: Failed to create ADX handle");
        return;
    }

    m_h_atr = iATR(m_symbol, m_tf, 14);
    if(m_h_atr == INVALID_HANDLE) {
        Print("Regime Engine ERROR: Failed to create ATR handle");
        return;
    }

    m_h_rsi = iRSI(m_symbol, m_tf, 14, PRICE_CLOSE);
    if(m_h_rsi == INVALID_HANDLE) {
        Print("Regime Engine ERROR: Failed to create RSI handle");
        return;
    }

    m_h_macd_main = iMACD(m_symbol, m_tf, 12, 26, 9, PRICE_CLOSE);
    if(m_h_macd_main == INVALID_HANDLE) {
        Print("Regime Engine ERROR: Failed to create MACD handle");
        return;
    }

    // Создание хэндлов для дополнительных индикаторов
    // TODO: m_h_chop = iCustom(m_symbol, m_tf, "ChoppinessIndex", 14);
    // TODO: m_h_volume = iCustom(m_symbol, m_tf, "NormalizedVolume", 20);
    // TODO: Добавить хэндл для тикера S&P 500 (например, "US500")
    
    // Заглушки для пока не реализованных индикаторов
    m_h_chop = INVALID_HANDLE; // Будет реализован позже
    m_h_volume = INVALID_HANDLE; // Будет реализован позже

    Print("Regime Engine: Initialized successfully for ", symbol, " ", EnumToString(tf));
}

//+------------------------------------------------------------------+
//| Обновление движка (вызывается на каждом тике)                     |
//+------------------------------------------------------------------+
void CRegimeEngine::Update() {
    datetime current_bar_time = (datetime)SeriesInfoInteger(m_symbol, m_tf, SERIES_LASTBAR_DATE);

    // --- Выполняем полный расчет только один раз на бар ---
    if(current_bar_time > m_last_update_time) {
        m_last_update_time = current_bar_time;
        
        // Вызываем приватный метод, который содержит всю логику
        CalculateRegime(); 
    }
}

//+------------------------------------------------------------------+
//| Основная логика определения режима рынка                          |
//+------------------------------------------------------------------+
void CRegimeEngine::CalculateRegime() {
    // --- 1. Сбор Данных ---
    // Получаем значения всех индикаторов на последнем закрытом баре (shift=1)
    double adx_value = GetIndicatorValue(m_h_adx, 0, 1);
    double atr_value = GetIndicatorValue(m_h_atr, 0, 1);
    double rsi_value = GetIndicatorValue(m_h_rsi, 0, 1);
    double macd_main = GetIndicatorValue(m_h_macd_main, 0, 1);
    
    // Вычисляем дополнительные индикаторы
    double chop_value = CalculateChoppinessIndex();
    double donchian_width = CalculateDonchianWidth();
    double normalized_volume = CalculateNormalizedVolume();
    
    // Получаем исторические данные для Z-Score расчетов
    double atr_history[], volume_history[], donchian_history[];
    int lookback_period = 50; // Период для статистического анализа
    
    ArraySetAsSeries(atr_history, true);
    ArraySetAsSeries(volume_history, true);
    ArraySetAsSeries(donchian_history, true);
    
    // Собираем исторические данные ATR
    double atr_z_score = 0.0;
    if(CopyBuffer(m_h_atr, 0, 1, lookback_period, atr_history) > 0) {
        atr_z_score = CalculateZScore(atr_value, lookback_period, atr_history);
    }
    
    // Для объема и Donchian width используем упрощенные Z-Score пока
    double vol_z_score = (normalized_volume - 1.0) / 0.5; // Примерная нормализация
    double donchian_z_score = (donchian_width - 5.0) / 2.0; // Примерная нормализация

    // Проверяем S&P 500
    bool is_sp500_crashing = IsMarketCrashing("US500");

    // --- 2. Определение Потенциального Режима ---
    E_MarketRegime new_potential_regime;

    // --- Приоритет 1: Макро-Паника ---
    if (is_sp500_crashing) {
        new_potential_regime = REGIME_RISK_OFF;
    
    // --- Приоритет 2: Конфликт Индикаторов ---
    } else if (adx_value > m_adx_unstable_threshold && vol_z_score < m_volume_z_threshold) {
        new_potential_regime = REGIME_UNSTABLE;

    // --- Приоритет 3: Ослабевающий Тренд ---
    } else if (m_current_regime == REGIME_TREND_MATURE && HasDivergence()) {
        new_potential_regime = REGIME_TREND_WEAKENING;

    // --- Приоритет 4: Основные Режимы ---
    } else {
        bool is_trend = (adx_value > m_adx_trend_threshold && 
                        chop_value < m_chop_trend_threshold && 
                        donchian_z_score > m_donchian_z_threshold);
        bool is_flat = (adx_value < m_adx_flat_threshold && 
                       chop_value > m_chop_flat_threshold);

        if (is_trend) {
            if (adx_value > m_adx_mature_threshold) new_potential_regime = REGIME_TREND_MATURE;
            else new_potential_regime = REGIME_TREND_YOUNG;
        } else if (is_flat) {
            if (atr_z_score < m_volume_z_threshold) new_potential_regime = REGIME_FLAT_QUIET;
            else new_potential_regime = REGIME_FLAT_CHOPPY;
        } else {
            // Если ни тренд, ни флэт не определены, сохраняем предыдущий режим
            new_potential_regime = m_potential_regime; // Сохраняем стабильность
        }
    }
    
    m_potential_regime = new_potential_regime;

    // --- 3. Гистерезис ---
    static E_MarketRegime prev_potential_regime = REGIME_UNDEFINED;

    if (m_potential_regime == prev_potential_regime) {
        m_hysteresis_counter++;
    } else {
        m_hysteresis_counter = 1; // Сбрасываем счетчик при смене потенциального режима
    }
    
    prev_potential_regime = m_potential_regime;

    if (m_hysteresis_counter >= m_hysteresis_bars) {
        if (m_current_regime != m_potential_regime) {
            Print("Regime Engine: New regime confirmed -> ", GetCurrentRegimeString());
            m_current_regime = m_potential_regime;
        }
    }
}

//+------------------------------------------------------------------+
//| Получение текущего режима                                         |
//+------------------------------------------------------------------+
/**
 * @brief Получение текущего режима рынка
 * @return Текущий определенный режим рынка
 */
E_MarketRegime CRegimeEngine::GetCurrentRegime() const {
    return m_current_regime;
}

//+------------------------------------------------------------------+
//| Получение строкового представления текущего режима                |
//+------------------------------------------------------------------+
/**
 * @brief Получение строкового представления текущего режима
 * @return Строковое описание режима для логов и панели
 */
string CRegimeEngine::GetCurrentRegimeString() const {
    switch(m_current_regime) {
        case REGIME_TREND_YOUNG:      return "TREND_YOUNG";
        case REGIME_TREND_MATURE:     return "TREND_MATURE";
        case REGIME_TREND_WEAKENING:  return "TREND_WEAKENING";
        case REGIME_FLAT_QUIET:       return "FLAT_QUIET";
        case REGIME_FLAT_CHOPPY:      return "FLAT_CHOPPY";
        case REGIME_UNSTABLE:         return "UNSTABLE";
        case REGIME_RISK_OFF:         return "RISK_OFF";
        case REGIME_UNDEFINED:        return "UNDEFINED";
        default:                      return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Вспомогательные функции (заглушки для компиляции)                 |
//+------------------------------------------------------------------+

/**
 * @brief Получение значения индикатора
 * @param handle Хэндл индикатора
 * @param buffer_index Индекс буфера индикатора
 * @param shift Смещение (бар)
 * @return Значение индикатора или 0.0 при ошибке
 */
double CRegimeEngine::GetIndicatorValue(int handle, int buffer_index, int shift) {
    if(handle == INVALID_HANDLE) return 0.0;
    
    double buffer[];
    if(CopyBuffer(handle, buffer_index, shift, 1, buffer) <= 0) {
        return 0.0;
    }
    return buffer[0];
}

/**
 * @brief Вычисление Z-Score для нормализации показателей
 * @param current_value Текущее значение для анализа
 * @param lookback_period Период для расчета статистики
 * @param data Массив исторических данных
 * @return Z-Score значение или 0.0 при ошибке
 */
double CRegimeEngine::CalculateZScore(double current_value, int lookback_period, const double &data[]) {
    // Вычисляем Z-Score для текущего значения относительно исторических данных
    if(lookback_period <= 1) return 0.0;
    
    // Вычисляем среднее значение
    double sum = 0.0;
    for(int i = 0; i < lookback_period; i++) {
        sum += data[i];
    }
    double mean = sum / lookback_period;
    
    // Вычисляем стандартное отклонение
    double variance_sum = 0.0;
    for(int i = 0; i < lookback_period; i++) {
        double diff = data[i] - mean;
        variance_sum += diff * diff;
    }
    double std_dev = MathSqrt(variance_sum / lookback_period);
    
    if(std_dev == 0.0) return 0.0;
    
    // Возвращаем Z-Score
    return (current_value - mean) / std_dev;
}

/**
 * @brief Проверка макро-панических условий на рынке
 * @param sp500_symbol Символ S&P 500 для анализа
 * @return true если детектирована макро-паника, false в противном случае
 */
bool CRegimeEngine::IsMarketCrashing(string sp500_symbol) {
    // Проверяем падение S&P 500 для определения макро-паники
    // Критерии: падение более чем на 3% за последние 2 дня или 5% за неделю
    
    double close[];
    ArraySetAsSeries(close, true);
    
    // Получаем данные по дневному таймфрейму для S&P 500
    if(CopyClose(sp500_symbol, PERIOD_D1, 0, 7, close) <= 0) {
        // Если нет данных по S&P 500, проверяем текущий инструмент на сильное падение
        if(CopyClose(m_symbol, PERIOD_D1, 0, 7, close) <= 0) {
            return false; // Нет данных - не паникуем
        }
    }
    
    if(ArraySize(close) < 7) return false;
    
    // Проверяем падение за 2 дня (более 3%)
    double change_2d = (close[0] - close[2]) / close[2] * 100.0;
    if(change_2d < -3.0) {
        Print("Regime Engine: Market crash detected - 2-day drop: ", change_2d, "%");
        return true;
    }
    
    // Проверяем падение за неделю (более 5%)
    double change_7d = (close[0] - close[6]) / close[6] * 100.0;
    if(change_7d < -5.0) {
        Print("Regime Engine: Market crash detected - 7-day drop: ", change_7d, "%");
        return true;
    }
    
    return false;
}

/**
 * @brief Определение дивергенции между ценой и осцилляторами
 * @return true если обнаружена дивергенция, false в противном случае
 */
bool CRegimeEngine::HasDivergence() {
    // Простая проверка дивергенции между ценой и RSI
    // Ищем ситуации, когда цена делает новые максимумы, а RSI - нет (медвежья дивергенция)
    // или цена делает новые минимумы, а RSI - нет (бычья дивергенция)
    
    int lookback = 10;
    double close[], rsi[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(rsi, true);
    
    if(CopyClose(m_symbol, m_tf, 1, lookback, close) <= 0 ||
       CopyBuffer(m_h_rsi, 0, 1, lookback, rsi) <= 0) {
        return false;
    }
    
    if(ArraySize(close) < lookback || ArraySize(rsi) < lookback) return false;
    
    // Находим максимумы и минимумы цены и RSI за период
    int price_max_idx = ArrayMaximum(close, 0, lookback);
    int price_min_idx = ArrayMinimum(close, 0, lookback);
    int rsi_max_idx = ArrayMaximum(rsi, 0, lookback);
    int rsi_min_idx = ArrayMinimum(rsi, 0, lookback);
    
    // Медвежья дивергенция: новый максимум цены при более низком максимуме RSI
    if(price_max_idx < 3 && rsi_max_idx > 3) { // Недавний максимум цены, но более старый максимум RSI
        if(close[price_max_idx] > close[rsi_max_idx] && rsi[price_max_idx] < rsi[rsi_max_idx]) {
            Print("Regime Engine: Bearish divergence detected");
            return true;
        }
    }
    
    // Бычья дивергенция: новый минимум цены при более высоком минимуме RSI
    if(price_min_idx < 3 && rsi_min_idx > 3) { // Недавний минимум цены, но более старый минимум RSI
        if(close[price_min_idx] < close[rsi_min_idx] && rsi[price_min_idx] > rsi[rsi_min_idx]) {
            Print("Regime Engine: Bullish divergence detected");
            return true;
        }
    }
    
    return false;
}

/**
 * @brief Расчет индекса Choppiness для определения флэтовых периодов
 * @return Значение Choppiness Index (0-100) или 50.0 при ошибке
 */
double CRegimeEngine::CalculateChoppinessIndex() {
    // Choppiness Index = 100 * LOG10(SUM(TrueRange, n) / (MAX(HIGH, n) - MIN(LOW, n))) / LOG10(n)
    // где n = период расчета (обычно 14)
    int period = 14;
    
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);
    
    if(CopyHigh(m_symbol, m_tf, 1, period + 1, high) <= 0 ||
       CopyLow(m_symbol, m_tf, 1, period + 1, low) <= 0 ||
       CopyClose(m_symbol, m_tf, 1, period + 1, close) <= 0) {
        return 50.0; // Возвращаем нейтральное значение при ошибке
    }
    
    // Находим максимум и минимум за период
    double max_high = high[ArrayMaximum(high, 0, period)];
    double min_low = low[ArrayMinimum(low, 0, period)];
    double high_low_range = max_high - min_low;
    
    if(high_low_range <= 0) return 50.0;
    
    // Вычисляем сумму True Range за период
    double sum_tr = 0.0;
    for(int i = 0; i < period; i++) {
        double tr1 = high[i] - low[i];
        double tr2 = (i < period) ? MathAbs(high[i] - close[i+1]) : tr1;
        double tr3 = (i < period) ? MathAbs(low[i] - close[i+1]) : tr1;
        double true_range = MathMax(tr1, MathMax(tr2, tr3));
        sum_tr += true_range;
    }
    
    // Вычисляем Choppiness Index
    double chop_index = 100.0 * MathLog10(sum_tr / high_low_range) / MathLog10(period);
    
    // Ограничиваем значение диапазоном 0-100
    return MathMax(0.0, MathMin(100.0, chop_index));
}

/**
 * @brief Расчет нормализованной ширины канала Донча
 * @return Ширина канала относительно ATR или 1.0 при ошибке
 */
double CRegimeEngine::CalculateDonchianWidth() {
    // Donchian Channel Width = (Highest High - Lowest Low) / ATR
    // Нормализуем ширину канала относительно ATR для сравнимости между инструментами
    int period = 20; // Стандартный период для Donchian Channel
    
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(m_symbol, m_tf, 1, period, high) <= 0 ||
       CopyLow(m_symbol, m_tf, 1, period, low) <= 0) {
        return 1.0; // Возвращаем нейтральное значение при ошибке
    }
    
    // Находим максимум и минимум за период
    double highest_high = high[ArrayMaximum(high, 0, period)];
    double lowest_low = low[ArrayMinimum(low, 0, period)];
    double channel_width = highest_high - lowest_low;
    
    // Получаем текущее значение ATR для нормализации
    double atr_value = GetIndicatorValue(m_h_atr, 0, 1);
    if(atr_value <= 0) return 1.0;
    
    // Возвращаем нормализованную ширину канала
    return channel_width / atr_value;
}

/**
 * @brief Расчет нормализованного объема торгов
 * @return Нормализованный объем (текущий/средний) или 1.0 при ошибке
 */
double CRegimeEngine::CalculateNormalizedVolume() {
    // Нормализуем объем относительно скользящего среднего за последние 20 периодов
    int period = 20;
    
    double volume[];
    ArraySetAsSeries(volume, true);
    
    if(CopyTickVolume(m_symbol, m_tf, 1, period, volume) <= 0) {
        return 1.0; // Возвращаем нейтральное значение при ошибке
    }
    
    // Вычисляем среднее значение объема за период
    double volume_sum = 0.0;
    for(int i = 0; i < period; i++) {
        volume_sum += volume[i];
    }
    double volume_average = volume_sum / period;
    
    if(volume_average <= 0) return 1.0;
    
    // Возвращаем нормализованный объем (текущий объем / средний объем)
    return volume[0] / volume_average;
}

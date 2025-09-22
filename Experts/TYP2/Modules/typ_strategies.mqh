// --- typ_strategies.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Sprint 2 :: Trading Strategies Module
#property copyright "TYP2"

// --- Подключение модулей технического анализа ---
#include "typ_patterns.mqh"
#include "typ_figures.mqh"
#include "typ_fibo.mqh"
#include "typ_regime_engine.mqh"

/**
 * @brief Структура для передачи сигналов-кандидатов
 * 
 * Унифицированная структура для передачи торговых сигналов
 * между стратегиями и системой исполнения.
 */
struct SignalCandidate {
    bool   isValid;          // Валидность сигнала
    string strategyID;       // Идентификатор стратегии
    string symbol;           // Торговый символ
    int    direction;        // Направление (1 = BUY, -1 = SELL)
    double entry_price;      // Цена входа
    double stop_loss;        // Стоп-лосс
    double take_profit;      // Тейк-профит
    double confidence_score; // Оценка уверенности (0.0 - 1.0)
    double lot_size;         // Размер лота
    string signal_reason;    // Причина/описание сигнала
    datetime signal_time;    // Время генерации сигнала
    
    // Дополнительные параметры
    double risk_reward_ratio; // Соотношение риск/прибыль
    double pattern_strength;  // Сила паттерна
    double fibo_confluence;   // Confluence с уровнями Фибо
    string timeframe;         // Таймфрейм анализа
    
    /**
     * @brief Конструктор с инициализацией по умолчанию
     */
    SignalCandidate() {
        isValid = false;
        strategyID = "";
        symbol = "";
        direction = 0;
        entry_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        confidence_score = 0.0;
        lot_size = 0.0;
        signal_reason = "";
        signal_time = 0;
        risk_reward_ratio = 0.0;
        pattern_strength = 0.0;
        fibo_confluence = 0.0;
        timeframe = "";
    }
};

/**
 * @brief Стратегия "Ночной Возврат к Среднему" (Night Mean Reversion)
 * 
 * Торгует в периоды низкой волатильности (обычно ночью по GMT),
 * используя паттерны разворота и уровни Фибоначчи для поиска
 * точек входа против краткосрочного тренда.
 */
class CStrategy_NightMR {
private:
    // --- Указатели на модули ТА ---
    CPatterns*  m_patterns;      // Модуль детекции паттернов
    CFigures*   m_figures;       // Модуль графических фигур
    CFibo*      m_fibo;          // Модуль Фибоначчи
    
    // --- Параметры стратегии ---
    string      m_strategy_id;   // Идентификатор стратегии
    string      m_symbol;        // Торговый символ
    ENUM_TIMEFRAMES m_timeframe; // Рабочий таймфрейм
    
    // --- Пороговые значения ---
    double      m_min_pattern_strength;    // Минимальная сила паттерна
    double      m_min_fibo_confluence;     // Минимальная confluence Фибо
    double      m_max_atr_threshold;       // Максимальный ATR для входа
    double      m_risk_reward_min;         // Минимальное R:R
    int         m_lookback_bars;           // Период анализа
    
    // --- Временные ограничения ---
    int         m_start_hour;              // Начало торгового окна
    int         m_end_hour;                // Конец торгового окна
    
public:
    /**
     * @brief Конструктор стратегии Night Mean Reversion
     */
    CStrategy_NightMR() : m_patterns(NULL),
                          m_figures(NULL),
                          m_fibo(NULL),
                          m_strategy_id("NIGHT_MR"),
                          m_symbol(""),
                          m_timeframe(PERIOD_H1),
                          m_min_pattern_strength(0.6),
                          m_min_fibo_confluence(0.5),
                          m_max_atr_threshold(0.8),
                          m_risk_reward_min(1.5),
                          m_lookback_bars(100),
                          m_start_hour(22),  // 22:00 GMT
                          m_end_hour(6)      // 06:00 GMT
    {}
    
    /**
     * @brief Деструктор стратегии
     */
    ~CStrategy_NightMR() {
        // Указатели не удаляем - они принадлежат главному модулю
    }
    
    /**
     * @brief Инициализация стратегии
     * @param patterns_ptr Указатель на модуль паттернов
     * @param figures_ptr Указатель на модуль фигур
     * @param fibo_ptr Указатель на модуль Фибоначчи
     * @param symbol Торговый символ
     * @param timeframe Рабочий таймфрейм
     * 
     * TODO: Добавить валидацию указателей и параметров
     */
    void Initialize(CPatterns* patterns_ptr, CFigures* figures_ptr, CFibo* fibo_ptr, 
                   const string symbol = "", ENUM_TIMEFRAMES timeframe = PERIOD_H1) {
        m_patterns = patterns_ptr;
        m_figures = figures_ptr;
        m_fibo = fibo_ptr;
        m_symbol = (symbol == "") ? Symbol() : symbol;
        m_timeframe = timeframe;
    }
    
    /**
     * @brief Основной метод генерации сигналов
     * @param current_regime Текущий режим рынка
     * @return Структура сигнала-кандидата
     * 
     * TODO: Реализовать полную логику скоринга:
     * 1. Проверка временного окна (ночные часы)
     * 2. Анализ волатильности (низкая ATR)
     * 3. Поиск паттернов разворота
     * 4. Confluence с уровнями Фибоначчи
     * 5. Проверка графических фигур
     * 6. Расчет entry/SL/TP уровней
     * 7. Оценка confidence score
     */
    SignalCandidate GetSignal(E_MarketRegime current_regime = REGIME_UNDEFINED) {
        SignalCandidate candidate;
        candidate.strategyID = m_strategy_id;
        candidate.symbol = m_symbol;
        candidate.timeframe = EnumToString(m_timeframe);
        candidate.signal_time = TimeCurrent();
        
        // TODO: Проверка временного окна
        if(!IsInTradingWindow()) {
            candidate.signal_reason = "Outside trading window";
            return candidate;
        }
        
        // TODO: Проверка режима рынка (предпочтительно FLAT_QUIET)
        if(current_regime != REGIME_FLAT_QUIET && current_regime != REGIME_UNDEFINED) {
            candidate.signal_reason = "Market regime not suitable for mean reversion";
            return candidate;
        }
        
        // TODO: Анализ волатильности
        if(!IsVolatilityAcceptable()) {
            candidate.signal_reason = "Volatility too high for night trading";
            return candidate;
        }
        
        // TODO: Поиск паттернов разворота
        string pattern_name;
        double pattern_strength = 0.0;
        int pattern_direction = AnalyzeReversalPatterns(pattern_name, pattern_strength);
        
        if(pattern_direction == 0 || pattern_strength < m_min_pattern_strength) {
            candidate.signal_reason = "No strong reversal patterns found";
            return candidate;
        }
        
        // TODO: Анализ уровней Фибоначчи
        double fibo_confluence = AnalyzeFiboConfluence();
        if(fibo_confluence < m_min_fibo_confluence) {
            candidate.signal_reason = "Insufficient Fibonacci confluence";
            return candidate;
        }
        
        // TODO: Расчет уровней входа, стопа и цели
        double entry, stop_loss, take_profit;
        if(!CalculateTradeLevels(pattern_direction, entry, stop_loss, take_profit)) {
            candidate.signal_reason = "Unable to calculate valid trade levels";
            return candidate;
        }
        
        // TODO: Проверка R:R соотношения
        double risk_reward = CalculateRiskReward(entry, stop_loss, take_profit, pattern_direction);
        if(risk_reward < m_risk_reward_min) {
            candidate.signal_reason = "Risk/Reward ratio too low";
            return candidate;
        }
        
        // Формируем валидный сигнал
        candidate.isValid = true;
        candidate.direction = pattern_direction;
        candidate.entry_price = entry;
        candidate.stop_loss = stop_loss;
        candidate.take_profit = take_profit;
        candidate.confidence_score = CalculateConfidenceScore(pattern_strength, fibo_confluence);
        candidate.risk_reward_ratio = risk_reward;
        candidate.pattern_strength = pattern_strength;
        candidate.fibo_confluence = fibo_confluence;
        candidate.signal_reason = StringFormat("Night MR: %s pattern (%.2f) + Fibo confluence (%.2f)", 
                                              pattern_name, pattern_strength, fibo_confluence);
        
        return candidate;
    }
    
    /**
     * @brief Обновление параметров стратегии
     * @param min_pattern_strength Минимальная сила паттерна
     * @param min_fibo_confluence Минимальная confluence Фибо
     * @param max_atr_threshold Максимальный ATR
     * @param risk_reward_min Минимальное R:R
     * @param start_hour Начальный час торговли
     * @param end_hour Конечный час торговли
     */
    void UpdateParameters(double min_pattern_strength = -1, double min_fibo_confluence = -1,
                         double max_atr_threshold = -1, double risk_reward_min = -1,
                         int start_hour = -1, int end_hour = -1) {
        if(min_pattern_strength >= 0) m_min_pattern_strength = min_pattern_strength;
        if(min_fibo_confluence >= 0) m_min_fibo_confluence = min_fibo_confluence;
        if(max_atr_threshold >= 0) m_max_atr_threshold = max_atr_threshold;
        if(risk_reward_min >= 0) m_risk_reward_min = risk_reward_min;
        if(start_hour >= 0) m_start_hour = start_hour;
        if(end_hour >= 0) m_end_hour = end_hour;
    }
    
    /**
     * @brief Получение статистики стратегии
     * @param stats Строка со статистикой (выходной параметр)
     */
    void GetStrategyStats(string &stats) {
        stats = StringFormat("Strategy: %s | Symbol: %s | TF: %s | Pattern Min: %.2f | Fibo Min: %.2f | ATR Max: %.2f | RR Min: %.2f",
                           m_strategy_id, m_symbol, EnumToString(m_timeframe),
                           m_min_pattern_strength, m_min_fibo_confluence, m_max_atr_threshold, m_risk_reward_min);
    }
    
private:
    // --- ПРИВАТНЫЕ МЕТОДЫ АНАЛИЗА ---
    
    /**
     * @brief Проверка временного окна торговли
     * @return true если сейчас время для торговли
     */
    bool IsInTradingWindow() {
        // TODO: Реализовать проверку ночного времени GMT
        // Учесть переход через полночь (start_hour > end_hour)
        MqlDateTime dt;
        TimeToStruct(TimeGMT(), dt);
        
        if(m_start_hour > m_end_hour) {
            // Переход через полночь (например, 22:00 - 06:00)
            return (dt.hour >= m_start_hour || dt.hour <= m_end_hour);
        } else {
            // Обычный диапазон (например, 02:00 - 06:00)
            return (dt.hour >= m_start_hour && dt.hour <= m_end_hour);
        }
    }
    
    /**
     * @brief Проверка приемлемости волатильности
     * @return true если волатильность подходит для ночной торговли
     */
    bool IsVolatilityAcceptable() {
        // TODO: Реализовать проверку ATR
        // - Получить текущее значение ATR
        // - Сравнить с историческими значениями
        // - Убедиться что волатильность не слишком высока
        return true; // Заглушка
    }
    
    /**
     * @brief Анализ паттернов разворота
     * @param pattern_name Название найденного паттерна (выходной параметр)
     * @param pattern_strength Сила паттерна (выходной параметр)
     * @return Направление паттерна (1 = бычий, -1 = медвежий, 0 = нет)
     */
    int AnalyzeReversalPatterns(string &pattern_name, double &pattern_strength) {
        // TODO: Реализовать анализ паттернов разворота:
        // - Проверить все паттерны разворота через m_patterns
        // - Найти самый сильный паттерн
        // - Вернуть направление и силу
        
        pattern_name = "None";
        pattern_strength = 0.0;
        return 0; // Заглушка
    }
    
    /**
     * @brief Анализ confluence с уровнями Фибоначчи
     * @return Сила confluence от 0.0 до 1.0
     */
    double AnalyzeFiboConfluence() {
        // TODO: Реализовать анализ Фибо через m_fibo:
        // - Найти ближайшие значимые свинги
        // - Рассчитать уровни коррекции и расширения
        // - Проверить confluence текущей цены с уровнями
        // - Учесть мультитаймфреймовый анализ
        
        return 0.0; // Заглушка
    }
    
    /**
     * @brief Расчет торговых уровней
     * @param direction Направление сделки
     * @param entry Цена входа (выходной параметр)
     * @param stop_loss Стоп-лосс (выходной параметр)
     * @param take_profit Тейк-профит (выходной параметр)
     * @return true если уровни рассчитаны успешно
     */
    bool CalculateTradeLevels(int direction, double &entry, double &stop_loss, double &take_profit) {
        // TODO: Реализовать расчет уровней:
        // - Entry: текущая цена или уровень паттерна
        // - Stop Loss: за уровнем инвалидации паттерна
        // - Take Profit: к ближайшему уровню сопротивления/поддержки
        
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        entry = current_price;
        stop_loss = current_price;
        take_profit = current_price;
        
        return false; // Заглушка
    }
    
    /**
     * @brief Расчет соотношения риск/прибыль
     * @param entry Цена входа
     * @param stop_loss Стоп-лосс
     * @param take_profit Тейк-профит
     * @param direction Направление сделки
     * @return Соотношение Risk:Reward
     */
    double CalculateRiskReward(double entry, double stop_loss, double take_profit, int direction) {
        double risk = MathAbs(entry - stop_loss);
        double reward = MathAbs(take_profit - entry);
        
        if(risk <= 0.0) return 0.0;
        return reward / risk;
    }
    
    /**
     * @brief Расчет общей уверенности в сигнале
     * @param pattern_strength Сила паттерна
     * @param fibo_confluence Confluence Фибо
     * @return Confidence score от 0.0 до 1.0
     */
    double CalculateConfidenceScore(double pattern_strength, double fibo_confluence) {
        // TODO: Реализовать взвешенную оценку:
        // - Вес паттерна: 60%
        // - Вес Фибо: 30%
        // - Вес временного фактора: 10%
        
        double weighted_score = (pattern_strength * 0.6) + (fibo_confluence * 0.3) + (0.5 * 0.1);
        return MathMin(1.0, MathMax(0.0, weighted_score));
    }
};

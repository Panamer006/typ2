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
     * @brief Основной метод генерации сигналов с полной системой скоринга
     * @param current_regime Текущий режим рынка
     * @return Структура сигнала-кандидата
     * 
     * Полная логика скоринга:
     * 1. "Якорь": касание 2-й границы Боллинджера
     * 2. Скоринг: проверка всех 12 критических подтверждений
     * 3. Формирование сигнала при score > 80
     */
    SignalCandidate GetSignal(E_MarketRegime current_regime = REGIME_UNDEFINED) {
        SignalCandidate candidate;
        candidate.strategyID = m_strategy_id;
        candidate.symbol = m_symbol;
        candidate.timeframe = EnumToString(m_timeframe);
        candidate.signal_time = TimeCurrent();
        
        // ЭТАП 1: Базовые фильтры
        if(!IsInTradingWindow()) {
            candidate.signal_reason = "Outside trading window";
            return candidate;
        }
        
        if(current_regime != REGIME_FLAT_QUIET && current_regime != REGIME_FLAT_CHOPPY) {
            candidate.signal_reason = "Market regime not suitable for mean reversion";
            return candidate;
        }
        
        // ЭТАП 2: "ЯКОРЬ" - Касание 2-й границы Боллинджера
        double bb_upper, bb_lower, bb_middle;
        int bb_touch_direction = 0; // 1 = касание верхней, -1 = касание нижней
        
        if(!CheckBollingerBandAnchor(bb_upper, bb_lower, bb_middle, bb_touch_direction)) {
            candidate.signal_reason = "No Bollinger Band anchor detected";
            return candidate;
        }
        
        // ЭТАП 3: Система скоринга (12 критических подтверждений)
        double total_score = 0;
        string scoring_details = "";
        
        // 1. VWAP анализ (10 очков)
        double vwap_score = AnalyzeVWAP(bb_touch_direction);
        total_score += vwap_score;
        scoring_details += StringFormat("VWAP: %.1f; ", vwap_score);
        
        // 2. Дивергенция RSI (15 очков)
        double divergence_score = AnalyzeDivergence(bb_touch_direction);
        total_score += divergence_score;
        scoring_details += StringFormat("Divergence: %.1f; ", divergence_score);
        
        // 3. Паттерны разворота (12 очков)
        double pattern_score = AnalyzeReversalPatternsScoring(bb_touch_direction);
        total_score += pattern_score;
        scoring_details += StringFormat("Patterns: %.1f; ", pattern_score);
        
        // 4. Фибоначчи confluence (10 очков)
        double fibo_score = AnalyzeFiboConfluenceScoring();
        total_score += fibo_score;
        scoring_details += StringFormat("Fibo: %.1f; ", fibo_score);
        
        // 5. Объемный анализ (8 очков)
        double volume_score = AnalyzeVolumeProfile();
        total_score += volume_score;
        scoring_details += StringFormat("Volume: %.1f; ", volume_score);
        
        // 6. ATR контекст (5 очков)
        double atr_score = AnalyzeATRContext();
        total_score += atr_score;
        scoring_details += StringFormat("ATR: %.1f; ", atr_score);
        
        // 7. Время суток (5 очков)
        double time_score = AnalyzeTimeContext();
        total_score += time_score;
        scoring_details += StringFormat("Time: %.1f; ", time_score);
        
        // 8. Графические фигуры (7 очков)
        double figures_score = AnalyzeFiguresContext(bb_touch_direction);
        total_score += figures_score;
        scoring_details += StringFormat("Figures: %.1f; ", figures_score);
        
        // 9. Уровни поддержки/сопротивления (8 очков)
        double levels_score = AnalyzeSupportResistance(bb_touch_direction);
        total_score += levels_score;
        scoring_details += StringFormat("S/R: %.1f; ", levels_score);
        
        // 10. Корреляция с другими инструментами (5 очков)
        double correlation_score = AnalyzeCorrelation();
        total_score += correlation_score;
        scoring_details += StringFormat("Corr: %.1f; ", correlation_score);
        
        // 11. Сезонность и статистика (3 очка)
        double seasonal_score = AnalyzeSeasonality();
        total_score += seasonal_score;
        scoring_details += StringFormat("Season: %.1f; ", seasonal_score);
        
        // 12. Фундаментальный контекст (2 очка)
        double fundamental_score = AnalyzeFundamentalContext();
        total_score += fundamental_score;
        scoring_details += StringFormat("Fund: %.1f", fundamental_score);
        
        // ЭТАП 4: Проверка порогового значения
        if(total_score < 80.0) {
            candidate.signal_reason = StringFormat("Score too low: %.1f/100 (%s)", total_score, scoring_details);
            return candidate;
        }
        
        // ЭТАП 5: Расчет торговых уровней
        double entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        double stop_loss, take_profit;
        
        if(bb_touch_direction == 1) {
            // Касание верхней границы BB - сигнал на продажу
            stop_loss = bb_upper + (bb_upper - bb_lower) * 0.1;
            take_profit = bb_middle;
        } else {
            // Касание нижней границы BB - сигнал на покупку
            stop_loss = bb_lower - (bb_upper - bb_lower) * 0.1;
            take_profit = bb_middle;
        }
        
        double risk_reward = CalculateRiskReward(entry_price, stop_loss, take_profit, -bb_touch_direction);
        if(risk_reward < m_risk_reward_min) {
            candidate.signal_reason = StringFormat("R:R too low: %.2f", risk_reward);
            return candidate;
        }
        
        // ЭТАП 6: Формирование валидного сигнала
        candidate.isValid = true;
        candidate.direction = -bb_touch_direction; // Инверсия: касание верхней BB = продажа
        candidate.entry_price = entry_price;
        candidate.stop_loss = stop_loss;
        candidate.take_profit = take_profit;
        candidate.confidence_score = total_score / 100.0; // Преобразуем в 0-1
        candidate.risk_reward_ratio = risk_reward;
        candidate.signal_reason = StringFormat("Night MR Score: %.1f/100 | %s | R:R: %.2f", 
                                              total_score, scoring_details, risk_reward);
        
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
     * @brief Проверка "якоря" - касание 2-й границы Боллинджера
     * @param bb_upper Верхняя граница BB (выходной параметр)
     * @param bb_lower Нижняя граница BB (выходной параметр)  
     * @param bb_middle Средняя линия BB (выходной параметр)
     * @param touch_direction Направление касания (выходной параметр)
     * @return true если обнаружено касание границы
     */
    bool CheckBollingerBandAnchor(double &bb_upper, double &bb_lower, double &bb_middle, int &touch_direction) {
        // Заглушка: простой расчет BB на основе SMA и стандартного отклонения
        MqlRates rates[50];
        if(CopyRates(m_symbol, m_timeframe, 0, 25, rates) < 20) return false;
        
        // Рассчитываем SMA(20)
        double sma = 0;
        for(int i = 1; i <= 20; i++) {
            sma += rates[i].close;
        }
        sma /= 20;
        bb_middle = sma;
        
        // Рассчитываем стандартное отклонение
        double variance = 0;
        for(int i = 1; i <= 20; i++) {
            variance += MathPow(rates[i].close - sma, 2);
        }
        double std_dev = MathSqrt(variance / 20);
        
        bb_upper = sma + (2.0 * std_dev);
        bb_lower = sma - (2.0 * std_dev);
        
        // Проверяем касание границ
        double current_price = rates[0].close;
        double tolerance = std_dev * 0.1;
        
        if(MathAbs(current_price - bb_upper) <= tolerance) {
            touch_direction = 1;
            return true;
        } else if(MathAbs(current_price - bb_lower) <= tolerance) {
            touch_direction = -1;
            return true;
        }
        
        return false;
    }
    
    // === 12 МЕТОДОВ СКОРИНГА ===
    
    /**
     * @brief 1. VWAP анализ (максимум 10 очков)
     */
    double AnalyzeVWAP(int direction) {
        // Заглушка: проверяем позицию цены относительно VWAP
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        // В реальности здесь должен быть расчет VWAP
        double vwap_level = current_price * (1 + (direction * 0.001)); // Имитация
        
        double distance = MathAbs(current_price - vwap_level) / current_price;
        if(distance < 0.002) return 8.0; // Близко к VWAP
        else if(distance < 0.005) return 5.0; // Средняя дистанция
        else return 2.0; // Далеко от VWAP
    }
    
    /**
     * @brief 2. Дивергенция RSI (максимум 15 очков)
     */
    double AnalyzeDivergence(int direction) {
        // Заглушка: анализ дивергенции между ценой и RSI
        MqlRates rates[10];
        if(CopyRates(m_symbol, m_timeframe, 0, 10, rates) < 5) return 0;
        
        // Проверяем расхождение цены и "RSI" (имитация)
        bool price_higher = rates[0].close > rates[4].close;
        bool rsi_lower = true; // Имитация RSI дивергенции
        
        if((direction == 1 && !price_higher && rsi_lower) || (direction == -1 && price_higher && !rsi_lower)) {
            return 12.0; // Сильная дивергенция
        } else if((direction == 1 && price_higher) || (direction == -1 && !price_higher)) {
            return 6.0; // Слабая дивергенция
        }
        return 0; // Нет дивергенции
    }
    
    /**
     * @brief 3. Паттерны разворота (максимум 12 очков)
     */
    double AnalyzeReversalPatternsScoring(int direction) {
        if(!m_patterns) return 0;
        
        MqlRates rates[50];
        if(CopyRates(m_symbol, m_timeframe, 0, 50, rates) < 10) return 0;
        
        string pattern_name;
        bool has_pattern = false;
        double pattern_strength = 0;
        
        if(direction == 1) {
            has_pattern = m_patterns.FindAnyBullishPattern(rates, 1, pattern_name);
        } else {
            has_pattern = m_patterns.FindAnyBearishPattern(rates, 1, pattern_name);
        }
        
        if(has_pattern) {
            pattern_strength = m_patterns.GetPatternStrength(rates, 1, pattern_name);
            return pattern_strength * 12.0; // Масштабируем до 12 очков
        }
        return 0;
    }
    
    /**
     * @brief 4. Фибоначчи confluence (максимум 10 очков)
     */
    double AnalyzeFiboConfluenceScoring() {
        if(!m_fibo) return 5.0; // Нейтральный счет без модуля
        
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        // В реальности здесь должен быть анализ через m_fibo
        // Заглушка: имитируем confluence анализ
        return 7.0; // Средний confluence
    }
    
    /**
     * @brief 5. Объемный анализ (максимум 8 очков)
     */
    double AnalyzeVolumeProfile() {
        MqlRates rates[20];
        if(CopyRates(m_symbol, m_timeframe, 0, 20, rates) < 10) return 0;
        
        // Анализируем объем текущей свечи относительно средних
        double current_volume = (double)rates[0].tick_volume;
        double avg_volume = 0;
        for(int i = 1; i < 10; i++) {
            avg_volume += (double)rates[i].tick_volume;
        }
        avg_volume /= 9;
        
        if(current_volume > avg_volume * 1.5) return 8.0; // Высокий объем
        else if(current_volume > avg_volume * 1.2) return 5.0; // Повышенный объем
        else if(current_volume < avg_volume * 0.7) return 2.0; // Низкий объем
        else return 4.0; // Средний объем
    }
    
    /**
     * @brief 6. ATR контекст (максимум 5 очков)
     */
    double AnalyzeATRContext() {
        // Анализ текущей волатильности относительно исторической
        double current_range = SymbolInfoDouble(m_symbol, SYMBOL_ASK) - SymbolInfoDouble(m_symbol, SYMBOL_BID);
        // Заглушка: имитируем ATR анализ
        return 3.0; // Нормальная волатильность
    }
    
    /**
     * @brief 7. Время суток (максимум 5 очков)
     */
    double AnalyzeTimeContext() {
        MqlDateTime dt;
        TimeToStruct(TimeGMT(), dt);
        
        // Лучшее время для Night MR: 22:00-06:00 GMT
        if((dt.hour >= 22) || (dt.hour <= 6)) {
            if(dt.hour >= 1 && dt.hour <= 4) return 5.0; // Оптимальное время
            else return 3.0; // Хорошее время
        } else if(dt.hour >= 18 && dt.hour <= 21) {
            return 1.0; // Переходное время
        }
        return 0; // Неподходящее время
    }
    
    /**
     * @brief 8. Графические фигуры (максимум 7 очков)
     */
    double AnalyzeFiguresContext(int direction) {
        if(!m_figures) return 3.0; // Нейтральный счет без модуля
        
        // В реальности здесь должен быть анализ через m_figures
        // Заглушка: имитируем анализ фигур
        return 4.0; // Средняя поддержка от фигур
    }
    
    /**
     * @brief 9. Уровни поддержки/сопротивления (максимум 8 очков)
     */
    double AnalyzeSupportResistance(int direction) {
        MqlRates rates[100];
        if(CopyRates(m_symbol, m_timeframe, 0, 100, rates) < 50) return 0;
        
        double current_price = rates[0].close;
        int nearby_levels = 0;
        
        // Простой поиск уровней поддержки/сопротивления
        for(int i = 10; i < 50; i++) {
            if(MathAbs(rates[i].high - current_price) < current_price * 0.002) nearby_levels++;
            if(MathAbs(rates[i].low - current_price) < current_price * 0.002) nearby_levels++;
        }
        
        if(nearby_levels >= 3) return 8.0; // Сильный уровень
        else if(nearby_levels >= 2) return 5.0; // Средний уровень
        else if(nearby_levels >= 1) return 3.0; // Слабый уровень
        else return 0; // Нет уровней
    }
    
    /**
     * @brief 10. Корреляция с другими инструментами (максимум 5 очков)
     */
    double AnalyzeCorrelation() {
        // Заглушка: анализ корреляции с индексами/валютами
        return 3.0; // Нейтральная корреляция
    }
    
    /**
     * @brief 11. Сезонность и статистика (максимум 3 очка)
     */
    double AnalyzeSeasonality() {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        
        // Простая сезонная логика
        if(dt.day_of_week == MONDAY || dt.day_of_week == FRIDAY) {
            return 2.0; // Начало/конец недели
        } else if(dt.day_of_week >= TUESDAY && dt.day_of_week <= THURSDAY) {
            return 3.0; // Середина недели (лучше для реверсий)
        }
        return 1.0;
    }
    
    /**
     * @brief 12. Фундаментальный контекст (максимум 2 очка)
     */
    double AnalyzeFundamentalContext() {
        // Заглушка: анализ экономических событий, новостей
        return 1.0; // Нейтральный фундаментальный фон
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

/**
 * @brief Стратегия "Границы Канала" (Channel Boundary)
 * 
 * Торгует отскоки от границ канала в периоды флэта,
 * используя каналы Дончиана или Кельтнера для определения границ.
 */
class CStrategy_ChannelBoundary {
private:
    // --- Указатели на модули ТА ---
    CPatterns*  m_patterns;
    CFigures*   m_figures;
    
    // --- Параметры стратегии ---
    string      m_strategy_id;
    string      m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    
    // --- Параметры канала ---
    int         m_channel_period;        // Период канала
    double      m_min_channel_width;     // Минимальная ширина канала
    double      m_touch_tolerance;       // Допуск касания границы
    
    // --- Пороговые значения ---
    double      m_min_atr_threshold;     // Минимальный ATR для торговли
    double      m_max_atr_threshold;     // Максимальный ATR для торговли
    double      m_risk_reward_min;       // Минимальное R:R
    
    // --- Хэндлы индикаторов ---
    int         m_h_atr;                 // ATR для волатильности
    
public:
    /**
     * @brief Конструктор стратегии Channel Boundary
     */
    CStrategy_ChannelBoundary() : m_patterns(NULL),
                                  m_figures(NULL),
                                  m_strategy_id("CHANNEL_BOUNDARY"),
                                  m_symbol(""),
                                  m_timeframe(PERIOD_H1),
                                  m_channel_period(20),
                                  m_min_channel_width(0.001),
                                  m_touch_tolerance(0.0005),
                                  m_min_atr_threshold(0.0003),
                                  m_max_atr_threshold(0.002),
                                  m_risk_reward_min(1.5),
                                  m_h_atr(INVALID_HANDLE)
    {}
    
    /**
     * @brief Деструктор стратегии
     */
    ~CStrategy_ChannelBoundary() {
        if(m_h_atr != INVALID_HANDLE) IndicatorRelease(m_h_atr);
    }
    
    /**
     * @brief Инициализация стратегии
     * @param patterns_ptr Указатель на модуль паттернов
     * @param figures_ptr Указатель на модуль фигур
     * @param symbol Торговый символ
     * @param timeframe Рабочий таймфрейм
     */
    void Initialize(CPatterns* patterns_ptr, CFigures* figures_ptr, 
                   const string symbol = "", ENUM_TIMEFRAMES timeframe = PERIOD_H1) {
        m_patterns = patterns_ptr;
        m_figures = figures_ptr;
        m_symbol = (symbol == "") ? Symbol() : symbol;
        m_timeframe = timeframe;
        
        m_h_atr = iATR(m_symbol, m_timeframe, 14);
    }
    
    /**
     * @brief Основной метод генерации сигналов
     * @param current_regime Текущий режим рынка
     * @return Структура сигнала-кандидата
     */
    SignalCandidate GetSignal(E_MarketRegime current_regime = REGIME_UNDEFINED) {
        SignalCandidate candidate;
        candidate.strategyID = m_strategy_id;
        candidate.symbol = m_symbol;
        candidate.timeframe = EnumToString(m_timeframe);
        candidate.signal_time = TimeCurrent();
        
        // 1. Проверка режима рынка (работаем только во флэте)
        if(current_regime != REGIME_FLAT_QUIET && current_regime != REGIME_FLAT_CHOPPY) {
            candidate.signal_reason = "Market regime not suitable for channel trading";
            return candidate;
        }
        
        // 2. Получаем границы канала Дончиана
        double upper_boundary, lower_boundary, middle_line;
        if(!GetChannelBoundaries(upper_boundary, lower_boundary, middle_line)) {
            candidate.signal_reason = "Unable to calculate channel boundaries";
            return candidate;
        }
        
        // 3. Проверяем ширину канала
        double channel_width = upper_boundary - lower_boundary;
        if(channel_width < m_min_channel_width) {
            candidate.signal_reason = "Channel too narrow for trading";
            return candidate;
        }
        
        // 4. Определяем касание границы канала
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        int touch_direction = 0; // 1 = верхняя граница (SELL), -1 = нижняя (BUY)
        
        if(MathAbs(current_price - upper_boundary) <= m_touch_tolerance) {
            touch_direction = 1; // Сигнал на продажу
        } else if(MathAbs(current_price - lower_boundary) <= m_touch_tolerance) {
            touch_direction = -1; // Сигнал на покупку
        }
        
        if(touch_direction == 0) {
            candidate.signal_reason = "Price not at channel boundary";
            return candidate;
        }
        
        // 5. Рассчитываем торговые уровни
        double atr_value = GetATRValue();
        double entry_price = current_price;
        double stop_loss, take_profit;
        
        if(touch_direction == 1) {
            // SELL LIMIT на верхней границе
            stop_loss = upper_boundary + (atr_value * 1.5);
            take_profit = middle_line;
        } else {
            // BUY LIMIT на нижней границе  
            stop_loss = lower_boundary - (atr_value * 1.5);
            take_profit = middle_line;
        }
        
        // 6. Проверяем R:R соотношение
        double risk = MathAbs(entry_price - stop_loss);
        double reward = MathAbs(take_profit - entry_price);
        double risk_reward = (risk > 0) ? reward / risk : 0;
        
        if(risk_reward < m_risk_reward_min) {
            candidate.signal_reason = StringFormat("R:R ratio too low: %.2f", risk_reward);
            return candidate;
        }
        
        // 7. Формируем валидный сигнал
        candidate.isValid = true;
        candidate.direction = -touch_direction; // Инверсия: касание верхней = продажа
        candidate.entry_price = entry_price;
        candidate.stop_loss = stop_loss;
        candidate.take_profit = take_profit;
        candidate.risk_reward_ratio = risk_reward;
        candidate.confidence_score = 0.7; // Базовая надежность стратегии
        candidate.signal_reason = StringFormat("Channel boundary: %s at %.5f, Target: %.5f, R:R: %.2f", 
                                              (touch_direction == 1) ? "SELL from upper" : "BUY from lower",
                                              entry_price, take_profit, risk_reward);
        
        return candidate;
    }
    
private:
    /**
     * @brief Получение границ канала Дончиана
     */
    bool GetChannelBoundaries(double &upper_boundary, double &lower_boundary, double &middle_line) {
        MqlRates rates[50];
        int rates_copied = CopyRates(m_symbol, m_timeframe, 0, m_channel_period + 5, rates);
        if(rates_copied < m_channel_period) return false;
        
        upper_boundary = rates[1].high;
        lower_boundary = rates[1].low;
        
        for(int i = 1; i <= m_channel_period; i++) {
            if(rates[i].high > upper_boundary) upper_boundary = rates[i].high;
            if(rates[i].low < lower_boundary) lower_boundary = rates[i].low;
        }
        
        middle_line = (upper_boundary + lower_boundary) / 2;
        return true;
    }
    
    /**
     * @brief Получение текущего значения ATR
     */
    double GetATRValue() {
        if(m_h_atr == INVALID_HANDLE) return 0.001;
        
        double atr_values[1];
        if(CopyBuffer(m_h_atr, 0, 0, 1, atr_values) <= 0) return 0.001;
        return atr_values[0];
    }
};

/**
 * @brief Стратегия "Ложный Пробой" (False Breakout)
 */
class CStrategy_FalseBreakout {
private:
    string m_strategy_id;
    string m_symbol;
    ENUM_TIMEFRAMES m_timeframe;
    int m_range_period;
    double m_breakout_threshold;
    int m_false_signal_bars;
    
public:
    CStrategy_FalseBreakout() : m_strategy_id("FALSE_BREAKOUT"),
                                m_symbol(""),
                                m_timeframe(PERIOD_H1),
                                m_range_period(20),
                                m_breakout_threshold(0.0005),
                                m_false_signal_bars(5)
    {}
    
    void Initialize(CPatterns* patterns_ptr, CFigures* figures_ptr, 
                   const string symbol = "", ENUM_TIMEFRAMES timeframe = PERIOD_H1) {
        m_symbol = (symbol == "") ? Symbol() : symbol;
        m_timeframe = timeframe;
    }
    
    SignalCandidate GetSignal(E_MarketRegime current_regime = REGIME_UNDEFINED) {
        SignalCandidate candidate;
        candidate.strategyID = m_strategy_id;
        candidate.symbol = m_symbol;
        candidate.signal_time = TimeCurrent();
        
        // Определяем ключевой диапазон
        double range_high, range_low;
        if(!GetKeyRange(range_high, range_low)) {
            candidate.signal_reason = "Unable to identify key range";
            return candidate;
        }
        
        // Проверяем ложный пробой
        double current_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        MqlRates rates[10];
        if(CopyRates(m_symbol, m_timeframe, 0, m_false_signal_bars + 2, rates) < m_false_signal_bars) {
            candidate.signal_reason = "Insufficient data";
            return candidate;
        }
        
        // Ищем ложный пробой
        bool had_upside_breakout = false;
        bool had_downside_breakout = false;
        
        for(int i = 1; i <= m_false_signal_bars; i++) {
            if(rates[i].high > range_high + m_breakout_threshold) had_upside_breakout = true;
            if(rates[i].low < range_low - m_breakout_threshold) had_downside_breakout = true;
        }
        
        int direction = 0;
        if(had_upside_breakout && current_price < range_high) {
            direction = -1; // Продажа после ложного пробоя вверх
        } else if(had_downside_breakout && current_price > range_low) {
            direction = 1; // Покупка после ложного пробоя вниз
        }
        
        if(direction == 0) {
            candidate.signal_reason = "No false breakout detected";
            return candidate;
        }
        
        // Формируем сигнал
        candidate.isValid = true;
        candidate.direction = direction;
        candidate.entry_price = current_price;
        candidate.stop_loss = (direction == 1) ? range_low - m_breakout_threshold : range_high + m_breakout_threshold;
        candidate.take_profit = (direction == 1) ? range_high : range_low;
        candidate.confidence_score = 0.75;
        candidate.signal_reason = StringFormat("False breakout: %s", 
                                              (direction == 1) ? "BUY after false down" : "SELL after false up");
        
        return candidate;
    }
    
private:
    bool GetKeyRange(double &range_high, double &range_low) {
        MqlRates rates[50];
        if(CopyRates(m_symbol, m_timeframe, 0, m_range_period + 5, rates) < m_range_period) return false;
        
        range_high = rates[1].high;
        range_low = rates[1].low;
        
        for(int i = 1; i <= m_range_period; i++) {
            if(rates[i].high > range_high) range_high = rates[i].high;
            if(rates[i].low < range_low) range_low = rates[i].low;
        }
        
        return true;
    }
};

//+------------------------------------------------------------------+
//| ТРЕНДОВЫЕ СТРАТЕГИИ (СПРИНТ 3)                                   |
//+------------------------------------------------------------------+

/**
 * @brief Стратегия "Двойная MA с Якорем" для трендовых рынков
 * 
 * Использует пересечение двух скользящих средних как основной сигнал
 * с дополнительным "якорем" для подтверждения тренда.
 */
class CStrategy_DualMA_Anchor {
private:
    // --- Указатели на модули ---
    CPatterns*              m_patterns;
    CFigures*               m_figures;
    
    // --- Параметры стратегии ---
    string                  m_strategy_id;
    string                  m_symbol;
    ENUM_TIMEFRAMES         m_timeframe;
    
    // --- Параметры MA ---
    int                     m_fast_ma_period;      // Период быстрой MA
    int                     m_slow_ma_period;      // Период медленной MA
    ENUM_MA_METHOD          m_ma_method;           // Метод расчета MA
    ENUM_APPLIED_PRICE      m_applied_price;       // Цена для расчета
    
    // --- Параметры якоря ---
    double                  m_anchor_threshold;    // Порог для якоря (в пипсах)
    int                     m_anchor_lookback;     // Период поиска якоря
    
    // --- Параметры фильтрации ---
    double                  m_min_trend_strength;  // Минимальная сила тренда
    double                  m_min_ma_separation;   // Минимальное разделение MA
    
    // --- Хэндлы индикаторов ---
    int                     m_h_fast_ma;
    int                     m_h_slow_ma;
    
public:
    /**
     * @brief Конструктор
     */
    CStrategy_DualMA_Anchor() : m_patterns(NULL),
                                m_figures(NULL),
                                m_strategy_id("DualMA_Anchor"),
                                m_symbol(""),
                                m_timeframe(PERIOD_H1),
                                m_fast_ma_period(21),
                                m_slow_ma_period(55),
                                m_ma_method(MODE_EMA),
                                m_applied_price(PRICE_CLOSE),
                                m_anchor_threshold(20.0),
                                m_anchor_lookback(20),
                                m_min_trend_strength(0.6),
                                m_min_ma_separation(5.0),
                                m_h_fast_ma(INVALID_HANDLE),
                                m_h_slow_ma(INVALID_HANDLE)
    {}
    
    /**
     * @brief Деструктор
     */
    ~CStrategy_DualMA_Anchor() {
        if(m_h_fast_ma != INVALID_HANDLE) IndicatorRelease(m_h_fast_ma);
        if(m_h_slow_ma != INVALID_HANDLE) IndicatorRelease(m_h_slow_ma);
    }
    
    /**
     * @brief Инициализация стратегии
     * @param patterns_ptr Указатель на модуль паттернов
     * @param figures_ptr Указатель на модуль фигур
     * @param symbol Торговый символ
     * @param timeframe Таймфрейм
     */
    void Initialize(CPatterns* patterns_ptr, CFigures* figures_ptr, 
                   const string symbol, ENUM_TIMEFRAMES timeframe) {
        m_patterns = patterns_ptr;
        m_figures = figures_ptr;
        m_symbol = (symbol == "") ? Symbol() : symbol;
        m_timeframe = timeframe;
        
        // Создаем хэндлы индикаторов
        m_h_fast_ma = iMA(m_symbol, m_timeframe, m_fast_ma_period, 0, m_ma_method, m_applied_price);
        m_h_slow_ma = iMA(m_symbol, m_timeframe, m_slow_ma_period, 0, m_ma_method, m_applied_price);
        
        if(m_h_fast_ma == INVALID_HANDLE || m_h_slow_ma == INVALID_HANDLE) {
            Print("DualMA Anchor Strategy: Failed to create MA handles");
        }
        
        Print("DualMA Anchor Strategy: Initialized for ", m_symbol, " on ", EnumToString(m_timeframe));
    }
    
    /**
     * @brief Основной метод генерации сигналов
     * @param current_regime Текущий режим рынка
     * @return Структура сигнала-кандидата
     */
    SignalCandidate GetSignal(E_MarketRegime current_regime = REGIME_UNDEFINED) {
        SignalCandidate candidate;
        candidate.strategyID = m_strategy_id;
        candidate.symbol = m_symbol;
        candidate.timeframe = EnumToString(m_timeframe);
        candidate.signal_time = TimeCurrent();
        
        // Проверяем режим рынка (предпочтительно трендовые режимы)
        if(current_regime != REGIME_TREND_STRONG && 
           current_regime != REGIME_TREND_WEAKENING &&
           current_regime != REGIME_UNDEFINED) {
            candidate.signal_reason = "Market regime not suitable for trend strategy";
            return candidate;
        }
        
        // Получаем данные MA
        double fast_ma[3], slow_ma[3];
        if(CopyBuffer(m_h_fast_ma, 0, 0, 3, fast_ma) < 3 ||
           CopyBuffer(m_h_slow_ma, 0, 0, 3, slow_ma) < 3) {
            candidate.signal_reason = "Failed to get MA data";
            return candidate;
        }
        
        // Анализируем пересечение MA
        int ma_cross_direction = AnalyzeMACross(fast_ma, slow_ma);
        if(ma_cross_direction == 0) {
            candidate.signal_reason = "No MA crossover detected";
            return candidate;
        }
        
        // Проверяем силу тренда
        double trend_strength = CalculateTrendStrength(fast_ma, slow_ma);
        if(trend_strength < m_min_trend_strength) {
            candidate.signal_reason = StringFormat("Trend strength too low: %.2f < %.2f", 
                                                 trend_strength, m_min_trend_strength);
            return candidate;
        }
        
        // Проверяем разделение MA
        double ma_separation = MathAbs(fast_ma[0] - slow_ma[0]) / _Point;
        if(ma_separation < m_min_ma_separation) {
            candidate.signal_reason = StringFormat("MA separation too small: %.1f < %.1f pips", 
                                                 ma_separation, m_min_ma_separation);
            return candidate;
        }
        
        // Ищем якорь (значимый экстремум)
        double anchor_price;
        bool anchor_found = FindAnchor(ma_cross_direction, anchor_price);
        if(!anchor_found) {
            candidate.signal_reason = "No significant anchor found";
            return candidate;
        }
        
        // Рассчитываем торговые уровни
        double entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        double stop_loss, take_profit;
        
        if(ma_cross_direction > 0) {
            // Бычий сигнал
            stop_loss = MathMin(anchor_price, slow_ma[0]) - (m_anchor_threshold * _Point);
            take_profit = entry_price + (MathAbs(entry_price - stop_loss) * 2.0); // R:R = 1:2
        } else {
            // Медвежий сигнал
            stop_loss = MathMax(anchor_price, slow_ma[0]) + (m_anchor_threshold * _Point);
            take_profit = entry_price - (MathAbs(stop_loss - entry_price) * 2.0); // R:R = 1:2
        }
        
        // Проверяем R:R соотношение
        double risk_reward = CalculateRiskReward(entry_price, stop_loss, take_profit, ma_cross_direction);
        if(risk_reward < 1.5) {
            candidate.signal_reason = StringFormat("Risk/Reward ratio too low: %.2f", risk_reward);
            return candidate;
        }
        
        // Формируем валидный сигнал
        candidate.isValid = true;
        candidate.direction = ma_cross_direction;
        candidate.entry_price = entry_price;
        candidate.stop_loss = stop_loss;
        candidate.take_profit = take_profit;
        candidate.confidence_score = CalculateConfidenceScore(trend_strength, ma_separation, anchor_found);
        candidate.risk_reward_ratio = risk_reward;
        candidate.signal_reason = StringFormat("DualMA Anchor: %s trend, strength %.2f, R:R %.2f", 
                                             (ma_cross_direction > 0) ? "Bullish" : "Bearish",
                                             trend_strength, risk_reward);
        
        return candidate;
    }
    
private:
    /**
     * @brief Анализ пересечения MA
     * @param fast_ma Массив значений быстрой MA
     * @param slow_ma Массив значений медленной MA
     * @return 1 для бычьего пересечения, -1 для медвежьего, 0 если нет пересечения
     */
    int AnalyzeMACross(const double &fast_ma[], const double &slow_ma[]) {
        // Проверяем бычье пересечение (быстрая MA пересекает медленную снизу вверх)
        if(fast_ma[1] <= slow_ma[1] && fast_ma[0] > slow_ma[0]) {
            return 1;
        }
        
        // Проверяем медвежье пересечение (быстрая MA пересекает медленную сверху вниз)
        if(fast_ma[1] >= slow_ma[1] && fast_ma[0] < slow_ma[0]) {
            return -1;
        }
        
        return 0;
    }
    
    /**
     * @brief Расчет силы тренда
     * @param fast_ma Массив значений быстрой MA
     * @param slow_ma Массив значений медленной MA
     * @return Сила тренда от 0.0 до 1.0
     */
    double CalculateTrendStrength(const double &fast_ma[], const double &slow_ma[]) {
        // Анализируем наклон MA
        double fast_slope = (fast_ma[0] - fast_ma[2]) / 2.0;
        double slow_slope = (slow_ma[0] - slow_ma[2]) / 2.0;
        
        // Проверяем согласованность направления
        bool same_direction = (fast_slope > 0 && slow_slope > 0) || (fast_slope < 0 && slow_slope < 0);
        
        if(!same_direction) return 0.0;
        
        // Рассчитываем силу на основе угла наклона
        double avg_slope = (MathAbs(fast_slope) + MathAbs(slow_slope)) / 2.0;
        double strength = MathMin(1.0, avg_slope / (_Point * 10.0)); // Нормализуем
        
        return strength;
    }
    
    /**
     * @brief Поиск якоря (значимого экстремума)
     * @param direction Направление тренда
     * @param anchor_price Цена якоря (выходной параметр)
     * @return true если якорь найден
     */
    bool FindAnchor(int direction, double &anchor_price) {
        MqlRates rates[50];
        if(CopyRates(m_symbol, m_timeframe, 0, m_anchor_lookback, rates) < m_anchor_lookback) {
            return false;
        }
        
        double threshold = m_anchor_threshold * _Point;
        
        if(direction > 0) {
            // Ищем значимый минимум для бычьего тренда
            for(int i = 1; i < m_anchor_lookback - 1; i++) {
                if(rates[i].low < rates[i-1].low && rates[i].low < rates[i+1].low) {
                    // Проверяем, насколько значим этот минимум
                    bool is_significant = true;
                    for(int j = MathMax(0, i-5); j <= MathMin(m_anchor_lookback-1, i+5); j++) {
                        if(j != i && rates[j].low <= rates[i].low + threshold) {
                            is_significant = false;
                            break;
                        }
                    }
                    
                    if(is_significant) {
                        anchor_price = rates[i].low;
                        return true;
                    }
                }
            }
        } else {
            // Ищем значимый максимум для медвежьего тренда
            for(int i = 1; i < m_anchor_lookback - 1; i++) {
                if(rates[i].high > rates[i-1].high && rates[i].high > rates[i+1].high) {
                    // Проверяем, насколько значим этот максимум
                    bool is_significant = true;
                    for(int j = MathMax(0, i-5); j <= MathMin(m_anchor_lookback-1, i+5); j++) {
                        if(j != i && rates[j].high >= rates[i].high - threshold) {
                            is_significant = false;
                            break;
                        }
                    }
                    
                    if(is_significant) {
                        anchor_price = rates[i].high;
                        return true;
                    }
                }
            }
        }
        
        return false;
    }
    
    /**
     * @brief Расчет confidence score
     * @param trend_strength Сила тренда
     * @param ma_separation Разделение MA
     * @param anchor_found Найден ли якорь
     * @return Confidence score от 0.0 до 1.0
     */
    double CalculateConfidenceScore(double trend_strength, double ma_separation, bool anchor_found) {
        double score = 0.0;
        
        // Базовый score от силы тренда
        score += trend_strength * 0.4;
        
        // Бонус за разделение MA
        if(ma_separation > m_min_ma_separation * 2) {
            score += 0.2;
        } else if(ma_separation > m_min_ma_separation) {
            score += 0.1;
        }
        
        // Бонус за найденный якорь
        if(anchor_found) {
            score += 0.3;
        }
        
        // Бонус за согласованность направления MA
        score += 0.1;
        
        return MathMin(1.0, score);
    }
    
    /**
     * @brief Расчет Risk/Reward соотношения
     */
    double CalculateRiskReward(double entry, double sl, double tp, int direction) {
        double risk = MathAbs(entry - sl);
        double reward = MathAbs(tp - entry);
        
        if(risk == 0) return 0;
        return reward / risk;
    }
};

/**
 * @brief Стратегия "Пробой Дончиана" для трендовых рынков
 * 
 * Использует пробой канала Дончиана как основной сигнал
 * с дополнительными фильтрами для подтверждения тренда.
 */
class CStrategy_DonchianBreakout {
private:
    // --- Указатели на модули ---
    CPatterns*              m_patterns;
    CFigures*               m_figures;
    
    // --- Параметры стратегии ---
    string                  m_strategy_id;
    string                  m_symbol;
    ENUM_TIMEFRAMES         m_timeframe;
    
    // --- Параметры канала Дончиана ---
    int                     m_donchian_period;     // Период канала Дончиана
    double                  m_breakout_threshold;  // Порог пробоя (в пипсах)
    int                     m_confirmation_bars;   // Количество баров подтверждения
    
    // --- Параметры фильтрации ---
    double                  m_min_channel_width;   // Минимальная ширина канала
    double                  m_volume_multiplier;   // Множитель объема для подтверждения
    int                     m_trend_confirmation;  // Период подтверждения тренда
    
    // --- Хэндлы индикаторов ---
    int                     m_h_donchian;
    int                     m_h_volume;
    
public:
    /**
     * @brief Конструктор
     */
    CStrategy_DonchianBreakout() : m_patterns(NULL),
                                   m_figures(NULL),
                                   m_strategy_id("DonchianBreakout"),
                                   m_symbol(""),
                                   m_timeframe(PERIOD_H1),
                                   m_donchian_period(20),
                                   m_breakout_threshold(5.0),
                                   m_confirmation_bars(2),
                                   m_min_channel_width(20.0),
                                   m_volume_multiplier(1.5),
                                   m_trend_confirmation(10),
                                   m_h_donchian(INVALID_HANDLE),
                                   m_h_volume(INVALID_HANDLE)
    {}
    
    /**
     * @brief Деструктор
     */
    ~CStrategy_DonchianBreakout() {
        if(m_h_donchian != INVALID_HANDLE) IndicatorRelease(m_h_donchian);
        if(m_h_volume != INVALID_HANDLE) IndicatorRelease(m_h_volume);
    }
    
    /**
     * @brief Инициализация стратегии
     * @param patterns_ptr Указатель на модуль паттернов
     * @param figures_ptr Указатель на модуль фигур
     * @param symbol Торговый символ
     * @param timeframe Таймфрейм
     */
    void Initialize(CPatterns* patterns_ptr, CFigures* figures_ptr, 
                   const string symbol, ENUM_TIMEFRAMES timeframe) {
        m_patterns = patterns_ptr;
        m_figures = figures_ptr;
        m_symbol = (symbol == "") ? Symbol() : symbol;
        m_timeframe = timeframe;
        
        // Создаем хэндлы индикаторов
        m_h_donchian = iCustom(m_symbol, m_timeframe, "Donchian_Channel", m_donchian_period);
        m_h_volume = iVolumes(m_symbol, m_timeframe, VOLUME_TICK);
        
        if(m_h_donchian == INVALID_HANDLE || m_h_volume == INVALID_HANDLE) {
            Print("Donchian Breakout Strategy: Failed to create indicator handles");
        }
        
        Print("Donchian Breakout Strategy: Initialized for ", m_symbol, " on ", EnumToString(m_timeframe));
    }
    
    /**
     * @brief Основной метод генерации сигналов
     * @param current_regime Текущий режим рынка
     * @return Структура сигнала-кандидата
     */
    SignalCandidate GetSignal(E_MarketRegime current_regime = REGIME_UNDEFINED) {
        SignalCandidate candidate;
        candidate.strategyID = m_strategy_id;
        candidate.symbol = m_symbol;
        candidate.timeframe = EnumToString(m_timeframe);
        candidate.signal_time = TimeCurrent();
        
        // Проверяем режим рынка (предпочтительно трендовые режимы)
        if(current_regime != REGIME_TREND_STRONG && 
           current_regime != REGIME_TREND_WEAKENING &&
           current_regime != REGIME_UNDEFINED) {
            candidate.signal_reason = "Market regime not suitable for breakout strategy";
            return candidate;
        }
        
        // Получаем данные канала Дончиана
        double donchian_upper[5], donchian_lower[5], donchian_middle[5];
        if(CopyBuffer(m_h_donchian, 0, 0, 5, donchian_upper) < 5 ||   // Верхняя линия
           CopyBuffer(m_h_donchian, 1, 0, 5, donchian_lower) < 5 ||   // Нижняя линия
           CopyBuffer(m_h_donchian, 2, 0, 5, donchian_middle) < 5) {  // Средняя линия
            candidate.signal_reason = "Failed to get Donchian Channel data";
            return candidate;
        }
        
        // Получаем текущие цены
        MqlRates rates[5];
        if(CopyRates(m_symbol, m_timeframe, 0, 5, rates) < 5) {
            candidate.signal_reason = "Failed to get price data";
            return candidate;
        }
        
        // Проверяем ширину канала
        double channel_width = (donchian_upper[0] - donchian_lower[0]) / _Point;
        if(channel_width < m_min_channel_width) {
            candidate.signal_reason = StringFormat("Channel width too small: %.1f < %.1f pips", 
                                                 channel_width, m_min_channel_width);
            return candidate;
        }
        
        // Анализируем пробой
        int breakout_direction = AnalyzeBreakout(rates, donchian_upper, donchian_lower);
        if(breakout_direction == 0) {
            candidate.signal_reason = "No significant breakout detected";
            return candidate;
        }
        
        // Проверяем подтверждение пробоя
        if(!ConfirmBreakout(rates, donchian_upper, donchian_lower, breakout_direction)) {
            candidate.signal_reason = "Breakout not confirmed";
            return candidate;
        }
        
        // Проверяем объем
        if(!CheckVolumeConfirmation()) {
            candidate.signal_reason = "Volume confirmation failed";
            return candidate;
        }
        
        // Рассчитываем торговые уровни
        double entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        double stop_loss, take_profit;
        
        if(breakout_direction > 0) {
            // Пробой вверх
            stop_loss = donchian_lower[0] - (m_breakout_threshold * _Point);
            take_profit = entry_price + (channel_width * _Point * 1.5); // 1.5x ширина канала
        } else {
            // Пробой вниз
            stop_loss = donchian_upper[0] + (m_breakout_threshold * _Point);
            take_profit = entry_price - (channel_width * _Point * 1.5); // 1.5x ширина канала
        }
        
        // Проверяем R:R соотношение
        double risk_reward = CalculateRiskReward(entry_price, stop_loss, take_profit, breakout_direction);
        if(risk_reward < 1.0) {
            candidate.signal_reason = StringFormat("Risk/Reward ratio too low: %.2f", risk_reward);
            return candidate;
        }
        
        // Формируем валидный сигнал
        candidate.isValid = true;
        candidate.direction = breakout_direction;
        candidate.entry_price = entry_price;
        candidate.stop_loss = stop_loss;
        candidate.take_profit = take_profit;
        candidate.confidence_score = CalculateConfidenceScore(channel_width, breakout_direction);
        candidate.risk_reward_ratio = risk_reward;
        candidate.signal_reason = StringFormat("Donchian Breakout: %s, channel %.1f pips, R:R %.2f", 
                                             (breakout_direction > 0) ? "Bullish" : "Bearish",
                                             channel_width, risk_reward);
        
        return candidate;
    }
    
private:
    /**
     * @brief Анализ пробоя канала Дончиана
     * @param rates Массив ценовых данных
     * @param upper Верхняя линия канала
     * @param lower Нижняя линия канала
     * @return 1 для пробоя вверх, -1 для пробоя вниз, 0 если нет пробоя
     */
    int AnalyzeBreakout(const MqlRates &rates[], const double &upper[], const double &lower[]) {
        double threshold = m_breakout_threshold * _Point;
        
        // Проверяем пробой вверх
        if(rates[0].close > upper[0] + threshold) {
            // Проверяем, что цена была внутри канала на предыдущих барах
            bool was_inside = true;
            for(int i = 1; i < m_confirmation_bars; i++) {
                if(rates[i].close > upper[i] || rates[i].close < lower[i]) {
                    was_inside = false;
                    break;
                }
            }
            
            if(was_inside) return 1;
        }
        
        // Проверяем пробой вниз
        if(rates[0].close < lower[0] - threshold) {
            // Проверяем, что цена была внутри канала на предыдущих барах
            bool was_inside = true;
            for(int i = 1; i < m_confirmation_bars; i++) {
                if(rates[i].close > upper[i] || rates[i].close < lower[i]) {
                    was_inside = false;
                    break;
                }
            }
            
            if(was_inside) return -1;
        }
        
        return 0;
    }
    
    /**
     * @brief Подтверждение пробоя
     * @param rates Массив ценовых данных
     * @param upper Верхняя линия канала
     * @param lower Нижняя линия канала
     * @param direction Направление пробоя
     * @return true если пробой подтвержден
     */
    bool ConfirmBreakout(const MqlRates &rates[], const double &upper[], const double &lower[], int direction) {
        int confirmation_count = 0;
        
        for(int i = 0; i < m_confirmation_bars; i++) {
            if(direction > 0) {
                // Для пробоя вверх проверяем, что цена остается выше верхней линии
                if(rates[i].close > upper[i]) {
                    confirmation_count++;
                }
            } else {
                // Для пробоя вниз проверяем, что цена остается ниже нижней линии
                if(rates[i].close < lower[i]) {
                    confirmation_count++;
                }
            }
        }
        
        return confirmation_count >= m_confirmation_bars;
    }
    
    /**
     * @brief Проверка подтверждения объемом
     * @return true если объем подтверждает пробой
     */
    bool CheckVolumeConfirmation() {
        double volume[10];
        if(CopyBuffer(m_h_volume, 0, 0, 10, volume) < 10) {
            return true; // Если не можем получить данные объема, пропускаем проверку
        }
        
        // Рассчитываем средний объем за последние 10 баров
        double avg_volume = 0;
        for(int i = 1; i < 10; i++) {
            avg_volume += volume[i];
        }
        avg_volume /= 9;
        
        // Проверяем, превышает ли текущий объем средний
        return volume[0] > (avg_volume * m_volume_multiplier);
    }
    
    /**
     * @brief Расчет confidence score
     * @param channel_width Ширина канала
     * @param direction Направление пробоя
     * @return Confidence score от 0.0 до 1.0
     */
    double CalculateConfidenceScore(double channel_width, int direction) {
        double score = 0.0;
        
        // Базовый score от ширины канала
        if(channel_width > m_min_channel_width * 2) {
            score += 0.4;
        } else if(channel_width > m_min_channel_width) {
            score += 0.3;
        } else {
            score += 0.2;
        }
        
        // Бонус за подтверждение пробоя
        score += 0.3;
        
        // Бонус за подтверждение объемом
        score += 0.2;
        
        // Бонус за силу пробоя
        score += 0.1;
        
        return MathMin(1.0, score);
    }
    
    /**
     * @brief Расчет Risk/Reward соотношения
     */
    double CalculateRiskReward(double entry, double sl, double tp, int direction) {
        double risk = MathAbs(entry - sl);
        double reward = MathAbs(tp - entry);
        
        if(risk == 0) return 0;
        return reward / risk;
    }
};

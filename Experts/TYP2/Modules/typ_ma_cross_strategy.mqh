// --- typ_ma_cross_strategy.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Sprint 3 Final :: MA Cross Strategy
#property copyright "TYP2"

#include "typ_patterns.mqh"
#include "typ_figures.mqh"

/**
 * @brief Стратегия "MA Cross" для трендовых рынков
 * 
 * Классическая стратегия пересечения скользящих средних
 * с дополнительными фильтрами для повышения точности.
 */
class CStrategy_MA_Cross {
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
    
    // --- Параметры фильтрации ---
    double                  m_min_trend_strength;  // Минимальная сила тренда
    double                  m_min_ma_separation;   // Минимальное разделение MA
    int                     m_confirmation_bars;   // Количество баров подтверждения
    double                  m_volume_threshold;    // Порог объема для подтверждения
    
    // --- Хэндлы индикаторов ---
    int                     m_h_fast_ma;
    int                     m_h_slow_ma;
    int                     m_h_volume;
    
public:
    /**
     * @brief Конструктор
     */
    CStrategy_MA_Cross() : m_patterns(NULL),
                           m_figures(NULL),
                           m_strategy_id("MA_Cross"),
                           m_symbol(""),
                           m_timeframe(PERIOD_H1),
                           m_fast_ma_period(10),
                           m_slow_ma_period(21),
                           m_ma_method(MODE_EMA),
                           m_applied_price(PRICE_CLOSE),
                           m_min_trend_strength(0.5),
                           m_min_ma_separation(3.0),
                           m_confirmation_bars(2),
                           m_volume_threshold(1.2),
                           m_h_fast_ma(INVALID_HANDLE),
                           m_h_slow_ma(INVALID_HANDLE),
                           m_h_volume(INVALID_HANDLE)
    {}
    
    /**
     * @brief Деструктор
     */
    ~CStrategy_MA_Cross() {
        if(m_h_fast_ma != INVALID_HANDLE) IndicatorRelease(m_h_fast_ma);
        if(m_h_slow_ma != INVALID_HANDLE) IndicatorRelease(m_h_slow_ma);
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
        m_h_fast_ma = iMA(m_symbol, m_timeframe, m_fast_ma_period, 0, m_ma_method, m_applied_price);
        m_h_slow_ma = iMA(m_symbol, m_timeframe, m_slow_ma_period, 0, m_ma_method, m_applied_price);
        m_h_volume = iVolumes(m_symbol, m_timeframe, VOLUME_TICK);
        
        if(m_h_fast_ma == INVALID_HANDLE || m_h_slow_ma == INVALID_HANDLE || m_h_volume == INVALID_HANDLE) {
            Print("MA Cross Strategy: Failed to create indicator handles");
        }
        
        Print("MA Cross Strategy: Initialized for ", m_symbol, " on ", EnumToString(m_timeframe));
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
            candidate.signal_reason = "Market regime not suitable for MA Cross strategy";
            return candidate;
        }
        
        // Получаем данные MA
        double fast_ma[5], slow_ma[5];
        if(CopyBuffer(m_h_fast_ma, 0, 0, 5, fast_ma) < 5 ||
           CopyBuffer(m_h_slow_ma, 0, 0, 5, slow_ma) < 5) {
            candidate.signal_reason = "Failed to get MA data";
            return candidate;
        }
        
        // Анализируем пересечение MA
        int cross_direction = AnalyzeMACross(fast_ma, slow_ma);
        if(cross_direction == 0) {
            candidate.signal_reason = "No MA crossover detected";
            return candidate;
        }
        
        // Проверяем подтверждение пересечения
        if(!ConfirmCross(fast_ma, slow_ma, cross_direction)) {
            candidate.signal_reason = "MA cross not confirmed";
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
        
        // Проверяем объем
        if(!CheckVolumeConfirmation()) {
            candidate.signal_reason = "Volume confirmation failed";
            return candidate;
        }
        
        // Рассчитываем торговые уровни
        double entry_price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
        double stop_loss, take_profit;
        
        if(cross_direction > 0) {
            // Бычий сигнал
            stop_loss = slow_ma[0] - (ma_separation * _Point * 0.5);
            take_profit = entry_price + (MathAbs(entry_price - stop_loss) * 2.0); // R:R = 1:2
        } else {
            // Медвежий сигнал
            stop_loss = slow_ma[0] + (ma_separation * _Point * 0.5);
            take_profit = entry_price - (MathAbs(stop_loss - entry_price) * 2.0); // R:R = 1:2
        }
        
        // Проверяем R:R соотношение
        double risk_reward = CalculateRiskReward(entry_price, stop_loss, take_profit, cross_direction);
        if(risk_reward < 1.5) {
            candidate.signal_reason = StringFormat("Risk/Reward ratio too low: %.2f", risk_reward);
            return candidate;
        }
        
        // Формируем валидный сигнал
        candidate.isValid = true;
        candidate.direction = cross_direction;
        candidate.entry_price = entry_price;
        candidate.stop_loss = stop_loss;
        candidate.take_profit = take_profit;
        candidate.confidence_score = CalculateConfidenceScore(trend_strength, ma_separation);
        candidate.risk_reward_ratio = risk_reward;
        candidate.signal_reason = StringFormat("MA Cross: %s trend, strength %.2f, R:R %.2f", 
                                             (cross_direction > 0) ? "Bullish" : "Bearish",
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
     * @brief Подтверждение пересечения
     * @param fast_ma Массив значений быстрой MA
     * @param slow_ma Массив значений медленной MA
     * @param direction Направление пересечения
     * @return true если пересечение подтверждено
     */
    bool ConfirmCross(const double &fast_ma[], const double &slow_ma[], int direction) {
        int confirmation_count = 0;
        
        for(int i = 0; i < m_confirmation_bars; i++) {
            if(direction > 0) {
                // Для бычьего пересечения проверяем, что быстрая MA остается выше медленной
                if(fast_ma[i] > slow_ma[i]) {
                    confirmation_count++;
                }
            } else {
                // Для медвежьего пересечения проверяем, что быстрая MA остается ниже медленной
                if(fast_ma[i] < slow_ma[i]) {
                    confirmation_count++;
                }
            }
        }
        
        return confirmation_count >= m_confirmation_bars;
    }
    
    /**
     * @brief Расчет силы тренда
     * @param fast_ma Массив значений быстрой MA
     * @param slow_ma Массив значений медленной MA
     * @return Сила тренда от 0.0 до 1.0
     */
    double CalculateTrendStrength(const double &fast_ma[], const double &slow_ma[]) {
        // Анализируем наклон MA
        double fast_slope = (fast_ma[0] - fast_ma[4]) / 4.0;
        double slow_slope = (slow_ma[0] - slow_ma[4]) / 4.0;
        
        // Проверяем согласованность направления
        bool same_direction = (fast_slope > 0 && slow_slope > 0) || (fast_slope < 0 && slow_slope < 0);
        
        if(!same_direction) return 0.0;
        
        // Рассчитываем силу на основе угла наклона
        double avg_slope = (MathAbs(fast_slope) + MathAbs(slow_slope)) / 2.0;
        double strength = MathMin(1.0, avg_slope / (_Point * 5.0)); // Нормализуем
        
        return strength;
    }
    
    /**
     * @brief Проверка подтверждения объемом
     * @return true если объем подтверждает сигнал
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
        return volume[0] > (avg_volume * m_volume_threshold);
    }
    
    /**
     * @brief Расчет confidence score
     * @param trend_strength Сила тренда
     * @param ma_separation Разделение MA
     * @return Confidence score от 0.0 до 1.0
     */
    double CalculateConfidenceScore(double trend_strength, double ma_separation) {
        double score = 0.0;
        
        // Базовый score от силы тренда
        score += trend_strength * 0.4;
        
        // Бонус за разделение MA
        if(ma_separation > m_min_ma_separation * 2) {
            score += 0.3;
        } else if(ma_separation > m_min_ma_separation) {
            score += 0.2;
        } else {
            score += 0.1;
        }
        
        // Бонус за подтверждение пересечения
        score += 0.2;
        
        // Бонус за подтверждение объемом
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

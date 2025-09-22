// --- typ_resolver.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Sprint 2 :: Trading Decision Resolver (The Brain)
#property copyright "TYP2"

#include "typ_strategies.mqh"
#include "typ_ai_layer.mqh"

/**
 * @brief Структура торгового приказа от Resolver
 */
struct TradeOrderInstruction {
    bool    isValid;              // Валидность приказа
    string  orderType;            // Тип ордера (MARKET, LIMIT, STOP)
    string  symbol;               // Торговый символ
    int     direction;            // Направление (1 = BUY, -1 = SELL)
    double  entry_price;          // Цена входа
    double  stop_loss;            // Стоп-лосс
    double  take_profit;          // Тейк-профит
    double  lot_size;             // Размер лота
    double  final_confidence;     // Итоговая уверенность
    string  volume_scenario;      // Сценарий управления объемом
    string  decision_reason;      // Причина принятия решения
    string  winning_strategy;     // Выигравшая стратегия
    double  confluence_bonus;     // Бонус за confluence
    int     hierarchy_level;      // Уровень в иерархии (1 = макро-фигуры, 2 = стратегии)
    
    TradeOrderInstruction() {
        isValid = false;
        orderType = "MARKET";
        symbol = "";
        direction = 0;
        entry_price = 0.0;
        stop_loss = 0.0;
        take_profit = 0.0;
        lot_size = 0.0;
        final_confidence = 0.0;
        volume_scenario = "STANDARD";
        decision_reason = "";
        winning_strategy = "";
        confluence_bonus = 0.0;
        hierarchy_level = 2;
    }
};

/**
 * @brief Центральный "Мозг" системы - Resolver
 * 
 * Принимает решения о торговле на основе иерархического анализа:
 * 1. Уровень 1: Макро-фигуры (высший приоритет)
 * 2. Уровень 2: Стратегии с confluence анализом
 * 3. Финальная оптимизация размера позиции и типа ордера
 */
class CResolver {
private:
    // --- Указатели на модули ---
    CFigures*               m_figures;
    CPatterns*              m_patterns;
    CAiLayer*               m_ai_layer;
    
    // --- Параметры Resolver ---
    double                  m_min_confidence_threshold;    // Минимальная уверенность для торговли
    double                  m_confluence_multiplier;       // Множитель за confluence сигналов
    double                  m_macro_figure_priority;       // Приоритет макро-фигур
    
    // --- Настройки управления объемом ---
    double                  m_base_lot_size;              // Базовый размер лота
    double                  m_max_lot_size;               // Максимальный размер лота
    double                  m_confidence_scaling;         // Масштабирование по уверенности
    
    // --- Статистика решений ---
    int                     m_total_decisions;
    int                     m_macro_decisions;
    int                     m_confluence_decisions;
    
    // --- Матрица Конфликтов и Конфлюэнса ---
    double                  m_conflict_matrix[10][10];  // Матрица конфликтов между стратегиями
    double                  m_confluence_matrix[10][10]; // Матрица конфлюэнса между стратегиями
    string                  m_strategy_names[10];       // Названия стратегий для индексации
    int                     m_strategy_count;           // Количество зарегистрированных стратегий
    
    // --- Гибкие фильтры ---
    double                  m_confidence_threshold;     // Динамический порог confidence
    double                  m_risk_reward_threshold;    // Динамический порог R:R
    double                  m_volume_filter_threshold;  // Порог фильтра объема
    double                  m_volatility_filter;        // Фильтр волатильности
    bool                    m_enable_news_filter;       // Включение фильтра новостей
    bool                    m_enable_session_filter;    // Включение фильтра сессий
    
    // --- Протокол Контртренда ---
    bool                    m_enable_countertrend;      // Включение контртрендовых сигналов
    double                  m_countertrend_threshold;   // Порог для контртрендовых сигналов
    int                     m_countertrend_max_attempts; // Максимум попыток контртренда
    int                     m_countertrend_attempts;    // Текущее количество попыток
    datetime                m_last_countertrend_time;   // Время последнего контртрендового сигнала
    
public:
    /**
     * @brief Конструктор Resolver
     * 
     * TODO: Подготовка к интеграции с Rules Engine
     * 
     * В будущих версиях здесь будет добавлена инициализация:
     * - CRulesEngine* m_rules_engine; // Указатель на движок правил
     * - Динамические параметры из конфигурационного файла
     * - Загрузка исторических данных для машинного обучения
     * - Инициализация адаптивных алгоритмов
     */
    CResolver() : m_figures(NULL),
                  m_patterns(NULL),
                  m_ai_layer(NULL),
                  m_min_confidence_threshold(0.7),
                  m_confluence_multiplier(1.3),
                  m_macro_figure_priority(2.0),
                  m_base_lot_size(0.1),
                  m_max_lot_size(1.0),
                  m_confidence_scaling(1.5),
                  m_total_decisions(0),
                  m_macro_decisions(0),
                  m_confluence_decisions(0),
                  m_strategy_count(0),
                  m_confidence_threshold(0.7),
                  m_risk_reward_threshold(1.5),
                  m_volume_filter_threshold(1.2),
                  m_volatility_filter(0.5),
                  m_enable_news_filter(true),
                  m_enable_session_filter(true),
                  m_enable_countertrend(false),
                  m_countertrend_threshold(0.8),
                  m_countertrend_max_attempts(3),
                  m_countertrend_attempts(0),
                  m_last_countertrend_time(0)
    {
        // Инициализация матриц конфликтов и конфлюэнса
        InitializeConflictConfluenceMatrices();
        
        // Инициализация гибких фильтров
        InitializeFlexibleFilters();
        
        // Инициализация протокола контртренда
        InitializeCountertrendProtocol();
    }
    
    /**
     * @brief Деструктор Resolver
     */
    ~CResolver() {
        // Указатели не освобождаем - они принадлежат главному модулю
    }
    
    /**
     * @brief Инициализация Resolver
     * @param figures_ptr Указатель на модуль фигур
     * @param patterns_ptr Указатель на модуль паттернов
     * @param ai_layer_ptr Указатель на AI-Слой (опционально)
     */
    void Initialize(CFigures* figures_ptr, CPatterns* patterns_ptr, CAiLayer* ai_layer_ptr = NULL) {
        m_figures = figures_ptr;
        m_patterns = patterns_ptr;
        m_ai_layer = ai_layer_ptr;
        
        Print("Resolver: Initialized with figures=", (figures_ptr != NULL ? "YES" : "NO"), 
              ", patterns=", (patterns_ptr != NULL ? "YES" : "NO"),
              ", AI layer=", (ai_layer_ptr != NULL ? "YES" : "NO"));
    }
    
    /**
     * @brief Главный метод принятия торговых решений
     * @param candidates Массив сигналов-кандидатов от стратегий
     * @param candidates_count Количество кандидатов
     * @return Структура торгового приказа
     * 
     * TODO: Интеграция с Движком Правил (Rules Engine)
     * 
     * В будущих версиях здесь будет интегрирован модуль Rules Engine для:
     * 1. Динамического управления параметрами стратегий
     * 2. Адаптивной настройки пороговых значений
     * 3. Контекстно-зависимых правил принятия решений
     * 4. Машинного обучения на основе исторических данных
     * 5. Автоматической оптимизации весов confluence
     * 
     * Планируемая архитектура:
     * - CRulesEngine::EvaluateRules(candidates, market_context)
     * - CRulesEngine::GetDynamicThresholds(strategy_id, market_conditions)
     * - CRulesEngine::ApplyAdaptiveWeights(candidates, historical_performance)
     * - CRulesEngine::LearnFromOutcome(trade_result, decision_context)
     */
    TradeOrderInstruction Decide(SignalCandidate &candidates[], int candidates_count) {
        TradeOrderInstruction instruction;
        instruction.decision_reason = "Resolver analysis started";
        
        m_total_decisions++;
        
        if(candidates_count <= 0) {
            instruction.decision_reason = "No signal candidates provided";
            return instruction;
        }
        
        // ЭТАП 1: Иерархия - поиск Макро-Фигур (Уровень 1)
        FigureInfo macro_figure;
        if(AnalyzeMacroFigures(macro_figure)) {
            m_macro_decisions++;
            
            // Макро-фигура найдена - она устанавливает глобальный сценарий
            instruction = ProcessMacroFigureScenario(macro_figure, candidates, candidates_count);
            instruction.hierarchy_level = 1;
            instruction.decision_reason = StringFormat("Macro Figure Override: %s (%.1f%% reliability)", 
                                                     macro_figure.figure_name, 
                                                     macro_figure.reliability * 100);
            return instruction;
        }
        
        // ЭТАП 2: Анализ конфликтов между кандидатами
        if(AnalyzeConflicts(candidates, candidates_count)) {
            instruction.decision_reason = "Critical conflicts detected - all signals blocked";
            return instruction;
        }
        
        // ЭТАП 3: Применение гибких фильтров
        int filtered_count = ApplyFlexibleFilters(candidates, candidates_count);
        if(filtered_count == 0) {
            instruction.decision_reason = "All candidates filtered out by flexible filters";
            return instruction;
        }
        
        // ЭТАП 4: Анализ контртрендовых возможностей
        if(AnalyzeCountertrendOpportunities(candidates, candidates_count, REGIME_UNDEFINED)) {
            Print("Resolver: Countertrend opportunity detected and processed");
        }
        
        // ЭТАП 4.5: AI-анализ вероятности сигналов (если AI-Слой доступен)
        if(m_ai_layer != NULL && m_ai_layer->IsInitialized() && m_ai_layer->IsAiAnalysisEnabled()) {
            ApplyAiAnalysis(candidates, candidates_count);
        }
        
        // ЭТАП 5: Скоринг и Confluence анализ (Уровень 2)
        // TODO: Интеграция с Rules Engine для динамической оценки кандидатов
        // candidates = g_RulesEngine.FilterCandidates(candidates, candidates_count, market_context);
        
        if(filtered_count == 1) {
            // Единственный кандидат - анализируем его индивидуально
            for(int i = 0; i < candidates_count; i++) {
                if(candidates[i].isValid) {
                    return ProcessSingleCandidate(candidates[i]);
                }
            }
        }
        
        // ЭТАП 6: Множественные кандидаты - ищем confluence
        // TODO: Адаптивные веса confluence на основе Rules Engine
        // return ProcessMultipleCandidatesWithRules(candidates, candidates_count);
        return ProcessMultipleCandidates(candidates, candidates_count);
    }
    
    /**
     * @brief Получение статистики работы Resolver
     * @param stats_string Строка со статистикой (выходной параметр)
     */
    void GetResolverStats(string &stats_string) {
        double macro_percentage = (m_total_decisions > 0) ? (double)m_macro_decisions / m_total_decisions * 100 : 0;
        double confluence_percentage = (m_total_decisions > 0) ? (double)m_confluence_decisions / m_total_decisions * 100 : 0;
        
        stats_string = StringFormat("Resolver Stats: Total: %d | Macro: %d (%.1f%%) | Confluence: %d (%.1f%%) | Threshold: %.2f",
                                   m_total_decisions, m_macro_decisions, macro_percentage, 
                                   m_confluence_decisions, confluence_percentage, m_min_confidence_threshold);
    }
    
private:
    // === МЕТОДЫ ИЕРАРХИЧЕСКОГО АНАЛИЗА ===
    
    /**
     * @brief Анализ макро-фигур (Уровень 1 иерархии)
     * @param macro_figure Информация о найденной макро-фигуре (выходной параметр)
     * @return true если найдена значимая макро-фигура
     */
    bool AnalyzeMacroFigures(FigureInfo &macro_figure) {
        if(!m_figures) return false;
        
        // Получаем данные для анализа фигур
        MqlRates rates[100];
        if(CopyRates(Symbol(), PERIOD_H4, 0, 100, rates) < 50) return false;
        
        double highs[100], lows[100];
        for(int i = 0; i < 100; i++) {
            highs[i] = rates[i].high;
            lows[i] = rates[i].low;
        }
        
        // Приоритет поиска макро-фигур по важности:
        
        // 1. Голова и Плечи (наивысший приоритет для разворота)
        if(m_figures.DetectHeadAndShoulders(highs, lows, 50, macro_figure)) {
            if(macro_figure.reliability > 0.7) { // Высокий порог для макро-фигур
                return true;
            }
        }
        
        // 2. Двойная Вершина/Дно
        if(m_figures.DetectDoubleTopBottom(highs, lows, 40, macro_figure, true)) { // Поиск двойной вершины
            if(macro_figure.reliability > 0.65) {
                return true;
            }
        }
        
        if(m_figures.DetectDoubleTopBottom(highs, lows, 40, macro_figure, false)) { // Поиск двойного дна
            if(macro_figure.reliability > 0.65) {
                return true;
            }
        }
        
        // 3. Клинья (сильные фигуры разворота)
        if(m_figures.DetectWedge(highs, lows, 40, macro_figure)) {
            if(macro_figure.reliability > 0.6) {
                return true;
            }
        }
        
        return false; // Значимых макро-фигур не найдено
    }
    
    /**
     * @brief Обработка сценария с макро-фигурой
     * @param macro_figure Информация о макро-фигуре
     * @param candidates Массив кандидатов
     * @param candidates_count Количество кандидатов
     * @return Торговый приказ
     */
    TradeOrderInstruction ProcessMacroFigureScenario(const FigureInfo &macro_figure, 
                                                    SignalCandidate &candidates[], 
                                                    int candidates_count) {
        TradeOrderInstruction instruction;
        
        // Макро-фигура устанавливает глобальный сценарий
        instruction.isValid = true;
        instruction.direction = macro_figure.direction;
        instruction.entry_price = macro_figure.breakout_price;
        instruction.stop_loss = macro_figure.stop_price;
        instruction.take_profit = macro_figure.target_price;
        instruction.final_confidence = macro_figure.reliability * m_macro_figure_priority;
        instruction.winning_strategy = "MACRO_FIGURE";
        instruction.orderType = "LIMIT"; // Макро-фигуры часто требуют лимитных ордеров
        
        // Фильтруем кандидатов - оставляем только совпадающие по направлению
        int aligned_candidates = 0;
        for(int i = 0; i < candidates_count; i++) {
            if(candidates[i].isValid && candidates[i].direction == macro_figure.direction) {
                aligned_candidates++;
                // Добавляем confluence бонус
                instruction.confluence_bonus += candidates[i].confidence_score * 0.1;
            }
        }
        
        // Усиливаем сигнал при confluence с другими стратегиями
        if(aligned_candidates > 0) {
            instruction.final_confidence = MathMin(1.0, instruction.final_confidence + instruction.confluence_bonus);
            instruction.decision_reason += StringFormat(" + %d aligned strategies (bonus: %.2f)", 
                                                       aligned_candidates, instruction.confluence_bonus);
        }
        
        // Определяем сценарий управления объемом
        if(instruction.final_confidence > 0.9) {
            instruction.volume_scenario = "AGGRESSIVE";
            instruction.lot_size = m_base_lot_size * 1.5;
        } else if(instruction.final_confidence > 0.8) {
            instruction.volume_scenario = "STANDARD";
            instruction.lot_size = m_base_lot_size;
        } else {
            instruction.volume_scenario = "CONSERVATIVE";
            instruction.lot_size = m_base_lot_size * 0.7;
        }
        
        instruction.lot_size = MathMin(instruction.lot_size, m_max_lot_size);
        
        return instruction;
    }
    
    /**
     * @brief Обработка единственного кандидата
     * @param candidate Сигнал-кандидат
     * @return Торговый приказ
     */
    TradeOrderInstruction ProcessSingleCandidate(const SignalCandidate &candidate) {
        TradeOrderInstruction instruction;
        
        if(!candidate.isValid || candidate.confidence_score < m_min_confidence_threshold) {
            instruction.decision_reason = StringFormat("Single candidate below threshold: %.2f < %.2f", 
                                                     candidate.confidence_score, m_min_confidence_threshold);
            return instruction;
        }
        
        // Преобразуем кандидата в торговый приказ
        instruction.isValid = true;
        instruction.symbol = candidate.symbol;
        instruction.direction = candidate.direction;
        instruction.entry_price = candidate.entry_price;
        instruction.stop_loss = candidate.stop_loss;
        instruction.take_profit = candidate.take_profit;
        instruction.final_confidence = candidate.confidence_score;
        instruction.winning_strategy = candidate.strategyID;
        instruction.orderType = GetOptimalOrderType(candidate);
        
        // Расчет размера лота на основе уверенности
        instruction.lot_size = m_base_lot_size * (1.0 + (candidate.confidence_score - 0.5) * m_confidence_scaling);
        instruction.lot_size = MathMax(0.01, MathMin(instruction.lot_size, m_max_lot_size));
        
        if(candidate.confidence_score > 0.8) {
            instruction.volume_scenario = "HIGH_CONFIDENCE";
        } else {
            instruction.volume_scenario = "STANDARD";
        }
        
        instruction.decision_reason = StringFormat("Single strategy: %s (%.2f confidence)", 
                                                 candidate.strategyID, candidate.confidence_score);
        
        return instruction;
    }
    
    /**
     * @brief Обработка множественных кандидатов (поиск confluence)
     * @param candidates Массив кандидатов
     * @param candidates_count Количество кандидатов
     * @return Торговый приказ
     * 
     * TODO: Расширение для интеграции с Rules Engine
     * 
     * Планируемые улучшения:
     * 1. Адаптивные веса confluence на основе исторической производительности
     * 2. Контекстно-зависимые правила для разных рыночных условий
     * 3. Машинное обучение для оптимизации параметров confluence
     * 4. Динамическая корректировка пороговых значений
     * 5. Интеграция с внешними источниками данных (новости, экономические индикаторы)
     */
    TradeOrderInstruction ProcessMultipleCandidates(SignalCandidate &candidates[], int candidates_count) {
        TradeOrderInstruction instruction;
        
        // Группируем кандидатов по направлению
        SignalCandidate* buy_candidates[10];
        SignalCandidate* sell_candidates[10];
        int buy_count = 0, sell_count = 0;
        
        for(int i = 0; i < candidates_count && i < 10; i++) {
            if(!candidates[i].isValid) continue;
            
            if(candidates[i].direction > 0 && buy_count < 10) {
                buy_candidates[buy_count] = &candidates[i];
                buy_count++;
            } else if(candidates[i].direction < 0 && sell_count < 10) {
                sell_candidates[sell_count] = &candidates[i];
                sell_count++;
            }
        }
        
        // Определяем лучшую группу
        double buy_score = CalculateGroupScore(buy_candidates, buy_count);
        double sell_score = CalculateGroupScore(sell_candidates, sell_count);
        
        if(buy_score < m_min_confidence_threshold && sell_score < m_min_confidence_threshold) {
            instruction.decision_reason = StringFormat("No group above threshold: BUY %.2f, SELL %.2f", buy_score, sell_score);
            return instruction;
        }
        
        // Выбираем лучшую группу
        SignalCandidate** winning_group;
        int winning_count;
        double winning_score;
        string winning_direction;
        
        if(buy_score > sell_score) {
            winning_group = buy_candidates;
            winning_count = buy_count;
            winning_score = buy_score;
            winning_direction = "BUY";
            instruction.direction = 1;
        } else {
            winning_group = sell_candidates;
            winning_count = sell_count;
            winning_score = sell_score;
            winning_direction = "SELL";
            instruction.direction = -1;
        }
        
        if(winning_count >= 2) {
            m_confluence_decisions++; // Засчитываем как confluence решение
        }
        
        // Формируем composite сигнал
        instruction.isValid = true;
        instruction.final_confidence = winning_score;
        instruction.confluence_bonus = (winning_count - 1) * 0.1; // Бонус за каждый дополнительный сигнал
        
        // Усредняем параметры лучших сигналов
        double avg_entry = 0, avg_sl = 0, avg_tp = 0;
        string strategies_list = "";
        
        for(int i = 0; i < winning_count; i++) {
            avg_entry += winning_group[i].entry_price;
            avg_sl += winning_group[i].stop_loss;
            avg_tp += winning_group[i].take_profit;
            
            strategies_list += winning_group[i].strategyID;
            if(i < winning_count - 1) strategies_list += "+";
        }
        
        instruction.entry_price = avg_entry / winning_count;
        instruction.stop_loss = avg_sl / winning_count;
        instruction.take_profit = avg_tp / winning_count;
        instruction.winning_strategy = strategies_list;
        instruction.orderType = "MARKET"; // Confluence сигналы часто требуют быстрого исполнения
        
        // Увеличиваем размер лота для confluence сигналов
        instruction.lot_size = m_base_lot_size * (1.0 + winning_count * 0.2);
        instruction.lot_size = MathMin(instruction.lot_size, m_max_lot_size);
        instruction.volume_scenario = "CONFLUENCE";
        
        instruction.decision_reason = StringFormat("Confluence: %d %s strategies, Score: %.2f, Bonus: %.2f", 
                                                 winning_count, winning_direction, winning_score, instruction.confluence_bonus);
        
        return instruction;
    }
    
    /**
     * @brief Расчет общего счета группы сигналов
     * @param group Группа сигналов
     * @param count Количество сигналов в группе
     * @return Общий счет группы
     */
    double CalculateGroupScore(SignalCandidate* group[], int count) {
        if(count == 0) return 0.0;
        
        double total_score = 0;
        double weight_sum = 0;
        
        for(int i = 0; i < count; i++) {
            double weight = 1.0; // Базовый вес
            
            // Даем больший вес высоко-надежным стратегиям
            if(group[i].confidence_score > 0.8) weight = 1.5;
            else if(group[i].confidence_score > 0.6) weight = 1.2;
            
            total_score += group[i].confidence_score * weight;
            weight_sum += weight;
        }
        
        double base_score = total_score / weight_sum;
        
        // Confluence бонус
        double confluence_bonus = 0;
        if(count >= 2) confluence_bonus = (count - 1) * 0.1 * m_confluence_multiplier;
        
        return MathMin(1.0, base_score + confluence_bonus);
    }
    
    /**
     * @brief Определение оптимального типа ордера
     * @param candidate Сигнал-кандидат
     * @return Тип ордера
     */
    string GetOptimalOrderType(const SignalCandidate &candidate) {
        // Анализируем расстояние до entry цены
        double current_price = SymbolInfoDouble(candidate.symbol, SYMBOL_BID);
        double distance = MathAbs(candidate.entry_price - current_price) / current_price;
        
        if(distance < 0.001) {
            return "MARKET"; // Цена очень близка - рыночный ордер
        } else if(distance < 0.005) {
            return "LIMIT"; // Небольшое расстояние - лимитный ордер
        } else {
            return "STOP"; // Большое расстояние - стоп ордер
        }
    }
    
    /**
     * @brief Инициализация матриц конфликтов и конфлюэнса
     */
    void InitializeConflictConfluenceMatrices() {
        // Инициализируем названия стратегий
        m_strategy_names[0] = "NightMR";
        m_strategy_names[1] = "ChannelBoundary";
        m_strategy_names[2] = "FalseBreakout";
        m_strategy_names[3] = "DualMA_Anchor";
        m_strategy_names[4] = "DonchianBreakout";
        m_strategy_count = 5;
        
        // Инициализируем матрицу конфликтов
        // 0.0 = нет конфликта, 1.0 = полный конфликт
        for(int i = 0; i < 10; i++) {
            for(int j = 0; j < 10; j++) {
                if(i == j) {
                    m_conflict_matrix[i][j] = 0.0; // Стратегия не конфликтует сама с собой
                } else {
                    m_conflict_matrix[i][j] = 0.5; // Базовый уровень конфликта
                }
            }
        }
        
        // Специфические конфликты между стратегиями
        // NightMR vs Trend strategies (высокий конфликт)
        SetConflictLevel("NightMR", "DualMA_Anchor", 0.9);
        SetConflictLevel("NightMR", "DonchianBreakout", 0.9);
        
        // ChannelBoundary vs FalseBreakout (средний конфликт)
        SetConflictLevel("ChannelBoundary", "FalseBreakout", 0.7);
        
        // Trend strategies между собой (низкий конфликт)
        SetConflictLevel("DualMA_Anchor", "DonchianBreakout", 0.3);
        
        // Инициализируем матрицу конфлюэнса
        // 0.0 = нет конфлюэнса, 1.0 = полная конфлюэнса
        for(int i = 0; i < 10; i++) {
            for(int j = 0; j < 10; j++) {
                if(i == j) {
                    m_confluence_matrix[i][j] = 1.0; // Стратегия полностью конфлюэнтна сама с собой
                } else {
                    m_confluence_matrix[i][j] = 0.0; // Базовый уровень конфлюэнса
                }
            }
        }
        
        // Специфическая конфлюэнса между стратегиями
        // Trend strategies имеют высокую конфлюэнса
        SetConfluenceLevel("DualMA_Anchor", "DonchianBreakout", 0.8);
        
        // Flat strategies имеют среднюю конфлюэнса
        SetConfluenceLevel("ChannelBoundary", "FalseBreakout", 0.6);
        
        Print("Resolver: Conflict and Confluence matrices initialized with ", m_strategy_count, " strategies");
    }
    
    /**
     * @brief Установка уровня конфликта между стратегиями
     * @param strategy1 Первая стратегия
     * @param strategy2 Вторая стратегия
     * @param conflict_level Уровень конфликта (0.0 - 1.0)
     */
    void SetConflictLevel(const string strategy1, const string strategy2, double conflict_level) {
        int idx1 = GetStrategyIndex(strategy1);
        int idx2 = GetStrategyIndex(strategy2);
        
        if(idx1 >= 0 && idx2 >= 0) {
            m_conflict_matrix[idx1][idx2] = conflict_level;
            m_conflict_matrix[idx2][idx1] = conflict_level; // Симметричная матрица
        }
    }
    
    /**
     * @brief Установка уровня конфлюэнса между стратегиями
     * @param strategy1 Первая стратегия
     * @param strategy2 Вторая стратегия
     * @param confluence_level Уровень конфлюэнса (0.0 - 1.0)
     */
    void SetConfluenceLevel(const string strategy1, const string strategy2, double confluence_level) {
        int idx1 = GetStrategyIndex(strategy1);
        int idx2 = GetStrategyIndex(strategy2);
        
        if(idx1 >= 0 && idx2 >= 0) {
            m_confluence_matrix[idx1][idx2] = confluence_level;
            m_confluence_matrix[idx2][idx1] = confluence_level; // Симметричная матрица
        }
    }
    
    /**
     * @brief Получение индекса стратегии по названию
     * @param strategy_name Название стратегии
     * @return Индекс стратегии или -1 если не найдена
     */
    int GetStrategyIndex(const string strategy_name) {
        for(int i = 0; i < m_strategy_count; i++) {
            if(m_strategy_names[i] == strategy_name) {
                return i;
            }
        }
        return -1;
    }
    
    /**
     * @brief Анализ конфликтов между кандидатами
     * @param candidates Массив кандидатов
     * @param candidates_count Количество кандидатов
     * @return true если обнаружены критические конфликты
     */
    bool AnalyzeConflicts(SignalCandidate &candidates[], int candidates_count) {
        for(int i = 0; i < candidates_count; i++) {
            for(int j = i + 1; j < candidates_count; j++) {
                // Проверяем конфликт по направлению
                if(candidates[i].direction != candidates[j].direction) {
                    int idx1 = GetStrategyIndex(candidates[i].strategyID);
                    int idx2 = GetStrategyIndex(candidates[j].strategyID);
                    
                    if(idx1 >= 0 && idx2 >= 0) {
                        double conflict_level = m_conflict_matrix[idx1][idx2];
                        
                        // Если конфликт критический (выше 0.8), блокируем оба сигнала
                        if(conflict_level > 0.8) {
                            candidates[i].isValid = false;
                            candidates[i].signal_reason = StringFormat("Critical conflict with %s (level: %.2f)", 
                                                                     candidates[j].strategyID, conflict_level);
                            candidates[j].isValid = false;
                            candidates[j].signal_reason = StringFormat("Critical conflict with %s (level: %.2f)", 
                                                                     candidates[i].strategyID, conflict_level);
                            
                            Print("Resolver: Critical conflict detected between ", candidates[i].strategyID, 
                                  " and ", candidates[j].strategyID, " (level: ", conflict_level, ")");
                            return true;
                        }
                    }
                }
            }
        }
        return false;
    }
    
    /**
     * @brief Расчет конфлюэнса между кандидатами
     * @param candidates Массив кандидатов
     * @param candidates_count Количество кандидатов
     * @return Общий уровень конфлюэнса (0.0 - 1.0)
     */
    double CalculateConfluence(SignalCandidate &candidates[], int candidates_count) {
        if(candidates_count < 2) return 0.0;
        
        double total_confluence = 0.0;
        int confluence_pairs = 0;
        
        for(int i = 0; i < candidates_count; i++) {
            for(int j = i + 1; j < candidates_count; j++) {
                // Проверяем конфлюэнса только для сигналов в одном направлении
                if(candidates[i].direction == candidates[j].direction) {
                    int idx1 = GetStrategyIndex(candidates[i].strategyID);
                    int idx2 = GetStrategyIndex(candidates[j].strategyID);
                    
                    if(idx1 >= 0 && idx2 >= 0) {
                        double confluence_level = m_confluence_matrix[idx1][idx2];
                        total_confluence += confluence_level;
                        confluence_pairs++;
                    }
                }
            }
        }
        
        if(confluence_pairs == 0) return 0.0;
        return total_confluence / confluence_pairs;
    }
    
    /**
     * @brief Применение конфлюэнса к confidence score
     * @param base_confidence Базовый confidence score
     * @param confluence_level Уровень конфлюэнса
     * @return Скорректированный confidence score
     */
    double ApplyConfluenceBoost(double base_confidence, double confluence_level) {
        // Конфлюэнса увеличивает confidence score
        double boost = confluence_level * 0.3; // Максимальный бонус 30%
        return MathMin(1.0, base_confidence + boost);
    }
    
    /**
     * @brief Получение статистики матриц
     * @param stats_string Строка со статистикой (выходной параметр)
     */
    void GetMatrixStats(string &stats_string) {
        int high_conflicts = 0;
        int high_confluences = 0;
        
        for(int i = 0; i < m_strategy_count; i++) {
            for(int j = i + 1; j < m_strategy_count; j++) {
                if(m_conflict_matrix[i][j] > 0.7) high_conflicts++;
                if(m_confluence_matrix[i][j] > 0.7) high_confluences++;
            }
        }
        
        stats_string = StringFormat("Matrix Stats: Strategies=%d, High Conflicts=%d, High Confluences=%d",
                                   m_strategy_count, high_conflicts, high_confluences);
    }
    
    /**
     * @brief Инициализация гибких фильтров
     */
    void InitializeFlexibleFilters() {
        // Адаптивные пороги на основе рыночных условий
        m_confidence_threshold = 0.7;      // Базовый порог confidence
        m_risk_reward_threshold = 1.5;     // Базовый порог R:R
        m_volume_filter_threshold = 1.2;   // Порог фильтра объема
        m_volatility_filter = 0.5;         // Фильтр волатильности
        
        // Включение фильтров
        m_enable_news_filter = true;       // Фильтр новостей
        m_enable_session_filter = true;    // Фильтр торговых сессий
        
        Print("Resolver: Flexible filters initialized");
    }
    
    /**
     * @brief Инициализация протокола контртренда
     */
    void InitializeCountertrendProtocol() {
        m_enable_countertrend = false;     // По умолчанию отключен
        m_countertrend_threshold = 0.8;    // Высокий порог для контртренда
        m_countertrend_max_attempts = 3;   // Максимум 3 попытки
        m_countertrend_attempts = 0;       // Счетчик попыток
        m_last_countertrend_time = 0;      // Время последней попытки
        
        Print("Resolver: Countertrend protocol initialized");
    }
    
    /**
     * @brief Применение гибких фильтров к кандидатам
     * @param candidates Массив кандидатов
     * @param candidates_count Количество кандидатов
     * @return Количество отфильтрованных кандидатов
     */
    int ApplyFlexibleFilters(SignalCandidate &candidates[], int candidates_count) {
        int filtered_count = 0;
        
        for(int i = 0; i < candidates_count; i++) {
            if(!candidates[i].isValid) continue;
            
            bool passed_filters = true;
            string filter_reason = "";
            
            // Фильтр confidence score
            if(candidates[i].confidence_score < m_confidence_threshold) {
                passed_filters = false;
                filter_reason = StringFormat("Confidence too low: %.2f < %.2f", 
                                           candidates[i].confidence_score, m_confidence_threshold);
            }
            
            // Фильтр R:R соотношения
            if(passed_filters && candidates[i].risk_reward_ratio < m_risk_reward_threshold) {
                passed_filters = false;
                filter_reason = StringFormat("R:R too low: %.2f < %.2f", 
                                           candidates[i].risk_reward_ratio, m_risk_reward_threshold);
            }
            
            // Фильтр объема (если доступен)
            if(passed_filters && m_enable_news_filter) {
                // Здесь можно добавить проверку объема
                // Пока пропускаем
            }
            
            // Фильтр волатильности
            if(passed_filters && m_volatility_filter > 0) {
                // Здесь можно добавить проверку волатильности
                // Пока пропускаем
            }
            
            // Фильтр торговых сессий
            if(passed_filters && m_enable_session_filter) {
                if(!IsInActiveTradingSession()) {
                    passed_filters = false;
                    filter_reason = "Outside active trading session";
                }
            }
            
            if(!passed_filters) {
                candidates[i].isValid = false;
                candidates[i].signal_reason = "Filtered: " + filter_reason;
            } else {
                filtered_count++;
            }
        }
        
        return filtered_count;
    }
    
    /**
     * @brief Проверка активной торговой сессии
     * @return true если текущее время в активной сессии
     */
    bool IsInActiveTradingSession() {
        datetime current_time = TimeCurrent();
        MqlDateTime time_struct;
        TimeToStruct(current_time, time_struct);
        
        int hour = time_struct.hour;
        
        // Лондонская сессия: 8:00 - 17:00 GMT
        // Нью-Йоркская сессия: 13:00 - 22:00 GMT
        // Азиатская сессия: 0:00 - 9:00 GMT
        
        return (hour >= 8 && hour < 17) ||   // Лондон
               (hour >= 13 && hour < 22) ||  // Нью-Йорк
               (hour >= 0 && hour < 9);      // Азия
    }
    
    /**
     * @brief Анализ контртрендовых возможностей
     * @param candidates Массив кандидатов
     * @param candidates_count Количество кандидатов
     * @param current_regime Текущий режим рынка
     * @return true если найдены контртрендовые возможности
     */
    bool AnalyzeCountertrendOpportunities(SignalCandidate &candidates[], int candidates_count, E_MarketRegime current_regime) {
        if(!m_enable_countertrend) return false;
        
        // Проверяем лимит попыток
        if(m_countertrend_attempts >= m_countertrend_max_attempts) {
            return false;
        }
        
        // Проверяем время с последней попытки (минимум 1 час)
        datetime current_time = TimeCurrent();
        if(current_time - m_last_countertrend_time < 3600) {
            return false;
        }
        
        // Ищем контртрендовые сигналы только в определенных режимах
        if(current_regime != REGIME_TREND_STRONG && 
           current_regime != REGIME_TREND_WEAKENING) {
            return false;
        }
        
        // Ищем сигналы с очень высоким confidence score
        for(int i = 0; i < candidates_count; i++) {
            if(candidates[i].isValid && 
               candidates[i].confidence_score >= m_countertrend_threshold) {
                
                // Проверяем, является ли сигнал контртрендовым
                if(IsCountertrendSignal(candidates[i], current_regime)) {
                    m_countertrend_attempts++;
                    m_last_countertrend_time = current_time;
                    
                    Print("Resolver: Countertrend opportunity detected - attempt ", m_countertrend_attempts);
                    return true;
                }
            }
        }
        
        return false;
    }
    
    /**
     * @brief Проверка контртрендового сигнала
     * @param candidate Кандидат для проверки
     * @param current_regime Текущий режим рынка
     * @return true если сигнал контртрендовый
     */
    bool IsCountertrendSignal(const SignalCandidate &candidate, E_MarketRegime current_regime) {
        // В сильном тренде ищем сигналы против тренда
        if(current_regime == REGIME_TREND_STRONG) {
            // Здесь можно добавить логику определения направления тренда
            // и сравнения с направлением сигнала
            return true; // Упрощенная версия
        }
        
        // В ослабевающем тренде контртрендовые сигналы более вероятны
        if(current_regime == REGIME_TREND_WEAKENING) {
            return candidate.confidence_score > 0.9; // Очень высокий confidence
        }
        
        return false;
    }
    
    /**
     * @brief Сброс счетчика контртрендовых попыток
     */
    void ResetCountertrendAttempts() {
        m_countertrend_attempts = 0;
        m_last_countertrend_time = 0;
        Print("Resolver: Countertrend attempts reset");
    }
    
    /**
     * @brief Настройка гибких фильтров
     * @param confidence_threshold Порог confidence
     * @param risk_reward_threshold Порог R:R
     * @param volume_threshold Порог объема
     * @param volatility_filter Фильтр волатильности
     */
    void ConfigureFlexibleFilters(double confidence_threshold, 
                                 double risk_reward_threshold,
                                 double volume_threshold,
                                 double volatility_filter) {
        m_confidence_threshold = confidence_threshold;
        m_risk_reward_threshold = risk_reward_threshold;
        m_volume_filter_threshold = volume_threshold;
        m_volatility_filter = volatility_filter;
        
        Print("Resolver: Flexible filters configured - Confidence: ", confidence_threshold, 
              ", R:R: ", risk_reward_threshold, ", Volume: ", volume_threshold, 
              ", Volatility: ", volatility_filter);
    }
    
    /**
     * @brief Включение/отключение протокола контртренда
     * @param enable Включить контртренд
     * @param threshold Порог для контртрендовых сигналов
     * @param max_attempts Максимум попыток
     */
    void ConfigureCountertrendProtocol(bool enable, double threshold, int max_attempts) {
        m_enable_countertrend = enable;
        m_countertrend_threshold = threshold;
        m_countertrend_max_attempts = max_attempts;
        
        if(enable) {
            Print("Resolver: Countertrend protocol enabled - Threshold: ", threshold, 
                  ", Max attempts: ", max_attempts);
        } else {
            Print("Resolver: Countertrend protocol disabled");
        }
    }
    
    /**
     * @brief Получение статистики фильтров
     * @param stats_string Строка со статистикой (выходной параметр)
     */
    void GetFilterStats(string &stats_string) {
        stats_string = StringFormat("Filter Stats: Confidence=%.2f, R:R=%.2f, Volume=%.2f, Volatility=%.2f, Countertrend=%s (%d/%d)",
                                   m_confidence_threshold, m_risk_reward_threshold, 
                                   m_volume_filter_threshold, m_volatility_filter,
                                   m_enable_countertrend ? "ON" : "OFF",
                                   m_countertrend_attempts, m_countertrend_max_attempts);
    }
    
    /**
     * @brief Применение AI-анализа к кандидатам
     * @param candidates Массив кандидатов
     * @param candidates_count Количество кандидатов
     */
    void ApplyAiAnalysis(SignalCandidate &candidates[], int candidates_count) {
        if(m_ai_layer == NULL || !m_ai_layer->IsInitialized()) {
            return;
        }
        
        string market_context = StringFormat("Regime=%s, Time=%s", 
                                           EnumToString(REGIME_UNDEFINED), 
                                           TimeToString(TimeCurrent()));
        
        for(int i = 0; i < candidates_count; i++) {
            if(!candidates[i].isValid) continue;
            
            // Получаем AI-оценку вероятности
            double ai_probability = m_ai_layer->IsSignalProbable(candidates[i], market_context);
            
            // Корректируем confidence score на основе AI-анализа
            double original_confidence = candidates[i].confidence_score;
            candidates[i].confidence_score = (original_confidence + ai_probability) / 2.0;
            
            // Если AI-анализ показывает низкую вероятность, помечаем как невалидный
            if(ai_probability < 0.3) {
                candidates[i].isValid = false;
                candidates[i].signal_reason = StringFormat("AI analysis: Low probability %.2f", ai_probability);
            } else {
                candidates[i].signal_reason += StringFormat(" | AI: %.2f", ai_probability);
            }
            
            Print("Resolver: AI analysis applied - Strategy: ", candidates[i].strategyID, 
                  ", Original: ", DoubleToString(original_confidence, 3),
                  ", AI: ", DoubleToString(ai_probability, 3),
                  ", Final: ", DoubleToString(candidates[i].confidence_score, 3));
        }
    }
    
    /**
     * @brief Установка указателя на AI-Слой
     * @param ai_layer_ptr Указатель на AI-Слой
     */
    void SetAiLayer(CAiLayer* ai_layer_ptr) {
        m_ai_layer = ai_layer_ptr;
        Print("Resolver: AI Layer pointer set to ", (ai_layer_ptr != NULL ? "VALID" : "NULL"));
    }
    
    /**
     * @brief Получение указателя на AI-Слой
     * @return Указатель на AI-Слой
     */
    CAiLayer* GetAiLayer() const {
        return m_ai_layer;
    }
};

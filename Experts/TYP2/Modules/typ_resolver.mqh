// --- typ_resolver.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Sprint 2 :: Trading Decision Resolver (The Brain)
#property copyright "TYP2"

#include "typ_strategies.mqh"

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
    
public:
    /**
     * @brief Конструктор Resolver
     */
    CResolver() : m_figures(NULL),
                  m_patterns(NULL),
                  m_min_confidence_threshold(0.7),
                  m_confluence_multiplier(1.3),
                  m_macro_figure_priority(2.0),
                  m_base_lot_size(0.1),
                  m_max_lot_size(1.0),
                  m_confidence_scaling(1.5),
                  m_total_decisions(0),
                  m_macro_decisions(0),
                  m_confluence_decisions(0)
    {}
    
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
     */
    void Initialize(CFigures* figures_ptr, CPatterns* patterns_ptr) {
        m_figures = figures_ptr;
        m_patterns = patterns_ptr;
    }
    
    /**
     * @brief Главный метод принятия торговых решений
     * @param candidates Массив сигналов-кандидатов от стратегий
     * @param candidates_count Количество кандидатов
     * @return Структура торгового приказа
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
        
        // ЭТАП 2: Скоринг и Confluence анализ (Уровень 2)
        if(candidates_count == 1) {
            // Единственный кандидат - анализируем его индивидуально
            return ProcessSingleCandidate(candidates[0]);
        }
        
        // ЭТАП 3: Множественные кандидаты - ищем confluence
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
};

// --- typ_timer_manager.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Sprint 2 :: Timer Manager for Computation Throttling
#property copyright "TYP2"

/**
 * @brief Структура для хранения информации о таймере
 */
struct TimerInfo {
    string timer_name;          // Название таймера
    datetime last_execution;    // Время последнего выполнения
    int interval_seconds;       // Интервал в секундах
    bool is_active;             // Активен ли таймер
    int execution_count;        // Количество выполнений
    datetime next_execution;    // Время следующего выполнения
    
    TimerInfo() {
        timer_name = "";
        last_execution = 0;
        interval_seconds = 0;
        is_active = false;
        execution_count = 0;
        next_execution = 0;
    }
};

/**
 * @brief Менеджер таймеров для дросселирования вычислений
 * 
 * Предоставляет централизованное управление временными интервалами
 * для оптимизации производительности системы.
 */
class CTimerManager {
private:
    // --- ПРИВАТНЫЕ ПЕРЕМЕННЫЕ ---
    TimerInfo m_timers[20];     // Массив таймеров
    int m_timer_count;          // Количество активных таймеров
    datetime m_last_cleanup;    // Время последней очистки
    
    // --- ПРИВАТНЫЕ МЕТОДЫ ---
    
    /**
     * @brief Поиск индекса таймера по имени
     * @param timer_name Название таймера
     * @return Индекс таймера или -1 если не найден
     */
    int FindTimerIndex(const string timer_name) const {
        for(int i = 0; i < m_timer_count; i++) {
            if(m_timers[i].timer_name == timer_name) {
                return i;
            }
        }
        return -1;
    }
    
    /**
     * @brief Очистка неактивных таймеров
     */
    void CleanupInactiveTimers() {
        datetime current_time = TimeCurrent();
        
        // Очищаем неактивные таймеры старше 1 часа
        for(int i = m_timer_count - 1; i >= 0; i--) {
            if(!m_timers[i].is_active && 
               (current_time - m_timers[i].last_execution) > 3600) {
                
                // Сдвигаем массив
                for(int j = i; j < m_timer_count - 1; j++) {
                    m_timers[j] = m_timers[j + 1];
                }
                m_timer_count--;
            }
        }
    }
    
public:
    /**
     * @brief Конструктор
     */
    CTimerManager() : m_timer_count(0), m_last_cleanup(0) {
        // Инициализация стандартных таймеров
        InitializeStandardTimers();
    }
    
    /**
     * @brief Деструктор
     */
    ~CTimerManager() {}
    
    /**
     * @brief Инициализация стандартных таймеров системы
     */
    void InitializeStandardTimers() {
        // Таймер для обновления режима рынка (каждые 30 секунд)
        RegisterTimer("MarketRegimeUpdate", 30);
        
        // Таймер для обновления позиций (каждые 10 секунд)
        RegisterTimer("PositionUpdate", 10);
        
        // Таймер для визуализации (каждые 5 минут)
        RegisterTimer("VisualizationUpdate", 300);
        
        // Таймер для анализа рисков (каждую минуту)
        RegisterTimer("RiskAnalysis", 60);
        
        // Таймер для генерации сигналов (каждые 15 секунд)
        RegisterTimer("SignalGeneration", 15);
        
        // Таймер для статистики (каждые 2 минуты)
        RegisterTimer("StatisticsUpdate", 120);
        
        Print("Timer Manager: Initialized with ", m_timer_count, " standard timers");
    }
    
    /**
     * @brief Регистрация нового таймера
     * @param timer_name Название таймера
     * @param interval_seconds Интервал в секундах
     * @return true если таймер успешно зарегистрирован
     */
    bool RegisterTimer(const string timer_name, int interval_seconds) {
        if(m_timer_count >= 20) {
            Print("Timer Manager: Maximum number of timers reached (20)");
            return false;
        }
        
        // Проверяем, не существует ли уже таймер с таким именем
        int existing_index = FindTimerIndex(timer_name);
        if(existing_index >= 0) {
            // Обновляем существующий таймер
            m_timers[existing_index].interval_seconds = interval_seconds;
            m_timers[existing_index].is_active = true;
            m_timers[existing_index].next_execution = TimeCurrent() + interval_seconds;
            Print("Timer Manager: Updated timer '", timer_name, "' with interval ", interval_seconds, "s");
            return true;
        }
        
        // Создаем новый таймер
        m_timers[m_timer_count].timer_name = timer_name;
        m_timers[m_timer_count].interval_seconds = interval_seconds;
        m_timers[m_timer_count].is_active = true;
        m_timers[m_timer_count].last_execution = 0;
        m_timers[m_timer_count].execution_count = 0;
        m_timers[m_timer_count].next_execution = TimeCurrent() + interval_seconds;
        
        m_timer_count++;
        Print("Timer Manager: Registered timer '", timer_name, "' with interval ", interval_seconds, "s");
        return true;
    }
    
    /**
     * @brief Проверка готовности таймера к выполнению
     * @param timer_name Название таймера
     * @return true если таймер готов к выполнению
     */
    bool IsTimerReady(const string timer_name) const {
        int index = FindTimerIndex(timer_name);
        if(index < 0) return false;
        
        if(!m_timers[index].is_active) return false;
        
        datetime current_time = TimeCurrent();
        return current_time >= m_timers[index].next_execution;
    }
    
    /**
     * @brief Отметка выполнения таймера
     * @param timer_name Название таймера
     * @return true если таймер успешно отмечен как выполненный
     */
    bool MarkTimerExecuted(const string timer_name) {
        int index = FindTimerIndex(timer_name);
        if(index < 0) return false;
        
        datetime current_time = TimeCurrent();
        m_timers[index].last_execution = current_time;
        m_timers[index].execution_count++;
        m_timers[index].next_execution = current_time + m_timers[index].interval_seconds;
        
        return true;
    }
    
    /**
     * @brief Активация таймера
     * @param timer_name Название таймера
     * @return true если таймер успешно активирован
     */
    bool ActivateTimer(const string timer_name) {
        int index = FindTimerIndex(timer_name);
        if(index < 0) return false;
        
        m_timers[index].is_active = true;
        m_timers[index].next_execution = TimeCurrent() + m_timers[index].interval_seconds;
        return true;
    }
    
    /**
     * @brief Деактивация таймера
     * @param timer_name Название таймера
     * @return true если таймер успешно деактивирован
     */
    bool DeactivateTimer(const string timer_name) {
        int index = FindTimerIndex(timer_name);
        if(index < 0) return false;
        
        m_timers[index].is_active = false;
        return true;
    }
    
    /**
     * @brief Получение информации о таймере
     * @param timer_name Название таймера
     * @param timer_info Структура с информацией о таймере (выходной параметр)
     * @return true если информация успешно получена
     */
    bool GetTimerInfo(const string timer_name, TimerInfo &timer_info) const {
        int index = FindTimerIndex(timer_name);
        if(index < 0) return false;
        
        timer_info = m_timers[index];
        return true;
    }
    
    /**
     * @brief Получение статистики таймеров
     * @param stats_string Строка со статистикой (выходной параметр)
     */
    void GetTimerStats(string &stats_string) const {
        int active_timers = 0;
        int total_executions = 0;
        
        for(int i = 0; i < m_timer_count; i++) {
            if(m_timers[i].is_active) active_timers++;
            total_executions += m_timers[i].execution_count;
        }
        
        stats_string = StringFormat("Timers: %d active/%d total | Executions: %d | Last cleanup: %s",
                                   active_timers, m_timer_count, total_executions,
                                   TimeToString(m_last_cleanup, TIME_DATE|TIME_SECONDS));
    }
    
    /**
     * @brief Обновление менеджера таймеров
     * 
     * Вызывается в OnTick() для обновления состояния таймеров
     */
    void Update() {
        datetime current_time = TimeCurrent();
        
        // Очищаем неактивные таймеры каждые 10 минут
        if(current_time - m_last_cleanup > 600) {
            CleanupInactiveTimers();
            m_last_cleanup = current_time;
        }
    }
    
    /**
     * @brief Получение времени до следующего выполнения таймера
     * @param timer_name Название таймера
     * @return Время в секундах до следующего выполнения (0 если таймер не найден)
     */
    int GetTimeToNextExecution(const string timer_name) const {
        int index = FindTimerIndex(timer_name);
        if(index < 0) return 0;
        
        if(!m_timers[index].is_active) return 0;
        
        datetime current_time = TimeCurrent();
        int time_diff = (int)(m_timers[index].next_execution - current_time);
        
        return MathMax(0, time_diff);
    }
    
    /**
     * @brief Получение списка готовых к выполнению таймеров
     * @param ready_timers Массив названий готовых таймеров (выходной параметр)
     * @return Количество готовых таймеров
     */
    int GetReadyTimers(string &ready_timers[]) const {
        int ready_count = 0;
        ArrayResize(ready_timers, 0);
        
        for(int i = 0; i < m_timer_count; i++) {
            if(m_timers[i].is_active && IsTimerReady(m_timers[i].timer_name)) {
                ArrayResize(ready_timers, ready_count + 1);
                ready_timers[ready_count] = m_timers[i].timer_name;
                ready_count++;
            }
        }
        
        return ready_count;
    }
    
    /**
     * @brief Сброс всех таймеров
     */
    void ResetAllTimers() {
        for(int i = 0; i < m_timer_count; i++) {
            m_timers[i].last_execution = 0;
            m_timers[i].execution_count = 0;
            m_timers[i].next_execution = TimeCurrent() + m_timers[i].interval_seconds;
        }
        
        Print("Timer Manager: All timers reset");
    }
    
    /**
     * @brief Получение количества активных таймеров
     * @return Количество активных таймеров
     */
    int GetActiveTimerCount() const {
        int active_count = 0;
        for(int i = 0; i < m_timer_count; i++) {
            if(m_timers[i].is_active) active_count++;
        }
        return active_count;
    }
};

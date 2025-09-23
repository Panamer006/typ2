// --- typ_execfilters.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Task: T2-005 :: Execution Filters (ExecGate)
#property copyright "TYP2"

#include "typ_regime_engine.mqh" // Подключаем Движок Режимов
#include <Trade/Trade.mqh>

// --- Структура для хранения новостей ---
struct NewsEvent {
    datetime start_time;
    datetime end_time;
    string   currency;
    string   title;
    int      impact; // 0=Low, 1=Medium, 2=High
    
    NewsEvent() {
        start_time = 0;
        end_time = 0;
        currency = "";
        title = "";
        impact = 0;
    }
    
    NewsEvent(datetime start, datetime end, string curr, string news_title, int imp) {
        start_time = start;
        end_time = end;
        currency = curr;
        title = news_title;
        impact = imp;
    }
};

/**
 * @brief Центральная система фильтров исполнения (ExecGate)
 * 
 * Обеспечивает многоуровневую защиту от неблагоприятных условий исполнения:
 * новостные события, спред, волатильность, сессии и проскальзывание.
 */
class CExecGate {
private:
    // --- ПАРАМЕТРЫ ---
    bool m_is_news_guard_enabled;
    bool m_is_spread_guard_enabled;
    bool m_is_volatility_guard_enabled;
    bool m_is_session_guard_enabled;
    bool m_is_slippage_guard_enabled;
    
    // Параметры NewsGuard
    int m_news_block_minutes_before;
    int m_news_block_minutes_after;
    int m_high_impact_block_minutes;
    int m_medium_impact_block_minutes;
    int m_low_impact_block_minutes;
    
    // Параметры SpreadGuard
    double m_max_spread_pips;
    double m_atr_multiplier_for_spread;
    
    // Параметры VolatilityGuard
    double m_max_volatility_percent;
    int m_volatility_lookback_periods;
    
    // Параметры SessionGuard
    bool m_is_london_session_enabled;
    bool m_is_new_york_session_enabled;
    bool m_is_tokyo_session_enabled;
    int m_london_start_hour;
    int m_london_end_hour;
    int m_new_york_start_hour;
    int m_new_york_end_hour;
    int m_tokyo_start_hour;
    int m_tokyo_end_hour;
    
    // Параметры SlippageGuard
    double m_max_slippage_pips;
    
    // --- СОСТОЯНИЕ КЛАССА ---
    NewsEvent m_news_events[];
    int m_news_events_count;
    datetime m_last_news_update;
    
    // Хэндлы индикаторов
    int m_h_atr;

public:
    // --- Публичные Методы ---
    
    /**
     * @brief Конструктор фильтров исполнения
     */
    CExecGate();
    
    /**
     * @brief Деструктор - освобождает ресурсы
     */
    ~CExecGate();
    
    /**
     * @brief Инициализация системы фильтров исполнения
     * @param is_news_guard_enabled Включить защиту от новостей
     * @param is_spread_guard_enabled Включить защиту от спреда
     * @param is_volatility_guard_enabled Включить защиту от волатильности
     * @param is_session_guard_enabled Включить защиту по сессиям
     * @param is_slippage_guard_enabled Включить защиту от проскальзывания
     * @param news_block_minutes_before Блокировка до новостей (минуты)
     * @param news_block_minutes_after Блокировка после новостей (минуты)
     * @param high_impact_block_minutes Блокировка для высокого воздействия (минуты)
     * @param medium_impact_block_minutes Блокировка для среднего воздействия (минуты)
     * @param low_impact_block_minutes Блокировка для низкого воздействия (минуты)
     * @param max_spread_pips Максимальный спред в пипсах
     * @param atr_multiplier_for_spread Множитель ATR для динамического спреда
     * @param max_volatility_percent Максимальная волатильность в %
     * @param volatility_lookback_periods Период для расчета волатильности
     * @param is_london_session_enabled Включить Лондонскую сессию
     * @param is_new_york_session_enabled Включить Нью-Йоркскую сессию
     * @param is_tokyo_session_enabled Включить Токийскую сессию
     * @param london_start_hour Начало Лондонской сессии (час)
     * @param london_end_hour Конец Лондонской сессии (час)
     * @param new_york_start_hour Начало Нью-Йоркской сессии (час)
     * @param new_york_end_hour Конец Нью-Йоркской сессии (час)
     * @param tokyo_start_hour Начало Токийской сессии (час)
     * @param tokyo_end_hour Конец Токийской сессии (час)
     * @param max_slippage_pips Максимальное проскальзывание в пипсах
     */
    void Initialize(bool is_news_guard_enabled = true,
                   bool is_spread_guard_enabled = true,
                   bool is_volatility_guard_enabled = true,
                   bool is_session_guard_enabled = true,
                   bool is_slippage_guard_enabled = true,
                   int news_block_minutes_before = 30,
                   int news_block_minutes_after = 15,
                   int high_impact_block_minutes = 60,
                   int medium_impact_block_minutes = 30,
                   int low_impact_block_minutes = 15,
                   double max_spread_pips = 3.0,
                   double atr_multiplier_for_spread = 2.0,
                   double max_volatility_percent = 5.0,
                   int volatility_lookback_periods = 20,
                   bool is_london_session_enabled = true,
                   bool is_new_york_session_enabled = true,
                   bool is_tokyo_session_enabled = false,
                   int london_start_hour = 8,
                   int london_end_hour = 17,
                   int new_york_start_hour = 13,
                   int new_york_end_hour = 22,
                   int tokyo_start_hour = 0,
                   int tokyo_end_hour = 9,
                   double max_slippage_pips = 2.0);
    
    /**
     * @brief Обновление состояния на каждом тике
     * @param current_regime Текущий режим рынка
     */
    void OnTick(E_MarketRegime current_regime);
    
    /**
     * @brief Главная функция проверки разрешения исполнения
     * @param symbol Торговый символ
     * @param direction Направление сделки (1=BUY, -1=SELL)
     * @param current_regime Текущий режим рынка
     * @param reason Причина блокировки (выходной параметр)
     * @return true если исполнение разрешено
     */
    bool IsExecutionAllowed(const string symbol, const int direction, E_MarketRegime current_regime, string &reason);
    
    /**
     * @brief Получение асимметричного стоп-лосса в пипсах
     * @param symbol Торговый символ
     * @param direction Направление сделки (1=BUY, -1=SELL)
     * @param current_regime Текущий режим рынка
     * @return Размер стоп-лосса в пипсах
     */
    double GetAsymmetricStopLossPips(const string symbol, const int direction, E_MarketRegime current_regime);
    
    // --- Публичные методы-заглушки ---
    
    /**
     * @brief Проверка необходимости закрытия позиций (заглушка)
     * @param symbol Торговый символ
     * @return false (заглушка)
     */
    bool IsFlattenRequired(const string symbol) { return false; }
    
    /**
     * @brief Проверка карантина для символа (заглушка)
     * @param symbol Торговый символ
     * @param direction Направление сделки
     * @return false (заглушка)
     */
    bool IsQuarantineActive(const string symbol, const int direction) { return false; }

private:
    // --- Приватные Методы-Проверки ---
    
    /**
     * @brief Проверка новостных событий
     * @param symbol Торговый символ
     * @param reason Причина блокировки (выходной параметр)
     * @return true если новости не блокируют торговлю
     */
    bool IsNewsOK(const string symbol, string &reason);
    
    /**
     * @brief Проверка спреда
     * @param symbol Торговый символ
     * @param current_regime Текущий режим рынка
     * @param reason Причина блокировки (выходной параметр)
     * @return true если спред допустим
     */
    bool IsSpreadOK(const string symbol, E_MarketRegime current_regime, string &reason);
    
    /**
     * @brief Проверка волатильности
     * @param symbol Торговый символ
     * @param reason Причина блокировки (выходной параметр)
     * @return true если волатильность допустима
     */
    bool IsVolatilityOK(const string symbol, string &reason);
    
    /**
     * @brief Проверка торговых сессий
     * @param reason Причина блокировки (выходной параметр)
     * @return true если текущая сессия разрешена
     */
    bool IsSessionOK(string &reason);
    
    /**
     * @brief Проверка проскальзывания
     * @param symbol Торговый символ
     * @param reason Причина блокировки (выходной параметр)
     * @return true если проскальзывание допустимо
     */
    bool IsSlippageOK(const string symbol, string &reason);
    
    // --- Вспомогательные методы ---
    
    /**
     * @brief Загрузка новостей из CSV файла
     * @param filename Имя файла с новостями
     * @return true если загрузка успешна
     */
    bool LoadNewsFromCSV(const string filename);
    
    /**
     * @brief Получение текущего ATR в пипсах
     * @param symbol Торговый символ
     * @param period Период ATR
     * @return ATR в пипсах
     */
    double GetATRInPips(const string symbol, const int period = 14);
    
    /**
     * @brief Получение текущего спреда в пипсах
     * @param symbol Торговый символ
     * @return Спред в пипсах
     */
    double GetSpreadInPips(const string symbol);
    
    /**
     * @brief Проверка родительского контроля (заглушка)
     * @return true (заглушка)
     */
    bool IsParentalLockOK() { return true; }
};

//+------------------------------------------------------------------+
//| Конструктор фильтров исполнения                                  |
//+------------------------------------------------------------------+
CExecGate::CExecGate() {
    m_is_news_guard_enabled = true;
    m_is_spread_guard_enabled = true;
    m_is_volatility_guard_enabled = true;
    m_is_session_guard_enabled = true;
    m_is_slippage_guard_enabled = true;
    
    m_news_block_minutes_before = 30;
    m_news_block_minutes_after = 15;
    m_high_impact_block_minutes = 60;
    m_medium_impact_block_minutes = 30;
    m_low_impact_block_minutes = 15;
    
    m_max_spread_pips = 3.0;
    m_atr_multiplier_for_spread = 2.0;
    
    m_max_volatility_percent = 5.0;
    m_volatility_lookback_periods = 20;
    
    m_is_london_session_enabled = true;
    m_is_new_york_session_enabled = true;
    m_is_tokyo_session_enabled = false;
    m_london_start_hour = 8;
    m_london_end_hour = 17;
    m_new_york_start_hour = 13;
    m_new_york_end_hour = 22;
    m_tokyo_start_hour = 0;
    m_tokyo_end_hour = 9;
    
    m_max_slippage_pips = 2.0;
    
    m_news_events_count = 0;
    m_last_news_update = 0;
    m_h_atr = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Деструктор фильтров исполнения                                   |
//+------------------------------------------------------------------+
CExecGate::~CExecGate() {
    if(m_h_atr != INVALID_HANDLE) {
        IndicatorRelease(m_h_atr);
    }
}

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
void CExecGate::Initialize(bool is_news_guard_enabled = true,
                          bool is_spread_guard_enabled = true,
                          bool is_volatility_guard_enabled = true,
                          bool is_session_guard_enabled = true,
                          bool is_slippage_guard_enabled = true,
                          int news_block_minutes_before = 30,
                          int news_block_minutes_after = 15,
                          int high_impact_block_minutes = 60,
                          int medium_impact_block_minutes = 30,
                          int low_impact_block_minutes = 15,
                          double max_spread_pips = 3.0,
                          double atr_multiplier_for_spread = 2.0,
                          double max_volatility_percent = 5.0,
                          int volatility_lookback_periods = 20,
                          bool is_london_session_enabled = true,
                          bool is_new_york_session_enabled = true,
                          bool is_tokyo_session_enabled = false,
                          int london_start_hour = 8,
                          int london_end_hour = 17,
                          int new_york_start_hour = 13,
                          int new_york_end_hour = 22,
                          int tokyo_start_hour = 0,
                          int tokyo_end_hour = 9,
                          double max_slippage_pips = 2.0) {
    
    m_is_news_guard_enabled = is_news_guard_enabled;
    m_is_spread_guard_enabled = is_spread_guard_enabled;
    m_is_volatility_guard_enabled = is_volatility_guard_enabled;
    m_is_session_guard_enabled = is_session_guard_enabled;
    m_is_slippage_guard_enabled = is_slippage_guard_enabled;
    
    m_news_block_minutes_before = news_block_minutes_before;
    m_news_block_minutes_after = news_block_minutes_after;
    m_high_impact_block_minutes = high_impact_block_minutes;
    m_medium_impact_block_minutes = medium_impact_block_minutes;
    m_low_impact_block_minutes = low_impact_block_minutes;
    
    m_max_spread_pips = max_spread_pips;
    m_atr_multiplier_for_spread = atr_multiplier_for_spread;
    
    m_max_volatility_percent = max_volatility_percent;
    m_volatility_lookback_periods = volatility_lookback_periods;
    
    m_is_london_session_enabled = is_london_session_enabled;
    m_is_new_york_session_enabled = is_new_york_session_enabled;
    m_is_tokyo_session_enabled = is_tokyo_session_enabled;
    m_london_start_hour = london_start_hour;
    m_london_end_hour = london_end_hour;
    m_new_york_start_hour = new_york_start_hour;
    m_new_york_end_hour = new_york_end_hour;
    m_tokyo_start_hour = tokyo_start_hour;
    m_tokyo_end_hour = tokyo_end_hour;
    
    m_max_slippage_pips = max_slippage_pips;
    
    // Инициализируем индикаторы
    m_h_atr = iATR(_Symbol, PERIOD_H1, 14);
    
    // Загружаем новости
    LoadNewsFromCSV("news_calendar.csv");
    
    Print("ExecGate: Initialized with NewsGuard=", m_is_news_guard_enabled, 
          ", SpreadGuard=", m_is_spread_guard_enabled,
          ", VolatilityGuard=", m_is_volatility_guard_enabled);
}

//+------------------------------------------------------------------+
//| Обновление на каждом тике                                        |
//+------------------------------------------------------------------+
void CExecGate::OnTick(E_MarketRegime current_regime) {
    // Обновляем новости каждый час
    datetime current_time = TimeCurrent();
    if(current_time - m_last_news_update > 3600) {
        LoadNewsFromCSV("news_calendar.csv");
        m_last_news_update = current_time;
    }
}

//+------------------------------------------------------------------+
//| Главная функция проверки разрешения исполнения                  |
//+------------------------------------------------------------------+
bool CExecGate::IsExecutionAllowed(const string symbol, const int direction, E_MarketRegime current_regime, string &reason) {
    // 1. Проверка новостей
    if(m_is_news_guard_enabled && !IsNewsOK(symbol, reason)) {
        return false;
    }
    
    // 2. Проверка спреда
    if(m_is_spread_guard_enabled && !IsSpreadOK(symbol, current_regime, reason)) {
        return false;
    }
    
    // 3. Проверка волатильности
    if(m_is_volatility_guard_enabled && !IsVolatilityOK(symbol, reason)) {
        return false;
    }
    
    // 4. Проверка сессий
    if(m_is_session_guard_enabled && !IsSessionOK(reason)) {
        return false;
    }
    
    // 5. Проверка проскальзывания
    if(m_is_slippage_guard_enabled && !IsSlippageOK(symbol, reason)) {
        return false;
    }
    
    return true; // Все проверки пройдены
}

//+------------------------------------------------------------------+
//| Получение асимметричного стоп-лосса                             |
//+------------------------------------------------------------------+
double CExecGate::GetAsymmetricStopLossPips(const string symbol, const int direction, E_MarketRegime current_regime) {
    double atr_pips = GetATRInPips(symbol, 14);
    
    // Асимметричные стоп-лоссы в зависимости от режима
    switch(current_regime) {
        case REGIME_TREND_YOUNG:
        case REGIME_TREND_MATURE:
            return atr_pips * 1.5; // Более широкие стопы в тренде
            
        case REGIME_FLAT_QUIET:
            return atr_pips * 1.0; // Стандартные стопы во флэте
            
        case REGIME_FLAT_CHOPPY:
            return atr_pips * 0.8; // Более узкие стопы в "пиле"
            
        case REGIME_TREND_WEAKENING:
            return atr_pips * 1.2; // Умеренные стопы при ослаблении тренда
            
        default:
            return atr_pips * 1.0; // Стандартные стопы
    }
}

//+------------------------------------------------------------------+
//| Проверка новостных событий                                       |
//+------------------------------------------------------------------+
bool CExecGate::IsNewsOK(const string symbol, string &reason) {
    datetime current_time = TimeCurrent();
    string base_currency = StringSubstr(symbol, 0, 3);
    string quote_currency = StringSubstr(symbol, 3, 3);
    
    for(int i = 0; i < m_news_events_count; i++) {
        NewsEvent &news = m_news_events[i];
        
        // Проверяем, касается ли новость нашего символа
        if(news.currency != base_currency && news.currency != quote_currency) {
            continue;
        }
        
        // Проверяем временной интервал
        datetime block_start = news.start_time - m_news_block_minutes_before * 60;
        datetime block_end = news.end_time + m_news_block_minutes_after * 60;
        
        if(current_time >= block_start && current_time <= block_end) {
            // Дополнительная блокировка в зависимости от воздействия
            int additional_minutes = 0;
            switch(news.impact) {
                case 2: additional_minutes = m_high_impact_block_minutes; break;
                case 1: additional_minutes = m_medium_impact_block_minutes; break;
                case 0: additional_minutes = m_low_impact_block_minutes; break;
            }
            
            block_end += additional_minutes * 60;
            
            if(current_time <= block_end) {
                reason = StringFormat("News block: %s (%s) until %s", 
                                    news.title, news.currency, TimeToString(block_end));
                return false;
            }
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка спреда                                                  |
//+------------------------------------------------------------------+
bool CExecGate::IsSpreadOK(const string symbol, E_MarketRegime current_regime, string &reason) {
    double current_spread = GetSpreadInPips(symbol);
    double max_allowed_spread = m_max_spread_pips;
    
    // Динамический спред на основе ATR
    if(current_regime == REGIME_FLAT_CHOPPY || current_regime == REGIME_UNSTABLE) {
        double atr_pips = GetATRInPips(symbol, 14);
        max_allowed_spread = MathMin(m_max_spread_pips, atr_pips * m_atr_multiplier_for_spread);
    }
    
    if(current_spread > max_allowed_spread) {
        reason = StringFormat("Spread too high: %.1f pips > %.1f pips", current_spread, max_allowed_spread);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка волатильности                                           |
//+------------------------------------------------------------------+
bool CExecGate::IsVolatilityOK(const string symbol, string &reason) {
    double atr_pips = GetATRInPips(symbol, 14);
    double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double volatility_percent = (atr_pips * SymbolInfoDouble(symbol, SYMBOL_POINT) * 100) / current_price;
    
    if(volatility_percent > m_max_volatility_percent) {
        reason = StringFormat("Volatility too high: %.2f%% > %.2f%%", volatility_percent, m_max_volatility_percent);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка торговых сессий                                         |
//+------------------------------------------------------------------+
bool CExecGate::IsSessionOK(string &reason) {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    int current_hour = dt.hour;
    
    bool is_london_active = m_is_london_session_enabled && 
                           (current_hour >= m_london_start_hour && current_hour < m_london_end_hour);
    bool is_new_york_active = m_is_new_york_session_enabled && 
                             (current_hour >= m_new_york_start_hour && current_hour < m_new_york_end_hour);
    bool is_tokyo_active = m_is_tokyo_session_enabled && 
                          (current_hour >= m_tokyo_start_hour && current_hour < m_tokyo_end_hour);
    
    if(!is_london_active && !is_new_york_active && !is_tokyo_active) {
        reason = StringFormat("No active trading session. Current hour: %d", current_hour);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка проскальзывания                                         |
//+------------------------------------------------------------------+
bool CExecGate::IsSlippageOK(const string symbol, string &reason) {
    // Упрощенная проверка - в реальности нужно отслеживать фактические проскальзывания
    double current_spread = GetSpreadInPips(symbol);
    
    if(current_spread > m_max_slippage_pips) {
        reason = StringFormat("Potential slippage too high: spread %.1f pips > max %.1f pips", 
                            current_spread, m_max_slippage_pips);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Загрузка новостей из CSV файла                                   |
//+------------------------------------------------------------------+
bool CExecGate::LoadNewsFromCSV(const string filename) {
    int file_handle = FileOpen(filename, FILE_READ|FILE_CSV);
    if(file_handle == INVALID_HANDLE) {
        Print("ExecGate: Cannot open news file: ", filename);
        return false;
    }
    
    m_news_events_count = 0;
    ArrayResize(m_news_events, 100); // Предварительное выделение памяти
    
    while(!FileIsEnding(file_handle)) {
        string line = FileReadString(file_handle);
        if(StringLen(line) == 0) continue;
        
        // Парсим CSV строку: start_time,end_time,currency,title,impact
        string parts[];
        int parts_count = StringSplit(line, ',', parts);
        if(parts_count < 5) continue;
        
        datetime start_time = StringToTime(parts[0]);
        datetime end_time = StringToTime(parts[1]);
        string currency = parts[2];
        string title = parts[3];
        int impact = (int)StringToInteger(parts[4]);
        
        if(start_time > 0 && end_time > 0) {
            m_news_events[m_news_events_count] = NewsEvent(start_time, end_time, currency, title, impact);
            m_news_events_count++;
        }
    }
    
    FileClose(file_handle);
    Print("ExecGate: Loaded ", m_news_events_count, " news events from ", filename);
    return true;
}

//+------------------------------------------------------------------+
//| Вспомогательные методы                                           |
//+------------------------------------------------------------------+
double CExecGate::GetATRInPips(const string symbol, const int period = 14) {
    if(m_h_atr == INVALID_HANDLE) return 0.0;
    
    double atr_buffer[];
    if(CopyBuffer(m_h_atr, 0, 1, 1, atr_buffer) <= 0) return 0.0;
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    return atr_buffer[0] / point;
}

double CExecGate::GetSpreadInPips(const string symbol) {
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    
    return (ask - bid) / point;
}
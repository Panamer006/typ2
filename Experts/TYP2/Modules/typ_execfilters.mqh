// --- typ_execfilters.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Task: T2-005 :: ExecGate - Execution Filters
#property copyright "TYP2"

#include "typ_regime_engine.mqh" // Подключаем Движок Режимов
#include "../typ_quantiles.mqh"   // Подключаем Квантили
#include <Arrays/ArrayObj.mqh>

// --- Структура для хранения новостных событий ---
struct NewsEvent {
    datetime time;
    string   currency;
    int      importance; // 1-Low, 2-Medium, 3-High
    bool     is_flatten_event; // True для супер-событий
    string   event_name;
    
    NewsEvent() {
        time = 0;
        currency = "";
        importance = 1;
        is_flatten_event = false;
        event_name = "";
    }
};

// --- Класс для управления новостными событиями ---
class CNewsManager : public CObject {
private:
    CArrayObj* m_events;
    
public:
    CNewsManager() {
        m_events = new CArrayObj();
    }
    
    ~CNewsManager() {
        if(m_events != NULL) {
            delete m_events;
        }
    }
    
    void AddEvent(datetime time, string currency, int importance, string event_name) {
        NewsEvent* event = new NewsEvent();
        event.time = time;
        event.currency = currency;
        event.importance = importance;
        event.event_name = event_name;
        
        // Определяем супер-события
        string lower_name = event_name;
        StringToLower(lower_name);
        event.is_flatten_event = (StringFind(lower_name, "rate") >= 0 || 
                                 StringFind(lower_name, "cpi") >= 0 || 
                                 StringFind(lower_name, "fomc") >= 0 ||
                                 StringFind(lower_name, "nfp") >= 0 ||
                                 StringFind(lower_name, "gdp") >= 0);
        
        m_events.Add(event);
    }
    
    void Clear() {
        m_events.Clear();
    }
    
    int Total() {
        return m_events.Total();
    }
    
    NewsEvent* At(int index) {
        return (NewsEvent*)m_events.At(index);
    }
};

class CExecGate {
private:
    // --- ПАРАМЕТРЫ ---
    // NewsGuard
    bool   m_is_news_guard_enabled;
    int    m_news_pre_mins;
    int    m_news_post_mins;
    // SpreadGuard
    double m_spread_atr_multiplier;
    // SL
    double m_sl_atr_multiplier_trend;
    double m_sl_atr_multiplier_flat;
    // Session Time Stop
    int    m_session_end_hour;
    // Volatility Guard
    double m_min_atr_multiplier;
    double m_max_atr_multiplier;
    // Slippage Guard
    double m_max_slippage_pips;
    
    // --- СОСТОЯНИЕ КЛАССА ---
    CNewsManager* m_news_manager; // Менеджер новостей
    int           m_h_atr_m15;    // ATR для M15 (спред)
    int           m_h_atr_h1;     // ATR для H1 (стоп-лосс)

public:
    // --- Публичные Методы ---
    CExecGate();
    ~CExecGate();
    void Initialize(bool is_news_guard_enabled = true,
                   int news_pre_mins = 30,
                   int news_post_mins = 15,
                   double spread_atr_multiplier = 0.5,
                   double sl_atr_multiplier_trend = 2.0,
                   double sl_atr_multiplier_flat = 1.5,
                   int session_end_hour = 16,
                   double min_atr_multiplier = 0.5,
                   double max_atr_multiplier = 3.0,
                   double max_slippage_pips = 3.0);
    void OnTick();

    // --- ГЛАВНАЯ ФУНКЦИЯ-ГВАРД ---
    bool IsExecutionAllowed(const string symbol, int direction, string signal_bucket, string &reason);
    
    // --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
    double GetAsymmetricStopLossPips(const string symbol, E_MarketRegime current_regime);
    bool IsFlattenRequired(const string symbol);
    bool IsQuarantineActive(const string symbol, int direction);

private:
    // --- Приватные Методы-Проверки ---
    void LoadNewsFromCSV(const string filename);
    bool IsNewsOK(const string symbol, string &reason);
    bool IsSpreadOK(const string symbol, string &reason);
    bool IsVolatilityOK(const string symbol, string &reason);
    bool IsSessionTimeOK(string signal_bucket, string &reason);
    
    /**
     * @brief Проверка родительского контроля (заглушка)
     * @param reason Причина блокировки (выходной параметр)
     * @return true если торговля разрешена
     * 
     * TODO: Implement full ParentalLock logic using OnTradeTransaction event.
     * This should include checks for trading hours restrictions, maximum daily trades,
     * account balance limits, and other protective measures.
     */
    bool IsParentalLockOK(string &reason);
    
    // Вспомогательные методы
    double GetATRValue(int handle);
    string ExtractBaseCurrency(const string symbol);
    string ExtractQuoteCurrency(const string symbol);
    double GetSpreadInPips(const string symbol);
    int GetCurrentHour();
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CExecGate::CExecGate() {
    m_is_news_guard_enabled = true;
    m_news_pre_mins = 30;
    m_news_post_mins = 15;
    m_spread_atr_multiplier = 0.5;
    m_sl_atr_multiplier_trend = 2.0;
    m_sl_atr_multiplier_flat = 1.5;
    m_session_end_hour = 16;
    m_min_atr_multiplier = 0.5;
    m_max_atr_multiplier = 3.0;
    m_max_slippage_pips = 3.0;
    
    m_news_manager = new CNewsManager();
    m_h_atr_m15 = INVALID_HANDLE;
    m_h_atr_h1 = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CExecGate::~CExecGate() {
    if(m_news_manager != NULL) {
        delete m_news_manager;
    }
    
    if(m_h_atr_m15 != INVALID_HANDLE) {
        IndicatorRelease(m_h_atr_m15);
    }
    
    if(m_h_atr_h1 != INVALID_HANDLE) {
        IndicatorRelease(m_h_atr_h1);
    }
}

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
void CExecGate::Initialize(bool is_news_guard_enabled = true,
                          int news_pre_mins = 30,
                          int news_post_mins = 15,
                          double spread_atr_multiplier = 0.5,
                          double sl_atr_multiplier_trend = 2.0,
                          double sl_atr_multiplier_flat = 1.5,
                          int session_end_hour = 16,
                          double min_atr_multiplier = 0.5,
                          double max_atr_multiplier = 3.0,
                          double max_slippage_pips = 3.0) {
    
    m_is_news_guard_enabled = is_news_guard_enabled;
    m_news_pre_mins = news_pre_mins;
    m_news_post_mins = news_post_mins;
    m_spread_atr_multiplier = spread_atr_multiplier;
    m_sl_atr_multiplier_trend = sl_atr_multiplier_trend;
    m_sl_atr_multiplier_flat = sl_atr_multiplier_flat;
    m_session_end_hour = session_end_hour;
    m_min_atr_multiplier = min_atr_multiplier;
    m_max_atr_multiplier = max_atr_multiplier;
    m_max_slippage_pips = max_slippage_pips;
    
    // Создаем хэндлы ATR
    m_h_atr_m15 = iATR(_Symbol, PERIOD_M15, 14);
    m_h_atr_h1 = iATR(_Symbol, PERIOD_H1, 14);
    
    if(m_h_atr_m15 == INVALID_HANDLE) {
        Print("ExecGate ERROR: Failed to create ATR M15 handle");
    }
    
    if(m_h_atr_h1 == INVALID_HANDLE) {
        Print("ExecGate ERROR: Failed to create ATR H1 handle");
    }
    
    // Загружаем новости
    LoadNewsFromCSV("news_calendar.csv");
    
    Print("ExecGate: Initialized with news guard = ", m_is_news_guard_enabled);
}

//+------------------------------------------------------------------+
//| Обновление на каждом тике                                        |
//+------------------------------------------------------------------+
void CExecGate::OnTick() {
    // Здесь можно добавить периодические проверки, например, обновление новостей
}

//+------------------------------------------------------------------+
//| Главная функция проверки возможности исполнения                   |
//+------------------------------------------------------------------+
/**
 * @brief Главная функция проверки возможности исполнения сделки
 * @param symbol Торговый символ
 * @param direction Направление сделки
 * @param signal_bucket Категория сигнала
 * @param reason Причина блокировки (выходной параметр)
 * @return true если исполнение разрешено
 */
bool CExecGate::IsExecutionAllowed(const string symbol, int direction, string signal_bucket, string &reason) {
    // Последовательно вызываем все проверки
    
    // 1. Проверка родительского контроля
    if(!IsParentalLockOK(reason)) {
        return false;
    }
    
    // 2. Проверка новостей
    if(!IsNewsOK(symbol, reason)) {
        return false;
    }
    
    // 3. Проверка спреда
    if(!IsSpreadOK(symbol, reason)) {
        return false;
    }
    
    // 4. Проверка волатильности
    if(!IsVolatilityOK(symbol, reason)) {
        return false;
    }
    
    // 5. Проверка времени сессии
    if(!IsSessionTimeOK(signal_bucket, reason)) {
        return false;
    }
    
    reason = "All execution filters passed";
    return true;
}

//+------------------------------------------------------------------+
//| Расчет асимметричного стоп-лосса                                  |
//+------------------------------------------------------------------+
double CExecGate::GetAsymmetricStopLossPips(const string symbol, E_MarketRegime current_regime) {
    double atr_value = GetATRValue(m_h_atr_h1);
    if(atr_value <= 0) return 50.0; // Значение по умолчанию
    
    // Конвертируем ATR в пипсы
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pip_size = (digits == 3 || digits == 5) ? point * 10.0 : point;
    double atr_pips = atr_value / pip_size;
    
    // Выбираем множитель в зависимости от режима
    double multiplier = 2.0; // По умолчанию
    
    switch(current_regime) {
        case REGIME_TREND_YOUNG:
        case REGIME_TREND_MATURE:
            multiplier = m_sl_atr_multiplier_trend;
            break;
            
        case REGIME_TREND_WEAKENING:
            multiplier = m_sl_atr_multiplier_trend * 0.8; // Меньший стоп при ослабевающем тренде
            break;
            
        case REGIME_FLAT_QUIET:
        case REGIME_FLAT_CHOPPY:
            multiplier = m_sl_atr_multiplier_flat;
            break;
            
        case REGIME_UNSTABLE:
            multiplier = m_sl_atr_multiplier_flat * 0.7; // Очень тайтовый стоп в нестабильности
            break;
            
        case REGIME_RISK_OFF:
            multiplier = m_sl_atr_multiplier_trend * 1.5; // Широкий стоп в панике
            break;
            
        default:
            multiplier = 2.0;
            break;
    }
    
    double sl_pips = atr_pips * multiplier;
    
    // Ограничиваем разумными пределами
    sl_pips = MathMax(10.0, MathMin(200.0, sl_pips));
    
    return sl_pips;
}

//+------------------------------------------------------------------+
//| Проверка необходимости закрытия позиций                          |
//+------------------------------------------------------------------+
bool CExecGate::IsFlattenRequired(const string symbol) {
    if(!m_is_news_guard_enabled) return false;
    
    string base_currency = ExtractBaseCurrency(symbol);
    string quote_currency = ExtractQuoteCurrency(symbol);
    
    datetime current_time = TimeCurrent();
    
    for(int i = 0; i < m_news_manager.Total(); i++) {
        NewsEvent* event = m_news_manager.At(i);
        if(event == NULL) continue;
        
        // Проверяем только супер-события
        if(!event.is_flatten_event) continue;
        
        // Проверяем валюты
        if(event.currency != base_currency && event.currency != quote_currency) continue;
        
        // Проверяем время - за 15 минут до события
        if(current_time >= event.time - 15*60 && current_time <= event.time + 5*60) {
            Print("ExecGate: Flatten required for ", symbol, " due to ", event.event_name);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Проверка пост-новостного карантина                               |
//+------------------------------------------------------------------+
bool CExecGate::IsQuarantineActive(const string symbol, int direction) {
    if(!m_is_news_guard_enabled) return false;
    
    string base_currency = ExtractBaseCurrency(symbol);
    string quote_currency = ExtractQuoteCurrency(symbol);
    
    datetime current_time = TimeCurrent();
    
    for(int i = 0; i < m_news_manager.Total(); i++) {
        NewsEvent* event = m_news_manager.At(i);
        if(event == NULL) continue;
        
        // Проверяем валюты
        if(event.currency != base_currency && event.currency != quote_currency) continue;
        
        // Проверяем время - карантин на 30 минут после важных событий
        if(event.importance >= 2 && 
           current_time >= event.time && 
           current_time <= event.time + 30*60) {
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Загрузка новостей из CSV файла                                   |
//+------------------------------------------------------------------+
void CExecGate::LoadNewsFromCSV(const string filename) {
    m_news_manager.Clear();
    
    int handle = FileOpen(filename, FILE_READ|FILE_CSV|FILE_ANSI, ',');
    if(handle == INVALID_HANDLE) {
        Print("ExecGate: News file ", filename, " not found in MQL5/Files/");
        return;
    }
    
    // Пропускаем заголовок
    if(!FileIsEnding(handle)) {
        string header = FileReadString(handle);
    }
    
    int events_loaded = 0;
    while(!FileIsEnding(handle)) {
        string date_str = FileReadString(handle);
        if(date_str == "") break;
        
        string currency = FileReadString(handle);
        string importance_str = FileReadString(handle);
        string event_name = FileReadString(handle);
        
        // Парсим дату и время
        datetime event_time = StringToTime(date_str);
        if(event_time == 0) continue;
        
        int importance = (int)StringToInteger(importance_str);
        if(importance < 1) importance = 1;
        if(importance > 3) importance = 3;
        
        m_news_manager.AddEvent(event_time, currency, importance, event_name);
        events_loaded++;
    }
    
    FileClose(handle);
    Print("ExecGate: Loaded ", events_loaded, " news events from ", filename);
}

//+------------------------------------------------------------------+
//| Проверка новостей                                                |
//+------------------------------------------------------------------+
bool CExecGate::IsNewsOK(const string symbol, string &reason) {
    if(!m_is_news_guard_enabled) return true;
    
    string base_currency = ExtractBaseCurrency(symbol);
    string quote_currency = ExtractQuoteCurrency(symbol);
    
    datetime current_time = TimeCurrent();
    
    for(int i = 0; i < m_news_manager.Total(); i++) {
        NewsEvent* event = m_news_manager.At(i);
        if(event == NULL) continue;
        
        // Проверяем валюты
        if(event.currency != base_currency && event.currency != quote_currency) continue;
        
        // Проверяем временной интервал
        datetime start_time = event.time - m_news_pre_mins * 60;
        datetime end_time = event.time + m_news_post_mins * 60;
        
        if(current_time >= start_time && current_time <= end_time) {
            reason = StringFormat("News guard: %s %s in %d minutes", 
                                event.currency, event.event_name, 
                                (int)((event.time - current_time) / 60));
            return false;
        }
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка спреда                                                  |
//+------------------------------------------------------------------+
bool CExecGate::IsSpreadOK(const string symbol, string &reason) {
    double current_spread_pips = GetSpreadInPips(symbol);
    double atr_value = GetATRValue(m_h_atr_m15);
    
    if(atr_value <= 0) {
        // Если нет ATR, используем фиксированный лимит
        if(current_spread_pips > 5.0) {
            reason = StringFormat("Spread too high: %.1f pips > 5.0 pips (no ATR)", current_spread_pips);
            return false;
        }
        return true;
    }
    
    // Конвертируем ATR в пипсы
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pip_size = (digits == 3 || digits == 5) ? point * 10.0 : point;
    double atr_pips = atr_value / pip_size;
    
    double allowed_spread = atr_pips * m_spread_atr_multiplier;
    
    if(current_spread_pips > allowed_spread) {
        reason = StringFormat("Spread too high: %.1f pips > %.1f pips (%.1f * %.2f ATR)", 
                            current_spread_pips, allowed_spread, atr_pips, m_spread_atr_multiplier);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка волатильности                                           |
//+------------------------------------------------------------------+
bool CExecGate::IsVolatilityOK(const string symbol, string &reason) {
    double atr_value = GetATRValue(m_h_atr_h1);
    if(atr_value <= 0) return true; // Если нет данных, разрешаем
    
    // Конвертируем ATR в пипсы
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pip_size = (digits == 3 || digits == 5) ? point * 10.0 : point;
    double atr_pips = atr_value / pip_size;
    
    // Проверяем минимальную волатильность
    if(atr_pips < 20.0 * m_min_atr_multiplier) {
        reason = StringFormat("Volatility too low: ATR %.1f pips < %.1f pips", 
                            atr_pips, 20.0 * m_min_atr_multiplier);
        return false;
    }
    
    // Проверяем максимальную волатильность
    if(atr_pips > 100.0 * m_max_atr_multiplier) {
        reason = StringFormat("Volatility too high: ATR %.1f pips > %.1f pips", 
                            atr_pips, 100.0 * m_max_atr_multiplier);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка времени сессии                                          |
//+------------------------------------------------------------------+
bool CExecGate::IsSessionTimeOK(string signal_bucket, string &reason) {
    // Проверяем только для сессионных стратегий
    if(StringFind(signal_bucket, "Session") == -1 && 
       StringFind(signal_bucket, "EU_") == -1 && 
       StringFind(signal_bucket, "US_") == -1 && 
       StringFind(signal_bucket, "ASIA_") == -1) {
        return true; // Не сессионная стратегия
    }
    
    int current_hour = GetCurrentHour();
    
    if(current_hour >= m_session_end_hour) {
        reason = StringFormat("Session ended: %02d:00 >= %02d:00", current_hour, m_session_end_hour);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Вспомогательные методы                                           |
//+------------------------------------------------------------------+
double CExecGate::GetATRValue(int handle) {
    if(handle == INVALID_HANDLE) return 0.0;
    
    double buffer[];
    if(CopyBuffer(handle, 0, 1, 1, buffer) <= 0) {
        return 0.0;
    }
    return buffer[0];
}

string CExecGate::ExtractBaseCurrency(const string symbol) {
    if(StringLen(symbol) >= 3) {
        return StringSubstr(symbol, 0, 3);
    }
    return "";
}

string CExecGate::ExtractQuoteCurrency(const string symbol) {
    if(StringLen(symbol) >= 6) {
        return StringSubstr(symbol, 3, 3);
    }
    return "";
}

double CExecGate::GetSpreadInPips(const string symbol) {
    long spread_points = SymbolInfoInteger(symbol, SYMBOL_SPREAD);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pip_size = (digits == 3 || digits == 5) ? point * 10.0 : point;
    
    return (double)spread_points * point / pip_size;
}

int CExecGate::GetCurrentHour() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    return dt.hour;
}

//+------------------------------------------------------------------+
//| Проверка родительского контроля (заглушка)                       |
//+------------------------------------------------------------------+
/**
 * @brief Проверка ограничений родительского контроля
 * @param reason Причина блокировки (выходной параметр)
 * @return true если торговля разрешена
 */
bool CExecGate::IsParentalLockOK(string &reason) {
    // TODO: Implement full ParentalLock logic using OnTradeTransaction event
    // Possible features to implement:
    // - Trading hours restrictions (e.g., only 9:00-17:00)
    // - Maximum daily trades limit
    // - Maximum daily loss limit
    // - Account balance protection
    // - Instrument restrictions (e.g., only major pairs)
    // - Leverage limitations
    
    // Заглушка - всегда разрешаем торговлю
    return true;
}

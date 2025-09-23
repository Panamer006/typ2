// --- typ_risk.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Task: T2-RISK :: Portfolio Risk Manager
#property copyright "TYP2"

#include "typ_regime_engine.mqh" // Подключаем Движок Режимов
#include <Arrays/ArrayObj.mqh>

// --- Класс для отслеживания состояния по каждому символу ---
class CSymbolState : public CObject {
public:
    string   symbol;
    datetime last_close_time; // Для Cooldown
    double   last_close_profit; // Для адаптивного Cooldown
    int      sl_cluster_count; // Для защиты от частых стопов
    datetime sl_cluster_start_time;
    
    /**
     * @brief Конструктор по умолчанию
     */
    CSymbolState() {
        symbol = "";
        last_close_time = 0;
        last_close_profit = 0.0;
        sl_cluster_count = 0;
        sl_cluster_start_time = 0;
    }
    
    /**
     * @brief Конструктор с символом
     * @param sym Торговый символ
     */
    CSymbolState(string sym) {
        symbol = sym;
        last_close_time = 0;
        last_close_profit = 0.0;
        sl_cluster_count = 0;
        sl_cluster_start_time = 0;
    }
    
    /**
     * @brief Деструктор
     */
    ~CSymbolState() {
        // Освобождение ресурсов если необходимо
    }
};

/**
 * @brief Менеджер состояний символов для Risk Manager
 * 
 * TODO: Optimize symbol state storage using a hash map for O(1) access
 * instead of current O(n) linear search. Consider using CHashMap if available
 * or implement custom hash table for "symbol" -> "CSymbolState*" mapping.
 */
class CSymbolStateManager : public CObject {
private:
    CArrayObj* m_states; // Временное решение с линейным поиском O(n)
    
public:
    /**
     * @brief Конструктор менеджера состояний символов
     */
    CSymbolStateManager() {
        m_states = new CArrayObj();
    }
    
    /**
     * @brief Деструктор - освобождает память массива состояний
     */
    ~CSymbolStateManager() {
        if(m_states != NULL) {
            delete m_states;
        }
    }
    
    /**
     * @brief Получение состояния символа (создает новое если не найдено)
     * @param symbol Торговый символ
     * @return Указатель на состояние символа
     */
    CSymbolState* GetState(const string symbol) {
        for(int i = 0; i < m_states.Total(); i++) {
            CSymbolState* state = (CSymbolState*)m_states.At(i);
            if(state != NULL && state.symbol == symbol) {
                return state;
            }
        }
        
        // Создаем новое состояние если не найдено
        CSymbolState* newState = new CSymbolState(symbol);
        m_states.Add(newState);
        return newState;
    }
};

/**
 * @brief Центральная система управления рисками портфеля
 * 
 * Обеспечивает многоуровневую защиту капитала через контроль дневной просадки,
 * ограничения экспозиции, кулдауны между сделками и защиту от кластеров стопов.
 */
class CRiskManager {
private:
    // --- ПАРАМЕТРЫ ---
    double m_max_daily_dd_percent;
    bool   m_is_gradual_dd_reduction_enabled;
    int    m_max_positions_per_currency;
    int    m_max_total_open_orders;
    double m_max_total_open_lots;
    double m_max_total_risk_percent;
    int    m_cooldown_seconds_win;
    int    m_cooldown_seconds_loss;
    int    m_sl_cluster_limit;
    int    m_sl_cluster_timespan_hours;
    bool   m_is_eow_protocol_enabled;
    ENUM_DAY_OF_WEEK m_eow_day;
    int    m_eow_hour;
    bool   m_is_recovery_protocol_enabled;

    // --- СОСТОЯНИЕ КЛАССА ---
    double   m_equity_on_day_start;
    datetime m_current_day_start_time;
    bool     m_is_trading_blocked_by_dd;
    double   m_loss_for_recovery;
    CArrayObj* m_symbol_states_map; 

public:
    // --- Публичные Методы ---
    
    /**
     * @brief Конструктор менеджера рисков
     */
    CRiskManager();
    
    /**
     * @brief Деструктор - освобождает ресурсы
     */
    ~CRiskManager();
    
    /**
     * @brief Инициализация системы управления рисками
     * @param max_daily_dd_percent Максимальная дневная просадка в %
     * @param is_gradual_dd_reduction_enabled Включить пошаговое снижение риска
     * @param max_positions_per_currency Максимум позиций на валюту
     * @param max_total_open_orders Максимум открытых ордеров
     * @param max_total_open_lots Максимум открытых лотов
     * @param max_total_risk_percent Максимальный суммарный риск в %
     * @param cooldown_seconds_win Кулдаун после прибыльной сделки (сек)
     * @param cooldown_seconds_loss Кулдаун после убыточной сделки (сек)
     * @param sl_cluster_limit Лимит кластера стоп-лоссов
     * @param sl_cluster_timespan_hours Период кластера в часах
     * @param is_eow_protocol_enabled Включить протокол конца недели
     * @param eow_day День недели для остановки торговли
     * @param eow_hour Час остановки торговли
     * @param is_recovery_protocol_enabled Включить протокол восстановления
     */
    void Initialize(double max_daily_dd_percent = 2.0,
                   bool is_gradual_dd_reduction_enabled = true,
                   int max_positions_per_currency = 3,
                   int max_total_open_orders = 10,
                   double max_total_open_lots = 5.0,
                   double max_total_risk_percent = 10.0,
                   int cooldown_seconds_win = 300,
                   int cooldown_seconds_loss = 600,
                   int sl_cluster_limit = 3,
                   int sl_cluster_timespan_hours = 4,
                   bool is_eow_protocol_enabled = true,
                   DayOfWeek eow_day = FRIDAY,
                   int eow_hour = 15,
                   bool is_recovery_protocol_enabled = true);
    
    /**
     * @brief Обновление состояния на каждом тике
     * @param current_regime Текущий режим рынка
     */
    void OnTick(E_MarketRegime current_regime);
    
    /**
     * @brief Уведомление о закрытии сделки
     * @param symbol Символ закрытой позиции
     * @param profit Прибыль/убыток по сделке
     */
    void OnTradeClose(const string symbol, const double profit);

    // --- ФУНКЦИИ-ГВАРДЫ (для вызова перед отправкой ордера) ---
    
    /**
     * @brief Получение модификатора риска с проверкой всех ограничений
     * @param symbol Торговый символ
     * @param risk_percent Запрашиваемый риск в %
     * @param reason Причина модификации/блокировки (выходной параметр)
     * @return Модификатор риска (0.0-1.0), где 0.0 = блокировка
     */
    double GetRiskModifier(const string symbol, const double risk_percent, string &reason);

    // --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
    
    /**
     * @brief Расчет размера лота по заданному риску
     * @param balance Баланс счета
     * @param risk_percent Риск в процентах
     * @param sl_pips Размер стоп-лосса в пипсах
     * @return Рассчитанный размер лота
     */
    double CalculateLotSize(const double balance, const double risk_percent, const double sl_pips);

private:
    // --- Приватные Методы-Проверки ---
    
    /**
     * @brief Проверка дневной просадки и расчет модификатора риска
     * @param reason Причина модификации (выходной параметр)
     * @return Модификатор риска (0.0-1.0)
     */
    double GetDailyDDRiskModifier(string &reason);
    
    /**
     * @brief Проверка ограничений экспозиции по валютам
     * @param symbol Торговый символ
     * @param reason Причина блокировки (выходной параметр)
     * @return true если экспозиция допустима
     */
    bool IsCurrencyExposureOK(const string symbol, string &reason);
    
    /**
     * @brief Проверка общих ограничений экспозиции
     * @param new_trade_risk_percent Риск новой сделки в %
     * @param new_trade_lot Размер лота новой сделки
     * @param reason Причина блокировки (выходной параметр)
     * @return true если общая экспозиция допустима
     */
    bool IsTotalExposureOK(const double new_trade_risk_percent, double new_trade_lot, string &reason);
    
    /**
     * @brief Проверка кулдауна между сделками
     * @param symbol Торговый символ
     * @param reason Причина блокировки (выходной параметр)
     * @return true если кулдаун прошел
     */
    bool IsCooldownOK(const string symbol, string &reason);
    
    /**
     * @brief Проверка кластера стоп-лоссов
     * @param symbol Торговый символ
     * @param reason Причина блокировки (выходной параметр)
     * @return true если кластер не превышен
     */
    bool IsStopLossClusterOK(const string symbol, string &reason);
    
    /**
     * @brief Проверка протокола конца недели
     * @param reason Причина блокировки (выходной параметр)
     * @return true если торговля разрешена
     */
    bool IsEOWProtocolActive(string &reason);
    
    // --- Вспомогательные методы ---
    
    /**
     * @brief Извлечение базовой валюты из символа
     * @param symbol Торговый символ (например, EURUSD)
     * @return Базовая валюта (например, EUR)
     */
    string ExtractBaseCurrency(const string symbol);
    
    /**
     * @brief Извлечение котируемой валюты из символа
     * @param symbol Торговый символ (например, EURUSD)
     * @return Котируемая валюта (например, USD)
     */
    string ExtractQuoteCurrency(const string symbol);
    
    /**
     * @brief Расчет общего объема открытых позиций
     * @return Суммарный объем в лотах
     */
    double CalculateTotalOpenLots();
    
    /**
     * @brief Расчет общего риска портфеля
     * @return Суммарный риск в процентах
     */
    double CalculateTotalRiskPercent();
    
    /**
     * @brief Подсчет позиций по указанной валюте
     * @param currency Валюта для подсчета
     * @return Количество позиций
     */
    int CountPositionsByCurrency(const string currency);
    
    /**
     * @brief Получение состояния символа (создает новое если не найдено)
     * @param symbol Торговый символ
     * @return Указатель на состояние символа
     */
    CSymbolState* GetSymbolState(const string symbol);
};

//+------------------------------------------------------------------+
//| Конструктор менеджера рисков                                      |
//+------------------------------------------------------------------+
/**
 * @brief Конструктор с инициализацией значений по умолчанию
 */
CRiskManager::CRiskManager() {
    m_max_daily_dd_percent = 2.0;
    m_is_gradual_dd_reduction_enabled = true;
    m_max_positions_per_currency = 3;
    m_max_total_open_orders = 10;
    m_max_total_open_lots = 5.0;
    m_max_total_risk_percent = 10.0;
    m_cooldown_seconds_win = 300;
    m_cooldown_seconds_loss = 600;
    m_sl_cluster_limit = 3;
    m_sl_cluster_timespan_hours = 4;
    m_is_eow_protocol_enabled = true;
    m_eow_day = FRIDAY;
    m_eow_hour = 15;
    m_is_recovery_protocol_enabled = true;
    
    m_equity_on_day_start = AccountInfoDouble(ACCOUNT_EQUITY);
    m_current_day_start_time = 0;
    m_is_trading_blocked_by_dd = false;
    m_loss_for_recovery = 0.0;
    
    m_symbol_states_map = new CArrayObj();
}

//+------------------------------------------------------------------+
//| Деструктор менеджера рисков                                       |
//+------------------------------------------------------------------+
/**
 * @brief Деструктор - освобождает динамически выделенную память
 */
CRiskManager::~CRiskManager() {
    if(m_symbol_states_map != NULL) {
        delete m_symbol_states_map;
    }
}

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
void CRiskManager::Initialize(double max_daily_dd_percent = 2.0,
                             bool is_gradual_dd_reduction_enabled = true,
                             int max_positions_per_currency = 3,
                             int max_total_open_orders = 10,
                             double max_total_open_lots = 5.0,
                             double max_total_risk_percent = 10.0,
                             int cooldown_seconds_win = 300,
                             int cooldown_seconds_loss = 600,
                             int sl_cluster_limit = 3,
                             int sl_cluster_timespan_hours = 4,
                             bool is_eow_protocol_enabled = true,
                             DayOfWeek eow_day = FRIDAY,
                             int eow_hour = 15,
                             bool is_recovery_protocol_enabled = true) {
    
    m_max_daily_dd_percent = max_daily_dd_percent;
    m_is_gradual_dd_reduction_enabled = is_gradual_dd_reduction_enabled;
    m_max_positions_per_currency = max_positions_per_currency;
    m_max_total_open_orders = max_total_open_orders;
    m_max_total_open_lots = max_total_open_lots;
    m_max_total_risk_percent = max_total_risk_percent;
    m_cooldown_seconds_win = cooldown_seconds_win;
    m_cooldown_seconds_loss = cooldown_seconds_loss;
    m_sl_cluster_limit = sl_cluster_limit;
    m_sl_cluster_timespan_hours = sl_cluster_timespan_hours;
    m_is_eow_protocol_enabled = is_eow_protocol_enabled;
    m_eow_day = eow_day;
    m_eow_hour = eow_hour;
    m_is_recovery_protocol_enabled = is_recovery_protocol_enabled;
    
    // Инициализируем дневную equity
    m_equity_on_day_start = AccountInfoDouble(ACCOUNT_EQUITY);
    m_current_day_start_time = iTime(_Symbol, PERIOD_D1, 0);
    
    Print("Risk Manager: Initialized with DD limit = ", m_max_daily_dd_percent, "%");
}

//+------------------------------------------------------------------+
//| Обновление на каждом тике                                        |
//+------------------------------------------------------------------+
void CRiskManager::OnTick(E_MarketRegime current_regime) {
    // Проверяем, начался ли новый день
    datetime current_day_time = iTime(_Symbol, PERIOD_D1, 0);
    if(current_day_time > m_current_day_start_time) {
        // Новый день - сбрасываем состояние
        m_current_day_start_time = current_day_time;
        m_equity_on_day_start = AccountInfoDouble(ACCOUNT_EQUITY);
        m_is_trading_blocked_by_dd = false;
        m_loss_for_recovery = 0.0;
        
        Print("Risk Manager: New day started. Equity reset to: ", m_equity_on_day_start);
    }
}

//+------------------------------------------------------------------+
//| Уведомление о закрытии сделки                                     |
//+------------------------------------------------------------------+
void CRiskManager::OnTradeClose(const string symbol, const double profit) {
    CSymbolState* state = GetSymbolState(symbol);
    if(state == NULL) return;
    
    state.last_close_time = TimeCurrent();
    state.last_close_profit = profit;
    
    // Если убыточная сделка - обновляем кластер стопов
    if(profit < 0) {
        // Проверяем, нужно ли начать новый кластер
        if(TimeCurrent() - state.sl_cluster_start_time > m_sl_cluster_timespan_hours * 3600) {
            state.sl_cluster_count = 1;
            state.sl_cluster_start_time = TimeCurrent();
        } else {
            state.sl_cluster_count++;
        }
        
        Print("Risk Manager: Loss registered for ", symbol, 
              ". Cluster count: ", state.sl_cluster_count, 
              ", Profit: ", profit);
    }
}

//+------------------------------------------------------------------+
//| Главная функция проверки рисков                                  |
//+------------------------------------------------------------------+
double CRiskManager::GetRiskModifier(const string symbol, const double risk_percent, string &reason) {
    // 1. Проверка дневной просадки (высший приоритет)
    double dd_modifier = GetDailyDDRiskModifier(reason);
    if(dd_modifier <= 0.0) {
        return 0.0; // Полная блокировка
    }
    if(dd_modifier < 1.0) {
        return dd_modifier; // Частичное снижение риска
    }
    
    // 2. Проверка EOW протокола
    if(!IsEOWProtocolActive(reason)) {
        return 0.0;
    }
    
    // 3. Проверка экспозиции по валютам
    if(!IsCurrencyExposureOK(symbol, reason)) {
        return 0.0;
    }
    
    // 4. Проверка общей экспозиции
    double lot_size = CalculateLotSize(AccountInfoDouble(ACCOUNT_EQUITY), risk_percent, 100); // Примерный расчет лота
    if(!IsTotalExposureOK(risk_percent, lot_size, reason)) {
        return 0.0;
    }
    
    // 5. Проверка кулдауна
    if(!IsCooldownOK(symbol, reason)) {
        return 0.0;
    }
    
    // 6. Проверка кластера стопов
    if(!IsStopLossClusterOK(symbol, reason)) {
        return 0.0;
    }
    
    return 1.0; // Все проверки пройдены
}

//+------------------------------------------------------------------+
//| Проверка дневной просадки                                        |
//+------------------------------------------------------------------+
double CRiskManager::GetDailyDDRiskModifier(string &reason) {
    double current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    
    if(m_equity_on_day_start <= 0) {
        reason = "Invalid day start equity";
        return 0.0;
    }
    
    double dd_percent = (m_equity_on_day_start - current_equity) / m_equity_on_day_start * 100.0;
    
    // Полная блокировка при превышении лимита
    if(dd_percent >= m_max_daily_dd_percent) {
        if(!m_is_trading_blocked_by_dd) {
            m_is_trading_blocked_by_dd = true;
            m_loss_for_recovery = m_equity_on_day_start - current_equity;
            Print("Risk Manager: DAILY DD LIMIT REACHED! DD: ", dd_percent, "%, Limit: ", m_max_daily_dd_percent, "%");
        }
        reason = StringFormat("Daily DD limit reached: %.2f%% >= %.2f%%", dd_percent, m_max_daily_dd_percent);
        return 0.0;
    }
    
    // Проверка протокола восстановления
    if(m_is_recovery_protocol_enabled && m_loss_for_recovery > 0) {
        double recovery_threshold = m_equity_on_day_start - (m_loss_for_recovery / 2.0);
        if(current_equity < recovery_threshold) {
            reason = StringFormat("Recovery protocol active. Need equity > %.2f", recovery_threshold);
            return 0.5; // Половинный риск
        } else {
            m_loss_for_recovery = 0.0; // Сбрасываем после восстановления
        }
    }
    
    // Пошаговое снижение риска
    if(m_is_gradual_dd_reduction_enabled) {
        double warning_threshold = m_max_daily_dd_percent * 0.5; // 50% от лимита
        if(dd_percent >= warning_threshold) {
            reason = StringFormat("Gradual risk reduction. DD: %.2f%%, Warning: %.2f%%", dd_percent, warning_threshold);
            return 0.5; // Половинный риск
        }
    }
    
    return 1.0; // Полный риск разрешен
}

//+------------------------------------------------------------------+
//| Проверка экспозиции по валютам                                   |
//+------------------------------------------------------------------+
bool CRiskManager::IsCurrencyExposureOK(const string symbol, string &reason) {
    string base_currency = ExtractBaseCurrency(symbol);
    string quote_currency = ExtractQuoteCurrency(symbol);
    
    // Проверяем базовую валюту
    int base_positions = CountPositionsByCurrency(base_currency);
    if(base_positions >= m_max_positions_per_currency) {
        reason = StringFormat("Base currency %s exposure limit: %d >= %d", 
                            base_currency, base_positions, m_max_positions_per_currency);
        return false;
    }
    
    // Проверяем котируемую валюту
    int quote_positions = CountPositionsByCurrency(quote_currency);
    if(quote_positions >= m_max_positions_per_currency) {
        reason = StringFormat("Quote currency %s exposure limit: %d >= %d", 
                            quote_currency, quote_positions, m_max_positions_per_currency);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка общей экспозиции                                        |
//+------------------------------------------------------------------+
bool CRiskManager::IsTotalExposureOK(const double new_trade_risk_percent, double new_trade_lot, string &reason) {
    // 1. Проверка по количеству ордеров
    int current_positions = PositionsTotal();
    if(current_positions >= m_max_total_open_orders) {
        reason = StringFormat("Max positions limit: %d >= %d", current_positions, m_max_total_open_orders);
        return false;
    }
    
    // 2. Проверка по суммарному лоту
    double total_lots = CalculateTotalOpenLots();
    if(total_lots + new_trade_lot > m_max_total_open_lots) {
        reason = StringFormat("Max lots limit: %.2f + %.2f > %.2f", 
                            total_lots, new_trade_lot, m_max_total_open_lots);
        return false;
    }
    
    // 3. Проверка по суммарному риску
    double total_risk = CalculateTotalRiskPercent();
    if(total_risk + new_trade_risk_percent > m_max_total_risk_percent) {
        reason = StringFormat("Max risk limit: %.2f%% + %.2f%% > %.2f%%", 
                            total_risk, new_trade_risk_percent, m_max_total_risk_percent);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка кулдауна                                                |
//+------------------------------------------------------------------+
bool CRiskManager::IsCooldownOK(const string symbol, string &reason) {
    CSymbolState* state = GetSymbolState(symbol);
    if(state == NULL) return true;
    
    if(state.last_close_time == 0) return true; // Никогда не торговали этим символом
    
    int elapsed_seconds = (int)(TimeCurrent() - state.last_close_time);
    int required_cooldown = (state.last_close_profit >= 0) ? m_cooldown_seconds_win : m_cooldown_seconds_loss;
    
    if(elapsed_seconds < required_cooldown) {
        int remaining = required_cooldown - elapsed_seconds;
        reason = StringFormat("Cooldown active for %s. Remaining: %d seconds", symbol, remaining);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка кластера стопов                                         |
//+------------------------------------------------------------------+
bool CRiskManager::IsStopLossClusterOK(const string symbol, string &reason) {
    CSymbolState* state = GetSymbolState(symbol);
    if(state == NULL) return true;
    
    // Сбрасываем кластер если прошло достаточно времени
    if(TimeCurrent() - state.sl_cluster_start_time > m_sl_cluster_timespan_hours * 3600) {
        state.sl_cluster_count = 0;
        state.sl_cluster_start_time = 0;
    }
    
    if(state.sl_cluster_count >= m_sl_cluster_limit) {
        reason = StringFormat("SL cluster limit for %s: %d >= %d", 
                            symbol, state.sl_cluster_count, m_sl_cluster_limit);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Проверка EOW протокола                                           |
//+------------------------------------------------------------------+
bool CRiskManager::IsEOWProtocolActive(string &reason) {
    if(!m_is_eow_protocol_enabled) return true;
    
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    
    if(dt.day_of_week >= m_eow_day && dt.hour >= m_eow_hour) {
        reason = StringFormat("EOW Protocol active. Current: %s %02d:00, Limit: %s %02d:00", 
                            EnumToString((ENUM_DAY_OF_WEEK)dt.day_of_week), dt.hour,
                            EnumToString(m_eow_day), m_eow_hour);
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Расчет размера лота                                              |
//+------------------------------------------------------------------+
double CRiskManager::CalculateLotSize(const double balance, const double risk_percent, const double sl_pips) {
    if(sl_pips <= 0 || balance <= 0 || risk_percent <= 0) return 0.0;
    
    double risk_amount = balance * risk_percent / 100.0;
    double pip_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lot_size = risk_amount / (sl_pips * pip_value);
    
    // Нормализуем размер лота
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
    lot_size = NormalizeDouble(lot_size, (int)(-MathLog10(lot_step)));
    
    return lot_size;
}

//+------------------------------------------------------------------+
//| Вспомогательные методы                                           |
//+------------------------------------------------------------------+
string CRiskManager::ExtractBaseCurrency(const string symbol) {
    if(StringLen(symbol) >= 3) {
        return StringSubstr(symbol, 0, 3);
    }
    return "";
}

string CRiskManager::ExtractQuoteCurrency(const string symbol) {
    if(StringLen(symbol) >= 6) {
        return StringSubstr(symbol, 3, 3);
    }
    return "";
}

double CRiskManager::CalculateTotalOpenLots() {
    double total = 0.0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionSelectByIndex(i)) {
            total += PositionGetDouble(POSITION_VOLUME);
        }
    }
    return total;
}

double CRiskManager::CalculateTotalRiskPercent() {
    // Упрощенный расчет - каждая позиция считается как 1% риска
    // В реальности нужно рассчитывать на основе стоп-лоссов
    return (double)PositionsTotal() * 1.0;
}

int CRiskManager::CountPositionsByCurrency(const string currency) {
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionSelectByIndex(i)) {
            string pos_symbol = PositionGetString(POSITION_SYMBOL);
            if(StringFind(pos_symbol, currency) == 0 || StringFind(pos_symbol, currency) == 3) {
                count++;
            }
        }
    }
    return count;
}

CSymbolState* CRiskManager::GetSymbolState(const string symbol) {
    // Ищем существующее состояние
    for(int i = 0; i < m_symbol_states_map.Total(); i++) {
        CSymbolState* state = (CSymbolState*)m_symbol_states_map.At(i);
        if(state != NULL && state.symbol == symbol) {
            return state;
        }
    }
    
    // Создаем новое состояние если не найдено
    CSymbolState* newState = new CSymbolState(symbol);
    m_symbol_states_map.Add(newState);
    return newState;
}

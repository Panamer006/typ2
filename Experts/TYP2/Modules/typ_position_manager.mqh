// --- typ_position_manager.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Task: T2-PM :: Position Manager
#property copyright "TYP2"

#include "typ_regime_engine.mqh"
#include "typ_risk.mqh" // Для "Освобождения Риска"
#include <Arrays/ArrayObj.mqh>
#include <Trade/Trade.mqh>

// --- Структура для хранения состояния каждой управляемой позиции ---
class CManagedPosition : public CObject {
public:
    ulong    ticket;
    string   symbol;
    int      signal_category; // 0-Конфлюэнс, 1-Королевский
    double   initial_risk_R_money; // Размер риска в деньгах при открытии
    int      be_stage; // 0-Нет, 1-Profit Lock, 2-Full BE
    int      tp_stage; // 0-Нет, 1-TP1 взят, 2-TP2 взят
    bool     is_risk_released;
    datetime open_time;
    double   open_price;
    double   volume;
    ENUM_ORDER_TYPE order_type;
    int      addons_count; // Количество доливок
    
    /**
     * @brief Конструктор по умолчанию
     */
    CManagedPosition() {
        ticket = 0;
        symbol = "";
        signal_category = 0;
        initial_risk_R_money = 0.0;
        be_stage = 0;
        tp_stage = 0;
        is_risk_released = false;
        open_time = 0;
        open_price = 0.0;
        volume = 0.0;
        order_type = ORDER_TYPE_BUY;
        addons_count = 0;
    }
    
    /**
     * @brief Конструктор с параметрами
     */
    CManagedPosition(ulong tkt, string sym, int cat, double risk, datetime otime, double oprice, double vol, ENUM_ORDER_TYPE type) {
        ticket = tkt;
        symbol = sym;
        signal_category = cat;
        initial_risk_R_money = risk;
        be_stage = 0;
        tp_stage = 0;
        is_risk_released = false;
        open_time = otime;
        open_price = oprice;
        volume = vol;
        order_type = type;
        addons_count = 0;
    }
    
    /**
     * @brief Деструктор
     */
    ~CManagedPosition() {
        // Освобождение ресурсов если необходимо
    }
};

/**
 * @brief Центральная система управления позициями
 * 
 * Обеспечивает полное сопровождение открытых сделок: от установки SL/TP 
 * до безубытка, частичных закрытий и наращивания позиции (пирамидинга).
 */
class CPositionManager {
private:
    // --- ПАРАМЕТРЫ ---
    bool   m_is_impulse_confirmation_be_enabled;
    int    m_max_addons_per_position;
    double m_profit_lock_r_level; // Уровень для Profit Lock (по умолчанию 1.0R)
    double m_full_be_r_level; // Уровень для полного безубытка (по умолчанию 2.0R)
    double m_tp1_r_level; // Уровень для первого TP (по умолчанию 1.5R)
    double m_tp2_r_level; // Уровень для второго TP (по умолчанию 3.0R)
    double m_tp1_close_percent; // Процент закрытия на TP1 (по умолчанию 50%)
    double m_tp2_close_percent; // Процент закрытия на TP2 (по умолчанию 30%)
    
    // --- СОСТОЯНИЕ КЛАССА ---
    CArrayObj*    m_managed_positions;
    CRiskManager* m_risk_manager_ptr;
    CTrade        m_trade;

public:
    // --- Публичные Методы ---
    
    /**
     * @brief Конструктор менеджера позиций
     */
    CPositionManager();
    
    /**
     * @brief Деструктор - освобождает ресурсы
     */
    ~CPositionManager();
    
    /**
     * @brief Инициализация системы управления позициями
     * @param risk_manager_ptr Указатель на менеджер рисков
     * @param is_impulse_confirmation_be_enabled Включить подтверждение импульса для BE
     * @param max_addons_per_position Максимальное количество доливок на позицию
     * @param profit_lock_r_level Уровень R для Profit Lock
     * @param full_be_r_level Уровень R для полного безубытка
     * @param tp1_r_level Уровень R для первого TP
     * @param tp2_r_level Уровень R для второго TP
     * @param tp1_close_percent Процент закрытия на TP1
     * @param tp2_close_percent Процент закрытия на TP2
     */
    void Initialize(CRiskManager* risk_manager_ptr,
                   bool is_impulse_confirmation_be_enabled = true,
                   int max_addons_per_position = 2,
                   double profit_lock_r_level = 1.0,
                   double full_be_r_level = 2.0,
                   double tp1_r_level = 1.5,
                   double tp2_r_level = 3.0,
                   double tp1_close_percent = 50.0,
                   double tp2_close_percent = 30.0);
    
    /**
     * @brief Обновление состояния на каждом тике
     * @param current_regime Текущий режим рынка
     */
    void OnTick(E_MarketRegime current_regime);
    
    /**
     * @brief Добавление новой позиции в управление
     * @param ticket Тикет позиции
     * @param signal_category Категория сигнала (0-Конфлюэнс, 1-Королевский)
     * @param initial_risk Размер риска в деньгах при открытии
     */
    void AddNewPosition(ulong ticket, int signal_category, double initial_risk);
    
    /**
     * @brief Синхронизация состояния с реальными позициями
     * Вызывается при инициализации для восстановления состояния после перезапуска
     */
    void SynchronizeState();
    
    /**
     * @brief Удаление позиции из управления (при закрытии)
     * @param ticket Тикет закрытой позиции
     */
    void RemovePosition(ulong ticket);

private:
    // --- Приватные Методы-Обработчики ---
    
    /**
     * @brief Обработка логики безубытка
     * @param pos Управляемая позиция
     * @param regime Текущий режим рынка
     */
    void HandleBreakEven(CManagedPosition &pos, E_MarketRegime regime);
    
    /**
     * @brief Обработка логики тейк-профита
     * @param pos Управляемая позиция
     * @param regime Текущий режим рынка
     */
    void HandleTakeProfit(CManagedPosition &pos, E_MarketRegime regime);
    
    /**
     * @brief Обработка логики доливок (пирамидинга)
     * @param pos Управляемая позиция
     * @param regime Текущий режим рынка
     */
    void HandleAddons(CManagedPosition &pos, E_MarketRegime regime);
    
    /**
     * @brief Обработка трейлинг-стопа
     * @param pos Управляемая позиция
     */
    void HandleTrailingStop(CManagedPosition &pos);
    
    // --- Вспомогательные методы ---
    
    /**
     * @brief Расчет текущей прибыли позиции в R
     * @param pos Управляемая позиция
     * @return Прибыль в R (отношение к initial_risk_R_money)
     */
    double CalculateProfitR(CManagedPosition &pos);
    
    /**
     * @brief Получение текущей цены позиции
     * @param pos Управляемая позиция
     * @return Текущая цена (Bid для SELL, Ask для BUY)
     */
    double GetCurrentPrice(CManagedPosition &pos);
    
    /**
     * @brief Проверка подтверждения импульса
     * @param pos Управляемая позиция
     * @return true если последняя свеча в направлении позиции
     */
    bool IsImpulseConfirmed(CManagedPosition &pos);
    
    /**
     * @brief Проверка дивергенции RSI для выхода по затуханию моментума
     * @param pos Управляемая позиция
     * @return true если обнаружена дивергенция
     */
    bool IsMomentumDivergence(CManagedPosition &pos);
    
    /**
     * @brief Адаптивное разделение объема в зависимости от режима
     * @param regime Текущий режим рынка
     * @param tp1_percent Процент закрытия на TP1 (выходной параметр)
     * @param tp2_percent Процент закрытия на TP2 (выходной параметр)
     */
    void GetAdaptiveVolumeSplit(E_MarketRegime regime, double &tp1_percent, double &tp2_percent);
    
    /**
     * @brief Адаптивные уровни R в зависимости от режима
     * @param regime Текущий режим рынка
     * @param tp1_r Уровень R для TP1 (выходной параметр)
     * @param tp2_r Уровень R для TP2 (выходной параметр)
     */
    void GetAdaptiveRLevels(E_MarketRegime regime, double &tp1_r, double &tp2_r);
    
    /**
     * @brief Поиск сигнала продолжения тренда для доливки
     * @param pos Управляемая позиция
     * @return true если найден сигнал продолжения
     */
    bool FindContinuationSignal(CManagedPosition &pos);
    
    /**
     * @brief Пересчет единого стоп-лосса для пирамиды
     * @param pos Управляемая позиция
     */
    void RecalculateUnifiedStopLoss(CManagedPosition &pos);
    
    /**
     * @brief Инициализация данных позиции из реальной позиции
     * @param pos Управляемая позиция
     * @return true если инициализация успешна
     */
    bool InitializePositionData(CManagedPosition &pos);
};

//+------------------------------------------------------------------+
//| Конструктор менеджера позиций                                    |
//+------------------------------------------------------------------+
CPositionManager::CPositionManager() {
    m_is_impulse_confirmation_be_enabled = true;
    m_max_addons_per_position = 2;
    m_profit_lock_r_level = 1.0;
    m_full_be_r_level = 2.0;
    m_tp1_r_level = 1.5;
    m_tp2_r_level = 3.0;
    m_tp1_close_percent = 50.0;
    m_tp2_close_percent = 30.0;
    
    m_managed_positions = new CArrayObj();
    m_risk_manager_ptr = NULL;
}

//+------------------------------------------------------------------+
//| Деструктор менеджера позиций                                     |
//+------------------------------------------------------------------+
CPositionManager::~CPositionManager() {
    if(m_managed_positions != NULL) {
        delete m_managed_positions;
    }
}

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
void CPositionManager::Initialize(CRiskManager* risk_manager_ptr,
                                 bool is_impulse_confirmation_be_enabled = true,
                                 int max_addons_per_position = 2,
                                 double profit_lock_r_level = 1.0,
                                 double full_be_r_level = 2.0,
                                 double tp1_r_level = 1.5,
                                 double tp2_r_level = 3.0,
                                 double tp1_close_percent = 50.0,
                                 double tp2_close_percent = 30.0) {
    
    m_risk_manager_ptr = risk_manager_ptr;
    m_is_impulse_confirmation_be_enabled = is_impulse_confirmation_be_enabled;
    m_max_addons_per_position = max_addons_per_position;
    m_profit_lock_r_level = profit_lock_r_level;
    m_full_be_r_level = full_be_r_level;
    m_tp1_r_level = tp1_r_level;
    m_tp2_r_level = tp2_r_level;
    m_tp1_close_percent = tp1_close_percent;
    m_tp2_close_percent = tp2_close_percent;
    
    // Синхронизируем состояние с реальными позициями
    SynchronizeState();
    
    Print("Position Manager: Initialized with max addons = ", m_max_addons_per_position);
}

//+------------------------------------------------------------------+
//| Обновление на каждом тике                                        |
//+------------------------------------------------------------------+
void CPositionManager::OnTick(E_MarketRegime current_regime) {
    // Обрабатываем все управляемые позиции
    for(int i = m_managed_positions.Total() - 1; i >= 0; i--) {
        CManagedPosition* pos = (CManagedPosition*)m_managed_positions.At(i);
        if(pos == NULL) continue;
        
        // Проверяем, что позиция еще существует
        if(!PositionSelectByTicket(pos.ticket)) {
            // Позиция закрыта - удаляем из управления
            m_managed_positions.Delete(i);
            continue;
        }
        
        // Инициализируем данные позиции если необходимо
        if(!InitializePositionData(*pos)) {
            continue;
        }
        
        // Обрабатываем логику безубытка
        HandleBreakEven(*pos, current_regime);
        
        // Обрабатываем логику тейк-профита
        HandleTakeProfit(*pos, current_regime);
        
        // Обрабатываем логику доливок
        HandleAddons(*pos, current_regime);
        
        // Обрабатываем трейлинг-стоп
        HandleTrailingStop(*pos);
    }
}

//+------------------------------------------------------------------+
//| Добавление новой позиции в управление                           |
//+------------------------------------------------------------------+
void CPositionManager::AddNewPosition(ulong ticket, int signal_category, double initial_risk) {
    if(!PositionSelectByTicket(ticket)) {
        Print("Position Manager: Cannot find position with ticket ", ticket);
        return;
    }
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
    double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
    double volume = PositionGetDouble(POSITION_VOLUME);
    ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
    
    CManagedPosition* new_pos = new CManagedPosition(ticket, symbol, signal_category, initial_risk, 
                                                   open_time, open_price, volume, order_type);
    
    m_managed_positions.Add(new_pos);
    
    Print("Position Manager: Added position ", ticket, " (", symbol, ") with risk ", initial_risk, " and category ", signal_category);
}

//+------------------------------------------------------------------+
//| Синхронизация состояния с реальными позициями                   |
//+------------------------------------------------------------------+
void CPositionManager::SynchronizeState() {
    // Очищаем текущий список
    m_managed_positions.Clear();
    
    // Проходим по всем открытым позициям
    for(int i = 0; i < PositionsTotal(); i++) {
        if(PositionSelectByIndex(i)) {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            string symbol = PositionGetString(POSITION_SYMBOL);
            
            // Проверяем, что это позиция нашего советника
            if(PositionGetInteger(POSITION_MAGIC) == _Magic) {
                // Создаем управляемую позицию с базовыми параметрами
                CManagedPosition* pos = new CManagedPosition();
                pos.ticket = ticket;
                pos.symbol = symbol;
                pos.signal_category = 0; // По умолчанию Конфлюэнс
                pos.initial_risk_R_money = 100.0; // Примерное значение, в реальности нужно рассчитать
                
                m_managed_positions.Add(pos);
                
                Print("Position Manager: Synchronized position ", ticket, " (", symbol, ")");
            }
        }
    }
    
    Print("Position Manager: Synchronized ", m_managed_positions.Total(), " positions");
}

//+------------------------------------------------------------------+
//| Удаление позиции из управления                                   |
//+------------------------------------------------------------------+
void CPositionManager::RemovePosition(ulong ticket) {
    for(int i = 0; i < m_managed_positions.Total(); i++) {
        CManagedPosition* pos = (CManagedPosition*)m_managed_positions.At(i);
        if(pos != NULL && pos.ticket == ticket) {
            m_managed_positions.Delete(i);
            Print("Position Manager: Removed position ", ticket, " from management");
            break;
        }
    }
}

//+------------------------------------------------------------------+
//| Обработка логики безубытка                                       |
//+------------------------------------------------------------------+
void CPositionManager::HandleBreakEven(CManagedPosition &pos, E_MarketRegime regime) {
    double profit_R = CalculateProfitR(pos);
    
    // Этап 1: Profit Lock (-0.5R)
    if(profit_R >= m_profit_lock_r_level && pos.be_stage == 0) {
        // Проверяем подтверждение импульса если включено
        if(m_is_impulse_confirmation_be_enabled && !IsImpulseConfirmed(pos)) {
            return;
        }
        
        // Перемещаем SL на уровень -0.5R
        double new_sl = pos.open_price - (pos.initial_risk_R_money * 0.5 / pos.volume);
        if(pos.order_type == ORDER_TYPE_SELL) {
            new_sl = pos.open_price + (pos.initial_risk_R_money * 0.5 / pos.volume);
        }
        
        if(m_trade.PositionModify(pos.ticket, new_sl, PositionGetDouble(POSITION_TP))) {
            pos.be_stage = 1;
            Print("Position Manager: Profit Lock activated for ", pos.ticket, " at -0.5R");
        }
    }
    
    // Этап 2: Полный Безубыток
    if(profit_R >= m_full_be_r_level && pos.be_stage == 1) {
        // Проверяем подтверждение импульса если включено
        if(m_is_impulse_confirmation_be_enabled && !IsImpulseConfirmed(pos)) {
            return;
        }
        
        // Перемещаем SL на цену открытия + спред
        double spread = SymbolInfoDouble(pos.symbol, SYMBOL_SPREAD) * SymbolInfoDouble(pos.symbol, SYMBOL_POINT);
        double new_sl = pos.open_price + spread;
        if(pos.order_type == ORDER_TYPE_SELL) {
            new_sl = pos.open_price - spread;
        }
        
        if(m_trade.PositionModify(pos.ticket, new_sl, PositionGetDouble(POSITION_TP))) {
            pos.be_stage = 2;
            pos.is_risk_released = true;
            
            // Освобождаем риск в менеджере рисков
            if(m_risk_manager_ptr != NULL) {
                // Здесь должен быть вызов метода освобождения риска
                // m_risk_manager_ptr->ReleaseRisk(pos.symbol, pos.initial_risk_R_money);
            }
            
            Print("Position Manager: Full Break-Even activated for ", pos.ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Обработка логики тейк-профита                                   |
//+------------------------------------------------------------------+
void CPositionManager::HandleTakeProfit(CManagedPosition &pos, E_MarketRegime regime) {
    double profit_R = CalculateProfitR(pos);
    
    // Адаптивные уровни и проценты в зависимости от режима
    double tp1_r, tp2_r;
    GetAdaptiveRLevels(regime, tp1_r, tp2_r);
    
    double tp1_percent, tp2_percent;
    GetAdaptiveVolumeSplit(regime, tp1_percent, tp2_percent);
    
    // TP1: Первое частичное закрытие
    if(profit_R >= tp1_r && pos.tp_stage == 0) {
        double close_volume = pos.volume * tp1_percent / 100.0;
        
        if(m_trade.PositionClosePartial(pos.ticket, close_volume)) {
            pos.tp_stage = 1;
            pos.volume -= close_volume; // Обновляем объем
            Print("Position Manager: TP1 executed for ", pos.ticket, " - closed ", tp1_percent, "%");
        }
    }
    
    // TP2: Второе частичное закрытие
    if(profit_R >= tp2_r && pos.tp_stage == 1) {
        double close_volume = pos.volume * tp2_percent / 100.0;
        
        if(m_trade.PositionClosePartial(pos.ticket, close_volume)) {
            pos.tp_stage = 2;
            pos.volume -= close_volume; // Обновляем объем
            Print("Position Manager: TP2 executed for ", pos.ticket, " - closed ", tp2_percent, "%");
        }
    }
    
    // Выход по затуханию моментума для "Раннера"
    if(pos.tp_stage == 2 && IsMomentumDivergence(pos)) {
        if(m_trade.PositionClose(pos.ticket)) {
            Print("Position Manager: Momentum divergence exit for ", pos.ticket);
            RemovePosition(pos.ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Обработка логики доливок (пирамидинга)                          |
//+------------------------------------------------------------------+
void CPositionManager::HandleAddons(CManagedPosition &pos, E_MarketRegime regime) {
    // Проверяем лимит доливок
    if(pos.addons_count >= m_max_addons_per_position) {
        return;
    }
    
    // Контекстное освобождение риска
    bool is_risk_released = false;
    double profit_R = CalculateProfitR(pos);
    
    if(regime == REGIME_TREND_YOUNG && profit_R >= 1.0) {
        is_risk_released = true;
    }
    if(regime == REGIME_TREND_MATURE && pos.be_stage == 2) {
        is_risk_released = true;
    }
    
    if(!is_risk_released) {
        return;
    }
    
    // Ищем сигнал продолжения тренда
    if(FindContinuationSignal(pos)) {
        // Здесь должна быть логика создания SignalCandidate и передачи в Resolver
        // Пока что просто логируем
        Print("Position Manager: Continuation signal found for addon to ", pos.ticket);
        
        // После открытия доливки пересчитываем единый стоп-лосс
        // RecalculateUnifiedStopLoss(pos);
    }
}

//+------------------------------------------------------------------+
//| Обработка трейлинг-стопа                                         |
//+------------------------------------------------------------------+
void CPositionManager::HandleTrailingStop(CManagedPosition &pos) {
    // Простая логика трейлинг-стопа
    double current_price = GetCurrentPrice(pos);
    double current_sl = PositionGetDouble(POSITION_SL);
    double atr = SymbolInfoDouble(pos.symbol, SYMBOL_ATR);
    
    if(atr <= 0) return;
    
    double trail_distance = atr * 2.0; // 2 ATR для трейлинга
    double new_sl = 0;
    
    if(pos.order_type == ORDER_TYPE_BUY) {
        new_sl = current_price - trail_distance;
        if(new_sl > current_sl && new_sl < current_price) {
            m_trade.PositionModify(pos.ticket, new_sl, PositionGetDouble(POSITION_TP));
        }
    } else if(pos.order_type == ORDER_TYPE_SELL) {
        new_sl = current_price + trail_distance;
        if(new_sl < current_sl && new_sl > current_price) {
            m_trade.PositionModify(pos.ticket, new_sl, PositionGetDouble(POSITION_TP));
        }
    }
}

//+------------------------------------------------------------------+
//| Вспомогательные методы                                           |
//+------------------------------------------------------------------+
double CPositionManager::CalculateProfitR(CManagedPosition &pos) {
    if(pos.initial_risk_R_money <= 0) return 0.0;
    
    double current_profit = PositionGetDouble(POSITION_PROFIT);
    return current_profit / pos.initial_risk_R_money;
}

double CPositionManager::GetCurrentPrice(CManagedPosition &pos) {
    if(pos.order_type == ORDER_TYPE_BUY) {
        return SymbolInfoDouble(pos.symbol, SYMBOL_BID);
    } else {
        return SymbolInfoDouble(pos.symbol, SYMBOL_ASK);
    }
}

bool CPositionManager::IsImpulseConfirmed(CManagedPosition &pos) {
    // Проверяем, что последняя закрытая свеча была в направлении позиции
    double close_price = iClose(pos.symbol, PERIOD_CURRENT, 1);
    double prev_close_price = iClose(pos.symbol, PERIOD_CURRENT, 2);
    
    if(pos.order_type == ORDER_TYPE_BUY) {
        return close_price > prev_close_price;
    } else {
        return close_price < prev_close_price;
    }
}

bool CPositionManager::IsMomentumDivergence(CManagedPosition &pos) {
    // Упрощенная проверка дивергенции RSI
    // В реальности нужен более сложный алгоритм
    int rsi_handle = iRSI(pos.symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
    if(rsi_handle == INVALID_HANDLE) return false;
    
    double rsi_buffer[];
    if(CopyBuffer(rsi_handle, 0, 1, 3, rsi_buffer) <= 0) return false;
    
    // Простая логика: если RSI падает, а цена растет (для BUY)
    if(pos.order_type == ORDER_TYPE_BUY) {
        return rsi_buffer[0] < rsi_buffer[1] && rsi_buffer[1] < rsi_buffer[2];
    } else {
        return rsi_buffer[0] > rsi_buffer[1] && rsi_buffer[1] > rsi_buffer[2];
    }
}

void CPositionManager::GetAdaptiveVolumeSplit(E_MarketRegime regime, double &tp1_percent, double &tp2_percent) {
    switch(regime) {
        case REGIME_TREND_YOUNG:
        case REGIME_TREND_MATURE:
            tp1_percent = 30.0; // Меньше закрываем в тренде
            tp2_percent = 20.0;
            break;
            
        case REGIME_FLAT_QUIET:
            tp1_percent = 50.0; // Стандартные значения
            tp2_percent = 30.0;
            break;
            
        case REGIME_FLAT_CHOPPY:
            tp1_percent = 60.0; // Больше закрываем в "пиле"
            tp2_percent = 30.0;
            break;
            
        default:
            tp1_percent = m_tp1_close_percent;
            tp2_percent = m_tp2_close_percent;
            break;
    }
}

void CPositionManager::GetAdaptiveRLevels(E_MarketRegime regime, double &tp1_r, double &tp2_r) {
    switch(regime) {
        case REGIME_TREND_YOUNG:
        case REGIME_TREND_MATURE:
            tp1_r = 2.0; // Выше уровни в тренде
            tp2_r = 4.0;
            break;
            
        case REGIME_FLAT_QUIET:
            tp1_r = m_tp1_r_level; // Стандартные значения
            tp2_r = m_tp2_r_level;
            break;
            
        case REGIME_FLAT_CHOPPY:
            tp1_r = 1.0; // Ниже уровни в "пиле"
            tp2_r = 2.0;
            break;
            
        default:
            tp1_r = m_tp1_r_level;
            tp2_r = m_tp2_r_level;
            break;
    }
}

bool CPositionManager::FindContinuationSignal(CManagedPosition &pos) {
    // Упрощенная логика поиска сигнала продолжения
    // В реальности нужен более сложный алгоритм
    
    // Проверяем пробой локального максимума/минимума
    double current_price = GetCurrentPrice(pos);
    double high_20 = iHigh(pos.symbol, PERIOD_CURRENT, iHighest(pos.symbol, PERIOD_CURRENT, MODE_HIGH, 20, 1));
    double low_20 = iLow(pos.symbol, PERIOD_CURRENT, iLowest(pos.symbol, PERIOD_CURRENT, MODE_LOW, 20, 1));
    
    if(pos.order_type == ORDER_TYPE_BUY) {
        return current_price > high_20; // Пробой максимума
    } else {
        return current_price < low_20; // Пробой минимума
    }
}

void CPositionManager::RecalculateUnifiedStopLoss(CManagedPosition &pos) {
    // Логика пересчета единого стоп-лосса для пирамиды
    // В реальности нужно учитывать все доливки и их цены открытия
    
    double total_volume = pos.volume; // Здесь должна быть сумма всех объемов пирамиды
    double weighted_price = pos.open_price; // Здесь должна быть средневзвешенная цена
    
    // Пересчитываем SL так, чтобы общий итог был не хуже безубытка
    double new_sl = weighted_price; // Упрощенная логика
    
    m_trade.PositionModify(pos.ticket, new_sl, PositionGetDouble(POSITION_TP));
    Print("Position Manager: Unified SL recalculated for pyramid ", pos.ticket);
}

bool CPositionManager::InitializePositionData(CManagedPosition &pos) {
    if(!PositionSelectByTicket(pos.ticket)) {
        return false;
    }
    
    // Обновляем данные позиции
    pos.symbol = PositionGetString(POSITION_SYMBOL);
    pos.volume = PositionGetDouble(POSITION_VOLUME);
    pos.order_type = (ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
    
    return true;
}
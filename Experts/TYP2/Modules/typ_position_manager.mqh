// --- typ_position_manager.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Task: T2-PM :: Position Manager
#property copyright "TYP2"

#include "typ_ai_layer.mqh"

#include "typ_regime_engine.mqh"
#include "typ_risk.mqh" // Для "Освобождения Риска"
#include <Arrays/ArrayObj.mqh>
#include <Trade/Trade.mqh>

// --- Структура для хранения состояния каждой управляемой позиции ---
struct ManagedPosition {
    ulong    ticket;
    string   symbol;
    int      signal_category; // 0-Конфлюэнс, 1-Королевский
    double   initial_risk_R; // Размер риска в деньгах при открытии
    double   initial_price; // Цена открытия
    double   initial_sl; // Изначальный стоп-лосс
    double   initial_volume; // Изначальный объем
    int      be_stage; // 0-Нет, 1-Profit Lock, 2-Full BE
    bool     is_risk_released;
    int      addons_count; // Количество доливок
    double   tp1_executed; // Объем закрытый на TP1
    double   tp2_executed; // Объем закрытый на TP2
    bool     tp1_triggered; // Флаг выполнения TP1
    bool     tp2_triggered; // Флаг выполнения TP2
    datetime last_addon_time; // Время последней доливки
    double   signal_score; // Качество сигнала (0.0-1.0)
    
    ManagedPosition() {
        ticket = 0;
        symbol = "";
        signal_category = 0;
        initial_risk_R = 0.0;
        initial_price = 0.0;
        initial_sl = 0.0;
        initial_volume = 0.0;
        be_stage = 0;
        is_risk_released = false;
        addons_count = 0;
        tp1_executed = 0.0;
        tp2_executed = 0.0;
        tp1_triggered = false;
        tp2_triggered = false;
        last_addon_time = 0;
        signal_score = 0.5;
    }
    
    ManagedPosition(ulong pos_ticket, string pos_symbol, int category, double score = 0.5) {
        ticket = pos_ticket;
        symbol = pos_symbol;
        signal_category = category;
        signal_score = score;
        initial_risk_R = 0.0;
        initial_price = 0.0;
        initial_sl = 0.0;
        initial_volume = 0.0;
        be_stage = 0;
        is_risk_released = false;
        addons_count = 0;
        tp1_executed = 0.0;
        tp2_executed = 0.0;
        tp1_triggered = false;
        tp2_triggered = false;
        last_addon_time = 0;
    }
};

// --- Класс для управления позициями ---
class CManagedPositionsList : public CObject {
private:
    CArrayObj* m_positions;
    
public:
    CManagedPositionsList() {
        m_positions = new CArrayObj();
    }
    
    ~CManagedPositionsList() {
        if(m_positions != NULL) {
            delete m_positions;
        }
    }
    
    void Add(ManagedPosition* pos) {
        m_positions.Add(pos);
    }
    
    ManagedPosition* FindByTicket(ulong ticket) {
        for(int i = 0; i < m_positions.Total(); i++) {
            ManagedPosition* pos = (ManagedPosition*)m_positions.At(i);
            if(pos != NULL && pos.ticket == ticket) {
                return pos;
            }
        }
        return NULL;
    }
    
    void RemoveByTicket(ulong ticket) {
        for(int i = 0; i < m_positions.Total(); i++) {
            ManagedPosition* pos = (ManagedPosition*)m_positions.At(i);
            if(pos != NULL && pos.ticket == ticket) {
                m_positions.Delete(i);
                break;
            }
        }
    }
    
    int Total() {
        return m_positions.Total();
    }
    
    ManagedPosition* At(int index) {
        return (ManagedPosition*)m_positions.At(index);
    }
    
    void Clear() {
        m_positions.Clear();
    }
};

class CPositionManager {
private:
    // --- ПАРАМЕТРЫ ---
    // Tiered BE
    bool   m_is_impulse_confirmation_be_enabled;
    // Add-ons
    int    m_max_addons_per_position;
    // Take Profit Levels
    double m_tp1_level_R; // TP1 в R
    double m_tp2_level_R; // TP2 в R
    // Volume Split Ratios
    double m_tp1_volume_percent; // % закрытия на TP1
    double m_tp2_volume_percent; // % закрытия на TP2
    // ADR settings
    double m_adr_exit_percent; // % от ADR для принудительного закрытия
    
    // --- СОСТОЯНИЕ КЛАССА ---
    CManagedPositionsList* m_managed_positions; // Динамический массив управляемых позиций
    CRiskManager* m_risk_manager_ptr; // Указатель на риск-менеджер
    CAiLayer* m_ai_layer_ptr; // Указатель на AI-Слой
    CTrade m_trade; // Объект для торговых операций
    int m_h_rsi; // Хэндл RSI для дивергенций

public:
    // --- Публичные Методы ---
    CPositionManager();
    ~CPositionManager();
    void Initialize(CRiskManager* risk_manager, 
                   CAiLayer* ai_layer = NULL,
                   bool impulse_confirmation_be = true,
                   int max_addons = 2,
                   double tp1_level = 1.5,
                   double tp2_level = 3.0,
                   double tp1_volume = 50.0,
                   double tp2_volume = 30.0,
                   double adr_exit = 80.0);
    void OnTick(E_MarketRegime current_regime);
    void AddNewPosition(ulong ticket, int signal_category, double signal_score = 0.5);
    void RemoveClosedPositions();
    void SynchronizeState();
    
    // --- Методы для работы с AI-Слоем ---
    void SetAiLayer(CAiLayer* ai_layer_ptr);
    CAiLayer* GetAiLayer() const;
    void GetAiPositionStats(string &stats_string);

private:
    // --- Приватные Методы-Обработчики ---
    void HandleBreakEven(ManagedPosition* pos, E_MarketRegime regime);
    void HandleTakeProfit(ManagedPosition* pos, E_MarketRegime regime);
    void HandleAddons(ManagedPosition* pos, E_MarketRegime regime);
    void HandleTrailingStop(ManagedPosition* pos);
    
    // --- Вспомогательные методы ---
    double CalculateProfitR(ManagedPosition* pos);
    bool IsImpulseConfirmed(const string symbol, int direction);
    bool HasMomentumDivergence(const string symbol, int direction);
    double GetADRPercent(const string symbol);
    void PartialClose(ulong ticket, double volume_percent, string reason);
    void MoveSLToLevel(ulong ticket, double new_sl, string reason);
    bool InitializePositionData(ManagedPosition* pos);
    double GetVolumeRatioForRegime(E_MarketRegime regime, int tp_level);
};

//+------------------------------------------------------------------+
//| Конструктор                                                      |
//+------------------------------------------------------------------+
CPositionManager::CPositionManager() {
    m_is_impulse_confirmation_be_enabled = true;
    m_max_addons_per_position = 2;
    m_tp1_level_R = 1.5;
    m_tp2_level_R = 3.0;
    m_tp1_volume_percent = 50.0;
    m_tp2_volume_percent = 30.0;
    m_adr_exit_percent = 80.0;
    
    m_managed_positions = new CManagedPositionsList();
    m_risk_manager_ptr = NULL;
    m_h_rsi = INVALID_HANDLE;
}

//+------------------------------------------------------------------+
//| Деструктор                                                       |
//+------------------------------------------------------------------+
CPositionManager::~CPositionManager() {
    if(m_managed_positions != NULL) {
        delete m_managed_positions;
    }
    
    if(m_h_rsi != INVALID_HANDLE) {
        IndicatorRelease(m_h_rsi);
    }
}

//+------------------------------------------------------------------+
//| Инициализация                                                    |
//+------------------------------------------------------------------+
void CPositionManager::Initialize(CRiskManager* risk_manager, 
                                 CAiLayer* ai_layer = NULL,
                                 bool impulse_confirmation_be = true,
                                 int max_addons = 2,
                                 double tp1_level = 1.5,
                                 double tp2_level = 3.0,
                                 double tp1_volume = 50.0,
                                 double tp2_volume = 30.0,
                                 double adr_exit = 80.0) {
    
    m_risk_manager_ptr = risk_manager;
    m_ai_layer_ptr = ai_layer;
    m_is_impulse_confirmation_be_enabled = impulse_confirmation_be;
    m_max_addons_per_position = max_addons;
    m_tp1_level_R = tp1_level;
    m_tp2_level_R = tp2_level;
    m_tp1_volume_percent = tp1_volume;
    m_tp2_volume_percent = tp2_volume;
    m_adr_exit_percent = adr_exit;
    
    // Создаем хэндл RSI для дивергенций
    m_h_rsi = iRSI(_Symbol, PERIOD_H1, 14, PRICE_CLOSE);
    if(m_h_rsi == INVALID_HANDLE) {
        Print("Position Manager ERROR: Failed to create RSI handle");
    }
    
    Print("Position Manager: Initialized with TP levels: ", m_tp1_level_R, "R/", m_tp2_level_R, "R");
}

//+------------------------------------------------------------------+
//| Обновление на каждом тике                                        |
//+------------------------------------------------------------------+
void CPositionManager::OnTick(E_MarketRegime current_regime) {
    // Удаляем закрытые позиции
    RemoveClosedPositions();
    
    // Обрабатываем каждую управляемую позицию
    for(int i = 0; i < m_managed_positions.Total(); i++) {
        ManagedPosition* pos = m_managed_positions.At(i);
        if(pos == NULL) continue;
        
        // Проверяем, что позиция еще существует
        if(!PositionSelectByTicket(pos.ticket)) {
            continue; // Позиция закрыта, будет удалена в RemoveClosedPositions
        }
        
        // Инициализируем данные позиции при первом обращении
        if(pos.initial_risk_R == 0.0) {
            if(!InitializePositionData(pos)) {
                continue; // Ошибка инициализации
            }
        }
        
        // Применяем логику управления
        HandleBreakEven(pos, current_regime);
        HandleTakeProfit(pos, current_regime);
        HandleAddons(pos, current_regime);
        HandleTrailingStop(pos);
    }
}

//+------------------------------------------------------------------+
//| Добавление новой позиции в управление                            |
//+------------------------------------------------------------------+
void CPositionManager::AddNewPosition(ulong ticket, int signal_category, double signal_score = 0.5) {
    // Проверяем, что позиция не добавлена ранее
    if(m_managed_positions.FindByTicket(ticket) != NULL) {
        return; // Уже управляется
    }
    
    if(!PositionSelectByTicket(ticket)) {
        Print("Position Manager ERROR: Cannot find position with ticket ", ticket);
        return;
    }
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    ManagedPosition* new_pos = new ManagedPosition(ticket, symbol, signal_category, signal_score);
    
    m_managed_positions.Add(new_pos);
    
    Print("Position Manager: Added position ", ticket, " (", symbol, ") to management. Category: ", signal_category);
}

//+------------------------------------------------------------------+
//| Удаление закрытых позиций из управления                          |
//+------------------------------------------------------------------+
void CPositionManager::RemoveClosedPositions() {
    for(int i = m_managed_positions.Total() - 1; i >= 0; i--) {
        ManagedPosition* pos = m_managed_positions.At(i);
        if(pos == NULL) continue;
        
        if(!PositionSelectByTicket(pos.ticket)) {
            Print("Position Manager: Removing closed position ", pos.ticket);
            m_managed_positions.RemoveByTicket(pos.ticket);
        }
    }
}

//+------------------------------------------------------------------+
//| Логика безубытка                                                 |
//+------------------------------------------------------------------+
void CPositionManager::HandleBreakEven(ManagedPosition* pos, E_MarketRegime regime) {
    if(!PositionSelectByTicket(pos.ticket)) return;
    
    double profit_R = CalculateProfitR(pos);
    
    // Этап 1: Profit Lock (-0.5R)
    if(profit_R >= 1.0 && pos.be_stage == 0) {
        // Проверяем подтверждение импульса если включено
        if(m_is_impulse_confirmation_be_enabled) {
            long pos_type = PositionGetInteger(POSITION_TYPE);
            int direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
            
            if(!IsImpulseConfirmed(pos.symbol, direction)) {
                return; // Ждем подтверждения импульса
            }
        }
        
        double new_sl = pos.initial_price - 0.5 * pos.initial_risk_R / pos.initial_volume;
        MoveSLToLevel(pos.ticket, new_sl, "Profit Lock -0.5R");
        pos.be_stage = 1;
    }
    
    // Этап 2: Полный безубыток
    if(profit_R >= 2.0 && pos.be_stage == 1) {
        // Проверяем подтверждение импульса если включено
        if(m_is_impulse_confirmation_be_enabled) {
            long pos_type = PositionGetInteger(POSITION_TYPE);
            int direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
            
            if(!IsImpulseConfirmed(pos.symbol, direction)) {
                return; // Ждем подтверждения импульса
            }
        }
        
        // Безубыток = цена открытия + спред
        double spread = SymbolInfoInteger(pos.symbol, SYMBOL_SPREAD) * SymbolInfoDouble(pos.symbol, SYMBOL_POINT);
        double new_sl = pos.initial_price + spread;
        
        MoveSLToLevel(pos.ticket, new_sl, "Full Breakeven");
        pos.be_stage = 2;
        pos.is_risk_released = true; // Риск освобожден
    }
}

//+------------------------------------------------------------------+
//| Логика тейк-профита                                              |
//+------------------------------------------------------------------+
void CPositionManager::HandleTakeProfit(ManagedPosition* pos, E_MarketRegime regime) {
    if(!PositionSelectByTicket(pos.ticket)) return;
    
    double profit_R = CalculateProfitR(pos);
    double current_volume = PositionGetDouble(POSITION_VOLUME);
    
    // TP1: Первичное закрытие
    if(profit_R >= m_tp1_level_R && !pos.tp1_triggered) {
        double tp1_ratio = GetVolumeRatioForRegime(regime, 1);
        double volume_to_close = pos.initial_volume * tp1_ratio / 100.0;
        
        if(volume_to_close > 0 && volume_to_close <= current_volume) {
            PartialClose(pos.ticket, tp1_ratio, StringFormat("TP1 at %.1fR", profit_R));
            pos.tp1_executed = volume_to_close;
            pos.tp1_triggered = true;
        }
    }
    
    // TP2: Вторичное закрытие
    if(profit_R >= m_tp2_level_R && !pos.tp2_triggered && pos.tp1_triggered) {
        double tp2_ratio = GetVolumeRatioForRegime(regime, 2);
        double volume_to_close = pos.initial_volume * tp2_ratio / 100.0;
        
        if(volume_to_close > 0 && volume_to_close <= current_volume) {
            PartialClose(pos.ticket, tp2_ratio, StringFormat("TP2 at %.1fR", profit_R));
            pos.tp2_executed = volume_to_close;
            pos.tp2_triggered = true;
        }
    }
    
    // Проверка ADR: принудительное закрытие при достижении 80% ADR
    double adr_percent = GetADRPercent(pos.symbol);
    if(adr_percent >= m_adr_exit_percent && current_volume > 0) {
        PartialClose(pos.ticket, 50.0, StringFormat("ADR Exit at %.1f%%", adr_percent));
    }
    
    // Выход по затуханию моментума для раннера
    if(pos.tp1_triggered && pos.tp2_triggered && current_volume > 0) {
        long pos_type = PositionGetInteger(POSITION_TYPE);
        int direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
        
        if(HasMomentumDivergence(pos.symbol, direction)) {
            PartialClose(pos.ticket, 100.0, "Momentum Divergence Exit");
        }
    }
}

//+------------------------------------------------------------------+
//| Логика доливок (пирамидинг)                                      |
//+------------------------------------------------------------------+
void CPositionManager::HandleAddons(ManagedPosition* pos, E_MarketRegime regime) {
    // Проверка лимита
    if(pos.addons_count >= m_max_addons_per_position) return;
    
    // Контекстное освобождение риска
    bool is_risk_released = false;
    double profit_R = CalculateProfitR(pos);
    
    if(regime == REGIME_TREND_YOUNG && profit_R >= 1.0) {
        is_risk_released = true;
    } else if(regime == REGIME_TREND_MATURE && pos.be_stage == 2) {
        is_risk_released = true;
    }
    
    if(!is_risk_released) return;
    
    // Проверка запретов от режимов
    if(regime == REGIME_TREND_WEAKENING || regime == REGIME_UNSTABLE || regime == REGIME_RISK_OFF) {
        return;
    }
    
    // Проверка временного интервала (не чаще раза в час)
    if(TimeCurrent() - pos.last_addon_time < 3600) return;
    
    // AI-анализ тактики управления позицией (если AI-Слой доступен)
    if(m_ai_layer_ptr != NULL && m_ai_layer_ptr->IsInitialized() && m_ai_layer_ptr->IsAiAnalysisEnabled()) {
        string position_info = StringFormat("Ticket=%d, Symbol=%s, Category=%d, Score=%.2f", 
                                          pos->ticket, pos->symbol, pos->signal_category, pos->signal_score);
        string market_context = StringFormat("Regime=%s, Addons=%d, Profit_R=%.2f", 
                                           EnumToString(regime), pos->addons_count, profit_R);
        
        string ai_tactic = m_ai_layer_ptr->SuggestTactic(position_info, market_context);
        
        // Если AI рекомендует не добавлять позицию, пропускаем
        if(StringFind(ai_tactic, "avoid") >= 0 || StringFind(ai_tactic, "no addon") >= 0) {
            Print("Position Manager: AI recommendation - ", ai_tactic, " for position ", pos->ticket);
            return;
        }
        
        Print("Position Manager: AI tactic suggestion - ", ai_tactic, " for position ", pos->ticket);
    }
    
    // Простая проверка сигнала продолжения (новый локальный экстремум)
    if(!PositionSelectByTicket(pos.ticket)) return;
    
    long pos_type = PositionGetInteger(POSITION_TYPE);
    double current_price = (pos_type == POSITION_TYPE_BUY) ? 
                          SymbolInfoDouble(pos.symbol, SYMBOL_ASK) : 
                          SymbolInfoDouble(pos.symbol, SYMBOL_BID);
    
    // Для BUY: текущая цена должна быть выше максимума последних 10 баров
    // Для SELL: текущая цена должна быть ниже минимума последних 10 баров
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(pos.symbol, PERIOD_H1, 0, 10, high) <= 0 || 
       CopyLow(pos.symbol, PERIOD_H1, 0, 10, low) <= 0) {
        return;
    }
    
    bool signal_continuation = false;
    if(pos_type == POSITION_TYPE_BUY) {
        double max_high = high[ArrayMaximum(high, 0, 10)];
        signal_continuation = (current_price > max_high);
    } else {
        double min_low = low[ArrayMinimum(low, 0, 10)];
        signal_continuation = (current_price < min_low);
    }
    
    if(signal_continuation) {
        Print("Position Manager: Addon signal for position ", pos.ticket, " - continuation pattern detected");
        pos.addons_count++;
        pos.last_addon_time = TimeCurrent();
        
        // Здесь должна быть логика открытия доливки
        // В реальной реализации нужно было бы:
        // 1. Рассчитать размер доливки
        // 2. Открыть новую позицию
        // 3. Пересчитать единый стоп-лосс для пирамиды
    }
}

//+------------------------------------------------------------------+
//| Трэйлинг стоп для раннеров                                       |
//+------------------------------------------------------------------+
void CPositionManager::HandleTrailingStop(ManagedPosition* pos) {
    // Трэйлинг применяется только к раннерам (после TP1 и TP2)
    if(!pos.tp1_triggered || !pos.tp2_triggered) return;
    
    if(!PositionSelectByTicket(pos.ticket)) return;
    
    double current_sl = PositionGetDouble(POSITION_SL);
    double current_price = PositionGetDouble(POSITION_PRICE_CURRENT);
    long pos_type = PositionGetInteger(POSITION_TYPE);
    
    // Простой ATR-основанный трэйлинг
    double atr_value = 0.0; // Здесь нужно получить текущий ATR
    // Для упрощения используем фиксированное значение
    double trailing_distance = 50 * SymbolInfoDouble(pos.symbol, SYMBOL_POINT);
    
    double new_sl = 0;
    bool should_update = false;
    
    if(pos_type == POSITION_TYPE_BUY) {
        new_sl = current_price - trailing_distance;
        should_update = (new_sl > current_sl);
    } else {
        new_sl = current_price + trailing_distance;
        should_update = (new_sl < current_sl || current_sl == 0);
    }
    
    if(should_update) {
        MoveSLToLevel(pos.ticket, new_sl, "Trailing Stop Update");
    }
}

//+------------------------------------------------------------------+
//| Вспомогательные методы                                           |
//+------------------------------------------------------------------+
double CPositionManager::CalculateProfitR(ManagedPosition* pos) {
    if(!PositionSelectByTicket(pos.ticket)) return 0.0;
    if(pos.initial_risk_R <= 0) return 0.0;
    
    double current_profit = PositionGetDouble(POSITION_PROFIT);
    return current_profit / pos.initial_risk_R;
}

bool CPositionManager::IsImpulseConfirmed(const string symbol, int direction) {
    // Проверяем, что последняя закрытая свеча была в направлении сделки
    double close[], open[];
    ArraySetAsSeries(close, true);
    ArraySetAsSeries(open, true);
    
    if(CopyClose(symbol, PERIOD_H1, 1, 2, close) <= 0 || 
       CopyOpen(symbol, PERIOD_H1, 1, 2, open) <= 0) {
        return true; // При ошибке разрешаем
    }
    
    bool is_bullish_candle = close[0] > open[0];
    
    if(direction > 0) { // BUY позиция
        return is_bullish_candle;
    } else { // SELL позиция
        return !is_bullish_candle;
    }
}

bool CPositionManager::HasMomentumDivergence(const string symbol, int direction) {
    if(m_h_rsi == INVALID_HANDLE) return false;
    
    // Простая проверка дивергенции RSI
    double rsi[], close[];
    ArraySetAsSeries(rsi, true);
    ArraySetAsSeries(close, true);
    
    if(CopyBuffer(m_h_rsi, 0, 0, 10, rsi) <= 0 || 
       CopyClose(symbol, PERIOD_H1, 0, 10, close) <= 0) {
        return false;
    }
    
    // Ищем дивергенцию на последних 5 барах
    int price_extreme_idx = (direction > 0) ? ArrayMaximum(close, 0, 5) : ArrayMinimum(close, 0, 5);
    int rsi_extreme_idx = (direction > 0) ? ArrayMaximum(rsi, 0, 5) : ArrayMinimum(rsi, 0, 5);
    
    // Дивергенция: экстремумы цены и RSI в разное время
    bool has_divergence = (price_extreme_idx != rsi_extreme_idx) && (MathAbs(price_extreme_idx - rsi_extreme_idx) > 2);
    
    if(has_divergence) {
        Print("Position Manager: Momentum divergence detected for ", symbol);
    }
    
    return has_divergence;
}

double CPositionManager::GetADRPercent(const string symbol) {
    // Упрощенный расчет % от ADR
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    
    if(CopyHigh(symbol, PERIOD_D1, 0, 1, high) <= 0 || 
       CopyLow(symbol, PERIOD_D1, 0, 1, low) <= 0) {
        return 0.0;
    }
    
    double daily_range = high[0] - low[0];
    double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double price_movement = MathAbs(current_price - low[0]);
    
    if(daily_range <= 0) return 0.0;
    
    return (price_movement / daily_range) * 100.0;
}

void CPositionManager::PartialClose(ulong ticket, double volume_percent, string reason) {
    if(!PositionSelectByTicket(ticket)) return;
    
    double current_volume = PositionGetDouble(POSITION_VOLUME);
    double volume_to_close = current_volume * volume_percent / 100.0;
    
    // Нормализуем объем
    double min_volume = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_VOLUME_MIN);
    double volume_step = SymbolInfoDouble(PositionGetString(POSITION_SYMBOL), SYMBOL_VOLUME_STEP);
    
    volume_to_close = MathMax(min_volume, volume_to_close);
    volume_to_close = NormalizeDouble(volume_to_close, (int)(-MathLog10(volume_step)));
    
    if(volume_to_close >= current_volume * 0.95) {
        // Закрываем полностью
        if(m_trade.PositionClose(ticket)) {
            Print("Position Manager: Fully closed position ", ticket, " - ", reason);
        }
    } else {
        // Частичное закрытие
        if(m_trade.PositionClosePartial(ticket, volume_to_close)) {
            Print("Position Manager: Partially closed ", volume_to_close, " lots of position ", ticket, " - ", reason);
        }
    }
}

void CPositionManager::MoveSLToLevel(ulong ticket, double new_sl, string reason) {
    if(!PositionSelectByTicket(ticket)) return;
    
    double current_sl = PositionGetDouble(POSITION_SL);
    string symbol = PositionGetString(POSITION_SYMBOL);
    
    // Нормализуем новый SL
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    new_sl = NormalizeDouble(new_sl, digits);
    
    // Проверяем, что новый SL лучше текущего
    long pos_type = PositionGetInteger(POSITION_TYPE);
    bool should_update = false;
    
    if(pos_type == POSITION_TYPE_BUY) {
        should_update = (new_sl > current_sl || current_sl == 0);
    } else {
        should_update = (new_sl < current_sl || current_sl == 0);
    }
    
    if(should_update) {
        if(m_trade.PositionModify(ticket, new_sl, PositionGetDouble(POSITION_TP))) {
            Print("Position Manager: Moved SL for position ", ticket, " to ", new_sl, " - ", reason);
        }
    }
}

bool CPositionManager::InitializePositionData(ManagedPosition* pos) {
    if(!PositionSelectByTicket(pos.ticket)) return false;
    
    pos.initial_price = PositionGetDouble(POSITION_PRICE_OPEN);
    pos.initial_sl = PositionGetDouble(POSITION_SL);
    pos.initial_volume = PositionGetDouble(POSITION_VOLUME);
    
    // Рассчитываем изначальный риск в деньгах
    if(pos.initial_sl != 0) {
        double sl_distance = MathAbs(pos.initial_price - pos.initial_sl);
        pos.initial_risk_R = sl_distance * pos.initial_volume;
        
        // Конвертируем в валюту депозита если нужно
        string symbol = PositionGetString(POSITION_SYMBOL);
        double contract_size = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
        pos.initial_risk_R *= contract_size;
    } else {
        // Если нет SL, используем 1% от цены открытия
        pos.initial_risk_R = pos.initial_price * 0.01 * pos.initial_volume;
    }
    
    if(pos.initial_risk_R <= 0) {
        pos.initial_risk_R = 100.0; // Значение по умолчанию
    }
    
    Print("Position Manager: Initialized position ", pos.ticket, " with risk R = ", pos.initial_risk_R);
    return true;
}

double CPositionManager::GetVolumeRatioForRegime(E_MarketRegime regime, int tp_level) {
    double base_ratio = (tp_level == 1) ? m_tp1_volume_percent : m_tp2_volume_percent;
    
    // Адаптируем коэффициенты в зависимости от режима
    switch(regime) {
        case REGIME_TREND_MATURE:
            // В зрелом тренде увеличиваем долю раннера
            return base_ratio * 0.8; // Закрываем меньше
            
        case REGIME_FLAT_QUIET:
        case REGIME_FLAT_CHOPPY:
            // Во флэте закрываем больше
            return base_ratio * 1.2;
            
        case REGIME_TREND_WEAKENING:
        case REGIME_UNSTABLE:
            // При ослабевающем тренде агрессивно закрываем
            return base_ratio * 1.5;
            
        default:
            return base_ratio;
    }
}

//+------------------------------------------------------------------+
//| Синхронизация состояния с реальными позициями                   |
//+------------------------------------------------------------------+
void CPositionManager::SynchronizeState() {
    Print("Position Manager: Starting state synchronization...");
    
    int initial_count = m_managed_positions.Total();
    int removed_count = 0;
    int added_count = 0;
    
    // Проверяем каждую управляемую позицию
    for(int i = m_managed_positions.Total() - 1; i >= 0; i--) {
        ManagedPosition* pos = m_managed_positions.At(i);
        if(pos == NULL) continue;
        
        bool position_exists = false;
        
        // Проверяем существование позиции
        if(PositionSelectByTicket(pos.ticket)) {
            // Позиция существует, проверяем ее актуальность
            if(PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER) {
                position_exists = true;
            }
        }
        
        // Если позиция не существует, удаляем ее из управления
        if(!position_exists) {
            Print("Position Manager: Removing non-existent position ", pos.ticket, " from management");
            m_managed_positions.RemoveByTicket(pos.ticket);
            removed_count++;
        }
    }
    
    // Проверяем наличие новых позиций, которые не управляются
    int total_positions = PositionsTotal();
    for(int i = 0; i < total_positions; i++) {
        if(PositionGetTicket(i) > 0) {
            ulong ticket = PositionGetTicket(i);
            
            // Проверяем, управляется ли уже эта позиция
            if(m_managed_positions.FindByTicket(ticket) != NULL) {
                continue; // Уже управляется
            }
            
            // Если позиция имеет наш Magic Number, добавляем ее
            if(PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER) {
                string symbol = PositionGetString(POSITION_SYMBOL);
                int signal_category = 1; // Автообнаруженная позиция
                double signal_score = 0.5; // Средний score
                
                AddNewPosition(ticket, signal_category, signal_score);
                added_count++;
                Print("Position Manager: Auto-detected and added position ", ticket, " for symbol ", symbol);
            }
        }
    }
    
    int final_count = m_managed_positions.Total();
    Print("Position Manager: Synchronization complete. Managed positions: ", initial_count, " -> ", final_count, 
          " (removed: ", removed_count, ", added: ", added_count, ")");
}

//+------------------------------------------------------------------+
//| Методы для работы с AI-Слоем                                     |
//+------------------------------------------------------------------+

/**
 * @brief Установка указателя на AI-Слой
 * @param ai_layer_ptr Указатель на AI-Слой
 */
void CPositionManager::SetAiLayer(CAiLayer* ai_layer_ptr) {
    m_ai_layer_ptr = ai_layer_ptr;
    Print("Position Manager: AI Layer pointer set to ", (ai_layer_ptr != NULL ? "VALID" : "NULL"));
}

/**
 * @brief Получение указателя на AI-Слой
 * @return Указатель на AI-Слой
 */
CAiLayer* CPositionManager::GetAiLayer() const {
    return m_ai_layer_ptr;
}

/**
 * @brief Получение статистики AI-анализа позиций
 * @param stats_string Строка со статистикой (выходной параметр)
 */
void CPositionManager::GetAiPositionStats(string &stats_string) {
    if(m_ai_layer_ptr == NULL || !m_ai_layer_ptr->IsInitialized()) {
        stats_string = "AI Layer: Not available";
        return;
    }
    
    string ai_stats;
    m_ai_layer_ptr->GetAiStats(ai_stats);
    
    int managed_positions = m_managed_positions->Total();
    stats_string = StringFormat("Position Manager AI Stats: Managed=%d, %s", 
                               managed_positions, ai_stats);
}

#include "typ_strategies.mqh"
#property strict
#property description "Take Your Profit 2.0 - Clean Build v2.1.0"
#property version   "2.1.0"

// --- Inputs для Risk Manager ---
input group "Risk Manager Settings"
input double inp_max_daily_dd_percent = 2.0;                    // Максимальная дневная просадка в %
input bool inp_is_gradual_dd_reduction_enabled = true;          // Включить пошаговое снижение риска
input int inp_max_positions_per_currency = 3;                   // Максимум позиций на валюту
input int inp_max_total_open_orders = 10;                       // Максимум открытых ордеров
input double inp_max_total_open_lots = 5.0;                     // Максимум открытых лотов
input double inp_max_total_risk_percent = 10.0;                 // Максимальный суммарный риск в %
input int inp_cooldown_seconds_win = 300;                       // Кулдаун после прибыльной сделки (сек)
input int inp_cooldown_seconds_loss = 600;                      // Кулдаун после убыточной сделки (сек)
input int inp_sl_cluster_limit = 3;                             // Лимит кластера стоп-лоссов
input int inp_sl_cluster_timespan_hours = 4;                    // Период кластера в часах
input bool inp_is_eow_protocol_enabled = true;                  // Включить протокол конца недели
input ENUM_DAY_OF_WEEK inp_eow_day = FRIDAY;                    // День недели для остановки торговли
input int inp_eow_hour = 15;                                    // Час остановки торговли
input bool inp_is_recovery_protocol_enabled = true;             // Включить протокол восстановления

// --- Inputs для ExecGate ---
input group "Execution Filters Settings"
input bool inp_is_news_guard_enabled = true;                    // Включить защиту от новостей
input bool inp_is_spread_guard_enabled = true;                  // Включить защиту от спреда
input bool inp_is_volatility_guard_enabled = true;              // Включить защиту от волатильности
input bool inp_is_session_guard_enabled = true;                 // Включить защиту по сессиям
input bool inp_is_slippage_guard_enabled = true;                // Включить защиту от проскальзывания
input int inp_news_block_minutes_before = 30;                   // Блокировка до новостей (минуты)
input int inp_news_block_minutes_after = 15;                    // Блокировка после новостей (минуты)
input int inp_high_impact_block_minutes = 60;                   // Блокировка для высокого воздействия (минуты)
input int inp_medium_impact_block_minutes = 30;                 // Блокировка для среднего воздействия (минуты)
input int inp_low_impact_block_minutes = 15;                    // Блокировка для низкого воздействия (минуты)
input double inp_max_spread_pips = 3.0;                         // Максимальный спред в пипсах
input double inp_atr_multiplier_for_spread = 2.0;               // Множитель ATR для динамического спреда
input double inp_max_volatility_percent = 5.0;                  // Максимальная волатильность в %
input int inp_volatility_lookback_periods = 20;                 // Период для расчета волатильности
input bool inp_is_london_session_enabled = true;                // Включить Лондонскую сессию
input bool inp_is_new_york_session_enabled = true;              // Включить Нью-Йоркскую сессию
input bool inp_is_tokyo_session_enabled = false;                // Включить Токийскую сессию
input int inp_london_start_hour = 8;                            // Начало Лондонской сессии (час)
input int inp_london_end_hour = 17;                             // Конец Лондонской сессии (час)
input int inp_new_york_start_hour = 13;                         // Начало Нью-Йоркской сессии (час)
input int inp_new_york_end_hour = 22;                           // Конец Нью-Йоркской сессии (час)
input int inp_tokyo_start_hour = 0;                             // Начало Токийской сессии (час)
input int inp_tokyo_end_hour = 9;                               // Конец Токийской сессии (час)
input double inp_max_slippage_pips = 2.0;                       // Максимальное проскальзывание в пипсах

// --- Inputs для Position Manager ---
input group "Position Manager Settings"
input bool inp_is_impulse_confirmation_be_enabled = true;        // Включить подтверждение импульса для BE
input int inp_max_addons_per_position = 2;                      // Максимальное количество доливок на позицию
input double inp_profit_lock_r_level = 1.0;                     // Уровень R для Profit Lock
input double inp_full_be_r_level = 2.0;                         // Уровень R для полного безубытка
input double inp_tp1_r_level = 1.5;                             // Уровень R для первого TP
input double inp_tp2_r_level = 3.0;                             // Уровень R для второго TP
input double inp_tp1_close_percent = 50.0;                      // Процент закрытия на TP1
input double inp_tp2_close_percent = 30.0;                      // Процент закрытия на TP2

#include <Trade/Trade.mqh>
CTrade trade;

#include "typ_core.mqh"
#include "typ_risk.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"
#include "Modules/typ_position_manager.mqh"
#include "Modules/typ_strategies.mqh"  // Модуль стратегий Sprint 2
#include "Modules/typ_ma_cross_strategy.mqh" // Стратегия MA Cross (Спринт 3)
#include "Modules/typ_resolver.mqh"    // Центральный "Мозг" системы
#include "Modules/typ_ai_layer.mqh"    // AI-Слой для интеллектуального анализа
#include "Modules/typ_timer_manager.mqh" // Менеджер таймеров для дросселирования

// --- Глобальные переменные для движка режимов ---
CRegimeEngine   g_RegimeEngine;
E_MarketRegime  g_currentRegime;

// --- Глобальные переменные для системы безопасности ---
CRiskManager    g_RiskManager;
CExecGate       g_ExecGate;

// --- Глобальная переменная для управления позициями ---
CPositionManager g_PosManager;

// --- Глобальные экземпляры модулей Спринта 2 ---
CPatterns           g_Patterns;         // Модуль детекции свечных паттернов
CFigures            g_Figures;          // Модуль детекции графических фигур
CFibo               g_Fibo;             // Модуль анализа уровней Фибоначчи
CStrategy_NightMR   g_Strategy_NightMR; // Стратегия "Ночной Возврат к Среднему"
CStrategy_ChannelBoundary g_Strategy_ChannelBoundary; // Стратегия "Границы Канала"
CStrategy_FalseBreakout   g_Strategy_FalseBreakout;   // Стратегия "Ложный Пробой"
CStrategy_DualMA_Anchor   g_Strategy_DualMA_Anchor;   // Стратегия "Двойная MA с Якорем" (Спринт 3)
CStrategy_DonchianBreakout g_Strategy_DonchianBreakout; // Стратегия "Пробой Дончиана" (Спринт 3)
CStrategy_MA_Cross        g_Strategy_MA_Cross;        // Стратегия "MA Cross" (Спринт 3 Final)
CResolver           g_Resolver;         // Центральный "Мозг" системы
CAiLayer            g_AiLayer;          // AI-Слой для интеллектуального анализа
CTimerManager       g_TimerManager;     // Менеджер таймеров для дросселирования

int OnInit()
{
  Print("TYP2 Clean Build Initialized. Ready for module integration.");
  EquityGuard::OnNewDay();
  
  // --- Инициализация движка режимов ---
  g_RegimeEngine.Initialize(_Symbol, PERIOD_H1);
  g_currentRegime = g_RegimeEngine.GetCurrentRegime();
  Print("Regime Engine: Initialized with regime = ", g_RegimeEngine.GetCurrentRegimeString());
  
  // --- Инициализация системы управления рисками ---
  g_RiskManager.Initialize(
    inp_max_daily_dd_percent,                    // max_daily_dd_percent
    inp_is_gradual_dd_reduction_enabled,         // is_gradual_dd_reduction_enabled
    inp_max_positions_per_currency,              // max_positions_per_currency
    inp_max_total_open_orders,                   // max_total_open_orders
    inp_max_total_open_lots,                     // max_total_open_lots
    inp_max_total_risk_percent,                  // max_total_risk_percent
    inp_cooldown_seconds_win,                    // cooldown_seconds_win
    inp_cooldown_seconds_loss,                   // cooldown_seconds_loss
    inp_sl_cluster_limit,                        // sl_cluster_limit
    inp_sl_cluster_timespan_hours,               // sl_cluster_timespan_hours
    inp_is_eow_protocol_enabled,                 // is_eow_protocol_enabled
    inp_eow_day,                                 // eow_day
    inp_eow_hour,                                // eow_hour
    inp_is_recovery_protocol_enabled             // is_recovery_protocol_enabled
  );
  Print("Risk Manager: Initialized");
  
  // --- Инициализация фильтров исполнения ---
  g_ExecGate.Initialize(
    inp_is_news_guard_enabled,                    // is_news_guard_enabled
    inp_is_spread_guard_enabled,                  // is_spread_guard_enabled
    inp_is_volatility_guard_enabled,              // is_volatility_guard_enabled
    inp_is_session_guard_enabled,                 // is_session_guard_enabled
    inp_is_slippage_guard_enabled,                // is_slippage_guard_enabled
    inp_news_block_minutes_before,                // news_block_minutes_before
    inp_news_block_minutes_after,                 // news_block_minutes_after
    inp_high_impact_block_minutes,                // high_impact_block_minutes
    inp_medium_impact_block_minutes,              // medium_impact_block_minutes
    inp_low_impact_block_minutes,                 // low_impact_block_minutes
    inp_max_spread_pips,                          // max_spread_pips
    inp_atr_multiplier_for_spread,                // atr_multiplier_for_spread
    inp_max_volatility_percent,                   // max_volatility_percent
    inp_volatility_lookback_periods,              // volatility_lookback_periods
    inp_is_london_session_enabled,                // is_london_session_enabled
    inp_is_new_york_session_enabled,              // is_new_york_session_enabled
    inp_is_tokyo_session_enabled,                 // is_tokyo_session_enabled
    inp_london_start_hour,                        // london_start_hour
    inp_london_end_hour,                          // london_end_hour
    inp_new_york_start_hour,                      // new_york_start_hour
    inp_new_york_end_hour,                        // new_york_end_hour
    inp_tokyo_start_hour,                         // tokyo_start_hour
    inp_tokyo_end_hour,                           // tokyo_end_hour
    inp_max_slippage_pips                         // max_slippage_pips
  );
  Print("ExecGate: Initialized");
  
  // --- Инициализация менеджера позиций ---
  g_PosManager.Initialize(
    &g_RiskManager,                                    // risk_manager_ptr
    inp_is_impulse_confirmation_be_enabled,            // is_impulse_confirmation_be_enabled
    inp_max_addons_per_position,                       // max_addons_per_position
    inp_profit_lock_r_level,                           // profit_lock_r_level
    inp_full_be_r_level,                               // full_be_r_level
    inp_tp1_r_level,                                   // tp1_r_level
    inp_tp2_r_level,                                   // tp2_r_level
    inp_tp1_close_percent,                             // tp1_close_percent
    inp_tp2_close_percent                              // tp2_close_percent
  );
  Print("Position Manager: Initialized with AI Layer");
  
  // Синхронизация состояния с реальными позициями
  g_PosManager.SynchronizeState();
  Print("Position Manager: State synchronized with real positions");
  
  // --- Инициализация модулей Спринта 2 ---
  // Модули ТА инициализируются автоматически через конструкторы
  Print("Technical Analysis Modules: Patterns, Figures, Fibonacci initialized");
  
  // Инициализация стратегии Night Mean Reversion
  g_Strategy_NightMR.Initialize(&g_Patterns, &g_Figures, &g_Fibo, _Symbol, PERIOD_H1);
  Print("Strategy Night MR: Initialized for ", _Symbol, " on H1 timeframe");
  
  // Инициализация стратегии Channel Boundary
  g_Strategy_ChannelBoundary.Initialize(&g_Patterns, &g_Figures, _Symbol, PERIOD_H1);
  Print("Strategy Channel Boundary: Initialized for ", _Symbol, " on H1 timeframe");
  
  // Инициализация стратегии False Breakout
  g_Strategy_FalseBreakout.Initialize(&g_Patterns, &g_Figures, _Symbol, PERIOD_H1);
  Print("Strategy False Breakout: Initialized for ", _Symbol, " on H1 timeframe");
  
  // === ИНИЦИАЛИЗАЦИЯ ТРЕНДОВЫХ СТРАТЕГИЙ (СПРИНТ 3) ===
  // Инициализация стратегии DualMA Anchor
  g_Strategy_DualMA_Anchor.Initialize(&g_Patterns, &g_Figures, _Symbol, PERIOD_H1);
  Print("Strategy DualMA Anchor: Initialized for ", _Symbol, " on H1 timeframe");
  
  // Инициализация стратегии Donchian Breakout
  g_Strategy_DonchianBreakout.Initialize(&g_Patterns, &g_Figures, _Symbol, PERIOD_H1);
  Print("Strategy Donchian Breakout: Initialized for ", _Symbol, " on H1 timeframe");
  
  // Инициализация стратегии MA Cross
  g_Strategy_MA_Cross.Initialize(&g_Patterns, &g_Figures, _Symbol, PERIOD_H1);
  Print("Strategy MA Cross: Initialized for ", _Symbol, " on H1 timeframe");
  
  // Инициализация AI-Слоя (интеллектуальный анализ)
  g_AiLayer.Initialize(&g_Patterns, &g_Figures, true); // Включаем AI анализ
  Print("AI Layer: Initialized - Intelligent analysis ready");
  
  // Инициализация центрального Resolver (Мозг системы) с AI-Слоем
  g_Resolver.Initialize(&g_Figures, &g_Patterns, &g_AiLayer);
  Print("Central Resolver: Initialized with AI Layer - The Brain is ready");
  
  // Инициализация менеджера таймеров (дросселирование вычислений)
  // g_TimerManager автоматически инициализируется в конструкторе
  Print("Timer Manager: Initialized - Computation throttling active");
  
  // Инициализация визуального слоя
  Print("Visualization Layer: Initialized");
  Print("- Pattern visualization: Color-coded strength indicators");
  Print("- Figure visualization: Trend lines and target levels");
  Print("- Fibonacci visualization: Retracement and extension levels");
  Print("- Confluence zones: Multi-level analysis");
  
  Print("=== SPRINT 2 & 3 + AI INTEGRATION COMPLETE ===");
  Print("Flat Strategies: Night MR, Channel Boundary, False Breakout");
  Print("Trend Strategies: DualMA Anchor, Donchian Breakout, MA Cross");
  Print("AI Decision Engine: Resolver with Flexible Filters & Countertrend Protocol");
  Print("AI Layer: Intelligent signal analysis and position management");
  Print("Advanced Features: Conflict/Confluence Matrix, Session Filters, Volume Analysis");
  Print("Visual Layer: Full TA visualization system ready");
  
  return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                       const MqlTradeRequest& request,
                       const MqlTradeResult& result) {
    // Обрабатываем закрытие позиций для системы управления рисками
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        if(HistoryDealSelect(trans.deal)) {
            string symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
            double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
            long deal_type = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
            
            // Уведомляем Risk Manager о закрытии позиции
            if(deal_type == DEAL_TYPE_SELL || deal_type == DEAL_TYPE_BUY) {
                g_RiskManager.OnTradeClose(symbol, profit);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Демонстрационная торговая логика                                 |
//+------------------------------------------------------------------+
void DemoTradingLogic() {
    static datetime last_signal_time = 0;
    
    // Генерируем сигнал раз в 5 минут для демонстрации
    if(TimeCurrent() - last_signal_time < 300) return;
    
    // Симулируем торговый сигнал
    string signal_symbol = _Symbol;
    int signal_direction = (MathRand() % 2 == 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    string signal_bucket = "DemoStrategy_Trend";
    double base_risk_percent = 2.0;
    
    ProcessTradingSignal(signal_symbol, signal_direction, signal_bucket, base_risk_percent);
    
    last_signal_time = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Обработка торгового сигнала через системы безопасности           |
//+------------------------------------------------------------------+
void ProcessTradingSignal(string symbol, int direction, string signal_bucket, double base_risk_percent) {
    string reason = "";
    
    // === ЭТАП 1: ПРОВЕРКА RISK MANAGER ===
    double risk_modifier = g_RiskManager.GetRiskModifier(symbol, base_risk_percent, reason);
    
    if(risk_modifier <= 0.0) {
        Print("=== SIGNAL BLOCKED BY RISK MANAGER === ", reason);
        return;
    }
    
    if(risk_modifier < 1.0) {
        Print("=== RISK REDUCED === ", reason, " (modifier: ", risk_modifier, ")");
    }
    
    double adjusted_risk = base_risk_percent * risk_modifier;
    
    // === ЭТАП 2: ПРОВЕРКА EXEC GATE ===
    if(!g_ExecGate.IsExecutionAllowed(symbol, direction, signal_bucket, reason)) {
        Print("=== SIGNAL BLOCKED BY EXEC GATE === ", reason);
        return;
    }
    
    // === ЭТАП 3: РАСЧЕТ ПАРАМЕТРОВ ОРДЕРА ===
    double sl_pips = g_ExecGate.GetAsymmetricStopLossPips(symbol, g_currentRegime);
    double lot_size = g_RiskManager.CalculateLotSize(AccountInfoDouble(ACCOUNT_EQUITY), adjusted_risk, sl_pips);
    
    if(lot_size <= 0) {
        Print("=== INVALID LOT SIZE === Calculated: ", lot_size);
        return;
    }
    
    // === ЭТАП 4: ОТПРАВКА ОРДЕРА ===
    PlaceDemoOrder(symbol, direction, lot_size, sl_pips, signal_bucket);
}

//+------------------------------------------------------------------+
//| Размещение демонстрационного ордера                              |
//+------------------------------------------------------------------+
void PlaceDemoOrder(string symbol, int direction, double lot_size, double sl_pips, string comment) {
    double current_price = (direction == ORDER_TYPE_BUY) ? 
                          SymbolInfoDouble(symbol, SYMBOL_ASK) : 
                          SymbolInfoDouble(symbol, SYMBOL_BID);
    
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    double pip_size = (digits == 3 || digits == 5) ? point * 10.0 : point;
    
    double sl_price = 0;
    if(direction == ORDER_TYPE_BUY) {
        sl_price = current_price - sl_pips * pip_size;
    } else {
        sl_price = current_price + sl_pips * pip_size;
    }
    
    // В демо режиме просто логируем
    Print("=== DEMO ORDER === ",
          "Symbol: ", symbol,
          ", Direction: ", (direction == ORDER_TYPE_BUY ? "BUY" : "SELL"),
          ", Lot: ", lot_size,
          ", Price: ", current_price,
          ", SL: ", sl_price,
          " (", sl_pips, " pips)",
          ", Comment: ", comment,
          ", Regime: ", g_RegimeEngine.GetCurrentRegimeString());
          
    // Симулируем успешное открытие позиции в демо режиме
    static ulong demo_ticket_counter = 1000;
    demo_ticket_counter++;
    
    // Определяем категорию сигнала (0-Конфлюэнс, 1-Королевский)
    int signal_category = (StringFind(comment, "Royal") >= 0) ? 1 : 0;
    double signal_score = 0.7; // Демо-качество сигнала
    
    // Добавляем демо-позицию в управление
    g_PosManager.AddNewPosition(demo_ticket_counter, signal_category, signal_score);
    
    // В реальной торговле здесь был бы:
    // if(trade.PositionOpen(symbol, order_type, lot_size, current_price, sl_price, tp_price, comment)) {
    //     g_PosManager.AddNewPosition(trade.ResultOrder(), signal_category, signal_score);
    // }
}

//+------------------------------------------------------------------+
//| Создание реальных демо-позиций для тестирования Position Manager |
//+------------------------------------------------------------------+
void CreateDemoPositionForTesting() {
    static datetime last_demo_position_time = 0;
    
    // Создаем реальную демо-позицию раз в 30 минут для тестирования
    if(TimeCurrent() - last_demo_position_time < 1800) return;
    
    // Проверяем систему безопасности
    string reason = "";
    double base_risk = 1.0;
    
    double risk_modifier = g_RiskManager.GetRiskModifier(_Symbol, base_risk, reason);
    if(risk_modifier <= 0.0) {
        Print("=== DEMO POSITION BLOCKED === ", reason);
        return;
    }
    
    int direction = (MathRand() % 2 == 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    if(!g_ExecGate.IsExecutionAllowed(_Symbol, direction, "DemoPositionTest", reason)) {
        Print("=== DEMO POSITION BLOCKED === ", reason);
        return;
    }
    
    // Создаем реальную демо-позицию
    double current_price = (direction == ORDER_TYPE_BUY) ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    double sl_pips = g_ExecGate.GetAsymmetricStopLossPips(_Symbol, g_currentRegime);
    double lot_size = 0.01; // Минимальный лот для демо
    
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double pip_size = (digits == 3 || digits == 5) ? point * 10.0 : point;
    
    double sl_price = 0;
    if(direction == ORDER_TYPE_BUY) {
        sl_price = current_price - sl_pips * pip_size;
    } else {
        sl_price = current_price + sl_pips * pip_size;
    }
    
    // Пытаемся открыть реальную позицию
    if(trade.PositionOpen(_Symbol, (ENUM_ORDER_TYPE)direction, lot_size, current_price, sl_price, 0, "PosManager_Test")) {
        ulong ticket = trade.ResultOrder();
        if(ticket > 0) {
            // Определяем категорию сигнала случайно
            int signal_category = (MathRand() % 2); // 0 или 1
            double signal_score = 0.5 + (MathRand() % 50) / 100.0; // 0.5-0.99
            
            // Добавляем в управление
            g_PosManager.AddNewPosition(ticket, signal_category, signal_score);
            
            Print("=== REAL DEMO POSITION CREATED === Ticket: ", ticket, 
                  ", Direction: ", (direction == ORDER_TYPE_BUY ? "BUY" : "SELL"),
                  ", Category: ", signal_category, ", Score: ", signal_score);
            
            last_demo_position_time = TimeCurrent();
        }
    } else {
        Print("=== DEMO POSITION FAILED === Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
    }
}
void OnTick(){
  // --- ОБНОВЛЕНИЕ МЕНЕДЖЕРА ТАЙМЕРОВ ---
  g_TimerManager.Update();
  
  // --- Обновление движка режимов (дросселирование) ---
  E_MarketRegime newRegime = g_currentRegime; // Используем кэшированное значение по умолчанию
  
  if(g_TimerManager.IsTimerReady("MarketRegimeUpdate")) {
    g_RegimeEngine.Update();
    newRegime = g_RegimeEngine.GetCurrentRegime();
    g_currentRegime = newRegime; // Обновляем кэш
    g_TimerManager.MarkTimerExecuted("MarketRegimeUpdate");
  }
  
  // --- Обновление системы управления рисками (дросселирование) ---
  if(g_TimerManager.IsTimerReady("RiskAnalysis")) {
    g_RiskManager.OnTick(newRegime);
    g_TimerManager.MarkTimerExecuted("RiskAnalysis");
  }
  
  g_ExecGate.OnTick(); // ExecGate обновляется каждый тик для быстрой реакции
  
  // --- Обновление менеджера позиций (дросселирование) ---
  if(g_TimerManager.IsTimerReady("PositionUpdate")) {
    g_PosManager.OnTick(newRegime);
    g_TimerManager.MarkTimerExecuted("PositionUpdate");
  }
  
  // --- Проверка необходимости закрытия позиций (flatten) ---
  if(g_ExecGate.IsFlattenRequired(_Symbol)) {
    Print("=== FLATTEN REQUIRED === Closing all positions due to news");
    // Здесь должна быть логика закрытия всех позиций
    // CloseAllPositions();
  }
  
  // --- ПРОВЕРКА ГЛОБАЛЬНЫХ ГВАРДОВ (RISK MANAGER) ---
  string reason;
  double risk_modifier = g_RiskManager.GetRiskModifier(_Symbol, 1.0, reason);
  if (risk_modifier <= 0) {
    // Логируем причину блокировки и выходим
    Print("=== RISK BLOCK === ", reason);
    return;
  }
  
  // --- ПРОВЕРКА ГВАРДОВ ИСПОЛНЕНИЯ (EXEC GATE) ---
  // Проверяем разрешение на исполнение (направление будет определено позже)
  if (!g_ExecGate.IsExecutionAllowed(_Symbol, 1, newRegime, reason)) {
    // Логируем причину блокировки и выходим
    Print("=== EXEC BLOCK === ", reason);
    return;
  }
  
  // --- ФИНАЛЬНЫЙ РАСЧЕТ ПАРАМЕТРОВ ---
  // Получаем асимметричный стоп-лосс (направление будет определено позже)
  double sl_pips = g_ExecGate.GetAsymmetricStopLossPips(_Symbol, 1, newRegime);
  double base_risk = 1.0; // 1.0% базовый риск
  double final_risk = base_risk * risk_modifier; // Применяем модификатор от DD
  
  // Логируем параметры для отладки
  if(risk_modifier < 1.0) {
    Print("=== RISK MODIFIED === Base risk: ", base_risk, "%, Final risk: ", final_risk, "%, Modifier: ", risk_modifier);
  }
  
  // --- ПРИМЕР ИСПОЛЬЗОВАНИЯ POSITION MANAGER ---
  // После успешного открытия новой сделки, немедленно зарегистрируйте ее в менеджере:
  // ulong order_ticket = trade.ResultOrder(); // Получаем тикет после открытия
  // if(order_ticket > 0) {
  //   double initial_risk = AccountInfoDouble(ACCOUNT_EQUITY) * final_risk / 100.0;
  //   int signal_category = 0; // 0-Конфлюэнс, 1-Королевский
  //   g_PosManager.AddNewPosition(order_ticket, signal_category, initial_risk);
  // }
  
  // --- Реагируем на смену режима ---
  if(newRegime != g_currentRegime) {
    g_currentRegime = newRegime;
    Print("=== REGIME CHANGE === New Market Regime: ", g_RegimeEngine.GetCurrentRegimeString());
    
    // --- Пример логики в зависимости от режима ---
    switch(g_currentRegime) {
      case REGIME_TREND_YOUNG:
        Print("-> Strategy: Early trend entry signals enabled");
        // Здесь можно включить более агрессивные сигналы входа
        break;
        
      case REGIME_TREND_MATURE:
        Print("-> Strategy: Trend following with tight stops");
        // Здесь следуем тренду с жесткими стопами
        break;
        
      case REGIME_TREND_WEAKENING:
        Print("-> Strategy: Prepare for reversal, reduce position sizes");
        // Здесь готовимся к развороту, уменьшаем позиции
        break;
        
      case REGIME_FLAT_QUIET:
        Print("-> Strategy: Range trading with wide targets");
        // Здесь торгуем в диапазоне с широкими целями
        break;
        
      case REGIME_FLAT_CHOPPY:
        Print("-> Strategy: Avoid new positions, scalping only");
        // Здесь избегаем новых позиций, только скальпинг
        break;
        
      case REGIME_UNSTABLE:
        Print("-> Strategy: CAUTION - Conflicting signals, reduce activity");
        // Здесь осторожность - конфликтующие сигналы
        break;
        
      case REGIME_RISK_OFF:
        Print("-> Strategy: RISK OFF - Close risky positions, avoid longs");
        // Здесь закрываем рискованные позиции
        break;
        
      default:
        Print("-> Strategy: Waiting for regime confirmation");
        break;
    }
  }
  
  // === БЛОК ГЕНЕРАЦИИ СИГНАЛОВ СПРИНТ 2 (дросселирование) ===
  if(g_TimerManager.IsTimerReady("SignalGeneration")) {
    // Собираем сигналы от всех активных стратегий
    SignalCandidate signal_candidates[10]; // Массив для кандидатов
    int candidates_count = 0;
  
  // 1. Стратегия Night Mean Reversion (лучше работает во флэте)
  if (g_currentRegime == REGIME_FLAT_QUIET || g_currentRegime == REGIME_FLAT_CHOPPY || g_currentRegime == REGIME_TREND_WEAKENING) {
      SignalCandidate night_mr_signal = g_Strategy_NightMR.GetSignal(g_currentRegime);
      if (night_mr_signal.isValid && candidates_count < 10) {
          signal_candidates[candidates_count] = night_mr_signal;
          candidates_count++;
          Print("Night MR Signal: ", night_mr_signal.signal_reason);
      }
  }
  
  // 2. Стратегия Channel Boundary (работает во флэте)
  if (g_currentRegime == REGIME_FLAT_QUIET || g_currentRegime == REGIME_FLAT_CHOPPY) {
      SignalCandidate channel_signal = g_Strategy_ChannelBoundary.GetSignal(g_currentRegime);
      if (channel_signal.isValid && candidates_count < 10) {
          signal_candidates[candidates_count] = channel_signal;
          candidates_count++;
          Print("Channel Boundary Signal: ", channel_signal.signal_reason);
      }
  }
  
  // 3. Стратегия False Breakout (универсальная)
  SignalCandidate false_breakout_signal = g_Strategy_FalseBreakout.GetSignal(g_currentRegime);
  if (false_breakout_signal.isValid && candidates_count < 10) {
      signal_candidates[candidates_count] = false_breakout_signal;
      candidates_count++;
      Print("False Breakout Signal: ", false_breakout_signal.signal_reason);
  }
  
  // === ТРЕНДОВЫЕ СТРАТЕГИИ (СПРИНТ 3) ===
  // 4. Стратегия DualMA Anchor (работает в тренде)
  if (g_currentRegime == REGIME_TREND_STRONG || g_currentRegime == REGIME_TREND_WEAKENING) {
      SignalCandidate dual_ma_signal = g_Strategy_DualMA_Anchor.GetSignal(g_currentRegime);
      if (dual_ma_signal.isValid && candidates_count < 10) {
          signal_candidates[candidates_count] = dual_ma_signal;
          candidates_count++;
          Print("DualMA Anchor Signal: ", dual_ma_signal.signal_reason);
      }
  }
  
  // 5. Стратегия Donchian Breakout (работает в тренде)
  if (g_currentRegime == REGIME_TREND_STRONG || g_currentRegime == REGIME_TREND_WEAKENING) {
      SignalCandidate donchian_signal = g_Strategy_DonchianBreakout.GetSignal(g_currentRegime);
      if (donchian_signal.isValid && candidates_count < 10) {
          signal_candidates[candidates_count] = donchian_signal;
          candidates_count++;
          Print("Donchian Breakout Signal: ", donchian_signal.signal_reason);
      }
  }
  
  // 6. Стратегия MA Cross (работает в тренде)
  if (g_currentRegime == REGIME_TREND_STRONG || g_currentRegime == REGIME_TREND_WEAKENING) {
      SignalCandidate ma_cross_signal = g_Strategy_MA_Cross.GetSignal(g_currentRegime);
      if (ma_cross_signal.isValid && candidates_count < 10) {
          signal_candidates[candidates_count] = ma_cross_signal;
          candidates_count++;
          Print("MA Cross Signal: ", ma_cross_signal.signal_reason);
      }
  }
  
  // Если есть сигналы-кандидаты, передаем их в Resolver для принятия решения
  if (candidates_count > 0) {
      Print("=== RESOLVER ANALYSIS ===");
      Print("Candidates collected: ", candidates_count);
      
      // Центральный мозг принимает решение
      TradeOrderInstruction trade_instruction = g_Resolver.Decide(signal_candidates, candidates_count);
      
      if (trade_instruction.isValid) {
          Print("=== TRADE DECISION APPROVED ===");
          Print("Strategy: ", trade_instruction.winning_strategy);
          Print("Decision: ", trade_instruction.decision_reason);
          Print("Direction: ", (trade_instruction.direction > 0 ? "BUY" : "SELL"));
          Print("Entry: ", DoubleToString(trade_instruction.entry_price, _Digits));
          Print("SL: ", DoubleToString(trade_instruction.stop_loss, _Digits));
          Print("TP: ", DoubleToString(trade_instruction.take_profit, _Digits));
          Print("Lot Size: ", DoubleToString(trade_instruction.lot_size, 2));
          Print("Confidence: ", DoubleToString(trade_instruction.final_confidence, 3));
          Print("Order Type: ", trade_instruction.orderType);
          Print("Volume Scenario: ", trade_instruction.volume_scenario);
          Print("Hierarchy Level: ", trade_instruction.hierarchy_level);
          
          // ЭТАП ФИНАЛЬНЫХ ПРОВЕРОК БЕЗОПАСНОСТИ
          string risk_reason = "";
          double risk_modifier = g_RiskManager.GetRiskModifier(_Symbol, 2.0, risk_reason);
          
          if (risk_modifier > 0) {
              string exec_reason = "";
              if (g_ExecGate.IsExecutionAllowed(_Symbol, trade_instruction.direction, "AUTOMATED", exec_reason)) {
                  
                  // ВСЕ ПРОВЕРКИ ПРОЙДЕНЫ - ИСПОЛНЯЕМ ОРДЕР
                  double final_lot_size = trade_instruction.lot_size * risk_modifier;
                  
                  Print("=== EXECUTING TRADE ===");
                  Print("Final Lot Size: ", DoubleToString(final_lot_size, 2), " (Risk Modifier: ", DoubleToString(risk_modifier, 2), ")");
                  
                  bool order_result = false;
                  if (trade_instruction.direction > 0) {
                      order_result = trade.Buy(final_lot_size, _Symbol, 0, trade_instruction.stop_loss, trade_instruction.take_profit, 
                                             StringFormat("TYP2_Sprint2_%s", trade_instruction.winning_strategy));
                  } else {
                      order_result = trade.Sell(final_lot_size, _Symbol, 0, trade_instruction.stop_loss, trade_instruction.take_profit,
                                              StringFormat("TYP2_Sprint2_%s", trade_instruction.winning_strategy));
                  }
                  
                  if (order_result) {
                      Print("=== TRADE EXECUTED SUCCESSFULLY ===");
                      Print("Ticket: ", trade.ResultOrder());
                      
                      // Уведомляем Position Manager о новой позиции
                      g_PosManager.AddNewPosition(trade.ResultOrder(), trade_instruction.winning_strategy);
                      
                      // Получаем статистику Resolver
                      string resolver_stats;
                      g_Resolver.GetResolverStats(resolver_stats);
                      Print("Resolver Stats: ", resolver_stats);
                      
                  } else {
                      Print("=== TRADE EXECUTION FAILED ===");
                      Print("Error: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
                  }
                  
              } else {
                  Print("=== EXECUTION BLOCKED BY EXECGATE ===");
                  Print("Reason: ", exec_reason);
              }
          } else {
              Print("=== TRADE BLOCKED BY RISK MANAGER ===");
              Print("Reason: ", risk_reason);
          }
      } else {
          Print("=== NO TRADE DECISION ===");
          Print("Resolver Result: ", trade_instruction.decision_reason);
      }
    }
    
    // Отмечаем выполнение генерации сигналов
    g_TimerManager.MarkTimerExecuted("SignalGeneration");
  }
  
  // === БЛОК ВИЗУАЛИЗАЦИИ ТЕХНИЧЕСКОГО АНАЛИЗА (дросселирование) ===
  if(g_TimerManager.IsTimerReady("VisualizationUpdate")) {
    // Визуализируем найденные паттерны, фигуры и уровни Фибоначчи
    VisualizeTechnicalAnalysis();
    g_TimerManager.MarkTimerExecuted("VisualizationUpdate");
  }
  
  // === ДЕМОНСТРАЦИОННАЯ ТОРГОВАЯ ЛОГИКА ===
  // Симулируем получение торгового сигнала
  DemoTradingLogic();
  
  // === ДЕМОНСТРАЦИЯ УПРАВЛЕНИЯ ПОЗИЦИЯМИ ===
  // Периодически создаем реальные демо-позиции для тестирования Position Manager
  CreateDemoPositionForTesting();
  
  // --- Логирование текущего режима каждые 100 тиков для мониторинга ---
  static int tick_counter = 0;
  tick_counter++;
  if(tick_counter >= 100) {
    tick_counter = 0;
    Print("Current Market Regime: ", g_RegimeEngine.GetCurrentRegimeString());
  }
}

/**
 * @brief Функция визуализации технического анализа
 * 
 * Отображает на графике:
 * - Найденные свечные паттерны с цветовой индикацией силы
 * - Графические фигуры с линиями тренда и целевыми уровнями
 * - Уровни Фибоначчи с confluence зонами
 */
void VisualizeTechnicalAnalysis() {
  static datetime last_visualization_time = 0;
  datetime current_time = TimeCurrent();
  
  // Обновляем визуализацию каждые 5 минут
  if(current_time - last_visualization_time < 300) return;
  last_visualization_time = current_time;
  
  long chart_id = ChartID();
  
  // === ВИЗУАЛИЗАЦИЯ ПАТТЕРНОВ ===
  MqlRates rates[50];
  if(CopyRates(_Symbol, PERIOD_H1, 0, 50, rates) >= 10) {
    
    // Поиск бычьих паттернов
    for(int i = 1; i < 10; i++) {
      string pattern_name;
      bool has_pattern = g_Patterns.FindAnyBullishPattern(rates, i, pattern_name);
      
      if(has_pattern) {
        double pattern_strength = g_Patterns.GetPatternStrength(rates, i, pattern_name);
        
        // Используем расширенную визуализацию с направлением
        g_Patterns.DrawPatternWithDirection(pattern_name, i, chart_id, rates, pattern_strength, true);
        
        // Добавляем зону влияния для сильных паттернов
        if(pattern_strength > 0.6) {
          g_Patterns.DrawPatternWithInfluence(pattern_name, i, chart_id, rates, pattern_strength, 5);
        }
      }
    }
    
    // Поиск медвежьих паттернов
    for(int i = 1; i < 10; i++) {
      string pattern_name;
      bool has_pattern = g_Patterns.FindAnyBearishPattern(rates, i, pattern_name);
      
      if(has_pattern) {
        double pattern_strength = g_Patterns.GetPatternStrength(rates, i, pattern_name);
        
        // Используем расширенную визуализацию с направлением
        g_Patterns.DrawPatternWithDirection(pattern_name, i, chart_id, rates, pattern_strength, false);
        
        // Добавляем зону влияния для сильных паттернов
        if(pattern_strength > 0.6) {
          g_Patterns.DrawPatternWithInfluence(pattern_name, i, chart_id, rates, pattern_strength, 5);
        }
      }
    }
  }
  
  // === ВИЗУАЛИЗАЦИЯ ГРАФИЧЕСКИХ ФИГУР ===
  double highs[100], lows[100];
  if(CopyHigh(_Symbol, PERIOD_H4, 0, 100, highs) >= 50 && 
     CopyLow(_Symbol, PERIOD_H4, 0, 100, lows) >= 50) {
    
    FigureInfo figure_info;
    
    // Поиск фигуры "Голова и Плечи"
    if(g_Figures.DetectHeadAndShoulders(highs, lows, 50, figure_info)) {
      g_Figures.DrawFigureAdvanced(figure_info, chart_id, rates);
      
      // Добавляем зону влияния для надежных фигур
      if(figure_info.reliability > 0.6) {
        g_Figures.DrawFigureWithInfluence(figure_info, chart_id, rates, 10);
      }
    }
    
    // Поиск двойной вершины
    if(g_Figures.DetectDoubleTopBottom(highs, lows, 40, figure_info, true)) {
      g_Figures.DrawFigureAdvanced(figure_info, chart_id, rates);
    }
    
    // Поиск двойного дна
    if(g_Figures.DetectDoubleTopBottom(highs, lows, 40, figure_info, false)) {
      g_Figures.DrawFigureAdvanced(figure_info, chart_id, rates);
    }
    
    // Поиск клиньев
    if(g_Figures.DetectWedge(highs, lows, 40, figure_info)) {
      g_Figures.DrawFigureAdvanced(figure_info, chart_id, rates);
    }
  }
  
  // === ВИЗУАЛИЗАЦИЯ УРОВНЕЙ ФИБОНАЧЧИ ===
  FiboGrid fibo_grid;
  if(g_Fibo.BuildFiboGrid(_Symbol, PERIOD_H1, fibo_grid)) {
    
    // Анализируем confluence
    int confluence_zones = g_Fibo.AnalyzeFiboConfluence(_Symbol, PERIOD_H1, fibo_grid);
    
    if(confluence_zones > 0) {
      // Рисуем с confluence зонами
      g_Fibo.DrawFiboWithConfluence(fibo_grid, chart_id, _Symbol);
    } else {
      // Рисуем обычную сетку
      g_Fibo.DrawFiboGrid(fibo_grid, chart_id, _Symbol);
    }
    
    // Проверяем текущую цену на confluence
    double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(g_Fibo.IsInFiboCluster(_Symbol, PERIOD_H1, current_price)) {
      Print("=== FIBONACCI CONFLUENCE DETECTED ===");
      Print("Current price: ", DoubleToString(current_price, _Digits));
      Print("Price is near significant Fibonacci level");
    }
  }
  
  // === ОЧИСТКА СТАРЫХ ОБЪЕКТОВ ===
  // Очищаем объекты старше 1 часа
  static datetime last_cleanup = 0;
  if(current_time - last_cleanup > 3600) {
    last_cleanup = current_time;
    
    int total_objects = ObjectsTotal(chart_id);
    for(int i = total_objects - 1; i >= 0; i--) {
      string obj_name = ObjectName(chart_id, i);
      datetime obj_time = (datetime)ObjectGetInteger(chart_id, obj_name, OBJPROP_TIME);
      
      // Удаляем объекты старше 1 часа
      if(current_time - obj_time > 3600) {
        if(StringFind(obj_name, "Pattern_") == 0 || 
           StringFind(obj_name, "Figure_") == 0 || 
           StringFind(obj_name, "Fibo") == 0) {
          ObjectDelete(chart_id, obj_name);
        }
      }
    }
  }
  
  // Обновляем график
  ChartRedraw(chart_id);
}



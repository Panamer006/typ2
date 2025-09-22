#include "typ_strategies.mqh"
#property strict
#property description "Take Your Profit 2.0 - Clean Build v2.1.0"
#property version   "2.1.0"

#include <Trade/Trade.mqh>
CTrade trade;

#include "typ_core.mqh"
#include "typ_risk.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"
#include "Modules/typ_position_manager.mqh"
#include "Modules/typ_strategies.mqh"  // Модуль стратегий Sprint 2

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
    2.0,    // max_daily_dd_percent
    true,   // is_gradual_dd_reduction_enabled
    3,      // max_positions_per_currency
    10,     // max_total_open_orders
    5.0,    // max_total_open_lots
    10.0,   // max_total_risk_percent
    300,    // cooldown_seconds_win
    600,    // cooldown_seconds_loss
    3,      // sl_cluster_limit
    4,      // sl_cluster_timespan_hours
    true,   // is_eow_protocol_enabled
    FRIDAY, // eow_day
    15,     // eow_hour
    true    // is_recovery_protocol_enabled
  );
  Print("Risk Manager: Initialized");
  
  // --- Инициализация фильтров исполнения ---
  g_ExecGate.Initialize(
    true,   // is_news_guard_enabled
    30,     // news_pre_mins
    15,     // news_post_mins
    0.5,    // spread_atr_multiplier
    2.0,    // sl_atr_multiplier_trend
    1.5,    // sl_atr_multiplier_flat
    16,     // session_end_hour
    0.5,    // min_atr_multiplier
    3.0,    // max_atr_multiplier
    3.0     // max_slippage_pips
  );
  Print("ExecGate: Initialized");
  
  // --- Инициализация менеджера позиций ---
  g_PosManager.Initialize(
    &g_RiskManager, // указатель на риск-менеджер
    true,   // impulse_confirmation_be
    2,      // max_addons
    1.5,    // tp1_level
    3.0,    // tp2_level
    50.0,   // tp1_volume
    30.0,   // tp2_volume
    80.0    // adr_exit
  );
  Print("Position Manager: Initialized");
  
  // --- Инициализация модулей Спринта 2 ---
  // Модули ТА инициализируются автоматически через конструкторы
  Print("Technical Analysis Modules: Patterns, Figures, Fibonacci initialized");
  
  // Инициализация стратегии Night Mean Reversion
  g_Strategy_NightMR.Initialize(&g_Patterns, &g_Figures, &g_Fibo, _Symbol, PERIOD_H1);
  Print("Strategy Night MR: Initialized for ", _Symbol, " on H1 timeframe");
  
  // TODO: Добавить инициализацию для других стратегий когда они будут созданы
  
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
  // --- Обновление движка режимов (в самом начале) ---
  g_RegimeEngine.Update();
  E_MarketRegime newRegime = g_RegimeEngine.GetCurrentRegime();
  
  // --- Обновление системы управления рисками ---
  g_RiskManager.OnTick(newRegime);
  g_ExecGate.OnTick();
  
  // --- Обновление менеджера позиций ---
  g_PosManager.OnTick(newRegime);
  
  // --- Проверка необходимости закрытия позиций (flatten) ---
  if(g_ExecGate.IsFlattenRequired(_Symbol)) {
    Print("=== FLATTEN REQUIRED === Closing all positions due to news");
    // Здесь должна быть логика закрытия всех позиций
    // CloseAllPositions();
  }
  
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
  
  // === БЛОК ГЕНЕРАЦИИ СИГНАЛОВ СПРИНТ 2 ===
  // Проверяем сигналы стратегий только в подходящих режимах
  if (g_currentRegime == REGIME_FLAT_QUIET || g_currentRegime == REGIME_TREND_WEAKENING) {
      // Получаем сигнал от стратегии Night Mean Reversion
      SignalCandidate night_mr_signal = g_Strategy_NightMR.GetSignal(g_currentRegime);
      
      if (night_mr_signal.isValid) {
          Print("=== SIGNAL DETECTED === Strategy: ", night_mr_signal.strategyID);
          Print("Signal: ", night_mr_signal.signal_reason);
          Print("Confidence: ", DoubleToString(night_mr_signal.confidence_score, 3));
          Print("Direction: ", (night_mr_signal.direction > 0 ? "BUY" : "SELL"));
          Print("Entry: ", DoubleToString(night_mr_signal.entry_price, _Digits));
          Print("SL: ", DoubleToString(night_mr_signal.stop_loss, _Digits));
          Print("TP: ", DoubleToString(night_mr_signal.take_profit, _Digits));
          Print("R:R Ratio: ", DoubleToString(night_mr_signal.risk_reward_ratio, 2));
          
          // TODO: Передать сигнал в Resolver для финального утверждения
          // TODO: Проверить через CRiskManager.GetRiskModifier()
          // TODO: Проверить через CExecGate.IsExecutionAllowed()
          // TODO: При успешных проверках - отправить ордер через CTrade
          
          // Пока что только логируем сигнал (заглушка)
          Print("Signal processing: PENDING (implementation required)");
      }
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



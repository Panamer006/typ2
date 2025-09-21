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

// --- Глобальные переменные для движка режимов ---
CRegimeEngine   g_RegimeEngine;
E_MarketRegime  g_currentRegime;

// --- Глобальные переменные для системы безопасности ---
CRiskManager    g_RiskManager;
CExecGate       g_ExecGate;

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
          
    // Здесь был бы реальный вызов trade.PositionOpen() для реальной торговли
}
void OnTick(){
  // --- Обновление движка режимов (в самом начале) ---
  g_RegimeEngine.Update();
  E_MarketRegime newRegime = g_RegimeEngine.GetCurrentRegime();
  
  // --- Обновление системы управления рисками ---
  g_RiskManager.OnTick(newRegime);
  g_ExecGate.OnTick();
  
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
  
  // === ДЕМОНСТРАЦИОННАЯ ТОРГОВАЯ ЛОГИКА ===
  // Симулируем получение торгового сигнала
  DemoTradingLogic();
  
  // --- Логирование текущего режима каждые 100 тиков для мониторинга ---
  static int tick_counter = 0;
  tick_counter++;
  if(tick_counter >= 100) {
    tick_counter = 0;
    Print("Current Market Regime: ", g_RegimeEngine.GetCurrentRegimeString());
  }
}



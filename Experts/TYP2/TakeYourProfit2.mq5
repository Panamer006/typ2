#include "typ_strategies.mqh"
#property strict
#property description "Take Your Profit 2.0 - Clean Build v2.1.0"
#property version   "2.1.0"

#include <Trade/Trade.mqh>
CTrade trade;

#include "typ_core.mqh"
#include "typ_risk.mqh"
#include "Modules/typ_regime_engine.mqh"

// --- Глобальные переменные для движка режимов ---
CRegimeEngine   g_RegimeEngine;
E_MarketRegime  g_currentRegime;

int OnInit()
{
  Print("TYP2 Clean Build Initialized. Ready for module integration.");
  EquityGuard::OnNewDay();
  
  // --- Инициализация движка режимов ---
  g_RegimeEngine.Initialize(_Symbol, PERIOD_H1);
  g_currentRegime = g_RegimeEngine.GetCurrentRegime();
  Print("Regime Engine: Initialized with regime = ", g_RegimeEngine.GetCurrentRegimeString());
  
  return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason){}
void OnTick(){
  // --- Обновление движка режимов (в самом начале) ---
  g_RegimeEngine.Update();
  E_MarketRegime newRegime = g_RegimeEngine.GetCurrentRegime();
  
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
  
  // --- Логирование текущего режима каждые 100 тиков для мониторинга ---
  static int tick_counter = 0;
  tick_counter++;
  if(tick_counter >= 100) {
    tick_counter = 0;
    Print("Current Market Regime: ", g_RegimeEngine.GetCurrentRegimeString());
  }
}



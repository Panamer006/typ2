//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//|                        Copyright 2025, Panamer006 |
//|                           https://github.com/Panamer006/typ2 |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Panamer006"
#property link      "https://github.com/Panamer006/typ2"
#property version   "1.00"
#property strict

// --- ПРИНУДИТЕЛЬНАЯ СИНХРОНИЗАЦИЯ СТАНДАРТНОЙ БИБЛИОТЕКИ ---
#include <Object.mqh> // --- ДОБАВЬТЕ ЭТУ СТРОКУ

// --- ПОДКЛЮЧАЕМ ВСЕ РЕАЛЬНЫЕ МОДУЛИ ПРОЕКТА ---
#include "Modules/typ_be.mqh"
#include "Modules/typ_bem.mqh"
#include "Modules/typ_ccybias.mqh"
#include "Modules/typ_core.mqh"
#include "Modules/typ_dualma_pro.mqh"
#include "Modules/typ_envelopes.mqh"
#include "Modules/typ_execfilters.mqh"
#include "Modules/typ_exit.mqh"
#include "Modules/typ_fibo_ext.mqh"
#include "Modules/typ_force.mqh"
#include "Modules/typ_parental.mqh"
#include "Modules/typ_resolver_v2.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_rsi_divergence.mqh"
#include "Modules/typ_strategies.mqh"
#include "Modules/typ_triangle.mqh"
#include "Modules/typ_triplescreen.mqh"
#include "Modules/typ_regime_engine.mqh" // <<<--- ИНТЕГРАЦИЯ НОВОГО МОДУЛЯ

// --- ВСЕ INPUT-ПАРАМЕТРЫ БУДУТ ТОЛЬКО ЗДЕСЬ ---
// (пока пусто)

// --- ВСЕ ГЛОБАЛЬНЫЕ ОБЪЕКТЫ БУДУТ ТОЛЬКО ЗДЕСЬ ---
#include <Trade/Trade.mqh>
CTrade trade;

CRegimeEngine   g_RegimeEngine;
E_MarketRegime  g_currentRegime;
// (другие глобальные объекты)

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  Print("TYP2 v6.0.0 (Clean Skeleton) Initialized.");
  
  // --- Инициализация движка режимов ---
  g_RegimeEngine.Initialize(_Symbol, PERIOD_H1);
  g_currentRegime = g_RegimeEngine.GetCurrentRegime();
  Print("Regime Engine: Initialized with regime = ", EnumToString(g_RegimeEngine.GetCurrentRegime()));
  
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  // --- Обновление движка режимов ---
  g_RegimeEngine.Update();
  E_MarketRegime newRegime = g_RegimeEngine.GetCurrentRegime();
  
  // --- Реагируем на смену режима ---
  if(newRegime != g_currentRegime) {
    g_currentRegime = newRegime;
    Print("=== REGIME CHANGE === New Market Regime: ", EnumToString(g_currentRegime));
    
    // --- Пример логики в зависимости от режима ---
    switch(g_currentRegime) {
      case REGIME_TREND_YOUNG:
        Print("-> Strategy: Early trend entry signals enabled");
        break;
        
      case REGIME_TREND_MATURE:
        Print("-> Strategy: Trend following with tight stops");
        break;
        
      case REGIME_TREND_WEAKENING:
        Print("-> Strategy: Prepare for reversal, reduce position sizes");
        break;
        
      case REGIME_FLAT_QUIET:
        Print("-> Strategy: Range trading with wide targets");
        break;
        
      case REGIME_FLAT_CHOPPY:
        Print("-> Strategy: Avoid new positions, scalping only");
        break;
        
      case REGIME_UNSTABLE:
        Print("-> Strategy: CAUTION - Conflicting signals, reduce activity");
        break;
        
      case REGIME_RISK_OFF:
        Print("-> Strategy: RISK OFF - Close risky positions, avoid longs");
        break;
        
      default:
        Print("-> Strategy: Undefined regime - wait for clear signals");
        break;
    }
  }
}
//+------------------------------------------------------------------+


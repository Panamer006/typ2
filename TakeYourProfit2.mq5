//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//+------------------------------------------------------------------+
#property version   "6.0.0"
#property strict

// --- ПОДКЛЮЧАЕМ ВСЕ МОДУЛИ-ЗАГЛУШКИ ---
#include "Modules/typ_core.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"

// --- Глобальные Объекты ---
CRegimeEngine g_regime_engine;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("TYP2 Skeleton Built by Cursor. Ready for development.");
    
    // Инициализация движка режимов рынка
    g_regime_engine.Initialize(_Symbol, PERIOD_CURRENT);
    
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
    // Обновление анализа режима рынка
    g_regime_engine.Update(_Symbol, PERIOD_CURRENT);
    
    // Получение текущего режима для дальнейшего использования
    E_MarketRegime current_regime = g_regime_engine.GetCurrentRegime();
    
    // Временная отладочная информация
    static datetime last_print_time = 0;
    if (TimeCurrent() - last_print_time > 60) { // Печатаем каждую минуту
        string regime_text = "";
        switch(current_regime) {
            case REGIME_TREND_MATURE: regime_text = "TREND_MATURE"; break;
            case REGIME_FLAT_QUIET: regime_text = "FLAT_QUIET"; break;
            case REGIME_UNDEFINED: regime_text = "UNDEFINED"; break;
        }
        Print("Current Market Regime: ", regime_text);
        last_print_time = TimeCurrent();
    }
}
//+------------------------------------------------------------------+
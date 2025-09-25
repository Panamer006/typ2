# Техническое Задание: T2-REFACTOR-SPRINT1 (v2 - Полная Версия)

## 1. Цель
Провести рефакторинг кода Спринта 1 для улучшения читаемости, гибкости и подготовки к будущему расширению.

---

## 2. Задача №1: Рефакторинг `typ_regime_engine.mqh`

**Действие:** Полностью перезаписать файл `MQL5/Experts/TYP2/TakeYourProfit2/Modules/typ_regime_engine.mqh` следующим кодом.

```cpp
// --- typ_regime_engine.mqh ---
#ifndef TYP_REGIME_ENGINE_MQH
#define TYP_REGIME_ENGINE_MQH

#include "typ_core.mqh"

// Enum для Режимов Рынка
enum E_MarketRegime {
    REGIME_TREND_MATURE,
    REGIME_FLAT_QUIET,
    REGIME_UNDEFINED
};

// Класс для определения текущего режима рынка
class CRegimeEngine {
private:
    // --- Пороги индикаторов ---
    double m_adx_trend_threshold; // Порог ADX для определения тренда

    // --- Состояние ---
    E_MarketRegime  m_current_regime;
    datetime        m_last_update_time;

    // --- Хэндлы Индикаторов ---
    int m_h_adx;
    // TODO: Добавить хэндлы для Choppiness, Donchian, Volume, RSI, MACD

public:
    // Конструктор: инициализирует параметры
    CRegimeEngine() : 
        m_adx_trend_threshold(25.0),
        m_current_regime(REGIME_UNDEFINED), 
        m_last_update_time(0), 
        m_h_adx(INVALID_HANDLE) 
    {}

    // Деструктор: освобождает ресурсы
   ~CRegimeEngine() {
        if (m_h_adx != INVALID_HANDLE) IndicatorRelease(m_h_adx);
    }

    // Инициализирует индикаторы
    void Initialize(const string symbol, const ENUM_TIMEFRAMES tf) {
        m_h_adx = iADX(symbol, tf, 14);
        // TODO: Добавить инициализацию других индикаторов
    }

    // Обновляет состояние на каждом тике (если новый бар)
    void Update(const string symbol, const ENUM_TIMEFRAMES tf) {
        datetime current_bar_time = (datetime)SeriesInfoInteger(symbol, tf, SERIES_LASTBAR_DATE);
        if(current_bar_time > m_last_update_time) {
            m_last_update_time = current_bar_time;
            CalculateRegime(symbol, tf); 
        }
    }

    // Возвращает текущий режим рынка (не изменяет состояние)
    E_MarketRegime GetCurrentRegime() const { return m_current_regime; }

private:
    // Рассчитывает режим рынка
    void CalculateRegime(const string symbol, const ENUM_TIMEFRAMES tf) {
        double adx_buffer[];
        if (CopyBuffer(m_h_adx, 0, 1, 1, adx_buffer) > 0) {
            if (adx_buffer > m_adx_trend_threshold) {
                 m_current_regime = REGIME_TREND_MATURE;
            } else {
                 m_current_regime = REGIME_FLAT_QUIET;
            }
        }
    }
};
#endif

# Задача №2: Рефакторинг typ_risk.mqh
Действие: Полностью перезаписать файл MQL5/Experts/TYP2/TakeYourProfit2/Modules/typ_risk.mqh следующим кодом.
code
C++
// --- typ_risk.mqh ---
#ifndef TYP_RISK_MQH
#define TYP_RISK_MQH

#include "typ_core.mqh"
#include <Arrays\ArrayObj.mqh>

// ... (код CSymbolState остается без изменений) ...

// Класс для управления торговыми рисками
class CRiskManager {
private:
    // ... (все параметры и состояние остаются без изменений) ...
    bool m_is_parental_lock_active; // Новый флаг для Parental Lock

public:
    // ... (конструктор, деструктор, Initialize, OnTick, IsRiskOK, CalculateLotSize остаются без изменений) ...

    // Проверяет, активен ли Parental Lock (не изменяет состояние)
    bool IsParentalLockOK(string &reason) const {
        // TODO: Implement full ParentalLock logic using OnTradeTransaction event.
        if (m_is_parental_lock_active) {
            reason = "Parental Lock is active";
            return false;
        }
        return true;
    }
};
#endif
Примечание для Cursor: Тебе нужно будет взять существующий код CRiskManager и добавить в него private-член m_is_parental_lock_active и public-метод IsParentalLockOK.

# Задача №3: Обновление Интеграции в TakeYourProfit2.mq5
Действие: Полностью перезаписать главный файл MQL5/Experts/TYP2/TakeYourProfit2/TakeYourProfit2.mq5 следующим кодом.
code
C++
//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//+------------------------------------------------------------------+
#property version   "6.04" // Версия обновлена
#property strict

// ... (все #include остаются без изменений) ...

// ... (все input-параметры остаются без изменений) ...

// ... (все глобальные объекты остаются без изменений) ...

//+------------------------------------------------------------------+
int OnInit()
{
  Print("TYP2 Initializing Modules (Refactored)...");
  
  // ... (инициализация всех модулей остается без изменений) ...
  
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+
void OnTick()
{
  // ... (обновление модулей остается без изменений) ...
  
  static datetime last_trade_time = 0;
  if (TimeCurrent() - last_trade_time > 3600)
  {
      string reason = "";
      if (g_RiskManager.IsRiskOK(reason) && g_RiskManager.IsParentalLockOK(reason)) // <<<--- ДОБАВЛЕНА ПРОВЕРКА
      {
          if (g_ExecGate.IsExecutionAllowed(reason)) 
          {
              // ... (остальная логика без изменений) ...
          } else {
              Print("ExecGate Block: ", reason);
          }
      } else {
          Print("RiskManager Block: ", reason);
      }
  }
}
//+------------------------------------------------------------------+
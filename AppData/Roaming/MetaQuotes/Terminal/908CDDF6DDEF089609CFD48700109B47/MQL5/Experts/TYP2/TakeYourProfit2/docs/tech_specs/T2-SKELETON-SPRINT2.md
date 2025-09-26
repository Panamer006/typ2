# Техническое Задание: T2-SKELETON-SPRINT2 (v2 - Полная Версия)

## 1. Цель
Создать пустые, но структурно правильные "скелеты" (файлы и классы) для всех модулей Спринта 2.

---

## 2. Задача №1: Создание "Скелетов" Модулей ТА

**Действие:** В папке `MQL5/Experts/TYP2/TakeYourProfit2/Modules/` создать три новых файла.

1.  **Файл `typ_patterns.mqh`:**
    ```cpp
    // --- typ_patterns.mqh ---
    #ifndef TYP_PATTERNS_MQH
    #define TYP_PATTERNS_MQH
    class CPatterns {
    public:
        // Возвращает true, если на баре `shift` есть паттерн "Бычье поглощение"
        bool IsBullishEngulfing(const MqlRates &rates[], int shift) const { return false; }
        // Возвращает true, если на баре `shift` есть паттерн "Медвежье поглощение"
        bool IsBearishEngulfing(const MqlRates &rates[], int shift) const { return false; }
    };
    #endif
    ```

2.  **Файл `typ_figures.mqh`:**
    ```cpp
    // --- typ_figures.mqh ---
    #ifndef TYP_FIGURES_MQH
    #define TYP_FIGURES_MQH
    class CFigures {
    public:
        // Возвращает true, если обнаружена фигура "Голова и Плечи"
        bool DetectHeadAndShoulders() const { return false; }
    };
    #endif
    ```

3.  **Файл `typ_fibo.mqh`:**
    ```cpp
    // --- typ_fibo.mqh ---
    #ifndef TYP_FIBO_MQH
    #define TYP_FIBO_MQH
    class CFibo {
    public:
        // Возвращает true, если цена находится в "кластерной" зоне Фибо
        bool IsInFiboCluster(double price) const { return false; }
    };
    #endif
    ```

---

## 3. Задача №2: Создание "Скелета" Модуля Стратегий

**Действие:** Создать новый файл `MQL5/Experts/TYP2/TakeYourProfit2/Modules/typ_strategies.mqh` со следующим содержимым.

```cpp
// --- typ_strategies.mqh ---
#ifndef TYP_STRATEGIES_MQH
#define TYP_STRATEGIES_MQH

#include "typ_patterns.mqh"
#include "typ_figures.mqh"
#include "typ_fibo.mqh"

// Структура для передачи сигналов-кандидатов
struct SignalCandidate {
    bool   isValid;
    string strategyID;
};

// Класс для стратегии "Ночной Возврат к Среднему"
class CStrategy_NightMR {
private:
    CPatterns* m_patterns; // Указатель на библиотеку паттернов
public:
    void Initialize(CPatterns* patterns_ptr) { m_patterns = patterns_ptr; }
    
    // Метод ищет сигнал и возвращает кандидата
    SignalCandidate GetSignal() const {
        SignalCandidate candidate;
        candidate.isValid = false;
        return candidate;
    }
};
#endif
4. Задача №3: Интеграция в Главный Файл
Действие: Полностью перезаписать главный файл MQL5/Experts/TYP2/TakeYourProfit2/TakeYourProfit2.mq5 следующим кодом.
code
C++
//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//+------------------------------------------------------------------+
#property version   "6.06" // Версия обновлена
#property strict

// --- ПОДКЛЮЧАЕМ ВСЕ МОДУЛИ ---
#include "Modules/typ_core.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"
#include "Modules/typ_pm.mqh"
#include "Modules/typ_chart_objects.mqh"
#include "Modules/typ_strategies.mqh" // <<<--- НОВЫЙ МОДУЛЬ

// --- INPUT ПАРАМЕТРЫ ---
// ... (все input-параметры без изменений)

// --- ГЛОБАЛЬНЫЕ ОБЪЕКТЫ ---
// ... (старые глобальные объекты без изменений)
CPatterns           g_Patterns; // <<<--- НОВЫЙ ОБЪЕКТ
CFigures            g_Figures;  // <<<--- НОВЫЙ ОБЪЕКТ
CFibo               g_Fibo;     // <<<--- НОВЫЙ ОБЪЕКТ
CStrategy_NightMR   g_Strategy_NightMR; // <<<--- НОВЫЙ ОБЪЕКТ

//+------------------------------------------------------------------+
int OnInit()
{
  // ... (старая инициализация без изменений)
  g_Strategy_NightMR.Initialize(&g_Patterns); // <<<--- ИНИЦИАЛИЗАЦИЯ
  
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+
void OnTick()
{
  // ... (старая логика OnTick без изменений)

  // --- БЛОК ГЕНЕРАЦИИ СИГНАЛОВ (ЗАГЛУШКА) ---
  if (g_currentRegime == REGIME_FLAT_QUIET) {
      SignalCandidate night_mr_signal = g_Strategy_NightMR.GetSignal();
      if (night_mr_signal.isValid) {
          // Логика открытия сделки будет здесь
      }
  }
}
//+------------------------------------------------------------------+
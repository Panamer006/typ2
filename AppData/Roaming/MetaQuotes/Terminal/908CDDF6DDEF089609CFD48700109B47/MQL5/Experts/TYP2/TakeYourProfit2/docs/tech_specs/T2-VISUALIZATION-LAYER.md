# Техническое Задание: T2-VISUALIZATION-LAYER (v2 - Адаптированная Версия)

## 1. Цель
Создать **инфраструктуру для будущего Визуального Слоя**. На данном этапе мы создадим только центральный менеджер графических объектов и интегрируем его в советник.

---

## 2. Файл №1: `typ_chart_objects.mqh` (CChartObjectsManager)

**Действие:** Создать новый файл `MQL5/Experts/TYP2/TakeYourProfit2/Modules/typ_chart_objects.mqh` со следующим содержимым.

```cpp
// --- typ_chart_objects.mqh ---
#ifndef TYP_CHART_OBJECTS_MQH
#define TYP_CHART_OBJECTS_MQH

#include <Arrays\ArrayString.h>

// Класс для централизованного управления графическими объектами
class CChartObjectsManager {
private:
    long         m_chart_id;      // ID графика, на котором работаем
    string       m_object_prefix; // Уникальный префикс для всех наших объектов
    CArrayString m_object_names;  // Список имен всех объектов, созданных в текущем тике

public:
    // Конструктор
    CChartObjectsManager() : m_chart_id(0) {
        m_object_prefix = "TYP2_" + (string)MQLInfoInteger(MQL_CHART_ID) + "_";
    }
    
    // Деструктор
   ~CChartObjectsManager() {}

    // Инициализация
    void Initialize(long chart_id) {
        m_chart_id = chart_id;
    }

    // Должен вызываться в начале OnTick()
    void OnTickStart() {
        m_object_names.Clear();
    }
    
    // Должен вызываться в конце OnTick()
    void OnTickEnd() {
        int total = ObjectsTotal(m_chart_id, -1, -1);
        for (int i = total - 1; i >= 0; i--) {
            string name = ObjectName(m_chart_id, i, -1, -1);
            // Если объект наш, но его не было в этом тике - удаляем
            if (StringFind(name, m_object_prefix) == 0 && m_object_names.Search(name) < 0) {
                ObjectDelete(m_chart_id, name);
            }
        }
    }

    // --- Методы для отрисовки (пока заглушки) ---
    
    // Рисует текстовую метку
    void DrawLabel(string name, string text) {
        string full_name = m_object_prefix + name;
        // TODO: Добавить логику ObjectCreate для метки
        m_object_names.Add(full_name);
    }
    
    // Рисует прямоугольник
    void DrawRectangle(string name) {
        string full_name = m_object_prefix + name;
        // TODO: Добавить логику ObjectCreate для прямоугольника
        m_object_names.Add(full_name);
    }
};
#endif
3. Файл №2: TakeYourProfit2.mq5 (Интеграция)
Действие: Полностью перезаписать главный файл MQL5/Experts/TYP2/TakeYourProfit2/TakeYourProfit2.mq5 следующим кодом.
code
C++
//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//+------------------------------------------------------------------+
#property version   "6.05" // Версия обновлена
#property strict

#include "Modules/typ_core.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"
#include "Modules/typ_pm.mqh"
#include "Modules/typ_chart_objects.mqh" // <<<--- ИНТЕГРАЦИЯ НОВОГО МОДУЛЯ

// --- INPUT ПАРАМЕТРЫ ---
input bool InpShowOnChart = true; // <<<--- НОВЫЙ ПАРАМЕТР
// ... (остальные input-параметры без изменений)

// --- ГЛОБАЛЬНЫЕ ОБЪЕКТЫ ---
CChartObjectsManager g_ChartManager; // <<<--- НОВЫЙ ОБЪЕКТ
// ... (остальные глобальные объекты без изменений)

//+------------------------------------------------------------------+
int OnInit()
{
  Print("TYP2 Initializing Modules...");
  
  g_ChartManager.Initialize(ChartID()); // <<<--- ИНИЦИАЛИЗАЦИЯ
  // ... (остальная инициализация без изменений)
  
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+
void OnTick()
{
  if(InpShowOnChart) g_ChartManager.OnTickStart(); // <<<--- ВЫЗОВ В НАЧАЛЕ
  
  // ... (вся основная логика OnTick без изменений) ...
  
  // --- Блок визуализации (пока пустой) ---
  if(InpShowOnChart)
  {
      // TODO: Здесь в будущем будет вызываться отрисовка паттернов и фигур
      g_ChartManager.DrawLabel("test_label", "Regime: " + EnumToString(g_currentRegime));
  }
  
  if(InpShowOnChart) g_ChartManager.OnTickEnd(); // <<<--- ВЫЗОВ В КОНЦЕ
}
//+------------------------------------------------------------------+
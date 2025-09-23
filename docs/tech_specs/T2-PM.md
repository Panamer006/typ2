# Техническое Задание (ТЗ) для Задачи: T2-PM - Position Manager (Реализация с Чистого Листа)

## 1. Цель

Создать **центральный модуль управления позициями `CPositionManager`** в файле `typ_position_manager.mqh`. Этот модуль должен инкапсулировать всю логику сопровождения открытых сделок: от установки SL/TP до безубытка, частичных закрытий и наращивания позиции (пирамидинга), в соответствии с утвержденной спецификацией.

## 2. Пошаговый План Реализации

### **Задача 1: Наполнение Файла `typ_position_manager.mqh`**

1.  **Действие:** Откройте файл `Experts/TYP2/Modules/typ_position_manager.mqh`.
2.  **Действие:** Замените пустой "скелет" класса на **полную структуру**, включающую все необходимые `private`-члены и `public`-методы, как мы обсуждали в нашем утвержденном ТЗ.

    ```cpp
    // --- typ_position_manager.mqh ---
    #include "typ_regime_engine.mqh"
    #include "typ_risk.mqh" // Для "Освобождения Риска"

    // --- Структура для хранения состояния каждой управляемой позиции ---
    class CManagedPosition : public CObject {
    public:
        ulong    ticket;
        string   symbol;
        int      signal_category; // 0-Конфлюэнс, 1-Королевский
        double   initial_risk_R_money; // Размер риска в деньгах при открытии
        int      be_stage; // 0-Нет, 1-Profit Lock, 2-Full BE
        int      tp_stage; // 0-Нет, 1-TP1 взят, 2-TP2 взят
        bool     is_risk_released;
    };

    class CPositionManager {
    private:
        // --- ПАРАМЕТРЫ ---
        bool   m_is_impulse_confirmation_be_enabled;
        int    m_max_addons_per_position;
        
        // --- СОСТОЯНИЕ КЛАССА ---
        CArrayObj*    m_managed_positions;
        CRiskManager* m_risk_manager_ptr;

    public:
        // ... (конструктор, деструктор, Initialize)
        void OnTick(E_MarketRegime current_regime);
        void AddNewPosition(ulong ticket, int signal_category, double initial_risk);

    private:
        void HandleBreakEven(CManagedPosition &pos, E_MarketRegime regime);
        void HandleTakeProfit(CManagedPosition &pos, E_MarketRegime regime);
        void HandleAddons(CManagedPosition &pos, E_MarketRegime regime);
    };
    ```

### **Задача 2: Логика Безубытка (`HandleBreakEven`)**

1.  **Действие:** Реализуйте приватный метод `HandleBreakEven`.
    *   **Логика:**
        1.  Рассчитайте текущую прибыль позиции в R (отношение текущей прибыли к `pos.initial_risk_R_money`).
        2.  **Этап 1: `Profit Lock` (-0.5R).** Если `profit_R >= 1.0` и `pos.be_stage == 0`, переместите SL на уровень `-0.5R`. Установите `pos.be_stage = 1`.
        3.  **Этап 2: Полный Безубыток.** Если `profit_R >= 2.0` и `pos.be_stage == 1`, переместите SL на цену открытия + спред. Установите `pos.be_stage = 2` и вызовите `m_risk_manager_ptr->ReleaseRisk(...)` для "Освобождения Риска".
        4.  **Апгрейд "Подтверждение Импульса":** Если `m_is_impulse_confirmation_be_enabled == true`, то перед перемещением SL на каждом этапе проверяйте, чтобы последняя закрытая свеча была в направлении сделки.

### **Задача 3: Логика Тейк-Профита (`HandleTakeProfit`)**

1.  **Действие:** Реализуйте приватный метод `HandleTakeProfit`.
    *   **Логика:**
        1.  **"Адаптивная Сетка ТП":** Если `profit_R >= 1.5` и `pos.tp_stage == 0`, закройте 50% объема и установите `pos.tp_stage = 1`. Если `profit_R >= 3.0` и `pos.tp_stage == 1`, закройте еще 30% и установите `pos.tp_stage = 2`.
        2.  **Апгрейд "Адаптивное Разделение Объема":** Коэффициенты (50%/30%) и уровни R (1.5/3.0) должны меняться в зависимости от `regime`.
        3.  **Апгрейд "Выход по Затуханию Моментума":** Для "Раннера" (`pos.tp_stage == 2`) отслеживайте дивергенцию на RSI. При ее появлении закройте оставшуюся часть.

### **Задача 4: Логика Доливок (`HandleAddons`)**

1.  **Действие:** Реализуйте приватный метод `HandleAddons`.
    *   **Логика:**
        1.  **Проверка Лимита:** `if (addons_count >= m_max_addons_per_position)` -> `return`.
        2.  **Апгрейд "Контекстное Освобождение Риска":**
            *   `bool is_risk_released = false;`
            *   `if (regime == REGIME_TREND_YOUNG && profit_R >= 1.0) is_risk_released = true;`
            *   `if (regime == REGIME_TREND_MATURE && pos.be_stage == 2) is_risk_released = true;`
            *   `if (!is_risk_released) return;`
        3.  **Ищите сигнал продолжения тренда** (например, пробой локального флага).
        4.  **Если сигнал найден**, сформируйте `SignalCandidate` и передайте его в `Resolver` для утверждения.
        5.  **"Единый Стоп-лосс":** После открытия доливки пересчитайте и модифицируйте SL для всей "пирамиды", чтобы общий итог был не хуже безубытка.

### **Задача 5: Интеграция в `TakeYourProfit2.mq5`**

1.  **Действие:** Создайте глобальный экземпляр `CPositionManager g_PosManager;`.
2.  **Действие:** В `OnInit()` вызовите `g_PosManager.Initialize(&g_RiskManager);`.
3.  **Действие:** В `OnTick()` вызывайте `g_PosManager.OnTick(g_currentRegime);`.
4.  **Действие:** После успешного открытия новой сделки, немедленно **зарегистрируйте** ее в менеджере: `g_PosManager.AddNewPosition(order_ticket, signal_category, initial_risk);`.```
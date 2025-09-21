# Техническое Задание (ТЗ) для Задачи: T2-PM - Position Manager (Детализированная Версия)

## 1. Цель

Создать **центральный модуль управления позициями CPositionManager** в новом файле 	yp_position_manager.mqh. Этот модуль должен инкапсулировать всю логику сопровождения открытых сделок: от установки SL/TP до безубытка, частичных закрытий и наращивания позиции (пирамидинга).

## 2. Пошаговый План Реализации

### **Задача 1: Создание Файла и Базовой Структуры Класса**

1.  **Действие:** Создайте новый файл Experts/TYP2/Modules/typ_position_manager.mqh.
2.  **Действие:** Вставьте в этот файл следующий **базовый "скелет" класса CPositionManager**.

    `cpp
    // --- typ_position_manager.mqh ---
    #include "typ_regime_engine.mqh"
    #include "typ_risk.mqh" // Для "Освобождения Риска"

    // --- Структура для хранения состояния каждой управляемой позиции ---
    struct ManagedPosition {
        ulong    ticket;
        string   symbol;
        int      signal_category; // 0-Конфлюэнс, 1-Королевский
        double   initial_risk_R; // Размер риска в деньгах при открытии
        int      be_stage; // 0-Нет, 1-Profit Lock, 2-Full BE
        bool     is_risk_released;
        // ... (другие параметры для отслеживания)
    };

    class CPositionManager {
    private:
        // --- ПАРАМЕТРЫ ---
        // Tiered BE
        bool   m_is_impulse_confirmation_be_enabled;
        // Add-ons
        int    m_max_addons_per_position;
        
        // --- СОСТОЯНИЕ КЛАССА ---
        CArrayObj* m_managed_positions; // Динамический массив управляемых позиций
        CRiskManager* m_risk_manager_ptr; // Указатель на риск-менеджер

    public:
        // --- Публичные Методы ---
        CPositionManager();
        ~CPositionManager();
        void Initialize(CRiskManager* risk_manager);
        void OnTick(E_MarketRegime current_regime);
        void AddNewPosition(ulong ticket, int signal_category);

    private:
        // --- Приватные Методы-Обработчики ---
        void HandleBreakEven(ManagedPosition* pos, E_MarketRegime regime);
        void HandleTakeProfit(ManagedPosition* pos, E_MarketRegime regime);
        void HandleAddons(ManagedPosition* pos, E_MarketRegime regime);
        void HandleTrailingStop(ManagedPosition* pos);
    };
    `

### **Задача 2: Логика Безубытка (HandleBreakEven)**

1.  **Действие:** Реализуйте приватный метод HandleBreakEven.
    *   **Логика:**
        1.  Рассчитайте текущую прибыль позиции в R (отношение текущей прибыли к первоначальному риску).
        2.  **Этап 1: Profit Lock (-0.5R).** Если profit_R >= 1.0 и pos.be_stage == 0, переместите SL на уровень -0.5R. Установите pos.be_stage = 1.
        3.  **Этап 2: Полный Безубыток.** Если profit_R >= 2.0 и pos.be_stage == 1, переместите SL на цену открытия + спред. Установите pos.be_stage = 2.
        4.  **Апгрейд "Подтверждение Импульса":** Если m_is_impulse_confirmation_be_enabled == true, то перед перемещением SL на каждом этапе проверяйте, чтобы последняя закрытая свеча была в направлении сделки.

### **Задача 3: Логика Тейк-Профита (HandleTakeProfit)**

1.  **Действие:** Реализуйте приватный метод HandleTakeProfit.
    *   **Логика:**
        1.  **"Адаптивная Сетка ТП":** При достижении уровня TP1 (например, +1.5R), закройте 50% объема. При достижении TP2 (например, +3R), закройте еще 30%. Оставшиеся 20% становятся "Раннером".
        2.  **Апгрейд "Адаптивное Разделение Объема":** Коэффициенты (50/30/20) должны меняться в зависимости от egime. В TREND_MATURE доля раннера увеличивается, в FLAT — уменьшается.
        3.  **Апгрейд "Динамический TP по Score":** Расстояние до TP1 и TP2 должно зависеть от pos.signal_category и score (который нужно будет сохранять в ManagedPosition).
        4.  **Апгрейд "ТП по ADR":** Добавьте проверку: если цена достигла 80% от ADR, принудительно закройте еще одну часть позиции.
        5.  **Апгрейд "Выход по Затуханию Моментума":** Для "Раннера" отслеживайте дивергенцию на RSI. При ее появлении закройте оставшуюся часть.

### **Задача 4: Логика Доливок (HandleAddons)**

1.  **Действие:** Реализуйте приватный метод HandleAddons.
    *   **Логика:**
        1.  **Проверка Лимита:** if (addons_count >= m_max_addons_per_position) -> eturn.
        2.  **Апгрейд "Контекстное Освобождение Риска":**
            *   ool is_risk_released = false;
            *   if (regime == REGIME_TREND_YOUNG && profit_R >= 1.0) is_risk_released = true;
            *   if (regime == REGIME_TREND_MATURE && pos.be_stage == 2) is_risk_released = true;
            *   if (!is_risk_released) return;
        3.  **Проверка Сигнала:** Ищите сигнал продолжения тренда (пробой локального экстремума или флага).
        4.  **Проверка Фильтров:** Убедитесь, что нет запрета от NewsGuard и Regime Engine (TREND_WEAKENING).
        5.  Если все проверки пройдены, инициируйте новую сделку-доливку.
        6.  **"Единый Стоп-лосс":** После открытия доливки пересчитайте единый, средневзвешенный SL для всей пирамиды, чтобы общий итог был не хуже безубытка.

### **Задача 5: Интеграция в TakeYourProfit2.mq5**

1.  **Действие:** Создайте глобальный экземпляр CPositionManager g_PosManager;.
2.  **Действие:** В OnInit() вызовите g_PosManager.Initialize(&g_RiskManager);.
3.  **Действие:** В OnTick() вызывайте g_PosManager.OnTick(g_currentRegime);.
4.  **Действие:** После успешного открытия новой сделки, немедленно зарегистрируйте ее в менеджере: g_PosManager.AddNewPosition(order_ticket, signal_category);.

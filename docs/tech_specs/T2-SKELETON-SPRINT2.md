# Техническое Задание (ТЗ) для Задачи: T2-SKELETON-SPRINT2

## 1. Цель

Создать "скелеты" (пустые, но структурно правильные файлы и классы) для всех модулей, запланированных к реализации в Спринте 2. Это включает модули для "Ночного Двигателя" и "Контекстного Технического Анализа".

## 2. Пошаговый План Реализации

### **Задача 1: Создание "Каркаса" для Модулей ТА**

1.  **Действие:** Создайте новый файл `Experts/TYP2/Modules/typ_patterns.mqh`.
    *   **Содержимое:** Добавьте в него "скелет" класса для детекции свечных паттернов.
        ```cpp
        // --- typ_patterns.mqh ---
        class CPatterns {
        public:
            // Возвращает true, если на баре `shift` есть паттерн "Бычье поглощение"
            bool IsBullishEngulfing(const MqlRates &rates[], int shift) const { return false; }
            // Возвращает true, если на баре `shift` есть паттерн "Медвежье поглощение"
            bool IsBearishEngulfing(const MqlRates &rates[], int shift) const { return false; }
            // TODO: Добавить заглушки для других паттернов: Pin Bar, Morning/Evening Star и т.д.
        };
        ```

2.  **Действие:** Создайте новый файл `Experts/TYP2/Modules/typ_figures.mqh`.
    *   **Содержимое:** Добавьте в него "скелет" класса для детекции графических фигур.
        ```cpp
        // --- typ_figures.mqh ---
        class CFigures {
        public:
            // Возвращает true, если обнаружена фигура "Голова и Плечи"
            bool DetectHeadAndShoulders(...) { return false; }
            // TODO: Добавить заглушки для других фигур: Треугольник, Флаг, Двойная вершина и т.д.
        };
        ```

3.  **Действие:** Создайте новый файл `Experts/TYP2/Modules/typ_fibo.mqh`.
    *   **Содержимое:** Добавьте в него "скелет" класса для работы с уровнями Фибоначчи.
        ```cpp
        // --- typ_fibo.mqh ---
        class CFibo {
        public:
            // Возвращает true, если цена находится в "кластерной" зоне Фибо
            bool IsInFiboCluster(double price, ...) { return false; }
        };
        ```

### **Задача 2: Создание "Каркаса" для Стратегий**

1.  **Действие:** Откройте файл `Experts/TYP2/Modules/typ_strategies.mqh`.
2.  **Действие:** Добавьте в него `#include` для новых модулей ТА.
    ```cpp
    #include "typ_patterns.mqh"
    #include "typ_figures.mqh"
    #include "typ_fibo.mqh"
    ```
3.  **Действие:** Создайте "скелет" класса `CStrategy_NightMR` для стратегии "Ночной Возврат к Среднему".
    ```cpp
    // --- Внутри typ_strategies.mqh ---
    
    // --- Структура для передачи сигналов-кандидатов ---
    struct SignalCandidate {
        bool   isValid;
        string strategyID;
        // ... (другие поля: entry, sl, tp, score)
    };
    
    class CStrategy_NightMR {
    private:
        CPatterns* m_patterns; // Указатель на библиотеку паттернов
    public:
        void Initialize(CPatterns* patterns_ptr) { m_patterns = patterns_ptr; }
        
        // Метод ищет сигнал и возвращает кандидата
        SignalCandidate GetSignal() {
            SignalCandidate candidate;
            candidate.isValid = false;
            // TODO: Реализовать полную логику скоринга
            return candidate;
        }
    };
    ```

### **Задача 3: Интеграция в Главный Файл**

1.  **Действие:** Откройте файл `Experts/TYP2/TakeYourProfit2.mq5`.
2.  **Действие:** В разделе глобальных переменных создайте экземпляры новых классов.
    ```cpp
    // ... (старые глобальные переменные)
    #include "Modules/typ_strategies.mqh" // Убедитесь, что он подключен

    // --- Глобальные экземпляры модулей Спринта 2 ---
    CPatterns           g_Patterns;
    CFigures            g_Figures;
    CFibo               g_Fibo;
    CStrategy_NightMR   g_Strategy_NightMR;
    ```
3.  **Действие:** В `OnInit()`, после всех остальных инициализаций, добавьте:
    ```cpp
    g_Strategy_NightMR.Initialize(&g_Patterns);
    // TODO: Добавить инициализацию для других стратегий и модулей ТА
    ```
4.  **Действие:** В `OnTick()`, создайте новый блок для генерации сигналов, который будет идти **после** всех проверок гвардов.
    ```cpp
    // ... (проверки CRiskManager и CExecGate пройдены) ...

    // --- БЛОК ГЕНЕРАЦИИ СИГНАЛОВ ---
    if (g_currentRegime == REGIME_FLAT_QUIET) {
        SignalCandidate night_mr_signal = g_Strategy_NightMR.GetSignal();
        
        // TODO: Передать сигнал в Resolver для финального утверждения
        if (night_mr_signal.isValid) {
            // ... (логика открытия сделки)
        }
    }
    ```
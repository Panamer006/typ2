# Техническое Задание (ТЗ) для Задачи: T2-AI-INTEGRATION

## 1. Цель

Интегрировать в архитектуру "скелет" AI-Слоя (`CAiLayer`), включающий "заглушки" для двух ключевых компонентов: `ML-Gate` (вероятностный фильтр сигналов) и `Bandit` (адаптивный выбор тактики). Это позволит проводить дальнейшую оптимизацию на финальной, полной архитектуре советника.

## 2. Пошаговый План Реализации

### **Задача 1: Создание Файла и Структуры Класса**

1.  **Действие:** Создайте новый файл `Experts/TYP2/Modules/typ_ai_layer.mqh`.
2.  **Действие:** Вставьте в него следующий **базовый "скелет" класса `CAiLayer`**.

    ```cpp
    // --- typ_ai_layer.mqh ---

    // --- Enum для тактик управления позицией ---
    enum E_PmTactic {
        TACTIC_STANDARD, // Стандартное сопровождение (Tiered BE, Сетка ТП)
        TACTIC_AGGRESSIVE, // Более быстрый БУ, более широкие цели
        TACTIC_CONSERVATIVE // Более быстрый выход, узкие цели
    };

    class CAiLayer {
    private:
        // --- Параметры ---
        bool m_is_ml_gate_enabled;
        bool m_is_bandit_enabled;
        
        // --- Состояние / Модели (в будущем) ---
        // TODO: Добавить хэндлы для ONNX-моделей

    public:
        // --- Конструктор ---
        CAiLayer();

        // --- Публичные Методы ---
        void Initialize();

        // --- Компонент 1: ML-Gate ---
        bool IsSignalProbable(SignalCandidate &candidate);

        // --- Компонент 2: Bandit ---
        E_PmTactic SuggestTactic(TradeOrderInstruction &instr);
    };
    ```

### **Задача 2: Реализация "Заглушек" для `ML-Gate` и `Bandit`**

1.  **Действие:** Реализуйте метод `bool IsSignalProbable(SignalCandidate &candidate)`.
    *   **Логика "заглушки":** На данном этапе этот метод **всегда** должен возвращать `true`. Он просто имитирует свою работу.
    *   **Код:**
        ```cpp
        bool CAiLayer::IsSignalProbable(SignalCandidate &candidate) {
            if (!m_is_ml_gate_enabled) {
                return true; // Если компонент выключен, пропускаем все
            }
            
            // TODO: Реализовать логику вызова ML-модели для оценки вероятности P(TP > SL).
            // Модель будет принимать на вход "вектор признаков" из кандидата.
            
            // --- Логика-заглушка ---
            return true;
        }
        ```

2.  **Действие:** Реализуйте метод `E_PmTactic SuggestTactic(TradeOrderInstruction &instr)`.
    *   **Логика "заглушки":** На данном этапе этот метод **всегда** должен возвращать `TACTIC_STANDARD`.
    *   **Код:**
        ```cpp
        E_PmTactic CAiLayer::SuggestTactic(TradeOrderInstruction &instr) {
            if (!m_is_bandit_enabled) {
                return TACTIC_STANDARD; // Если компонент выключен, используем стандартную тактику
            }

            // TODO: Реализовать логику многорукого бандита для выбора лучшей
            // тактики (Standard/Aggressive/Conservative) на основе контекста.

            // --- Логика-заглушка ---
            return TACTIC_STANDARD;
        }
        ```

### **Задача 3: Интеграция AI-Слоя в `Resolver` и `Position Manager`**

1.  **Действие:** Модифицируйте `typ_resolver.mqh`.
    *   **Что сделать:** `CResolver` должен получить указатель на `CAiLayer` и использовать `ML-Gate` как финальный фильтр.
    *   **Как сделать:**
        1.  Добавьте `#include "typ_ai_layer.mqh"`.
        2.  Добавьте `private`-член: `CAiLayer* m_ai_layer_ptr;`.
        3.  Добавьте в `Initialize` прием указателя: `void Initialize(CAiLayer* ai_layer) { m_ai_layer_ptr = ai_layer; }`.
        4.  В методе `Decide()`, **после** выбора лучшего кандидата, но **перед** формированием `TradeOrderInstruction`, добавьте вызов:
            ```cpp
            // ... (best_candidate выбран) ...
            if (m_ai_layer_ptr != NULL && !m_ai_layer_ptr->IsSignalProbable(best_candidate)) {
                // Если ML-Gate заблокировал сигнал, возвращаем невалидный приказ
                trade_instruction.isValid = false;
                return trade_instruction;
            }
            // ... (далее формирование приказа) ...
            ```

2.  **Действие:** Модифицируйте `typ_position_manager.mqh`.
    *   **Что сделать:** `CPositionManager` должен получить указатель на `CAiLayer` и учитывать тактику, предложенную `Bandit`-ом.
    *   **Как сделать:**
        1.  Добавьте `#include "typ_ai_layer.mqh"`.
        2.  Добавьте `private`-член: `CAiLayer* m_ai_layer_ptr;`.
        3.  Добавьте в `Initialize` прием указателя: `void Initialize(CRiskManager* risk_manager, CAiLayer* ai_layer)`.
        4.  В структуре `ManagedPosition` добавьте поле: `E_PmTactic tactic;`.
        5.  В `AddNewPosition(...)` добавьте прием `TradeOrderInstruction` и вызов `Bandit`-а:
            ```cpp
            void CPositionManager::AddNewPosition(..., TradeOrderInstruction &instr) {
                // ...
                if (m_ai_layer_ptr != NULL) {
                    new_pos.tactic = m_ai_layer_ptr->SuggestTactic(instr);
                } else {
                    new_pos.tactic = TACTIC_STANDARD;
                }
                // ...
            }
            ```
        6.  В методах `HandleBreakEven` и `HandleTakeProfit` используйте значение `pos.tactic` для выбора логики (например, разные множители ATR или уровни R).

### **Задача 4: Финальная Интеграция в `TakeYourProfit2.mq5`**

1.  **Действие:** Включите `#include "Modules/typ_ai_layer.mqh"`.
2.  **Действие:** Создайте глобальный экземпляр: `CAiLayer g_AiLayer;`.
3.  **Действие:** В `OnInit()`, вызовите `g_AiLayer.Initialize();` и передайте указатели в `Resolver` и `Position Manager`:
    ```cpp
    g_Resolver.Initialize(&g_AiLayer);
    g_PosManager.Initialize(&g_RiskManager, &g_AiLayer);
    ```
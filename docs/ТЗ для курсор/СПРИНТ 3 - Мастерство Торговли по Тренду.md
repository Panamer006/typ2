# Техническое Задание (ТЗ) для Задачи: СПРИНТ 3 - Мастерство Торговли по Тренду

## 1. Цель

Реализовать флагманские торговые "двигатели" для торговли по тренду (`DualMA Anchor` и `Donchian Breakout`) и завершить разработку "Мозга" (`Resolver`), наделив его полной "Матрицей Конфликтов и Конфлюэнса" для принятия финальных, взвешенных торговых решений.

## 2. Пошаговый План Реализации

### **Часть А: Трендовые "Двигатели" (`typ_strategies.mqh`)**

#### **Задача 1: Создание Флагманской Стратегии `CStrategy_DualMA_Anchor`**

1.  **Действие:** В файле `typ_strategies.mqh` создайте новый класс `CStrategy_DualMA_Anchor`.
2.  **Действие:** Реализуйте **"Иерархию Скользящих"** как `private`-члены класса (хэндлы для SMA 500, EMA 200, 100, 50).
3.  **Действие:** Реализуйте логику **Динамической "Сигнальной Зоны"** (ширина зависит от ATR).
4.  **Действие:** Создайте приватные методы для **трех тактик у `SMA 500`**: `CheckBounceConfirmation`, `CheckBreakAndRetest`, `CheckFalseBreakoutEngulfing`.
5.  **Действие:** Реализуйте главный метод `void FindSignals(CArrayObj* candidates_array)`.
    *   **Логика:** Этот метод должен проверять все типы входов ("Пробой и Закрепление", "Отскок-Прокол", тактики у SMA 500). Для каждого найденного сетапа он должен создавать объект `SignalCandidate`, **не проводя финального скоринга**, и добавлять его в `candidates_array`.

#### **Задача 2: Создание Стратегии `CStrategy_DonchianBreakout`**

1.  **Действие:** В файле `typ_strategies.mqh` создайте новый класс `CStrategy_DonchianBreakout`.
2.  **Действие:** Реализуйте метод `void FindSignals(CArrayObj* candidates_array)`.
    *   **Логика:** При пробое верхней/нижней границы Канала Дончиана (период 20) создавайте и добавляйте в `candidates_array` соответствующий `SignalCandidate`.

### **Часть Б: Финализация "Мозга" (`typ_resolver.mqh`)**

#### **Задача 3: Реализация "Матрицы Конфликтов и Конфлюэнса" в `CResolver`**

1.  **Действие:** Модифицируйте главный метод `TradeOrderInstruction Decide(CArrayObj* candidates_array)`.
2.  **Действие:** Реализуйте **"Матрицу"** как серию приватных методов-модификаторов, которые принимают `SignalCandidate` и изменяют его `score`.
    *   `void ApplyConfluenceRules(SignalCandidate &candidate)`:
        *   Проверяет **все 6 правил Конфлюэнса** (Тренд + Фигура, Тренд + Волатильность и т.д.).
        *   При совпадении — увеличивает `candidate.score` (например, `score *= 1.4`).
    *   `void ApplyConflictRules(SignalCandidate &candidate)`:
        *   Проверяет **все 6 правил Конфликта** (Тренд vs. Дивергенция, Сигнал vs. Конец сессии и т.д.).
        *   При совпадении — уменьшает `candidate.score` (например, `score -= 40`).

3.  **Действие:** В методе `Decide()` реализуйте следующий пайплайн:
    1.  Пройтись циклом по всем кандидатам в `candidates_array`.
    2.  Для каждого кандидата вызвать `ApplyConfluenceRules()` и `ApplyConflictRules()`.
    3.  Выбрать кандидата с наивысшим итоговым `score`.
    4.  Проверить, не является ли он одним из **"Королевских Сетапов"** (например, "Идеальный Откат").
    5.  На основе финального `score` и типа сетапа сформировать и вернуть `TradeOrderInstruction` с типом ордера, объемом и SL/TP.

### **Часть В: Интеграция в `TakeYourProfit2.mq5`**

1.  **Действие:** В разделе глобальных переменных создайте экземпляры новых стратегий: `CStrategy_DualMA_Anchor g_Strategy_DualMA;`, `CStrategy_DonchianBreakout g_Strategy_Donchian;`.
2.  **Действие:** В `OnInit()` вызовите их инициализацию.
3.  **Действие:** В `OnTick()`, в блоке генерации сигналов:
    1.  Создайте `CArrayObj* candidates = new CArrayObj();`.
    2.  **Если `g_currentRegime` трендовый**, вызовите `g_Strategy_DualMA.FindSignals(candidates);` и `g_Strategy_Donchian.FindSignals(candidates);`.
    3.  **Если `g_currentRegime` флэтовый**, вызовите `FindSignals` для флэтовых стратегий из Спринта 2.
    4.  Передайте `candidates` в `g_Resolver.Decide()`.
    5.  После получения `TradeOrderInstruction` исполните ордер.
    6.  Не забудьте очистить память: `delete candidates;`.
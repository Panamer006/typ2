# Техническое Задание (ТЗ) для Задачи: T2-005 - ExecGate (Детализированная Версия)

## 1. Цель

Создать и/или доработать **центральный модуль фильтров исполнения `CExecGate`** в файле `typ_execfilters.mqh`. Этот модуль должен стать "фейс-контролем" для каждой сделки, проверяя рыночные условия (новости, спред, волатильность) в момент перед отправкой ордера и предоставляя контекстно-зависимые параметры (например, размер SL).

## 2. Пошаговый План Реализации

### **Задача 1: Создание/Обновление Файла и Структуры Класса**

1.  **Действие:** Откройте для редактирования файл `Experts/TYP2/Modules/typ_execfilters.mqh`.
2.  **Действие:** Создайте или переработайте файл, чтобы он содержал следующий **базовый "скелет" класса `CExecGate`**.

    ```cpp
    // --- typ_execfilters.mqh ---
    #include "typ_regime_engine.mqh" // Подключаем Движок Режимов
    #include "typ_quantiles.mqh"   // Подключаем Квантили

    // --- Структура для хранения новостных событий ---
    struct NewsEvent {
        datetime time;
        string   currency;
        int      importance; // 1-Low, 2-Medium, 3-High
        bool     is_flatten_event; // True для супер-событий
    };

    class CExecGate {
    private:
        // --- ПАРАМЕТРЫ ---
        // NewsGuard
        bool   m_is_news_guard_enabled;
        int    m_news_pre_mins;
        int    m_news_post_mins;
        // SpreadGuard
        double m_spread_atr_multiplier;
        // SL
        double m_sl_atr_multiplier_trend;
        double m_sl_atr_multiplier_flat;
        // Session Time Stop
        int    m_session_end_hour;
        // ... (другие параметры для Slippage, Volatility и т.д.)
        
        // --- СОСТОЯНИЕ КЛАССА ---
        CArrayObj* m_news_events; // Массив для хранения новостей
        int        m_h_atr;

    public:
        // --- Публичные Методы ---
        CExecGate();
        ~CExecGate();
        void Initialize(/* ... параметры из input ... */);
        void OnTick();

        // --- ГЛАВНАЯ ФУНКЦИЯ-ГВАРД ---
        bool IsExecutionAllowed(const string symbol, int direction, string signal_bucket, string &reason);
        
        // --- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ---
        double GetAsymmetricStopLossPips(const string symbol, E_MarketRegime current_regime);
    
    private:
        // --- Приватные Методы-Проверки ---
        void LoadNewsFromCSV(const string filename);
        bool IsNewsOK(const string symbol, string &reason);
        bool IsSpreadOK(const string symbol, string &reason);
        bool IsVolatilityOK(const string symbol, string &reason);
        bool IsSessionTimeOK(string signal_bucket, string &reason);
    };
    ```

### **Задача 2: Реализация `NewsGuard`**

1.  **Действие:** Реализуйте приватный метод `void LoadNewsFromCSV(const string filename)`.
    *   **Логика:** Метод должен открывать `CSV`-файл из папки `MQL5/Files`. Формат файла: `datetime,currency,importance,event_name`. Метод парсит файл и заполняет массив `m_news_events` объектами `NewsEvent`. Для "супер-событий" (содержащих "Rate", "CPI", "FOMC") устанавливайте флаг `is_flatten_event = true`.

2.  **Действие:** Реализуйте приватный метод `bool IsNewsOK(const string symbol, string &reason)`.
    *   **Логика:**
        1.  Пройдитесь циклом по всем событиям в `m_news_events`.
        2.  Извлеките валюты из `symbol` (например, "EUR" и "USD").
        3.  Проверьте, совпадает ли одна из валют с `event.currency`.
        4.  Проверьте, попадает ли `TimeCurrent()` в запрещенный интервал: `event.time - m_news_pre_mins*60` и `event.time + m_news_post_mins*60`.
        5.  Если все условия совпали, верните `false` и заполните `reason`.

3.  **Действие:** Реализуйте **"Проактивное Снижение Позиции"** и **"Пост-новостной Карантин"**.
    *   **Примечание для Cursor:** Эта логика будет вызываться извне, из главного файла советника. Класс `CExecGate` должен лишь предоставить публичные методы для проверки, например: `bool IsFlattenRequired(symbol)` и `bool IsQuarantineActive(symbol, direction)`.

### **Задача 3: Реализация Контекстных Гвардов (`Spread`, `SL`)**

1.  **Действие:** Реализуйте приватный метод `bool IsSpreadOK(const string symbol, string &reason)`.
    *   **Логика:**
        1.  Получите текущий спред в пунктах: `SymbolInfoInteger(symbol, SYMBOL_SPREAD)`.
        2.  Получите текущее значение `ATR` на M15 в пунктах.
        3.  **Апгрейд "Динамический Max Spread":** Рассчитайте допустимый лимит: `allowed_spread = atr_pips * m_spread_atr_multiplier`.
        4.  `if (current_spread > allowed_spread)` -> `false`.

2.  **Действие:** Реализуйте публичный метод `double GetAsymmetricStopLossPips(const string symbol, E_MarketRegime current_regime)`.
    *   **Логика:**
        1.  Получите текущее значение `ATR` на H1 в пунктах.
        2.  **Апгрейд "Асимметричный Стоп-лосс":**
            ```cpp
            // Псевдокод
            if (current_regime is TREND) {
                return atr_pips * m_sl_atr_multiplier_trend;
            } else if (current_regime is FLAT) {
                return atr_pips * m_sl_atr_multiplier_flat;
            } else {
                return atr_pips * default_multiplier;
            }
            ```

### **Задача 4: Реализация Прочих Гвардов**

1.  **Действие:** Реализуйте приватный метод `bool IsSessionTimeOK(string signal_bucket, string &reason)`.
    *   **Логика:** Если `signal_bucket` относится к сессионной стратегии (например, "DualMA_Anchor_EU_Session"), проверьте текущий час сервера. Если `current_hour >= m_session_end_hour`, верните `false`.

2.  **Действие:** Добавьте в класс `CExecGate` и реализуйте "заглушки" для `IsVolatilityOK` (потребует `typ_quantiles.mqh`), `SlippageGuard` и `ParentalLock`. Их полная реализация будет в следующих итерациях, но каркас должен быть готов.

### **Задача 5: Интеграция и Финальная Сборка**

1.  **Действие:** Реализуйте главный публичный метод `bool IsExecutionAllowed(...)`.
    *   **Логика:** Этот метод должен **последовательно вызывать** все приватные гварды (`IsNewsOK`, `IsSpreadOK`, `IsSessionTimeOK` и т.д.). Если хотя бы один из них возвращает `false`, главный метод немедленно возвращает `false`.

2.  **Действие:** Интегрируйте вызов в `TakeYourProfit2.mq5`. В главном торговом цикле, после получения валидного сигнала и **после** проверок в `CRiskManager`, добавьте финальную проверку:
    ```cpp
    // ... (проверки CRiskManager пройдены) ...
    if (g_ExecGate.IsExecutionAllowed(signal.symbol, signal.direction, signal.bucket, reason)) {
        // --- Расчет финальных параметров ордера ---
        double sl_pips = g_ExecGate.GetAsymmetricStopLossPips(signal.symbol, g_currentRegime);
        double lot = g_RiskManager.CalculateLotSize(..., sl_pips);
        
        // --- ОТПРАВКА ОРДЕРА ---
        // ...
    }
    ```
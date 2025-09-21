# TYP2 Modules Documentation

## Обзор Модульной Архитектуры

Take Your Profit 2.0 построен на основе модульной архитектуры, где каждый компонент отвечает за конкретную область функциональности. Все модули находятся в директории `Experts/TYP2/Modules/`.

## Структура Модулей

```
Experts/TYP2/Modules/
├── typ_regime_engine.mqh      # Движок определения режимов рынка
├── typ_risk.mqh              # Система управления рисками портфеля
├── typ_execfilters.mqh       # Фильтры исполнения сделок
├── typ_position_manager.mqh  # Менеджер управления позициями
└── README_TYP2_MODULES.md    # Эта документация
```

## 🎯 1. Regime Engine (typ_regime_engine.mqh)

### Назначение
Интеллектуальное определение текущего состояния рынка с использованием множественных технических индикаторов.

### Ключевые Функции
- **8 режимов рынка:** От молодого тренда до макро-паники
- **Система гистерезиса:** Предотвращение ложных переключений
- **Техническая база:** ADX, ATR, RSI, MACD, Choppiness Index, Donchian Channel
- **Макро-анализ:** Детекция падений S&P 500

### Использование
```mql5
CRegimeEngine engine;
engine.Initialize(_Symbol, PERIOD_H1);
engine.Update();
E_MarketRegime current = engine.GetCurrentRegime();
```

### Режимы
- `REGIME_TREND_YOUNG` - Зарождающийся тренд
- `REGIME_TREND_MATURE` - Устоявшийся тренд  
- `REGIME_TREND_WEAKENING` - Ослабевающий тренд
- `REGIME_FLAT_QUIET` - Тихий флэт
- `REGIME_FLAT_CHOPPY` - Волатильный флэт
- `REGIME_UNSTABLE` - Конфликт индикаторов
- `REGIME_RISK_OFF` - Макро-паника
- `REGIME_UNDEFINED` - Неопределенное состояние

## 🛡️ 2. Risk Manager (typ_risk.mqh)

### Назначение
Комплексная система защиты капитала и управления рисками портфеля.

### Ключевые Функции
- **Защита от DD:** Дневные лимиты просадки с градуальным снижением
- **Ограничения экспозиции:** По валютам, лотам, общему риску
- **Кулдауны:** Адаптивные паузы между сделками
- **EOW Protocol:** Блокировка в конце недели
- **Recovery Protocol:** Снижение риска до восстановления

### Использование
```mql5
CRiskManager rm;
rm.Initialize(2.0, true, 3, 10, 5.0, 10.0);
double modifier = rm.GetRiskModifier(symbol, risk_percent, reason);
```

### Параметры
- `max_daily_dd_percent` - Лимит дневной просадки (2.0%)
- `max_positions_per_currency` - Позиций на валюту (3)
- `cooldown_seconds_win/loss` - Кулдауны (300/600 сек)
- `sl_cluster_limit` - Лимит кластера стопов (3)

## 🚪 3. Exec Gate (typ_execfilters.mqh)

### Назначение
Многоуровневая система фильтрации торговых сигналов по рыночным условиям.

### Ключевые Функции
- **NewsGuard:** Блокировка вокруг новостей с CSV календарем
- **SpreadGuard:** Динамические лимиты спреда относительно ATR
- **Volatility Guard:** Контроль минимальной/максимальной волатильности
- **Session Guard:** Ограничения по времени торговых сессий
- **Asymmetric SL:** Режимо-зависимые стоп-лоссы

### Использование
```mql5
CExecGate gate;
gate.Initialize(true, 30, 15, 0.5, 2.0, 1.5);
bool allowed = gate.IsExecutionAllowed(symbol, direction, bucket, reason);
double sl_pips = gate.GetAsymmetricStopLossPips(symbol, regime);
```

### Фильтры
- **News:** Временные окна до/после событий
- **Spread:** Лимит = ATR × multiplier  
- **Volatility:** Min/max пределы для ATR
- **Time:** Ограничения сессионных стратегий

## 📊 4. Position Manager (typ_position_manager.mqh)

### Назначение
Интеллектуальное сопровождение позиций от открытия до закрытия с адаптацией к рыночным режимам.

### Ключевые Функции
- **Tiered Breakeven:** Двухэтапный безубыток (-0.5R → 0R)
- **Adaptive Take Profits:** Режимо-зависимая сетка TP1/TP2/Runner
- **Smart Addons:** Контекстное освобождение риска для доливок
- **Trailing Stop:** ATR-основанный трэйлинг для раннеров
- **Momentum Exit:** Выход по дивергенции RSI

### Использование
```mql5
CPositionManager pm;
pm.Initialize(&risk_manager, true, 2, 1.5, 3.0);
pm.AddNewPosition(ticket, signal_category, signal_score);
pm.OnTick(current_regime);
```

### Стратегии
- **BE Stage 1:** Profit Lock на -0.5R при 1R прибыли
- **BE Stage 2:** Полный BE при 2R + освобождение риска
- **TP1:** 50% позиции при 1.5R (адаптивно)
- **TP2:** 30% позиции при 3.0R (адаптивно)
- **Runner:** 20% с трэйлингом и умным выходом

## 🔄 Интеграция Модулей

### Последовательность Проверок
```mql5
// 1. Определение режима рынка
g_RegimeEngine.Update();
E_MarketRegime regime = g_RegimeEngine.GetCurrentRegime();

// 2. Проверка рисков
double risk_modifier = g_RiskManager.GetRiskModifier(symbol, risk, reason);

// 3. Фильтрация исполнения  
bool allowed = g_ExecGate.IsExecutionAllowed(symbol, direction, bucket, reason);

// 4. Размещение и управление
if(allowed && risk_modifier > 0) {
    // Открываем позицию
    g_PosManager.AddNewPosition(ticket, category, score);
}

// 5. Постоянное сопровождение
g_PosManager.OnTick(regime);
```

### Взаимодействие Систем
- **Regime → All:** Все системы адаптируются к текущему режиму
- **Risk → Exec:** Модификатор риска влияет на размер позиции
- **Exec → PosMan:** Асимметричные SL передаются в управление
- **PosMan → Risk:** Уведомления о закрытии для обновления статистики

## 📋 Конфигурация

### Инициализация в OnInit()
```mql5
// Инициализация в правильном порядке
g_RegimeEngine.Initialize(_Symbol, PERIOD_H1);
g_RiskManager.Initialize(2.0, true, 3, 10, 5.0, 10.0);
g_ExecGate.Initialize(true, 30, 15, 0.5, 2.0, 1.5);
g_PosManager.Initialize(&g_RiskManager, true, 2, 1.5, 3.0);
```

### Обновление в OnTick()
```mql5
// Обновление в каждом тике
g_RegimeEngine.Update();
g_RiskManager.OnTick(regime);
g_ExecGate.OnTick();
g_PosManager.OnTick(regime);
```

## 🔧 Настройка под Стратегии

### Консервативная Настройка
```mql5
// Строгие лимиты рисков
g_RiskManager.Initialize(1.5, true, 2, 5, 2.0, 5.0);

// Широкие фильтры новостей
g_ExecGate.Initialize(true, 60, 30, 0.3, 1.5, 1.2);

// Быстрые тейк-профиты
g_PosManager.Initialize(&rm, true, 1, 1.0, 2.0, 70.0, 25.0);
```

### Агрессивная Настройка
```mql5
// Более свободные лимиты
g_RiskManager.Initialize(3.0, false, 5, 15, 10.0, 15.0);

// Узкие фильтры новостей
g_ExecGate.Initialize(true, 15, 5, 0.8, 3.0, 2.0);

// Больше раннеров
g_PosManager.Initialize(&rm, false, 3, 2.0, 4.0, 30.0, 20.0);
```

## 📊 Мониторинг и Диагностика

### Журналирование
Все модули ведут детальные логи:
```
Regime Engine: New regime confirmed -> TREND_MATURE
Risk Manager: DAILY DD LIMIT REACHED! DD: 2.50% >= 2.00%
ExecGate: News guard: USD FOMC Interest Rate Decision in 15 minutes
Position Manager: Moved SL for position 12345 to 1.1245 - Profit Lock -0.5R
```

### Мониторинг Производительности
- **Regime Engine:** Частота смены режимов
- **Risk Manager:** Процент заблокированных сигналов
- **Exec Gate:** Эффективность фильтров
- **Position Manager:** Статистика закрытий по этапам

## 🚀 Расширения и Доработки

### Готовые Интерфейсы
Все модули предоставляют стандартизированные интерфейсы для:
- Конфигурации параметров
- Получения текущего состояния
- Подписки на события
- Статистического анализа

### Планы Развития
1. **Machine Learning:** Адаптивная оптимизация параметров
2. **Multi-Asset:** Кросс-инструментальное управление
3. **Advanced Analytics:** Глубокий анализ эффективности
4. **Cloud Integration:** Синхронизация между терминалами

## 💡 Лучшие Практики

### При Разработке Стратегий
1. **Всегда используйте Regime Engine** для адаптации логики
2. **Обязательно проверяйте Risk Manager** перед входом
3. **Применяйте Exec Gate** для фильтрации сигналов  
4. **Регистрируйте позиции** в Position Manager для автоматического управления

### При Настройке Параметров
1. **Начните с консервативных настроек**
2. **Тестируйте на исторических данных**
3. **Адаптируйте под характеристики инструмента**
4. **Мониторьте эффективность в реальном времени**

### При Отладке
1. **Анализируйте логи всех модулей**
2. **Проверяйте последовательность проверок**
3. **Убедитесь в корректности инициализации**
4. **Валидируйте входные параметры**

---

*Документация обновлена: 21 сентября 2025*  
*Версия модулей: v2.1.0*  
*Статус: Production Ready*

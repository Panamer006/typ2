# Движок Режимов Рынка (Market Regime Engine)

## Описание

Модуль **typ_regime_engine.mqh** реализует интеллектуальную систему определения режимов рынка для EA Take Your Profit 2.0. Движок анализирует множественные технические индикаторы и макроэкономические условия для классификации текущего состояния рынка.

## Режимы Рынка

### Трендовые Режимы
- **REGIME_TREND_YOUNG** - Молодой, зарождающийся тренд
- **REGIME_TREND_MATURE** - Зрелый, устоявшийся тренд  
- **REGIME_TREND_WEAKENING** - Ослабевающий тренд, возможен разворот

### Флэтовые Режимы
- **REGIME_FLAT_QUIET** - Тихий флэт, низкая волатильность
- **REGIME_FLAT_CHOPPY** - "Пила", высокая волатильность в диапазоне

### Защитные Режимы
- **REGIME_UNSTABLE** - Конфликт индикаторов, торговля запрещена
- **REGIME_RISK_OFF** - Макро-паника, запрет покупки рисковых активов

## Используемые Индикаторы

1. **ADX (Average Directional Index)** - Определение силы тренда
2. **ATR (Average True Range)** - Измерение волатильности
3. **RSI (Relative Strength Index)** - Детекция дивергенций
4. **MACD** - Подтверждение трендовых сигналов
5. **Choppiness Index** - Идентификация флэтовых периодов
6. **Donchian Channel Width** - Измерение ширины канала
7. **Normalized Volume** - Анализ объемов торгов

## Алгоритм Определения Режима

### 1. Сбор Данных
- Получение значений всех индикаторов на последнем закрытом баре
- Вычисление Z-Score для нормализации показателей
- Проверка макроэкономических условий (S&P 500)

### 2. Иерархия Приоритетов
1. **Макро-паника** (RISK_OFF) - высший приоритет
2. **Конфликт индикаторов** (UNSTABLE)
3. **Ослабевающий тренд** (TREND_WEAKENING)
4. **Основные режимы** (TREND/FLAT)

### 3. Гистерезис
- Подтверждение нового режима в течение 3 баров
- Предотвращение ложных переключений
- Стабилизация решений

## Критерии Определения

### Трендовые Режимы
```mql5
bool is_trend = (adx_value > 22 && chop_value < 38 && donchian_z_score > 0.5);

if (is_trend) {
    if (adx_value > 40) 
        regime = REGIME_TREND_MATURE;
    else 
        regime = REGIME_TREND_YOUNG;
}
```

### Флэтовые Режимы
```mql5
bool is_flat = (adx_value < 18 && chop_value > 62);

if (is_flat) {
    if (atr_z_score < -1.0) 
        regime = REGIME_FLAT_QUIET;
    else 
        regime = REGIME_FLAT_CHOPPY;
}
```

### Защитные Режимы
```mql5
// Макро-паника
if (is_sp500_crashing) 
    regime = REGIME_RISK_OFF;

// Конфликт индикаторов
if (adx_value > 30 && vol_z_score < -1.0) 
    regime = REGIME_UNSTABLE;

// Ослабевающий тренд
if (current_regime == REGIME_TREND_MATURE && HasDivergence()) 
    regime = REGIME_TREND_WEAKENING;
```

## Использование в Торговых Стратегиях

### Инициализация
```mql5
#include "Modules/typ_regime_engine.mqh"

CRegimeEngine g_RegimeEngine;
E_MarketRegime g_currentRegime;

int OnInit() {
    g_RegimeEngine.Initialize(_Symbol, PERIOD_H1);
    return INIT_SUCCEEDED;
}
```

### Обновление в OnTick()
```mql5
void OnTick() {
    g_RegimeEngine.Update();
    E_MarketRegime newRegime = g_RegimeEngine.GetCurrentRegime();
    
    if(newRegime != g_currentRegime) {
        g_currentRegime = newRegime;
        // Реагируем на смену режима
        OnRegimeChange(g_currentRegime);
    }
}
```

### Адаптивная Торговая Логика
```mql5
void OnRegimeChange(E_MarketRegime regime) {
    switch(regime) {
        case REGIME_TREND_YOUNG:
            // Агрессивные входы по тренду
            EnableTrendFollowing(true);
            SetRiskLevel(MEDIUM);
            break;
            
        case REGIME_TREND_MATURE:
            // Консервативное следование тренду
            EnableTrendFollowing(true);
            SetRiskLevel(LOW);
            break;
            
        case REGIME_FLAT_QUIET:
            // Диапазонная торговля
            EnableRangeTrading(true);
            SetRiskLevel(MEDIUM);
            break;
            
        case REGIME_RISK_OFF:
            // Закрытие рискованных позиций
            CloseRiskyPositions();
            SetRiskLevel(MINIMAL);
            break;
    }
}
```

## Преимущества

1. **Адаптивность** - Автоматическая адаптация стратегий к рыночным условиям
2. **Надежность** - Система гистерезиса предотвращает ложные сигналы
3. **Комплексность** - Учет множественных факторов и индикаторов
4. **Масштабируемость** - Легко интегрируется в любые торговые стратегии

## Мониторинг и Отладка

Движок выводит подробную информацию в лог:
- Смены режимов с указанием нового состояния
- Детекцию макро-событий (падения рынка, дивергенции)
- Периодические отчеты о текущем режиме

## Настройка Параметров

Основные параметры для тюнинга:
- `m_hysteresis_bars = 3` - Количество баров для подтверждения
- Пороговые значения ADX (22/18/40)
- Пороговые значения Choppiness Index (38/62)
- Z-Score пороги для волатильности и объема

## Будущие Улучшения

1. Добавление машинного обучения для оптимизации порогов
2. Интеграция дополнительных макроэкономических индикаторов
3. Поддержка мультитаймфреймового анализа
4. Адаптивная калибровка параметров под конкретные инструменты

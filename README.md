# Take Your Profit EA 2.0 (TYP2)

**Baseline v2.0.1** — стабильное ядро для дальнейшей разработки.

## Состав
- **Experts/TYP2/** — исходники эксперта и модулей (`typ_*.mqh`, `TakeYourProfit2.mq5`)
- **Indicators/** — `TYP_Viewer.mq5`
- **Files/** — примеры пресетов (`SET_EURUSD_M15.set`)
- **docs/** — Roadmap, Master Feature Matrix, чек-лист задач и slim‑README

## Быстрый старт
1. Скопируйте папки в каталог `MQL5` вашего терминала.
2. Откройте `TakeYourProfit2.mq5` в MetaEditor → **Compile**.
3. В тестере стратегий выберите `EURUSD M15` и пресет `SET_EURUSD_M15.set`.

## Ветки разработки
- `main` — релизы/rc (защищено).
- `dev` — интеграция фич перед релизом.
- `feature/T2-xxx-*` — задачи из чек-листа.

## Лицензия и Market
Код предназначен для сборки под частные лицензии и публикации в MQL5 Market (ограничения DEMO настраиваются в модуле лицензирования).

----
См. **docs/** для подробностей (Roadmap, матрица фич, чек-лист).

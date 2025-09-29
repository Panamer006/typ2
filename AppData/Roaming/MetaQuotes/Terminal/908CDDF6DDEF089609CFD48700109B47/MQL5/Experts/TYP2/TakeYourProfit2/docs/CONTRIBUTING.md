# Contributing Guide

## Ветки и поток
- `main` — релизы/RC (защищена).
- `dev` — интеграция фич (источник правды).
- `feature/T2-XXX-<slug>` — ветка под каждую задачу.
- `chore/*`, `fix/*` — вспомогательные ветки.

## Задачи (Issues)
- Формат: **T2-XXX Короткое название** (labels: `T2`, `feature`/`bug`/`chore`).
- В описании: контекст, ожидания, ссылки на спеки/макеты/скриншоты.

## Спеки и чек-листы
- **Спека** → `docs/specs/T2-XXX_<slug>.md` (см. шаблон в `docs/specs/README.md`).
- **Чек-лист** → `docs/checklists/T2-XXX.md` (см. `docs/checklists/README.md`).
- В PR обязательно приложить: скриншоты тестера и `.set` из `Files/`.

## Коммиты
- Префиксы: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`.
- Примеры:
  - `feat(T2-006): add VWAP filters baseline`
  - `docs(spec): T2-004 RSI divergence spec`
  - `refactor(core): split CRegimeEngine indicators init`

## Структура репозитория (ключевая)
- `Experts/TYP2/` — исходники EA/модулей (MQL5).
- `Indicators/` — индикаторы (в т.ч. отладочная визуализация).
- `Files/` — пресеты `.set`, тестовые данные.
- `docs/` — документация (overview, architecture, roadmap, specs, checklists).

## Архитектурные правила (важно)
- Стратегии вызываются **после** гвардов Risk/Exec (см. ARCHITECTURE.md).
- `GetSignal()` возвращает **структурированный** результат (тип/направление/score/SL/TP/обоснование).
- Визуализация — только через `CChartObjectsManager`.
- TA-классы — изолируемые, желательно **stateless-API**.

## Код-стандарт
- Любой код обязан соответствовать `docs/CODE_GUIDELINES_MQL5.md`.

## Процесс PR
1. Ветка: `feature/T2-XXX-<slug>`.
2. Компиляция/проверки — зелёные.
3. Описание PR:
   - ссылка на **Issue**,
   - ссылка на **спеку** и **чек-лист**,
   - как тестировать (параметры, пресет `.set`), скриншоты,
   - риски/совместимость.
4. Минимум 1 ревью.  
5. Merge → `dev` (**Squash**). Обновить `docs/ROADMAP.md`.

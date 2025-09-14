# TYP2 Master Feature Matrix (из 7 частей зависшего чата)

| Категория     | Идея / Фича                                              | Статус   | Комментарий                                    |
|:--------------|:---------------------------------------------------------|:---------|:-----------------------------------------------|
| Выходы/Риск   | 3 TP (40/30/30), BE, ATR-трейл, staged entries           | Есть     | PM+RiskGovernor                                |
| Выходы/Риск   | Tiered BE (в т.ч. отриц.)                                | Есть     |                                                |
| Выходы/Риск   | Points-режим (фикс. TP/SL/BE/Trail)                      | Нет      | Сейчас ATR/R                                   |
| Выходы/Риск   | Kelly-lite риск                                          | Нет      |                                                |
| Выходы/Риск   | USD-risk basket / cap                                    | Нет      | Корзинный лимит не реализован                  |
| Выходы/Риск   | Portfolio Risk Manager (корзины/корреляции/кэпы)         | Нет      | Только дневные лимиты RiskGovernor             |
| Выходы/Риск   | Flip-протокол (смена доминанты → reduce/flat)            | Нет      |                                                |
| Фильтры       | EMA200 H4 режимный фильтр                                | Есть     | Через TripleScreen                             |
| Фильтры       | ADX filter                                               | Есть     |                                                |
| Фильтры       | ATR-percentile                                           | Есть     |                                                |
| Фильтры       | Spread ≤ медиана+σ                                       | Есть     | Стат. спред-фильтр                             |
| Фильтры       | Сессионные (Лондон/НЙ/Азия)                              | Есть     |                                                |
| Фильтры       | NewsGuard (CSV окна блокировки)                          | Частично | Расширенных playbooks нет                      |
| Фильтры       | Donchian / Aroon / SuperTrend                            | Нет      |                                                |
| Фильтры       | VWAP (anchored daily/weekly)                             | Нет      | Включено в план v2.0.2                         |
| Фильтры       | Keltner Squeeze (Donchian+Keltner)                       | Нет      |                                                |
| Фильтры       | MinSpace до уровня/круглого (≥0.6–1 ATR)                 | Нет      | В план v2.0.2                                  |
| Фильтры       | Time-Stop (бар-таймаут без прогресса)                    | Нет      | В план v2.0.2                                  |
| Фильтры       | No-Chase (ограничение цены входа/проскальз.)             | Нет      | В план v2.0.2                                  |
| Фильтры       | Auto-Regime (TREND/NORMAL/FLAT)                          | Нет      | Пока ручные режимы TripleScreen                |
| Фильтры       | HeadwindScore (MA200/круглый/VWAP/Fibo-кластер)          | Нет      | Запланирован на v2.1                           |
| Сигналы       | DualMA Anchor (Bounce/Break/Retest/Pinch→Momentum)       | Есть     | Флагман                                        |
| Сигналы       | DualMA Anchor Pro (TrendStrict / AltFilters)             | Нет      | Planned v2.0.2                                 |
| Сигналы       | Triangle (base)                                          | Есть     |                                                |
| Сигналы       | Triangle.HYBRID (EDGE_FADE / TREND_ACCUM / BREAKOUT+ADD) | Частично | Только base, гибрид в план v2.0.2              |
| Сигналы       | Fibo Pullback (A→B, GP)                                  | Есть     | Базовый                                        |
| Сигналы       | Fibo Pullback расширенный (Anchors/Cluster/AB=CD)        | Частично | Anchors частично, Cluster/AB=CD нет            |
| Сигналы       | ElliottAssist (правила волн)                             | Нет      |                                                |
| Сигналы       | RSI Divergence/Convergence                               | Нет      | План v2.0.2                                    |
| Сигналы       | Divergence по другим индикаторам                         | Нет      |                                                |
| Сигналы       | Two-point trendline (3rd touch)                          | Нет      |                                                |
| Сигналы       | Auto-трендовые линии (ZigZag/Fractals)                   | Нет      |                                                |
| Сигналы       | CandleConfirm (pin/engulf у линии)                       | Нет      |                                                |
| Сигналы       | PatternScore (H&S, DT/DB, Flag, Wedge, S&D)              | Нет      |                                                |
| Сигналы       | MA-лимитки/стопы (откат/перевзятие)                      | Нет      |                                                |
| Сигналы       | BracketOnFailBreak (авто-переворот при пробое)           | Нет      | ReverseOnBreak есть, но не bracket ОСО-связка  |
| Resolver/Exec | Resolver (веса/штрафы/анти-спам)                         | Есть     |                                                |
| Resolver/Exec | SignalBus (приоритеты, bus)                              | Нет      | Упрощён через Resolver                         |
| Resolver/Exec | WaitForFormation (созревание фигуры)                     | Нет      |                                                |
| Resolver/Exec | ReverseOnBreak (переворот по пробою)                     | Есть     | Order Engine                                   |
| Resolver/Exec | AddOnRetest (очередь ретестов)                           | Есть     | Order Engine                                   |
| Resolver/Exec | StructureTrail (HL/LH или линии ±ATR)                    | Нет      | Только ATR-трейл                               |
| Resolver/Exec | No-Chase/MinSpace/Time-Stop – как исполнительные правила | Нет      | В план v2.0.2                                  |
| Macro/Bias    | CCY Cross-dominance (EUR↔GBP)                            | Есть     | v2.0.1                                         |
| Macro/Bias    | USD basket в CCY Bias                                    | Нет      | v2.1                                           |
| Macro/Bias    | Auto-routing EURUSD↔GBPUSD                               | Нет      | v2.1 PortfolioRouter                           |
| Macro/Bias    | Safe-Mode при смене bias (урезать трейл, стоп доливки)   | Нет      |                                                |
| Macro/Bias    | Portfolio Risk Manager (1 USD-ветка/бар, корреляции)     | Нет      |                                                |
| Новости       | NewsGuard (блокировка окон)                              | Есть     | CSV                                            |
| Новости       | NewsPlaybook (Momentum/Break&Hold/Fade/Straddle)         | Нет      | v2.1                                           |
| Новости       | SurpriseZ (actual vs forecast, z-score)                  | Нет      | v2.1                                           |
| Новости       | Pre-news Straddle (OCO)                                  | Нет      | v2.1                                           |
| Новости       | Post-news Momentum/Break&Hold/Fade                       | Нет      | v2.1                                           |
| Новости       | NewsRiskMult (A/B/C)                                     | Нет      | v2.1                                           |
| Новости       | News+Fibo связка                                         | Нет      | v2.1                                           |
| AI/ML         | ML-Gate (P(TP1>SL))                                      | Нет      | v3.0                                           |
| AI/ML         | Bandit (Limit vs Break vs Retest)                        | Нет      | v3.0                                           |
| AI/ML         | Auto-profiles TREND/NORMAL/FLAT (Regime Engine)          | Нет      | v3.0                                           |
| AI/ML         | Health Monitor (PF/Expectancy/Hit-rate/MFE-MAE/CUSUM)    | Нет      | v3.0                                           |
| AI/ML         | Equity/Drift guard (CUSUM/Page-Hinkley)                  | Нет      | v3.0                                           |
| AI/ML         | Quantile-range прогноз hi/lo                             | Нет      | Backlog                                        |
| AI/ML         | K-NN пресеты                                             | Нет      | Backlog                                        |
| AI/ML         | GPT-интеграция (Advisor/Pilot)                           | Нет      | Backlog                                        |
| Инфра         | Viewer-индикатор (графика/телеметрия)                    | Есть     | TYP_Viewer.mq5                                 |
| Инфра         | ParentalLock (блок ручных)                               | Есть     |                                                |
| Инфра         | Auto-screens/Push на события                             | Нет      |                                                |
| Инфра         | SandboxEA для модульных тестов                           | Нет      |                                                |
| Инфра         | Auto-combine оптимизаций (ini+bat+PS)                    | Нет      |                                                |
| Инфра         | WFO-пайплайн                                             | Нет      |                                                |
| Инфра         | Расширенные логи (Pattern/Angle/EntryType/JSON причин)   | Нет      | JSON-лог причин запланирован 2.0.2             |
| Инфра         | Yandex.Cloud / LAN ферма / MQL5 Cloud                    | Нет      | Орг. часть, вне кода EA                        |
| Маркетинг     | README/FAQ RU/EN, скрины, пресеты                        | Частично | Черновики есть, нужно добить                   |
| Маркетинг     | Preset Packs (DualMA, Triangle, Fibo, Elder)             | Частично | EURUSD base + доп. пресеты в план              |
| Маркетинг     | DEMO-ограничения Market                                  | Частично | Лицензирование есть, доп. демо-настройки нужны |
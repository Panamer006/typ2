# Take Your Profit 2.0  ROADMAP (master checklist)

## P0  база и инфраструктура
- **Resolver v2**: единая точка `AllowEntry(dir, entry, reasonJson)`; приоритет  ExecGate, затем взвешенные сигналы (DualMA, Triangle, Fibo PRZ/AB=CD, RSI-div, VWAP); режим dry-run; обязательный JSON-лог allow/deny.
- **Exec Filters (ExecGate)**:  
  - NoChase (ATR%, пипсы, от EMA)  запрет входа если убежало.  
  - MinSpace (до преграды  Z*ATR/пипсов).  
  - TimeStop (N баров без прогресса).  
  - Spread-guard (MaxSpread), slippage cap, сессии/часы.  
  - Логи: `[EXEC]...` и `[ENTRY BLOCKED] {...}` (JSON).
- **Бейзлайн**: пресет `.set` для EURUSD M15; визуальный smoke-тест.

## P1  модули сигналов (реальные, не скелеты)

### T2-001 DualMA Pro
- Fast/Slow EMA (опц. SMA), TrendStrict (фильтр тренда D1/H4), MTF подтверждение.  
- Наклон (EMA/ATR-slope), MinCrossDelta, фильтры спред/вола, DelayBarsAfterFlip, flatten-guard.  
- Сигнал: пересечение MA + подтверждения; вход только по старшему тренду.

### T2-002 Triangle.HYBRID (расширенный)
- Режимы: **EDGE_FADE** (контртренд от границы), **BREAKOUT** (импульс+ATR-эксплозия, закрытие за гранью), **TRACCUM** (по тренду на ретесте грани).  
- Диапазон/сжатие: 34 касания граней, сходимость High/Low, прогресс к апексу > N баров; свежесть касаний  вес; ADX не падает.  
- Конфлюэнс с MA/VWAP/линиями/круглыми уровнями.  
- SL: за структурный экстремум (+offset ATR); TP: ATR-кратные/границы/частичный.

### T2-003 Fibo Extended
- **Anchors**: выбор swing high/low (Pivot L/R) автоматом или вручную.  
- **Cluster** уровней (retrac/extension), подсчёт кон-флюэнса.  
- **AB=CD (опция)**, PRZ-окно с весами подтверждений (RSI-div, Triangle-edge).  
- Частичные TP в PRZ; защитный stop-offset; запрет пирамидинга и re-entry в PRZ N баров.

### T2-004 RSI Divergence
- RSI(period), pivots L/R; быч/медв див; опц. MTF подтверждение.  
- Возврат +1/-1/0; хранить 23 последних свинга.

### T2-006 VWAP Filters
- Дневной/сессионный VWAP; полосы stdev; запрет контртренда против склона VWAP; кросс как подтверждение; посленовостной сглаживающий период (stub).

### T2-008 Trendline Pro (третье касание, ретест/пробой)
- Построение трендовой по **двум сильным свингам** (Fractal/ZigZag) на `StructureTF` (обычно H4), допуск по углу/толерансу.  
- Валидность: **3 касаний**; для канала  параллельные границы, 3 касаний каждой.  
- **RETTEST_FADE**: лимитка на касание (`TouchBuffer`), `OrderTTL=23`, строгий SL за экстремум.  
- **BREAK_RETAKE**: перевзятие после пробоя.  
- **Доливки** на ретесте: `AddStep  0.8ATR`, лоты **1.00.70.5**, суммарный риск  **2R**.  
- Структурный фильтр: на TradeTF перед касанием  3-свечная усталость (короче тела).

### T2-009 Three Trades & Volume Plan
- AUTO: **netting  SERVER_LIMITS**, **hedging  MULTI_TPS (3 сделки с собственными SL/TP)**.  
- Ступени входа: **1.0  0.7  0.5**, `MaxAdds=23`, `PROMOTE_ON_BE` (разрешить следующую ступень объёмом Stage1, если пред. уже в BE/Tier2+).  
- Во **флэте** доливки OFF/микро-лот; пер-символьный лимит риска; корр-скейлинг по корзине/CCY.

### T2-010 Elder: Triple Screen + Force Index
- Правило **46 по масштабу** (старший тренд  рабочий вход  младший тайминг).  
- Младший экран: **Force Index (2/13)**; Envelopes на EMA (ATRmult или %).  
- Используется как **фильтр**/вес в Resolver; логи `[TRIPLE]`, `[FORCE]`.

## P2  Risk/Exit/Оптимация/Инфра
- **Risk/Money**: автолот %, неттинг/хеджинг, лимиты, RR-таргеты, частичные, просадка-стоп.  
- **Exit/BE/Trailing**: BE по ATR/pips, trailing (step/ATR/struct), time-exit, выход по контр-сигналу.  
- **Оптимизация/WFO**: бейзлайн .set, окна train/test, цель 150300 сделок/окно; отчёты/метрики (PF, win, DD).  
- **MT5 Build**: скрипты PowerShell (compile/deploy), пресеты в Profiles\Tester, логи MetaEditor.  
- **GitHub Flow**: ветки `feature/T2-XXX-*`, PR (squash), delete branch, теги (`p0-baseline`, `p0-slim-toolchain`), .gitignore backups/*.log.

---



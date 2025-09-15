# T2-008 Trendline Pro — Block#1 (скелет)

**Что входит:**
- каркас модуля `typ_trendlinepro.mqh`: параметры ZigZag 12/5/3, ATR(14), режим SMA500, черновой `CHANNEL_TP`;
- `typ_fibomap.mqh` — автогенерация уровней Фибо по Hi/Lo за lookback (D1 по умолчанию);
- `typ_draw.mqh` — вспомогательное рисование линий.

**Что дальше (Block#2+):**
- построение базовой трендовой по свингам ZZ, подсчёт касаний (>=2) и подтверждение 3-го;
- сценарии **RETEST_FADE / BREAK_RETAKE / FALSE_BREAK**;
- каналы и TP поATR×k + доливки 1.0→0.7→0.5, AddStep≥0.8·ATR;
- баланс приоритетов с MA(50/100/200/500) и Resolver v2.

Файлы не трогают основной `TakeYourProfit2.mq5` — интеграцию подключим в отдельном PR (Block#2).

## v1 (Block#2) — сигналы и пороги
**Сигналы:** `TL_RETEST_FADE_{BUY|SELL}`, `TL_BREAK_RETAKE_{BUY|SELL}`, `TL_FALSE_BREAK_{BUY|SELL}`, `TL_CHANNEL_TP`  
**Пороговые параметры (по умолчанию):**
- `tolTouchATR=0.35`, `breakBufferATR=0.35`, `retestBars=5`
- `fboCloseATR=0.40`, `fboLookAheadBars=3`, `wickBodyMin=1.5`
- `minBarsBetweenTouches=6`, `channelWidthATR=2.0`
**Примечания:**
- Свинги считаются локальными поворотами (swing L/R).
- Канал строится параллелью через ближайший противоположный свинг.
- SMA500 помечает режим (`inBigTrend`) — используется в Resolver для веса/объёма.

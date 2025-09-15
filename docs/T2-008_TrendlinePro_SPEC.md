
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

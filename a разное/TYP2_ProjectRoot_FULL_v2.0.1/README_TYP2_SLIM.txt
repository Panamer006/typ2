Take Your Profit 2.0 — SLIM MT5 Package (<= 20 files)

Files:
- Experts/TYP2/TakeYourProfit2.mq5       — main EA
- Experts/TYP2/typ_core.mqh              — globals/utils/newbar/news/portfolio (consolidated)
- Experts/TYP2/typ_risk.mqh              — autolot & risk calc
- Experts/TYP2/typ_be.mqh                — tiered BE manager
- Experts/TYP2/typ_exit.mqh              — server reduce-orders partial exits
- Experts/TYP2/typ_parental.mqh          — parental lock (manual neutralizer)
- Experts/TYP2/typ_strategies.mqh        — DualMA signature + placeholders
- Indicators/TYP_Viewer.mq5              — viewer overlay
- Files/                                  (reserved for presets/CSV later)

Install:
1) MetaTrader 5 → File → Open Data Folder.
2) Copy the provided MQL5 folder contents into your data folder.
3) Compile: Experts/TYP2/TakeYourProfit2.mq5 and Indicators/TYP_Viewer.mq5.
4) Attach EA to a chart, enable Algo Trading.

Notes:
- DualMA, ParentalLock, tiered BE, and server partial-TP are functional.
- Triangle/Fibo/Divergence/Resolver/News/Cross-bias to be added incrementally.

# TYP2 Roadmap (v2.0.x → v3.0)
**Project:** Take Your Profit EA 2.0 (TYP2)  
**Owner:** Босс  
**Chat:** Проектный чат №3 (переезд из зависшего чата №1)  
**Date:** 2025‑09‑13 (Europe/Stockholm)

---

## 0) TL;DR
- **Сейчас в корне:** стабильное ядро v2.0.1 (DualMA, Triangle базовый, Fibo базовый, TripleScreen HARD/SOFT, CCY Bias EUR/GBP, Resolver, Position Manager, RiskGovernor, NewsGuard CSV, Viewer).
- **Цель v2.0.2:** закрыть «ядро идей» из чата №1 без ML: **Fibo Pullback (расшир.), Triangle.HYBRID, RSI Divergence**, DualMA Anchor Pro (TrendStrict/AltFilters), усилить фильтры (MinSpace / Time‑stop / No‑chase / VWAP (баз.)).  
- **Цель v3.0:** портфельный риск (корзины/корреляции/кэпы), CrossBias USD‑basket, NewsPlaybook (активные стратегии под новости), Regime Engine, ML‑Gate/Bandit, Health‑монитор.

---

## 1) Что уже реализовано (v2.0.1)
- **Signals:** DualMA Anchor (Bounce / Break / Retest / Pinch→Momentum), Triangle (base), Fibo (A→B, GP).
- **Filters:** ADX, ATR‑percentile, Spread‑stats, trading hours/sessions, TripleScreen (HARD/SOFT D1/H4/H1 ↔ H4/H1/M15).
- **Bias:** CCY Cross‑dominance (EUR↔GBP) — бонус/штраф в TS/Resolver.
- **Resolver:** веса, headwind‑штрафы (емкие барьеры), анти‑спам (лимиты, cooldown), risk_scale.
- **Order Engine:** лимит/стоп заявки, TTL/репрайс, ретест‑очередь, ReverseOnBreak (переворот по пробою).
- **Position Manager:** TP1/TP2/TP3 (частичные через серверные reduce‑ордера), BE после TP1, ATR‑трейл после TP2, логи CSV.
- **Risk Governor:** дневные лимиты (‑% / −R), lock (close‑only), кулдаун после серии стопов, CSV‑лог.
- **News:** CSV‑календарь с окнами блокировки (guard).
- **Viewer:** графика фигур/якорей/уровней, телеметрия.
- **Пресеты:** EURUSD M15 base; доп. наборы (DualMA H1/H4 TrendStrict/Alt, TripleScreen HARD/SOFT).

---

## 2) Матрица «что теряли на переезде» (из чата №1)
| Категория | Идея / Фича | Статус |
|---|---|---|
| Фильтры | Donchian / Aroon / SuperTrend / VWAP / Squeeze | ❌ |
| Геометрия | Two‑point trendline (3rd touch), StructureTrail | ❌ |
| Fibo | Confluence/Cluster, Harmonic AB=CD | ⏳ частично |
| Pattern | CandleConfirm (pin/engulf), H&S / DT/DB / Flag / Wedge / Supply&Demand | ❌ |
| Divergence | RSI дивергенции (regular/hidden) | ❌ |
| News | Playbook (Momentum / Break&Hold / Fade / Straddle) + SurpriseZ | ❌ |
| Macro | USD basket в CCY Bias, Flip‑протокол | ❌ |
| Risk/Portfolio | Portfolio Risk Manager (корзины, корреляции, кэпы) | ❌ |
| Exec | Time‑stop, No‑chase, MinSpace до барьера | ❌ |
| AI/ML | ML‑Gate, Bandit, Regime Engine, Health Monitor | ❌ |
| Infra | SandboxEA, auto‑combine (ini+bat+PS), WFO‑пайплайн | ❌ |

Легенда: ✅ есть / ⏳ частично / ❌ нет (переносим в план).

---

## 3) План релизов
### v2.0.2 (ядро без ML) — **основной спринт**
**Цели/модули:**
1) **Fibo Pullback (расширенный)**  
   – Anchors: ZZ/HTF swing/session; уровни 38.2/50/61.8/78.6, зона GP;  
   – **Confluence/Cluster** (сшивка уровней + ATR‑кластеры);  
   – Опц.: **AB=CD** (первый harmonic).  
   **DoD:** тест‑план TC‑F1..F15; объекты `TYP_FIBO_*`; регрессы H1/H4 EURUSD/GBPUSD/USDJPY.

2) **Triangle.HYBRID**  
   – Режимы: **EDGE_FADE**, **BREAKOUT** (measured‑move H), **TREND_ACCUM** (near‑apex);  
   – Геометрия: наклоны, конвергенция, окно апекса; ретест‑логика.  
   **DoD:** TC‑T1..T15; переключатель ATR‑целей ⇄ measured‑move; логи геометрии.

3) **RSI Divergence/Convergence**  
   – Regular (разворот) / Hidden (продолжение); фильтры ATR, delta RSI; опция filter‑mode (через Resolver).  
   **DoD:** TC‑Diverg*, графика линий на цене и RSI, совместимость с TripleScreen.

4) **DualMA Anchor Pro**  
   – Режимы: **TrendStrict (EMA200)** и **AltFilters** (MinATR/MaxATR/MaxSpread + anti‑flat);  
   – Сигналы: Bounce / Break / Retest / Pinch→Momentum; **Headwind‑gate**; **Re‑entry cooldown**.  
   **DoD:** TC‑D1..D15; пресеты H1/H4 (`TrendStrict`, `AltFilters`).

5) **Exec‑усилители**  
   – **MinSpace** до барьера (≥0.6–1.0 ATR), **Time‑stop** (N баров без прогресса), **No‑chase** (макс. проскальз./дистанция).  
   **DoD:** юнит‑чек правил + визуальные кейсы.

6) **VWAP (базовый)**  
   – Daily/Weekly anchored VWAP как headwind/confirm в Resolver/TripleScreen.  
   **DoD:** включаемый фильтр, логи дистанции до VWAP.

**Артефакты v2.0.2:**  
- `typ_fibo.mqh`, `typ_triangle.mqh` (HYBRID), `typ_divergence.mqh`, `typ_dualma_pro.mqh`, `typ_execfilters.mqh`, `typ_vwap.mqh` + README_* + TestPlan_*.  
- Обновлённые пресеты: `TYP2_Presets_Core_v202.zip` (DualMA Pro, Triangle.HYBRID, Fibo Pullback, TripleScreen HARD/SOFT).

---

### v2.1 (портфель/макро/новости)
- **Portfolio Risk Manager** (корзины, корреляции, кэпы, лимиты −R дневные/недельные; AllowAddOn после BE).  
- **CCY Bias: USD basket** (индекс силы USD; бонус/штраф).  
- **Flip‑протокол** при смене доминанты (авторедукция/flat/safe‑mode).  
- **NewsPlaybook**: Momentum / Break&Hold / Fade / Straddle + **SurpriseZ**.  
- **HeadwindScore** (MA200 / круглый / VWAP / Fibo‑кластер).

**Артефакты v2.1:** `typ_portfolio.mqh`, `typ_ccy_usd.mqh`, `typ_flip.mqh`, `typ_newsplaybook.mqh`, `typ_headwind.mqh` + README/TestPlan.

---

### v3.0 (ML/режимы/мониторинг)
- **Regime Engine** (TREND/NORMAL/FLAT + авто‑переключение по ADX/CHOP/ATR/EMA‑slope).  
- **ML‑Gate** (P(TP1>SL) фильтр), **Bandit** (Limit vs Break vs Retest), **online‑recalibration**.  
- **Health Monitor** (PF, Expectancy, Hit‑rate, MFE/MAE, **CUSUM/Page‑Hinkley**).  
- **SandboxEA** + **WFO‑пайплайн** (ini/bat/PS), combining результатов.

---

## 4) Чек‑лист внедрения (последовательность работ)
### 4.1 Код‑этапы (v2.0.2)
[ ] Подключить **DualMA Pro** (новый файл, alias старого DualMA внутри `typ_strategies.mqh`).  
[ ] Обновить **Triangle → HYBRID** (режимы, цели, геометрия).  
[ ] Расширить **Fibo Pullback** (кластер, AB=CD, конфиги).  
[ ] Добавить **RSI Divergence** (filter‑mode + entry‑mode).  
[ ] Включить **Exec‑усилители** (MinSpace, Time‑stop, No‑chase).  
[ ] Добавить **VWAP** (headwind/confirm).  
[ ] Расширить **Resolver**: веса новых модулей, бонусы/штрафы, логи причин JSON.  
[ ] Привести **логирование** к единому формату (entry_type, score_breakdown, barriers).

### 4.2 Пресеты/тесты
[ ] Сборка `TYP2_Presets_Core_v202.zip`:  
  • DualMA_TrendStrict_H1/H4, DualMA_AltFilters_H1/H4;  
  • Triangle_HYBRID_H1/H4; Fibo_Pullback_H1/H4;  
  • TripleScreen_HARD/SOFT (D1/H4/H1 и H4/H1/M15).  
[ ] Визуальные кейсы (графики/скрины): по 1–2 на модуль.  
[ ] **Регрессы:** EURUSD/GBPUSD/USDJPY H1/H4 (3–6 мес).  
[ ] **WFO‑мини**: скользящие окна 6м/3м, метрика OnTesterScore: `Exp×Trades×√PF − DD% − Stagnation`.

### 4.3 Документация/рынок
[ ] README RU/EN (таблица параметров; FAQ).  
[ ] Скрины (Viewer + вход/выход).  
[ ] Чейнджлог `CHANGELOG.md` (2.0.2).  
[ ] Маркет‑черновик (описание, ограничение DEMO).

---

## 5) Технические детали интеграции
- **Файлы:**  
  `typ_dualma_pro.mqh`, `typ_triangle.mqh` (HYBRID), `typ_fibo.mqh` (расш.), `typ_divergence.mqh`,  
  `typ_execfilters.mqh` (MinSpace/Time‑stop/No‑chase), `typ_vwap.mqh`.  

- **Вставки:**  
  – В `typ_strategies.mqh`: регистрация новых провайдеров сигналов (DualMA_Pro / Triangle.HYBRID / Fibo.Pullback / RSI.Div).  
  – В `typ_triplescreen.mqh`: опциональный учёт VWAP/Headwind для SOFT‑режима.  
  – В `typ_core.mqh`/`typ_filters.mqh`: вызовы Exec‑усилителей.  
  – В `typ_resolver.mqh`: веса, score‑breakdown, JSON‑лог причин.

- **Сохранить лимит ≤ 20 файлов в корне.** Доп. README/скрины/пресеты держим в `Extras/`.

---

## 6) Тест‑план (минимум, что гоним перед релизом 2.0.2)
- **Визуальные проверки:** по модулю 5–10 сетапов (позитив/негатив/краевые).  
- **Прогоны:** 3 символа × 2 ТФ × 2 режима TripleScreen = 12 серий.  
- **Критерии «ОК» (базовые):** PF ≥ 1.20, Trades ≥ 150, DD ≤ 20%, Stagnation ≤ 120 дней.  
- **Сравнение:** DualMA_TrendStrict vs AltFilters (ожидаем: Strict реже, но чище; Alt – чаще, но с фильтрами).

---

## 7) Backlog (v3.0+)
- Portfolio Risk Manager; CCY USD basket; Flip‑протокол.  
- NewsPlaybook + SurpriseZ.  
- Regime Engine; ML‑Gate; Bandit; Health Monitor.  
- Two‑point trendline; StructureTrail; PatternScore; Supply/Demand.  
- Donchian/Aroon/SuperTrend; VWAP Pro; Squeeze.  
- SandboxEA; auto‑combine; WFO‑пайплайн; расширенные CSV‑логи.

---

## 8) История и ссылки
- **Handover v2.0.1:** патчи `typ_triplescreen.mqh`, `typ_ccybias.mqh`, `typ_risk.mqh`, пресеты `SET_*`.  
- **Документы перехода:** части 1–6 + «доп. пункты», финальный чек‑лист, RiskGovernor v2.2 PATCH.  
- **Этот Roadmap** — собран из 7 частей зависшего чата №1 и актуального состояния кода v2.0.1.

— **Конец Roadmap** —

TYP2 — P0 Pack #003 (T2-001 DualMA Pro — "real" минимальная логика)

Файл:
- Experts/TYP2/typ_dualma_pro.mqh

Возможности:
- TrendStrict (EMA fast vs slow + slope)
- AltFilters (ATR min, max spread, flat guard)
- Сигналы: Bounce / Break / Retest / Pinch (упрощённые)

Подключение:
- В проекте include уже присутствует; замена файла безопасна.
- В Resolver можно использовать:
    int dir;
    if(DMP_TrendStrict(_Symbol, _Period, dir) && DMP_AltFiltersGate(_Symbol,_Period)) { ... }

Примечание: алгоритмы упрощены для быстрой интеграции; параметры — инпуты.

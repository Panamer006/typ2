TYP2  P0 Pack #002 (T2-007 Resolver v2)

- Experts/TYP2/typ_resolver_v2.mqh: централизованный входной гейт с JSON-трассировкой.
- Безопасно: если typ_vwap.mqh не подключён в проекте, VWAP-проверки пропускаются.
Подключение:
   #include "typ_resolver_v2.mqh"
   string reason;
   if(!ResolverV2_AllowEntry(dir, entryPrice, reason)) return(false);

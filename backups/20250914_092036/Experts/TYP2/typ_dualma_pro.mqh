#property strict
#ifndef __TYP_DUALMA_PRO_MQH__
#define __TYP_DUALMA_PRO_MQH__

// DualMA Pro  заготовка (TrendStrict / AltFilters / hooks для Headwind/Re-entry)
class TYP_DualMA_Pro
{
private:
   bool m_use;
   int  m_fast, m_slow;
   ENUM_TIMEFRAMES m_tf;

public:
   void Setup(bool use, int fast, int slow, ENUM_TIMEFRAMES tf)
   {
      m_use = use; m_fast = fast; m_slow = slow; m_tf = tf;
      // TODO: добавить хэндлы EMA и подготовку фильтров (ATR/Spread/Flat)
   }

   bool Ready() const { return m_use; }

   // TODO: методы:
   //  - bool SignalBounce(...), SignalBreak(...), SignalRetest(...), SignalPinch(...)
   //  - bool TrendStrictGate(...), AltFiltersGate(...)
   //  - void  ReentryCooldownTick(...), HeadwindGate(...)
};

#endif // __TYP_DUALMA_PRO_MQH__

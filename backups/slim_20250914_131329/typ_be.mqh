#ifndef __TYP_BE_MQH__
#define __TYP_BE_MQH__
#include <Trade/Trade.mqh>
CTrade _beTrade;

class TYP_BEManager
{
  bool   m_tiered;
  int    m_t1_pts; double m_t1_r; int m_off1; int m_off2; int m_off3;
public:
  void Setup(bool tiered,int t1_pts,double t1_r,int off1,int off2,int off3)
  { m_tiered=tiered; m_t1_pts=t1_pts; m_t1_r=t1_r; m_off1=off1; m_off2=off2; m_off3=off3; }

  void Maintain(const string sym)
  {
    if(!PositionSelect(sym)) return;
    long   type   = (long)PositionGetInteger(POSITION_TYPE);
    double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
    double sl     = PositionGetDouble(POSITION_SL);
    double price  = (type==POSITION_TYPE_BUY) ? SymbolInfoDouble(sym,SYMBOL_BID) : SymbolInfoDouble(sym,SYMBOL_ASK);

    double profit_pts = (type==POSITION_TYPE_BUY) ? (price-entry) : (entry-price);
    double new_sl = sl;

    // Tier 1: early safety
    if(m_tiered && profit_pts/_Point > m_t1_pts)
      new_sl = (type==POSITION_TYPE_BUY) ? entry + m_off1*_Point : entry - m_off1*_Point;

    // Tier 2: true BE at ~0.5R (approx via price move)
    if(m_tiered && profit_pts >= 0.5*(MathAbs(entry-sl)))
      new_sl = (type==POSITION_TYPE_BUY) ? entry + m_off2*_Point : entry - m_off2*_Point;

    // Tier 3: lock-in small profit (~0.8R)
    if(m_tiered && profit_pts >= 0.8*(MathAbs(entry-sl)))
      new_sl = (type==POSITION_TYPE_BUY) ? entry + m_off3*_Point : entry - m_off3*_Point;

    if(MathAbs(new_sl-sl) >= 0.1*_Point)
    {
      _beTrade.PositionModify(sym, new_sl, PositionGetDouble(POSITION_TP));
    }
  }
};

#endif // __TYP_BE_MQH__


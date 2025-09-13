#pragma once
#include <Trade/Trade.mqh>

CTrade _exTrade;

class TYP_Exit
{
  ENUM_EXIT_MODE m_mode; double m_sh1,m_sh2,m_sh3;
public:
  void Setup(ENUM_EXIT_MODE mode,double s1,double s2,double s3){ m_mode=mode; m_sh1=s1; m_sh2=s2; m_sh3=s3; }

  void PlaceReduceOrders(const string sym, int dir, double lot, double tp1, double tp2, double tp3)
  {
    if(m_mode!=EXIT_SINGLE_PARTIALS_SERVER_LIMITS) return;
    if(lot<=0) return;

    double v1 = NormalizeLots(sym, lot*m_sh1);
    double v2 = NormalizeLots(sym, lot*m_sh2);
    double v3 = NormalizeLots(sym, lot*m_sh3);

    if(dir==DIR_LONG)
    {
      if(v1>0 && tp1>0) PlaceLimit(sym, ORDER_TYPE_SELL_LIMIT, v1, tp1);
      if(v2>0 && tp2>0) PlaceLimit(sym, ORDER_TYPE_SELL_LIMIT, v2, tp2);
      if(v3>0 && tp3>0) PlaceLimit(sym, ORDER_TYPE_SELL_LIMIT, v3, tp3);
    }
    else if(dir==DIR_SHORT)
    {
      if(v1>0 && tp1>0) PlaceLimit(sym, ORDER_TYPE_BUY_LIMIT, v1, tp1);
      if(v2>0 && tp2>0) PlaceLimit(sym, ORDER_TYPE_BUY_LIMIT, v2, tp2);
      if(v3>0 && tp3>0) PlaceLimit(sym, ORDER_TYPE_BUY_LIMIT, v3, tp3);
    }
  }

  void Maintain(const string sym)
  {
    // TODO: re-sync reduce orders after BE/trail modifications if needed
  }

private:
  double NormalizeLots(const string sym,double lot)
  {
    double step = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
    double minv = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
    double maxv = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
    double out  = MathMax(minv, MathMin(maxv, MathFloor(lot/step)*step));
    return out;
  }

  bool PlaceLimit(const string sym, ENUM_ORDER_TYPE t, double vol, double price)
  {
    MqlTradeRequest r; MqlTradeResult rr; ZeroMemory(r); ZeroMemory(rr);
    r.action = TRADE_ACTION_PENDING;
    r.type   = t;
    r.symbol = sym;
    r.volume = vol;
    r.price  = price;
    r.type_filling = ORDER_FILLING_RETURN;
    bool ok = OrderSend(r, rr);
    if(!ok) Print("Reduce order failed ", sym, " ", vol, " @", price, " err:", GetLastError());
    return ok;
  }
};

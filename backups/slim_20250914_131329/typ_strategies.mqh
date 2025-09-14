#ifndef __TYP_STRATEGIES_MQH__
#define __TYP_STRATEGIES_MQH__
#include "typ_core.mqh"

// === Signature strategy: DualMA Anchor (primary EMA + adaptive EMA by High/Low) ===
class TYP_DualMA
{
  bool m_use; int m_p1, m_p2; ENUM_TIMEFRAMES m_tf;
  int h_ma1_close; int h_ma2_low; int h_ma2_high;
public:
  void Setup(bool use,int p1,int p2,ENUM_TIMEFRAMES tf)
  {
    m_use=use; m_p1=p1; m_p2=p2; m_tf=tf;
    h_ma1_close = iMA(_Symbol, m_tf, m_p1, 0, MODE_EMA, PRICE_CLOSE);
    h_ma2_low   = iMA(_Symbol, m_tf, m_p2, 0, MODE_EMA, PRICE_LOW);
    h_ma2_high  = iMA(_Symbol, m_tf, m_p2, 0, MODE_EMA, PRICE_HIGH);
  }

  void Evaluate(const string sym, SignalCandidate &out)
  {
    if(!m_use){ out.valid=false; return; }
    double ma1[], ma2L[], ma2H[];
    ArraySetAsSeries(ma1,true); ArraySetAsSeries(ma2L,true); ArraySetAsSeries(ma2H,true);
    if(CopyBuffer(h_ma1_close,0,0,3,ma1)<3) { out.valid=false; return; }
    if(CopyBuffer(h_ma2_low,  0,0,3,ma2L)<3) { out.valid=false; return; }
    if(CopyBuffer(h_ma2_high, 0,0,3,ma2H)<3) { out.valid=false; return; }

    MqlTick tk; SymbolInfoTick(sym, tk);
    double price = tk.bid;

    bool above = (price > ma1[0]);
    double ma2  = above ? ma2L[0] : ma2H[0];

    double atr = TYP_Utils::ATR(sym, m_tf, 14);
    double touch_buf = 0.20*atr;
    double break_buf = 0.25*atr;

    ZeroMemory(out);
    out.module = "DualMA";

    // Bounce
    if(above && (price - ma2) <= touch_buf)
    {
      out.valid=true; out.dir=DIR_LONG; out.entry=price; out.sl=ma2 - 0.35*atr;
      out.tp1=price + 0.62*atr; out.tp2=price + 1.0*atr; out.tp3=price + 1.5*atr;
      out.reason="Bounce@MA2(Low)"; out.score=70; return;
    }
    if(!above && (ma2 - price) <= touch_buf)
    {
      out.valid=true; out.dir=DIR_SHORT; out.entry=price; out.sl=ma2 + 0.35*atr;
      out.tp1=price - 0.62*atr; out.tp2=price - 1.0*atr; out.tp3=price - 1.5*atr;
      out.reason="Bounce@MA2(High)"; out.score=70; return;
    }

    // Break & go (placeholder)
    if(above && (price - ma2) > break_buf)
    {
      out.valid=true; out.dir=DIR_LONG; out.entry=price; out.sl=ma2 - 0.35*atr;
      out.tp1=price + 0.62*atr; out.tp2=price + 1.0*atr; out.tp3=price + 1.5*atr;
      out.reason="BreakAboveMA2"; out.score=60; return;
    }
    if(!above && (ma2 - price) > break_buf)
    {
      out.valid=true; out.dir=DIR_SHORT; out.entry=price; out.sl=ma2 + 0.35*atr;
      out.tp1=price - 0.62*atr; out.tp2=price - 1.0*atr; out.tp3=price - 1.5*atr;
      out.reason="BreakBelowMA2"; out.score=60; return;
    }

    out.valid=false;
  }
};

// === Placeholders for Triangle / Fibo / Divergence / Resolver (to be implemented) ===

#endif // __TYP_STRATEGIES_MQH__


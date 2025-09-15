#property strict
#property description "TLP Demo: Trendline Pro v1 viewer/signaller"
#include "modules/typ_trendlinepro.mqh"
#include "lib/typ_draw.mqh"

input int    TL_SwingLeft  = 4;
input int    TL_SwingRight = 3;
input int    TL_LookBackBars = 500;
input int    TL_ATR        = 14;
input double TL_TouchATR   = 0.35;
input double TL_BreakATR   = 0.35;
input int    TL_RetestBars = 5;
input double TL_FBO_ATR    = 0.40;
input int    TL_FBO_Bars   = 3;
input double TL_WickBody   = 1.50;
input int    TL_MinGap     = 6;
input double TL_ChannelATR = 2.0;

CTLTrendlinePro TLP;
TLProInput      P;

int OnInit()
{
  P.swingLeft=TL_SwingLeft; P.swingRight=TL_SwingRight; P.lookBackBars=TL_LookBackBars;
  P.atrPeriod=TL_ATR; P.tolTouchATR=TL_TouchATR; P.breakBufferATR=TL_BreakATR;
  P.retestBars=TL_RetestBars; P.fboCloseATR=TL_FBO_ATR; P.fboLookAheadBars=TL_FBO_Bars;
  P.wickBodyMin=TL_WickBody; P.minBarsBetweenTouches=TL_MinGap; P.channelWidthATR=TL_ChannelATR;
  if(!TLP.Init(_Symbol,_Period,P)){ Print("TLP init failed"); return(INIT_FAILED); }
  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){}

void OnTick()
{
  static datetime last=0; if(Time[0]==last) return; last=Time[0];
  TLSignal s; if(!TLP.Evaluate(s)) return;

  // Рисуем TL и канал
  if(s.iA>0 && s.iB>0){
    datetime tA=iTime(_Symbol,_Period,s.iA), tB=iTime(_Symbol,_Period,s.iB);
    TYPD::DrawTrend("TLP_BASE",tA,s.pA,tB,s.pB, clrAqua);
    if(s.iOpp>0){
      // параллель через противоположный свинг
      // копируем наклон базовой и проводим через pOpp
      double m = (s.pB - s.pA) / (s.iB - s.iA + 1e-9);
      double pOppB = s.pOpp;               // через точку Opp
      double pOppA = pOppB - m*(s.iB - s.iA);
      TYPD::DrawTrend("TLP_CHAN",tA,pOppA,tB,pOppB, clrDarkSlateBlue);
    }
  }

  string kind = (s.type==TL_RETEST_FADE_BUY?"RETEST_FADE_BUY":
                s.type==TL_RETEST_FADE_SELL?"RETEST_FADE_SELL":
                s.type==TL_BREAK_RETAKE_BUY?"BREAK_RETAKE_BUY":
                s.type==TL_BREAK_RETAKE_SELL?"BREAK_RETAKE_SELL":
                s.type==TL_FALSE_BREAK_BUY ?"FBO_BUY":
                s.type==TL_FALSE_BREAK_SELL?"FBO_SELL":"CHANNEL");
  PrintFormat("[TL] %s | price=%.5f tp=%.5f note=%s", kind, s.price, s.tp, s.note);
}

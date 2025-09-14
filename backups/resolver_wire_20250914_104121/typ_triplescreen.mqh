#ifndef __TYP_TRIPLESCREEN_MQH__
#define __TYP_TRIPLESCREEN_MQH__

#include "typ_core.mqh"
#include "typ_ccybias.mqh"
#include "typ_force.mqh"
#include "typ_envelopes.mqh"

input int              Trend_EMA_Period      = 200;
input TS_Mode          TS_ModeSetting        = TS_HARD;
input ENUM_TIMEFRAMES  TF_Trend              = PERIOD_H4;
input ENUM_TIMEFRAMES  TF_Setup              = PERIOD_H1;
input ENUM_TIMEFRAMES  TF_Trigger            = PERIOD_M15;

input bool             Setup_UseDMA          = true;
input bool             Setup_UseTriangle     = true;

input int              Setup_DMA_MA_Period   = 34;
input ENUM_MA_METHOD   Setup_DMA_Method      = MODE_EMA;
input int              Setup_DMA_ATR_Period  = 14;
input double           Setup_DMA_TouchBuf_ATR= 0.20;
input double           Setup_DMA_BreakBuf_ATR= 0.25;

input int              Setup_TRI_FractalDepth= 2;
input int              Setup_TRI_SearchWindow= 300;
input double           Setup_TRI_TouchBuf_ATR= 0.20;
input double           Setup_TRI_BreakBuf_ATR= 0.25;
input int              Setup_TRI_ATR_Period  = 14;

input bool             UseForceTrigger       = true;
input bool             UseEnvelopesTrigger   = true;
input bool             Trigger_ANY           = true;

input bool             UseRSITrigger         = true;
input ENUM_TIMEFRAMES  RSI_TF                = PERIOD_M15;
input int              RSI_Period            = 14;
input double           RSI_LongLevel         = 55.0;
input double           RSI_ShortLevel        = 45.0;
input bool             RSI_UseCross          = true;

input bool             UseStochTrigger       = true;
input ENUM_TIMEFRAMES  Stoch_TF              = PERIOD_M15;
input int              Stoch_K               = 14;
input int              Stoch_D               = 3;
input int              Stoch_Slow            = 3;
input ENUM_MA_METHOD   Stoch_Method          = MODE_SMA;
input ENUM_STO_PRICE   Stoch_Price           = STO_LOWHIGH;
input bool             Stoch_UseLevelFilter  = true;
input double           Stoch_LowLevel        = 20.0;
input double           Stoch_HighLevel       = 80.0;

input double           TS_W_Trend            = 1.0;
input double           TS_W_Setup            = 1.0;
input double           TS_W_Trigger          = 1.0;
input double           TS_W_Conflict         = 1.0;
input double           TS_W_Headwind         = 1.0;
input double           TS_W_Cross            = 0.5;
input double           TS_ScoreThreshold     = 2.0;

input bool             Bias_HardBlockInHARD  = true;
input bool             Cross_HardBlockInHARD = false;

int hEMA_trend = INVALID_HANDLE;
int hMA34_low  = INVALID_HANDLE, hMA34_high = INVALID_HANDLE, hMA34_close = INVALID_HANDLE;
int hATR_setup = INVALID_HANDLE;
int hFr        = INVALID_HANDLE;

int hRSI       = INVALID_HANDLE;
int hStoch     = INVALID_HANDLE;

double __tb(int h,int shift=0){ double a[]; if(CopyBuffer(h,0,shift,1,a)<1) return 0; return a[0]; }

void __ensure_setup(){
  if(hMA34_low  == INVALID_HANDLE)  hMA34_low  = iMA(_Symbol, TF_Setup, Setup_DMA_MA_Period, 0, Setup_DMA_Method, PRICE_LOW);
  if(hMA34_high == INVALID_HANDLE)  hMA34_high = iMA(_Symbol, TF_Setup, Setup_DMA_MA_Period, 0, Setup_DMA_Method, PRICE_HIGH);
  if(hMA34_close== INVALID_HANDLE)  hMA34_close= iMA(_Symbol, TF_Setup, Setup_DMA_MA_Period, 0, Setup_DMA_Method, PRICE_CLOSE);
  if(hATR_setup == INVALID_HANDLE)  hATR_setup = iATR(_Symbol, TF_Setup, Setup_DMA_ATR_Period);
  if(hFr        == INVALID_HANDLE)  hFr        = iFractals(_Symbol, TF_Setup);
}

int trend_dir(){
  if(hEMA_trend==INVALID_HANDLE) hEMA_trend=iMA(_Symbol, TF_Trend, Trend_EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
  double ema[2]; if(CopyBuffer(hEMA_trend,0,0,2,ema)<2) return 0;
  double p = iClose(_Symbol, TF_Trend, 0);
  if(p>ema[0] && ema[0]>ema[1]) return +1;
  if(p<ema[0] && ema[0]<ema[1]) return -1;
  return 0;
}

bool setup_dma_ok(int dir){
  if(!Setup_UseDMA) return false;
  __ensure_setup();
  double px  = iClose(_Symbol, TF_Setup, 0);
  double atr = __tb(hATR_setup,0); if(atr<=0) return false;
  double mL=__tb(hMA34_low,0), mH=__tb(hMA34_high,0), mC=__tb(hMA34_close,0);
  bool bounce_long  = (dir>0 && px<=mL+Setup_DMA_TouchBuf_ATR*atr);
  bool bounce_short = (dir<0 && px>=mH-Setup_DMA_TouchBuf_ATR*atr);
  bool broke_up     = (dir>0 && px> mC+Setup_DMA_BreakBuf_ATR*atr);
  bool broke_down   = (dir<0 && px< mC-Setup_DMA_BreakBuf_ATR*atr);
  return (bounce_long||bounce_short||broke_up||broke_down);
}

bool last_two_fr(int buf_idx,int look,int &i1,double &p1,int &i2,double &p2){
  double b[]; ArraySetAsSeries(b,true);
  int need=look+50;
  if(CopyBuffer(hFr,buf_idx,0,need,b)<10) return false;
  int c=0;
  for(int i=1;i<need && c<2;i++){
    if(b[i]!=0.0){
      if(c==0){i1=i;p1=b[i];} else{ i2=i;p2=b[i]; }
      c++;
    }
  }
  return (c==2);
}
double line_p(double pA,int iA,double pB,int iB,int x=0){
  if(iA==iB) return pA;
  double a=(pA-pB)/(double)(iA-iB); double b=pA-a*iA;
  return a*x+b;
}

bool setup_triangle_ok(int dir){
  if(!Setup_UseTriangle) return false;
  __ensure_setup();
  double atrv[]; if(CopyBuffer(hATR_setup,0,0,1,atrv)<1) return false;
  double A=atrv[0]; if(A<=0) return false;
  int iu1,iu2,id1,id2; double pu1,pu2,pd1,pd2;
  if(!last_two_fr(0,Setup_TRI_SearchWindow,iu1,pu1,iu2,pu2)) return false;
  if(!last_two_fr(1,Setup_TRI_SearchWindow,id1,pd1,id2,pd2)) return false;
  double up=line_p(pu1,iu1,pu2,iu2,0), lo=line_p(pd1,id1,pd2,id2,0), px=iClose(_Symbol, TF_Setup, 0);
  bool near_up=(up>0 && (up-px)<=Setup_TRI_TouchBuf_ATR*A);
  bool near_lo=(lo>0 && (px-lo)<=Setup_TRI_TouchBuf_ATR*A);
  bool br_up  =(up>0 && px>up+Setup_TRI_BreakBuf_ATR*A);
  bool br_dn  =(lo>0 && px<lo-Setup_TRI_BreakBuf_ATR*A);
  if(dir>0) return (near_lo||br_up);
  if(dir<0) return (near_up||br_dn);
  return false;
}

int rsi_ready(){ if(hRSI==INVALID_HANDLE) hRSI=iRSI(_Symbol, RSI_TF, RSI_Period, PRICE_CLOSE); return hRSI; }
bool rsi_values(double &r0,double &r1){ if(rsi_ready()==INVALID_HANDLE) return false; double a[2]; if(CopyBuffer(hRSI,0,0,2,a)<2) return false; r0=a[0]; r1=a[1]; return true; }
bool RSI_TriggerOK(int dir){
  if(!UseRSITrigger) return true;
  double r0,r1; if(!rsi_values(r0,r1)) return false;
  if(RSI_UseCross){
    if(dir>0) return (r1<=RSI_LongLevel  && r0>RSI_LongLevel);
    if(dir<0) return (r1>=RSI_ShortLevel && r0<RSI_ShortLevel);
    return false;
  }else{
    if(dir>0) return (r0>RSI_LongLevel);
    if(dir<0) return (r0<RSI_ShortLevel);
    return false;
  }
}

int stoch_ready(){ if(hStoch==INVALID_HANDLE) hStoch=iStochastic(_Symbol, Stoch_TF, Stoch_K, Stoch_D, Stoch_Slow, Stoch_Method, Stoch_Price); return hStoch; }
bool stoch_values(double &k0,double &k1,double &d0,double &d1){
  if(stoch_ready()==INVALID_HANDLE) return false;
  double K[2],D[2];
  if(CopyBuffer(hStoch,0,0,2,K)<2) return false;
  if(CopyBuffer(hStoch,1,0,2,D)<2) return false;
  k0=K[0]; k1=K[1]; d0=D[0]; d1=D[1]; return true;
}
bool Stoch_TriggerOK(int dir){
  if(!UseStochTrigger) return true;
  double k0,k1,d0,d1; if(!stoch_values(k0,k1,d0,d1)) return false;
  if(dir>0){
    bool crossUp = (k1<=d1 && k0>d0);
    if(!crossUp) return false;
    if(Stoch_UseLevelFilter) return (MathMin(k0,k1) <= Stoch_LowLevel);
    return true;
  }
  if(dir<0){
    bool crossDn = (k1>=d1 && k0<d0);
    if(!crossDn) return false;
    if(Stoch_UseLevelFilter) return (MathMax(k0,k1) >= Stoch_HighLevel);
    return true;
  }
  return false;
}

bool trigger_ok(int dir){
  int enabled=0, ok=0;
  if(UseForceTrigger){ enabled++; if(Force_TriggerOK(dir)) ok++; }
  if(UseEnvelopesTrigger){ enabled++; if(Envelopes_TouchDir(dir,0)) ok++; }
  if(UseRSITrigger){ enabled++; if(RSI_TriggerOK(dir)) ok++; }
  if(UseStochTrigger){ enabled++; if(Stoch_TriggerOK(dir)) ok++; }
  if(enabled==0) return true;
  return (Trigger_ANY ? (ok>0) : (ok==enabled));
}

bool setup_ok(int dir){
  bool ok=false;
  if(Setup_UseDMA)      ok |= setup_dma_ok(dir);
  if(Setup_UseTriangle) ok |= setup_triangle_ok(dir);
  return ok;
}

bool TS_AllowDir(int dir){
  if(TS_ModeSetting!=TS_HARD) return true;
  int tr = trend_dir();
  if(tr!=dir)                 return false;
  if(!setup_ok(dir))          return false;
  if(!trigger_ok(dir))        return false;

  if(Bias_HardBlockInHARD){
    CCYBiasState b=BiasFor(_Symbol);
    if(dir==+1 && b.delta<0)  return false;
    if(dir==-1 && b.delta>0)  return false;
  }
  if(Cross_HardBlockInHARD){
    double bonus = CCYCrossBonusFor(_Symbol, dir);
    if(bonus < 0.0) return false; // значимый встречный сигнал
  }
  return true;
}

double TS_ScoreDir(int dir){
  if(TS_ModeSetting!=TS_SOFT) return 0.0;
  double sc=0.0;
  int tr = trend_dir();
  if(tr==dir)     sc += TS_W_Trend;
  else if(tr==-dir) sc -= TS_W_Conflict;
  if(setup_ok(dir))   sc += TS_W_Setup;
  if(trigger_ok(dir)) sc += TS_W_Trigger;

  CCYBiasState b=BiasFor(_Symbol);
  if( (dir==+1 && b.delta<0) || (dir==-1 && b.delta>0) )
    sc -= TS_W_Headwind;

  double bonus = CCYCrossBonusFor(_Symbol, dir); // [-1..+1]
  sc += TS_W_Cross * bonus;

  return sc;
}

#endif

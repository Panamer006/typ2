#property strict
#ifndef __TYP_DUALMA_PRO_MQH__
#define __TYP_DUALMA_PRO_MQH__
// ... (минимальная real логика TrendStrict/AltFilters + Bounce/Break/Retest/Pinch)
input int  DMP_FastPeriod=21, DMP_SlowPeriod=55, DMP_SlopeLookback=5;
input ENUM_TIMEFRAMES DMP_TF=PERIOD_CURRENT;
input double DMP_MinSlope=0.0;
input int DMP_ATR_Period=14; input double DMP_ATR_MinATR=0.0, DMP_MaxSpreadPips=2.0, DMP_Flat_K=0.0;
double _pip(string s){double p=SymbolInfoDouble(s,SYMBOL_POINT);int d=(int)SymbolInfoInteger(s,SYMBOL_DIGITS);return (d==3||d==5)?p*10.0:p;}
bool _ema(string s,ENUM_TIMEFRAMES tf,int pr,int sh,double &v){int h=iMA(s,tf,pr,0,MODE_EMA,PRICE_CLOSE);if(h==INVALID_HANDLE)return false;double b[];ArraySetAsSeries(b,true);if(CopyBuffer(h,0,sh,2,b)<2)return false;v=b[0];return true;}
bool _atr(string s,ENUM_TIMEFRAMES tf,int p,double &v){int h=iATR(s,tf,p);if(h==INVALID_HANDLE)return false;double a[];ArraySetAsSeries(a,true);if(CopyBuffer(h,0,0,1,a)<1)return false;v=a[0];return true;}
double _slope(string s,ENUM_TIMEFRAMES tf,int p,int look){int h=iMA(s,tf,p,0,MODE_EMA,PRICE_CLOSE);if(h==INVALID_HANDLE)return 0;double v[];ArraySetAsSeries(v,true);if(CopyBuffer(h,0,0,look+1,v)<look+1)return 0;return (v[0]-v[look])/look;}
bool DMP_AltFiltersGate(string s,ENUM_TIMEFRAMES tf){if(DMP_MaxSpreadPips>0){double spr=SymbolInfoDouble(s,SYMBOL_SPREAD);if(spr> DMP_MaxSpreadPips){PrintFormat("[DMP][ALT] spread=%.1f>%.1f",spr,DMP_MaxSpreadPips);return false;}}
 if(DMP_ATR_MinATR>0){double atr; if(_atr(s,tf,DMP_ATR_Period,atr) && atr<DMP_ATR_MinATR){PrintFormat("[DMP][ALT] atr=%.5f<%.5f",atr,DMP_ATR_MinATR);return false;}}
 if(DMP_Flat_K>0){double atr; if(_atr(s,tf,DMP_ATR_Period,atr)){double pt=SymbolInfoDouble(s,SYMBOL_POINT); if(atr < DMP_Flat_K*pt){Print("[DMP][ALT] flat guard"); return false;}}} return true;}
bool DMP_TrendStrict(string s,ENUM_TIMEFRAMES tf,int &dir){dir=0;double f,s; if(!_ema(s,tf,DMP_FastPeriod,0,f)||!_ema(s,tf,DMP_SlowPeriod,0,s))return false;
 double sf=_slope(s,tf,DMP_FastPeriod,DMP_SlopeLookback), ss=_slope(s,tf,DMP_SlowPeriod,DMP_SlopeLookback);
 if(DMP_MinSlope>0 && (MathAbs(sf)<DMP_MinSlope||MathAbs(ss)<DMP_MinSlope)) return false;
 if(f>s){dir=+1;return true;} if(f<s){dir=-1;return true;} return false;}
bool DMP_Signal_Break(string s,ENUM_TIMEFRAMES tf,int &dir){dir=0;double slow; if(!_ema(s,tf,DMP_SlowPeriod,0,slow))return false;double c0=iClose(s,tf,0), c1=iClose(s,tf,1);
 if(c1<slow && c0>slow){dir=+1;return true;} if(c1>slow && c0<slow){dir=-1;return true;} return false;}
bool DMP_Signal_Retest(string s,ENUM_TIMEFRAMES tf,int &dir){dir=0;double f0,s0,s1; if(!_ema(s,tf,DMP_FastPeriod,0,f0)||!_ema(s,tf,DMP_SlowPeriod,0,s0)||!_ema(s,tf,DMP_SlowPeriod,1,s1))return false;
 double c1=iClose(s,tf,1), c0=iClose(s,tf,0); if(f0>s0 && c1<=s1 && c0>s0){dir=+1;return true;} if(f0<s0 && c1>=s1 && c0<s0){dir=-1;return true;} return false;}
bool DMP_Signal_Pinch(string s,ENUM_TIMEFRAMES tf,int &dir){dir=0;double f0,s0; if(!_ema(s,tf,DMP_FastPeriod,0,f0)||!_ema(s,tf,DMP_SlowPeriod,0,s0))return false;double gap=MathAbs(f0-s0);
 double atr; if(!_atr(s,tf,DMP_ATR_Period,atr)) atr=0; double th=(atr>0?0.15*atr:3*_pip(s)); if(gap<th){double c=iClose(s,tf,0); if(c>s0){dir=+1;return true;} if(c<s0){dir=-1;return true;}} return false;}
#endif

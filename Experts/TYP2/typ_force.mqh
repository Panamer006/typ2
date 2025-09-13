#ifndef __TYP_FORCE_MQH__
#define __TYP_FORCE_MQH__

/*
 Simple momentum/force trigger:
 - EMA of Close (period configurable)
 - Optional: require sign cross on current TF
 - Optional: require that sign aligns with higher-TF trend (external check is in TripleScreen)
*/

input ENUM_TIMEFRAMES  Force_TF            = PERIOD_M15;
input int              Force_PeriodEMA     = 13;
input double           Force_MinAbs        = 0.0;   // minimal absolute force to accept
input bool             Force_RequireCross  = true;  // require sign cross on the last bar
input bool             Force_SignInTrend   = true;  // informational; TripleScreen enforces separately

int hForceEMA = INVALID_HANDLE;

double __force_val(int shift=0){
  if(hForceEMA==INVALID_HANDLE)
    hForceEMA = iMA(_Symbol, Force_TF, Force_PeriodEMA, 0, MODE_EMA, PRICE_CLOSE);
  double ema[2]; if(CopyBuffer(hForceEMA,0,shift,2,ema)<2) return 0.0;
  double price = iClose(_Symbol, Force_TF, shift);
  return price - ema[0]; // positive => upward momentum
}

// Return true if momentum condition passes for direction dir (+1/-1)
bool Force_TriggerOK(int dir){
  if(dir==0) return false;
  double f0 = __force_val(0);
  if(MathAbs(f0) < Force_MinAbs) return false;
  if(Force_RequireCross){
    double f1 = __force_val(1);
    if(!( (dir>0 && f1<=0 && f0>0) || (dir<0 && f1>=0 && f0<0) )) return false;
  }else{
    if(!( (dir>0 && f0>0) || (dir<0 && f0<0) )) return false;
  }
  return true;
}

#endif // __TYP_FORCE_MQH__

#ifndef __TYP_ENV_MQH__
#define __TYP_ENV_MQH__

/*
 Envelopes proximity trigger:
 - Checks touch/exit relative to upper/lower band on Trigger TF.
*/

input ENUM_TIMEFRAMES Env_TF               = PERIOD_M15;
input int            Env_Period            = 34;
input ENUM_MA_METHOD Env_Method            = MODE_EMA;
input double         Env_DeviationPcnt     = 0.8;   // percent deviation
input ENUM_APPLIED_PRICE Env_AppliedPrice  = PRICE_CLOSE;
input int            Env_TouchTolerancePts = 10;

int hEnv = INVALID_HANDLE;

bool __env_ready(){
  if(hEnv!=INVALID_HANDLE) return true;
  hEnv = iEnvelopes(_Symbol, Env_TF, Env_Period, 0, Env_Method, Env_AppliedPrice, Env_DeviationPcnt);
  return (hEnv!=INVALID_HANDLE);
}

bool Envelopes_TouchDir(int dir, int shift){
  if(!__env_ready()) return false;
  double up[], lo[]; if(CopyBuffer(hEnv, 0, shift, 1, up)<1) return false;
  if(CopyBuffer(hEnv, 1, shift, 1, lo)<1) return false;
  double price = iClose(_Symbol, Env_TF, shift);
  int pt = (int)_Point;
  if(dir>0){
    return (price <= lo[0] + Env_TouchTolerancePts*pt);
  }else if(dir<0){
    return (price >= up[0] - Env_TouchTolerancePts*pt);
  }
  return false;
}

#endif // __TYP_ENV_MQH__

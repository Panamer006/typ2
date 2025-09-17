#ifndef __TYP_CORE_MQH__
#define __TYP_CORE_MQH__

// SLIM stub: только то, что точно безопасно и часто нужно

// Гиджинг/неттинг  корректная реализация для MQL5
bool IsHedging()
{
  long mode = (long)AccountInfoInteger(ACCOUNT_MARGIN_MODE);
  return (mode==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING || mode==ACCOUNT_MARGIN_MODE_EXCHANGE);
}
/* === TYP Utils (unified) === */
double _pip(const string s){
  const int d=(int)SymbolInfoInteger(s,SYMBOL_DIGITS);
  const double p=SymbolInfoDouble(s,SYMBOL_POINT);
  return (d==3||d==5)? p*10.0 : p;
}
double _pips2price(const string s,double pips){ return pips*_pip(s); }

bool _ema(const string s, ENUM_TIMEFRAMES tf, int period, double &out){
  int h=iMA(s,tf,period,0,MODE_EMA,PRICE_CLOSE); if(h==INVALID_HANDLE) return false;
  double a[]; ArraySetAsSeries(a,true); if(CopyBuffer(h,0,0,1,a)<1) return false; out=a[0]; return true;
}
bool _atr(const string s, ENUM_TIMEFRAMES tf, int period, double &out){
  int h=iATR(s,tf,period); if(h==INVALID_HANDLE) return false;
  double a[]; ArraySetAsSeries(a,true); if(CopyBuffer(h,0,0,1,a)<1) return false; out=a[0]; return true;
}
double _slope_est(const double &arr[]){
  if(ArraySize(arr)<2) return 0.0; return (arr[0]-arr[1]); // простой градиент
}
#endif // __TYP_CORE_MQH__



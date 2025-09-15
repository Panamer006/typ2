#pragma once
// Fibo Map (Block#1): уровни от «мастера диапазона» за lookback дней
struct FiboMapCfg {
  int lookbackDays = 365;       // якоря Hi/Lo за период
  double levels[];              // сюда запишем уровни (23.6/38.2/50/61.8/78.6/100/127/161.8)
};

bool FiboMap_Calc(const string sym, ENUM_TIMEFRAMES tf, FiboMapCfg &cfg) {
  datetime to   = TimeCurrent();
  datetime from = to - 86400LL*cfg.lookbackDays;
  MqlRates rr[]; int n=CopyRates(sym,tf,from,to,rr);
  if(n<50) return false;
  double hi = rr[0].high, lo = rr[0].low;
  for(int i=0;i<n;i++){ if(rr[i].high>hi) hi=rr[i].high; if(rr[i].low<lo) lo=rr[i].low; }
  if(hi<=lo) return false;

  double range = hi - lo;
  ArrayResize(cfg.levels,0);
  double fibs[] = {0.0, 0.236, 0.382, 0.5, 0.618, 0.786, 1.0, 1.27, 1.618};
  for(int i=0;i<ArraySize(fibs);++i) {
    double lv = hi - range*fibs[i];  // сверху вниз (по тренду вниз инвертируем в будущем)
    int sz=ArraySize(cfg.levels); ArrayResize(cfg.levels,sz+1); cfg.levels[sz]=lv;
  }
  return true;
}

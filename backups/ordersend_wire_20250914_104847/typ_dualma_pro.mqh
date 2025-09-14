
#property strict
#ifndef __TYP_DUALMA_PRO_MQH__
#define __TYP_DUALMA_PRO_MQH__

/*
  DualMA Pro — "real" минимальная логика без внешних зависимостей.
  Возможности:
   - TrendStrict: fast EMA vs slow EMA + проверка угла (slope) обеих средних
   - AltFilters: ATR минимальный, макс. спред, запрет во флэте (ATR/Point)
   - Сигналы: Bounce / Break / Retest / Pinch (упрощённые, пригодны для Resolver)
*/

// ---- Inputs
input int  DMP_FastPeriod   = 21;
input int  DMP_SlowPeriod   = 55;
input ENUM_TIMEFRAMES DMP_TF = PERIOD_CURRENT;
input int  DMP_SlopeLookback = 5;           // глубина расчёта наклона
input double DMP_MinSlope    = 0.0;         // min обязательный угол EMA (0 — отключено)

// AltFilters
input int    DMP_ATR_Period    = 14;
input double DMP_ATR_MinATR    = 0.0;       // min ATR (в ценах); 0 — нет проверки
input double DMP_MaxSpreadPips = 2.0;       // 0 — нет проверки
input double DMP_Flat_K        = 0.0;       // 0 — нет проверки; если ATR < K * Point → flat

// ---- Helpers
static double _pip(const string s){
  double p=SymbolInfoDouble(s,SYMBOL_POINT);
  int d=(int)SymbolInfoInteger(s,SYMBOL_DIGITS);
  return (d==3 || d==5) ? p*10.0 : p;
}
static double _pips(const string s, double pips){ return pips*_pip(s); }

static bool _ema(const string s, ENUM_TIMEFRAMES tf, int period, int shift, double &val)
{
   int h = iMA(s, tf, period, 0, MODE_EMA, PRICE_CLOSE);
   if(h==INVALID_HANDLE) return false;
   double b[]; ArraySetAsSeries(b,true);
   if(CopyBuffer(h,0,shift,2,b)<2) return false;
   val=b[0]; return true;
}
static bool _atr(const string s, ENUM_TIMEFRAMES tf, int p, double &val)
{
   int h=iATR(s,tf,p); if(h==INVALID_HANDLE) return false;
   double v[]; ArraySetAsSeries(v,true);
   if(CopyBuffer(h,0,0,1,v)<1) return false;
   val=v[0]; return true;
}
static double _slope_est(const string s, ENUM_TIMEFRAMES tf, int period, int look)
{
   // простая оценка наклона EMA за look баров
   int h=iMA(s,tf,period,0,MODE_EMA,PRICE_CLOSE);
   if(h==INVALID_HANDLE) return 0.0;
   double v[]; ArraySetAsSeries(v,true);
   if(CopyBuffer(h,0,0,look+1,v)<(look+1)) return 0.0;
   return (v[0]-v[look])/look;
}

// ---- AltFilters gate
static bool DMP_AltFiltersGate(const string s, ENUM_TIMEFRAMES tf)
{
   // spread
   if(DMP_MaxSpreadPips>0.0){
      double spread = SymbolInfoDouble(s,SYMBOL_SPREAD)*_pip(s)/_pip(s); // приводим к пипсам
      double maxsp  = DMP_MaxSpreadPips;
      if(spread>maxsp) { PrintFormat("[DMP][ALT] spread=%.1f>%.1f -> BLOCK",spread,maxsp); return false; }
   }
   // ATR
   if(DMP_ATR_MinATR>0.0){
      double atr; if(!_atr(s,tf,DMP_ATR_Period,atr)) return true;
      if(atr<DMP_ATR_MinATR){ PrintFormat("[DMP][ALT] atr=%.5f<%.5f -> BLOCK",atr,DMP_ATR_MinATR); return false; }
   }
   // flat
   if(DMP_Flat_K>0.0){
      double atr; if(!_atr(s,tf,DMP_ATR_Period,atr)) return true;
      double pt = SymbolInfoDouble(s,SYMBOL_POINT);
      if(atr < DMP_Flat_K*pt){ PrintFormat("[DMP][ALT] flat atr=%.5f<th=%.5f -> BLOCK",atr,DMP_Flat_K*pt); return false; }
   }
   return true;
}

// ---- TrendStrict
static bool DMP_TrendStrict(const string s, ENUM_TIMEFRAMES tf, int &dir)
{
   dir=0;
   double f,s; if(!_ema(s,tf,DMP_FastPeriod,0,f)) return false;
   if(!_ema(s,tf,DMP_SlowPeriod,0,s)) return false;

   double sf = _slope_est(s,tf,DMP_FastPeriod,DMP_SlopeLookback);
   double ss = _slope_est(s,tf,DMP_SlowPeriod,DMP_SlopeLookback);

   if(DMP_MinSlope>0.0){
     if(MathAbs(sf)<DMP_MinSlope || MathAbs(ss)<DMP_MinSlope) return false;
   }

   if(f>s){ dir=+1; return true; }
   if(f<s){ dir=-1; return true; }
   return false;
}

// ---- Signals (минимальные правила на базе EMA)
static bool DMP_Signal_Bounce(const string s, ENUM_TIMEFRAMES tf, int &dir)
{
   // bounce: fast EMA отталкивается от slow EMA (меняет наклон в сторону пересечения, но без факта пересечения)
   dir=0;
   double f0,f1,s0,s1;
   if(!_ema(s,tf,DMP_FastPeriod,0,f0) || !_ema(s,tf,DMP_FastPeriod,1,f1)) return false;
   if(!_ema(s,tf,DMP_SlowPeriod,0,s0) || !_ema(s,tf,DMP_SlowPeriod,1,s1)) return false;

   // если были сходящимися и теперь расходятся
   double d0 = f0-s0, d1 = f1-s1;
   if(MathAbs(d1) < MathAbs(d0) && MathAbs(d0) < MathAbs(d0 + (d0-d1))) return false; // защита от шума

   if(d1<0 && d0>0) { dir=+1; return true; }   // отскок вверх
   if(d1>0 && d0<0) { dir=-1; return true; }   // отскок вниз
   return false;
}

static bool DMP_Signal_Break(const string s, ENUM_TIMEFRAMES tf, int &dir)
{
   // break: цена пересекает slow EMA в сторону fast EMA
   dir=0;
   double s0; if(!_ema(s,tf,DMP_SlowPeriod,0,s0)) return false;
   double c0 = iClose(s,tf,0);
   double c1 = iClose(s,tf,1);
   if(c1<s0 && c0>s0) { dir=+1; return true; }
   if(c1>s0 && c0<s0) { dir=-1; return true; }
   return false;
}

static bool DMP_Signal_Retest(const string s, ENUM_TIMEFRAMES tf, int &dir)
{
   // retest: после пересечения fast/slow цена возвращается к slow EMA и отскакивает
   dir=0;
   double f0,s0; if(!_ema(s,tf,DMP_FastPeriod,0,f0) || !_ema(s,tf,DMP_SlowPeriod,0,s0)) return false;
   double c1 = iClose(s,tf,1);
   double s1; if(!_ema(s,tf,DMP_SlowPeriod,1,s1)) return false;
   // тренд должен быть определён
   if(f0>s0 && c1<=s1 && iClose(s,tf,0)>s0){ dir=+1; return true; }
   if(f0<s0 && c1>=s1 && iClose(s,tf,0)<s0){ dir=-1; return true; }
   return false;
}

static bool DMP_Signal_Pinch(const string s, ENUM_TIMEFRAMES tf, int &dir)
{
   // pinch: fast и slow сильно сблизились (возможен импульс)
   dir=0;
   double f0,s0; if(!_ema(s,tf,DMP_FastPeriod,0,f0) || !_ema(s,tf,DMP_SlowPeriod,0,s0)) return false;
   double gap = MathAbs(f0-s0);
   double atr; if(!_atr(s,tf,DMP_ATR_Period,atr)) atr=0;
   // если gap < X% от ATR, считаем "pinch"
   double th = (atr>0 ? 0.15*atr : 3*_pip(s)); // эвристика
   if(gap<th){
      // направление по положению цены относительно slow
      double c0=iClose(s,tf,0);
      if(c0>s0){ dir=+1; return true; }
      if(c0<s0){ dir=-1; return true; }
   }
   return false;
}

#endif // __TYP_DUALMA_PRO_MQH__

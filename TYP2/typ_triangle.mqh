#property strict
#ifndef __TYP_TRIANGLE_MQH__
#define __TYP_TRIANGLE_MQH__

/*
  Triangle.HYBRID  минимальная реал-логика:
   - детектор сжатия/схождения экстремумов (n-бара),
   - режимы: EDGE_FADE, BREAKOUT, TREND_ACCUM,
   - без внешних зависимостей; безопасный include.
*/

// Inputs
input int    TRI_Lookback     = 60;     // глубина поиска экстремумов
input int    TRI_MinBars      = 12;     // минимальная длина треугольника
input int    TRI_CompressBars = 20;     // сколько последних баров анализируем на сжатие
input double TRI_MinSlopeAbs  = 0.0;    // минимум |наклона| для границ (0  отключено)
input double TRI_MinTightness = 0.30;   // насколько узким должен стать диапазон (доля от изначального)
input double TRI_BO_BufferATR = 0.20;   // буфер для breakout в ATR

// Helpers
static bool _atr(const string s, ENUM_TIMEFRAMES tf, int p, double &val)
{
   int h=iATR(s,tf,p); if(h==INVALID_HANDLE) return false;
   double v[]; ArraySetAsSeries(v,true);
   if(CopyBuffer(h,0,0,1,v)<1) return false;
   val=v[0]; return true;
}

struct TriDesc {
   bool found;
   int  start;
   int  end;
   double top0, top1;
   double bot0, bot1;
   double width0, width1;
};

// Линия через две точки (bar->price): price = a*bar + b
static void _line_from_points(int x1,double y1,int x2,double y2,double &a,double &b)
{
   if(x2==x1){ a=0; b=y2; return; }
   a = (y2-y1)/double(x2-x1);
   b = y1 - a*x1;
}

// Оценка треугольника: верхняя и нижняя границы сходятся, ширина уменьшается
static TriDesc TRI_Find(const string s, ENUM_TIMEFRAMES tf)
{
   TriDesc d; d.found=false; d.start=0; d.end=0; d.top0=d.top1=d.bot0=d.bot1=0; d.width0=d.width1=0;
   const int N = MathMax(TRI_Lookback, TRI_CompressBars+TRI_MinBars);
   MqlRates r[]; ArraySetAsSeries(r,true);
   int got=CopyRates(s,tf,0,N,r);
   if(got<TRI_CompressBars+TRI_MinBars) return d;

   // ранние экстремумы
   int i0 = TRI_CompressBars+TRI_MinBars;
   double hi0 = r[i0].High, lo0 = r[i0].Low;
   int hi0i=i0, lo0i=i0;
   for(int i=i0+1;i<got;i++){
      if(r[i].High>hi0){ hi0=r[i].High; hi0i=i; }
      if(r[i].Low <lo0){ lo0=r[i].Low;  lo0i=i; }
   }

   // последние экстремумы в зоне сжатия
   int j0 = TRI_CompressBars;
   double hi1=r[j0].High, lo1=r[j0].Low;
   int hi1i=j0, lo1i=j0;
   for(int j=1;j<=TRI_CompressBars;j++){
      if(r[j].High>hi1){ hi1=r[j].High; hi1i=j; }
      if(r[j].Low <lo1){ lo1=r[j].Low;  lo1i=j; }
   }

   // границы
   double at,bt, ab,bb;
   _line_from_points(hi0i,hi0,hi1i,hi1,at,bt);   // top
   _line_from_points(lo0i,lo0,lo1i,lo1,ab,bb);   // bottom

   // проверим схождение: ширина стала меньше TRI_MinTightness * исходной
   double w0 = hi0 - lo0;
   double w1 = hi1 - lo1;
   if(w0<=0) return d;
   const bool tight  = (w1 <= w0*TRI_MinTightness);
   const bool slopes = (MathAbs(at)>=TRI_MinSlopeAbs || MathAbs(ab)>=TRI_MinSlopeAbs);
   if(!(tight && slopes)) return d;

   d.found=true; d.start=i0; d.end=0;
   d.top0=hi0; d.top1=hi1; d.bot0=lo0; d.bot1=lo1;
   d.width0=w0; d.width1=w1;
   return d;
}

enum TriMode { TRI_EDGE_FADE=0, TRI_BREAKOUT=1, TRI_TREND_ACCUM=2 };

// EDGE_FADE: торгуем от границы внутрь
static bool TRI_EdgeFade(const string s, ENUM_TIMEFRAMES tf, const TriDesc &d, int &dir)
{
   dir=0; if(!d.found) return false;
   double c = iClose(s,tf,0);
   double distTop = MathAbs(c - d.top1);
   double distBot = MathAbs(c - d.bot1);
   if(distTop < distBot){ dir=-1; return true; }
   if(distBot < distTop){ dir=+1; return true; }
   return false;
}

// BREAKOUT: выход за границы (с ATR-буфером)
static bool TRI_Breakout(const string s, ENUM_TIMEFRAMES tf, const TriDesc &d, int &dir)
{
   dir=0; if(!d.found) return false;
   double c = iClose(s,tf,0);
   double atr; if(!_atr(s,tf,14,atr)) atr=0;
   double buf = atr*TRI_BO_BufferATR;
   if(c > d.top1 + buf){ dir=+1; return true; }
   if(c < d.bot1 - buf){ dir=-1; return true; }
   return false;
}

// TREND_ACCUM: на сужении по EMA(21/55) тренду
static bool TRI_TrendAccum(const string s, ENUM_TIMEFRAMES tf, const TriDesc &d, int &dir)
{
   dir=0; if(!d.found) return false;
   int h1=iMA(s,tf,21,0,MODE_EMA,PRICE_CLOSE);
   int h2=iMA(s,tf,55,0,MODE_EMA,PRICE_CLOSE);
   if(h1==INVALID_HANDLE||h2==INVALID_HANDLE) return false;
   double a[]; ArraySetAsSeries(a,true);
   if(CopyBuffer(h1,0,0,1,a)<1) return false; double f=a[0];
   if(CopyBuffer(h2,0,0,1,a)<1) return false; double g=a[0];
   if(f>g){ dir=+1; return true; }
   if(f<g){ dir=-1; return true; }
   return false;
}

#endif // __TYP_TRIANGLE_MQH__

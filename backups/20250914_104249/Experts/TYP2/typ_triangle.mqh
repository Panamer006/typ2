#property strict
#ifndef __TYP_TRIANGLE_MQH__
#define __TYP_TRIANGLE_MQH__

input int    TRI_Lookback     = 60;
input int    TRI_MinBars      = 12;
input int    TRI_CompressBars = 20;
input double TRI_MinSlopeAbs  = 0.0;
input double TRI_MinTightness = 0.30;
input double TRI_BO_BufferATR = 0.20;

static bool _atr(const string s, ENUM_TIMEFRAMES tf, int p, double &val){
   int h=iATR(s,tf,p); if(h==INVALID_HANDLE) return false;
   double v[]; ArraySetAsSeries(v,true);
   if(CopyBuffer(h,0,0,1,v)<1) return false; val=v[0]; return true; }

struct TriDesc { bool found; int start; int end; double top0,top1,bot0,bot1,width0,width1; };

static void _line_from_points(int x1,double y1,int x2,double y2,double &a,double &b){
   if(x2==x1){ a=0; b=y2; return; } a=(y2-y1)/double(x2-x1); b=y1-a*x1; }

static TriDesc TRI_Find(const string s, ENUM_TIMEFRAMES tf){
   TriDesc d; d.found=false; const int N=MathMax(TRI_Lookback,TRI_CompressBars+TRI_MinBars);
   MqlRates r[]; ArraySetAsSeries(r,true); int got=CopyRates(s,tf,0,N,r);
   if(got<TRI_CompressBars+TRI_MinBars) return d;

   int i0=TRI_CompressBars+TRI_MinBars; double hi0=r[i0].High, lo0=r[i0].Low; int hi0i=i0, lo0i=i0;
   for(int i=i0+1;i<got;i++){ if(r[i].High>hi0){hi0=r[i].High;hi0i=i;} if(r[i].Low<lo0){lo0=r[i].Low;lo0i=i;} }

   int j0=TRI_CompressBars; double hi1=r[j0].High, lo1=r[j0].Low; int hi1i=j0, lo1i=j0;
   for(int j=1;j<=TRI_CompressBars;j++){ if(r[j].High>hi1){hi1=r[j].High;hi1i=j;} if(r[j].Low<lo1){lo1=r[j].Low;lo1i=j;} }

   double at,bt,ab,bb; _line_from_points(hi0i,hi0,hi1i,hi1,at,bt); _line_from_points(lo0i,lo0,lo1i,lo1,ab,bb);

   double w0=hi0-lo0, w1=hi1-lo1; if(w0<=0) return d;
   bool tight=(w1<=w0*TRI_MinTightness);
   bool slopes=(MathAbs(at)>=TRI_MinSlopeAbs || MathAbs(ab)>=TRI_MinSlopeAbs);
   if(!(tight&&slopes)) return d;

   d.found=true; d.start=i0; d.end=0; d.top0=hi0; d.top1=hi1; d.bot0=lo0; d.bot1=lo1; d.width0=w0; d.width1=w1;
   return d;
}

enum TriMode { TRI_EDGE_FADE=0, TRI_BREAKOUT=1, TRI_TREND_ACCUM=2 };

static bool TRI_EdgeFade(const string s, ENUM_TIMEFRAMES tf, const TriDesc &d, int &dir){
   dir=0; if(!d.found) return false; double c=iClose(s,tf,0);
   double dt=MathAbs(c-d.top1), db=MathAbs(c-d.bot1);
   if(dt<db){dir=-1;return true;} if(db<dt){dir=+1;return true;} return false; }

static bool TRI_Breakout(const string s, ENUM_TIMEFRAMES tf, const TriDesc &d, int &dir){
   dir=0; if(!d.found) return false; double c=iClose(s,tf,0); double atr; if(!_atr(s,tf,14,atr)) atr=0;
   double buf=atr*TRI_BO_BufferATR; if(c>d.top1+buf){dir=+1;return true;} if(c<d.bot1-buf){dir=-1;return true;} return false; }

static bool TRI_TrendAccum(const string s, ENUM_TIMEFRAMES tf, const TriDesc &d, int &dir){
   dir=0; if(!d.found) return false; int h1=iMA(s,tf,21,0,MODE_EMA,PRICE_CLOSE), h2=iMA(s,tf,55,0,MODE_EMA,PRICE_CLOSE);
   if(h1==INVALID_HANDLE||h2==INVALID_HANDLE) return false; double a[]; ArraySetAsSeries(a,true);
   if(CopyBuffer(h1,0,0,1,a)<1) return false; double f=a[0]; if(CopyBuffer(h2,0,0,1,a)<1) return false; double g=a[0];
   if(f>g){dir=+1;return true;} if(f<g){dir=-1;return true;} return false; }

#endif // __TYP_TRIANGLE_MQH__

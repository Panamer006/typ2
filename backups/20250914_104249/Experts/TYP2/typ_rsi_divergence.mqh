#property strict
#ifndef __TYP_RSI_DIV_MQH__
#define __TYP_RSI_DIV_MQH__

/*
  RSI Divergence (base):
   - RSI(Period) на PRICE_CLOSE
   - Бычья дивергенция: цена делает ниже Low, RSI делает выше Low
   - Медвежья: цена выше High, RSI ниже High
   - Простая проверка по двум последним свинг-экстремумам цены и RSI
*/

input int  RSID_Period      = 14;
input int  RSID_PivotLeft   = 3;
input int  RSID_PivotRight  = 3;
input int  RSID_Lookback    = 300;

struct RSID_Swing { int idx; double price; double rsi; bool isHigh; };

static bool _isHigh(double a[], int i, int L, int R){
  double v=a[i]; for(int j=1;j<=L;j++) if(a[i+j] >= v) return false;
                 for(int j=1;j<=R;j++) if(a[i-j] >  v) return false; return true; }
static bool _isLow (double a[], int i, int L, int R){
  double v=a[i]; for(int j=1;j<=L;j++) if(a[i+j] <= v) return false;
                 for(int j=1;j<=R;j++) if(a[i-j] <  v) return false; return true; }

static int RSID_Collect(const string s, ENUM_TIMEFRAMES tf, RSID_Swing &sw[])
{
  MqlRates r[]; ArraySetAsSeries(r,true);
  int got=CopyRates(s,tf,0,RSID_Lookback,r);
  if(got<RSID_PivotLeft+RSID_PivotRight+20) return 0;

  int h = iRSI(s,tf,RSID_Period,PRICE_CLOSE);
  if(h==INVALID_HANDLE) return 0;
  double rv[]; ArraySetAsSeries(rv,true);
  if(CopyBuffer(h,0,0,got,rv)<got) return 0;

  RSID_Swing tmp[]; ArrayResize(tmp,0);
  for(int i=RSID_PivotRight; i<got-RSID_PivotLeft; i++){
    if(_isHigh(rv,i,RSID_PivotLeft,RSID_PivotRight)){
      RSID_Swing s1; s1.idx=i; s1.price=r[i].High; s1.rsi=rv[i]; s1.isHigh=true;
      int n=ArraySize(tmp); ArrayResize(tmp,n+1); tmp[n]=s1;
    }
    if(_isLow(rv,i,RSID_PivotLeft,RSID_PivotRight)){
      RSID_Swing s2; s2.idx=i; s2.price=r[i].Low; s2.rsi=rv[i]; s2.isHigh=false;
      int n=ArraySize(tmp); ArrayResize(tmp,n+1); tmp[n]=s2;
    }
  }
  ArraySort(tmp,WHOLE_ARRAY,0,MODE_DESCEND); // по idx убыв.
  int keep=MathMin(20,ArraySize(tmp));
  ArrayResize(sw,keep); for(int k=0;k<keep;k++) sw[k]=tmp[k];
  return keep;
}

// Возвращает +1 (bull), -1 (bear) или 0 (нет)
static int RSID_CheckDivergence(const string s, ENUM_TIMEFRAMES tf)
{
  RSID_Swing sw[]; int n=RSID_Collect(s,tf,sw);
  if(n<2) return 0;
  RSID_Swing a=sw[1], b=sw[0];

  if(!a.isHigh && !b.isHigh){
    // бычья: цена ниже Low, RSI выше Low
    if(b.price < a.price && b.rsi > a.rsi) return +1;
  }
  if(a.isHigh && b.isHigh){
    // медвежья: цена выше High, RSI ниже High
    if(b.price > a.price && b.rsi < a.rsi) return -1;
  }
  return 0;
}
#endif // __TYP_RSI_DIV_MQH__

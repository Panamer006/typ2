#property strict
#ifndef __TYP_FIBO_EXT_MQH__
#define __TYP_FIBO_EXT_MQH__

/*
  Fibo Extended (real, safe):
    - Пивоты (anchors) по свингам: простая детекция high/low (left/right).
    - Кластеры уровней: ищем совпадение retrace/extension двух последних AB-сегментов.
    - AB=CD: базовый детектор завершения, сигнал на реверс.
*/

input int    FE_LookbackBars     = 300;
input int    FE_PivotLeft        = 3;
input int    FE_PivotRight       = 3;
input double FE_ClusterTolPips   = 5.0;     // допустимое расхождение уровней в пипсах
input bool   FE_UseCluster       = true;
input bool   FE_Use_ABCD         = true;

static double _pip(const string s){
  const int d = (int)SymbolInfoInteger(s,SYMBOL_DIGITS);
  const double p = SymbolInfoDouble(s,SYMBOL_POINT);
  return (d==3||d==5) ? p*10.0 : p;
}
static double _pips2price(const string s, double pips){ return pips * _pip(s); }
static bool _copy_rates(const string sym, ENUM_TIMEFRAMES tf, int count, MqlRates &r[], int &got){
  ArrayFree(r); ArraySetAsSeries(r,true);
  got = CopyRates(sym, tf, 0, count, r);
  return (got>0);
}

static bool _isPivotHigh(const MqlRates &r[], int i, int L, int R){
  double v = r[i].High;
  for(int j=1;j<=L;j++)   if(r[i+j].High >= v) return false;
  for(int j=1;j<=R;j++)   if(r[i-j].High >  v) return false;
  return true;
}
static bool _isPivotLow(const MqlRates &r[], int i, int L, int R){
  double v = r[i].Low;
  for(int j=1;j<=L;j++)   if(r[i+j].Low <= v)  return false;
  for(int j=1;j<=R;j++)   if(r[i-j].Low <  v)  return false;
  return true;
}

struct FE_Swing { int idx; double price; bool isHigh; };

static int FE_CollectSwings(const string sym, ENUM_TIMEFRAMES tf, FE_Swing &sw[], const int L, const int R, const int Nbars)
{
  MqlRates rr[]; int got=0;
  if(!_copy_rates(sym,tf,MathMax(Nbars, L+R+50), rr, got)) return 0;
  // поисковый диапазон: сдвигаемся от R до got-L-1
  FE_Swing tmp[]; ArrayResize(tmp,0);
  for(int i=R; i<got-L; i++){
    if(_isPivotHigh(rr,i,L,R)){ FE_Swing s; s.idx=i; s.price=rr[i].High; s.isHigh=true;  int n=ArraySize(tmp);  ArrayResize(tmp,n+1); tmp[n]=s; }
    if(_isPivotLow (rr,i,L,R)){ FE_Swing s; s.idx=i; s.price=rr[i].Low;  s.isHigh=false; int n=ArraySize(tmp);  ArrayResize(tmp,n+1); tmp[n]=s; }
  }
  // Оставим последние 20 свингов, переупорядочим по индексу (свежие ближе к 0)
  ArraySort(tmp, WHOLE_ARRAY, 0, MODE_DESCEND); // по idx убыв.
  int keep = MathMin(20, ArraySize(tmp));
  ArrayResize(sw, keep);
  for(int k=0;k<keep;k++) sw[k]=tmp[k];
  return keep;
}

// --- Построение retrace/extension уровней для AB (up=+1, down=-1)
static int FE_BuildLevels(const double A, const double B, const int dir, double &levels[])
{
  // retrace (A->B): 0.382, 0.5, 0.618; extension: 1.272, 1.618
  const double rts[] = {0.382, 0.500, 0.618};
  const double exs[] = {1.272, 1.618};

  double L[]; ArrayResize(L, 0);

  // retrace от B назад к A
  for(int i=0;i<ArraySize(rts);i++){
    double t = (dir>0) ? (B - (B-A)*rts[i]) : (B + (A-B)*rts[i]);
    int n=ArraySize(L); ArrayResize(L,n+1); L[n]=t;
  }
  // extension от B дальше по тренду
  for(int i=0;i<ArraySize(exs);i++){
    double t = (dir>0) ? (B + (B-A)*exs[i]) : (B - (A-B)*exs[i]);
    int n=ArraySize(L); ArrayResize(L,n+1); L[n]=t;
  }

  ArrayResize(levels, ArraySize(L));
  for(int i=0;i<ArraySize(L);i++) levels[i]=L[i];
  return ArraySize(levels);
}

// --- Кластер: сравниваем уровни двух последних AB; если есть пара ближе tol -> вернём cluster
static bool FE_FindCluster(const string sym, const double L1[], const double L2[], const double tol_pips, double &cluster_price)
{
  const double tol = _pips2price(sym, tol_pips);
  for(int i=0;i<ArraySize(L1);i++)
    for(int j=0;j<ArraySize(L2);j++)
      if(MathAbs(L1[i]-L2[j]) <= tol){ cluster_price = 0.5*(L1[i]+L2[j]); return true; }
  return false;
}

// --- AB=CD: A,B,C  последние чередующиеся свинги; ищем достижение D=C|B-A| (торгуем реверс)
static bool FE_Signal_ABCD(const string sym, ENUM_TIMEFRAMES tf, const FE_Swing &A, const FE_Swing &B, const FE_Swing &C, int &dir, double &Dtarget)
{
  dir=0; Dtarget=0.0;
  const double ab = (B.price - A.price);
  const int cdSign = (ab>0 ? +1 : -1);  // направление CD как AB
  Dtarget = C.price + cdSign * MathAbs(ab);
  const double c0 = iClose(sym,tf,0);
  const double tol = _pips2price(sym, FE_ClusterTolPips);
  if(MathAbs(c0 - Dtarget) <= tol){
    // реверс против CD
    dir = -cdSign;
    return true;
  }
  return false;
}

// --- Вспомогательная: получить два последних AB (для кластеров) и A,B,C для AB=CD
static bool FE_LastSegments(const string sym, ENUM_TIMEFRAMES tf, FE_Swing &A, FE_Swing &B, FE_Swing &C, FE_Swing &A2, FE_Swing &B2)
{
  FE_Swing sw[]; int n=FE_CollectSwings(sym,tf,sw, FE_PivotLeft, FE_PivotRight, FE_LookbackBars);
  if(n<4) return false;
  // Требуются чередующиеся: ... A2 B2 A B C (индексы по убыванию  ближе к 0 свежее)
  // Возьмём первые пять свингов и построим из них
  // (с учётом возможной последовательности high/low)
  FE_Swing s0=sw[0], s1=sw[1], s2=sw[2], s3=sw[3], s4=sw[4];
  // A,B,C  три последних чередующихся
  A=s2; B=s1; C=s0;
  A2=s4; B2=s3;
  return true;
}

#endif // __TYP_FIBO_EXT_MQH__

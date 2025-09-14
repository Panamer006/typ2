
#property strict
#ifndef __TYP_EXECFILTERS_MQH__
#define __TYP_EXECFILTERS_MQH__

// ===== Inputs
enum NoChaseMode { NC_ATR=0, NC_PIPS=1 };
input bool        Exec_UseMinSpace          = true;
input int         Exec_MinSpace_Lookback    = 80;     // глубина поиска свингов
input double      Exec_MinSpace_ATR         = 0.80;   // min зазор до барьера в ATR
input bool        Exec_UseTimeStop          = true;
input int         Exec_TimeStop_Bars        = 8;      // закрыть/отменить, если N баров без прогресса
input bool        Exec_UseNoChase           = true;
input NoChaseMode Exec_NoChase_Mode         = NC_ATR; // ATR или pips
input double      Exec_NoChase_MaxSlipATR   = 0.20;   // макс. догон в ATR
input double      Exec_NoChase_MaxSlipPips  = 5.0;    // макс. догон в пипсах
input double      Exec_Round_StepPips       = 25.0;   // шаг «круглых» уровней
input double      Exec_Round_TolerancePips  = 5.0;    // толеранс к «круглому» уровню

// ===== Helpers
static double _atr(const string s, ENUM_TIMEFRAMES tf, int p=14)
{
   int h=iATR(s,tf,p); if(h==INVALID_HANDLE) return 0.0;
   double v[]; ArraySetAsSeries(v,true);
   if(CopyBuffer(h,0,0,1,v)<1) return 0.0;
   return v[0];
}
static double _pip(const string s){
   double p=SymbolInfoDouble(s,SYMBOL_POINT);
   int d=(int)SymbolInfoInteger(s,SYMBOL_DIGITS);
   return (d==3 || d==5) ? p*10.0 : p;
}
static double _pips2price(const string s,double pips){ return pips*_pip(s); }
static double _dist_pips(const string s,double a,double b){ return MathAbs(a-b)/_pip(s); }

static double _nearest_round(const string s,double price,double step_pips){
   const double step = _pips2price(s,step_pips);
   const double k    = MathRound(price/step);
   return k*step;
}

// ===== No-Chase
bool ExecCheck_NoChase(const string s, ENUM_TIMEFRAMES tf, const double signal_price, const double market_price)
{
   if(!Exec_UseNoChase) return true;
   if(Exec_NoChase_Mode==NC_ATR){
      double atr=_atr(s,tf); if(atr<=0) return true;
      const double dist=MathAbs(market_price-signal_price);
      const bool ok=(dist<=atr*Exec_NoChase_MaxSlipATR);
      if(!ok) PrintFormat("[EXEC][NO-CHASE/ATR] dist=%.5f atr=%.5f max=%.5f -> BLOCK",
                          dist,atr,atr*Exec_NoChase_MaxSlipATR);
      return ok;
   }else{
      const double dist=_dist_pips(s,market_price,signal_price);
      const bool ok=(dist<=Exec_NoChase_MaxSlipPips);
      if(!ok) PrintFormat("[EXEC][NO-CHASE/PIPS] dist=%.1f pips max=%.1f -> BLOCK",
                          dist,Exec_NoChase_MaxSlipPips);
      return ok;
   }
}

// ===== MinSpace (свинг + «круглый» уровень), dir: +1 long / -1 short
bool ExecCheck_MinSpace(const string s, ENUM_TIMEFRAMES tf, const int dir, const double entry_price)
{
   if(!Exec_UseMinSpace) return true;

   MqlRates r[]; ArraySetAsSeries(r,true);
   int got=CopyRates(s,tf,0,Exec_MinSpace_Lookback,r);
   if(got<10) return true;

   // Свинговый барьер
   double swing_barrier = entry_price;
   if(dir>0){ // long — берём ближайший high выше entry
      double best = DBL_MAX;
      for(int i=1;i<got;i++) if(r[i].High>entry_price) best = MathMin(best, r[i].High);
      if(best<DBL_MAX) swing_barrier=best;
   }else{     // short — ближайший low ниже entry
      double best = -DBL_MAX;
      for(int i=1;i<got;i++) if(r[i].Low<entry_price)  best = MathMax(best, r[i].Low);
      if(best>-DBL_MAX) swing_barrier=best;
   }

   // «Круглый» уровень
   const double round    = _nearest_round(s, entry_price, Exec_Round_StepPips);
   const double tol_price= _pips2price(s, Exec_Round_TolerancePips);
   const bool   round_ahead = (dir>0 ? round>=entry_price : round<=entry_price);
   const double round_dist  = (round_ahead ? MathAbs(round-entry_price) : DBL_MAX);

   // Фактический ближний барьер
   double barrier = swing_barrier;
   if(round_ahead) barrier = (dir>0 ? MathMin(barrier, entry_price+round_dist) : MathMax(barrier, entry_price-round_dist));

   double atr=_atr(s,tf); if(atr<=0) return true;
   const double space = (dir>0 ? (barrier-entry_price) : (entry_price-barrier));
   const bool   ok    = (space >= atr*Exec_MinSpace_ATR) && ( (round_dist==DBL_MAX) || (round_dist>tol_price) );

   if(!ok){
      PrintFormat("[EXEC][MINSPACE] space=%.5f atr=%.5f need>=%.5f roundDist=%.5f tol=%.5f -> BLOCK",
                  space,atr,atr*Exec_MinSpace_ATR, (round_dist==DBL_MAX? -1.0 : round_dist), tol_price);
   }
   return ok;
}

// ===== Time-Stop: сколько баров прошло с момента входа
int ExecTimeStop_BarsElapsed(const string s, ENUM_TIMEFRAMES tf, const datetime open_time)
{
   return Bars(s, tf, open_time, TimeCurrent());
}

bool ExecTimeStop_Exceeded(const string s, ENUM_TIMEFRAMES tf, const datetime open_time)
{
   if(!Exec_UseTimeStop) return false;
   int b = ExecTimeStop_BarsElapsed(s, tf, open_time);
   return (b >= Exec_TimeStop_Bars);
}

// ===== Pre-order gate: одно место для всех проверок
bool ExecGate_PreOrder(const string s, ENUM_TIMEFRAMES tf, const int dir, const double signal_price, const double market_price)
{
   if(!ExecCheck_NoChase(s,tf,signal_price,market_price)) return false;
   if(!ExecCheck_MinSpace(s,tf,dir,signal_price))         return false;
   return true;
}

#endif // __TYP_EXECFILTERS_MQH__

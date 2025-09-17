#pragma once
//+------------------------------------------------------------------+
//| TYP2 - Execution Filters Module (T2-005) v1.1                    |
//| Включает: NoChase, MinSpace, TimeStop, PreOrder Gate            |
//+------------------------------------------------------------------+
#property copyright "TYP2"
#property version   "2.1.0"

// --- Inputs для ExecGate ---
input group "Execution Filters"
enum NoChaseMode { NC_ATR=0, NC_PIPS=1 };
input bool        Exec_UseMinSpace          = true;
input int         Exec_MinSpace_Lookback    = 80;     // Глубина поиска свингов
input double      Exec_MinSpace_ATR         = 0.80;   // Мин. зазор до барьера в ATR
input bool        Exec_UseTimeStop          = true;
input int         Exec_TimeStop_Bars        = 8;      // Закрыть/отменить, если N баров без прогресса
input bool        Exec_UseNoChase           = true;
input NoChaseMode Exec_NoChase_Mode         = NC_ATR; // ATR или pips
input double      Exec_NoChase_MaxSlipATR   = 0.20;   // Макс. догон в ATR
input double      Exec_NoChase_MaxSlipPips  = 5.0;    // Макс. догон в пипсах
input double      Exec_Round_StepPips       = 50.0;   // Шаг "круглых" уровней
input double      Exec_Round_TolerancePips  = 5.0;    // Толеранс к "круглому" уровню

// --- Helpers (утилиты) ---
namespace ExecUtils
{
  static double _atr(const string s, ENUM_TIMEFRAMES tf, int p=14) {
     int h=iATR(s,tf,p); if(h==INVALID_HANDLE) return 0.0;
     double v[]; ArraySetAsSeries(v,true); if(CopyBuffer(h,0,0,1,v)<1) return 0.0; return v[0];
  }
  static double _pip(const string s) {
     double p=SymbolInfoDouble(s,SYMBOL_POINT); int d=(int)SymbolInfoInteger(s,SYMBOL_DIGITS);
     return (d==3||d==5) ? p*10.0 : p;
  }
  static double _pips2price(const string s,double pips){ return pips*_pip(s); }
  static double _dist_pips(const string s,double a,double b){ return MathAbs(a-b)/_pip(s); }
  static double _nearest_round(const string s,double price,double step_pips){
     const double step = _pips2price(s,step_pips); return MathRound(price/step)*step;
  }
}

// --- Логика фильтров ---
bool ExecCheck_NoChase(const string s, ENUM_TIMEFRAMES tf, const double signal_price, const double market_price) {
   if(!Exec_UseNoChase) return true;
   if(Exec_NoChase_Mode==NC_ATR){
      double atr=ExecUtils::_atr(s,tf); if(atr<=0) return true;
      const double dist=MathAbs(market_price-signal_price); const bool ok=(dist<=atr*Exec_NoChase_MaxSlipATR);
      if(!ok) PrintFormat("[ExecGate] NoChase/ATR LOCK: dist %.5f > max %.5f", dist, atr*Exec_NoChase_MaxSlipATR);
      return ok;
   } else {
      const double dist=ExecUtils::_dist_pips(s,market_price,signal_price); const bool ok=(dist<=Exec_NoChase_MaxSlipPips);
      if(!ok) PrintFormat("[ExecGate] NoChase/Pips LOCK: dist %.1f > max %.1f", dist, Exec_NoChase_MaxSlipPips);
      return ok;
   }
}
bool ExecCheck_MinSpace(const string s, ENUM_TIMEFRAMES tf, const int dir, const double entry_price) {
   if(!Exec_UseMinSpace) return true;
   MqlRates r[]; ArraySetAsSeries(r,true); if(CopyRates(s,tf,0,Exec_MinSpace_Lookback,r)<10) return true;
   double swing_barrier = (dir>0) ? DBL_MAX : -DBL_MAX;
   for(int i=1;i<ArraySize(r);i++){
     if(dir>0 && r[i].High > entry_price) swing_barrier = MathMin(swing_barrier, r[i].High);
     if(dir<0 && r[i].Low < entry_price) swing_barrier = MathMax(swing_barrier, r[i].Low);
   }
   const double round = ExecUtils::_nearest_round(s, entry_price, Exec_Round_StepPips);
   const bool round_ahead = (dir>0 ? round>=entry_price : round<=entry_price);
   double barrier = swing_barrier;
   if(round_ahead) barrier = (dir>0 ? MathMin(barrier, round) : MathMax(barrier, round));
   double atr=ExecUtils::_atr(s,tf); if(atr<=0) return true;
   const double space = MathAbs(barrier-entry_price); const bool ok=(space >= atr*Exec_MinSpace_ATR);
   if(!ok) PrintFormat("[ExecGate] MinSpace LOCK: space %.5f < required %.5f", space, atr*Exec_MinSpace_ATR);
   return ok;
}
bool ExecTimeStop_Exceeded(const string s, ENUM_TIMEFRAMES tf, const datetime open_time) {
   if(!Exec_UseTimeStop) return false;
   return (Bars(s, tf, open_time, TimeCurrent()) >= Exec_TimeStop_Bars);
}

// --- Единый Гейт для проверок перед ордером ---
bool ExecGate_PreOrder(const string s, ENUM_TIMEFRAMES tf, const int dir, const double signal_price) {
   double market_price = (dir > 0) ? SymbolInfoDouble(s, SYMBOL_ASK) : SymbolInfoDouble(s, SYMBOL_BID);
   if(!ExecCheck_NoChase(s,tf,signal_price,market_price)) return false;
   if(!ExecCheck_MinSpace(s,tf,dir,signal_price)) return false;
   return true;
}

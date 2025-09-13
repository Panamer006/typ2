#property strict
#ifndef __TYP_EXECFILTERS_MQH__
#define __TYP_EXECFILTERS_MQH__

input bool   Exec_UseMinSpace        = true;
input double Exec_MinSpace_ATR       = 0.8;    // мин. зазор до барьера в ATR
input bool   Exec_UseTimeStop        = true;
input int    Exec_TimeStop_Bars      = 8;      // закрыть/отменить, если N баров без прогресса
input bool   Exec_UseNoChase         = true;
input double Exec_NoChase_MaxSlipATR = 0.20;   // максимум догонять сигнал (в ATR)

double _atr(const string sym, ENUM_TIMEFRAMES tf, int p=14)
{
   int h = iATR(sym, tf, p);
   if(h == INVALID_HANDLE) return 0.0;
   double v[]; ArraySetAsSeries(v,true);
   if(CopyBuffer(h,0,0,1,v) < 1) return 0.0;
   return v[0];
}

// Ограничить вход, если рынок убежал от цены сигнала
bool ExecCheck_NoChase(const string sym, ENUM_TIMEFRAMES tf, const double signal_price, const double market_price)
{
   if(!Exec_UseNoChase) return true;
   double atr = _atr(sym, tf);
   if(atr <= 0) return true;
   double dist = MathAbs(market_price - signal_price);
   bool ok = (dist <= atr * Exec_NoChase_MaxSlipATR);
   if(!ok) PrintFormat("[EXEC][NO-CHASE] dist=%.5f atr=%.5f max=%.5f -> BLOCK",
                       dist, atr, atr*Exec_NoChase_MaxSlipATR);
   return ok;
}

// Проверка есть ли место до ближайшего свинга по направлению сделки
// dir: +1 = long, -1 = short
bool ExecCheck_MinSpace(const string sym, ENUM_TIMEFRAMES tf, const int dir, const double entry_price, const int lookback=50)
{
   if(!Exec_UseMinSpace) return true;

   MqlRates r[]; ArraySetAsSeries(r,true);
   if(CopyRates(sym, tf, 0, lookback, r) < 2) return true;

   double nearest = 0.0;
   if(dir > 0) // long
   {
      nearest = r[1].High;
      for(int i=2; i<MathMin(lookback, ArraySize(r)); ++i)
         if(r[i].High > entry_price) nearest = MathMin(nearest, r[i].High);
   }
   else        // short
   {
      nearest = r[1].Low;
      for(int i=2; i<MathMin(lookback, ArraySize(r)); ++i)
         if(r[i].Low < entry_price) nearest = (nearest==0.0 ? r[i].Low : MathMax(nearest, r[i].Low));
   }

   double atr = _atr(sym, tf);
   if(atr <= 0) return true;

   double space = (dir > 0 ? (nearest - entry_price) : (entry_price - nearest));
   bool ok = (space >= atr * Exec_MinSpace_ATR);
   if(!ok)
      PrintFormat("[EXEC][MINSPACE] space=%.5f atr=%.5f need>=%.5f -> BLOCK",
                  space, atr, atr*Exec_MinSpace_ATR);
   return ok;
}

// Time-Stop: скелет (в PM/цикл позиций); сейчас всегда true (включим позже)
bool ExecApply_TimeStop(const string sym, ENUM_TIMEFRAMES tf, const ulong ticket, const datetime open_time)
{
   if(!Exec_UseTimeStop) return true;
   return true;
}

#endif // __TYP_EXECFILTERS_MQH__

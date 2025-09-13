#property strict
#ifndef __TYP_VWAP_MQH__
#define __TYP_VWAP_MQH__

// ===== Inputs (подключатся через главный .mq5)
input bool   VWAP_UseConfirm     = true;   // подтверждение направления: long выше VWAP, short ниже
input bool   VWAP_UseHeadwind    = true;   // встречный ветер: не входим в VWAP вплотную
input double VWAP_MinSpace_ATR   = 0.50;   // минимальный зазор до VWAP в ATR
enum VWAPAnchorMode { VWAP_DAILY=0, VWAP_WEEKLY=1, VWAP_BOTH=2 };
input VWAPAnchorMode VWAP_Mode   = VWAP_BOTH;

// ===== Helpers
static int _tf_minutes(ENUM_TIMEFRAMES tf){
   switch(tf){
      case PERIOD_M1: return 1; case PERIOD_M2: return 2; case PERIOD_M3: return 3; case PERIOD_M4: return 4;
      case PERIOD_M5: return 5; case PERIOD_M6: return 6; case PERIOD_M10: return 10; case PERIOD_M12: return 12;
      case PERIOD_M15: return 15; case PERIOD_M20: return 20; case PERIOD_M30: return 30;
      case PERIOD_H1: return 60; case PERIOD_H2: return 120; case PERIOD_H3: return 180; case PERIOD_H4: return 240;
      case PERIOD_H6: return 360; case PERIOD_H8: return 480; case PERIOD_H12: return 720;
      case PERIOD_D1: return 1440; case PERIOD_W1: return 10080; case PERIOD_MN1: return 43200;
      default: return 60;
   }
}

static datetime _truncate_day(datetime t){
   MqlDateTime dt; TimeToStruct(t, dt);
   dt.hour=0; dt.min=0; dt.sec=0; return StructToTime(dt);
}

static datetime _week_start_mon(datetime t){
   MqlDateTime dt; TimeToStruct(t, dt);
   datetime day0 = _truncate_day(t);
   // 0=Sunday  6=Saturday  смещение до понедельника
   int shift = (dt.day_of_week + 6) % 7;
   return (day0 - shift*24*60*60);
}

static double _atr(const string sym, ENUM_TIMEFRAMES tf, int p=14){
   int h = iATR(sym, tf, p);
   if(h==INVALID_HANDLE) return 0.0;
   double v[]; ArraySetAsSeries(v,true);
   if(CopyBuffer(h,0,0,1,v) < 1) return 0.0;
   return v[0];
}

// ===== VWAP расчёт от якоря (день/неделя) до текущего бара
static double _vwap_from_anchor(const string sym, ENUM_TIMEFRAMES tf, datetime anchor){
   // оцениваем количество баров, которого точно хватит от якоря
   int mins = _tf_minutes(tf); if(mins<=0) mins=60;
   int want = (int)MathCeil( ( (double)(TimeCurrent() - anchor) / 60.0 ) / mins ) + 5;
   want = MathMax(want, 10); want = MathMin(want, 5000);

   MqlRates r[]; ArraySetAsSeries(r,true);
   int n = CopyRates(sym, tf, 0, want, r);
   if(n<=0) return 0.0;

   double sum_pv=0.0, sum_v=0.0;
   for(int i=0; i<n; ++i){
      if(r[i].time < anchor) break; // дальше бары якоря не нужны (массив обратный)
      double typ = (r[i].High + r[i].Low + r[i].Close)/3.0;
      double vol = (double)r[i].tick_volume; // в форексе используем tick volume
      sum_pv += typ * vol;
      sum_v  += vol;
   }
   if(sum_v<=0.0) return (n>0 ? r[0].Close : 0.0);
   return sum_pv / sum_v;
}

double VWAP_Daily(const string sym, ENUM_TIMEFRAMES tf){
   return _vwap_from_anchor(sym, tf, _truncate_day(TimeCurrent()));
}

double VWAP_Weekly(const string sym, ENUM_TIMEFRAMES tf){
   return _vwap_from_anchor(sym, tf, _week_start_mon(TimeCurrent()));
}

// ===== Полезные проверки (пока не используем в ордерах  будут вызваны из Resolver/Core)
bool VWAP_CheckConfirm(const string sym, ENUM_TIMEFRAMES tf, const int dir, const double price){
   if(!VWAP_UseConfirm) return true;
   double v = (VWAP_Mode==VWAP_DAILY ? VWAP_Daily(sym,tf)
                : VWAP_Mode==VWAP_WEEKLY ? VWAP_Weekly(sym,tf)
                : (VWAP_Daily(sym,tf) + VWAP_Weekly(sym,tf))/2.0);
   if(v<=0) return true;
   bool ok = (dir>0 ? price >= v : price <= v);
   if(!ok) PrintFormat("[VWAP][CONFIRM] price=%.5f vwap=%.5f dir=%d -> BLOCK", price, v, dir);
   return ok;
}

bool VWAP_CheckHeadwind(const string sym, ENUM_TIMEFRAMES tf, const int dir, const double entry_price){
   if(!VWAP_UseHeadwind) return true;
   double v = (VWAP_Mode==VWAP_DAILY ? VWAP_Daily(sym,tf)
                : VWAP_Mode==VWAP_WEEKLY ? VWAP_Weekly(sym,tf)
                : (VWAP_Daily(sym,tf) + VWAP_Weekly(sym,tf))/2.0);
   if(v<=0) return true;
   double atr = _atr(sym, tf); if(atr<=0) return true;

   // headwind: если идём в VWAP, требуем минимум ATR-зазор
   double space = (dir>0 ? (entry_price - v) : (v - entry_price)); // положительно, если уже по нужную сторону
   bool to_vwap = (dir>0 ? entry_price < v : entry_price > v);     // вход в сторону VWAP
   if(to_vwap && space < atr * VWAP_MinSpace_ATR){
      PrintFormat("[VWAP][HEADWIND] space=%.5f atr=%.5f need>=%.5f -> BLOCK", space, atr, atr*VWAP_MinSpace_ATR);
      return false;
   }
   return true;
}

#endif // __TYP_VWAP_MQH__

#ifndef __TYP_RISK_MQH__
#define __TYP_RISK_MQH__

input bool   Risk_Enable                   = true;
input double Risk_DailyMaxLossMoney        = 0.0;   // 0 -> off
input double Risk_DailyMaxLossPercent      = 2.0;   // % of equity at day start, 0 -> off
input int    Risk_DailyMaxTrades           = 0;     // 0 -> off
input int    Risk_MaxConsecutiveLosses     = 3;     // 0 -> off
input int    Risk_CooldownMinutes          = 60;    // 0 -> off
input bool   Risk_CooldownAfterLossStreak  = true;
input double Risk_BigLossPctForCooldown    = 3.5;   // % of equity at day start, 0 -> off
input bool   Risk_AllowCloseOnly           = true;  // when locked: allow PM to close/modify, but block new entries
input bool   Risk_LogToCSV                 = true;
input string Risk_LogFilename              = "typ2_risk_log.csv";

datetime   __risk_last_refresh = 0;
datetime   __risk_lock_until   = 0;
long       __risk_day_id       = -1;
double     __risk_day_start_equity = 0.0;
int        __risk_trades_today = 0;
int        __risk_consec_losses= 0;
double     __risk_pl_today     = 0.0;
bool       __risk_locked       = false;

long __risk_make_day_id(datetime t){ MqlDateTime md; TimeToStruct(t, md); return (long)(md.year*10000 + md.mon*100 + md.day); }

void __risk_log(const string msg){
  if(!Risk_LogToCSV) return;
  int h=FileOpen(Risk_LogFilename, FILE_WRITE|FILE_READ|FILE_TXT|FILE_COMMON|FILE_ANSI);
  if(h==INVALID_HANDLE){ return; }
  FileSeek(h, 0, SEEK_END);
  string line=StringFormat("%s;%I64d;%G;%d;%d;%G;%s\n",
    TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS),
    (long)__risk_day_id, __risk_day_start_equity,
    __risk_trades_today, __risk_consec_losses, __risk_pl_today, msg);
  FileWriteString(h, line);
  FileClose(h);
}

void __risk_rebuild_from_history(){
  datetime now = TimeCurrent();
  long day_id = __risk_make_day_id(now);
  if(day_id != __risk_day_id){
    __risk_day_id = day_id;
    __risk_day_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
    __risk_trades_today = 0;
    __risk_consec_losses= 0;
    __risk_pl_today     = 0.0;
    __risk_lock_until   = 0;
    __risk_locked       = false;
    __risk_log("RESET_DAY");
  }
  datetime day_begin; MqlDateTime md; TimeToStruct(now, md); md.hour=0; md.min=0; md.sec=0; day_begin = StructToTime(md);

  if(__risk_last_refresh!=0 && (now-__risk_last_refresh)<60) return;
  __risk_last_refresh = now;

  HistorySelect(day_begin, now);
  int total=HistoryDealsTotal();
  double pl=0.0;
  int trades=0;

  for(int i=0;i<total;i++){
    ulong ticket=HistoryDealGetTicket(i);
    int entry=(int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
    if(entry==DEAL_ENTRY_OUT){
      trades++;
      pl += profit;
    }
  }
  int tmp_consec=0;
  for(int i=total-1;i>=0;i--){
    ulong ticket=HistoryDealGetTicket(i);
    int entry=(int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
    if(entry!=DEAL_ENTRY_OUT) continue;
    double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
    if(profit< -0.0000001){
      tmp_consec++;
    }else if(profit> 0.0000001){
      break;
    }else{
      tmp_consec++;
    }
  }

  __risk_trades_today = trades;
  __risk_pl_today     = pl;
  __risk_consec_losses= tmp_consec;
}

void Risk_OnTradeTransaction(const MqlTradeTransaction &trans){}

bool __risk_in_lock_window(){
  datetime now=TimeCurrent();
  if(__risk_lock_until>now) return true;
  return false;
}

void __risk_lock(const string reason){
  __risk_locked = true;
  if(Risk_CooldownMinutes>0){
    __risk_lock_until = TimeCurrent() + 60*Risk_CooldownMinutes;
  }else{
    __risk_lock_until = LONG_MAX;
  }
  __risk_log("LOCK:"+reason);
}

bool Risk_AllowNewTrade(){
  if(!Risk_Enable) return true;

  __risk_rebuild_from_history();

  if(__risk_in_lock_window()){
    return false;
  }

  if(Risk_DailyMaxLossMoney>0.0 && __risk_pl_today <= -MathAbs(Risk_DailyMaxLossMoney)){
    __risk_lock("DAILY_MONEY_LIMIT");
    return false;
  }
  if(Risk_DailyMaxLossPercent>0.0 && __risk_day_start_equity>0.0){
    double dd_pct = -100.0*__risk_pl_today/__risk_day_start_equity;
    if(dd_pct >= Risk_DailyMaxLossPercent){
      __risk_lock("DAILY_PCT_LIMIT");
      return false;
    }
  }
  if(Risk_DailyMaxTrades>0 && __risk_trades_today >= Risk_DailyMaxTrades){
    __risk_lock("DAILY_TRADES_LIMIT");
    return false;
  }
  if(Risk_MaxConsecutiveLosses>0 && __risk_consec_losses >= Risk_MaxConsecutiveLosses){
    if(Risk_CooldownAfterLossStreak){
      __risk_lock("LOSS_STREAK");
      return false;
    }else{
      return false;
    }
  }
  if(Risk_BigLossPctForCooldown>0.0 && __risk_day_start_equity>0.0){
    datetime now=TimeCurrent();
    MqlDateTime md; TimeToStruct(now, md); md.hour=0; md.min=0; md.sec=0; datetime day_begin=StructToTime(md);
    HistorySelect(day_begin, now);
    int total=HistoryDealsTotal();
    for(int i=total-1;i>=0;i--){
      ulong ticket=HistoryDealGetTicket(i);
      int entry=(int)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry!=DEAL_ENTRY_OUT) continue;
      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT) + HistoryDealGetDouble(ticket, DEAL_SWAP) + HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      if(profit < 0){
        double loss_pct = -100.0*profit/__risk_day_start_equity;
        if(loss_pct >= Risk_BigLossPctForCooldown){
          __risk_lock("BIG_LOSS");
          return false;
        }
      }
      break;
    }
  }

  return true;
}

double Risk_GetPL_Today(){ __risk_rebuild_from_history(); return __risk_pl_today; }
int    Risk_GetTrades_Today(){ __risk_rebuild_from_history(); return __risk_trades_today; }
int    Risk_GetConsecLosses(){ __risk_rebuild_from_history(); return __risk_consec_losses; }
bool   Risk_IsLocked(){ return __risk_locked || __risk_in_lock_window(); }
datetime Risk_LockUntil(){ return __risk_lock_until; }

#endif // __TYP_RISK_MQH__

#ifndef __TYP_CORE_MQH__
#define __TYP_CORE_MQH__
#include <Trade/Trade.mqh>

//=== Globals / enums ===
enum ENUM_DIR { DIR_NONE=0, DIR_LONG=1, DIR_SHORT=2 };

enum ENUM_EXIT_MODE
{
  EXIT_AUTO=0,
  EXIT_SINGLE_PARTIALS,
  EXIT_SINGLE_PARTIALS_SERVER_LIMITS,
  EXIT_MULTI_TPS
};

enum ENUM_STAGE_RISK_MODE { STAGE_DECLINING=0, STAGE_EQUAL=1, STAGE_PROMOTE_ON_BE=2 };

struct SignalCandidate
{
  bool   valid;
  string module;
  string reason;
  ENUM_DIR dir;
  double entry;
  double sl;
  double tp1;
  double tp2;
  double tp3;
  double score;
};

//=== Utils ===
namespace TYP_Utils
{
  double Pip(const string sym)
  {
    double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
    int    dg = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
    return (dg==3 || dg==5) ? pt*10.0 : pt;
  }

  double ATR(const string sym, ENUM_TIMEFRAMES tf, int period=14)
  {
    int h = iATR(sym, tf, period);
    if(h==INVALID_HANDLE) return 0.0;
    double buf[]; ArraySetAsSeries(buf,true);
    if(CopyBuffer(h,0,0,3,buf)<3) return 0.0;
    return buf[0];
  }

  bool IsHedging(){ long m; AccountInfoInteger(ACCOUNT_MARGIN_MODE); return (m==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING); }
}

//=== NewBar helper ===
class TYP_NewBar
{
  datetime m_last_bar_time;
public:
  bool Check(const string sym, ENUM_TIMEFRAMES tf)
  {
    datetime t = iTime(sym, tf, 0);
    if(t==0) return false;
    if(m_last_bar_time!=t){ m_last_bar_time=t; return true; }
    return false;
  }
};

//=== News guard (stub) ===
namespace TYP_NewsGuard
{
  void Refresh(){ /* TODO: hook MT5 calendar; block new entries in windows */ }
}

//=== Portfolio symbols ===
class TYP_Portfolio
{
  string m_syms[]; ENUM_TIMEFRAMES m_trade_tf, m_struct_tf;
public:
  void Init(string csv, ENUM_TIMEFRAMES trade_tf, ENUM_TIMEFRAMES struct_tf)
  {
    m_trade_tf=trade_tf; m_struct_tf=struct_tf;
    StringSplit(csv, ',', m_syms);
    for(int i=0;i<ArraySize(m_syms);++i) m_syms[i]=StringTrim(m_syms[i]);
  }
  bool SymbolAllowed(const string sym)
  {
    for(int i=0;i<ArraySize(m_syms);++i) if(m_syms[i]==sym) return true;
    return false;
  }
}

//=== Cross-currency bias (stub) ===
;


#endif // __TYP_CORE_MQH__


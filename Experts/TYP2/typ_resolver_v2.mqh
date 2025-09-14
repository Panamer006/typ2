#property strict
#ifndef __TYP_RESOLVER_V2_MQH__
#define __TYP_RESOLVER_V2_MQH__

// Centralized gating with JSON-like trace

input bool   R_Log_JSON          = true;
input bool   R_Use_ExecGate      = true;       // NoChase/MinSpace (typ_execfilters)
input bool   R_Use_VWAP_Confirm  = true;       // long above / short below VWAP
input bool   R_Use_VWAP_Headwind = true;       // min ATR distance to VWAP
input double R_W_VWAP_Confirm    = 1.0;
input double R_W_VWAP_Headwind   = 1.0;

string _json_escape(const string s){
  string r=s; StringReplace(r,"\\","\\\\"); StringReplace(r,"\"","\\\""); return r;
}
string _kv(const string k, const string v){ return "\"" + _json_escape(k) + "\":\"" + _json_escape(v) + "\""; }
string _kvn(const string k, const double n){ return "\"" + _json_escape(k) + "\":" + DoubleToString(n,6); }

#include "typ_execfilters.mqh"   // обязателен (есть в проекте)
// ВАЖНО: не включаем typ_vwap.mqh здесь.
// Если проект уже подключил его где-то  будет определён __TYP_VWAP_MQH__.

bool ResolverV2_AllowEntry(const int dir, const double entry_price, string &json_reason)
{
   const double mkt = (dir>0 ? SymbolInfoDouble(_Symbol,SYMBOL_ASK)
                             : SymbolInfoDouble(_Symbol,SYMBOL_BID));

   bool allow = true;
   double score = 0.0;
   string reasons = "[";
   bool first = true;

   // 1) Exec pre-order gate (жёстко)
   if(R_Use_ExecGate){
      bool ok = ExecGate_PreOrder(_Symbol, _Period, dir, entry_price, mkt);
      if(!ok) allow=false;
      if(!first) reasons += ","; first=false;
      reasons += "{"+_kv("check","exec_preorder")+","+_kv("pass", ok?"1":"0")+"}";
   }

   // 2) VWAP (мягкие проверки)  только если модуль уже подключён в проекте
   #ifdef __TYP_VWAP_MQH__
   if(allow && R_Use_VWAP_Confirm){
      bool ok = VWAP_CheckConfirm(_Symbol, _Period, dir, mkt);
      if(!ok) allow=false;
      if(!first) reasons += ","; first=false;
      reasons += "{"+_kv("check","vwap_confirm")+","+_kv("pass", ok?"1":"0")+","+_kvn("w",R_W_VWAP_Confirm)+"}";
      if(ok) score += R_W_VWAP_Confirm;
   }
   if(allow && R_Use_VWAP_Headwind){
      bool ok = VWAP_CheckHeadwind(_Symbol, _Period, dir, entry_price);
      if(!ok) allow=false;
      if(!first) reasons += ","; first=false;
      reasons += "{"+_kv("check","vwap_headwind")+","+_kv("pass", ok?"1":"0")+","+_kvn("w",R_W_VWAP_Headwind)+"}";
      if(ok) score += R_W_VWAP_Headwind;
   }
   #endif

   reasons += "]";
   if(R_Log_JSON){
      json_reason = "{"+_kv("sym",_Symbol)+","+_kv("tf",IntegerToString(_Period))+","+_kv("dir",IntegerToString(dir))+
                    ","+_kvn("entry",entry_price)+","+_kvn("mkt",mkt)+","+_kvn("score",score)+","+_kv("allow",allow?"1":"0")+
                    ","+"\"checks\":"+reasons+"}";
      Print("[ResolverV2] ", json_reason);
   } else json_reason = "";

   return allow;
}

#endif // __TYP_RESOLVER_V2_MQH__

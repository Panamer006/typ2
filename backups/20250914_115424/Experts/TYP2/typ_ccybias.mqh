#ifndef __TYP_CCYBIAS_MQH__
#define __TYP_CCYBIAS_MQH__
#include "typ_core.mqh"

struct CCYBiasState { double S_base; double S_quote; double delta; bool dominant; };

input bool UseCCYBias=true;
input ENUM_TIMEFRAMES Bias_TF=PERIOD_H1;
input int Bias_Lookback=48;
input int Bias_SmoothEMA=5;
input bool Bias_UseZScore=true;
input double Bias_Threshold=0.6;
input double Bias_HeadwindPenalty=1.0;

// --- NEW: Cross-dominance (EUR vs GBP by EURGBP) ---
input bool Bias_UseCrossDominance=true;
input string Bias_CrossSymbol="EURGBP";
input ENUM_TIMEFRAMES Bias_CrossTF=PERIOD_H1;
input int Bias_CrossLookback=48;
input int Bias_CrossSmoothEMA=5;
input bool Bias_CrossZScore=true;
input double Bias_CrossThreshold=0.20; // significance threshold

string EUR_BASKET[]={"EURUSD","EURGBP","EURJPY","EURAUD","EURCAD","EURCHF","EURNZD"};
string USD_BASKET[]={"EURUSD","GBPUSD","USDJPY","AUDUSD","USDCAD","USDCHF","NZDUSD"};
string GBP_BASKET[]={"GBPUSD","EURGBP","GBPJPY","GBPAUD","GBPCAD","GBPCHF","GBPNZD"};
string JPY_BASKET[]={"USDJPY","EURJPY","GBPJPY","AUDJPY","CADJPY","CHFJPY","NZDJPY"};
string AUD_BASKET[]={"EURAUD","AUDUSD","AUDJPY","AUDCAD","AUDCHF","AUDNZD","GBPAUD"};
string CAD_BASKET[]={"USDCAD","EURCAD","GBPCAD","AUDCAD","CADJPY","CADCHF","NZDCAD"};
string CHF_BASKET[]={"USDCHF","EURCHF","GBPCHF","AUDCHF","CADCHF","CHFJPY","NZDCHF"};
string NZD_BASKET[]={"EURNZD","NZDUSD","NZDJPY","AUDNZD","NZDCAD","NZDCHF","GBPNZD"};

bool sym_exists(const string s){ return SymbolSelect(s,true); }

double pair_change_signed(const string sym,const string ccy,int lookback){
  if(!sym_exists(sym)) return 0.0;
  double p0=iClose(sym,Bias_TF,0), pL=iClose(sym,Bias_TF,lookback);
  if(p0<=0||pL<=0) return 0.0;
  double ch=(p0-pL)/pL;
  string base=StringSubstr(sym,0,3), quote=StringSubstr(sym,3,3);
  if(ccy==base) return +ch;
  if(ccy==quote) return -ch;
  return 0.0;
}

double basket_strength_raw(string ccy){
  string &B[]=(ccy=="EUR")?EUR_BASKET:(ccy=="USD")?USD_BASKET:(ccy=="GBP")?GBP_BASKET:(ccy=="JPY")?JPY_BASKET:(ccy=="AUD")?AUD_BASKET:(ccy=="CAD")?CAD_BASKET:(ccy=="CHF")?CHF_BASKET:NZD_BASKET;
  int n=ArraySize(B); if(n==0) return 0.0;
  double acc=0; int k=0;
  for(int i=0;i<n;i++){ double v=pair_change_signed(B[i], ccy, Bias_Lookback); if(v!=0){ acc+=v; k++; } }
  if(k==0) return 0.0;
  return acc/k;
}

double zscore_solo(double x){
  double s=(x==0?1e-6:fabs(x));
  double z=x/s;
  if(z>3) z=3; if(z<-3) z=-3;
  return z;
}

void split_symbol_bias(const string sym, string &base, string &quote){
  base=StringSubstr(sym,0,3); quote=StringSubstr(sym,3,3);
}

CCYBiasState BiasFor(const string sym){
  CCYBiasState st; st.S_base=0; st.S_quote=0; st.delta=0; st.dominant=false;
  if(!UseCCYBias) return st;
  string base,quote; split_symbol_bias(sym,base,quote);
  double Sb=basket_strength_raw(base), Sq=basket_strength_raw(quote);
  if(Bias_UseZScore){ Sb=zscore_solo(Sb); Sq=zscore_solo(Sq); }
  static double pb=0, pq=0; static bool init=false;
  double k=2.0/(MathMax(1,Bias_SmoothEMA)+1.0);
  double eb,eq;
  if(!init){ eb=Sb; eq=Sq; init=true; } else { eb = k*Sb + (1.0-k)*pb; eq = k*Sq + (1.0-k)*pq; }
  pb=Sb; pq=Sq;
  st.S_base=eb; st.S_quote=eq;
  st.delta=eb-eq;
  st.dominant=(MathAbs(st.delta)>=Bias_Threshold);
  return st;
}

// --- NEW: EUR vs GBP cross dominance via EURGBP ---
double __cross_delta_raw(){
  if(!Bias_UseCrossDominance) return 0.0;
  string cs=Bias_CrossSymbol; if(StringLen(cs)!=6) return 0.0;
  if(!sym_exists(cs)) return 0.0;
  double p0=iClose(cs, Bias_CrossTF, 0), pL=iClose(cs, Bias_CrossTF, Bias_CrossLookback);
  if(p0<=0||pL<=0) return 0.0;
  double ch=(p0-pL)/pL; // >0 => EUR stronger vs GBP
  if(Bias_CrossZScore) ch=zscore_solo(ch);
  static double prev=0; static bool init=false;
  double k=2.0/(MathMax(1,Bias_CrossSmoothEMA)+1.0);
  double sm = (init? (k*ch + (1.0-k)*prev) : ch);
  prev=sm; init=true;
  return sm;
}

// Return bonus in [-1..+1] for symbol+dir alignment with EUR/GBP cross dominance.
double CCYCrossBonusFor(const string sym, int dir){
  if(!Bias_UseCrossDominance || dir==0) return 0.0;
  double d = __cross_delta_raw(); // >0 EUR>GBP, <0 GBP>EUR
  if(MathAbs(d) < Bias_CrossThreshold) return 0.0; // not significant
  string base=StringSubstr(sym,0,3), quote=StringSubstr(sym,3,3);
  bool hasEUR=(base=="EUR"||quote=="EUR");
  bool hasGBP=(base=="GBP"||quote=="GBP");
  if(!(hasEUR||hasGBP)) return 0.0;

  double m = MathMin(1.0, MathAbs(d)/MathMax(1e-6, Bias_CrossThreshold));

  double sgn=0.0;
  if(hasEUR && !hasGBP){
    sgn = (d>0? +1.0 : -1.0);
    if(quote=="EUR") sgn = -sgn;
  } else if(hasGBP && !hasEUR){
    sgn = (d>0? -1.0 : +1.0);
    if(quote=="GBP") sgn = -sgn;
  } else {
    return 0.0; // EURGBP itself — игнор
  }
  double align = (dir>0? sgn : -sgn);
  return align * m; // [-1..+1]
}

#endif

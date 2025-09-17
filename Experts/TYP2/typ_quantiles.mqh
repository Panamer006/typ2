#pragma once
//+------------------------------------------------------------------+
//| TYP2 - Quantiles Loader (статистика по часам)                    |
//+------------------------------------------------------------------+
#property copyright "TYP2"
struct QRow { string sym; int hour; int spread_q80; double atrpct_q20; double atrpct_q80; };
QRow _QRows[];

bool TYPQ_Load(const string csvName="quantiles.csv"){
  int h = FileOpen(csvName, FILE_READ|FILE_CSV|FILE_ANSI, ',');
  if(h==INVALID_HANDLE){ PrintFormat("Quantiles: Файл %s не найден в MQL5/Files/", csvName); return false; }
  ArrayResize(_QRows, 0);
  if(!FileIsEnding(h)) {
    string h1=FileReadString(h); // Пропускаем заголовок
    if(StringToLower(h1)=="symbol") { for(int i=0;i<4;i++) FileReadString(h); } else { FileSeek(h,0,SEEK_SET); }
  }
  while(!FileIsEnding(h)){
    QRow row;
    row.sym=FileReadString(h); if(row.sym=="") break;
    row.hour  =(int)StrToInteger(FileReadString(h));
    row.spread_q80=(int)StrToInteger(FileReadString(h));
    row.atrpct_q20  =StrToDouble(FileReadString(h));
    row.atrpct_q80  =StrToDouble(FileReadString(h));
    int n=ArraySize(_QRows); ArrayResize(_QRows,n+1); _QRows[n]=row;
  }
  FileClose(h);
  PrintFormat("Quantiles: Загружено %d строк из %s", ArraySize(_QRows), csvName);
  return ArraySize(_QRows)>0;
}

bool __TYPQ_Find(const string sym, int hour, int &idxOut){
  for(int i=0;i<ArraySize(_QRows);++i)
    if(_QRows[i].sym==sym && _QRows[i].hour==hour){ idxOut=i; return true; }
  return false;
}

int TYPQ_SpreadQ80(const string sym, int hour, int fallbackPts){
  int idx; if(__TYPQ_Find(sym,hour,idx)) return _QRows[idx].spread_q80;
  return fallbackPts;
}

bool TYPQ_ATRPctRange(const string sym, int hour, double &lo, double &hi, double fallbackLo, double fallbackHi){
  int idx; if(__TYPQ_Find(sym,hour,idx)){ lo=_QRows[idx].atrpct_q20; hi=_QRows[idx].atrpct_q80; return true; }
  lo=fallbackLo; hi=fallbackHi; return false;
}

#pragma once
// Простые обёртки для рисования линий/уровней (для визуальных тестов)
void DrawHLine(const string name, const double price, const color clr, const int style=STYLE_DASHDOT) {
  string nm = name+"#"+IntegerToString(GetTickCount());
  if(ObjectCreate(0,nm,OBJ_HLINE,0,TimeCurrent(),price)) {
    ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
    ObjectSetInteger(0,nm,OBJPROP_STYLE,style);
    ObjectSetInteger(0,nm,OBJPROP_WIDTH,1);
  }
}

void DrawTrend(const string name, datetime t1,double p1, datetime t2,double p2, const color clr) {
  string nm = name+"#"+IntegerToString(GetTickCount());
  if(ObjectCreate(0,nm,OBJ_TREND,0,t1,p1,t2,p2)) {
    ObjectSetInteger(0,nm,OBJPROP_COLOR,clr);
    ObjectSetInteger(0,nm,OBJPROP_WIDTH,2);
  }
}

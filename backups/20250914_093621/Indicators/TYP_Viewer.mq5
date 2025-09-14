#property indicator_chart_window
#property strict
// TYP Viewer (slim) — shows MA1 (primary) and MA2 (adaptive)

input int MA1_Period = 200;
input int MA2_Period = 34;

int h_ma1,h_ma2L,h_ma2H;
int OnInit()
{
  h_ma1 = iMA(_Symbol, PERIOD_CURRENT, MA1_Period, 0, MODE_EMA, PRICE_CLOSE);
  h_ma2L= iMA(_Symbol, PERIOD_CURRENT, MA2_Period, 0, MODE_EMA, PRICE_LOW);
  h_ma2H= iMA(_Symbol, PERIOD_CURRENT, MA2_Period, 0, MODE_EMA, PRICE_HIGH);
  return(INIT_SUCCEEDED);
}

int OnCalculate(const int rates_total,const int prev_calculated,const datetime &time[],const double &open[],const double &high[],const double &low[],const double &close[],const long &tick_volume[],const long &volume[],const int &spread[])
{
  if(rates_total<3) return(rates_total);
  double ma1[],ma2L[],ma2H[]; ArraySetAsSeries(ma1,true);ArraySetAsSeries(ma2L,true);ArraySetAsSeries(ma2H,true);
  CopyBuffer(h_ma1,0,0,2,ma1); CopyBuffer(h_ma2L,0,0,2,ma2L); CopyBuffer(h_ma2H,0,0,2,ma2H);

  double price = close[0];
  bool above = price>ma1[0];
  double ma2 = above?ma2L[0]:ma2H[0];

  string n1 = "TYPV_MA1"; string n2 = "TYPV_MA2";
  DrawHLine(n1, ma1[0], clrDodgerBlue);
  DrawHLine(n2, ma2,    clrOrange);
  return(rates_total);
}

void DrawHLine(string name,double price,color c)
{
  if(!ObjectFind(0,name)) ObjectCreate(0,name,OBJ_HLINE,0,0,0);
  ObjectSetDouble(0,name,OBJPROP_PRICE,price);
  ObjectSetInteger(0,name,OBJPROP_COLOR,c);
}

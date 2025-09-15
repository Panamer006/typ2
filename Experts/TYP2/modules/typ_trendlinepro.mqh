#pragma once
#property strict
// T2-008 Trendline Pro v1
// Функция: строим базовую трендовую (по свингам), канал, и выдаём сигналы:
//  - TL_RETEST_FADE_* (третье касание/ретест с отбоем)
//  - TL_BREAK_RETAKE_* (пробой + ретест)
//  - TL_FALSE_BREAK_*  (ложный пробой и возврат)
// Логи — в текст/JSON, без открытия сделок. Демонстрацию см. в TLP_Demo.mq5.

enum TLSigType {
  TL_NONE = 0,
  TL_RETEST_FADE_BUY, TL_RETEST_FADE_SELL,
  TL_BREAK_RETAKE_BUY, TL_BREAK_RETAKE_SELL,
  TL_FALSE_BREAK_BUY,  TL_FALSE_BREAK_SELL,
  TL_CHANNEL_TP
};

struct TLProInput {
  // Свинги (псевдо-ZZ на свинг-окне)
  int    swingLeft          = 4;
  int    swingRight         = 3;
  int    lookBackBars       = 500;

  // Метрики
  int    atrPeriod          = 14;
  double tolTouchATR        = 0.35;  // допуск касания к TL
  double breakBufferATR     = 0.35;  // для подтверждения пробоя (close за линией)
  int    retestBars         = 5;     // окно ретеста после пробоя

  // Ложный пробой (FBO)
  double fboCloseATR        = 0.40;  // «тонкий» выход
  int    fboLookAheadBars   = 3;     // возврат внутрь за N баров
  double wickBodyMin        = 1.50;  // тень/тело на баре выхода

  // Вспомогательно
  int    minBarsBetweenTouches = 6;  // чтобы не считать «кластер» как новое касание

  // Канал
  double channelWidthATR    = 2.0;   // ориентир ТР от midline (для демо)

  // SMA500 (режим)
  int    smaBigPeriod       = 500;
  ENUM_MA_METHOD smaBigMethod = MODE_SMA;
};

struct TLSignal {
  TLSigType type;
  datetime  t0;
  double    price;
  double    sl, tp;
  string    note;
  bool      inBigTrend;

  // Отладка/рисование
  int iA, iB;      double pA, pB;     // базовая TL (через A->B)
  int iOpp;        double pOpp;       // параллель через противоположный свинг (верх/низ канала)
  double lineNow;  // цена линии на баре 0
};

class CTLTrendlinePro {
private:
  string _sym; ENUM_TIMEFRAMES _tf; TLProInput _in;
  int _hATR, _hSMA;

  struct Swing { int i; double px; bool isHigh; };
  Swing _swings[];  // series=true

  static double _atr(int h){ double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(h,0,0,2,b)<2) return 0; return b[0]; }
  static double _sma(int h){ double b[]; ArraySetAsSeries(b,true); if(CopyBuffer(h,0,0,1,b)<1) return EMPTY_VALUE; return b[0]; }

  bool _isHigh(const int i,const int L,const int R){
    for(int k=1;k<=L;k++) if(High[i]<High[i+k]) return false;
    for(int k=1;k<=R;k++) if(High[i]<=High[i-k])return false;
    return true;
  }
  bool _isLow(const int i,const int L,const int R){
    for(int k=1;k<=L;k++) if(Low[i]>Low[i+k])  return false;
    for(int k=1;k<=R;k++) if(Low[i]>=Low[i-k]) return false;
    return true;
  }

  void _collectSwings()
  {
    ArrayResize(_swings,0);
    int maxb = MathMin(_in.lookBackBars, Bars(_sym,_tf)-(_in.swingLeft+_in.swingRight+5));
    for(int i=_in.swingRight; i<maxb; ++i)
    {
      if(_isHigh(i,_in.swingLeft,_in.swingRight)){
        int n=ArraySize(_swings); ArrayResize(_swings,n+1);
        _swings[n].i=i; _swings[n].px=High[i]; _swings[n].isHigh=true;
      }
      if(_isLow(i,_in.swingLeft,_in.swingRight)){
        int n=ArraySize(_swings); ArrayResize(_swings,n+1);
        _swings[n].i=i; _swings[n].px=Low[i]; _swings[n].isHigh=false;
      }
    }
    // упорядочены по индексу возрастанию (старее → новее), потому что series=true и i увеличивается в прошлое
    // нам удобнее обратный обход: от старших i к меньшим (к текущему) — сделаем где надо.
  }

  // Линия по двум точкам A(iA,pA) и B(iB,pB): цена на баре k
  static double _priceOnLine(const int iA,const double pA,const int iB,const double pB,const int k){
    const double m = (pB - pA) / (iB - iA + 1e-9);
    return pB + m * (k - iB);
  }

  // поиск базовой TL: два ближайших по времени «согласных» свинга одного типа с положительным/отрицательным уклоном
  bool _findBaseTL(int &iA,double &pA,int &iB,double &pB,bool &isSupport,int &iOpp,double &pOpp)
  {
    // берём последние 300 свингов и просматриваем пары (low->low) и (high->high)
    int n=ArraySize(_swings); if(n<4) return false;

    // пробуем поддержку (ап-тренд): последние два low с восходящим наклоном
    for(int a=n-1; a>=1; --a){
      for(int b=a-1; b>=0; --b){
        if(!_swings[a].isHigh && !_swings[b].isHigh){
          int i1=_swings[b].i, i2=_swings[a].i; double p1=_swings[b].px, p2=_swings[a].px;
          if(i2>=i1) continue; // требуется iB<iA по серии? мы хотим A старше, B новее
          if(p2<=p1) continue; // должен расти
          // нашли! теперь оппозитный свинг — берём ближайший high между ними или сразу после
          int iH=-1; double pH=0.0;
          for(int k=a; k<n; ++k){ if(_swings[k].isHigh){ iH=_swings[k].i; pH=_swings[k].px; break; } }
          if(iH<0){ for(int k=a-1; k>=0; --k){ if(_swings[k].isHigh){ iH=_swings[k].i; pH=_swings[k].px; break; } }
          }
          iA=i1; pA=p1; iB=i2; pB=p2; isSupport=true; iOpp=iH; pOpp=pH; return true;
        }
      }
    }
    // пробуем сопротивление (даун-тренд): два high с нисходящим наклоном
    for(int a=n-1; a>=1; --a){
      for(int b=a-1; b>=0; --b){
        if(_swings[a].isHigh && _swings[b].isHigh){
          int i1=_swings[b].i, i2=_swings[a].i; double p1=_swings[b].px, p2=_swings[a].px;
          if(i2>=i1) continue;
          if(p2>=p1) continue; // должен падать
          int iL=-1; double pL=0.0;
          for(int k=a; k<n; ++k){ if(!_swings[k].isHigh){ iL=_swings[k].i; pL=_swings[k].px; break; } }
          if(iL<0){ for(int k=a-1; k>=0; --k){ if(!_swings[k].isHigh==false){ iL=_swings[k].i; pL=_swings[k].px; break; } }
          }
          iA=i1; pA=p1; iB=i2; pB=p2; isSupport=false; iOpp=iL; pOpp=pL; return true;
        }
      }
    }
    return false;
  }

  // касание внутри допуска ATR
  bool _touchOK(const bool isSupport,const double linePx,const double atr,const int i,const int gap){
    if(isSupport)
      return ( (Low[i] <= linePx + _in.tolTouchATR*atr) && (Close[i] >= linePx) && (gap >= _in.minBarsBetweenTouches) );
    else
      return ( (High[i]>= linePx - _in.tolTouchATR*atr) && (Close[i] <= linePx) && (gap >= _in.minBarsBetweenTouches) );
  }

  // CLV [-1..+1]
  static double _clv(const int i){
    const double r = (High[i]-Low[i]); if(r<=0) return 0.0;
    return ((Close[i]-Low[i]) - (High[i]-Close[i])) / r;
  }

public:
  bool Init(const string sym, ENUM_TIMEFRAMES tf, const TLProInput &in)
  {
    _sym=sym; _tf=tf; _in=in;
    _hATR = iATR(_sym,_tf,_in.atrPeriod);
    _hSMA = iMA(_sym,_tf,_in.smaBigPeriod,0,_in.smaBigMethod,PRICE_CLOSE);
    ArraySetAsSeries(High,true); ArraySetAsSeries(Low,true); ArraySetAsSeries(Close,true); ArraySetAsSeries(Time,true);
    return (_hATR!=INVALID_HANDLE && _hSMA!=INVALID_HANDLE);
  }

  // Главная оценка — возвращает 0/1 сигнал на текущий бар
  bool Evaluate(TLSignal &sig)
  {
    sig.type=TL_NONE; sig.t0=Time[0]; sig.price=Close[0]; sig.sl=0; sig.tp=0; sig.note=""; sig.inBigTrend=false;
    _collectSwings();
    int iA=-1,iB=-1,iOpp=-1; double pA=0,pB=0,pOpp=0; bool isSupport=true;
    if(!_findBaseTL(iA,pA,iB,pB,isSupport,iOpp,pOpp)) return false;

    const double atr = _atr(_hATR); if(atr<=0) return false;
    const double sma = _sma(_hSMA);
    sig.inBigTrend = ( (Close[0] > sma) == isSupport ); // апрежим для поддержки, даунрежим для сопротивления

    // текущая цена линии
    const double line0 = _priceOnLine(iA,pA,iB,pB,0);
    sig.iA=iA; sig.pA=pA; sig.iB=iB; sig.pB=pB; sig.lineNow=line0; sig.iOpp=iOpp; sig.pOpp=pOpp;

    // === 1) Третье касание / ретест с отбоем ===
    // считаем два последних касания (по окну 150 баров)
    int touches=0; int lastTouchGap=999;
    for(int i=iB-1, gap=0; i>0 && i>iB-150; --i, ++gap){
      double li = _priceOnLine(iA,pA,iB,pB,i);
      if(_touchOK(isSupport, li, atr, i, lastTouchGap)){
        touches++; lastTouchGap=0;
      }
    }
    if(touches>=1) // у нас уже есть две опоры (A,B), это будет «третье/четвёртое»
    {
      // отбой подтверждаем CLV на текущем баре
      double clv0 = _clv(0);
      if(isSupport && Close[0]>=line0 && clv0>=0.2){
        sig.type = TL_RETEST_FADE_BUY; sig.note="TL retest fade (support)"; sig.tp = Close[0] + _in.channelWidthATR*atr*(sig.inBigTrend?1.2:1.0);
        return true;
      }
      if(!isSupport && Close[0]<=line0 && clv0<=-0.2){
        sig.type = TL_RETEST_FADE_SELL; sig.note="TL retest fade (resistance)"; sig.tp = Close[0] - _in.channelWidthATR*atr*(sig.inBigTrend?1.2:1.0);
        return true;
      }
    }

    // === 2) Пробой + ретест (break & retake) ===
    // ищем в последних retestBars баров бар-пробой (close за линией > breakBuffer) и затем ретест (касание с обратной стороны)
    int iBreak=-1;
    for(int i=_in.retestBars; i>=1; --i){
      double li = _priceOnLine(iA,pA,iB,pB,i);
      if(isSupport){
        if(Close[i] < li - _in.breakBufferATR*atr) { iBreak=i; break; }
      } else {
        if(Close[i] > li + _in.breakBufferATR*atr) { iBreak=i; break; }
      }
    }
    if(iBreak>0){
      // был пробой — проверим ретест
      bool ret=false;
      for(int j=iBreak-1; j>=1 && j>=iBreak- _in.retestBars; --j){
        double lj = _priceOnLine(iA,pA,iB,pB,j);
        if(isSupport){
          if(High[j] >= lj - _in.tolTouchATR*atr && Close[j] < lj){ ret=true; break; }
        } else {
          if(Low[j]  <= lj + _in.tolTouchATR*atr && Close[j] > lj){ ret=true; break; }
        }
      }
      if(ret){
        if(isSupport){ sig.type=TL_BREAK_RETAKE_SELL; sig.note="TL break & retake (support)"; }
        else         { sig.type=TL_BREAK_RETAKE_BUY;  sig.note="TL break & retake (resistance)"; }
        sig.tp = (isSupport? Close[0]-_in.channelWidthATR*atr : Close[0]+_in.channelWidthATR*atr);
        return true;
      }
    }

    // === 3) Ложный пробой (FBO) ===
    // бар iF — тонкий выход (|close-line| < fboCloseATR*ATR) и быстрый возврат внутрь ≤ fboLookAheadBars, плюс «длинная тень»
    for(int i=_in.fboLookAheadBars; i>=1; --i){
      double li = _priceOnLine(iA,pA,iB,pB,i);
      double body = MathAbs(Close[i]-Open[i]);
      double wick = (isSupport? (High[i]-MathMax(Close[i],Open[i])) : (MathMin(Close[i],Open[i])-Low[i]));
      bool thinBreak = (isSupport? (Close[i] < li && (li-Close[i]) <= _in.fboCloseATR*atr)
                                  : (Close[i] > li && (Close[i]-li) <= _in.fboCloseATR*atr));
      if(thinBreak && wick/body >= _in.wickBodyMin){
        // возврат внутрь на текущем баре:
        if( (isSupport && Close[0] >= line0) || (!isSupport && Close[0] <= line0) ){
          if(isSupport){ sig.type=TL_FALSE_BREAK_BUY;  sig.note="TL FBO return (support)"; }
          else         { sig.type=TL_FALSE_BREAK_SELL; sig.note="TL FBO return (resistance)"; }
          sig.tp = (isSupport? Close[0]+_in.channelWidthATR*atr : Close[0]-_in.channelWidthATR*atr);
          return true;
        }
      }
    }

    // === 4) Канальный TP (по умолчанию — информативный) ===
    sig.type  = TL_CHANNEL_TP;
    sig.note  = "TL channel context";
    sig.tp    = (isSupport? Close[0]+_in.channelWidthATR*atr : Close[0]-_in.channelWidthATR*atr);
    return true;
  }
};

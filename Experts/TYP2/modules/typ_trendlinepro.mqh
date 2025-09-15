#pragma once
// T2-008 Trendline Pro (skeleton Block#1)
// ВНИМАНИЕ: это базовый каркас. Логика третьего касания/ретеста/пробоя будет расширяться блоками 2+.

struct TLProInput {
  // ZigZag (для свингов) — дефолт как в телефоне: 12/5/3
  int   zzDepth      = 12;
  int   zzDeviation  = 5;
  int   zzBackstep   = 3;

  // ATR и допуски
  int   atrPeriod    = 14;
  double tolTouchATR = 0.35;   // допуск касания к трендовой в ATR
  double tolBreakATR = 0.5;    // допуск for break/close

  // Режим крупной SMA (500) как «силовой тренд»
  int   smaBigPeriod = 500;
  ENUM_MA_METHOD smaBigMethod = MODE_SMA;

  // Канал/ТП
  double channelMulATR = 2.0;  // ширина рабочего канала (ATR) для early TP

  // Фильтры времени/спреда (будет подключено к ExecGate)
  int   minBarsBetweenTouches = 8;
};

enum TLSigType {
  TL_NONE = 0,
  TL_RETEST_FADE_BUY, TL_RETEST_FADE_SELL,
  TL_BREAK_RETAKE_BUY, TL_BREAK_RETAKE_SELL,
  TL_FALSE_BREAK_BUY,  TL_FALSE_BREAK_SELL,
  TL_CHANNEL_TP
};

struct TLSignal {
  TLSigType type;
  datetime  t0;         // бар сигнала (время close)
  double    price;      // референс
  double    sl, tp;     // базовые уровни (переопределяются Risk/Exit)
  string    note;       // причина
  bool      inBigTrend; // режим SMA500
};

class CTLTrendlinePro {
private:
  string _sym; ENUM_TIMEFRAMES _tf;
  int    _hATR, _hSMA;
  int    _bars;

  double ATR(int p) {
    double v[]; CopyBuffer(_hATR,0,0,p,v); return (ArraySize(v)>0?v[0]:0.0);
  }
  double SMA(int shift) {
    double v[]; CopyBuffer(_hSMA,0,shift,1,v); return (ArraySize(v)>0?v[0]:0.0);
  }
  bool InBigTrend(const TLProInput &in) {
    // inBigTrend = цена и «быстрые» MA над/под SMA500 (простая эвристика, расширим позднее)
    double price = iClose(_sym,_tf,0);
    double sma500 = SMA(0);
    return (price > sma500);
  }

public:
  bool Init(const string sym, ENUM_TIMEFRAMES tf, const TLProInput &in) {
    _sym=sym; _tf=tf;
    _hATR = iATR(_sym,_tf,in.atrPeriod);
    _hSMA = iMA(_sym,_tf,in.smaBigPeriod,0, in.smaBigMethod, PRICE_CLOSE);
    _bars = Bars(_sym,_tf);
    return (_hATR!=INVALID_HANDLE && _hSMA!=INVALID_HANDLE && _bars>100);
  }

  // Каркас сигнала: пока отрабатываем только CHANNEL_TP + big-trend regime flag.
  bool Evaluate(const TLProInput &in, TLSignal &sig) {
    ArrayInitialize(sig,0);
    sig.type = TL_NONE;
    if(_bars<200) return false;

    // TODO: построение трендовой по ZZ (12/5/3) и каналов. Здесь — заглушка канала по ATR.
    double atr = ATR(0);
    if(atr<=0) return false;

    sig.inBigTrend = InBigTrend(in);

    // Простейший ранний TP: если волатильность высока, вернуть «канальный» TP
    if(atr > 0) {
      sig.type  = TL_CHANNEL_TP;
      sig.t0    = TimeCurrent();
      sig.price = iClose(_sym,_tf,0);
      sig.sl    = 0.0;                    // выставит Risk/Exit
      sig.tp    = sig.price + in.channelMulATR*atr*(sig.inBigTrend? 1.2:1.0); // черновой расчёт
      sig.note  = "TL: channel TP (skeleton)";
      return true;
    }
    return false;
  }
};

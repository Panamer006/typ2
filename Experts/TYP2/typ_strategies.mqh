#pragma once
//+------------------------------------------------------------------+
//| TYP2 - Strategies Module (T2-STRAT-NIGHT) v1.0                   |
//| Включает: Night MR и Night Scalp                                 |
//+------------------------------------------------------------------+
#property copyright "TYP2"
#include "typ_core.mqh"

// --- Улучшенная структура сигнала ---
struct TYP_SignalEx {
  bool valid; string id,symbol,bucket,reason;
  int dir; double entry, sl, tp1, tp2, tp3; datetime expiry; double strength;
  bool use_stop_limit; double stop_price;
};

// --- Утилиты для стратегий ---
namespace StratUtils {
  bool IsQuietRange(const string s, ENUM_TIMEFRAMES tf, int bars, double max_atr_mult) {
    double atr = ExecUtils::_atr(s, tf); if (atr <= 0) return false;
    double high = iHigh(s, tf, iHighest(s, tf, MODE_HIGH, bars, 1));
    double low = iLow(s, tf, iLowest(s, tf, MODE_LOW, bars, 1));
    return (high - low) <= max_atr_mult * atr;
  }
  
  double GetEMASlope(const string s, ENUM_TIMEFRAMES tf, int period) {
      int handle = iMA(s, tf, period, 0, MODE_EMA, PRICE_CLOSE);
      if(handle == INVALID_HANDLE) return 0.0;
      double ma_values[2];
      if(CopyBuffer(handle, 0, 0, 2, ma_values) < 2) return 0.0;
      return ma_values[0] - ma_values[1];
  }
}

// --- Реализация ночных стратегий ---
TYP_SignalEx BuildNightMR(const string sym, ENUM_TIMEFRAMES tf) {
  TYP_SignalEx s; ZeroMemory(s); s.symbol=sym; s.bucket="FX_Night_MR"; s.id="night_mr_v1";
  
  // Фильтр "Slope Veto"
  if (MathAbs(StratUtils::GetEMASlope(sym, tf, 50)) > ExecUtils::_atr(sym, tf) * 0.1) {
      s.reason = "Slope too high"; return s;
  }

  // Сигнал по RSI (пример)
  int rsi_handle = iRSI(sym, tf, 14, PRICE_CLOSE);
  if (rsi_handle != INVALID_HANDLE) {
      double rsi_val[1];
      if (CopyBuffer(rsi_handle, 0, 0, 1, rsi_val) > 0) {
          double atr = ExecUtils::_atr(sym, tf);
          if (rsi_val[0] > 70) {
              s.valid = true; s.dir = -1; // SHORT
              s.entry = SymbolInfoDouble(sym, SYMBOL_BID);
              s.sl = s.entry + 1.5 * atr;
              s.tp1 = s.entry - 1.0 * atr;
              s.reason = "RSI Overbought";
          } else if (rsi_val[0] < 30) {
              s.valid = true; s.dir = 1; // LONG
              s.entry = SymbolInfoDouble(sym, SYMBOL_ASK);
              s.sl = s.entry - 1.5 * atr;
              s.tp1 = s.entry + 1.0 * atr;
              s.reason = "RSI Oversold";
          }
      }
  }
  return s;
}

TYP_SignalEx BuildNightScalp(const string sym, ENUM_TIMEFRAMES tf) {
  TYP_SignalEx s; ZeroMemory(s); s.symbol=sym; s.bucket="FX_Night_Scalp"; s.id="night_scalp_v1";

  if (!StratUtils::IsQuietRange(sym, tf, 12, 1.5)) {
      s.reason = "Range not quiet"; return s;
  }
  
  // Пример сигнала по Bollinger Bands
  int bb_handle = iBands(sym, tf, 20, 0, 2.0, PRICE_CLOSE);
  if (bb_handle != INVALID_HANDLE) {
      double upper_band[1], lower_band[1];
      if (CopyBuffer(bb_handle, 1, 0, 1, upper_band) > 0 && CopyBuffer(bb_handle, 2, 0, 1, lower_band) > 0) {
          double price = iClose(sym, tf, 0);
          if (price > upper_band[0]) {
              s.valid = true; s.dir = -1; // SHORT
              s.entry = SymbolInfoDouble(sym, SYMBOL_BID);
              s.sl = price + ExecUtils::_atr(sym, tf) * 1.0;
              s.tp1 = price - ExecUtils::_atr(sym, tf) * 0.8;
              s.reason = "BB Upper Break";
          } else if (price < lower_band[0]) {
              s.valid = true; s.dir = 1; // LONG
              s.entry = SymbolInfoDouble(sym, SYMBOL_ASK);
              s.sl = price - ExecUtils::_atr(sym, tf) * 1.0;
              s.tp1 = price + ExecUtils::_atr(sym, tf) * 0.8;
              s.reason = "BB Lower Break";
          }
      }
  }
  return s;
}

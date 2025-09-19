#pragma once
//+------------------------------------------------------------------+
//| TYP2 - Portfolio Risk Manager Module (T2-RISK) v1.2              |
//+------------------------------------------------------------------+
#property copyright "TYP2"
#property version   "2.1.0"
input group "Portfolio Risk Manager"
input bool   Risk_EnableEquityGuard   = true;
input double Risk_DailyMaxLossPercent = 2.0;
input bool   Risk_EnableBasketLimits  = true;
input double Risk_MaxNetRisk_USD      = 1.5;
input double Risk_MaxNetRisk_EUR      = 1.5;
input double Risk_MaxNetRisk_JPY      = 1.0;
namespace EquityGuard {
  static double dayStartEquity = 0; static datetime dayStartTime = 0; static bool isLocked = false;
  void OnNewDay() {
    dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY); dayStartTime = iTime(_Symbol, PERIOD_D1, 0); isLocked = false;
    PrintFormat("[EquityGuard] New day. Start Equity: %.2f", dayStartEquity);
  }
  bool IsOK() {
    if (!Risk_EnableEquityGuard) return true;
    if (iTime(_Symbol, PERIOD_D1, 0) != dayStartTime) OnNewDay();
    if (isLocked) return false;
    double drawdown = (dayStartEquity - AccountInfoDouble(ACCOUNT_EQUITY)) / dayStartEquity * 100.0;
    if (drawdown >= Risk_DailyMaxLossPercent) {
      isLocked = true; PrintFormat("[EquityGuard] LOCK! DD %.2f%% > Limit %.2f%%", drawdown, Risk_DailyMaxLossPercent); return false;
    }
    return true;
  }
}
namespace CurrencyBasket {
  double GetCurrentRiskPercent(string currency) {
    double totalRisk = 0;
    for (int i = PositionsTotal() - 1; i >= 0; i--) {
      if (PositionGetSymbol(i)) {
        if (StringFind(PositionGetString(POSITION_SYMBOL), currency) != -1) totalRisk += 1.0; // TODO: Заменить на точный расчет риска
      }
    }
    return totalRisk;
  }
  bool IsOK(string symbol, double newTradeRiskPercent) {
    if (!Risk_EnableBasketLimits) return true;
    string baseC = StringSubstr(symbol, 0, 3), quoteC = StringSubstr(symbol, 3, 3);
    double limit = 0;
    if (StringFind("USD,EUR,JPY", baseC) != -1) {
      if (baseC == "USD") limit = Risk_MaxNetRisk_USD; if (baseC == "EUR") limit = Risk_MaxNetRisk_EUR; if (baseC == "JPY") limit = Risk_MaxNetRisk_JPY;
      if (GetCurrentRiskPercent(baseC) + newTradeRiskPercent > limit) { PrintFormat("[BasketLimit] LOCK! %s limit %.1f%% exceeded", baseC, limit); return false; }
    }
    if (StringFind("USD,EUR,JPY", quoteC) != -1) {
      if (quoteC == "USD") limit = Risk_MaxNetRisk_USD; if (quoteC == "EUR") limit = Risk_MaxNetRisk_EUR; if (quoteC == "JPY") limit = Risk_MaxNetRisk_JPY;
      if (GetCurrentRiskPercent(quoteC) + newTradeRiskPercent > limit) { PrintFormat("[BasketLimit] LOCK! %s limit %.1f%% exceeded", quoteC, limit); return false; }
    }
    return true;
  }
}
bool Risk_PortfolioGuardsOK(string symbol, int dir, double entryPrice, double newTradeRiskPercent) {
  if (!EquityGuard::IsOK()) return false;
  if (!CurrencyBasket::IsOK(symbol, newTradeRiskPercent)) return false;
  return true;
}

#property strict
#property description "Take Your Profit 2.0  SLIM bootstrap"
#property version     "3.1.002"

#include <Trade/Trade.mqh>
CTrade TYPTrade;

// базовые модули
#include "typ_core.mqh"
#include "typ_risk.mqh"
#include "typ_be.mqh"
#include "typ_exit.mqh"
#include "typ_parental.mqh"
#include "typ_strategies.mqh"

// --- Inputs для smoke-теста (минимум)
input bool  UseParentalLock = false;

// --- Жизненный цикл
int OnInit()
{
  // тут позже инициализируем стратегии/ресолвер/фильтры
  return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
}

void OnTick()
{
  // SLIM: пока ничего не делаем  просто проверка сборки/развёртывания
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &req,
                        const MqlTradeResult &res)
{
  // SLIM: опционально передадим в parental lock, когда он включён
  // if(UseParentalLock) GLock.Handle(trans, req, res);
}

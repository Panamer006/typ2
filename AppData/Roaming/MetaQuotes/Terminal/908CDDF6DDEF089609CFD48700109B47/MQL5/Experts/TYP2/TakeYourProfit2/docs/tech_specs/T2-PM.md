# Техническое Задание: T2-PM - Position Manager (v2 - Полная Версия)

## 1. Цель
Создать и интегрировать модуль управления позициями `CPositionManager` в файле `typ_pm.mqh`.

---

## 2. Файл №1: `typ_pm.mqh` (CPositionManager)

**Действие:** Создать новый файл `MQL5/Experts/TYP2/TakeYourProfit2/Modules/typ_pm.mqh` со следующим содержимым.

```cpp
// --- typ_pm.mqh ---
#ifndef TYP_PM_MQH
#define TYP_PM_MQH

#include "typ_regime_engine.mqh"
#include "typ_risk.mqh"
#include <Arrays\ArrayObj.mqh>

// --- Структура для хранения состояния каждой управляемой позиции ---
class CManagedPosition : public CObject {
public:
    ulong    ticket;
    string   symbol;
    double   initial_risk_money;
    int      be_stage; // 0-Нет, 1-Profit Lock, 2-Full BE
    
    CManagedPosition() : ticket(0), initial_risk_money(0.0), be_stage(0) {}
};

class CPositionManager {
private:
    // --- СОСТОЯНИЕ КЛАССА ---
    CArrayObj*    m_managed_positions;
    CRiskManager* m_risk_manager_ptr; // Указатель на Risk Manager

public:
    CPositionManager() {
        m_managed_positions = new CArrayObj();
        m_risk_manager_ptr = NULL;
    }
    ~CPositionManager() {
        if(CheckPointer(m_managed_positions) == POINTER_DYNAMIC) {
            delete m_managed_positions;
        }
    }
    
    void Initialize(CRiskManager* risk_manager) {
        m_risk_manager_ptr = risk_manager;
    }

    void OnTick(E_MarketRegime current_regime) {
        // TODO: В будущем здесь будет цикл по всем управляемым позициям
        // для вызова HandleBreakEven, HandleTakeProfit и т.д.
    }

    void AddNewPosition(ulong ticket, double initial_risk) {
        CManagedPosition* pos = new CManagedPosition();
        pos.ticket = ticket;
        pos.initial_risk_money = initial_risk;
        m_managed_positions.Add(pos);
        Print("Position Manager: New position ", ticket, " is now under management.");
    }

private:
    // --- ЗАГЛУШКИ ДЛЯ БУДУЩЕЙ РЕАЛИЗАЦИИ ---
    void HandleBreakEven(CManagedPosition &pos, E_MarketRegime regime) {
        // Логика безубытка будет здесь
    }
    void HandleTakeProfit(CManagedPosition &pos, E_MarketRegime regime) {
        // Логика тейк-профита будет здесь
    }
    void HandleAddons(CManagedPosition &pos, E_MarketRegime regime) {
        // Логика доливок будет здесь
    }
};
#endif

# Файл №2: TakeYourProfit2.mq5 (Интеграция)
Действие: Полностью перезаписать главный файл MQL5/Experts/TYP2/TakeYourProfit2/TakeYourProfit2.mq5 следующим кодом для интеграции нового модуля.
code
C++
//+------------------------------------------------------------------+
//|                                           TakeYourProfit2.mq5 |
//+------------------------------------------------------------------+
#property version   "6.03"
#property strict

#include "Modules/typ_core.mqh"
#include "Modules/typ_regime_engine.mqh"
#include "Modules/typ_risk.mqh"
#include "Modules/typ_execfilters.mqh"
#include "Modules/typ_pm.mqh" // <<<--- ИНТЕГРАЦИЯ НОВОГО МОДУЛЯ

// --- INPUT ПАРАМЕТРЫ ---
input double InpMaxDailyDD = 5.0;
input bool InpGradualDD = true;
input int InpMaxOrders = 10;
input double InpMaxSpreadPips = 3.0;
input double InpBaseRiskPercent = 1.0;

// --- ГЛОБАЛЬНЫЕ ОБЪЕКТЫ ---
CRegimeEngine   g_RegimeEngine;
CRiskManager    g_RiskManager;
CExecGate       g_ExecGate;
CPositionManager g_PosManager; // <<<--- НОВЫЙ ОБЪЕКТ
E_MarketRegime  g_currentRegime;

//+------------------------------------------------------------------+
int OnInit()
{
  Print("TYP2 Initializing Modules...");
  
  g_RegimeEngine.Initialize(_Symbol, PERIOD_H1);
  g_RiskManager.Initialize(InpMaxDailyDD, InpGradualDD, InpMaxOrders);
  g_ExecGate.Initialize(InpMaxSpreadPips);
  g_PosManager.Initialize(&g_RiskManager); // <<<--- ИНИЦИАЛИЗАЦИЯ
  
  return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {}
//+------------------------------------------------------------------+
void OnTick()
{
  g_RegimeEngine.Update(_Symbol, PERIOD_H1);
  g_RiskManager.OnTick();
  g_PosManager.OnTick(g_currentRegime); // <<<--- ОБНОВЛЕНИЕ
  
  // --- Пример торговой логики с проверками ---
  static datetime last_trade_time = 0;
  if (TimeCurrent() - last_trade_time > 3600)
  {
      string reason = "";
      if (g_RiskManager.IsRiskOK(reason)) 
      {
          if (g_ExecGate.IsExecutionAllowed(reason)) 
          {
              Print("All checks passed. Ready to trade.");
              double sl_pips = g_ExecGate.GetStopLossPips(g_currentRegime);
              double lot = g_RiskManager.CalculateLotSize(AccountInfoDouble(ACCOUNT_BALANCE), InpBaseRiskPercent, sl_pips);
              
              // --- Placeholder for trade execution ---
              // ulong ticket = trade.Buy(...);
              // if(ticket > 0) {
              //    double initial_risk = ...;
              //    g_PosManager.AddNewPosition(ticket, initial_risk); // <<<--- РЕГИСТРАЦИЯ СДЕЛКИ
              // }
              
              last_trade_time = TimeCurrent();
          } else {
              Print("ExecGate Block: ", reason);
          }
      } else {
          Print("RiskManager Block: ", reason);
      }
  }
}
//+------------------------------------------------------------------+
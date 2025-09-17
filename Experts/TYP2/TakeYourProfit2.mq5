#property strict
#property description "Take Your Profit EA 2.0"
#property version   "2.1.0"

#include <Trade/Trade.mqh>

// ====== MODULES ======
#include "typ_core.mqh"
#include "typ_risk.mqh"
#include "typ_execfilters.mqh" // <--- НАШ НОВЫЙ МОДУЛЬ
// ... другие ваши #include ...
#include "typ_strategies.mqh"
#include "typ_be.mqh"
#include "typ_exit.mqh"
#include "typ_parental.mqh"


// ====== GLOBAL INPUTS ======
input int    Magic            = 68001;
input bool   DryRun           = true;
input ENUM_TIMEFRAMES TradeTF = PERIOD_M15;
// ... другие ваши глобальные input ...


// ====== STATE ======
CTrade trade;
datetime lastBar=0;

// ====== INIT/DEINIT ======
int OnInit()
{
  lastBar=iTime(_Symbol, TradeTF, 0);
  EquityGuard::OnNewDay();
  return(INIT_SUCCEEDED);
}
void OnDeinit(const int r){}

// ====== TRADE TRANSACTION HOOK ======
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &req,
                        const MqlTradeResult &res)
{
  // ... логика для PM hook ...
}

// ====== TICK ======
void OnTick()
{
  if(iTime(_Symbol, TradeTF, 0) == lastBar) return;
  lastBar=iTime(_Symbol, TradeTF, 0);

  // --- ШАГ 1: Проверка Глобальных Гвардов ---
  // TODO: Заменить "1.0" на реальный риск будущей сделки из модуля AutoLot
  if (!Risk_PortfolioGuardsOK(_Symbol, 0, 0, 1.0))
  {
    return; // Глобальные риски не позволяют торговать
  }
  
  // --- ШАГ 2: Сбор Сигналов-Кандидатов ---
  // ... здесь будет логика вызова DualMA_Probe, Triangle_Probe и т.д. ...
  // Для примера, создадим тестовый сигнал:
  SignalCandidate test_signal;
  test_signal.valid = true;
  test_signal.dir = 1; // LONG
  test_signal.entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  
  // --- ШАГ 3: Проверка Сигнала через ExecGate ---
  if (test_signal.valid)
  {
    if (ExecGate_PreOrder(_Symbol, TradeTF, test_signal.dir, test_signal.entry))
    {
      PrintFormat("[OK] Signal from %s passed ExecGate. Ready to send to Resolver.", "Test");
      // ... здесь сигнал отправляется в Resolver ...
    }
  }
  
  // --- ШАГ 4: Сопровождение открытых позиций ---
  // ... здесь будет вызов PositionManager ...

}
```=== END FILE ===

### **Команды для PowerShell (Выгрузка в GitHub)**

После того, как вы заменили содержимое файлов, выполните этот блок в PowerShell.

```powershell
# --- Пути ---
$Project = "C:\Users\User\Desktop\Take Your Profit 2"
Set-Location $Project

# --- Коммит и выгрузка ---
Write-Host "--- Выгружаем изменения для T2-005 в GitHub ---" -ForegroundColor Yellow
git add .
git commit -m "feat(T2-005): Finalize ExecGate logic and integration"
git push
Write-Host "Задача T2-005 успешно выгружена в dev-ветку." -ForegroundColor Cyan

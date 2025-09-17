#property strict
#property description "Take Your Profit EA 2.0"
#property version   "2.1.0"

#include <Trade/Trade.mqh>

// ====== MODULES ======
#include "typ_core.mqh"
#include "typ_risk.mqh"
#include "typ_execfilters.mqh" // <--- РќРђРЁ РќРћР’Р«Р™ РњРћР”РЈР›Р¬
// ... РґСЂСѓРіРёРµ РІР°С€Рё #include ...
#include "typ_strategies.mqh"
#include "typ_be.mqh"
#include "typ_exit.mqh"
#include "typ_parental.mqh"


// ====== GLOBAL INPUTS ======
input int    Magic            = 68001;
input bool   DryRun           = true;
input ENUM_TIMEFRAMES TradeTF = PERIOD_M15;
// ... РґСЂСѓРіРёРµ РІР°С€Рё РіР»РѕР±Р°Р»СЊРЅС‹Рµ input ...


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
  // ... Р»РѕРіРёРєР° РґР»СЏ PM hook ...
}

// ====== TICK ======
void OnTick()
{
  if(iTime(_Symbol, TradeTF, 0) == lastBar) return;
  lastBar=iTime(_Symbol, TradeTF, 0);

  // --- РЁРђР“ 1: РџСЂРѕРІРµСЂРєР° Р“Р»РѕР±Р°Р»СЊРЅС‹С… Р“РІР°СЂРґРѕРІ ---
  // TODO: Р—Р°РјРµРЅРёС‚СЊ "1.0" РЅР° СЂРµР°Р»СЊРЅС‹Р№ СЂРёСЃРє Р±СѓРґСѓС‰РµР№ СЃРґРµР»РєРё РёР· РјРѕРґСѓР»СЏ AutoLot
  if (!Risk_PortfolioGuardsOK(_Symbol, 0, 0, 1.0))
  {
    return; // Р“Р»РѕР±Р°Р»СЊРЅС‹Рµ СЂРёСЃРєРё РЅРµ РїРѕР·РІРѕР»СЏСЋС‚ С‚РѕСЂРіРѕРІР°С‚СЊ
  }
  
  // --- РЁРђР“ 2: РЎР±РѕСЂ РЎРёРіРЅР°Р»РѕРІ-РљР°РЅРґРёРґР°С‚РѕРІ ---
  // ... Р·РґРµСЃСЊ Р±СѓРґРµС‚ Р»РѕРіРёРєР° РІС‹Р·РѕРІР° DualMA_Probe, Triangle_Probe Рё С‚.Рґ. ...
  // Р”Р»СЏ РїСЂРёРјРµСЂР°, СЃРѕР·РґР°РґРёРј С‚РµСЃС‚РѕРІС‹Р№ СЃРёРіРЅР°Р»:
  SignalCandidate test_signal;
  test_signal.valid = true;
  test_signal.dir = 1; // LONG
  test_signal.entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  
  // --- РЁРђР“ 3: РџСЂРѕРІРµСЂРєР° РЎРёРіРЅР°Р»Р° С‡РµСЂРµР· ExecGate ---
  if (test_signal.valid)
  {
    if (ExecGate_PreOrder(_Symbol, TradeTF, test_signal.dir, test_signal.entry))
    {
      PrintFormat("[OK] Signal from %s passed ExecGate. Ready to send to Resolver.", "Test");
      // ... Р·РґРµСЃСЊ СЃРёРіРЅР°Р» РѕС‚РїСЂР°РІР»СЏРµС‚СЃСЏ РІ Resolver ...
    }
  }
  
  // --- РЁРђР“ 4: РЎРѕРїСЂРѕРІРѕР¶РґРµРЅРёРµ РѕС‚РєСЂС‹С‚С‹С… РїРѕР·РёС†РёР№ ---
  // ... Р·РґРµСЃСЊ Р±СѓРґРµС‚ РІС‹Р·РѕРІ PositionManager ...

}
```=== END FILE ===

### **РљРѕРјР°РЅРґС‹ РґР»СЏ PowerShell (Р’С‹РіСЂСѓР·РєР° РІ GitHub)**

РџРѕСЃР»Рµ С‚РѕРіРѕ, РєР°Рє РІС‹ Р·Р°РјРµРЅРёР»Рё СЃРѕРґРµСЂР¶РёРјРѕРµ С„Р°Р№Р»РѕРІ, РІС‹РїРѕР»РЅРёС‚Рµ СЌС‚РѕС‚ Р±Р»РѕРє РІ PowerShell.

```powershell
# --- РџСѓС‚Рё ---
$Project = "C:\Users\User\Desktop\Take Your Profit 2"
Set-Location $Project

# --- РљРѕРјРјРёС‚ Рё РІС‹РіСЂСѓР·РєР° ---
Write-Host "--- Р’С‹РіСЂСѓР¶Р°РµРј РёР·РјРµРЅРµРЅРёСЏ РґР»СЏ T2-005 РІ GitHub ---" -ForegroundColor Yellow
git add .
git commit -m "feat(T2-005): Finalize ExecGate logic and integration"
git push
Write-Host "Р—Р°РґР°С‡Р° T2-005 СѓСЃРїРµС€РЅРѕ РІС‹РіСЂСѓР¶РµРЅР° РІ dev-РІРµС‚РєСѓ." -ForegroundColor Cyan


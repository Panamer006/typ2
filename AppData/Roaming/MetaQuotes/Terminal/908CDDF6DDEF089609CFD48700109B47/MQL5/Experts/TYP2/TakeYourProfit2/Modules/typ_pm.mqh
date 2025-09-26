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
    
    // Инициализирует менеджер позиций с указателем на риск-менеджер
    void Initialize(CRiskManager* risk_manager) {
        m_risk_manager_ptr = risk_manager;
    }

    // Обновляет управление всеми позициями на каждом тике
    void OnTick(E_MarketRegime current_regime) {
        // TODO: В будущем здесь будет цикл по всем управляемым позициям
        // для вызова HandleBreakEven, HandleTakeProfit и т.д.
    }

    // Добавляет новую позицию под управление менеджера
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

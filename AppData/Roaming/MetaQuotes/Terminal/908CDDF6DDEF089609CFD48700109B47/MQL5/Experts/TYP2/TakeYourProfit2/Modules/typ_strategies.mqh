// --- typ_strategies.mqh ---
#ifndef TYP_STRATEGIES_MQH
#define TYP_STRATEGIES_MQH

#include "typ_patterns.mqh"
#include "typ_figures.mqh"
#include "typ_fibo.mqh"

// Структура для передачи сигналов-кандидатов
struct SignalCandidate {
    bool   isValid;
    string strategyID;
};

// Класс для стратегии "Ночной Возврат к Среднему"
class CStrategy_NightMR {
private:
    CPatterns* m_patterns; // Указатель на библиотеку паттернов
public:
    void Initialize(CPatterns* patterns_ptr) { m_patterns = patterns_ptr; }
    
    // Метод ищет сигнал и возвращает кандидата
    SignalCandidate GetSignal() const {
        SignalCandidate candidate;
        candidate.isValid = false;
        return candidate;
    }
};
#endif

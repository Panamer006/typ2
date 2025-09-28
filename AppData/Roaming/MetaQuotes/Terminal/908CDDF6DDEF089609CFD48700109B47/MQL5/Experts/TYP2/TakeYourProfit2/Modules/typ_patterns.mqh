// --- typ_patterns.mqh ---
#ifndef TYP_PATTERNS_MQH
#define TYP_PATTERNS_MQH
class CPatterns {
public:
    // Возвращает true, если на баре `shift` есть паттерн "Бычье поглощение"
    bool IsBullishEngulfing(const MqlRates &rates[], int shift) const { return false; }
    // Возвращает true, если на баре `shift` есть паттерн "Медвежье поглощение"
    bool IsBearishEngulfing(const MqlRates &rates[], int shift) const { return false; }
};
#endif



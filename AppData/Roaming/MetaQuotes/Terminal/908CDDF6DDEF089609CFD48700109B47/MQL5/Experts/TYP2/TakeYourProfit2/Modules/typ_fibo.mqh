// --- typ_fibo.mqh ---
#ifndef TYP_FIBO_MQH
#define TYP_FIBO_MQH
class CFibo {
public:
    // Возвращает true, если цена находится в "кластерной" зоне Фибо
    bool IsInFiboCluster(double price) const { return false; }
};
#endif

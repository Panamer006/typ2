// --- typ_chart_objects.mqh ---
#ifndef TYP_CHART_OBJECTS_MQH
#define TYP_CHART_OBJECTS_MQH

#include <Arrays/ArrayString.mqh> // <<<--- ИСПРАВЛЕНИЕ №1

// Класс для централизованного управления графическими объектами
class CChartObjectsManager {
private:
    long         m_chart_id;      // ID графика, на котором работаем
    string       m_object_prefix; // Уникальный префикс для всех наших объектов
    CArrayString m_object_names;  // Список имен всех объектов, созданных в текущем тике

public:
    // Конструктор
    CChartObjectsManager() : m_chart_id(0) {
        // <<<--- ИСПРАВЛЕНИЕ №2
        m_object_prefix = "TYP2_" + (string)ChartID() + "_"; 
    }
    
    // Деструктор
   ~CChartObjectsManager() {}

    // Инициализация
    void Initialize(long chart_id) {
        m_chart_id = chart_id;
    }

    // Должен вызываться в начале OnTick()
    void OnTickStart() {
        m_object_names.Clear();
    }
    
    // Должен вызываться в конце OnTick()
    void OnTickEnd() {
        int total = ObjectsTotal(m_chart_id, -1, -1);
        for (int i = total - 1; i >= 0; i--) {
            string name = ObjectName(m_chart_id, i, -1, -1);
            // Если объект наш, но его не было в этом тике - удаляем
            if (StringFind(name, m_object_prefix) == 0 && m_object_names.Search(name) < 0) {
                ObjectDelete(m_chart_id, name);
            }
        }
    }

    // --- Методы для отрисовки (пока заглушки) ---
    
    // Рисует текстовую метку
    void DrawLabel(string name, string text) {
        string full_name = m_object_prefix + name;
        // TODO: Добавить логику ObjectCreate для метки
        m_object_names.Add(full_name);
    }
    
    // Рисует прямоугольник
    void DrawRectangle(string name) {
        string full_name = m_object_prefix + name;
        // TODO: Добавить логику ObjectCreate для прямоугольника
        m_object_names.Add(full_name);
    }
};
#endif
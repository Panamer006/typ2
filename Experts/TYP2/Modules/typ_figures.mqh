// --- typ_figures.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Sprint 2 :: Chart Figures Detection Module
#property copyright "TYP2"

/**
 * @brief Структура для описания обнаруженной фигуры
 */
struct FigureInfo {
    bool    is_valid;           // Валидность фигуры
    string  figure_name;        // Название фигуры
    string  figure_type;        // Тип: "Reversal" или "Continuation"
    bool    is_formed;          // Сформирована ли фигура
    bool    is_broken;          // Пробита ли фигура
    double  breakout_price;     // Цена пробоя
    double  target_price;       // Целевая цена
    double  stop_price;         // Стоп цена
    int     direction;          // Направление ожидаемого движения (1=UP, -1=DOWN)
    double  reliability;        // Надежность фигуры (0.0-1.0)
    
    // Ключевые точки фигуры
    datetime key_times[10];     // Временные координаты ключевых точек
    double   key_prices[10];    // Ценовые координаты ключевых точек
    int      key_points_count;  // Количество ключевых точек
    
    FigureInfo() {
        is_valid = false;
        figure_name = "";
        figure_type = "";
        is_formed = false;
        is_broken = false;
        breakout_price = 0.0;
        target_price = 0.0;
        stop_price = 0.0;
        direction = 0;
        reliability = 0.0;
        key_points_count = 0;
        ArrayInitialize(key_times, 0);
        ArrayInitialize(key_prices, 0.0);
    }
};

/**
 * @brief Модуль детекции графических фигур
 * 
 * Предоставляет функциональность для автоматического распознавания
 * классических графических паттернов и фигур технического анализа.
 */
class CFigures {
public:
    /**
     * @brief Конструктор модуля фигур
     */
    CFigures() {}
    
    /**
     * @brief Деструктор модуля фигур
     */
    ~CFigures() {}
    
    // --- ФИГУРЫ РАЗВОРОТА ---
    
    /**
     * @brief Детекция фигуры "Голова и Плечи"
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @param figure_info Структура с подробной информацией о фигуре
     * @return true если обнаружена фигура "Голова и Плечи"
     */
    bool DetectHeadAndShoulders(const double &highs[], const double &lows[], int lookback, FigureInfo &figure_info) {
        if(ArraySize(highs) < lookback || ArraySize(lows) < lookback) return false;
        
        figure_info = FigureInfo(); // Сброс структуры
        
        // Ищем локальные максимумы для плеч и головы
        double peaks[50];
        int peak_indices[50];
        int peaks_found = FindLocalMaxima(highs, lookback, peaks, peak_indices);
        
        if(peaks_found < 3) return false;
        
        // Ищем паттерн: левое плечо - голова - правое плечо
        for(int i = 0; i < peaks_found - 2; i++) {
            double left_shoulder = peaks[i];
            double head = peaks[i + 1];
            double right_shoulder = peaks[i + 2];
            
            int left_idx = peak_indices[i];
            int head_idx = peak_indices[i + 1];
            int right_idx = peak_indices[i + 2];
            
            // 1. Голова должна быть выше плеч
            if(head <= left_shoulder || head <= right_shoulder) continue;
            
            // 2. Плечи должны быть примерно на одном уровне (допуск 5%)
            double shoulder_diff = MathAbs(left_shoulder - right_shoulder);
            double avg_shoulder = (left_shoulder + right_shoulder) / 2;
            if(shoulder_diff > avg_shoulder * 0.05) continue;
            
            // 3. Находим минимумы между плечами (линия шеи)
            double left_valley = DBL_MAX;
            double right_valley = DBL_MAX;
            int left_valley_idx = -1;
            int right_valley_idx = -1;
            
            // Левая впадина (между левым плечом и головой)
            for(int j = left_idx; j < head_idx; j++) {
                if(lows[j] < left_valley) {
                    left_valley = lows[j];
                    left_valley_idx = j;
                }
            }
            
            // Правая впадина (между головой и правым плечом)
            for(int j = head_idx; j < right_idx; j++) {
                if(lows[j] < right_valley) {
                    right_valley = lows[j];
                    right_valley_idx = j;
                }
            }
            
            if(left_valley_idx == -1 || right_valley_idx == -1) continue;
            
            // 4. Линия шеи должна быть примерно горизонтальной
            double neckline_slope = MathAbs(right_valley - left_valley);
            double head_height = head - MathMax(left_valley, right_valley);
            if(neckline_slope > head_height * 0.2) continue; // Наклон не более 20% от высоты
            
            // 5. Расчет целей и надежности
            double neckline_level = (left_valley + right_valley) / 2;
            double pattern_height = head - neckline_level;
            
            // Заполняем структуру фигуры
            figure_info.is_valid = true;
            figure_info.figure_name = "Head and Shoulders";
            figure_info.figure_type = "Reversal";
            figure_info.is_formed = true;
            figure_info.direction = -1; // Медвежья фигура
            figure_info.breakout_price = neckline_level;
            figure_info.target_price = neckline_level - pattern_height;
            figure_info.stop_price = head;
            
            // Ключевые точки
            figure_info.key_points_count = 5;
            figure_info.key_prices[0] = left_shoulder;  // Левое плечо
            figure_info.key_prices[1] = left_valley;    // Левая впадина
            figure_info.key_prices[2] = head;           // Голова
            figure_info.key_prices[3] = right_valley;   // Правая впадина
            figure_info.key_prices[4] = right_shoulder; // Правое плечо
            
            // Надежность на основе симметрии
            double symmetry = 1.0 - (shoulder_diff / avg_shoulder);
            double height_ratio = pattern_height / head;
            figure_info.reliability = (symmetry + height_ratio) / 2;
            
            return true;
        }
        
        return false;
    }
    
    /**
     * @brief Детекция фигуры "Обратная Голова и Плечи"
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @return true если обнаружена фигура "Обратная Голова и Плечи"
     * 
     * TODO: Реализовать логику детекции Inverse Head and Shoulders:
     * - Поиск трех последовательных впадин
     * - Центральная впадина (голова) ниже боковых (плечи)
     * - Примерно равные глубины плеч
     * - Линия шеи соединяет максимумы между плечами
     * - Пробой линии шеи как сигнал к покупке
     */
    bool DetectInverseHeadAndShoulders(const double &highs[], const double &lows[], int lookback = 50) {
        return false;
    }
    
    /**
     * @brief Детекция фигуры "Двойная Вершина/Дно"
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @param figure_info Структура с подробной информацией о фигуре
     * @param search_tops true для поиска двойной вершины, false для двойного дна
     * @return true если обнаружена фигура
     */
    bool DetectDoubleTopBottom(const double &highs[], const double &lows[], int lookback, FigureInfo &figure_info, bool search_tops = true) {
        if(ArraySize(highs) < lookback || ArraySize(lows) < lookback) return false;
        
        figure_info = FigureInfo();
        
        if(search_tops) {
            // Поиск двойной вершины
            double peaks[20];
            int peak_indices[20];
            int peaks_found = FindLocalMaxima(highs, lookback, peaks, peak_indices);
            
            if(peaks_found < 2) return false;
            
            for(int i = 0; i < peaks_found - 1; i++) {
                double first_peak = peaks[i];
                double second_peak = peaks[i + 1];
                int first_idx = peak_indices[i];
                int second_idx = peak_indices[i + 1];
                
                // Расстояние между пиками должно быть 10-50 баров
                int distance = second_idx - first_idx;
                if(distance < 10 || distance > 50) continue;
                
                // Пики должны быть на одинаковом уровне (допуск 2%)
                double price_diff = MathAbs(first_peak - second_peak);
                double avg_price = (first_peak + second_peak) / 2;
                if(price_diff > avg_price * 0.02) continue;
                
                // Находим минимум между пиками
                double valley = DBL_MAX;
                int valley_idx = -1;
                for(int j = first_idx; j < second_idx; j++) {
                    if(lows[j] < valley) {
                        valley = lows[j];
                        valley_idx = j;
                    }
                }
                
                // Минимум должен быть ниже пиков на 3-5%
                double retracement = (avg_price - valley) / avg_price;
                if(retracement < 0.03 || retracement > 0.15) continue;
                
                // Заполняем информацию о фигуре
                figure_info.is_valid = true;
                figure_info.figure_name = "Double Top";
                figure_info.figure_type = "Reversal";
                figure_info.is_formed = true;
                figure_info.direction = -1;
                figure_info.breakout_price = valley;
                figure_info.target_price = valley - (avg_price - valley);
                figure_info.stop_price = avg_price;
                figure_info.reliability = 1.0 - (price_diff / avg_price) - MathAbs(retracement - 0.05) * 2;
                
                figure_info.key_points_count = 3;
                figure_info.key_prices[0] = first_peak;
                figure_info.key_prices[1] = valley;
                figure_info.key_prices[2] = second_peak;
                
                return true;
            }
        } else {
            // Поиск двойного дна
            double valleys[20];
            int valley_indices[20];
            int valleys_found = FindLocalMinima(lows, lookback, valleys, valley_indices);
            
            if(valleys_found < 2) return false;
            
            for(int i = 0; i < valleys_found - 1; i++) {
                double first_valley = valleys[i];
                double second_valley = valleys[i + 1];
                int first_idx = valley_indices[i];
                int second_idx = valley_indices[i + 1];
                
                // Расстояние между впадинами должно быть 10-50 баров
                int distance = second_idx - first_idx;
                if(distance < 10 || distance > 50) continue;
                
                // Впадины должны быть на одинаковом уровне (допуск 2%)
                double price_diff = MathAbs(first_valley - second_valley);
                double avg_price = (first_valley + second_valley) / 2;
                if(price_diff > avg_price * 0.02) continue;
                
                // Находим максимум между впадинами
                double peak = 0;
                int peak_idx = -1;
                for(int j = first_idx; j < second_idx; j++) {
                    if(highs[j] > peak) {
                        peak = highs[j];
                        peak_idx = j;
                    }
                }
                
                // Максимум должен быть выше впадин на 3-5%
                double retracement = (peak - avg_price) / avg_price;
                if(retracement < 0.03 || retracement > 0.15) continue;
                
                // Заполняем информацию о фигуре
                figure_info.is_valid = true;
                figure_info.figure_name = "Double Bottom";
                figure_info.figure_type = "Reversal";
                figure_info.is_formed = true;
                figure_info.direction = 1;
                figure_info.breakout_price = peak;
                figure_info.target_price = peak + (peak - avg_price);
                figure_info.stop_price = avg_price;
                figure_info.reliability = 1.0 - (price_diff / avg_price) - MathAbs(retracement - 0.05) * 2;
                
                figure_info.key_points_count = 3;
                figure_info.key_prices[0] = first_valley;
                figure_info.key_prices[1] = peak;
                figure_info.key_prices[2] = second_valley;
                
                return true;
            }
        }
        
        return false;
    }
    
    /**
     * @brief Детекция фигуры "Тройная Вершина"
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @return true если обнаружена "Тройная Вершина"
     * 
     * TODO: Реализовать логику детекции Triple Top:
     * - Три максимума на примерно одинаковом уровне
     * - Минимумы между вершинами ниже на 3-5%
     * - Равномерные интервалы между вершинами
     */
    bool DetectTripleTop(const double &highs[], const double &lows[], int lookback = 50) {
        return false;
    }
    
    /**
     * @brief Детекция фигуры "Тройное Дно"
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @return true если обнаружено "Тройное Дно"
     */
    bool DetectTripleBottom(const double &highs[], const double &lows[], int lookback = 50) {
        return false;
    }
    
    // --- ТРЕУГОЛЬНЫЕ ФИГУРЫ ---
    
    /**
     * @brief Детекция "Восходящего Треугольника"
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @return true если обнаружен восходящий треугольник
     * 
     * TODO: Реализовать логику детекции Ascending Triangle:
     * - Горизонтальная линия сопротивления (одинаковые максимумы)
     * - Восходящая линия поддержки (растущие минимумы)
     * - Минимум 4 точки касания (2 на каждой линии)
     * - Сужающийся диапазон торговли
     */
    bool DetectAscendingTriangle(const double &highs[], const double &lows[], int lookback = 50) {
        return false;
    }
    
    /**
     * @brief Детекция "Нисходящего Треугольника"
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @return true если обнаружен нисходящий треугольник
     * 
     * TODO: Реализовать логику детекции Descending Triangle:
     * - Горизонтальная линия поддержки (одинаковые минимумы)
     * - Нисходящая линия сопротивления (убывающие максимумы)
     * - Минимум 4 точки касания
     */
    bool DetectDescendingTriangle(const double &highs[], const double &lows[], int lookback = 50) {
        return false;
    }
    
    /**
     * @brief Детекция "Симметричного Треугольника"
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @return true если обнаружен симметричный треугольник
     * 
     * TODO: Реализовать логику детекции Symmetrical Triangle:
     * - Нисходящая линия сопротивления
     * - Восходящая линия поддержки
     * - Схождение линий в одной точке
     * - Равномерное сужение диапазона
     */
    bool DetectSymmetricalTriangle(const double &highs[], const double &lows[], int lookback = 50) {
        return false;
    }
    
    // --- ФИГУРЫ ПРОДОЛЖЕНИЯ ---
    
    /**
     * @brief Детекция фигуры "Флаг"
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @return true если обнаружен флаг
     * 
     * TODO: Реализовать логику детекции Flag:
     * - Сильное движение (флагшток)
     * - Консолидация в узком диапазоне (флаг)
     * - Флаг направлен против основного тренда
     * - Пробой флага в направлении тренда
     */
    bool DetectFlag(const double &highs[], const double &lows[], int lookback = 30) {
        return false;
    }
    
    /**
     * @brief Детекция фигуры "Вымпел"
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @return true если обнаружен вымпел
     * 
     * TODO: Реализовать логику детекции Pennant:
     * - Сильное движение (флагшток)
     * - Консолидация в виде маленького треугольника
     * - Схождение линий поддержки и сопротивления
     * - Пробой в направлении основного тренда
     */
    bool DetectPennant(const double &highs[], const double &lows[], int lookback = 30) {
        return false;
    }
    
    /**
     * @brief Детекция фигуры "Прямоугольник" (Range)
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @return true если обнаружен прямоугольник
     * 
     * TODO: Реализовать логику детекции Rectangle:
     * - Горизонтальная линия сопротивления
     * - Горизонтальная линия поддержки
     * - Параллельные линии
     * - Минимум 4 касания (по 2 на каждой линии)
     */
    bool DetectRectangle(const double &highs[], const double &lows[], int lookback = 50) {
        return false;
    }
    
    // --- КРИТИЧЕСКИ ВАЖНЫЕ ФИГУРЫ (КЛИН, ФЛАГ, ТРЕУГОЛЬНИК, ПРЯМОУГОЛЬНИК) ---
    
    /**
     * @brief Детекция фигуры "Клин" (Wedge)
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @param figure_info Структура с информацией о фигуре
     * @return true если обнаружен клин
     */
    bool DetectWedge(const double &highs[], const double &lows[], int lookback, FigureInfo &figure_info) {
        if(ArraySize(highs) < lookback) return false;
        
        figure_info = FigureInfo();
        
        // Найдем линии тренда для максимумов и минимумов
        double upper_slope, lower_slope;
        double upper_start, lower_start;
        
        if(!CalculateTrendLine(highs, lookback/2, upper_slope, upper_start) ||
           !CalculateTrendLine(lows, lookback/2, lower_slope, lower_start)) return false;
        
        // Проверяем схождение линий (клин)
        bool is_wedge = false;
        bool is_rising = false;
        
        if(upper_slope < 0 && lower_slope < 0 && lower_slope < upper_slope) {
            // Нисходящий клин (бычий)
            is_wedge = true;
            is_rising = false;
        } else if(upper_slope > 0 && lower_slope > 0 && upper_slope < lower_slope) {
            // Восходящий клин (медвежий)
            is_wedge = true;
            is_rising = true;
        }
        
        if(is_wedge) {
            figure_info.is_valid = true;
            figure_info.figure_name = is_rising ? "Rising Wedge" : "Falling Wedge";
            figure_info.figure_type = "Reversal";
            figure_info.direction = is_rising ? -1 : 1;
            figure_info.reliability = 0.7;
            return true;
        }
        
        return false;
    }
    
    /**
     * @brief Детекция фигуры "Флаг" (Flag)
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @param figure_info Структура с информацией о фигуре
     * @return true если обнаружен флаг
     */
    bool DetectFlag(const double &highs[], const double &lows[], int lookback, FigureInfo &figure_info) {
        if(ArraySize(highs) < lookback) return false;
        
        figure_info = FigureInfo();
        
        // Ищем сильное движение (флагшток) + консолидацию
        double range_start = highs[lookback-10];
        double range_end = highs[5];
        double movement = MathAbs(range_end - range_start);
        
        // Проверяем консолидацию в последних 10 барах
        double consolidation_range = 0;
        for(int i = 0; i < 10; i++) {
            consolidation_range += highs[i] - lows[i];
        }
        consolidation_range /= 10;
        
        if(movement > consolidation_range * 5) {
            figure_info.is_valid = true;
            figure_info.figure_name = "Flag";
            figure_info.figure_type = "Continuation";
            figure_info.direction = (range_end > range_start) ? 1 : -1;
            figure_info.reliability = 0.75;
            return true;
        }
        
        return false;
    }
    
    /**
     * @brief Детекция фигуры "Треугольник" (Triangle)
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @param figure_info Структура с информацией о фигуре
     * @return true если обнаружен треугольник
     */
    bool DetectTriangle(const double &highs[], const double &lows[], int lookback, FigureInfo &figure_info) {
        if(ArraySize(highs) < lookback) return false;
        
        figure_info = FigureInfo();
        
        // Рассчитываем линии тренда
        double upper_slope, lower_slope;
        double upper_start, lower_start;
        
        if(!CalculateTrendLine(highs, lookback, upper_slope, upper_start) ||
           !CalculateTrendLine(lows, lookback, lower_slope, lower_start)) return false;
        
        // Определяем тип треугольника
        string triangle_type = "";
        if(upper_slope < -0.0001 && lower_slope > 0.0001) {
            triangle_type = "Symmetrical Triangle";
        } else if(MathAbs(upper_slope) < 0.0001 && lower_slope > 0.0001) {
            triangle_type = "Ascending Triangle";
        } else if(upper_slope < -0.0001 && MathAbs(lower_slope) < 0.0001) {
            triangle_type = "Descending Triangle";
        }
        
        if(triangle_type != "") {
            figure_info.is_valid = true;
            figure_info.figure_name = triangle_type;
            figure_info.figure_type = "Continuation";
            figure_info.reliability = 0.65;
            return true;
        }
        
        return false;
    }
    
    /**
     * @brief Детекция фигуры "Прямоугольник" (Rectangle)
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @param figure_info Структура с информацией о фигуре
     * @return true если обнаружен прямоугольник
     */
    bool DetectRectangle(const double &highs[], const double &lows[], int lookback, FigureInfo &figure_info) {
        if(ArraySize(highs) < lookback) return false;
        
        figure_info = FigureInfo();
        
        // Найдем уровни поддержки и сопротивления
        double resistance_level = 0;
        double support_level = DBL_MAX;
        
        for(int i = 0; i < lookback; i++) {
            if(highs[i] > resistance_level) resistance_level = highs[i];
            if(lows[i] < support_level) support_level = lows[i];
        }
        
        // Проверяем, что цена касается уровней минимум 2 раза каждого
        int resistance_touches = 0;
        int support_touches = 0;
        double tolerance = (resistance_level - support_level) * 0.02;
        
        for(int i = 0; i < lookback; i++) {
            if(MathAbs(highs[i] - resistance_level) <= tolerance) resistance_touches++;
            if(MathAbs(lows[i] - support_level) <= tolerance) support_touches++;
        }
        
        if(resistance_touches >= 2 && support_touches >= 2) {
            double range_size = resistance_level - support_level;
            if(range_size > 0) {
                figure_info.is_valid = true;
                figure_info.figure_name = "Rectangle";
                figure_info.figure_type = "Continuation";
                figure_info.breakout_price = resistance_level;
                figure_info.target_price = resistance_level + range_size;
                figure_info.stop_price = support_level;
                figure_info.reliability = 0.6;
                return true;
            }
        }
        
        return false;
    }
    
    // --- КОМБИНИРОВАННЫЕ МЕТОДЫ ---
    
    /**
     * @brief Поиск любой фигуры разворота
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @param figure_name Имя найденной фигуры (выходной параметр)
     * @return true если найдена фигура разворота
     */
    bool FindAnyReversalFigure(const double &highs[], const double &lows[], int lookback, string &figure_name) {
        // TODO: Последовательно проверить все фигуры разворота
        figure_name = "None";
        return false;
    }
    
    /**
     * @brief Поиск любой фигуры продолжения
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период поиска
     * @param figure_name Имя найденной фигуры (выходной параметр)
     * @return true если найдена фигура продолжения
     */
    bool FindAnyContinuationFigure(const double &highs[], const double &lows[], int lookback, string &figure_name) {
        // TODO: Последовательно проверить все фигуры продолжения
        figure_name = "None";
        return false;
    }
    
    /**
     * @brief Расчет надежности найденной фигуры
     * @param figure_name Имя фигуры для анализа
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @param lookback Период анализа
     * @return Надежность фигуры от 0.0 (ненадежная) до 1.0 (очень надежная)
     * 
     * TODO: Реализовать scoring систему на основе:
     * - Качества линий поддержки/сопротивления
     * - Количества точек касания
     * - Объемов при формировании фигуры
     * - Соответствия классическим пропорциям
     */
    double GetFigureReliability(const string figure_name, const double &highs[], const double &lows[], int lookback) {
        return 0.5; // Нейтральная надежность по умолчанию
    }
    
    /**
     * @brief Определение цели движения после пробоя фигуры
     * @param figure_name Имя фигуры
     * @param breakout_price Цена пробоя
     * @param highs Массив максимумов
     * @param lows Массив минимумов
     * @return Целевая цена движения
     * 
     * TODO: Реализовать расчет целей на основе:
     * - Высоты фигуры
     * - Типа фигуры (разворот/продолжение)
     * - Классических соотношений
     */
    double CalculateTarget(const string figure_name, double breakout_price, const double &highs[], const double &lows[]) {
        return breakout_price; // Заглушка - возвращает цену пробоя
    }
    
private:
    // --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ---
    
    /**
     * @brief Поиск локальных максимумов
     * @param prices Массив цен
     * @param window Окно поиска
     * @param peaks Массив найденных пиков
     * @param peak_indices Массив индексов пиков
     * @return Количество найденных пиков
     */
    int FindLocalMaxima(const double &prices[], int window, double &peaks[], int &peak_indices[]) {
        int peaks_count = 0;
        int lookback_window = 3; // Окно для поиска локальных максимумов
        
        for(int i = lookback_window; i < window - lookback_window && peaks_count < 50; i++) {
            bool is_peak = true;
            
            // Проверяем, что текущая точка выше всех соседних
            for(int j = i - lookback_window; j <= i + lookback_window; j++) {
                if(j != i && prices[j] >= prices[i]) {
                    is_peak = false;
                    break;
                }
            }
            
            if(is_peak) {
                peaks[peaks_count] = prices[i];
                peak_indices[peaks_count] = i;
                peaks_count++;
            }
        }
        
        return peaks_count;
    }
    
    /**
     * @brief Поиск локальных минимумов
     * @param prices Массив цен
     * @param window Окно поиска
     * @param valleys Массив найденных впадин
     * @param valley_indices Массив индексов впадин
     * @return Количество найденных впадин
     */
    int FindLocalMinima(const double &prices[], int window, double &valleys[], int &valley_indices[]) {
        int valleys_count = 0;
        int lookback_window = 3;
        
        for(int i = lookback_window; i < window - lookback_window && valleys_count < 50; i++) {
            bool is_valley = true;
            
            // Проверяем, что текущая точка ниже всех соседних
            for(int j = i - lookback_window; j <= i + lookback_window; j++) {
                if(j != i && prices[j] <= prices[i]) {
                    is_valley = false;
                    break;
                }
            }
            
            if(is_valley) {
                valleys[valleys_count] = prices[i];
                valley_indices[valleys_count] = i;
                valleys_count++;
            }
        }
        
        return valleys_count;
    }
    
    /**
     * @brief Расчет линии тренда методом наименьших квадратов
     * @param prices Массив цен
     * @param window Период расчета
     * @param slope Угол наклона (выходной параметр)
     * @param intercept Y-перехват (выходной параметр)
     * @return true если расчет успешен
     */
    bool CalculateTrendLine(const double &prices[], int window, double &slope, double &intercept) {
        if(window < 2) return false;
        
        double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
        
        for(int i = 0; i < window; i++) {
            sum_x += i;
            sum_y += prices[i];
            sum_xy += i * prices[i];
            sum_x2 += i * i;
        }
        
        double n = window;
        double denominator = n * sum_x2 - sum_x * sum_x;
        
        if(MathAbs(denominator) < 1e-10) return false;
        
        slope = (n * sum_xy - sum_x * sum_y) / denominator;
        intercept = (sum_y - slope * sum_x) / n;
        
        return true;
    }
    
    /**
     * @brief Визуальный слой - отрисовка фигур на графике
     * @param figure_info Информация о фигуре
     * @param chart_id ID графика
     */
    void DrawFigure(const FigureInfo &figure_info, long chart_id = 0) const {
        if(!figure_info.is_valid) return;
        
        string figure_prefix = StringFormat("Figure_%s_%d", figure_info.figure_name, GetTickCount());
        
        // Отрисовываем ключевые точки
        for(int i = 0; i < figure_info.key_points_count; i++) {
            string point_name = figure_prefix + "_point_" + IntegerToString(i);
            ObjectDelete(chart_id, point_name);
            
            if(ObjectCreate(chart_id, point_name, OBJ_ARROW, 0, figure_info.key_times[i], figure_info.key_prices[i])) {
                ObjectSetInteger(chart_id, point_name, OBJPROP_ARROWCODE, 159);
                ObjectSetInteger(chart_id, point_name, OBJPROP_COLOR, clrBlue);
                ObjectSetInteger(chart_id, point_name, OBJPROP_WIDTH, 2);
            }
        }
        
        // Добавляем текстовую метку
        string label_name = figure_prefix + "_label";
        ObjectDelete(chart_id, label_name);
        
        if(figure_info.key_points_count > 0) {
            datetime label_time = figure_info.key_times[0];
            double label_price = figure_info.key_prices[0];
            
            if(ObjectCreate(chart_id, label_name, OBJ_TEXT, 0, label_time, label_price)) {
                string direction_text = (figure_info.direction > 0) ? "BULLISH" : (figure_info.direction < 0) ? "BEARISH" : "NEUTRAL";
                string label_text = StringFormat("%s %s (%.1f%%)", figure_info.figure_name, direction_text, figure_info.reliability * 100);
                ObjectSetString(chart_id, label_name, OBJPROP_TEXT, label_text);
                ObjectSetInteger(chart_id, label_name, OBJPROP_COLOR, (figure_info.figure_type == "Reversal") ? clrOrange : clrCyan);
                ObjectSetInteger(chart_id, label_name, OBJPROP_FONTSIZE, 9);
            }
        }
    }
    
    /**
     * @brief Построение линии тренда по двум точкам
     * @param x1 X-координата первой точки
     * @param y1 Y-координата первой точки
     * @param x2 X-координата второй точки
     * @param y2 Y-координата второй точки
     * @param x Точка для расчета Y
     * @return Y-значение линии тренда в точке x
     */
    double GetTrendLineValue(int x1, double y1, int x2, double y2, int x) {
        if(x1 == x2) return y1; // Вертикальная линия
        
        double slope = (y2 - y1) / (x2 - x1);
        return y1 + slope * (x - x1);
    }
    
    /**
     * @brief Проверка качества линии поддержки/сопротивления
     * @param line_points Точки касания линии
     * @param prices Массив цен для проверки
     * @return Качество линии от 0.0 до 1.0
     */
    double CalculateLineQuality(const double &line_points[], const double &prices[]) {
        // TODO: Реализовать оценку качества линии на основе:
        // - Количества точек касания
        // - Точности касаний (отклонения от линии)
        // - Равномерности распределения точек
        return 0.5;
    }
    
    /**
     * @brief Расчет угла наклона линии тренда
     * @param x1 X-координата первой точки
     * @param y1 Y-координата первой точки
     * @param x2 X-координата второй точки
     * @param y2 Y-координата второй точки
     * @return Угол наклона в градусах
     */
    double CalculateAngle(int x1, double y1, int x2, double y2) {
        if(x1 == x2) return 90.0; // Вертикальная линия
        
        double slope = (y2 - y1) / (x2 - x1);
        return MathArctan(slope) * 180.0 / M_PI;
    }
    
    // === РАСШИРЕННЫЕ МЕТОДЫ ВИЗУАЛИЗАЦИИ ===
    
    /**
     * @brief Визуализация фигуры с расширенными возможностями
     * @param figure_info Информация о фигуре
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     */
    void DrawFigureAdvanced(const FigureInfo &figure_info, long chart_id, const MqlRates &rates[]) const {
        if(figure_info.figure_name == "None") return;
        
        // Определяем цвет в зависимости от надежности
        color figure_color;
        if(figure_info.reliability > 0.8) figure_color = clrLime;
        else if(figure_info.reliability > 0.6) figure_color = clrGreen;
        else if(figure_info.reliability > 0.4) figure_color = clrYellow;
        else figure_color = clrOrange;
        
        // Рисуем основную фигуру
        DrawFigure(figure_info, chart_id, rates);
        
        // Добавляем расширенную информацию
        string info_name = StringFormat("Figure_Info_%s_%d", figure_info.figure_name, (int)TimeCurrent());
        ObjectDelete(chart_id, info_name);
        
        if(ObjectCreate(chart_id, info_name, OBJ_TEXT, 0, figure_info.breakout_time, figure_info.breakout_price)) {
            ObjectSetString(chart_id, info_name, OBJPROP_TEXT, 
                          StringFormat("%s (%.1f%%) | Target: %.5f", 
                                     figure_info.figure_name, 
                                     figure_info.reliability * 100,
                                     figure_info.target_price));
            ObjectSetInteger(chart_id, info_name, OBJPROP_COLOR, figure_color);
            ObjectSetInteger(chart_id, info_name, OBJPROP_FONTSIZE, 9);
            ObjectSetInteger(chart_id, info_name, OBJPROP_ANCHOR, ANCHOR_LOWER);
        }
    }
    
    /**
     * @brief Визуализация фигуры с зоной влияния
     * @param figure_info Информация о фигуре
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     * @param influence_bars Количество баров зоны влияния
     */
    void DrawFigureWithInfluence(const FigureInfo &figure_info, long chart_id, 
                                const MqlRates &rates[], int influence_bars = 10) const {
        if(figure_info.figure_name == "None") return;
        
        // Рисуем основную фигуру
        DrawFigure(figure_info, chart_id, rates);
        
        // Определяем цвет зоны влияния
        color zone_color = (figure_info.reliability > 0.6) ? C'0,255,0,30' : C'255,165,0,30';
        
        string zone_name = StringFormat("Figure_Zone_%s_%d", figure_info.figure_name, (int)TimeCurrent());
        ObjectDelete(chart_id, zone_name);
        
        // Находим экстремумы в зоне влияния
        double high_price = figure_info.breakout_price;
        double low_price = figure_info.breakout_price;
        
        for(int i = 0; i < MathMin(influence_bars, ArraySize(rates)); i++) {
            if(rates[i].high > high_price) high_price = rates[i].high;
            if(rates[i].low < low_price) low_price = rates[i].low;
        }
        
        datetime start_time = figure_info.breakout_time;
        datetime end_time = (influence_bars < ArraySize(rates)) ? 
                           rates[influence_bars].time : rates[ArraySize(rates)-1].time;
        
        if(ObjectCreate(chart_id, zone_name, OBJ_RECTANGLE, 0, start_time, high_price, end_time, low_price)) {
            ObjectSetInteger(chart_id, zone_name, OBJPROP_COLOR, zone_color);
            ObjectSetInteger(chart_id, zone_name, OBJPROP_FILL, true);
            ObjectSetInteger(chart_id, zone_name, OBJPROP_BACK, true);
            ObjectSetInteger(chart_id, zone_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(chart_id, zone_name, OBJPROP_WIDTH, 1);
        }
    }
    
    /**
     * @brief Визуализация фигуры с целевыми уровнями
     * @param figure_info Информация о фигуре
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     * @param target_levels Массив целевых уровней
     * @param target_count Количество целевых уровней
     */
    void DrawFigureWithTargets(const FigureInfo &figure_info, long chart_id, 
                              const MqlRates &rates[], const double &target_levels[], int target_count) const {
        if(figure_info.figure_name == "None" || target_count <= 0) return;
        
        // Рисуем основную фигуру
        DrawFigure(figure_info, chart_id, rates);
        
        // Определяем цвет целей
        color target_color = (figure_info.reliability > 0.6) ? clrDodgerBlue : clrSteelBlue;
        
        // Рисуем целевые уровни
        for(int i = 0; i < target_count; i++) {
            string target_name = StringFormat("Figure_Target_%s_%d_%d", figure_info.figure_name, i, (int)TimeCurrent());
            ObjectDelete(chart_id, target_name);
            
            if(ObjectCreate(chart_id, target_name, OBJ_HLINE, 0, 0, target_levels[i])) {
                ObjectSetInteger(chart_id, target_name, OBJPROP_COLOR, target_color);
                ObjectSetInteger(chart_id, target_name, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(chart_id, target_name, OBJPROP_WIDTH, 2);
                ObjectSetString(chart_id, target_name, OBJPROP_TEXT, 
                              StringFormat("Target %d: %.5f", i+1, target_levels[i]));
            }
        }
    }
    
    /**
     * @brief Визуализация фигуры с уровнями поддержки/сопротивления
     * @param figure_info Информация о фигуре
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     * @param support_levels Массив уровней поддержки
     * @param resistance_levels Массив уровней сопротивления
     * @param support_count Количество уровней поддержки
     * @param resistance_count Количество уровней сопротивления
     */
    void DrawFigureWithLevels(const FigureInfo &figure_info, long chart_id, 
                             const MqlRates &rates[], 
                             const double &support_levels[], const double &resistance_levels[],
                             int support_count, int resistance_count) const {
        if(figure_info.figure_name == "None") return;
        
        // Рисуем основную фигуру
        DrawFigure(figure_info, chart_id, rates);
        
        // Определяем цвет уровней
        color support_color = clrBlue;
        color resistance_color = clrRed;
        
        // Рисуем уровни поддержки
        for(int i = 0; i < support_count; i++) {
            string support_name = StringFormat("Figure_Support_%s_%d_%d", figure_info.figure_name, i, (int)TimeCurrent());
            ObjectDelete(chart_id, support_name);
            
            if(ObjectCreate(chart_id, support_name, OBJ_HLINE, 0, 0, support_levels[i])) {
                ObjectSetInteger(chart_id, support_name, OBJPROP_COLOR, support_color);
                ObjectSetInteger(chart_id, support_name, OBJPROP_STYLE, STYLE_DASH);
                ObjectSetInteger(chart_id, support_name, OBJPROP_WIDTH, 2);
                ObjectSetString(chart_id, support_name, OBJPROP_TEXT, 
                              StringFormat("Support %d: %.5f", i+1, support_levels[i]));
            }
        }
        
        // Рисуем уровни сопротивления
        for(int i = 0; i < resistance_count; i++) {
            string resistance_name = StringFormat("Figure_Resistance_%s_%d_%d", figure_info.figure_name, i, (int)TimeCurrent());
            ObjectDelete(chart_id, resistance_name);
            
            if(ObjectCreate(chart_id, resistance_name, OBJ_HLINE, 0, 0, resistance_levels[i])) {
                ObjectSetInteger(chart_id, resistance_name, OBJPROP_COLOR, resistance_color);
                ObjectSetInteger(chart_id, resistance_name, OBJPROP_STYLE, STYLE_DASH);
                ObjectSetInteger(chart_id, resistance_name, OBJPROP_WIDTH, 2);
                ObjectSetString(chart_id, resistance_name, OBJPROP_TEXT, 
                              StringFormat("Resistance %d: %.5f", i+1, resistance_levels[i]));
            }
        }
    }
    
    /**
     * @brief Визуализация фигуры с линиями тренда
     * @param figure_info Информация о фигуре
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     * @param trend_lines Массив структур линий тренда
     * @param line_count Количество линий тренда
     */
    void DrawFigureWithTrendLines(const FigureInfo &figure_info, long chart_id, 
                                 const MqlRates &rates[], const TrendLine &trend_lines[], int line_count) const {
        if(figure_info.figure_name == "None" || line_count <= 0) return;
        
        // Рисуем основную фигуру
        DrawFigure(figure_info, chart_id, rates);
        
        // Рисуем линии тренда
        for(int i = 0; i < line_count; i++) {
            string line_name = StringFormat("Figure_TrendLine_%s_%d_%d", figure_info.figure_name, i, (int)TimeCurrent());
            ObjectDelete(chart_id, line_name);
            
            if(ObjectCreate(chart_id, line_name, OBJ_TREND, 0, 
                           trend_lines[i].start_time, trend_lines[i].start_price,
                           trend_lines[i].end_time, trend_lines[i].end_price)) {
                ObjectSetInteger(chart_id, line_name, OBJPROP_COLOR, trend_lines[i].color);
                ObjectSetInteger(chart_id, line_name, OBJPROP_STYLE, trend_lines[i].style);
                ObjectSetInteger(chart_id, line_name, OBJPROP_WIDTH, trend_lines[i].width);
                ObjectSetInteger(chart_id, line_name, OBJPROP_RAY_RIGHT, true);
                ObjectSetString(chart_id, line_name, OBJPROP_TEXT, 
                              StringFormat("Trend Line %d", i+1));
            }
        }
    }
    
    /**
     * @brief Визуализация фигуры с анимацией
     * @param figure_info Информация о фигуре
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     * @param animation_speed Скорость анимации (мс)
     */
    void DrawFigureWithAnimation(const FigureInfo &figure_info, long chart_id, 
                                const MqlRates &rates[], int animation_speed = 1000) const {
        if(figure_info.figure_name == "None") return;
        
        // Создаем анимированную стрелку
        string arrow_name = StringFormat("Figure_Animated_%s_%d", figure_info.figure_name, (int)TimeCurrent());
        ObjectDelete(chart_id, arrow_name);
        
        if(ObjectCreate(chart_id, arrow_name, OBJ_ARROW, 0, figure_info.breakout_time, figure_info.breakout_price)) {
            ObjectSetInteger(chart_id, arrow_name, OBJPROP_ARROWCODE, 233);
            ObjectSetInteger(chart_id, arrow_name, OBJPROP_COLOR, clrYellow);
            ObjectSetInteger(chart_id, arrow_name, OBJPROP_WIDTH, 5);
            
            // Добавляем мигающий эффект
            ObjectSetInteger(chart_id, arrow_name, OBJPROP_BACK, false);
        }
        
        // Рисуем основную фигуру
        DrawFigure(figure_info, chart_id, rates);
    }
    
    /**
     * @brief Очистка всех объектов визуализации фигур
     * @param chart_id ID графика
     */
    void ClearFigureVisualization(long chart_id) const {
        int total_objects = ObjectsTotal(chart_id);
        for(int i = total_objects - 1; i >= 0; i--) {
            string obj_name = ObjectName(chart_id, i);
            if(StringFind(obj_name, "Figure_") == 0) {
                ObjectDelete(chart_id, obj_name);
            }
        }
    }
};

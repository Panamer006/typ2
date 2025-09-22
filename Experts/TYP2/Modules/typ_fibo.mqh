// --- typ_fibo.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Sprint 2 :: Fibonacci Analysis Module with Full Visualization
#property copyright "TYP2"

/**
 * @brief Структура для хранения информации о Фибоначчи уровне
 */
struct FiboLevel {
    double price;           // Цена уровня
    double percentage;      // Процент Фибоначчи
    string level_name;      // Название уровня
    color level_color;      // Цвет для визуализации
    int line_style;         // Стиль линии
    int line_width;         // Толщина линии
    bool is_strong;         // Сильный уровень
    int confluence_count;   // Количество совпадений
    
    FiboLevel() {
        price = 0.0;
        percentage = 0.0;
        level_name = "";
        level_color = clrGray;
        line_style = STYLE_DOT;
        line_width = 1;
        is_strong = false;
        confluence_count = 0;
    }
};

/**
 * @brief Структура для хранения информации о Фибоначчи сетке
 */
struct FiboGrid {
    double swing_high;      // Максимум свинга
    double swing_low;       // Минимум свинга
    datetime high_time;     // Время максимума
    datetime low_time;      // Время минимума
    FiboLevel levels[20];   // Массив уровней
    int level_count;        // Количество уровней
    bool is_valid;          // Валидность сетки
    
    FiboGrid() {
        swing_high = 0.0;
        swing_low = 0.0;
        high_time = 0;
        low_time = 0;
        level_count = 0;
        is_valid = false;
    }
};

/**
 * @brief Модуль анализа уровней Фибоначчи с полной визуализацией
 */
class CFibo {
private:
    double m_retracement_levels[5];
    double m_extension_levels[4];
    string m_level_names[9];
    color m_level_colors[9];
    int m_min_swing_bars;
    double m_min_swing_pips;
    int m_lookback_period;
    double m_confluence_tolerance;
    
public:
    CFibo() : m_min_swing_bars(5),
              m_min_swing_pips(20.0),
              m_lookback_period(100),
              m_confluence_tolerance(5.0)
    {
        m_retracement_levels[0] = 23.6;
        m_retracement_levels[1] = 38.2;
        m_retracement_levels[2] = 50.0;
        m_retracement_levels[3] = 61.8;
        m_retracement_levels[4] = 78.6;
        
        m_extension_levels[0] = 127.2;
        m_extension_levels[1] = 161.8;
        m_extension_levels[2] = 200.0;
        m_extension_levels[3] = 261.8;
        
        m_level_names[0] = "23.6% Ret";
        m_level_names[1] = "38.2% Ret";
        m_level_names[2] = "50.0% Ret";
        m_level_names[3] = "61.8% Ret";
        m_level_names[4] = "78.6% Ret";
        m_level_names[5] = "127.2% Ext";
        m_level_names[6] = "161.8% Ext";
        m_level_names[7] = "200.0% Ext";
        m_level_names[8] = "261.8% Ext";
        
        m_level_colors[0] = clrLightBlue;
        m_level_colors[1] = clrBlue;
        m_level_colors[2] = clrDodgerBlue;
        m_level_colors[3] = clrSteelBlue;
        m_level_colors[4] = clrDarkBlue;
        m_level_colors[5] = clrOrange;
        m_level_colors[6] = clrRed;
        m_level_colors[7] = clrCrimson;
        m_level_colors[8] = clrDarkRed;
    }
    
    ~CFibo() {}
    
    bool FindSignificantSwing(const string symbol, ENUM_TIMEFRAMES timeframe,
                             double &swing_high, double &swing_low,
                             datetime &high_time, datetime &low_time) {
        MqlRates rates[200];
        if(CopyRates(symbol, timeframe, 0, m_lookback_period, rates) < m_lookback_period) {
            return false;
        }
        
        double max_high = 0, min_low = DBL_MAX;
        int max_index = -1, min_index = -1;
        
        for(int i = m_min_swing_bars; i < m_lookback_period - m_min_swing_bars; i++) {
            bool is_local_high = true, is_local_low = true;
            
            for(int j = i - m_min_swing_bars; j <= i + m_min_swing_bars; j++) {
                if(j != i && rates[j].high >= rates[i].high) {
                    is_local_high = false;
                    break;
                }
            }
            
            for(int j = i - m_min_swing_bars; j <= i + m_min_swing_bars; j++) {
                if(j != i && rates[j].low <= rates[i].low) {
                    is_local_low = false;
                    break;
                }
            }
            
            if(is_local_high && rates[i].high > max_high) {
                max_high = rates[i].high;
                max_index = i;
            }
            
            if(is_local_low && rates[i].low < min_low) {
                min_low = rates[i].low;
                min_index = i;
            }
        }
        
        if(max_index == -1 || min_index == -1) return false;
        
        double swing_range = max_high - min_low;
        double min_range = m_min_swing_pips * _Point;
        
        if(swing_range < min_range) return false;
        
        if(max_index < min_index) {
            swing_low = min_low;
            swing_high = max_high;
            low_time = rates[min_index].time;
            high_time = rates[max_index].time;
        } else {
            swing_high = max_high;
            swing_low = min_low;
            high_time = rates[max_index].time;
            low_time = rates[min_index].time;
        }
        
        return true;
    }
    
    bool BuildFiboGrid(const string symbol, ENUM_TIMEFRAMES timeframe, FiboGrid &fibo_grid) {
        if(!FindSignificantSwing(symbol, timeframe, fibo_grid.swing_high, fibo_grid.swing_low,
                                fibo_grid.high_time, fibo_grid.low_time)) {
            return false;
        }
        
        double swing_range = fibo_grid.swing_high - fibo_grid.swing_low;
        int level_index = 0;
        
        for(int i = 0; i < 5; i++) {
            double fibo_price = fibo_grid.swing_low + (swing_range * m_retracement_levels[i] / 100.0);
            
            fibo_grid.levels[level_index].price = fibo_price;
            fibo_grid.levels[level_index].percentage = m_retracement_levels[i];
            fibo_grid.levels[level_index].level_name = m_level_names[i];
            fibo_grid.levels[level_index].level_color = m_level_colors[i];
            fibo_grid.levels[level_index].line_style = STYLE_DASH;
            fibo_grid.levels[level_index].line_width = 1;
            fibo_grid.levels[level_index].is_strong = (m_retracement_levels[i] == 50.0 || m_retracement_levels[i] == 61.8);
            fibo_grid.levels[level_index].confluence_count = 0;
            
            level_index++;
        }
        
        for(int i = 0; i < 4; i++) {
            double fibo_price = fibo_grid.swing_high + (swing_range * (m_extension_levels[i] - 100.0) / 100.0);
            
            fibo_grid.levels[level_index].price = fibo_price;
            fibo_grid.levels[level_index].percentage = m_extension_levels[i];
            fibo_grid.levels[level_index].level_name = m_level_names[level_index];
            fibo_grid.levels[level_index].level_color = m_level_colors[level_index];
            fibo_grid.levels[level_index].line_style = STYLE_DOT;
            fibo_grid.levels[level_index].line_width = 1;
            fibo_grid.levels[level_index].is_strong = (m_extension_levels[i] == 161.8 || m_extension_levels[i] == 200.0);
            fibo_grid.levels[level_index].confluence_count = 0;
            
            level_index++;
        }
        
        fibo_grid.level_count = level_index;
        fibo_grid.is_valid = true;
        
        return true;
    }
    
    bool IsInFiboCluster(const string symbol, ENUM_TIMEFRAMES timeframe, double price) {
        FiboGrid fibo_grid;
        if(!BuildFiboGrid(symbol, timeframe, fibo_grid)) {
            return false;
        }
        
        double tolerance = m_confluence_tolerance * _Point;
        
        for(int i = 0; i < fibo_grid.level_count; i++) {
            if(MathAbs(price - fibo_grid.levels[i].price) <= tolerance) {
                return true;
            }
        }
        
        return false;
    }
    
    void DrawFiboGrid(const FiboGrid &fibo_grid, long chart_id, const string symbol) const {
        if(!fibo_grid.is_valid) return;
        
        string grid_name = StringFormat("FiboGrid_%s_%d", symbol, (int)TimeCurrent());
        
        for(int i = 0; i < fibo_grid.level_count; i++) {
            string level_name = StringFormat("%s_Level_%d", grid_name, i);
            ObjectDelete(chart_id, level_name);
            
            if(ObjectCreate(chart_id, level_name, OBJ_HLINE, 0, 0, fibo_grid.levels[i].price)) {
                ObjectSetInteger(chart_id, level_name, OBJPROP_COLOR, fibo_grid.levels[i].level_color);
                ObjectSetInteger(chart_id, level_name, OBJPROP_STYLE, fibo_grid.levels[i].line_style);
                ObjectSetInteger(chart_id, level_name, OBJPROP_WIDTH, 
                               fibo_grid.levels[i].is_strong ? 2 : fibo_grid.levels[i].line_width);
                ObjectSetString(chart_id, level_name, OBJPROP_TEXT, fibo_grid.levels[i].level_name);
                
                if(fibo_grid.levels[i].is_strong) {
                    ObjectSetInteger(chart_id, level_name, OBJPROP_COLOR, clrYellow);
                    ObjectSetInteger(chart_id, level_name, OBJPROP_WIDTH, 3);
                }
            }
        }
        
        string high_line = StringFormat("%s_High", grid_name);
        string low_line = StringFormat("%s_Low", grid_name);
        
        ObjectDelete(chart_id, high_line);
        ObjectDelete(chart_id, low_line);
        
        if(ObjectCreate(chart_id, high_line, OBJ_VLINE, 0, fibo_grid.high_time, 0)) {
            ObjectSetInteger(chart_id, high_line, OBJPROP_COLOR, clrRed);
            ObjectSetInteger(chart_id, high_line, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(chart_id, high_line, OBJPROP_WIDTH, 2);
        }
        
        if(ObjectCreate(chart_id, low_line, OBJ_VLINE, 0, fibo_grid.low_time, 0)) {
            ObjectSetInteger(chart_id, low_line, OBJPROP_COLOR, clrBlue);
            ObjectSetInteger(chart_id, low_line, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(chart_id, low_line, OBJPROP_WIDTH, 2);
        }
    }
    
    void DrawFiboWithConfluence(const FiboGrid &fibo_grid, long chart_id, const string symbol) const {
        if(!fibo_grid.is_valid) return;
        
        DrawFiboGrid(fibo_grid, chart_id, symbol);
        
        double tolerance = m_confluence_tolerance * _Point;
        
        for(int i = 0; i < fibo_grid.level_count; i++) {
            if(fibo_grid.levels[i].confluence_count > 0) {
                string confluence_name = StringFormat("FiboConfluence_%s_%d_%d", symbol, i, (int)TimeCurrent());
                ObjectDelete(chart_id, confluence_name);
                
                double zone_high = fibo_grid.levels[i].price + tolerance;
                double zone_low = fibo_grid.levels[i].price - tolerance;
                
                if(ObjectCreate(chart_id, confluence_name, OBJ_RECTANGLE, 0, 
                               TimeCurrent() - 3600, zone_high, TimeCurrent() + 3600, zone_low)) {
                    ObjectSetInteger(chart_id, confluence_name, OBJPROP_COLOR, C'255,255,0,50');
                    ObjectSetInteger(chart_id, confluence_name, OBJPROP_FILL, true);
                    ObjectSetInteger(chart_id, confluence_name, OBJPROP_BACK, true);
                    ObjectSetInteger(chart_id, confluence_name, OBJPROP_STYLE, STYLE_SOLID);
                    ObjectSetInteger(chart_id, confluence_name, OBJPROP_WIDTH, 1);
                }
            }
        }
    }
    
    void ClearFiboVisualization(long chart_id) const {
        int total_objects = ObjectsTotal(chart_id);
        for(int i = total_objects - 1; i >= 0; i--) {
            string obj_name = ObjectName(chart_id, i);
            if(StringFind(obj_name, "Fibo") == 0) {
                ObjectDelete(chart_id, obj_name);
            }
        }
    }
};

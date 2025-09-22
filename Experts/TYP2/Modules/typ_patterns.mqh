// --- typ_patterns.mqh ---
// (c) 2025, Take Your Profit 2.0 Project
// Sprint 2 :: Candlestick Patterns Detection Module
#property copyright "TYP2"

/**
 * @brief Модуль детекции свечных паттернов
 * 
 * Предоставляет функциональность для автоматического распознавания
 * классических свечных паттернов на ценовых данных.
 */
class CPatterns {
public:
    /**
     * @brief Конструктор модуля паттернов
     */
    CPatterns() {}
    
    /**
     * @brief Деструктор модуля паттернов
     */
    ~CPatterns() {}
    
    // --- ПАТТЕРНЫ ПОГЛОЩЕНИЯ ---
    
    /**
     * @brief Детекция паттерна "Бычье поглощение"
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружен паттерн бычьего поглощения
     */
    bool IsBullishEngulfing(const MqlRates &rates[], int shift) const { 
        if(shift + 1 >= ArraySize(rates)) return false;
        
        const MqlRates &current = rates[shift];
        const MqlRates &previous = rates[shift + 1];
        
        // 1. Предыдущая свеча должна быть медвежьей
        if(!IsBearishCandle(previous)) return false;
        
        // 2. Текущая свеча должна быть бычьей
        if(!IsBullishCandle(current)) return false;
        
        // 3. Тело текущей свечи полностью поглощает тело предыдущей
        if(current.open >= previous.close || current.close <= previous.open) return false;
        
        // 4. Минимальный размер тел свечей (фильтр шума)
        double min_body_size = (current.high - current.low) * 0.6; // Тело должно быть >= 60% от диапазона
        if(GetCandleBody(current) < min_body_size || GetCandleBody(previous) < min_body_size * 0.3) return false;
        
        // 5. Объем текущей свечи должен быть выше среднего (если доступен)
        if(ArraySize(rates) > shift + 20) {
            double avg_volume = 0;
            for(int i = shift + 1; i <= shift + 20; i++) {
                avg_volume += (double)rates[i].tick_volume;
            }
            avg_volume /= 20;
            if(current.tick_volume < avg_volume * 1.2) return false;
        }
        
        return true;
    }
    
    /**
     * @brief Детекция паттерна "Медвежье поглощение"
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружен паттерн медвежьего поглощения
     */
    bool IsBearishEngulfing(const MqlRates &rates[], int shift) const { 
        if(shift + 1 >= ArraySize(rates)) return false;
        
        const MqlRates &current = rates[shift];
        const MqlRates &previous = rates[shift + 1];
        
        // 1. Предыдущая свеча должна быть бычьей
        if(!IsBullishCandle(previous)) return false;
        
        // 2. Текущая свеча должна быть медвежьей
        if(!IsBearishCandle(current)) return false;
        
        // 3. Тело текущей свечи полностью поглощает тело предыдущей
        if(current.open <= previous.close || current.close >= previous.open) return false;
        
        // 4. Минимальный размер тел свечей (фильтр шума)
        double min_body_size = (current.high - current.low) * 0.6;
        if(GetCandleBody(current) < min_body_size || GetCandleBody(previous) < min_body_size * 0.3) return false;
        
        // 5. Объем текущей свечи должен быть выше среднего
        if(ArraySize(rates) > shift + 20) {
            double avg_volume = 0;
            for(int i = shift + 1; i <= shift + 20; i++) {
                avg_volume += (double)rates[i].tick_volume;
            }
            avg_volume /= 20;
            if(current.tick_volume < avg_volume * 1.2) return false;
        }
        
        return true;
    }
    
    // --- ПАТТЕРНЫ PIN BAR ---
    
    /**
     * @brief Универсальная детекция Pin Bar с определением контекста
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @param is_bullish Результат: true если бычий, false если медвежий
     * @return true если обнаружен Pin Bar (любого типа)
     */
    bool IsPinBar(const MqlRates &rates[], int shift, bool &is_bullish) const {
        if(shift >= ArraySize(rates)) return false;
        
        const MqlRates &candle = rates[shift];
        
        double body = GetCandleBody(candle);
        double upper_shadow = GetUpperShadow(candle);
        double lower_shadow = GetLowerShadow(candle);
        double total_range = GetCandleRange(candle);
        
        if(total_range <= 0) return false;
        
        // Pin Bar должен иметь маленькое тело (< 25% от общего диапазона)
        if(body > total_range * 0.25) return false;
        
        // Проверяем соотношения теней
        bool is_hammer = (lower_shadow >= total_range * 0.6) && (upper_shadow <= total_range * 0.15);
        bool is_shooting_star = (upper_shadow >= total_range * 0.6) && (lower_shadow <= total_range * 0.15);
        
        if(!is_hammer && !is_shooting_star) return false;
        
        // Определяем контекст (бычий/медвежий) на основе предыдущего тренда
        if(shift + 5 < ArraySize(rates)) {
            double trend_direction = 0;
            for(int i = shift + 1; i <= shift + 5; i++) {
                trend_direction += rates[i].close - rates[i].open;
            }
            
            if(is_hammer) {
                is_bullish = (trend_direction < 0); // Hammer в нисходящем тренде = бычий сигнал
            } else { // is_shooting_star
                is_bullish = false; // Shooting Star = медвежий сигнал
            }
        } else {
            is_bullish = is_hammer;
        }
        
        return true;
    }
    
    /**
     * @brief Детекция бычьего Pin Bar (Hammer)
     */
    bool IsBullishPinBar(const MqlRates &rates[], int shift) const { 
        bool is_bullish;
        if(!IsPinBar(rates, shift, is_bullish)) return false;
        return is_bullish;
    }
    
    /**
     * @brief Детекция медвежьего Pin Bar (Shooting Star)
     */
    bool IsBearishPinBar(const MqlRates &rates[], int shift) const { 
        bool is_bullish;
        if(!IsPinBar(rates, shift, is_bullish)) return false;
        return !is_bullish;
    }
    
    // --- ПАТТЕРНЫ ЗВЕЗД ---
    
    /**
     * @brief Детекция паттерна "Утренняя звезда"
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара (проверяется 3-свечная комбинация)
     * @return true если обнаружена утренняя звезда
     */
    bool IsMorningStar(const MqlRates &rates[], int shift) const { 
        if(shift + 2 >= ArraySize(rates)) return false;
        
        const MqlRates &third = rates[shift];      // Последняя свеча
        const MqlRates &second = rates[shift + 1]; // Средняя свеча (звезда)
        const MqlRates &first = rates[shift + 2];  // Первая свеча
        
        // 1. Первая свеча должна быть длинной медвежьей
        if(!IsBearishCandle(first)) return false;
        double first_body = GetCandleBody(first);
        if(first_body < GetCandleRange(first) * 0.6) return false;
        
        // 2. Средняя свеча должна быть маленькой (звезда)
        double second_body = GetCandleBody(second);
        if(second_body > first_body * 0.3) return false;
        
        // 3. Гэп вниз между первой и второй свечей
        if(second.high >= first.close) return false;
        
        // 4. Третья свеча должна быть бычьей
        if(!IsBullishCandle(third)) return false;
        
        // 5. Третья свеча закрывается выше середины первой свечи
        double first_midpoint = (first.open + first.close) / 2;
        if(third.close <= first_midpoint) return false;
        
        // 6. Объемное подтверждение
        if(third.tick_volume <= second.tick_volume) return false;
        
        return true;
    }
    
    /**
     * @brief Детекция паттерна "Вечерняя звезда"
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара (проверяется 3-свечная комбинация)
     * @return true если обнаружена вечерняя звезда
     */
    bool IsEveningStar(const MqlRates &rates[], int shift) const { 
        if(shift + 2 >= ArraySize(rates)) return false;
        
        const MqlRates &third = rates[shift];      // Последняя свеча
        const MqlRates &second = rates[shift + 1]; // Средняя свеча (звезда)
        const MqlRates &first = rates[shift + 2];  // Первая свеча
        
        // 1. Первая свеча должна быть длинной бычьей
        if(!IsBullishCandle(first)) return false;
        double first_body = GetCandleBody(first);
        if(first_body < GetCandleRange(first) * 0.6) return false;
        
        // 2. Средняя свеча должна быть маленькой (звезда)
        double second_body = GetCandleBody(second);
        if(second_body > first_body * 0.3) return false;
        
        // 3. Гэп вверх между первой и второй свечей
        if(second.low <= first.close) return false;
        
        // 4. Третья свеча должна быть медвежьей
        if(!IsBearishCandle(third)) return false;
        
        // 5. Третья свеча закрывается ниже середины первой свечи
        double first_midpoint = (first.open + first.close) / 2;
        if(third.close >= first_midpoint) return false;
        
        // 6. Объемное подтверждение
        if(third.tick_volume <= second.tick_volume) return false;
        
        return true;
    }
    
    // --- ПАТТЕРНЫ ДОДЖИ ---
    
    /**
     * @brief Детекция паттерна "Доджи"
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружен доджи
     * 
     * TODO: Реализовать логику детекции Doji:
     * - Цена открытия ≈ цена закрытия (разница < 10% от диапазона свечи)
     * - Наличие верхних и нижних теней
     * - Появление после значительного движения
     */
    bool IsDoji(const MqlRates &rates[], int shift) const { 
        return false; 
    }
    
    /**
     * @brief Детекция паттерна "Надгробие" (Gravestone Doji)
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружено надгробие
     * 
     * TODO: Реализовать логику детекции Gravestone Doji:
     * - Открытие ≈ закрытие ≈ минимум
     * - Длинная верхняя тень
     * - Отсутствие или очень короткая нижняя тень
     */
    bool IsGravestoneDoji(const MqlRates &rates[], int shift) const { 
        return false; 
    }
    
    /**
     * @brief Детекция паттерна "Стрекоза" (Dragonfly Doji)
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружена стрекоза
     * 
     * TODO: Реализовать логику детекции Dragonfly Doji:
     * - Открытие ≈ закрытие ≈ максимум
     * - Длинная нижняя тень
     * - Отсутствие или очень короткая верхняя тень
     */
    bool IsDragonflyDoji(const MqlRates &rates[], int shift) const { 
        return false; 
    }
    
    // --- ПАТТЕРНЫ ХАРАМИ ---
    
    /**
     * @brief Детекция паттерна "Бычье харами"
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружено бычье харами
     * 
     * TODO: Реализовать логику детекции Bullish Harami:
     * - Первая свеча: длинная медвежья
     * - Вторая свеча: маленькая, полностью внутри тела первой
     * - Вторая свеча может быть любого цвета
     */
    bool IsBullishHarami(const MqlRates &rates[], int shift) const { 
        return false; 
    }
    
    /**
     * @brief Детекция паттерна "Медвежье харами"
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружено медвежье харами
     * 
     * TODO: Реализовать логику детекции Bearish Harami:
     * - Первая свеча: длинная бычья
     * - Вторая свеча: маленькая, полностью внутри тела первой
     * - Вторая свеча может быть любого цвета
     */
    bool IsBearishHarami(const MqlRates &rates[], int shift) const { 
        return false; 
    }
    
    // --- НОВЫЕ КРИТИЧЕСКИ ВАЖНЫЕ ПАТТЕРНЫ ---
    
    /**
     * @brief Детекция паттерна "Три Белых Солдата"
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружены три белых солдата
     */
    bool IsThreeWhiteSoldiers(const MqlRates &rates[], int shift) const {
        if(shift + 2 >= ArraySize(rates)) return false;
        
        // Проверяем три последовательные бычьи свечи
        for(int i = 0; i < 3; i++) {
            const MqlRates &candle = rates[shift + i];
            if(!IsBullishCandle(candle)) return false;
            
            // Каждая свеча должна иметь значительное тело
            if(GetCandleBody(candle) < GetCandleRange(candle) * 0.6) return false;
            
            // Небольшие верхние тени
            if(GetUpperShadow(candle) > GetCandleBody(candle) * 0.3) return false;
        }
        
        // Каждая следующая свеча открывается выше предыдущей и закрывается еще выше
        for(int i = 0; i < 2; i++) {
            const MqlRates &current = rates[shift + i];
            const MqlRates &next = rates[shift + i + 1];
            
            if(current.open <= next.close || current.close <= next.open) return false;
        }
        
        return true;
    }
    
    /**
     * @brief Детекция паттерна "Три Черных Ворона"
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружены три черных ворона
     */
    bool IsThreeBlackCrows(const MqlRates &rates[], int shift) const {
        if(shift + 2 >= ArraySize(rates)) return false;
        
        // Проверяем три последовательные медвежьи свечи
        for(int i = 0; i < 3; i++) {
            const MqlRates &candle = rates[shift + i];
            if(!IsBearishCandle(candle)) return false;
            
            // Каждая свеча должна иметь значительное тело
            if(GetCandleBody(candle) < GetCandleRange(candle) * 0.6) return false;
            
            // Небольшие нижние тени
            if(GetLowerShadow(candle) > GetCandleBody(candle) * 0.3) return false;
        }
        
        // Каждая следующая свеча открывается ниже предыдущей и закрывается еще ниже
        for(int i = 0; i < 2; i++) {
            const MqlRates &current = rates[shift + i];
            const MqlRates &next = rates[shift + i + 1];
            
            if(current.open >= next.close || current.close >= next.open) return false;
        }
        
        return true;
    }
    
    /**
     * @brief Детекция паттерна "Просвет" (Piercing Line)
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружен просвет
     */
    bool IsPiercingLine(const MqlRates &rates[], int shift) const {
        if(shift + 1 >= ArraySize(rates)) return false;
        
        const MqlRates &current = rates[shift];
        const MqlRates &previous = rates[shift + 1];
        
        // 1. Первая свеча медвежья
        if(!IsBearishCandle(previous)) return false;
        
        // 2. Вторая свеча бычья
        if(!IsBullishCandle(current)) return false;
        
        // 3. Вторая свеча открывается ниже минимума первой
        if(current.open >= previous.low) return false;
        
        // 4. Вторая свеча закрывается выше середины первой
        double previous_midpoint = (previous.open + previous.close) / 2;
        if(current.close <= previous_midpoint) return false;
        
        // 5. Но не закрывается выше открытия первой
        if(current.close >= previous.open) return false;
        
        return true;
    }
    
    /**
     * @brief Детекция паттерна "Завеса" (Dark Cloud Cover)
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружена завеса
     */
    bool IsDarkCloudCover(const MqlRates &rates[], int shift) const {
        if(shift + 1 >= ArraySize(rates)) return false;
        
        const MqlRates &current = rates[shift];
        const MqlRates &previous = rates[shift + 1];
        
        // 1. Первая свеча бычья
        if(!IsBullishCandle(previous)) return false;
        
        // 2. Вторая свеча медвежья
        if(!IsBearishCandle(current)) return false;
        
        // 3. Вторая свеча открывается выше максимума первой
        if(current.open <= previous.high) return false;
        
        // 4. Вторая свеча закрывается ниже середины первой
        double previous_midpoint = (previous.open + previous.close) / 2;
        if(current.close >= previous_midpoint) return false;
        
        // 5. Но не закрывается ниже открытия первой
        if(current.close <= previous.open) return false;
        
        return true;
    }
    
    /**
     * @brief Детекция паттерна "Пинцет" (Tweezers)
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @param is_top true для поиска пинцета на вершине, false для дна
     * @return true если обнаружен пинцет
     */
    bool IsTweezerTopBottom(const MqlRates &rates[], int shift, bool is_top = true) const {
        if(shift + 1 >= ArraySize(rates)) return false;
        
        const MqlRates &current = rates[shift];
        const MqlRates &previous = rates[shift + 1];
        
        if(is_top) {
            // Пинцет на вершине - одинаковые максимумы
            double price_diff = MathAbs(current.high - previous.high);
            double avg_range = (GetCandleRange(current) + GetCandleRange(previous)) / 2;
            
            if(price_diff > avg_range * 0.1) return false; // Максимумы должны быть близки
            
            // Первая свеча должна быть бычьей, вторая медвежьей
            return IsBullishCandle(previous) && IsBearishCandle(current);
        } else {
            // Пинцет на дне - одинаковые минимумы
            double price_diff = MathAbs(current.low - previous.low);
            double avg_range = (GetCandleRange(current) + GetCandleRange(previous)) / 2;
            
            if(price_diff > avg_range * 0.1) return false; // Минимумы должны быть близки
            
            // Первая свеча должна быть медвежьей, вторая бычьей
            return IsBearishCandle(previous) && IsBullishCandle(current);
        }
    }
    
    /**
     * @brief Детекция паттерна "Три Внутри Вверх/Вниз"
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @param is_up true для "Три Внутри Вверх", false для "Три Внутри Вниз"
     * @return true если обнаружен паттерн
     */
    bool IsThreeInsideUpDown(const MqlRates &rates[], int shift, bool is_up = true) const {
        if(shift + 2 >= ArraySize(rates)) return false;
        
        const MqlRates &third = rates[shift];
        const MqlRates &second = rates[shift + 1];
        const MqlRates &first = rates[shift + 2];
        
        if(is_up) {
            // Три Внутри Вверх
            // 1. Большая медвежья свеча
            if(!IsBearishCandle(first) || GetCandleBody(first) < GetCandleRange(first) * 0.6) return false;
            
            // 2. Маленькая бычья свеча внутри первой
            if(!IsBullishCandle(second)) return false;
            if(second.open <= first.close || second.close >= first.open) return false;
            
            // 3. Третья свеча закрывается выше максимума первой
            if(!IsBullishCandle(third) || third.close <= first.high) return false;
        } else {
            // Три Внутри Вниз
            // 1. Большая бычья свеча
            if(!IsBullishCandle(first) || GetCandleBody(first) < GetCandleRange(first) * 0.6) return false;
            
            // 2. Маленькая медвежья свеча внутри первой
            if(!IsBearishCandle(second)) return false;
            if(second.open >= first.close || second.close <= first.open) return false;
            
            // 3. Третья свеча закрывается ниже минимума первой
            if(!IsBearishCandle(third) || third.close >= first.low) return false;
        }
        
        return true;
    }
    
    /**
     * @brief Детекция паттерна "Рельсы" (Railway Tracks)
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @return true если обнаружены рельсы
     */
    bool IsRailwayTracks(const MqlRates &rates[], int shift) const {
        if(shift + 1 >= ArraySize(rates)) return false;
        
        const MqlRates &current = rates[shift];
        const MqlRates &previous = rates[shift + 1];
        
        // Свечи должны быть противоположными по направлению
        if(IsBullishCandle(current) == IsBullishCandle(previous)) return false;
        
        // Тела свечей должны быть примерно одинакового размера
        double current_body = GetCandleBody(current);
        double previous_body = GetCandleBody(previous);
        double size_ratio = current_body / previous_body;
        if(size_ratio < 0.8 || size_ratio > 1.2) return false;
        
        // Свечи должны иметь значительные тела
        if(current_body < GetCandleRange(current) * 0.6) return false;
        if(previous_body < GetCandleRange(previous) * 0.6) return false;
        
        // Цены закрытия должны быть близки друг к другу
        double close_diff = MathAbs(current.close - previous.close);
        double avg_body = (current_body + previous_body) / 2;
        if(close_diff > avg_body * 0.1) return false;
        
        return true;
    }
    
    // --- КОМБИНИРОВАННЫЕ МЕТОДЫ ---
    
    /**
     * @brief Поиск любого бычьего паттерна
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @param pattern_name Имя найденного паттерна (выходной параметр)
     * @return true если найден любой бычий паттерн
     */
    bool FindAnyBullishPattern(const MqlRates &rates[], int shift, string &pattern_name) const {
        // Проверяем все бычьи паттерны в порядке приоритета
        
        if(IsThreeWhiteSoldiers(rates, shift)) {
            pattern_name = "Three White Soldiers";
            return true;
        }
        
        if(IsBullishEngulfing(rates, shift)) {
            pattern_name = "Bullish Engulfing";
            return true;
        }
        
        if(IsMorningStar(rates, shift)) {
            pattern_name = "Morning Star";
            return true;
        }
        
        if(IsBullishPinBar(rates, shift)) {
            pattern_name = "Bullish Pin Bar";
            return true;
        }
        
        if(IsPiercingLine(rates, shift)) {
            pattern_name = "Piercing Line";
            return true;
        }
        
        if(IsThreeInsideUpDown(rates, shift, true)) {
            pattern_name = "Three Inside Up";
            return true;
        }
        
        if(IsTweezerTopBottom(rates, shift, false)) {
            pattern_name = "Tweezers Bottom";
            return true;
        }
        
        if(IsBullishHarami(rates, shift)) {
            pattern_name = "Bullish Harami";
            return true;
        }
        
        pattern_name = "None";
        return false;
    }
    
    /**
     * @brief Поиск любого медвежьего паттерна
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @param pattern_name Имя найденного паттерна (выходной параметр)
     * @return true если найден любой медвежий паттерн
     */
    bool FindAnyBearishPattern(const MqlRates &rates[], int shift, string &pattern_name) const {
        // Проверяем все медвежьи паттерны в порядке приоритета
        
        if(IsThreeBlackCrows(rates, shift)) {
            pattern_name = "Three Black Crows";
            return true;
        }
        
        if(IsBearishEngulfing(rates, shift)) {
            pattern_name = "Bearish Engulfing";
            return true;
        }
        
        if(IsEveningStar(rates, shift)) {
            pattern_name = "Evening Star";
            return true;
        }
        
        if(IsBearishPinBar(rates, shift)) {
            pattern_name = "Bearish Pin Bar";
            return true;
        }
        
        if(IsDarkCloudCover(rates, shift)) {
            pattern_name = "Dark Cloud Cover";
            return true;
        }
        
        if(IsThreeInsideUpDown(rates, shift, false)) {
            pattern_name = "Three Inside Down";
            return true;
        }
        
        if(IsTweezerTopBottom(rates, shift, true)) {
            pattern_name = "Tweezers Top";
            return true;
        }
        
        if(IsBearishHarami(rates, shift)) {
            pattern_name = "Bearish Harami";
            return true;
        }
        
        pattern_name = "None";
        return false;
    }
    
    /**
     * @brief Расчет силы найденного паттерна
     * @param rates Массив ценовых данных
     * @param shift Смещение от текущего бара
     * @param pattern_name Имя паттерна для анализа
     * @return Сила паттерна от 0.0 (слабый) до 1.0 (очень сильный)
     */
    double GetPatternStrength(const MqlRates &rates[], int shift, const string pattern_name) const {
        if(shift >= ArraySize(rates)) return 0.0;
        
        double strength = 0.5; // Базовая сила
        const MqlRates &candle = rates[shift];
        
        // 1. Фактор размера тела свечи
        double body_ratio = GetCandleBody(candle) / GetCandleRange(candle);
        if(body_ratio > 0.7) strength += 0.15;  // Длинное тело
        else if(body_ratio < 0.3) strength -= 0.1; // Короткое тело
        
        // 2. Фактор объема
        if(ArraySize(rates) > shift + 10) {
            double avg_volume = 0;
            for(int i = shift + 1; i <= shift + 10; i++) {
                avg_volume += (double)rates[i].tick_volume;
            }
            avg_volume /= 10;
            
            if(candle.tick_volume > avg_volume * 1.5) strength += 0.2;  // Высокий объем
            else if(candle.tick_volume < avg_volume * 0.7) strength -= 0.15; // Низкий объем
        }
        
        // 3. Контекстуальные факторы
        if(pattern_name == "Three White Soldiers" || pattern_name == "Three Black Crows") {
            strength += 0.1; // Трехсвечные паттерны более надежны
        }
        
        if(pattern_name == "Bullish Engulfing" || pattern_name == "Bearish Engulfing") {
            // Проверяем полноту поглощения
            if(shift + 1 < ArraySize(rates)) {
                const MqlRates &prev = rates[shift + 1];
                double engulfing_ratio = GetCandleBody(candle) / GetCandleBody(prev);
                if(engulfing_ratio > 2.0) strength += 0.15; // Полное поглощение
            }
        }
        
        // 4. Фактор позиции в тренде
        if(shift + 5 < ArraySize(rates)) {
            double trend_strength = 0;
            for(int i = shift + 1; i <= shift + 5; i++) {
                trend_strength += rates[i].close - rates[i].open;
            }
            
            bool strong_trend = MathAbs(trend_strength) > GetCandleRange(candle) * 3;
            if(strong_trend) strength += 0.1; // Паттерн на сильном тренде
        }
        
        return MathMax(0.0, MathMin(1.0, strength));
    }
    
    /**
     * @brief Визуальный слой - отрисовка паттернов на графике
     * @param pattern_name Название паттерна
     * @param shift Смещение бара
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     * @param strength Сила паттерна
     */
    void DrawPattern(const string pattern_name, int shift, long chart_id, const MqlRates &rates[], double strength) const {
        if(pattern_name == "None") return;
        
        datetime bar_time = rates[shift].time;
        double price_level = rates[shift].high + (rates[shift].high - rates[shift].low) * 0.1;
        
        // Определяем цвет на основе силы паттерна
        color pattern_color = clrYellow;
        if(strength > 0.7) pattern_color = clrLime;
        else if(strength > 0.6) pattern_color = clrGreen;
        else if(strength < 0.4) pattern_color = clrOrange;
        else if(strength < 0.3) pattern_color = clrRed;
        
        // Создаем уникальное имя объекта
        string object_name = StringFormat("Pattern_%s_%d_%d", pattern_name, shift, (int)bar_time);
        
        // Удаляем существующий объект
        ObjectDelete(chart_id, object_name);
        
        // Создаем текстовую метку
        if(ObjectCreate(chart_id, object_name, OBJ_TEXT, 0, bar_time, price_level)) {
            ObjectSetString(chart_id, object_name, OBJPROP_TEXT, StringFormat("%s (%.1f%%)", pattern_name, strength * 100));
            ObjectSetInteger(chart_id, object_name, OBJPROP_COLOR, pattern_color);
            ObjectSetInteger(chart_id, object_name, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(chart_id, object_name, OBJPROP_ANCHOR, ANCHOR_LOWER);
            
            // Добавляем стрелку для направления
            string arrow_name = object_name + "_arrow";
            ObjectDelete(chart_id, arrow_name);
            
            bool is_bullish = (StringFind(pattern_name, "Bullish") >= 0 || 
                              StringFind(pattern_name, "Morning") >= 0 ||
                              StringFind(pattern_name, "White") >= 0 ||
                              StringFind(pattern_name, "Piercing") >= 0 ||
                              StringFind(pattern_name, "Up") >= 0 ||
                              StringFind(pattern_name, "Bottom") >= 0);
            
            if(ObjectCreate(chart_id, arrow_name, OBJ_ARROW, 0, bar_time, rates[shift].high)) {
                ObjectSetInteger(chart_id, arrow_name, OBJPROP_ARROWCODE, is_bullish ? 241 : 242);
                ObjectSetInteger(chart_id, arrow_name, OBJPROP_COLOR, pattern_color);
                ObjectSetInteger(chart_id, arrow_name, OBJPROP_WIDTH, 3);
            }
        }
    }
    
private:
    // --- ВСПОМОГАТЕЛЬНЫЕ МЕТОДЫ ---
    
    /**
     * @brief Проверка является ли свеча бычьей
     * @param candle Данные свечи
     * @return true если свеча бычья (зеленая)
     */
    bool IsBullishCandle(const MqlRates &candle) const {
        return candle.close > candle.open;
    }
    
    /**
     * @brief Проверка является ли свеча медвежьей
     * @param candle Данные свечи
     * @return true если свеча медвежья (красная)
     */
    bool IsBearishCandle(const MqlRates &candle) const {
        return candle.close < candle.open;
    }
    
    /**
     * @brief Расчет размера тела свечи
     * @param candle Данные свечи
     * @return Размер тела в пунктах
     */
    double GetCandleBody(const MqlRates &candle) const {
        return MathAbs(candle.close - candle.open);
    }
    
    /**
     * @brief Расчет размера верхней тени свечи
     * @param candle Данные свечи
     * @return Размер верхней тени в пунктах
     */
    double GetUpperShadow(const MqlRates &candle) const {
        return candle.high - MathMax(candle.open, candle.close);
    }
    
    /**
     * @brief Расчет размера нижней тени свечи
     * @param candle Данные свечи
     * @return Размер нижней тени в пунктах
     */
    double GetLowerShadow(const MqlRates &candle) const {
        return MathMin(candle.open, candle.close) - candle.low;
    }
    
    /**
     * @brief Расчет полного диапазона свечи
     * @param candle Данные свечи
     * @return Диапазон от минимума до максимума в пунктах
     */
    double GetCandleRange(const MqlRates &candle) const {
        return candle.high - candle.low;
    }
    
    // === РАСШИРЕННЫЕ МЕТОДЫ ВИЗУАЛИЗАЦИИ ===
    
    /**
     * @brief Визуализация паттерна с указанием направления
     * @param pattern_name Название паттерна
     * @param shift Смещение бара
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     * @param strength Сила паттерна
     * @param is_bullish true для бычьего паттерна, false для медвежьего
     */
    void DrawPatternWithDirection(const string pattern_name, int shift, long chart_id, 
                                 const MqlRates &rates[], double strength, bool is_bullish) const {
        if(pattern_name == "None") return;
        
        datetime bar_time = rates[shift].time;
        double price_level = is_bullish ? 
                           rates[shift].high + (rates[shift].high - rates[shift].low) * 0.1 :
                           rates[shift].low - (rates[shift].high - rates[shift].low) * 0.1;
        
        // Определяем цвет в зависимости от направления и силы
        color pattern_color;
        if(is_bullish) {
            if(strength > 0.8) pattern_color = clrLime;
            else if(strength > 0.6) pattern_color = clrGreen;
            else if(strength > 0.4) pattern_color = clrYellowGreen;
            else pattern_color = clrLightGreen;
        } else {
            if(strength > 0.8) pattern_color = clrRed;
            else if(strength > 0.6) pattern_color = clrCrimson;
            else if(strength > 0.4) pattern_color = clrOrange;
            else pattern_color = clrLightCoral;
        }
        
        string object_name = StringFormat("Pattern_%s_%s_%d_%d", 
                                        is_bullish ? "BULL" : "BEAR", pattern_name, shift, (int)bar_time);
        ObjectDelete(chart_id, object_name);
        
        if(ObjectCreate(chart_id, object_name, OBJ_TEXT, 0, bar_time, price_level)) {
            string direction_text = is_bullish ? "BULL" : "BEAR";
            ObjectSetString(chart_id, object_name, OBJPROP_TEXT, 
                          StringFormat("%s %s (%.1f%%)", direction_text, pattern_name, strength * 100));
            ObjectSetInteger(chart_id, object_name, OBJPROP_COLOR, pattern_color);
            ObjectSetInteger(chart_id, object_name, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(chart_id, object_name, OBJPROP_ANCHOR, is_bullish ? ANCHOR_LOWER : ANCHOR_UPPER);
        }
        
        // Добавляем стрелку направления
        string arrow_name = object_name + "_arrow";
        ObjectDelete(chart_id, arrow_name);
        
        int arrow_code = is_bullish ? 233 : 234; // Стрелка вверх или вниз
        double arrow_price = is_bullish ? rates[shift].low - 5*_Point : rates[shift].high + 5*_Point;
        
        if(ObjectCreate(chart_id, arrow_name, OBJ_ARROW, 0, bar_time, arrow_price)) {
            ObjectSetInteger(chart_id, arrow_name, OBJPROP_ARROWCODE, arrow_code);
            ObjectSetInteger(chart_id, arrow_name, OBJPROP_COLOR, pattern_color);
            ObjectSetInteger(chart_id, arrow_name, OBJPROP_WIDTH, 3);
        }
    }
    
    /**
     * @brief Визуализация паттерна с зоной влияния
     * @param pattern_name Название паттерна
     * @param shift Смещение бара
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     * @param strength Сила паттерна
     * @param influence_bars Количество баров зоны влияния
     */
    void DrawPatternWithInfluence(const string pattern_name, int shift, long chart_id, 
                                 const MqlRates &rates[], double strength, int influence_bars = 5) const {
        if(pattern_name == "None") return;
        
        // Сначала рисуем основной паттерн
        DrawPattern(pattern_name, shift, chart_id, rates, strength);
        
        // Определяем цвет зоны влияния (полупрозрачный)
        color zone_color = (strength > 0.6) ? C'0,255,0,50' : C'255,165,0,50';
        
        string zone_name = StringFormat("Pattern_Zone_%s_%d_%d", pattern_name, shift, (int)rates[shift].time);
        ObjectDelete(chart_id, zone_name);
        
        datetime start_time = rates[shift].time;
        datetime end_time = (shift + influence_bars < ArraySize(rates)) ? 
                           rates[shift + influence_bars].time : rates[ArraySize(rates)-1].time;
        
        double high_price = rates[shift].high;
        double low_price = rates[shift].low;
        
        // Находим экстремумы в зоне влияния
        for(int i = shift; i < MathMin(shift + influence_bars, ArraySize(rates)); i++) {
            if(rates[i].high > high_price) high_price = rates[i].high;
            if(rates[i].low < low_price) low_price = rates[i].low;
        }
        
        if(ObjectCreate(chart_id, zone_name, OBJ_RECTANGLE, 0, start_time, high_price, end_time, low_price)) {
            ObjectSetInteger(chart_id, zone_name, OBJPROP_COLOR, zone_color);
            ObjectSetInteger(chart_id, zone_name, OBJPROP_FILL, true);
            ObjectSetInteger(chart_id, zone_name, OBJPROP_BACK, true);
            ObjectSetInteger(chart_id, zone_name, OBJPROP_STYLE, STYLE_SOLID);
            ObjectSetInteger(chart_id, zone_name, OBJPROP_WIDTH, 1);
        }
    }
    
    /**
     * @brief Визуализация паттерна с уровнями поддержки/сопротивления
     * @param pattern_name Название паттерна
     * @param shift Смещение бара
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     * @param strength Сила паттерна
     * @param support_level Уровень поддержки
     * @param resistance_level Уровень сопротивления
     */
    void DrawPatternWithLevels(const string pattern_name, int shift, long chart_id, 
                              const MqlRates &rates[], double strength, 
                              double support_level, double resistance_level) const {
        if(pattern_name == "None") return;
        
        // Рисуем основной паттерн
        DrawPattern(pattern_name, shift, chart_id, rates, strength);
        
        // Определяем цвет уровней
        color level_color = (strength > 0.6) ? clrBlue : clrGray;
        
        // Рисуем уровень поддержки
        if(support_level > 0) {
            string support_name = StringFormat("Pattern_Support_%s_%d_%d", pattern_name, shift, (int)rates[shift].time);
            ObjectDelete(chart_id, support_name);
            
            if(ObjectCreate(chart_id, support_name, OBJ_HLINE, 0, 0, support_level)) {
                ObjectSetInteger(chart_id, support_name, OBJPROP_COLOR, level_color);
                ObjectSetInteger(chart_id, support_name, OBJPROP_STYLE, STYLE_DASH);
                ObjectSetInteger(chart_id, support_name, OBJPROP_WIDTH, 2);
                ObjectSetString(chart_id, support_name, OBJPROP_TEXT, StringFormat("Support: %.5f", support_level));
            }
        }
        
        // Рисуем уровень сопротивления
        if(resistance_level > 0) {
            string resistance_name = StringFormat("Pattern_Resistance_%s_%d_%d", pattern_name, shift, (int)rates[shift].time);
            ObjectDelete(chart_id, resistance_name);
            
            if(ObjectCreate(chart_id, resistance_name, OBJ_HLINE, 0, 0, resistance_level)) {
                ObjectSetInteger(chart_id, resistance_name, OBJPROP_COLOR, level_color);
                ObjectSetInteger(chart_id, resistance_name, OBJPROP_STYLE, STYLE_DASH);
                ObjectSetInteger(chart_id, resistance_name, OBJPROP_WIDTH, 2);
                ObjectSetString(chart_id, resistance_name, OBJPROP_TEXT, StringFormat("Resistance: %.5f", resistance_level));
            }
        }
    }
    
    /**
     * @brief Визуализация паттерна с целевыми уровнями
     * @param pattern_name Название паттерна
     * @param shift Смещение бара
     * @param chart_id ID графика
     * @param rates Массив ценовых данных
     * @param strength Сила паттерна
     * @param target_levels Массив целевых уровней
     * @param target_count Количество целевых уровней
     */
    void DrawPatternWithTargets(const string pattern_name, int shift, long chart_id, 
                               const MqlRates &rates[], double strength, 
                               const double &target_levels[], int target_count) const {
        if(pattern_name == "None" || target_count <= 0) return;
        
        // Рисуем основной паттерн
        DrawPattern(pattern_name, shift, chart_id, rates, strength);
        
        // Определяем цвет целей
        color target_color = (strength > 0.6) ? clrDodgerBlue : clrSteelBlue;
        
        // Рисуем целевые уровни
        for(int i = 0; i < target_count; i++) {
            string target_name = StringFormat("Pattern_Target_%s_%d_%d_%d", pattern_name, shift, i, (int)rates[shift].time);
            ObjectDelete(chart_id, target_name);
            
            if(ObjectCreate(chart_id, target_name, OBJ_HLINE, 0, 0, target_levels[i])) {
                ObjectSetInteger(chart_id, target_name, OBJPROP_COLOR, target_color);
                ObjectSetInteger(chart_id, target_name, OBJPROP_STYLE, STYLE_DOT);
                ObjectSetInteger(chart_id, target_name, OBJPROP_WIDTH, 1);
                ObjectSetString(chart_id, target_name, OBJPROP_TEXT, StringFormat("Target %d: %.5f", i+1, target_levels[i]));
            }
        }
    }
    
    /**
     * @brief Очистка всех объектов визуализации паттернов
     * @param chart_id ID графика
     */
    void ClearPatternVisualization(long chart_id) const {
        int total_objects = ObjectsTotal(chart_id);
        for(int i = total_objects - 1; i >= 0; i--) {
            string obj_name = ObjectName(chart_id, i);
            if(StringFind(obj_name, "Pattern_") == 0) {
                ObjectDelete(chart_id, obj_name);
            }
        }
    }
};

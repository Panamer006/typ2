CODE_GUIDELINES_MQL5.md (v1.0)

Эталон качества кода для проекта TYP2

1. Золотые правила (ядро)

Структура классов

Все методы и данные определяются только внутри тела класса.

Никаких CMyClass::Method() вне фигурных скобок.

#include пути

Наши модули → "".

Стандартные библиотеки MQL5 → <>.

Константы и enum

Никаких «магических чисел».

Использовать enum, #define, const.

const-корректность

Методы без побочных эффектов → объявлять const.

Ресурсы

Индикаторы: освобождать через IndicatorRelease().

Динамические объекты: delete в деструкторе.

Торговля

Все операции через CTrade.

Проверка result.retcode на TRADE_RETCODE_*.

SL/TP всегда обязательны.

Проверки данных

BarsCalculated, INVALID_HANDLE, границы массивов, деление на ноль.

Сигналы стратегий

Используем унифицированную структуру:

struct TSignal {
  bool valid;
  ENUM_POSITION_TYPE dir;
  double sl;
  double tp;
  double score;
  string reason;
};


Гварды и архитектура

Все сигналы проходят RiskManager + ExecGate.

Порядок вызовов см. ARCHITECTURE.md.

Визуализация

Только через CChartObjectsManager.

2. Обязательные практики (из MQL5 Book)

ООП-подход: советники строятся на классах (Init, OnTick, GetSignal).

Event Model: OnInit (инициализация), OnTick (логика), OnDeinit (освобождение ресурсов).

Таймсерии/индикаторы: доступ только через API (CopyRates, CopyBuffer), с проверкой доступности.

Торговые условия: проверять торговый режим, спред, тип учёта (неттинг/хеджинг).

Логи и тестирование: логирование с контролем уровня; тесты должны быть воспроизводимы.

3. AI Integration Guidelines (из NeuroBook)

Все AI-модули должны быть реализованы в виде класса CAiLayer.

Нейросеть возвращает оценки/вероятности, которые конвертируются в TSignal.

Resolver остаётся дирижёром — AI лишь один из источников сигналов.

Асинхронность: AI-вызовы не должны блокировать OnTick.

ONNX/Python: для интеграции использовать встроенные функции MQL5.

4. Частые ошибки (чего избегать)

Неинициализированные хэндлы индикаторов (INVALID_HANDLE).

Деление на ноль, выход за границы массивов.

Игнорирование BarsCalculated.

Торговые вызовы без проверки retcode.

Магические числа вместо enum.

Логика вне OnInit/OnTick/OnDeinit.

5. Required References (использовать всегда)
Из MQL5 Docs

Language Basics

Predefined Variables

Event Handling

Timeseries and Indicators Access

Trade Functions

Standard Library

Constants, Enumerations, Structures

Из MQL5 Book

Introduction to MQL5

Basics of MQL5

Event Model

Trading in MQL5

Indicators

Object-Oriented Programming

Из MQL5 NeuroBook

Feature Engineering

Model Training (Python/ONNX)

ONNX Integration

Python Integration

Inference in EA

6. Recommended References

Array Functions

Math Functions

String Functions

Date and Time

Account Information

Market Info

Chart Operations

Object Functions

Technical Indicators

Custom Indicators

Arrays & Timeseries (Book)

Math & Statistics (Book)

Testing and Optimization (Book)

Practical Examples (Book)

Data Preprocessing (NeuroBook)

Metrics: precision/recall/F1 (NeuroBook)

Hybrid Approaches (NeuroBook)

7. Advanced References

Matrix and Vector Methods

Conversion Functions

Checkup

Economic Calendar

Custom Symbols

Global Variables of the Terminal

File Functions

Network Functions

Databases

Python Integration

ONNX Integration

OpenCL

DirectX

File Operations (Book)

DLL (Book)

Custom Indicators Development (Book)

Advanced OOP (Book)

Deep Networks (NeuroBook)

Reinforcement Learning (NeuroBook)

Edge Cases (NeuroBook)

8. Инструкции для Архитектора и Кодекса

Архитектор (GPT) в каждом ТЗ обязан писать:

«Соблюдай docs/CODE_GUIDELINES_MQL5.md, архитектуру TYP2, и оф. справку из разделов Required References.»

Кодекс (MQL5 Dev):

Любой код пишется только по этим правилам.

Стратегии всегда возвращают TSignal.

Все торговые операции проверяются.

AI-слой только через CAiLayer и Resolver.

Cursor: только scaffold + git-операции.
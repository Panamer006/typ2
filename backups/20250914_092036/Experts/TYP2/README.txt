TYP2 — P0 Pack #001 (T2-005 Exec Filters — Logic)

Что внутри:
- Experts/TYP2/typ_execfilters.mqh — полная логика Exec-фильтров:
  * No-Chase (ATR/PIPS режимы)
  * MinSpace (свинг + «круглые» уровни)
  * Time-Stop (bars elapsed)
  * ExecGate_PreOrder(...) — общий пред-ордерный гейт

Как установить:
1) Скопируйте файл в: Experts/TYP2/ (замените, если существует).
2) Скомпилируйте проект в MetaEditor.
3) (Опционально — включение действий)
   - Перед отправкой ордера вызовите:
       if(!ExecGate_PreOrder(_Symbol,_Period,dir,entryPrice,marketPrice)) return(false);
   - В Position Manager:
       if(ExecTimeStop_Exceeded(_Symbol,_Period,open_time)) { /* BE/close policy */ }

Примечание:
- Сейчас действия Time-Stop не активируем, только проверка; политику (BE/close) подключим позже.
- Пороговые инпуты вынесены в начало файла; по умолчанию безопасные.

## Context

См. `proposal.md` для мотивации и `specs/input-event-dispatch/spec.md` для наблюдаемого контракта. Сейчас `Components.Edit` хранит готовый message, поэтому значение input приходится представлять строкой-маркером в JSON. `Home.decode` затем обходит весь JSON и подменяет маркер до `msg_of_yojson`.

`Home.view` и page view являются чистыми функциями от текущего state. Android хранит event как непрозрачный JSON array и пересылает его вместе с единственным строковым `value`.

## Goals / Non-Goals

**Goals:**
- Сохранять Elm-поток: view объявляет создание `Msg`, а update получает готовый `Msg`.
- Сделать обработку input композиционной через существующий `Components.map` для любой вложенности дерева.
- Не требовать изменений Android production-кода.
- Отклонять input event от устаревшего документа до изменения state.

**Non-Goals:**
- Не переводить button, системные `Back` и `Load` на selector-ы.
- Не вводить формы с несколькими полями или произвольные значения input кроме одной строки.
- Не менять глобальную модель одного UI-сеанса или добавлять хранение server-side callback-реестра.

## Decisions

### Input хранит message builder

`Components.Edit` будет хранить `string -> 'event`, а `edit` будет принимать эту функцию. Page view объявляет `fun name -> Create name` или `fun prompt -> Run_claude prompt`; существующие message с `string` и page update остаются domain-level API.

`Components.map` композиционно оборачивает builder: после любого числа `map` разрешённый input возвращает итоговый `Home.msg`. Это устраняет page-specific ветки из `Home.decode`.

Не используется отдельный `action` type или `value` в `update`: оба варианта меняют Elm-контракт page update и связывают его с transport envelope.

### Selector строится и разрешается общим обходом дерева

При сериализации `Components.to_json` рекурсивно передаёт путь дочерних индексов. Для каждого `Edit` он публикует selector вида `["input", revision, path]`; button продолжает публиковать текущий сериализованный message. Общий resolver проходит то же дерево по `path`, удостоверяется, что конечный узел является `Edit`, и вызывает его builder со строкой input.

Путь и tagged array являются деталями `Components`; page-компоненты не задают id и не знают JSON-формат. Используется путь, а не постоянный callback-реестр: обработчик заново получается из чистого `Home.view` текущего state.

### Ревизия документа защищает от устаревшей адресации

`Home.state` будет хранить монотонную revision. Каждое успешно применённое message увеличивает revision, а все JSON-документы используют текущую revision при создании selector-ов. При input request сервер читает snapshot state, сравнивает revision selector-а, разрешает handler в view этого snapshot и атомарно фиксирует результат только если snapshot всё ещё актуален. При несовпадении revision или неудачном сравнении request получает ошибку без запуска command.

Это необходимо для структурного пути: без revision input из старого экрана мог бы совпасть с индексом другого input в новом документе.

### HTTP decoder различает selector input и существующие messages

`Home.decode` распознаёт tagged input selector и делегирует его разрешение `Components`; для остальных event сохраняется текущий путь `Home.msg_of_yojson`, обслуживающий button, `Back` и `Load`. Input selector требует строковый `value`; `null` или неверная структура дают `Bad_request`.

`replace_value` удаляется. В частности, строка `"__VALUE__"` больше не имеет специального значения.

## Risks / Trade-offs

- [Возможна рассинхронизация сериализатора и resolver-а] → Оба используют один и тот же рекурсивный порядок `Components`; покрыть вложенные `map`, `row` и `column` проверками round-trip selector-а.
- [Событие input из старого документа отклоняется] → Клиент уже блокирует повторные события во время запроса и применяет каждый streaming-документ; возврат ошибки безопаснее ошибочного запуска действия на новом экране.
- [Одно глобальное состояние конкурирует между HTTP requests] → Проверять revision и атомарно фиксировать вычисленный переход для input dispatch.
- [Протокол input selector меняется] → Android передаёт event array непрозрачно; обновить только его contract tests и README.

## Migration Plan

1. Выпустить сервер, который отдаёт selector-ы для input и принимает их, сохраняя существующий формат button event.
2. Обновить backend и Android contract tests, затем README с новым описанием input event.
3. Откатить сервер при необходимости; нет сохранённых данных, миграции клиента или совместимого состояния.

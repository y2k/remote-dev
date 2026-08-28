## Context

См. `proposal.md` для мотивации. В `Runtime.load_worktrees` и `Runtime.stream_claude` запуск процесса, чтение stdout и ожидание статуса смешаны с разбором соответствующих протоколов. Приложение запускается внутри `Eio_main.run`; Claude выполняется в отдельном domain через `Eio.Domain_manager.run`, поэтому динамическая область effect handler-а основного domain не покрывает этот callback.

## Goals / Non-Goals

**Goals:**

- Изолировать весь lifecycle stdout-процесса за единым effect-ом, сохранив streaming для Claude.
- Оставить parsing, накопление worktree-данных, фильтрацию Claude delta и классификацию exit status вне effect handler-а.
- Дать unit-тестам возможность подменить входящие строки и status без файловой системы, shell и process environment.
- Сохранить текущие exception и streaming semantics.

**Non-Goals:**

- Изменение команды `git`, shell wrapper Claude, CLI-аргументов или форматов stdout.
- Добавление timeout, cancellation, stderr capture, retry или нового async API.
- Перепроектирование `Home`, HTTP-маршрутов или Eio concurrency.

## Decisions

### Один streaming process effect

Effect принимает описание запуска и callback для одной stdout-строки, а продолжению возвращает `Unix.process_status`. Production handler запускает процесс, передаёт строки callback-у по мере чтения и затем закрывает process channel. Один и тот же effect покрывает оба вызова: `load_worktrees` собирает/разбирает porcelain-строки, а `stream_claude` разбирает JSON и сразу отправляет text delta.

Это сохраняет текущую потоковую передачу Claude без буферизации всего stdout. Semantic effects вроде `Load_worktrees` и `Stream_claude` отклонены: их fake handler подменял бы разбор и проверку статуса вместе с IO. Раздельные `Open_process`/`Read_line`/`Close_process` отклонены: они раскрывают lifecycle channel-а в вызывающий код и тесты.

### Handler содержит только Unix lifecycle

Построение command/argv, git porcelain state machine, Claude JSON parser, вызов `on_delta` и решение об ошибке при неуспешном status остаются в обычных функциях `Runtime`. Handler отвечает только за `Unix.open_process*_in`, `input_line` и `Unix.close_process_in`.

При исключении из line callback handler всё равно закрывает channel и повторно поднимает исходное исключение. Это сохраняет поведение malformed Claude JSON: процесс завершается, а вызывающий код получает `Yojson.Json_error`.

### Явные production handler boundaries

Основной handler устанавливается вокруг server execution в `main.ml`, чтобы покрыть worktree loading из обычных Eio fibers. Отдельный handler устанавливается внутри callback, передаваемого `Eio.Domain_manager.run`, перед вызовом `Runtime.stream_claude`; handler из родительского domain туда не переносится автоматически.

Прямые тесты `Runtime` устанавливают fake handler сами. Он подаёт заданные строки и status, вызывая тот же line callback, поэтому тестирует parsing и результат без реального процесса.

### Сохранение текущего контракта ошибок

Effect возвращает raw `Unix.process_status`; `Runtime` сохраняет существующее правило: `Unix.WEXITED 0` успешен, остальные статусы приводят к текущему общему failure. Ошибки запуска и чтения остаются исключениями Unix. Новый public result type не вводится.

## Risks / Trade-offs

- [Незакрытый process channel при parser exception] → Handler использует защищённый cleanup и тест покрывает malformed JSON.
- [Unhandled effect в execution context вне основного handler-а] → Отдельно обернуть domain callback и прогнать HTTP streaming-тест.
- [Fake handler расходится с реальным порядком строк] → Fake handler вызывает переданный callback синхронно и в указанном порядке; protocol assertions остаются в `test_runtime`.
- [Прямой вызов `Runtime` без handler-а завершается unhandled effect] → Production entry points и IO-зависимые тесты явно устанавливают соответствующий handler.

## Migration Plan

Изменение не требует миграции данных или развёртывания в несколько фаз. После замены теста выполняются существующие `dune runtest` и ручная проверка Claude streaming. Откат состоит в возврате Unix-вызовов в `Runtime` и удалении handler boundaries.

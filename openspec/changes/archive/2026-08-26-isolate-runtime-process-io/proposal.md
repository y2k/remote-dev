## Why

Тест `Runtime.stream_claude` запускает временный shell-скрипт и изменяет глобальные `PATH` и переменные окружения, хотя проверяет разбор stdout и обработку статуса процесса. `load_worktrees` не имеет столь же изолированного теста. Изоляция process IO позволит проверять оба сценария детерминированно без дочерних процессов.

## What Changes

- Ввести один пользовательский effect для выполнения процесса, построчной передачи stdout и возврата статуса завершения.
- Перенести вызовы `Unix.open_process*_in`, `input_line` и `Unix.close_process_in` в production handler эффекта.
- Сохранить построение команд, разбор git porcelain и Claude stream JSON, передачу delta и проверку статуса обычной логикой `Runtime`.
- Установить production handler в server execution contexts, включая callback, выполняемый через `Eio.Domain_manager.run`.
- Заменить тестовый shell-скрипт и изменения окружения fake handler-ом; покрыть разбор worktree-списка.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет. Наблюдаемое поведение git и Claude CLI, HTTP streaming и UI не изменяются.

## Impact

- Затрагиваются `lib/runtime.ml`, точки запуска в `bin/main.ml` и `lib/server.ml`, а также `test/test_runtime.ml` и тестовый handler для IO-зависимых сценариев.
- Внешние API, CLI-аргументы, зависимости и форматы сообщений не меняются.

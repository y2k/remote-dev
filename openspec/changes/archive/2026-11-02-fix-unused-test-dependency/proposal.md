# Proposal

## Why

`make test` останавливается на проверке `dune build @unused-libs`: тест `test_folder_tabs` объявляет неиспользуемую библиотеку `eio_main`. В его исходнике нет обращений к Eio.

## What Changes

- Удалить `eio_main` только из списка библиотек `test_folder_tabs` в `test/dune`.
- Проверить исправление командой `make test` и ревью изменения.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет: меняется только конфигурация сборки теста; требования `dune-package-management` сохраняются. Установлен `skip_specs: true`.

## Impact

Одна декларация зависимости в `test/dune`. Существующая проверка `@unused-libs` воспроизводит ошибку и служит проверкой исправления.

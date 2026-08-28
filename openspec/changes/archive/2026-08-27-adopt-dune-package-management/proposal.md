## Why

Проект разрешает библиотеки из активного opam-switch, поэтому новый клон требует заранее установить зависимости вручную. Ручные codec-и `result` остаются необходимыми для текущего PPX usage.

## What Changes

- Включить Dune Package Management для обычных команд `dune`.
- Разрешать released `ppx_deriving_yojson` из package repository.
- Создать и добавить в репозиторий `dune.lock` с разрешённым графом compiler и библиотек.
- Сохранить локальные `result_to_yojson` и `result_of_yojson` и их JSON-представление: `["Ok", value]` и `["Error", value]`.
- Обновить инструкции по prerequisites для Dune-managed сборки.

## Capabilities

### New Capabilities
- `dune-package-management`: воспроизводимое получение toolchain и библиотек через Dune.

### Modified Capabilities
- Нет.

## Impact

- Затрагивает `dune-project`, новый `dune-workspace`, `dune.lock` и `README.md`.
- Зависимость `ppx_deriving_yojson` будет разрешаться Dune из package repository вместо активного opam-switch.
- Первые Dune-managed сборка и тесты загрузят и соберут зафиксированные зависимости в `_build`.

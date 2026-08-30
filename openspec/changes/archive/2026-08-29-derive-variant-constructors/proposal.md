## Why

Композиция вложенных TEA-компонентов повторяет однотипные lambda-обёртки вокруг variant constructors для `Components.map`, `Cmd.map` и input builders. `ppx_variants_conv` может генерировать first-class constructor functions и сделать эти места короче без изменения поведения.

## What Changes

- Подключить `ppx_variants_conv` как зависимость и Dune PPX.
- Добавить `[@@deriving variants]` только к типам `msg`, чьи constructor functions реально используются.
- Заменить повторяющиеся lambda-обёртки сгенерированными constructor functions.
- Сохранить существующую JSON-сериализацию, TEA-поток и внешний протокол без изменений.

## Capabilities

### New Capabilities

- Нет: изменение не добавляет наблюдаемого поведения.

### Modified Capabilities

- Нет: изменение является внутренним refactor/tooling change, поэтому specs пропущены.

## Impact

- Затрагиваются `dune-project`, `lib/dune`, `lib/home.ml` и `lib/home_components.ml`.
- В сборку добавляются `ppx_variants_conv` и его runtime dependency `variantslib`; `base` становится транзитивной зависимостью.
- Публичный OCaml API модулей с производными типами расширяется сгенерированными constructor, predicate, accessor и metadata values.

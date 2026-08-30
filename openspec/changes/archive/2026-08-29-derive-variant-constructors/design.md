## Context

См. `proposal.md` для мотивации. Сейчас `Home.msg` и `Worktree.msg` имеют constructor-ы с аргументами, которые нельзя передать как first-class functions без lambda-обёртки. Одни и те же обёртки повторяются в `Components.map` и `Cmd.map`.

Проект уже использует PPX pipeline для `[@@deriving yojson]`, генерирует `remote_dev.opam` из `dune-project` и собирается на OCaml 5.3+. Совместимый `ppx_variants_conv` 0.17 поддерживает этот compiler и текущий `ppxlib`.

## Goals / Non-Goals

**Goals:**

- Генерировать first-class constructor functions для повторно используемых message wrappers.
- Сохранить существующую `yojson` derivation на тех же типах.
- Ограничить применение PPX типами, где generated functions заменяют существующее повторение.

**Non-Goals:**

- Не менять variant constructors, JSON representation, view, update или command semantics.
- Не добавлять `[@@deriving variants]` ко всем variant types.
- Не вводить `.mli` только для сокрытия сгенерированного API.
- Не связывать изменение с незавершённым `dispatch-input-handlers`; его новые input builders могут использовать generated functions отдельно, когда появятся в коде.

## Decisions

### Использовать `ppx_variants_conv` в существующем PPX pipeline

`ppx_variants_conv` добавляется в dependencies `dune-project` и в `(pps ...)` библиотеки рядом с `ppx_deriving_yojson`. Типы используют объединённую аннотацию `[@@deriving yojson, variants]`.

Dune получает `variantslib` через `ppx_runtime_libraries`, поэтому отдельная запись в `(libraries ...)` не нужна. `remote_dev.opam` обновляется генератором Dune, а не вручную.

Альтернатива с локальными constructor functions требует поддерживать те же обёртки вручную и не соответствует принятому решению подключить derivation.

### Derivation применяется выборочно

На текущем коде `variants` добавляется к `Home.msg` и `Worktree.msg`. Сгенерированные `worktrees_msg`, `new_worktree_msg`, `worktree_msg` и `emulator_msg` заменяют соответствующие lambda-обёртки в `Components.map` и `Cmd.map`.

Другие `msg` не аннотируются без использования generated functions. В частности, это избегает генерации `Worktrees.load`, который был бы перекрыт существующим command value `load`.

### Сгенерированный API принимается как часть внутренней библиотеки

Без `.mli` PPX также публикует predicates, accessors и `Variants_of_msg`. Добавление интерфейсных файлов только ради их сокрытия создаст больше поддержки, чем решаемое повторение, поэтому в рамках этого изменения API не ограничивается.

## Risks / Trade-offs

- [Новая зависимость увеличивает dependency и compile surface] -> Зафиксировать совместимую ветку `v0.17` через constraints пакета и применять PPX только к двум типам.
- [Generated names могут конфликтовать с существующими values] -> Аннотировать только проверенные типы и собирать весь проект с warnings.
- [PPX может случайно изменить JSON derivation] -> Сохранить `yojson` в общей deriving-аннотации и прогнать существующие round-trip и server tests.
- [Сгенерированный публичный API шире используемых constructor functions] -> Принять это для текущей внутренней библиотеки; добавить `.mli` только при появлении внешних consumers.

## Migration Plan

1. Добавить dependency и PPX configuration.
2. Добавить выборочные deriving-аннотации и заменить wrapper lambdas.
3. Перегенерировать package metadata штатной сборкой, выполнить formatter и tests.
4. Для отката вернуть lambdas, удалить `variants` derivation и dependency; данные и протокол миграции не требуют.

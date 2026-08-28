## Context

Сейчас проект разрешает библиотеки из активного opam-switch. Для `result` `lib/home_components.ml` использует локальные codec-и, совместимые с released `ppx_deriving_yojson` 3.10.0. См. мотивацию в `proposal.md` и требования в `specs/dune-package-management/spec.md`.

## Goals / Non-Goals

**Goals:**
- Сделать обычные `dune build` и `dune test` независимыми от библиотек активного opam-switch.
- Воспроизводимо выбирать released PPX и весь транзитивный граф зависимостей.
- Сохранить JSON-представление `result` и существующие helpers, от которых зависит PPX expansion.

**Non-Goals:**
- Не обновлять зависимости сверх версий, выбранных при создании первого lockfile.
- Не добавлять CI, альтернативные lock directory или поддержку нескольких compiler configurations.
- Не менять контракт `result-json-codecs`.

## Decisions

### Включить package management явно

Добавить корневой `dune-workspace` с `(pkg enabled)`. Явная настройка не зависит от неявного поведения Dune при наличии `dune.lock` и действует для всех обычных команд проекта.

Альтернатива, использовать `--pkg=enabled` в каждой команде, отвергнута: она не воспроизводится через `make` и документацию.

### Использовать released PPX

Сохранить существующую package dependency `ppx_deriving_yojson` без project-level `pin`. Dune разрешит released версию 3.10.0 из package repository; имя PPX и stanza `pps` не меняются.

Альтернативы:
- Git fork отвергнут: его PPX expansion несовместим с текущими deriving types.
- `opam pin` отвергнут, потому что хранится в одном switch.

### Хранить Dune lock directory в Git

После добавления workspace без Git pin выполнить `dune pkg lock` и добавить созданный `dune.lock` в репозиторий. Lock directory является единственным источником точных версий compiler и транзитивных пакетов для Dune-managed сборок; вручную редактировать его нельзя.

### Сохранить codec `result`

Сохранить ручные `result_to_yojson` и `result_of_yojson` и их прямые тесты. Released PPX использует эти функции для текущих deriving types. Существующие round-trip проверки сообщений `Loaded` и `Finished` дополнительно подтверждают wire format.

### Обновить developer documentation

README будет требовать установленный Dune, но больше не будет требовать заранее установленные зависимости из `remote_dev.opam`. Первый Dune-managed build загрузит compiler и пакеты сам.

## Risks / Trade-offs

- [Первое разрешение и сборка требуют сети и занимают больше времени] → Закоммитить `dune.lock`; повторные сборки используют уже зафиксированный граф.
- [Dune Package Management остаётся экспериментальным] → Ограничить изменение одним workspace и одним стандартным lock directory без дополнительной инфраструктуры.
- [Обновление зависимости не происходит автоматически] → Обновлять dependency и повторно выполнять `dune pkg lock` только отдельным сознательным изменением.

## Migration Plan

1. Добавить Dune workspace без Git pin, затем сгенерировать `dune.lock`.
2. Убедиться, что lock directory фиксирует released `ppx_deriving_yojson` 3.10.0.
3. Сохранить ручные codec-и и их прямые тесты.
4. Запустить `dune build @all` и `dune test`; подтвердить прямые и round-trip JSON проверки для `Ok` и `Error`.
5. Обновить README и проверить команду из инструкции в чистом Dune-managed окружении.

Rollback: удалить workspace и `dune.lock`, затем продолжить использовать текущий opam-switch.

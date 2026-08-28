## Context

`ppx_deriving_yojson` 3.10.0 treats standard `result` as a named external type, so `lib/home_components.ml` supplies local codec-и. Fork commit `b10a96d` makes `result`, `Result.t`, and `Result.result` builtin PPX types and qualifies generated standard `result` constructors to avoid collisions with user-defined `Error` constructors. See `proposal.md` for motivation and `specs/dune-package-management/spec.md` for the changed dependency contract.

## Goals / Non-Goals

**Goals:**
- Разрешать PPX из Git fork через Dune Package Management и фиксировать точный commit в `dune.lock`.
- Удалить application-local workaround, сохранив JSON-массивы `Ok` и `Error`.
- Сохранить проверку message round-trip и проверять decode error для malformed result через HTTP boundary.

**Non-Goals:**
- Не менять публичный JSON wire format успешных или ошибочных result messages.
- Не фиксировать текст decode error для malformed result input.
- Не добавлять CI, release tag или альтернативный package source.

## Decisions

### Использовать project-level Dune pin

Добавить `pin` в `dune-project` с `git+https://github.com/y2k/ppx_deriving_yojson.git` для package `ppx_deriving_yojson`. Project-level pin является частью versioned project configuration; workspace-level pin потребовал бы дополнительного включения в lock directory.

Версия pin остаётся стандартной `dev`, а воспроизводимость обеспечивается Git revision в committed `dune.lock`. При lock generation fork должен разрешиться в `b10a96d`.

Альтернатива, сохранить released 3.10.0 и helpers, отвергнута: она не использует требуемую builtin поддержку fork. Pin на branch или вручную изменённый lockfile отвергнуты: branch не фиксирует revision, а lockfile генерирует Dune.

### Удалить local result codec-и

Удалить `result_to_yojson` и `result_of_yojson`: fork обрабатывает standard `result` до поиска именованных codec-ов. Удалить их прямые tests и оставить round-trip tests сообщений `Loaded` и `Finished`, которые подтверждают сохранённый wire format.

Добавить одну boundary-level проверку malformed result event через `Home.decode`; она должна требовать `Error _`, а не точный error text. Fork возвращает path-based PPX error вместо прежнего literal `"result"`; HTTP server уже преобразует decode error в HTTP 400.

Fork содержит regression test для enclosing variant с `Error of string` и nested standard `result`. PPX должен генерировать квалифицированные constructors runtime `Result`, иначе OCaml связывает `Error` с enclosing variant.

## Risks / Trade-offs

- [Regenerating `dune.lock` can select a newer fork revision] → Проверять Git commit и lockfile diff при каждом сознательном обновлении lock directory.
- [Fork is not a released opam package] → Хранить project pin и resolved commit в Git; не зависеть от активного opam-switch.
- [Malformed request error text changes] → Сохранять HTTP 400 и тестировать только наличие decode error.

## Migration Plan

1. Добавить pin и regenerate `dune.lock`; проверить Git source и resolved commit.
2. Удалить local codec-и и их direct tests; добавить boundary malformed-result assertion.
3. Запустить format, lock validation, build, test и documented `make build`.

Rollback: удалить pin, regenerate `dune.lock` для released package и вернуть local codec-и вместе с direct tests.

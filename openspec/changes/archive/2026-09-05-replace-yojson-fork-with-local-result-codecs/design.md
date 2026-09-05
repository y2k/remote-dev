## Context

Сейчас `dune-project` закрепляет fork `y2k/ppx_deriving_yojson`, а `dune.lock` фиксирует commit `b10a96d`. Fork отличается от upstream встроенной поддержкой `result` и квалификацией генерируемых конструкторов результата. См. мотивацию в `proposal.md` и требование к источнику package в `specs/dune-package-management/spec.md`.

Официальный `ppx_deriving_yojson` 3.10.0 рассматривает `(ok, error) result` как обычный именованный тип и по существующему extension point ищет доступные в scope функции `result_to_yojson` и `result_of_yojson`. Такие функции уже использовались в истории проекта. Все четыре сериализуемых поля с `result` сейчас находятся в `lib/home_components.ml`.

## Goals / Non-Goals

**Goals:**
- Изолировать ручную поддержку `result` в одном небольшом модуле.
- Сохранить текущий JSON wire format и поведение malformed input на HTTP boundary.
- Вернуть dependency graph к официальным release packages.

**Non-Goals:**
- Не менять типы сообщений или публичные имена сгенерированных message codec-ов.
- Не переходить на другой Yojson PPX и не добавлять новый dependency.
- Не стандартизировать текст внутренней decode error для malformed `result`.
- Не добавлять поддержку гипотетических типов, отсутствующих в текущем проекте.

## Decisions

### Использовать официальный `ppx_deriving_yojson` 3.10.0

Удалить project-level Git pin из `dune-project` и перегенерировать `dune.lock`, чтобы package repository разрешил официальный release 3.10.0. Имя dependency и `(pps ppx_deriving_yojson ...)` остаются без изменений.

Альтернативы с сохранением fork или переходом на `ppx_yojson_conv` отвергнуты: первая продолжает сопровождение собственного package source ради двух функций, вторая меняет PPX API и требует несоразмерной миграции.

### Предоставить codec-и через `Result_yojson`

Добавить `lib/result_yojson.ml` с полиморфными `result_to_yojson` и `result_of_yojson`. Serializer кодирует стандартные конструкторы двухэлементными JSON-массивами. Deserializer принимает только эти две точные формы, передаёт payload соответствующему вложенному decoder и возвращает `Error "result"` для неизвестного tag или неверной формы.

Добавить локальный `open Result_yojson` перед `msg` в каждом из четырёх компонентов в `lib/home_components.ml`. Официальный PPX автоматически захватывает функции с ожидаемыми именами; повторять attributes на четырёх полях или менять их типы не требуется.

Альтернатива с функциями непосредственно в `home_components.ml` короче на один файл, но смешивает workaround dependency с TEA-компонентами. Отдельный модуль является явно требуемой границей, а локальные imports остаются рядом с местами использования.

### Проверять codec-и напрямую и через сообщения

В существующем `test/test_remote_dev.ml` добавить прямые assertions для `Ok`, `Error` и malformed JSON. Существующие message round-trip проверки подтверждают интеграцию PPX, а существующая malformed event проверка подтверждает HTTP boundary. Отдельный test executable не нужен.

## Risks / Trade-offs

- [Официальный release 3.10.0 не содержит post-release исправление взаимно рекурсивных variants с одинаковыми конструкторами] -> Текущий проект не содержит затронутых deriving groups; пересмотреть версию или workaround только при появлении такого типа или воспроизведённой ошибке.
- [Ручной codec может случайно изменить wire format] -> Зафиксировать обе точные JSON-формы прямыми assertions и сохранить message round-trip проверки.
- [Regeneration lock directory может затронуть другие packages] -> Использовать `dune pkg lock`, проверить diff и выполнить `dune pkg validate-lockdir` перед build.
- [Текст decode error меняется с path-based значения fork на `"result"`] -> HTTP boundary не раскрывает этот текст; тестировать наличие `Error`, а не его внутреннюю строку.

## Migration Plan

1. Добавить локальный модуль и импорт, затем удалить Git pin.
2. Перегенерировать и проверить `dune.lock`, убедившись, что он содержит официальный `ppx_deriving_yojson` 3.10.0 без Git source.
3. Добавить прямые codec assertions и запустить formatting, lock validation, build и tests.

Rollback: вернуть Git pin, перегенерировать lock directory на commit `b10a96d`, удалить локальный модуль и его прямые tests.

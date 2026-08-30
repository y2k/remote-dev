## Context

См. `proposal.md` для мотивации. Сейчас `lib/home.ml` содержит два слоя: вложенный `module Home` с корневым TEA state/message/view/update и окружающие его функции для HTTP envelope, JSON, глобального `Atomic`-состояния, command dispatch и Claude streaming. `Server` уже владеет HTTP routes, Eio fibers, response writers и выполнением `Runtime`, но вызывает runtime helpers из внешнего `Home`, поэтому публичные пути компонента имеют форму `Home.Home.*`.

Текущий `Components.Cmd` хранит не более одной отложенной команды, а `Server.initialize`, обычный UI streaming и Claude streaming применяют возвращаемые messages к одному глобальному UI-сеансу. Активный change `dispatch-input-handlers` ещё не реализован и планирует добавить revision-aware atomic dispatch поверх этого состояния.

## Goals / Non-Goals

**Goals:**

- Сделать compilation unit `Home` корневым TEA-компонентом той же формы, что модули в `Home_components`: `model`, `msg`, `init`, `view`, `update`.
- Сосредоточить владение изменяемым UI-сеансом и transport/runtime orchestration в `Server`.
- Сохранить текущую последовательность state transitions, команд и streaming documents.
- Оставить подходящую границу для будущего server-owned `{ revision; home }` из `dispatch-input-handlers`.

**Non-Goals:**

- Не менять `Components.Cmd`, не вводить effect algebra или отдельный runtime interpreter.
- Не удалять вызовы `Runtime` и `Sys.argv` из `Home_components`.
- Не менять JSON-представление `Home.msg`, UI-документов или request envelope.
- Не объединять синхронный `Server.response` и Eio request handler и не менять Claude process streaming.
- Не обновлять planning artifacts активного `dispatch-input-handlers` в рамках этого change.

## Decisions

### `Home` становится top-level компонентом

Содержимое вложенного `module Home` переносится на уровень compilation unit. `state` переименовывается в `model`, а типы `screen` и `msg`, navigation helpers, `init`, `view` и `update` сохраняют текущую семантику. После этого потребители используют `Home.model`, `Home.Worktree_msg`, `Home.view` и `Home.update` вместо `Home.Home.*`.

Генерируемые `msg_to_yojson` и `msg_of_yojson` остаются рядом с типом `msg`: button protocol сериализует typed messages, и все дочерние компоненты используют тот же подход. Перенос codec-а в `Server` потребовал бы ручного дублирования variant mapping и не устранил бы JSON codec-и дочерних messages. Transport-level разбор envelope и построение документа при этом из `Home` удаляются.

### `Server` владеет UI-сеансом и command loop

Глобальный `Atomic` переносится в `Server` и хранит `Home.model`. Server-private `step` применяет `Home.update` и фиксирует новую модель; `dispatch` выполняет существующую цепочку `Cmd.run` до `Cmd.none`. `initialize`, синхронный `response` и Eio handler используют это состояние напрямую.

Не вводится новый `App`, `Session` или `Home_runtime` module: единственный потребитель этой обвязки уже `Server`, а дополнительный compilation unit только перенесёт те же функции без новой границы поведения. Когда `dispatch-input-handlers` добавит revision, `Server` сможет заменить значение atomic на `{ revision; home : Home.model }`, не меняя component model.

### HTTP и JSON преобразования остаются на серверной границе

`request`, `decode_request`, input marker replacement и message decode переносятся в `Server`. Рендеринг документа строится как `Home.view model`, затем сериализуется через `Components.to_json Home.msg_to_yojson`; pretty и compact формы остаются деталями соответствующих HTTP/streaming ответов.

Неиспользуемые `trace`, `event` и `Home.response` удаляются вместо переноса. Существующий `Server.response` сохраняется как синхронный test seam и продолжает использовать тот же state transition path, что и Eio handler.

### Streaming orchestration остаётся специальным server path

Распознавание `Home.Worktree_msg (Worktree.Run_claude prompt)`, получение cwd из текущего `Home.Worktree` model, запуск `Runtime.stream_claude` и запись incremental документов остаются в `Server`. Delta и error messages применяются через общий server-owned `dispatch`, после чего сериализуется новый `Home.view`.

Альтернатива выразить Claude stream через новый вариант `Cmd` отклонена: это расширило бы refactoring изменением effect model и затронуло бы все command runners. Server будет знать конкретный root message и screen ровно в этом существующем специальном transport path; сам `Home` не будет знать о response writer, Eio или stream lifecycle.

### Проверки следуют новой границе ownership

Проверки чистой композиции и переходов используют `Home.*`. Проверки request decode, global state, command execution, HTTP responses и streaming helpers используют `Server.*`. Существующие JSON equality assertions сохраняются, чтобы механический перенос не изменил внешний протокол.

Отдельные новые test files и test framework не требуются: текущий `test/test_remote_dev.ml` уже покрывает обе стороны границы и позволяет проверить рефакторинг заменой существующих ссылок.

## Risks / Trade-offs

- [Механический перенос случайно меняет JSON events или документы] -> Сохранить определения `msg` и тела `view`/`update`, затем выполнить существующие equality и round-trip проверки.
- [Синхронный и Eio server paths расходятся после переноса] -> Оба пути должны использовать одни server-owned decode, step и document helpers; не рефакторить сами HTTP handlers сверх необходимой замены вызовов.
- [Server сильнее знает внутренние варианты `Home` для Claude streaming] -> Это уже существующая специальная связь; локализовать её в server streaming path и не расширять component API вспомогательным stream abstraction.
- [Активный `dispatch-input-handlers` ссылается на старые `Home.state` и `Home.decode`] -> Реализовать этот change первым, затем отдельно обновить его design/tasks под server-owned session до apply.
- [Внешний OCaml-код мог использовать прежние `Home.Home.*` или runtime helpers] -> Проект не объявляет стабильный OCaml library API; обновить все repository callers и не добавлять compatibility aliases.

## Migration Plan

1. Превратить вложенный `Home.Home` в top-level TEA API без изменения component transitions.
2. Перенести session state, decode/encode, command dispatch и stream helpers в `Server`, удалив неиспользуемые helpers.
3. Перевести существующие проверки на новые component/server paths и подтвердить неизменность документов, HTTP и streaming.
4. Выполнить `dune fmt` и `dune test`.

Сохранённых данных и поэтапного выпуска нет. Откат ограничивается возвратом внутреннего расположения функций; Android-клиент и HTTP-протокол не мигрируют.

## Context

См. `proposal.md` и delta specs. Сейчас путь repository читается из `Sys.argv` внутри `Worktrees`, `Run_claude` напрямую определяет streaming route, а `Runtime.stream_claude` извлекает только Claude text deltas. Модель выбранного worktree не хранит CLI session ID. OpenCode 1.18.20 предоставляет `run --dir <path> --format json`, печатает completed text parts и session ID, поддерживает явный `--session`, command mode и `--auto`.

Активный change `dispatch-input-handlers` меняет тот же command input и server decoder. Этот change проектируется поверх его handler-based input API и не должен реализовываться раньше него.

## Goals / Non-Goals

**Goals:**
- Передать неизменяемые startup agent и repository root явно через TEA boundary без чтения process arguments в компонентах.
- Сохранить один UI и один HTTP streaming path для обоих CLI при разных stdout-протоколах.
- Продолжать только session текущего открытого worktree по явному ID.
- Не допустить запуска Claude из OpenCode process mode даже для непубликованного UI message.

**Non-Goals:**
- Унифицировать внутренние модели, permission systems или token streaming двух CLI.
- Хранить transcript или session ID после `Back` и рестарта backend.
- Добавлять cancellation, timeout, OpenCode daemon, model selection или OpenCode worktree creation.
- Исправлять существующую семантику `claude --worktree`.

## Decisions

### Startup configuration is explicit TEA environment

`main` использует стандартный `Arg` для обязательного `--agent` с точными значениями `claude` и `opencode` и одного необязательного anonymous repository path. Результат становится неизменяемым environment `{ agent; root }`, передаваемым в `Server.run`, `Home.init`, `Home.view` и `Home.update`. Agent не хранится в `Home.model`, и message для его изменения не существует.

Это одновременно удаляет текущее скрытое чтение `Sys.argv` из `Worktrees` и оставляет view/update чистыми функциями. Глобальное чтение arguments из `Runtime` отклонено: оно скрывает зависимость и мешает проверять оба режима в одном test process. Default agent отклонён, потому что оператор должен сделать режим явным.

Корневой `Home.view` добавляет статический agent label перед текущим screen content. `Worktrees.view` публикует `New` только для Claude; `Worktree.view` публикует Claude-specific shortcuts только для Claude. `Home.update` также не переводит OpenCode mode в creation screen, поэтому скрыто сконструированный event не достигает `Runtime.create_worktree`; конкретный HTTP response для такого непубликованного event не становится контрактом.

### One generic prompt message selects one fixed runtime

Domain message `Run_claude` становится agent-neutral `Run_prompt`; startup environment, а не event payload, определяет CLI. Server streaming request фиксирует agent, cwd, prompt и текущий optional session ID до запуска background process. Клиент не может подменить agent или session ID.

`Runtime` имеет один общий streaming entry point с match по двум конкретным agent variants. Claude сохраняет child-only `cd` shell wrapper, существующие stream-json flags и локальные permissions; при наличии session ID добавляется explicit resume. OpenCode запускается через argument vector без shell с `run`, `--dir`, `--format json`, `--auto` и optional `--session`.

Отдельный long-running `opencode serve` отклонён: выбранная CLI уже предоставляет нужный one-shot interface, а daemon добавил бы lifecycle, порт и SSE API только ради более мелких text updates.

### OpenCode slash commands use command mode

Перед OpenCode invocation input trim-ится только для распознавания команды. Если первая непустая часть имеет вид `/name`, имя без `/` передаётся как command, а оставшаяся строка как arguments. Одиночный `/` и любой другой input остаются обычным prompt. Разбор использует операции `String`, а не `Arg`: input является одной HTTP-строкой, не process command line.

Неизвестная command завершается обычной ошибкой OpenCode. Fallback к prompt отклонён, поскольку command уже могла частично изменить worktree до ошибки и повторный model run был бы неявным вторым выполнением.

### Session ID is hidden worktree state

`Worktree.model` получает `session_id : string option`. Первый prompt запускается без resume option; каждый распознанный CLI session event отправляет внутреннее `Session_started` message. Server применяет это message к модели без отправки отдельного UI-документа, поскольку view не меняется. Следующие prompt используют сохранённый ID. `Run_prompt` очищает только output и error, сохраняя session ID.

`Back` уже удаляет весь `Worktree.model`, поэтому отдельная session map, reset button и persistence не нужны. CLI-owned conversation остаётся в обычном локальном хранилище. ID, полученный до process failure, сохраняется; неуспешный resume не очищает его и не повторяет prompt. Это оставляет `Back` единственным явным способом начать новый разговор.

Не используется `--continue`: он выбирает последнюю session по директории и может подхватить разговор из TUI или другого процесса вместо session, созданной текущим экраном.

### Provider parsers emit the same internal stream events

Claude parser извлекает session ID из init event и сохраняет текущую обработку `text_delta`. OpenCode parser извлекает top-level `sessionID` и completed text из `type = "text"` с text part. Correct unknown JSON events игнорируются. Каждый parser выдаёт общие внутренние события `Session` и `Text`, не передавая provider JSON в Android.

Runtime отслеживает первый reported ID и проверяет каждый последующий. Malformed JSON, отсутствие ID при successful exit, ID отличный от requested resume ID и несколько разных ID вызывают отдельный fatal protocol exception. Server не преобразует это исключение в `Worktree.Finished (Error ...)`, а позволяет ему завершить backend. Process start/exit failures после корректного protocol data продолжают использовать существующий финальный UI error и не завершают backend.

Альтернатива считать отсутствие ID новой session отклонена: это молча нарушило бы обещанное продолжение разговора. Token-level OpenCode output не синтезируется; каждый completed part становится одной добавленной text portion и одним полным NDJSON UI document.

### Documentation and tests stay process-local

README показывает обязательный `--agent`, условные prerequisites, OpenCode 1.18.20+, отсутствие OpenCode worktree creation и усиленное trusted-LAN предупреждение для `--auto`. Availability/version preflight не добавляется.

Runtime checks используют существующий effect-based fake process и проверяют argv, оба JSON formats, session capture/resume, slash command routing, process failures и fatal protocol violations. Home/server checks покрывают immutable label, conditional controls, session lifecycle и отсутствие запуска Claude в OpenCode mode. Реальные authenticated CLI не запускаются в automated tests.

## Risks / Trade-offs

- [OpenCode `--auto` одобряет все effective `ask`, включая external paths и `.env`] -> Сохранить explicit deny rules и prominent trusted-LAN warning; не утверждать, что `--auto` является sandbox.
- [OpenCode показывает completed text parts, а не token deltas] -> Сохранить существующий NDJSON transport и принять более редкие UI updates; переходить на server/SSE только отдельным change.
- [Изменение provider JSON сломает parser] -> Документировать baseline 1.18.20 и завершать backend при malformed protocol вместо молчаливой потери session continuity.
- [Session остаются в локальной истории после `Back`] -> Не вводить несовместимый cross-provider cleanup; управление сохранёнными sessions оставить соответствующему CLI.
- [Обязательный `--agent` ломает прежние startup commands] -> Обновить Makefile forwarding и README examples вместе с backend argument parser.

## Migration Plan

1. Сначала реализовать и архивировать `dispatch-input-handlers`.
2. Добавить startup parser/environment, conditional UI и generic prompt message, сохраняя Claude mode работоспособным.
3. Добавить session protocol для Claude, затем OpenCode parser/invocation и fake-process checks.
4. Обновить README и запускать backend только с явным `--agent`.
5. Для rollback вернуть предыдущую версию backend и убрать `--agent` из startup command; сохранённые CLI sessions и Git worktrees не требуют миграции.

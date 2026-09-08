## Context

См. `proposal.md` и delta specs. Сейчас `Home` всегда начинает с worktree list, `Worktree.model` хранит скрытый `session_id`, а `Server.respond` держит Android request открытым, пока отдельный CLI process печатает текущий response. Android в это время сериализует события и отключает controls.

OpenCode 1.18.20 предоставляет локальный HTTP server, где session уже содержит `id`, `title`, `directory` и timestamps. Stable `/session` перечисляет sessions только одного project, а `/experimental/session` перечисляет sessions всех projects. REST API также возвращает messages, directory-scoped status и pending permission/question requests, принимает asynchronous prompt и abort. Endpoint slash command возвращает ответ синхронно. `httpun-eio` уже предоставляет client connection поверх имеющегося Eio network capability.

## Goals / Non-Goals

**Goals:**
- Оставить OpenCode единственным source of truth для session metadata, transcript и run status.
- Освободить Android request сразу после принятия prompt, чтобы background run не блокировал navigation и refresh.
- Сохранить Claude process, stream и worktree behavior отдельной неизменённой веткой TEA.
- Использовать существующий HTTP stack без новой package dependency.

**Non-Goals:**
- Управлять lifecycle `opencode serve`, выбирать его address или подключаться к server по LAN.
- Создавать, удалять, переименовывать, архивировать или публиковать sessions.
- Рендерить tool calls, reasoning, diffs или token deltas.
- Отвечать на permissions и questions из Android.
- Подписываться на OpenCode SSE events или автоматически polling-овать UI.
- Переводить Claude на background agents, Channels, Remote Control или Agent SDK.

## Decisions

### OpenCode server is an external localhost service

Оператор запускает `opencode serve --hostname 127.0.0.1 --port 4096`, а terminal client при необходимости использует `opencode attach http://127.0.0.1:4096`. Backend всегда подключается к этому точному endpoint и не принимает отдельную URL option.

Это позволяет Android и TUI управлять одной process-local run state. Запуск второго server из remote_dev отклонён: он не увидит active runs первого server и добавит ownership, shutdown и port-selection behavior. Configurable endpoint отклонён до реального требования; OpenCode server намеренно остаётся за LAN-facing remote_dev backend.

### Startup environment makes provider states explicit

`Runtime.environment` становится provider-specific variant: Claude несёт repository root, OpenCode не несёт root. Argument parser принимает optional positional root только с `--agent claude` и отклоняет его с `--agent opencode`, вместо хранения неиспользуемого значения.

`Home.init` выбирает initial screen по environment. Claude сохраняет `Worktrees`, `New_worktree` и `Worktree`; OpenCode получает `Sessions` и `Session`. Общий root model продолжает хранить emulator отдельно. Это меньше и безопаснее, чем добавлять session fields в существующие worktree models или поддерживать одновременно выбранные worktree и session.

### REST operations reuse the Runtime effect boundary

Runtime получает один testable HTTP request effect рядом с существующими process effects. Production handler открывает localhost connection через `Httpun_eio.Client`, отправляет request, полностью читает небольшой JSON response и закрывает connection. Один connection на operation выбран вместо pool: manual refresh и single-user UI не оправдывают lifecycle shared connection.

Глобальный list выполняется через `/experimental/session` без directory и проходит все страницы по cursor последней записи. Чтобы показать status каждой session, backend группирует результат по уникальной паре directory/workspace и запрашивает `/session/status` для каждой группы; отсутствие session ID в status map означает `idle`. Selected detail аналогично запрашивает messages, status, permissions и questions с directory и workspace выбранной session и фильтрует pending requests по её ID.

Для GET official SDK передаёт percent-encoded directory и workspace в query, для POST -- directory в `x-opencode-directory` header и workspace в query; backend повторяет это wire behavior и кодирует значения ровно один раз. Session ID, agent и model берутся только из server response; prompt и command arguments кодируются в JSON, а follow-up явно сохраняет agent/model session. Backend проверяет HTTP status и ожидаемую JSON shape, но игнорирует неизвестные object fields для совместимости с добавлениями protocol.

Shelling out to `curl` отклонён как новая неописанная runtime dependency. Ручной socket-level HTTP parser отклонён, поскольку уже установленный `httpun-eio` поддерживает client side.

### OpenCode TEA models contain only the displayed snapshot

`Sessions.model` хранит последний загруженный список summary rows и UI error. `Session.model` хранит выбранные server metadata, последний textual transcript snapshot, status, pending-input flag, prompt text и UI error. Это view state, а не дублирующее persistence: каждый Refresh заменяет snapshot данными OpenCode.

Session list объединяет `/experimental/session` с directory-scoped `/session/status`. Selected detail отдельно объединяет messages, status, `/permission` и `/question` по session ID; pending permission или question отображается как needs-input поверх обычного run status. Selected view показывает role labels и `text` parts в server order; остальные part variants пропускаются.

Если выбранная session исчезла, update возвращает root session list с ошибкой. Он не выбирает другую session и не создаёт replacement.

### Prompt submission is detached from response rendering

Обычный input вызывает `/session/{id}/prompt_async` с одним text part. После `204` TEA очищает input и возвращает обычный complete UI document; response text появится только после Refresh. Старый OpenCode NDJSON response stream и parser удаляются, а Claude special streaming route остаётся.

Существующий slash parser сохраняется. Lone `/` идёт в `prompt_async`; распознанная command идёт в `/session/{id}/command`. Поскольку command endpoint может ждать agent response, server запускает этот HTTP call как Eio fiber под application switch и сразу отвечает Android. Success не записывает transcript локально; failure записывает UI error только если та же session всё ещё выбрана. Автоматический fallback command в prompt остаётся запрещён.

Persistent OpenCode SSE subscription отклонена: Android всё равно не имеет независимого inbound stream, а текущий indefinite event response отключил бы input и Stop. Manual Refresh уже является поддержанным client interaction и даёт полный authoritative snapshot.

### Refresh becomes a provider-neutral root event

Android заменяет hard-coded `Worktrees_msg Load` на root `Refresh`. `Home.update` маршрутизирует его в текущий screen: reload worktrees для Claude, reload all sessions для OpenCode root и reload selected session для OpenCode detail. Existing command NDJSON lifecycle используется для этих finite loads без изменения UI node protocol.

Back из OpenCode detail возвращает загруженный session list. Back на root screen остаётся no-op. Stop отображается только при `busy`, вызывает `/abort`, затем выполняет тот же detail reload.

## Risks / Trade-offs

- [OpenCode server не запущен или запущен на random default port] -> Показать connection error и документировать explicit `--port 4096`; backend остаётся доступным.
- [Manual Refresh показывает не самый свежий transcript] -> Это intentional first slice; добавить Android polling или push transport только при подтверждённой необходимости.
- [Session блокируется на permission или question] -> Показать needs-input и направить пользователя в attached OpenCode TUI; remote replies остаются отдельным change.
- [Blocking slash command живёт дольше Android request] -> Запустить request в application-scoped Eio fiber и отобразить только transport failure; OpenCode остаётся владельцем command state.
- [OpenCode добавляет новые JSON fields или part variants] -> Парсить нужные fields структурно, игнорировать unknown fields и non-text parts, но считать missing required fields protocol failure текущей operation.
- [`/experimental/session` меняется между OpenCode versions] -> Зафиксировать baseline 1.18.20, покрыть exact response decoder test и обновлять integration при фактическом protocol change.
- [Все projects server становятся видимы через trusted-LAN backend] -> Сохранить существующую single-user trusted-LAN модель и localhost-only OpenCode endpoint; не расширять network exposure.

## Migration Plan

1. Добавить OpenCode HTTP boundary и protocol parsing, не меняя Claude process boundary.
2. Добавить OpenCode Sessions/Session TEA components и provider-specific Home navigation.
3. Перевести OpenCode submit/abort на REST и оставить Claude streaming route прежним.
4. Обновить Android Refresh event, README и process-local tests; после `.ml` изменений выполнить `dune fmt`.
5. Перед запуском нового OpenCode mode оператор запускает fixed-port server и при необходимости подключает TUI к тому же URL.
6. Для rollback остановить backend, вернуть предыдущую версию и снова запускать `--agent opencode <root>`; OpenCode-owned sessions и files не требуют migration.

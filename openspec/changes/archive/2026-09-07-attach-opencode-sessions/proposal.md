## Why

OpenCode mode сейчас скрывает сохранённые разговоры за выбором Git worktree и запускает отдельный `opencode run` для каждого prompt. OpenCode server уже предоставляет адресуемые sessions, transcript и background execution, поэтому session должна стать основным объектом OpenCode UI.

## What Changes

- **BREAKING** OpenCode mode заменяет список worktree на список существующих OpenCode sessions и больше не создаёт session первым prompt выбранного worktree.
- **BREAKING** OpenCode mode показывает все sessions известные server и больше не принимает positional repository root; directory становится атрибутом каждой session. Claude mode сохраняет optional root.
- Backend подключается к отдельно запущенному `opencode serve` на `127.0.0.1:4096`; server остаётся недоступным из LAN напрямую.
- Глобальный список читается через OpenCode 1.18.20 `/experimental/session`, поскольку стабильный `/session` ограничен одним project.
- Session list показывает title, directory и status, а выбранная session показывает её текстовый transcript.
- Follow-up prompt отправляется асинхронно в точную выбранную session; Android request завершается до окончания agent run.
- Пользователь может вручную обновить session list или transcript/status и остановить busy session.
- Session, ожидающая permission или question, только показывает состояние ожидания; ответ остаётся в OpenCode TUI.
- Claude mode сохраняет текущую worktree navigation, CLI streaming и session continuation без изменений.

## Capabilities

### New Capabilities
- `opencode-session-attachment`: Обнаружение существующих OpenCode sessions, просмотр transcript/status, асинхронный follow-up и остановка выбранной session через локальный OpenCode server.

### Modified Capabilities
- `startup-agent-mode`: OpenCode mode не принимает repository root, использует фиксированный локальный server endpoint и сообщает недоступность server при загрузке UI; Claude startup contract не меняется.
- `opencode-cli-execution`: One-shot `opencode run`, CLI JSON parsing и `--auto` заменяются OpenCode REST operations над существующей session.
- `agent-session-continuation`: Worktree-scoped hidden session ID и response-only rendering остаются только в Claude mode.
- `worktree-navigation`: Worktree list и selected-worktree navigation остаются только в Claude mode; OpenCode mode использует session navigation.
- `worktree-chat-layout`: OpenCode больше не отображает selected-worktree layout; существующий layout остаётся Claude-specific.
- `android-backend-driven-ui`: Manual refresh отправляет provider-neutral root event, чтобы обновлять текущий Claude worktree list или OpenCode session screen.
- `eio-http-server`: Начальное UI state и provider-neutral Refresh загружают текущий Claude worktree или OpenCode session screen.

## Impact

- Изменятся `Runtime`, `Home`, OpenCode-specific TEA components и server prompt dispatch; Claude process path останется существующим.
- `httpun-eio`, уже присутствующий в проекте, будет использоваться как HTTP client к OpenCode server; новая dependency не требуется.
- OpenCode integration принимает риск experimental global-session endpoint; изменение его protocol потребует обновления backend decoder.
- Android заменит refresh event и добавит один видимый Refresh action; UI nodes и HTTP document protocol останутся прежними.
- README и tests будут обновлены для обязательного `opencode serve --hostname 127.0.0.1 --port 4096`, session-centric OpenCode UI и нового async lifecycle.

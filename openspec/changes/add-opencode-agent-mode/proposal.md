## Why

Backend сейчас всегда запускает Claude CLI, поэтому локально настроенный OpenCode нельзя использовать из Android-клиента. Агент должен выбираться один раз при старте backend и оставаться неизменным, чтобы поведение процесса и доступные действия UI были однозначными.

## What Changes

- **BREAKING**: запуск backend требует `--agent claude|opencode`; путь репозитория остаётся необязательным позиционным аргументом.
- Показывать выбранный agent во всех backend-defined UI-документах без возможности переключить его через UI.
- Выполнять prompt через выбранный CLI и продолжать созданную им сессию, пока открыт текущий worktree.
- Запускать OpenCode отдельной командой `opencode run` для каждого prompt, с JSON output, `--auto` и обычной локальной конфигурацией модели.
- Распознавать ведущий `/command` в OpenCode input и выполнять его через CLI command mode; неизвестную команду не повторять как обычный prompt.
- В режиме OpenCode скрывать создание worktree и Claude-specific prompt shortcuts; режим Claude сохраняет существующее создание через `claude --worktree` и текущие shortcuts.
- Считать malformed CLI JSON, отсутствующий session ID и изменение session ID фатальным нарушением протокола; обычный process failure по-прежнему отображать как UI-ошибку.

## Capabilities

### New Capabilities
- `startup-agent-mode`: Обязательный неизменяемый выбор Claude или OpenCode при старте backend и его отражение в UI.
- `opencode-cli-execution`: Non-interactive выполнение OpenCode prompt и slash-команд с JSON output, локальными настройками и auto-approved permission requests.
- `agent-session-continuation`: Явная привязка последовательных prompt выбранного worktree к одной CLI session до выхода с экрана.

### Modified Capabilities
- `claude-cli-execution`: Claude invocation сообщает session ID и возобновляет явно выбранную session для следующих prompt.
- `worktree-creation-ui`: Кнопка и обработка создания worktree доступны только в Claude startup mode.
- `worktree-prompt-shortcuts`: Claude-specific shortcuts публикуются только в Claude startup mode.

## Impact

- Затрагиваются startup parsing, неизменяемое окружение `Home`, backend-defined view, server streaming dispatch, runtime process adapters, OCaml tests и README.
- Android production-код и HTTP envelope не меняются; клиент продолжает отображать полные JSON/NDJSON UI-документы и пересылать opaque events.
- Для режима OpenCode требуется локальный `opencode` версии 1.18.20 или новее; runtime version check и CLI availability preflight не добавляются.
- Реализация change должна выполняться после `dispatch-input-handlers`, поскольку оба change затрагивают command input и server dispatch.

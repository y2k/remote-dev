## ADDED Requirements

### Requirement: Stream finite provider UI commands
Когда обработка backend-defined UI-события создаёт обычную конечную UI-команду, система SHALL вернуть `application/x-ndjson`. Каждая непустая строка response SHALL быть одним компактным полным UI-документом: первым документом для модели сразу после `update`, а каждым следующим — для модели после сообщения от команды. Система SHALL закрыть response после завершения команды, не ожидая завершения внешнего Claude-агента.

#### Scenario: Return reloads agents
- **WHEN** активен Claude chat и событие Back создаёт команду загрузки списка агентов
- **THEN** клиент получает документ списка до результата загрузки и обновлённый документ после него в том же конечном NDJSON response

#### Scenario: Command reports a UI error
- **WHEN** обычная UI-команда завершается сообщением об ошибке
- **THEN** финальная строка NDJSON response является полным UI-документом, отображающим ошибку

## REMOVED Requirements

### Requirement: Stream ordinary UI command lifecycle
**Reason**: The former lifecycle included worktree-return commands, which are retired.
**Migration**: Use `Stream finite provider UI commands` for before/after full-document responses, including agent-list navigation without waiting for an external agent turn.

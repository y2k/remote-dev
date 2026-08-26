# ui-command-streaming Specification

## Purpose

Позволяет клиенту наблюдать модель до и после обычной UI-команды в одном HTTP-ответе.

## Requirements

### Requirement: Stream ordinary UI command lifecycle
Когда обработка backend-defined UI-события создаёт обычную UI-команду, система SHALL вернуть `application/x-ndjson`. Каждая непустая строка response SHALL быть одним компактным полным UI-документом: первым документом для модели сразу после `update`, а каждым следующим -- для модели после сообщения, полученного от команды. Система SHALL закрыть response после завершения команды.

#### Scenario: Return reloads worktrees
- **WHEN** активен selected-worktree document и событие `back` создаёт команду загрузки списка worktree
- **THEN** клиент получает worktree-list document до результата загрузки и обновлённый worktree-list document после него в том же NDJSON response

#### Scenario: Command reports a UI error
- **WHEN** обычная UI-команда завершается сообщением об ошибке
- **THEN** финальная строка NDJSON response является полным UI-документом, отображающим ошибку

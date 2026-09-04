# worktree-creation-ui Specification

## Purpose

Позволяет создать worktree из списка по имени новой ветки, не требуя выбирать путь worktree в UI.

## Requirements

### Requirement: Start new worktree creation
When the backend startup agent is Claude, the system SHALL provide an interactive `New` button in the worktree-list document that opens the worktree creation UI. When the startup agent is OpenCode, the system SHALL omit that button and SHALL NOT advertise worktree creation.

#### Scenario: User opens creation UI
- **WHEN** the backend runs in Claude mode and the user sends the advertised `New` button event from the worktree-list document
- **THEN** the system returns a document with a branch-name input

#### Scenario: Worktree list is rendered in OpenCode mode
- **WHEN** the backend returns the worktree-list document in OpenCode mode
- **THEN** the document contains no `New` button or other advertised worktree-creation action

### Requirement: Accept a new branch name
Система SHALL принимать непустое строковое значение поля имени ветки через текущий input event envelope и запускать одноразовую сессию локального Claude CLI, создающую Git worktree с этим именем. Пользователь не обязан выбирать путь worktree, существующую ветку или начальную ревизию.

#### Scenario: User submits a branch name
- **WHEN** пользователь отправляет непустое имя из UI создания и Claude CLI успешно завершает создание worktree
- **THEN** система возвращает обновлённый документ списка worktree, содержащий созданный worktree

#### Scenario: Worktree creation fails
- **WHEN** пользователь отправляет имя из UI создания и Claude CLI не может создать worktree
- **THEN** система возвращает UI создания с сообщением об ошибке и не изменяет отображаемый список worktree

#### Scenario: User submits an empty name
- **WHEN** пользователь отправляет пустое имя из UI создания
- **THEN** система возвращает UI создания с сообщением об ошибке, не запуская Claude CLI

### Requirement: Return from creation UI
Система SHALL обрабатывать событие `back` в UI создания worktree, возвращая документ списка worktree.

#### Scenario: User leaves creation UI
- **WHEN** UI создания worktree активно и система получает событие `back`
- **THEN** система возвращает документ списка worktree

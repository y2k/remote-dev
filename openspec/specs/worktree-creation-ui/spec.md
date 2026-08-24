# worktree-creation-ui Specification

## Purpose

Позволяет начать создание worktree из списка, запросив имя новой ветки без выполнения Git-операций.

## Requirements

### Requirement: Start new worktree creation
Система SHALL предоставлять в документе списка worktree интерактивную кнопку `New`, которая открывает UI создания worktree.

#### Scenario: User opens creation UI
- **WHEN** пользователь отправляет событие кнопки `New` из документа списка worktree
- **THEN** система возвращает документ с полем ввода имени новой ветки

### Requirement: Accept a new branch name
Система SHALL принимать строковое значение поля имени ветки через текущий input event envelope без требования выбирать существующую ветку или начальную ревизию.

#### Scenario: User submits a branch name
- **WHEN** пользователь отправляет имя ветки из UI создания
- **THEN** система успешно возвращает документ UI создания без создания Git-ветки, Git-worktree или изменения списка worktree

### Requirement: Return from creation UI
Система SHALL обрабатывать событие `back` в UI создания worktree, возвращая документ списка worktree.

#### Scenario: User leaves creation UI
- **WHEN** UI создания worktree активно и система получает событие `back`
- **THEN** система возвращает документ списка worktree

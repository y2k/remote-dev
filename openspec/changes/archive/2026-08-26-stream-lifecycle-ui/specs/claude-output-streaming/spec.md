## MODIFIED Requirements

### Requirement: Preserve non-streaming UI events
Система SHALL возвращать единственный `application/json` UI-документ для каждого допустимого UI-события, которое не запускает обычную UI-команду и не запускает Claude output stream.

#### Scenario: Client loads or navigates
- **WHEN** клиент отправляет допустимое событие `select_worktree`, `set_prompt`, `new_worktree` или `create_worktree`, не запускающее команду
- **THEN** сервер возвращает один полный UI-документ с `application/json`

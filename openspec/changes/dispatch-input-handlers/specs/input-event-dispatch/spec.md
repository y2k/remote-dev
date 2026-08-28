## Purpose

Позволяет backend-defined UI безопасно и композиционно превращать ввод одного поля в объявленный компонентом Elm message без шаблонов значений в JSON-событиях.

## ADDED Requirements

### Requirement: Publish input handler selectors
Система SHALL публиковать для каждого `input` непрозрачный JSON event selector, идентифицирующий этот input в конкретной ревизии возвращённого UI-документа. Selector SHALL NOT содержать строковый маркер `"__VALUE__"` или сериализованное значение, предназначенное для последующей подстановки.

#### Scenario: Render branch input
- **WHEN** система возвращает UI создания worktree
- **THEN** событие поля имени ветки содержит selector обработчика input, привязанный к этой ревизии документа

#### Scenario: Render nested input
- **WHEN** input находится внутри произвольной вложенности `column`, `row` и отображений компонентов
- **THEN** система публикует selector, который однозначно адресует этот input без page-specific протокольного кода

### Requirement: Dispatch submitted input as a component message
Система SHALL при получении актуального input selector и строкового `value` вызвать обработчик input из соответствующего UI-дерева и применить созданный им message обычным путём обработки UI-событий. Значение SHALL передаваться обработчику без подстановки в JSON.

#### Scenario: Submit branch name
- **WHEN** клиент отправляет актуальный selector поля имени ветки со значением `feature/foo`
- **THEN** система запускает существующую обработку создания worktree с именем `feature/foo`

#### Scenario: Submit Claude prompt
- **WHEN** клиент отправляет актуальный selector поля команды выбранного worktree со значением `review this MR`
- **THEN** система запускает существующую обработку Claude с prompt `review this MR`

### Requirement: Reject invalid input selectors
Система MUST отклонять input event, если selector не принадлежит текущей ревизии UI-документа, не адресует input или имеет недопустимую структуру. Отклонённое событие SHALL NOT менять UI-state и SHALL NOT запускать команду.

#### Scenario: Submit a stale input selector
- **WHEN** клиент отправляет selector из документа, который уже заменён более новой ревизией
- **THEN** система отвечает ошибкой и не применяет значение к текущему экрану

#### Scenario: Submit a selector for a non-input node
- **WHEN** клиент отправляет selector, не указывающий на опубликованный input
- **THEN** система отвечает ошибкой и не запускает действие

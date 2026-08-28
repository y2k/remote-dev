## Why

Форма `New worktree` принимает имя, но ничего не создаёт, поэтому пользователь не может начать работу на новой ветке из клиента. Локальный Claude CLI уже умеет создать Git worktree для сессии через `--worktree`, что устраняет необходимость выбирать путь worktree в UI.

## What Changes

- Заменить заглушку отправки имени в UI создания worktree на одноразовый запуск Claude CLI с `--worktree`.
- Завершать запуск после короткого ответа Claude и затем перезагружать список worktree.
- Показывать ошибку создания в UI формы, не меняя список при неуспехе.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `worktree-creation-ui`: Отправка имени создаёт worktree через Claude CLI и обновляет список после успеха вместо no-op.

## Impact

- Изменяются `lib/home_components.ml`, `lib/home.ml` и `lib/runtime.ml`.
- Дополняются проверки создания и ошибок в `test/test_remote_dev.ml` и `test/test_runtime.ml`.
- Используется уже установленный Claude CLI; новые зависимости и изменения Android-протокола не нужны.

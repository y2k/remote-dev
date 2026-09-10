## Why

Локальный OpenCode запущен с паролем и возвращает `401 Unauthorized` с требованием Basic Auth. Backend `remote_dev` не передаёт авторизацию, поэтому не может загрузить сессии даже при наличии `OPENCODE_SERVER_PASSWORD` в окружении.

## What Changes

- Передавать HTTP Basic Auth во всех запросах backend к OpenCode, если в окружении backend задан непустой `OPENCODE_SERVER_PASSWORD`.
- Всегда использовать имя пользователя `opencode`; без пароля сохранять запросы без авторизации.
- Документировать передачу одинаковых учётных данных серверу OpenCode и отдельно запускаемому backend.
- Проверить формирование заголовка и сохранение обработки отказа в авторизации.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

- `opencode-session-attachment`: подключение к локальному серверу с Basic Auth из окружения backend.

## Impact

Изменения затрагивают общий HTTP-путь в `lib/runtime.ml`, проверки в `test/test_runtime.ml` и инструкцию запуска в `README.md`. Адрес сервера остаётся `127.0.0.1:4096`; Android не получает учётные данные. Добавляется библиотека `base64` для кодирования заголовка.

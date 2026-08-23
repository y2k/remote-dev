## Why

Обработка одного UI-действия описана двумя разными конструкторами: `Set_prompt` для view и `Prompt_selected` для update. Это создаёт лишнее преобразование и вынуждает придумывать разные имена для одного намерения из-за общего пространства имён конструкторов OCaml.

## What Changes

- Передавать типизированное page-local `action` в `Worktree.msg` единым message-конвертом вместе со значением HTTP envelope.
- Убрать дублирующие внутренние сообщения `Run` и `Prompt_selected`.
- Сохранить существующие JSON event tags, UI-документы, выполнение Claude и обработку ошибок без наблюдаемых изменений.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет. Изменение является внутренним рефакторингом и не меняет специфицированное поведение UI или HTTP protocol.

## Impact

- Изменяются `lib/home.ml` и его OCaml-проверки в `test/test_remote_dev.ml`.
- Новые зависимости, изменения Android-клиента и изменения основных OpenSpec specifications не требуются.

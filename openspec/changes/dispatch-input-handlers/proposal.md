## Why

Input-события кодируют значение `"__VALUE__"` внутри сериализованного `Msg`, а сервер рекурсивно заменяет этот литерал значением HTTP envelope. Это связывает dispatch с формой каждого message, ломается при совпадении строк и не масштабируется на вложенные компоненты.

## What Changes

- `input` в дереве компонентов будет хранить функцию, создающую обычный Elm `Msg` из введённой строки.
- Сервер будет публиковать для input непрозрачный selector обработчика, привязанный к ревизии UI-документа, и разрешать selector через текущее дерево view.
- Сервер будет передавать результат обработчика в существующий `Home.update`; page update не будет получать HTTP `value` или знать о протоколе selector.
- Устаревший, некорректный или указывающий не на input selector будет отклоняться.
- Строковый маркер `"__VALUE__"` и рекурсивная JSON-подстановка будут удалены.

## Capabilities

### New Capabilities
- `input-event-dispatch`: Разрешение input selector из backend-defined UI-документа в типизированный Elm message.

### Modified Capabilities
- Нет.

## Impact

- Затрагиваются `lib/components.ml`, `lib/home.ml`, `lib/home_components.ml`, серверный dispatch и OCaml-проверки.
- Android production-код не изменяется: он уже передаёт event array непрозрачно вместе со строкой input.
- Изменятся примеры и проверки event envelope в Android-тестах и документации протокола.

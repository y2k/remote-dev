## Why

Compilation unit `Home` одновременно представляет корневой TEA-компонент и владеет серверными деталями: глобальным `Atomic`-состоянием, HTTP envelope, JSON-преобразованиями и координацией streaming. Из-за вложенного `Home.Home` граница компонента не совпадает с границами остальных TEA-компонентов и усложняет дальнейшую работу над server-side dispatch.

## What Changes

- Сделать `Home` обычным корневым TEA-компонентом с top-level `model`, `msg`, `init`, чистым `view` и `update`.
- Перенести глобальное состояние UI-сеанса, HTTP/JSON dispatch, выполнение command chain и координацию Claude/UI streaming в `Server`.
- Удалить ставшие ненужными runtime helpers из `Home` и заменить обращения `Home.Home.*` на `Home.*`.
- Сохранить текущие HTTP-ответы, UI-документы, JSON events, последовательность команд и streaming-поведение без изменений.
- Сохранить генерируемый JSON codec для `Home.msg`, поскольку текущий button protocol сериализует типизированные сообщения так же, как сообщения дочерних компонентов.

## Capabilities

### New Capabilities

Нет.

### Modified Capabilities

Нет. Это внутренний рефакторинг без изменения наблюдаемого поведения; change использует `skip_specs: true`.

## Impact

- Затрагиваются `lib/home.ml`, `lib/server.ml` и OCaml-проверки в `test/test_remote_dev.ml`.
- Новые зависимости, HTTP routes, форматы SDUI nodes, Android-код и runtime operations не требуются.

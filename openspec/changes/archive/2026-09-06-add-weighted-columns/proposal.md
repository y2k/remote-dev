## Why

Растущий streaming-ответ в выбранном worktree сейчас увеличивает высоту всего экрана и уводит shortcut-кнопки и поле команды за пределы viewport. Нужна ограниченная по высоте прокручиваемая область ответа, которая занимает свободное вертикальное пространство, пока элементы управления остаются видимыми.

## What Changes

- `column` получает необязательный массив `weights` и при его наличии занимает всю доступную высоту.
- Нулевой вес означает размер ребёнка по содержимому, а положительные веса делят оставшееся пространство; та же семантика нуля добавляется существующему `row.weights`.
- Положительно взвешенные дети `column` становятся вертикально прокручиваемыми при переполнении выделенной области.
- Экран выбранного worktree использует weighted column: область ответа получает оставшуюся высоту, а заголовок, path, shortcut-кнопки и поле команды сохраняют высоту по содержимому.
- Unweighted `column` и `row` сохраняют текущее content-sized поведение.
- Автоматическая прокрутка к новым streaming-данным не входит в изменение и отслеживается отдельно в GitHub issue #1.

## Capabilities

### New Capabilities

- `worktree-chat-layout`: Фиксирует вертикальную композицию выбранного worktree с прокручиваемой областью ответа и постоянно видимыми элементами управления.

### Modified Capabilities

- `android-backend-driven-ui`: Добавляет weighted `column`, нулевые веса для `column` и `row`, вертикальное заполнение и прокрутку положительно взвешенных детей колонки.

## Impact

- Изменяются OCaml-модель layout nodes, helper-ы, event mapping и JSON-сериализация в `lib/components.ml`.
- Меняется композиция `Worktree.view` в `lib/home_components.ml` и backend document assertions.
- Изменяются Android-модель и parser SDUI в `MainActivity.kt`, корневая scroll/layout-композиция и renderer в `UiNodeContent.kt`, а также parser и Compose tests.
- README описывает общую семантику `weights` для `row` и `column`.
- Новые зависимости, HTTP routes, TEA messages и изменения persisted state не требуются.

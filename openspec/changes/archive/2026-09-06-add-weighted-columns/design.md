## Context

См. `proposal.md` и delta specs. Backend layout model сейчас хранит optional weights только в `Row`; Android parser принимает для них только положительные числа, а renderer применяет Compose `weight` по горизонтали. `Column` не содержит sizing metadata.

Весь backend document рендерится внутри `Column.fillMaxSize().verticalScroll(...)` в `MainActivity.kt`. Такой контейнер измеряет потомков с неограниченной высотой, поэтому вертикальный Compose `weight` не может распределить viewport. В `Worktree.view` ответ, shortcut-кнопки и input сейчас являются content-sized детьми одной колонки, поэтому растущий streaming output увеличивает весь документ.

## Goals / Non-Goals

**Goals:**
- Дать backend одинаковую модель нулевых и положительных весов для обеих осей.
- Передать weighted columns конечную высоту viewport без Android-specific распознавания worktree или текста ответа.
- Локализовать ручную вертикальную прокрутку внутри положительно-взвешенного ребёнка, чтобы его zero-weight siblings оставались на месте.
- Сохранить прежнюю раскладку узлов без `weights`.

**Non-Goals:**
- Не добавлять auto-scroll к концу streaming output; это отдельно отслеживается в GitHub issue #1.
- Не вводить отдельный `scroll`, `chat` или `split-pane` node.
- Не менять формат output, streaming transport, TEA model/messages или отправку input.
- Не добавлять adaptive layout, ограничения minimum size или специальную обработку экранной клавиатуры.

## Decisions

### `Column` повторяет существующее представление `Row`

OCaml-вариант `Column` будет хранить optional список целочисленных весов, helper `column` получит optional аргумент `weights`, `Components.map` сохранит metadata, а `to_json` добавит поле только при его наличии. `Row` и `Column` останутся двумя вариантами существующего layout type; отдельная sizing abstraction не нужна.

Backend продолжит только сериализовать внутренне построенный документ. Проверка типа, длины и значений остаётся на Android parser как на trust boundary, как уже сделано для `row.weights`.

### Ноль означает content size на обеих осях

Android parser будет одинаково разбирать `weights` у `column` и `row`: массив должен совпадать по длине с `children`, а каждый элемент должен быть конечным неотрицательным числом. Массив из одних нулей допустим: все дети получают content size, а layout node всё равно занимает доступный размер по своей основной оси.

Renderer не передаёт `0` в Compose `Modifier.weight`, который требует положительное значение. Zero-weight children рендерятся как обычные content-sized дети; только positive-weight children получают `Modifier.weight`, поэтому Compose распределяет между ними пространство, оставшееся после zero-weight children и spacing.

Отклонён вариант сохранить запрет нуля для `row`: одинаковое поле с разной валидацией по типу родителя было бы неожиданным и потребовало бы дублирования parser rules.

### Weighted column владеет прокруткой положительных областей

Weighted `Column` заполняет доступную высоту. Каждый positive-weight child находится в контейнере выделенной высоты с собственным `verticalScroll`; zero-weight children остаются вне scroll containers. Это прямо выражает нужную композицию без нового protocol field: область, которой backend отдаёт остаток высоты, одновременно является областью overflow.

Unweighted `Column` остаётся content-sized и не получает новую локальную прокрутку. Автоматическое изменение scroll position при замене streaming document не добавляется.

Отдельный optional `scroll` отклонён: текущему контракту нужна только прокрутка ограниченной weighted области, а независимый флаг создал бы комбинации scroll без конечной высоты. Автоматическая прокрутка всех `Column` также отклонена из-за конфликтов nested vertical scroll.

### Корневой renderer предоставляет конечный viewport

Общий `verticalScroll` удаляется с Android-контейнера документа. Loading и event error остаются content-sized элементами внешней полноэкранной колонки, а backend document размещается в оставшемся bounded контейнере и получает его полный размер. Внешняя колонка использует no-op `scrollable` как nested-scroll источник для `PullToRefreshBox`; он возвращает весь drag родителю и не меняет измерение детей. Корневой `row` по-прежнему делит ширину 2:1, но теперь его потомки также получают конечную высоту.

После этого backend явно задаёт scroll ownership там, где контент реально может расти. `Worktree.view` возвращает одну weighted column со стабильными секциями: error, heading/path, output, shortcuts и input. Output получает положительный вес, остальные секции -- ноль. Пустые error и shortcuts остаются пустыми content-sized columns, поэтому длина `children` и `weights` не зависит от состояния или выбранного agent.

Корневая левая колонка продолжает располагать agent label перед текущим screen; bounded measurement передаёт screen оставшуюся высоту. Список worktrees переводится на weighted column с прокручиваемой областью списка, чтобы удаление прежнего общего scroll не ухудшило длинные списки. Малые формы и emulator content остаются content-sized.

Отклонён Android special-case, который искал бы worktree или output в JSON tree: backend уже владеет layout и может выразить нужную область весами.

### Проверки разделяют protocol и поведение layout

OCaml assertions покроют сериализацию weighted/unweighted columns, сохранение weights через `map` и итоговый worktree document с положительным весом только у output. Существующая проверка weighted row останется и дополнится нулевым значением.

Android parser checks покроют weighted column, нули у обоих layout nodes и отклонение отрицательных, нечисловых, non-finite и несовпадающих по количеству значений. Compose checks зафиксируют распределение высоты, content-sized zero-weight controls и ручную прокрутку переполненного positive-weight child; существующая проверка пропорции row подтвердит отсутствие регрессии.

## Risks / Trade-offs

- [Удаление общего screen scroll меняет владельца прокрутки] -> Перевести существующий растущий список worktrees на weighted scroll region и проверить текущие root screens в instrumentation tests.
- [Zero-weight controls занимают всю высоту] -> Positive region получает только оставшееся пространство; дополнительные overflow rules вводить только по воспроизведённой проблеме.
- [Старый Android client игнорирует `column.weights`] -> Выпустить backend document и поддержку клиента вместе; старый клиент сохранит прежний общий scroll, но не закрепит controls.
- [Backend начнёт отправлять нулевой `row` старому client] -> В рамках изменения использовать нули только для новых columns; zero-weight rows становятся доступным protocol behavior без немедленного применения в application document.

## Migration Plan

1. Добавить parsing и rendering новой семантики в Android вместе с bounded root container.
2. Расширить OCaml layout model и сериализацию, затем переключить worktree output и список worktrees на weighted columns.
3. Обновить contract, document и Compose checks, выполнить backend и Android verification и выпустить backend с Android client согласованно.
4. Для rollback вернуть unweighted backend columns и общий Android `verticalScroll`; persisted data и state migration отсутствуют.

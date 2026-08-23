## Context

См. `proposal.md`. Сейчас `Components` немедленно строит `Yojson.Basic.t`, а страницы передают ему JSON event objects. Это стирает тип действия до того, как `Home` может поднять его в root-level контекст. Android намеренно хранит и пересылает event object как opaque JSON, а `value` input-а передаётся отдельно в HTTP envelope.

## Goals / Non-Goals

**Goals:**

- Сохранить тип действия в UI tree до сериализации HTTP-ответа.
- Позволить каждой странице объявлять и использовать собственный тип действий в её `view`.
- Сохранить существующие JSON documents, event envelope, page decoding и обработку `value`.

**Non-Goals:**

- Не сериализовать внутренние `msg`, включая `Loaded`, `Finished` и `Error`.
- Не менять Android opaque-event transport, HTTP-маршруты или event tags.
- Не добавлять PPX, универсальный page framework или новую dependency.

## Decisions

`Components` будет определять параметризованное дерево `type 'event t`, в котором `Button` и `Edit` хранят `'event`, а layout и text остаются рекурсивными узлами того же дерева. `button` и `edit` будут возвращать typed nodes, а не JSON. Тип-параметр сохраняет принадлежность действия к странице: `Worktrees.view` создаёт `Worktrees.action Components.t`, а `Worktree.view` — `Worktree.action Components.t`. Альтернатива с единым `Home.event` в компонентах отклонена: она разрешает странице привязывать действия чужой страницы и связывает `Components` с root module.

Добавить в `Components` рекурсивный `map`, поднимающий `'event t` в другой event type, и serializer, который принимает encoder событий. `Home.document` будет map-ить typed tree активной страницы в sum type `Home.event`; перед отправкой ответа serializer обойдёт дерево и вызовет page-local encoder для каждого event. Это соответствует существующему `Cmd.map` и не требует GADT или first-class modules.

Каждая страница введёт небольшой `action` type только для действий, доступных её компонентам, и encoder этого type в текущий JSON event object. `Worktrees` будет строить action выбора worktree, а `Worktree` — action запуска Claude. Разбор HTTP envelope останется page-local: decoder сопоставит текущие строковые tags с текущими `msg` и сохранит screen-specific ошибки для допустимого, но неподходящего события. JSON-теги неизбежны на сетевой границе, но больше не появятся в view.

`Edit` будет нести одно статическое typed action, а не функцию `string -> msg`. Сериализованный action остаётся в поле `event`, а введённый текст продолжает поступать отдельным `value` в запросе и превращаться decoder-ом в существующий `Run value`. Альтернатива с `string -> msg` в UI tree отклонена: serializer не может построить статический JSON event для произвольной функции до фактического ввода.

Для получившегося typed tree не использовать JSON deriving PPX. Существующий protocol имеет плоский `{ "type": ..., ... }` формат и разделяет event от envelope `value`; явные маленькие encoder/decoder-ы точнее сохраняют этот contract без новой зависимости или смены `Yojson.Basic`.

## Risks / Trade-offs

- [Изменение затрагивает все конструкторы UI] → Сохранить ограниченный набор текущих узлов и покрыть serializer существующими JSON assertions.
- [Строковые tags останутся в decoder-е] → Ограничить их transport boundary и удалить их из view; OCaml variants не пересылаются напрямую Android-клиенту.
- [Подъём event tree добавляет `Home.event`] → Ограничить sum type двумя текущими страницами, как уже ограничен `Home.msg`.
- [Некорректное событие всё ещё может прийти по сети] → Сохранить текущую page-local validation и ошибки, поскольку тип UI защищает только код, строящий ответ, а не HTTP trust boundary.

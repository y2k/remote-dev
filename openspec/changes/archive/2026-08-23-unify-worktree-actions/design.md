## Context

См. `proposal.md` для мотивации. `Worktree.view` уже возвращает `action Components.t`, поэтому только интерактивные элементы могут публиковать `Run_claude` или `Set_prompt`. После получения HTTP-запроса decoder создаёт независимый `msg`: сейчас это `Run` либо `Prompt_selected`, хотя оба значения уже описаны в `action`.

## Goals / Non-Goals

**Goals:**

- Оставить `action` единственным типом вариантов пользовательских действий.
- Сохранить отдельный `msg` для внутренних событий, таких как `Finished`, `Error` и `Back`.
- Передавать envelope `value` в update вместе с исходным `action`.

**Non-Goals:**

- Делать `msg` типом событий UI или разрешать view публиковать внутренние сообщения.
- Вводить polymorphic variants, модули-обёртки или обобщённый event framework.
- Менять JSON protocol, Android-клиент или выполнение Claude.

## Decisions

Ввести единственный вариант `msg`, который оборачивает `action` и `string option` из HTTP envelope. Decoder восстанавливает исходный `action` по JSON event и помещает его вместе со значением envelope в этот конверт; update сопоставляет пару `action` и value.

Так `Set_prompt` определяется только в `action` и применяется update без промежуточного `Prompt_selected`. Аналогично, `Run_claude` обрабатывается вместе со значением input без промежуточного `Run`.

Не использовать `msg` напрямую как тип компонентов: это сократило бы один тип, но разрешило бы view привязать к кнопке `Finished` или другой внутренний вариант. Не использовать polymorphic variants: они позволяют делить label между типами, но добавляют более сложную типовую модель, не устраняя лишний переход decoder-to-update.

## Risks / Trade-offs

- [Новый message-конверт несёт value, не нужное shortcut-кнопкам] → Это уже форма HTTP envelope и позволяет одинаково передать действия кнопки и input без второго внутреннего типа.
- [Ошибка в сопоставлении action и value меняет обработку пустого input] → Сохранить существующий путь ошибки для `Run_claude` с `None` и проверить его существующими assertions.

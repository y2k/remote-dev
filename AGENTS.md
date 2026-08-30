# Engineering Approach

- Implement only the behavior explicitly required now. Do not add speculative features, abstractions, configuration, extension points, or architecture for possible future needs.
- Prefer deleting code, reusing existing code, the standard library, and native platform features. Choose the smallest clear change that works.
- Do not handle hypothetical edge cases. Add handling only for an explicit requirement, a reproduced failure, or a trust-boundary risk involving security or data loss.
- Do not introduce dependencies or boilerplate when a direct implementation is sufficient.
- Mark an intentional shortcut with a `ponytail:` comment that states its limit and when it should be revisited.

# Server-Defined UI

- Implement server-defined UI on the OCaml backend using The Elm Architecture (TEA): `model`, `msg`, a pure `view`, and `update`.
- When composing server-defined UI, prefer self-contained components for distinct sections. Components do not need separate files.

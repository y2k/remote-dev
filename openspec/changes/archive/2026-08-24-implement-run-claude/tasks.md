## 1. Runtime Implementation

- [x] 1.1 Implement `Runtime.run_claude` with explicit cwd and prompt arguments, the fixed argument-safe `cd "$1" && exec claude --print -- "$2"` wrapper, complete unchanged stdout reading, and a general exception for unsuccessful exit status; document the wrapper and inherited-stderr limits with a `ponytail:` comment.
- [x] 1.2 Update `Home.test` to accept path and body arguments and pass both to `Runtime.run_claude` without adding HTTP routing.

## 2. Verification

- [x] 2.1 Add one focused runtime check using a temporary fake `claude` executable on `PATH` to verify process cwd, exact stdout, literal path and prompt argument handling including an initial hyphen, and a general exception for one non-zero exit.
- [x] 2.2 Run `dune fmt` and the focused runtime check.

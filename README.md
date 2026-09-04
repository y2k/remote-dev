# remote_dev

`remote_dev` is a local development tool for browsing Git worktrees from an Android client and sending prompts to a locally installed Claude or OpenCode CLI in a selected worktree.

## Security

This is a single-user, trusted-LAN development tool, not a public service. The backend listens on port `8080` without authentication. A client on the network can select a worktree and submit prompts to the selected CLI using the server user's local configuration and permissions. OpenCode runs with `--auto`, which approves permission requests not explicitly denied and is not a sandbox.

Run it only on a network you trust. Do not expose port `8080` to the internet.

## Architecture

```text
Android client
    |
    | POST / (JSON UI events)
    v
OCaml / Eio server on :8080
    |-- git worktree list
    |-- claude --print stream-json or opencode run --format json
    `-- adb devices and screencap for selected Android emulators
```

The server returns a backend-defined UI document. The Android client renders that document and sends events back to the server.

## Prerequisites

- A POSIX environment with Dune 3.24 or newer. Dune obtains the OCaml compiler and project dependencies from `dune.lock` on the first build.
- Git.
- For `--agent claude`, the `claude` CLI installed, authenticated, and available on `PATH`.
- For `--agent opencode`, OpenCode 1.18.20 or newer installed, authenticated, and available on `PATH`.
- Android Platform Tools (`adb`) on `PATH` when using emulator screenshots.
- Android Studio or an Android SDK setup that can build the `android/` Gradle project.
- An Android device on the same trusted LAN as the backend.

## Run The Backend

Build the project:

```sh
make build
```

Start the backend with the required agent and an optional Git repository root:

```sh
make run ARGS="--agent claude /path/to/repository"
make run ARGS="--agent opencode /path/to/repository"
```

Omit only the repository root to use the current working directory:

```sh
make run ARGS="--agent opencode"
```

The selected agent cannot be changed without restarting the backend. The server does not preflight executable availability or version; a missing executable is reported when a prompt is run. The server listens on all IPv4 interfaces at port `8080`.

Worktree creation and the `/igor-pending-reviews` and `/igor-restart-mr-tests` shortcuts are available only in Claude mode. OpenCode mode can use existing worktrees but does not create them.

## Build The Android Client

The Android client receives its backend address at build time. Create or update `android/local.properties` without removing any existing Android SDK settings:

```properties
backendHost=192.168.0.15
```

Use the LAN address of the machine running the backend. Gradle generates both the client URL and the Android cleartext allowlist from this value.

Build a debug APK:

```sh
cd android
./gradlew assembleDebug
```

Override the local value for one build when needed:

```sh
./gradlew assembleDebug -PbackendHost=192.168.0.42
```

On Android 17 and later, grant the app Local Network Access permission before it can contact the backend. See [`android/README.md`](android/README.md) for the Android-specific setup summary.

## HTTP Protocol

The server loads running ADB emulators once, then loads the initial worktree list,
before accepting HTTP requests. The client starts a UI session with `GET /`, which
returns the current document as `application/json`.

Interactive UI nodes use `POST /` with a JSON event envelope. The client copies the
event value advertised by the node into `event`:

```json
{
  "event": ["Worktrees_msg", ["Load"]],
  "value": null
}
```

`value` is either a string or `null`; the server substitutes a string value for the
`"__VALUE__"` marker in an input event. Events without a command return one complete
`application/json` UI document. Events that load worktrees, including manual refresh
and `back` from a selected worktree, return `application/x-ndjson` with the document
before and after the load command.

A successful `run_prompt` also returns `application/x-ndjson`. Each nonempty line is
a compact complete UI document with the current response accumulated so far; the
Android client replaces its displayed document for every line until the response
closes. Claude streams text deltas, while OpenCode emits completed text parts and can
therefore update less frequently. If the selected CLI fails after the stream starts,
the final document contains the error.

The first prompt on an open worktree screen starts a CLI session. Later prompts on
that screen explicitly resume its session ID while replacing the previously rendered
response. Returning to the worktree list or restarting the backend forgets the ID;
the CLI-owned session remains in that CLI's local history.

The emulator panel appears on every screen. Its buttons send a root event such as
`["Emulator_msg",["Select","emulator-5554"]]`. The selected serial is global and
remains in backend memory while navigating; restarting the backend creates a fresh
selection. A device stopped after startup remains selected, so the client displays
the screenshot error until that device is available again or the backend restarts.

The client refreshes the selected emulator screenshot independently every three
seconds. Each image source is a `GET /emulators/<serial>/screenshot.png` response
with `image/png` and `Cache-Control: no-store`; a stopped or unknown emulator returns
a non-success response.

The UI document supports these nodes:

- `column`: vertically arranged `children`.
- `row`: horizontally arranged `children`. An optional `weights` array contains
  one positive number per child and divides the available width proportionally;
  without it, children keep their content-sized widths.
- `text`: a `text` string.
- `button`: a `label` string and optional backend `event`.
- `input`: a `label`, backend `event`, and optional initial `text`.
- `image`: a backend-relative `src` path beginning with `/` but not `//`, plus a
  `label`. The client resolves it against the configured backend origin.

Every screen uses one root weighted row with the current screen first and the
emulator panel second:

```json
{
  "@type": "row",
  "children": [
    { "@type": "column", "children": [] },
    { "@type": "column", "children": [] }
  ],
  "weights": [2, 1]
}
```

The Android client treats each event value as backend-defined JSON. `input` submits
its current value as the envelope's `value` field.

## Development

Run the OCaml tests:

```sh
dune test
```

Build the Android debug APK with an explicit backend host:

```sh
cd android
./gradlew assembleDebug -PbackendHost=192.168.0.15
```

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).

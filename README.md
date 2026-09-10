# remote_dev

`remote_dev` is a local development tool for browsing Claude worktrees or attaching an Android client to existing sessions from a local OpenCode server.

## Security

This is a single-user, trusted-LAN development tool, not a public service. The backend listens on port `8080` without authentication. A client on the network can submit prompts using the server user's local configuration and permissions. The OpenCode API remains localhost-only on port `4096`; remote_dev exposes session titles, directories, textual transcripts, and controls for every project known to that OpenCode server.

Run it only on a network you trust. Do not expose port `8080` to the internet.

## Architecture

```text
Android client
    |
    | POST / (JSON UI events)
    v
OCaml / Eio server on :8080
    |-- Claude: git worktrees and claude --print stream-json
    |-- OpenCode: HTTP API on 127.0.0.1:4096
    `-- adb devices and screencap for selected Android emulators
```

The server returns a backend-defined UI document. The Android client renders that document and sends events back to the server.

## Prerequisites

- A POSIX environment with Dune 3.24 or newer. Dune obtains the OCaml compiler and project dependencies from `dune.lock` on the first build.
- Git.
- For `--agent claude`, the `claude` CLI installed, authenticated, and available on `PATH`.
- For `--agent opencode`, OpenCode 1.18.20 or newer installed and authenticated.
- Android Platform Tools (`adb`) on `PATH` when using emulator screenshots.
- Android Studio or an Android SDK setup that can build the `android/` Gradle project.
- An Android device on the same trusted LAN as the backend.

## Run The Backend

Build the project:

```sh
make build
```

Claude accepts an optional Git repository root and defaults to the current directory:

```sh
make run ARGS="--agent claude /path/to/repository"
make run ARGS="--agent claude"
```

For OpenCode, first start the fixed localhost server, optionally attach its terminal UI, then start remote_dev without a repository root:

```sh
opencode serve --hostname 127.0.0.1 --port 4096
opencode attach http://127.0.0.1:4096
make run ARGS="--agent opencode"
```

`opencode attach` is optional and can run in another terminal, but it is required to answer permissions or questions. OpenCode mode rejects a positional repository root. It lists the 20 most recently updated sessions across all projects known to the server and does not create sessions. Older sessions remain in OpenCode history.

If the OpenCode server uses a password, the remote_dev backend must inherit the same `OPENCODE_SERVER_PASSWORD`. Export it in each terminal before starting its process; setting it only for `opencode serve` does not pass it to a separately started backend. For example, after setting the variable in the backend's terminal:

```sh
export OPENCODE_SERVER_PASSWORD
make run ARGS="--agent opencode"
```

The backend sends Basic authentication on every OpenCode request when the password is non-empty, always using the username `opencode`. An unset or empty password sends no authorization header. Restart the backend after changing its environment. HTTP 401 means the server rejected the request's authentication.

The selected agent cannot be changed without restarting remote_dev. The backend does not start or stop `opencode serve` and reports connection or protocol errors in the UI. It listens on all IPv4 interfaces at port `8080`.

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

On Android 17 and later, grant the app Local Network Access permission before it can contact the backend.

## HTTP Protocol

The server loads running ADB emulators once, then loads the initial Claude worktree list or the OpenCode session list before accepting HTTP requests. The client starts a UI session with `GET /`, which returns the current document as `application/json`.

Interactive UI nodes use `POST /` with a JSON event envelope. The client copies the
event value advertised by the node into `event`:

```json
{
  "event": ["Refresh"],
  "value": null
}
```

`value` is either a string or `null`; the server substitutes a string value for the
`"__VALUE__"` marker in an input event. Pull-to-refresh always sends the provider-neutral root `Refresh` event. It reloads the current Claude worktree list, OpenCode all-server session list, or selected OpenCode session. Finite load commands return `application/x-ndjson` with documents before and after the load.

A Claude prompt returns `application/x-ndjson`. Each nonempty line is a compact complete UI document with the current response accumulated so far; the Android client replaces its displayed document for every line until the response closes. If Claude fails after the stream starts, the final document contains the error.

An ordinary OpenCode prompt is sent to `prompt_async`; remote_dev waits only for its `204` acceptance and returns one `application/json` document. A recognized slash command uses the command endpoint in an application-scoped background fiber and also returns immediately. There is no automatic command-to-prompt fallback. New transcript text and status appear after manual refresh. A busy session exposes Stop; retrying remains visible until OpenCode leaves retry state.

Pending OpenCode permissions and questions are displayed only as `Needs input in OpenCode`. Answer them in an `opencode attach` terminal. The Android client intentionally cannot approve or reject them.

In Claude mode, the first prompt on an open worktree screen starts a CLI session. Later prompts on that screen explicitly resume its session ID while replacing the previously rendered response. Returning to the worktree list or restarting the backend forgets the ID; the Claude-owned session remains in its local history. OpenCode session metadata, transcript, and status always come from `opencode serve`.

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

- `column`: vertically arranged `children`. An optional `weights` array makes the
  column fill the available height. Zero-weight children keep their content height;
  positive-weight children divide the remaining height proportionally and scroll
  vertically when their content overflows.
- `row`: horizontally arranged `children`. Its optional `weights` array makes the row
  fill the available width. Zero-weight children keep their content width and
  positive-weight children divide the remaining width proportionally.
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

The selected screen uses a weighted column inside the left pane. Transcript or Claude output gets the remaining height while controls remain content-sized. For example, an OpenCode session has this inner shape:

```json
{
  "@type": "column",
  "children": [
    { "@type": "column", "children": [] },
    { "@type": "text", "text": "OpenCode session" },
    { "@type": "text", "text": "Session title" },
    { "@type": "text", "text": "/path/to/project" },
    { "@type": "text", "text": "Status: idle" },
    { "@type": "column", "children": [] },
    { "@type": "column", "children": [] },
    {
      "@type": "input",
      "label": "Prompt",
      "event": ["Session_msg", ["Run_prompt", "__VALUE__"]],
      "text": ""
    }
  ],
  "weights": [0, 0, 0, 0, 0, 1, 0, 0]
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

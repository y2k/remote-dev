let with_process ~check lines (status : Unix.process_status) f =
  try f ()
  with effect Remote_dev.Runtime.Process_lines (process, on_line), k ->
    check process;
    List.iter on_line lines;
    Effect.Deep.continue k status

let with_http handle =
  Remote_dev.Runtime.with_http (fun request ->
      (if Array.length Sys.argv = 2 then
         let expected = if Sys.argv.(1) = "" then None else Some Sys.argv.(1) in
         assert (List.assoc_opt "authorization" request.headers = expected));
      handle request)

let with_emulator_processes f =
  try f () with
  | effect
      Remote_dev.Runtime.Process_lines
        (Remote_dev.Runtime.Args ("adb", argv), on_line), k ->
      let lines, status =
        match argv with
        | [| "adb"; "devices"; "-l" |] ->
            ( [
                "List of devices attached";
                "emulator-5554\tdevice product:sdk";
                "emulator-5556\tdevice product:sdk";
                "physical-device\tdevice product:phone";
              ],
              Unix.WEXITED 0 )
        | [| "adb"; "-s"; "emulator-5554"; "emu"; "avd"; "name" |] ->
            ([ "Pixel"; "OK" ], Unix.WEXITED 0)
        | [| "adb"; "-s"; "emulator-5556"; "emu"; "avd"; "name" |] ->
            ([], Unix.WEXITED 1)
        | _ -> assert false
      in
      List.iter on_line lines;
      Effect.Deep.continue k status
  | effect
      Remote_dev.Runtime.Process_bytes (Remote_dev.Runtime.Args ("adb", argv)), k
    ->
      assert (
        argv = [| "adb"; "-s"; "emulator-5554"; "exec-out"; "screencap"; "-p" |]);
      Effect.Deep.continue k ("\137PNG", Unix.WEXITED 0)

let check_claude ?session cwd prompt = function
  | Remote_dev.Runtime.Args ("/bin/sh", argv) ->
      let expected =
        match session with
        | None ->
            [|
              "/bin/sh";
              "-c";
              "cd \"$1\" && exec claude --print --output-format stream-json \
               --verbose --include-partial-messages -- \"$2\"";
              "sh";
              cwd;
              prompt;
            |]
        | Some session ->
            [|
              "/bin/sh";
              "-c";
              "cd \"$1\" && exec claude --print --output-format stream-json \
               --verbose --include-partial-messages --resume \"$2\" -- \"$3\"";
              "sh";
              cwd;
              session;
              prompt;
            |]
      in
      assert (argv = expected)
  | Remote_dev.Runtime.Shell _ | Remote_dev.Runtime.Args _ -> assert false

let check_create_worktree root name = function
  | Remote_dev.Runtime.Args ("/bin/sh", argv) ->
      assert (
        argv
        = [|
            "/bin/sh";
            "-c";
            "cd \"$1\" && exec claude --worktree \"$2\" --print --tools '' -- \
             \"$3\"";
            "sh";
            root;
            name;
            "Reply only: READY.";
          |])
  | Remote_dev.Runtime.Shell _ | Remote_dev.Runtime.Args _ -> assert false

let claude_delta text =
  "{\"type\":\"stream_event\",\"event\":{\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\""
  ^ text ^ "\"}}}"

let claude_init session_id =
  "{\"type\":\"system\",\"subtype\":\"init\",\"session_id\":\"" ^ session_id
  ^ "\"}"

let protocol_failure f =
  try
    f ();
    false
  with Remote_dev.Runtime.Protocol_error _ -> true

let has_usage message =
  message |> String.split_on_char '\n'
  |> List.exists (String.starts_with ~prefix:"Usage:")

let () =
  (if Array.length Sys.argv = 1 then
     let environment =
       Unix.environment () |> Array.to_list
       |> List.filter (fun entry ->
           not
             (String.starts_with ~prefix:"OPENCODE_SERVER_PASSWORD=" entry
             || String.starts_with ~prefix:"OPENCODE_SERVER_USERNAME=" entry))
     in
     List.iter
       (fun (credentials, expected) ->
         let pid =
           Unix.create_process_env Sys.executable_name
             [| Sys.executable_name; expected |]
             (Array.of_list (credentials @ environment))
             Unix.stdin Unix.stdout Unix.stderr
         in
         assert (snd (Unix.waitpid [] pid) = Unix.WEXITED 0))
       [
         ([], "");
         ([ "OPENCODE_SERVER_PASSWORD=" ], "");
         ([ "OPENCODE_SERVER_PASSWORD=secret" ], "Basic b3BlbmNvZGU6c2VjcmV0");
         ( [
             "OPENCODE_SERVER_PASSWORD=secret"; "OPENCODE_SERVER_USERNAME=alice";
           ],
           "Basic b3BlbmNvZGU6c2VjcmV0" );
         ( [ "OPENCODE_SERVER_PASSWORD= p:a\tss\n " ],
           "Basic b3BlbmNvZGU6IHA6YQlzcwog" );
       ]);
  let claude =
    Remote_dev.Runtime.parse_args [| "remote_dev"; "--agent"; "claude" |]
  in
  assert (claude = Remote_dev.Runtime.Claude { root = Sys.getcwd () });
  assert (
    Remote_dev.Runtime.parse_args [| "remote_dev"; "--agent"; "opencode" |]
    = Remote_dev.Runtime.OpenCode);
  assert (
    try
      ignore
        (Remote_dev.Runtime.parse_args
           [| "remote_dev"; "--agent"; "opencode"; "/tmp/repository" |]);
      false
    with Arg.Bad message -> has_usage message);
  assert (
    try
      ignore (Remote_dev.Runtime.parse_args [| "remote_dev" |]);
      false
    with Arg.Bad message -> has_usage message);
  assert (
    try
      ignore
        (Remote_dev.Runtime.parse_args [| "remote_dev"; "--agent"; "Claude" |]);
      false
    with Arg.Bad message -> has_usage message);
  assert (
    try
      ignore
        (Remote_dev.Runtime.parse_args
           [| "remote_dev"; "--agent"; "claude"; "--agent"; "opencode" |]);
      false
    with Arg.Bad _ -> true);
  let worktree = "worktree ; $literal" in
  let prompt = "-prompt with spaces; $(literal) \"quoted\"" in
  let events = ref [] in
  with_process
    ~check:(check_claude worktree prompt)
    [
      claude_init "claude-session";
      claude_delta "Hel";
      claude_delta "lo";
      "{\"type\":\"result\",\"result\":\"Hello\"}";
    ]
    (Unix.WEXITED 0)
    (fun () ->
      Remote_dev.Runtime.stream_claude ~cwd:worktree ~prompt ~session_id:None
        (fun event -> events := event :: !events));
  assert (
    List.rev !events
    = [
        Remote_dev.Runtime.Session "claude-session";
        Remote_dev.Runtime.Text "Hel";
        Remote_dev.Runtime.Text "lo";
      ]);
  let resumed = ref [] in
  with_process
    ~check:(check_claude ~session:"claude-session" worktree "continue")
    [ claude_init "claude-session"; claude_delta "Again" ]
    (Unix.WEXITED 0)
    (fun () ->
      Remote_dev.Runtime.stream_claude ~cwd:worktree ~prompt:"continue"
        ~session_id:(Some "claude-session") (fun event ->
          resumed := event :: !resumed));
  assert (
    List.rev !resumed
    = [
        Remote_dev.Runtime.Session "claude-session";
        Remote_dev.Runtime.Text "Again";
      ]);
  let failed_events = ref [] in
  assert (
    try
      with_process
        ~check:(check_claude worktree "--fail")
        [ claude_init "failed-session"; claude_delta "Hel" ]
        (Unix.WEXITED 1)
        (fun () ->
          Remote_dev.Runtime.stream_claude ~cwd:worktree ~prompt:"--fail"
            ~session_id:None (fun event ->
              failed_events := event :: !failed_events));
      false
    with Failure _ -> true);
  assert (
    List.rev !failed_events
    = [
        Remote_dev.Runtime.Session "failed-session";
        Remote_dev.Runtime.Text "Hel";
      ]);
  assert (
    protocol_failure (fun () ->
        with_process ~check:(check_claude worktree "--bad-json")
          [ "{bad json}" ] (Unix.WEXITED 0) (fun () ->
            Remote_dev.Runtime.stream_claude ~cwd:worktree ~prompt:"--bad-json"
              ~session_id:None (fun _ -> ()))));
  assert (
    protocol_failure (fun () ->
        with_process
          ~check:(check_claude worktree "missing-session")
          [ claude_delta "text" ]
          (Unix.WEXITED 0)
          (fun () ->
            Remote_dev.Runtime.stream_claude ~cwd:worktree
              ~prompt:"missing-session" ~session_id:None (fun _ -> ()))));
  assert (
    protocol_failure (fun () ->
        with_process
          ~check:(check_claude ~session:"expected" worktree "mismatch")
          [ claude_init "different" ]
          (Unix.WEXITED 0)
          (fun () ->
            Remote_dev.Runtime.stream_claude ~cwd:worktree ~prompt:"mismatch"
              ~session_id:(Some "expected") (fun _ -> ()))));
  assert (
    protocol_failure (fun () ->
        with_process
          ~check:(check_claude worktree "conflict")
          [
            claude_init "first";
            "{\"type\":\"result\",\"session_id\":\"second\"}";
          ]
          (Unix.WEXITED 0)
          (fun () ->
            Remote_dev.Runtime.stream_claude ~cwd:worktree ~prompt:"conflict"
              ~session_id:None (fun _ -> ()))));
  let session_json =
    "[{\"id\":\"session-1\",\"title\":\"Review\",\"directory\":\"/tmp/a \
     b%\",\"workspaceID\":\"workspace \
     1\",\"agent\":\"plan\",\"model\":{\"providerID\":\"anthropic\",\"id\":\"claude\",\"variant\":\"high\"},\"time\":{\"updated\":123},\"extra\":true}]"
  in
  assert (
    Remote_dev.Runtime.opencode_sessions session_json
    = [
        {
          Remote_dev.Runtime.id = "session-1";
          title = "Review";
          directory = "/tmp/a b%";
          workspace = Some "workspace 1";
          agent = Some "plan";
          model = Some ("anthropic", "claude", Some "high");
          status = Idle;
        };
      ]);
  assert (
    protocol_failure (fun () ->
        ignore (Remote_dev.Runtime.opencode_sessions "[{\"id\":\"missing\"}]")));
  assert (
    Remote_dev.Runtime.opencode_messages
      "[{\"info\":{\"role\":\"user\",\"extra\":1},\"parts\":[{\"type\":\"tool\",\"name\":\"ignored\"},{\"type\":\"text\",\"text\":\"hello\",\"extra\":true}]},{\"info\":{\"role\":\"assistant\"},\"parts\":[{\"type\":\"text\",\"text\":\"world\"}]}]"
    = [
        { Remote_dev.Runtime.role = User; text = "hello" };
        { role = Assistant; text = "world" };
      ]);
  assert (
    protocol_failure (fun () ->
        ignore
          (Remote_dev.Runtime.opencode_messages "[{\"info\":{},\"parts\":[]}]")));
  assert (
    Remote_dev.Runtime.opencode_input "/" = `Prompt "/"
    && Remote_dev.Runtime.opencode_input "/ review" = `Prompt "/ review"
    && Remote_dev.Runtime.opencode_input " \t/review  main; $(literal) \n"
       = `Command ("review", "main; $(literal)"));
  assert (
    Yojson.Basic.from_string
      (Remote_dev.Runtime.opencode_prompt_body
         {
           id = "session-1";
           title = "Review";
           directory = "/tmp/a b%";
           workspace = None;
           agent = Some "plan";
           model = Some ("anthropic", "claude", Some "high");
           status = Idle;
         }
         "  -prompt; $(literal) \"quoted\"  ")
    = `Assoc
        [
          ("agent", `String "plan");
          ( "model",
            `Assoc
              [
                ("providerID", `String "anthropic");
                ("modelID", `String "claude");
              ] );
          ("variant", `String "high");
          ( "parts",
            `List
              [
                `Assoc
                  [
                    ("type", `String "text");
                    ("text", `String "  -prompt; $(literal) \"quoted\"  ");
                  ];
              ] );
        ]);
  assert (
    Remote_dev.Runtime.opencode_command_body
      {
        id = "new";
        title = "New session";
        directory = "/tmp/new";
        workspace = None;
        agent = None;
        model = None;
        status = Idle;
      }
      "review" ""
    |> Yojson.Basic.from_string
    = `Assoc [ ("command", `String "review"); ("arguments", `String "") ]);
  let requests = ref [] in
  let sessions =
    with_http
      (fun (request : Remote_dev.Runtime.http_request) ->
        requests := request :: !requests;
        match request.target with
        | "/experimental/session?limit=20" ->
            { status = 200; body = session_json }
        | "/session/status?directory=%2Ftmp%2Fa%20b%25&workspace=workspace%201"
          ->
            { status = 200; body = "{\"session-1\":{\"type\":\"busy\"}}" }
        | _ -> assert false)
      Remote_dev.Runtime.load_opencode_sessions
  in
  assert ((List.hd sessions).status = Busy);
  assert (List.length !requests = 2);
  let page =
    `List
      (List.init 20 (fun index ->
           `Assoc
             [
               ("id", `String ("paged-" ^ string_of_int index));
               ("title", `String "Paged");
               ("directory", `String "/tmp/paged");
               ("agent", `String "build");
               ( "model",
                 `Assoc
                   [
                     ("providerID", `String "anthropic");
                     ("id", `String "claude");
                   ] );
               ("time", `Assoc [ ("updated", `Int (200 - index)) ]);
             ]))
    |> Yojson.Basic.to_string
  in
  let paged_requests = ref [] in
  let paged =
    with_http
      (fun (request : Remote_dev.Runtime.http_request) ->
        paged_requests := request.target :: !paged_requests;
        match request.target with
        | "/experimental/session?limit=20" -> { status = 200; body = page }
        | "/session/status?directory=%2Ftmp%2Fpaged" ->
            { status = 200; body = "{}" }
        | _ -> assert false)
      Remote_dev.Runtime.load_opencode_sessions
  in
  assert (List.length paged = 20);
  assert (
    List.map
      (fun (session : Remote_dev.Runtime.opencode_session) -> session.id)
      paged
    = List.init 20 (fun index -> "paged-" ^ string_of_int index));
  assert (List.length !paged_requests = 2);
  let session = List.hd sessions in
  let detail =
    with_http
      (fun (request : Remote_dev.Runtime.http_request) ->
        match request.target with
        | target
          when String.starts_with ~prefix:"/session/session-1/message" target ->
            {
              status = 200;
              body =
                "[{\"info\":{\"role\":\"assistant\"},\"parts\":[{\"type\":\"text\",\"text\":\"done\"},{\"type\":\"tool\"}]}]";
            }
        | target when String.starts_with ~prefix:"/session/status" target ->
            { status = 200; body = "{}" }
        | target when String.starts_with ~prefix:"/permission" target ->
            { status = 200; body = "[{\"sessionID\":\"session-1\"}]" }
        | target when String.starts_with ~prefix:"/question" target ->
            { status = 200; body = "[]" }
        | _ -> assert false)
      (fun () -> Remote_dev.Runtime.load_opencode_detail session)
  in
  assert (detail.session.status = Idle);
  assert detail.needs_input;
  assert (detail.messages = [ { role = Assistant; text = "done" } ]);
  let posts = ref [] in
  let post_response (request : Remote_dev.Runtime.http_request) =
    posts := request :: !posts;
    if
      String.starts_with ~prefix:"/session/session-1/prompt_async"
        request.target
    then { Remote_dev.Runtime.status = 204; body = "" }
    else if
      String.starts_with ~prefix:"/session/session-1/command" request.target
    then
      { Remote_dev.Runtime.status = 200; body = "{\"info\":{},\"parts\":[]}" }
    else { Remote_dev.Runtime.status = 200; body = "true" }
  in
  with_http post_response (fun () ->
      Remote_dev.Runtime.submit_opencode_prompt session "$(literal); \"quoted\"");
  with_http post_response (fun () ->
      Remote_dev.Runtime.submit_opencode_command session "review" "main branch");
  with_http post_response (fun () -> Remote_dev.Runtime.abort_opencode session);
  List.iter
    (fun (request : Remote_dev.Runtime.http_request) ->
      assert (
        List.assoc_opt "x-opencode-directory" request.headers
        = Some "%2Ftmp%2Fa%20b%25");
      assert (String.ends_with ~suffix:"?workspace=workspace%201" request.target);
      assert (
        List.assoc_opt "content-type" request.headers = Some "application/json"
        || request.body = ""))
    !posts;
  assert (
    !posts
    |> List.exists (fun (request : Remote_dev.Runtime.http_request) ->
        request.body <> ""
        && Yojson.Basic.from_string request.body |> function
           | `Assoc fields ->
               List.assoc_opt "agent" fields = Some (`String "plan")
               && List.assoc_opt "model" fields
                  = Some (`String "anthropic/claude")
               && List.assoc_opt "arguments" fields
                  = Some (`String "main branch")
               && List.assoc_opt "variant" fields = Some (`String "high")
           | _ -> false));
  assert (
    try
      with_http
        (fun (_ : Remote_dev.Runtime.http_request) ->
          failwith "connection refused")
        Remote_dev.Runtime.load_opencode_sessions
      |> ignore;
      false
    with
    | Failure message -> message = "connection refused"
    | _ -> false);
  assert (
    try
      with_http
        (fun (_ : Remote_dev.Runtime.http_request) ->
          { Remote_dev.Runtime.status = 500; body = "failed" })
        Remote_dev.Runtime.load_opencode_sessions
      |> ignore;
      false
    with Failure _ -> true);
  assert (
    protocol_failure (fun () ->
        with_http
          (fun (_ : Remote_dev.Runtime.http_request) ->
            { Remote_dev.Runtime.status = 200; body = "not-json" })
          Remote_dev.Runtime.load_opencode_sessions
        |> ignore));
  assert (
    try
      with_http
        (fun (_ : Remote_dev.Runtime.http_request) ->
          {
            Remote_dev.Runtime.status = 401;
            body = "secret Authorization: Basic YWxpY2U6c2VjcmV0";
          })
        Remote_dev.Runtime.load_opencode_sessions
      |> ignore;
      false
    with Failure message -> message = "OpenCode server returned HTTP 401");
  let root = "/tmp/remote-dev" in
  with_process ~check:(check_create_worktree root "feature/new-worktree")
    [] (Unix.WEXITED 0) (fun () ->
      Remote_dev.Runtime.create_worktree root "feature/new-worktree");
  assert (
    try
      with_process ~check:(check_create_worktree root "broken")
        [] (Unix.WEXITED 1) (fun () ->
          Remote_dev.Runtime.create_worktree root "broken");
      false
    with Failure _ -> true);
  let worktrees =
    with_process
      ~check:(function
        | Remote_dev.Runtime.Shell command ->
            assert (
              command
              = "git -C " ^ Filename.quote root ^ " worktree list --porcelain")
        | Remote_dev.Runtime.Args _ -> assert false)
      [
        "worktree /tmp/remote-dev";
        "HEAD 123";
        "branch refs/heads/main";
        "";
        "worktree /tmp/remote-dev-feature";
        "HEAD 456";
        "branch refs/heads/feature";
      ]
      (Unix.WEXITED 0)
      (fun () -> Remote_dev.Runtime.load_worktrees root)
  in
  assert (
    worktrees
    = [
        { Remote_dev.Runtime.path = "/tmp/remote-dev"; branch = "main" };
        { path = "/tmp/remote-dev-feature"; branch = "feature" };
      ]);
  assert (
    try
      ignore
        (with_process
           ~check:(fun _ -> ())
           [] (Unix.WEXITED 1)
           (fun () -> Remote_dev.Runtime.load_worktrees root));
      false
    with Failure _ -> true);
  let emulators = with_emulator_processes Remote_dev.Runtime.load_emulators in
  assert (
    emulators
    = [
        { Remote_dev.Runtime.serial = "emulator-5554"; name = "Pixel" };
        { serial = "emulator-5556"; name = "emulator-5556" };
      ]);
  assert (
    with_process
      ~check:(function
        | Remote_dev.Runtime.Args ("adb", [| "adb"; "devices"; "-l" |]) -> ()
        | Remote_dev.Runtime.Shell _ | Remote_dev.Runtime.Args _ -> assert false)
      [] (Unix.WEXITED 0) Remote_dev.Runtime.load_emulators
    = []);
  assert (
    with_emulator_processes (fun () ->
        Remote_dev.Runtime.capture_emulator_screenshot "emulator-5554")
    = "\137PNG");
  assert (
    try
      ignore
        (try Remote_dev.Runtime.capture_emulator_screenshot "emulator-5554"
         with effect Remote_dev.Runtime.Process_bytes _, k ->
           Effect.Deep.continue k ("", Unix.WEXITED 1));
      false
    with Failure _ -> true)

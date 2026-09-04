let with_process ~check lines (status : Unix.process_status) f =
  try f ()
  with effect Remote_dev.Runtime.Process_lines (process, on_line), k ->
    check process;
    List.iter on_line lines;
    Effect.Deep.continue k status

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

let check_opencode ?session expected_input cwd = function
  | Remote_dev.Runtime.Args ("opencode", argv) ->
      let expected =
        [ "opencode"; "run"; "--dir"; cwd; "--format"; "json"; "--auto" ]
        @
        match session with
        | Some session -> [ "--session"; session ] @ expected_input
        | None -> expected_input
      in
      assert (Array.to_list argv = expected)
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

let opencode_text session_id text =
  "{\"type\":\"text\",\"sessionID\":\"" ^ session_id
  ^ "\",\"part\":{\"type\":\"text\",\"text\":\"" ^ text ^ "\"}}"

let protocol_failure f =
  try
    f ();
    false
  with Remote_dev.Runtime.Protocol_error _ -> true

let has_usage message =
  message |> String.split_on_char '\n'
  |> List.exists (String.starts_with ~prefix:"Usage:")

let () =
  let claude =
    Remote_dev.Runtime.parse_args [| "remote_dev"; "--agent"; "claude" |]
  in
  assert (claude.agent = Remote_dev.Runtime.Claude);
  assert (claude.root = Sys.getcwd ());
  let opencode =
    Remote_dev.Runtime.parse_args
      [| "remote_dev"; "--agent"; "opencode"; "/tmp/repository" |]
  in
  assert (opencode.agent = Remote_dev.Runtime.OpenCode);
  assert (opencode.root = "/tmp/repository");
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
      Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.Claude ~cwd:worktree
        ~prompt ~session_id:None (fun event -> events := event :: !events));
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
      Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.Claude ~cwd:worktree
        ~prompt:"continue" ~session_id:(Some "claude-session") (fun event ->
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
          Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.Claude
            ~cwd:worktree ~prompt:"--fail" ~session_id:None (fun event ->
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
            Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.Claude
              ~cwd:worktree ~prompt:"--bad-json" ~session_id:None (fun _ -> ()))));
  assert (
    protocol_failure (fun () ->
        with_process
          ~check:(check_claude worktree "missing-session")
          [ claude_delta "text" ]
          (Unix.WEXITED 0)
          (fun () ->
            Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.Claude
              ~cwd:worktree ~prompt:"missing-session" ~session_id:None (fun _ ->
                ()))));
  assert (
    protocol_failure (fun () ->
        with_process
          ~check:(check_claude ~session:"expected" worktree "mismatch")
          [ claude_init "different" ]
          (Unix.WEXITED 0)
          (fun () ->
            Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.Claude
              ~cwd:worktree ~prompt:"mismatch" ~session_id:(Some "expected")
              (fun _ -> ()))));
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
            Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.Claude
              ~cwd:worktree ~prompt:"conflict" ~session_id:None (fun _ -> ()))));
  let opencode_prompt = "  -prompt  with $(literal) \"quoted value\" \tend  " in
  let opencode_events = ref [] in
  with_process
    ~check:
      (check_opencode
         [
           "--";
           "";
           "";
           "-prompt";
           "";
           "with";
           "$(literal)";
           "\"quoted";
           "value\"";
           "\tend";
           "";
           "";
         ]
         worktree)
    [
      "{\"type\":\"step_start\",\"sessionID\":\"open-session\"}";
      opencode_text "open-session" "Hello";
      opencode_text "open-session" " world";
      "{\"type\":\"unknown\",\"sessionID\":\"open-session\"}";
    ]
    (Unix.WEXITED 0)
    (fun () ->
      Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.OpenCode ~cwd:worktree
        ~prompt:opencode_prompt ~session_id:None (fun event ->
          opencode_events := event :: !opencode_events));
  assert (
    List.rev !opencode_events
    = [
        Remote_dev.Runtime.Session "open-session";
        Remote_dev.Runtime.Text "Hello";
        Remote_dev.Runtime.Text " world";
      ]);
  with_process
    ~check:
      (check_opencode ~session:"open-session" [ "--"; "continue" ] worktree)
    [ opencode_text "open-session" "continued" ]
    (Unix.WEXITED 0)
    (fun () ->
      Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.OpenCode ~cwd:worktree
        ~prompt:"continue" ~session_id:(Some "open-session") (fun _ -> ()));
  with_process
    ~check:(check_opencode [ "--"; "/" ] worktree)
    [ opencode_text "slash-session" "slash" ]
    (Unix.WEXITED 0)
    (fun () ->
      Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.OpenCode ~cwd:worktree
        ~prompt:"/" ~session_id:None (fun _ -> ()));
  with_process
    ~check:
      (check_opencode
         [ "--command"; "review"; "--"; "main"; "branch" ]
         worktree)
    [ opencode_text "command-session" "review" ]
    (Unix.WEXITED 0)
    (fun () ->
      Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.OpenCode ~cwd:worktree
        ~prompt:" \t/review  main branch \n" ~session_id:None (fun _ -> ()));
  with_process
    ~check:(check_opencode [ "--"; "/"; "review" ] worktree)
    [ opencode_text "spaced-slash-session" "prompt" ]
    (Unix.WEXITED 0)
    (fun () ->
      Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.OpenCode ~cwd:worktree
        ~prompt:"/ review" ~session_id:None (fun _ -> ()));
  let command_processes = ref 0 in
  assert (
    try
      with_process
        ~check:(fun process ->
          incr command_processes;
          check_opencode [ "--command"; "missing" ] worktree process)
        [ "{\"type\":\"error\",\"sessionID\":\"command-session\"}" ]
        (Unix.WEXITED 1)
        (fun () ->
          Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.OpenCode
            ~cwd:worktree ~prompt:"/missing" ~session_id:None (fun _ -> ()));
      false
    with Failure _ -> true);
  assert (!command_processes = 1);
  assert (
    try
      with_process
        ~check:(check_opencode [ "--"; "failed" ] worktree)
        [ opencode_text "failed-session" "partial" ]
        (Unix.WSIGNALED Sys.sigterm)
        (fun () ->
          Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.OpenCode
            ~cwd:worktree ~prompt:"failed" ~session_id:None (fun _ -> ()));
      false
    with
    | Failure message -> message = "opencode failed"
    | _ -> false);
  assert (
    protocol_failure (fun () ->
        with_process
          ~check:(check_opencode [ "--"; "bad" ] worktree)
          [ "not-json" ] (Unix.WEXITED 0)
          (fun () ->
            Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.OpenCode
              ~cwd:worktree ~prompt:"bad" ~session_id:None (fun _ -> ()))));
  assert (
    protocol_failure (fun () ->
        with_process
          ~check:(check_opencode [ "--"; "missing" ] worktree)
          [ "{\"type\":\"unknown\"}" ]
          (Unix.WEXITED 0)
          (fun () ->
            Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.OpenCode
              ~cwd:worktree ~prompt:"missing" ~session_id:None (fun _ -> ()))));
  assert (
    protocol_failure (fun () ->
        with_process
          ~check:
            (check_opencode ~session:"expected" [ "--"; "mismatch" ] worktree)
          [ opencode_text "different" "text" ]
          (Unix.WEXITED 0)
          (fun () ->
            Remote_dev.Runtime.stream_prompt Remote_dev.Runtime.OpenCode
              ~cwd:worktree ~prompt:"mismatch" ~session_id:(Some "expected")
              (fun _ -> ()))));
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

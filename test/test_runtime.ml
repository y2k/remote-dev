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

let check_claude cwd prompt = function
  | Remote_dev.Runtime.Args ("/bin/sh", argv) ->
      assert (
        argv
        = [|
            "/bin/sh";
            "-c";
            "cd \"$1\" && exec claude --print --output-format stream-json \
             --verbose --include-partial-messages -- \"$2\"";
            "sh";
            cwd;
            prompt;
          |])
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

let () =
  let worktree = "worktree ; $literal" in
  let prompt = "-prompt with spaces; $(literal) \"quoted\"" in
  let output = ref [] in
  with_process
    ~check:(check_claude worktree prompt)
    [
      "{\"type\":\"system\",\"subtype\":\"init\"}";
      claude_delta "Hel";
      claude_delta "lo";
      "{\"type\":\"result\",\"result\":\"Hello\"}";
    ]
    (Unix.WEXITED 0)
    (fun () ->
      Remote_dev.Runtime.stream_claude worktree prompt (fun delta ->
          output := delta :: !output));
  assert (List.rev !output = [ "Hel"; "lo" ]);
  let failed_output = ref [] in
  assert (
    try
      with_process
        ~check:(check_claude worktree "--fail")
        [ claude_delta "Hel" ]
        (Unix.WEXITED 1)
        (fun () ->
          Remote_dev.Runtime.stream_claude worktree "--fail" (fun delta ->
              failed_output := delta :: !failed_output));
      false
    with Failure _ -> true);
  assert (List.rev !failed_output = [ "Hel" ]);
  assert (
    try
      with_process ~check:(check_claude worktree "--bad-json")
        [ "{bad json}" ] (Unix.WEXITED 0) (fun () ->
          Remote_dev.Runtime.stream_claude worktree "--bad-json" (fun _ -> ()));
      false
    with Yojson.Json_error _ -> true);
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

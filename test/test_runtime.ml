let with_process ~check lines (status : Unix.process_status) f =
  try f ()
  with effect Remote_dev.Runtime.Process_lines (process, on_line), k ->
    check process;
    List.iter on_line lines;
    Effect.Deep.continue k status

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
    with Failure _ -> true)

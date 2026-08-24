let () =
  let root = Filename.temp_file "remote_dev_claude_" "" in
  Unix.unlink root;
  Unix.mkdir root 0o700;
  let bin = Filename.concat root "bin" in
  let worktree = Filename.concat root "worktree ; $literal" in
  Unix.mkdir bin 0o700;
  Unix.mkdir worktree 0o700;
  let claude = Filename.concat bin "claude" in
  let channel = open_out claude in
  output_string channel
    "#!/bin/sh\n\
     if [ \"$#\" -ne 7 ] || [ \"$1\" != \"--print\" ] || [ \"$2\" != \
     \"--output-format\" ] || [ \"$3\" != \"stream-json\" ] || [ \"$4\" != \
     \"--verbose\" ] || [ \"$5\" != \"--include-partial-messages\" ] || [ \
     \"$6\" != \"--\" ]; then\n\
     exit 2\n\
     fi\n\
     if [ \"$7\" = \"--bad-json\" ]; then\n\
     printf '{bad json}\\n'\n\
     exit 0\n\
     fi\n\
     if [ \"$7\" = \"--fail\" ]; then\n\
     printf \
     '{\"type\":\"stream_event\",\"event\":{\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Hel\"}}}\\n'\n\
     exit 1\n\
     fi\n\
     if [ \"$PWD\" != \"$EXPECTED_CWD\" ] || [ \"$7\" != \"$EXPECTED_PROMPT\" \
     ]; then\n\
     exit 2\n\
     fi\n\
     printf '{\"type\":\"system\",\"subtype\":\"init\"}\\n'\n\
     printf \
     '{\"type\":\"stream_event\",\"event\":{\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"Hel\"}}}\\n'\n\
     printf \
     '{\"type\":\"stream_event\",\"event\":{\"type\":\"content_block_delta\",\"delta\":{\"type\":\"text_delta\",\"text\":\"lo\"}}}\\n'\n\
     printf '{\"type\":\"result\",\"result\":\"Hello\"}\\n'\n";
  close_out channel;
  Unix.chmod claude 0o700;
  let old_path = Sys.getenv_opt "PATH" in
  Unix.putenv "PATH" (bin ^ ":" ^ Option.value ~default:"" old_path);
  Unix.putenv "EXPECTED_CWD" worktree;
  Fun.protect
    ~finally:(fun () ->
      Unix.putenv "PATH" (Option.value ~default:"" old_path);
      Unix.putenv "EXPECTED_CWD" "";
      Unix.putenv "EXPECTED_PROMPT" "";
      Unix.unlink claude;
      Unix.rmdir bin;
      Unix.rmdir worktree;
      Unix.rmdir root)
    (fun () ->
      let prompt = "-prompt with spaces; $(literal) \"quoted\"" in
      Unix.putenv "EXPECTED_PROMPT" prompt;
      let output = ref [] in
      Remote_dev.Runtime.stream_claude worktree prompt (fun delta ->
          output := delta :: !output);
      assert (List.rev !output = [ "Hel"; "lo" ]);
      let failed_output = ref [] in
      assert (
        try
          Remote_dev.Runtime.stream_claude worktree "--fail" (fun delta ->
              failed_output := delta :: !failed_output);
          false
        with Failure _ -> true);
      assert (List.rev !failed_output = [ "Hel" ]);
      assert (
        try
          Remote_dev.Runtime.stream_claude worktree "--bad-json" (fun _ -> ());
          false
        with Yojson.Json_error _ -> true))

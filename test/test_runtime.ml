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
     if [ \"$#\" -ne 3 ] || [ \"$1\" != \"--print\" ] || [ \"$2\" != \"--\" ]; \
     then\n\
     exit 2\n\
     fi\n\
     if [ \"$3\" = \"--fail\" ]; then\n\
     exit 1\n\
     fi\n\
     printf 'cwd=%s\\nprompt=%s\\n' \"$PWD\" \"$3\"\n";
  close_out channel;
  Unix.chmod claude 0o700;
  let old_path = Sys.getenv_opt "PATH" in
  Unix.putenv "PATH" (bin ^ ":" ^ Option.value ~default:"" old_path);
  Fun.protect
    ~finally:(fun () ->
      Unix.putenv "PATH" (Option.value ~default:"" old_path);
      Unix.unlink claude;
      Unix.rmdir bin;
      Unix.rmdir worktree;
      Unix.rmdir root)
    (fun () ->
      let prompt = "-prompt with spaces; $(literal) \"quoted\"" in
      assert (
        Remote_dev.Runtime.run_claude worktree prompt
        = "cwd=" ^ worktree ^ "\nprompt=" ^ prompt ^ "\n");
      assert (
        try
          ignore (Remote_dev.Runtime.run_claude worktree "--fail");
          false
        with Failure _ -> true))

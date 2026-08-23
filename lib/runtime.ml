type worktree = { path : string; branch : string }

let load_worktrees (path : string) : worktree list =
  let command =
    "git -C " ^ Filename.quote path ^ " worktree list --porcelain"
  in
  let channel = Unix.open_process_in command in
  let add_worktree worktrees = function
    | Some (Some path, Some branch) -> { path; branch } :: worktrees
    | _ -> worktrees
  in
  let rec read worktrees current =
    match input_line channel with
    | line ->
        if String.starts_with ~prefix:"worktree " line then
          read
            (add_worktree worktrees current)
            (Some (Some (String.sub line 9 (String.length line - 9)), None))
        else if String.starts_with ~prefix:"branch refs/heads/" line then
          read worktrees
            (Option.map
               (fun (path, _) ->
                 (path, Some (String.sub line 18 (String.length line - 18))))
               current)
        else read worktrees current
    | exception End_of_file -> (
        let worktrees = List.rev (add_worktree worktrees current) in
        match Unix.close_process_in channel with
        | Unix.WEXITED 0 -> worktrees
        | _ -> failwith "git worktree list failed")
  in
  read [] None

let run_claude (cwd : string) (prompt : string) : string =
  (* ponytail: shell wrapper provides child-only cwd and inherited stderr; use fork/pipe only if stderr capture is needed. *)
  let channel =
    Unix.open_process_args_in "/bin/sh"
      [|
        "/bin/sh";
        "-c";
        "cd \"$1\" && exec claude --print -- \"$2\"";
        "sh";
        cwd;
        prompt;
      |]
  in
  let output = In_channel.input_all channel in
  match Unix.close_process_in channel with
  | Unix.WEXITED 0 -> output
  | _ -> failwith "claude failed"

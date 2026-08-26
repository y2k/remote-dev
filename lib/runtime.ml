type worktree = { path : string; branch : string } [@@deriving yojson]

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

let stream_claude (cwd : string) (prompt : string) on_delta : unit =
  (* ponytail: shell wrapper provides child-only cwd and inherited stderr; use fork/pipe only if stderr capture is needed. *)
  let channel =
    Unix.open_process_args_in "/bin/sh"
      [|
        "/bin/sh";
        "-c";
        "cd \"$1\" && exec claude --print --output-format stream-json \
         --verbose --include-partial-messages -- \"$2\"";
        "sh";
        cwd;
        prompt;
      |]
  in
  let field name fields = List.assoc_opt name fields in
  let text_delta line =
    match Yojson.Basic.from_string line with
    | `Assoc fields -> (
        match (field "type" fields, field "event" fields) with
        | Some (`String "stream_event"), Some (`Assoc event) -> (
            match (field "type" event, field "delta" event) with
            | Some (`String "content_block_delta"), Some (`Assoc delta) -> (
                match (field "type" delta, field "text" delta) with
                | Some (`String "text_delta"), Some (`String text) -> Some text
                | _ -> None)
            | _ -> None)
        | _ -> None)
    | _ -> None
  in
  let rec read () =
    match input_line channel with
    | line ->
        (match text_delta line with Some text -> on_delta text | None -> ());
        read ()
    | exception End_of_file -> ()
  in
  let result = try Ok (read ()) with exn -> Error exn in
  match (result, Unix.close_process_in channel) with
  | Ok (), Unix.WEXITED 0 -> ()
  | Error exn, _ -> raise exn
  | Ok (), _ -> failwith "claude failed"

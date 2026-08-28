type worktree = { path : string; branch : string } [@@deriving yojson]
type process = Shell of string | Args of string * string array

type _ Effect.t +=
  | Process_lines : (process * (string -> unit)) -> Unix.process_status Effect.t

let with_unix_process f =
  try f ()
  with effect Process_lines (process, on_line), k ->
    let channel =
      match process with
      | Shell command -> Unix.open_process_in command
      | Args (program, argv) -> Unix.open_process_args_in program argv
    in
    let rec read () =
      match input_line channel with
      | line ->
          on_line line;
          read ()
      | exception End_of_file -> ()
    in
    let status : Unix.process_status =
      match try Ok (read ()) with exn -> Error exn with
      | Ok () -> Unix.close_process_in channel
      | Error exn ->
          (try ignore (Unix.close_process_in channel) with _ -> ());
          raise exn
    in
    Effect.Deep.continue k status

let load_worktrees (path : string) : worktree list =
  let command =
    "git -C " ^ Filename.quote path ^ " worktree list --porcelain"
  in
  let add_worktree worktrees = function
    | Some (Some path, Some branch) -> { path; branch } :: worktrees
    | _ -> worktrees
  in
  let rec parse worktrees current = function
    | line :: lines ->
        if String.starts_with ~prefix:"worktree " line then
          parse
            (add_worktree worktrees current)
            (Some (Some (String.sub line 9 (String.length line - 9)), None))
            lines
        else if String.starts_with ~prefix:"branch refs/heads/" line then
          parse worktrees
            (Option.map
               (fun (path, _) ->
                 (path, Some (String.sub line 18 (String.length line - 18))))
               current)
            lines
        else parse worktrees current lines
    | [] -> List.rev (add_worktree worktrees current)
  in
  let lines = ref [] in
  match
    Effect.perform
      (Process_lines (Shell command, fun line -> lines := line :: !lines))
  with
  | Unix.WEXITED 0 -> parse [] None (List.rev !lines)
  | _ -> failwith "git worktree list failed"

let create_worktree (root : string) (name : string) : unit =
  match
    Effect.perform
      (Process_lines
         ( Args
             ( "/bin/sh",
               [|
                 "/bin/sh";
                 "-c";
                 "cd \"$1\" && exec claude --worktree \"$2\" --print --tools \
                  '' -- \"$3\"";
                 "sh";
                 root;
                 name;
                 "Reply only: READY.";
               |] ),
           fun _ -> () ))
  with
  | Unix.WEXITED 0 -> ()
  | _ -> failwith "claude worktree creation failed"

let stream_claude (cwd : string) (prompt : string) on_delta : unit =
  (* ponytail: shell wrapper provides child-only cwd and inherited stderr; use fork/pipe only if stderr capture is needed. *)
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
  match
    Effect.perform
      (Process_lines
         ( Args
             ( "/bin/sh",
               [|
                 "/bin/sh";
                 "-c";
                 "cd \"$1\" && exec claude --print --output-format stream-json \
                  --verbose --include-partial-messages -- \"$2\"";
                 "sh";
                 cwd;
                 prompt;
               |] ),
           fun line ->
             match text_delta line with
             | Some text -> on_delta text
             | None -> () ))
  with
  | Unix.WEXITED 0 -> ()
  | _ -> failwith "claude failed"

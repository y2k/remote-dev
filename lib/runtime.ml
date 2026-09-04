type worktree = { path : string; branch : string } [@@deriving yojson]
type emulator = { serial : string; name : string } [@@deriving yojson]
type process = Shell of string | Args of string * string array
type agent = Claude | OpenCode
type environment = { agent : agent; root : string }
type stream_event = Session of string | Text of string

exception Protocol_error of string

let parse_args argv =
  let agent = ref None and root = ref None in
  let set_agent value =
    if Option.is_some !agent then
      raise (Arg.Bad "--agent specified more than once");
    agent :=
      Some
        (match value with
        | "claude" -> Claude
        | "opencode" -> OpenCode
        | _ -> raise (Arg.Bad "--agent must be claude or opencode"))
  in
  let set_root value =
    match !root with
    | None -> root := Some value
    | Some _ -> raise (Arg.Bad "only one repository root is allowed")
  in
  let current = ref 0 in
  let usage = "Usage: remote_dev --agent claude|opencode [repository-root]" in
  let options =
    [ ("--agent", Arg.String set_agent, "claude|opencode Coding agent") ]
  in
  Arg.parse_argv ~current argv options set_root usage;
  match !agent with
  | Some agent -> { agent; root = Option.value ~default:(Sys.getcwd ()) !root }
  | None ->
      raise (Arg.Bad ("--agent is required\n" ^ Arg.usage_string options usage))

type _ Effect.t +=
  | Process_lines : (process * (string -> unit)) -> Unix.process_status Effect.t
  | Process_bytes : process -> (string * Unix.process_status) Effect.t

let open_process = function
  | Shell command -> Unix.open_process_in command
  | Args (program, argv) -> Unix.open_process_args_in program argv

let with_unix_process f =
  try f () with
  | effect Process_lines (process, on_line), k ->
      let channel = open_process process in
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
  | effect Process_bytes process, k ->
      let channel = open_process process in
      let buffer = Buffer.create 4096 in
      let bytes = Bytes.create 4096 in
      let rec read () =
        match input channel bytes 0 (Bytes.length bytes) with
        | 0 -> ()
        | length ->
            Buffer.add_subbytes buffer bytes 0 length;
            read ()
      in
      let status : Unix.process_status =
        match try Ok (read ()) with exn -> Error exn with
        | Ok () -> Unix.close_process_in channel
        | Error exn ->
            (try ignore (Unix.close_process_in channel) with _ -> ());
            raise exn
      in
      Effect.Deep.continue k (Buffer.contents buffer, status)

let lines process =
  let output = ref [] in
  match
    Effect.perform
      (Process_lines (process, fun line -> output := line :: !output))
  with
  | Unix.WEXITED 0 -> List.rev !output
  | _ -> failwith "process failed"

let words line =
  line |> String.split_on_char '\t'
  |> List.concat_map (String.split_on_char ' ')
  |> List.filter (fun word -> word <> "")

let running_emulator_serials () =
  lines (Args ("adb", [| "adb"; "devices"; "-l" |]))
  |> List.filter_map (fun line ->
      match words line with
      | serial :: "device" :: _
        when String.starts_with ~prefix:"emulator-" serial ->
          Some serial
      | _ -> None)

let emulator_name serial =
  match
    lines (Args ("adb", [| "adb"; "-s"; serial; "emu"; "avd"; "name" |]))
  with
  | name :: _ when name <> "" && name <> "OK" -> name
  | _ -> serial

let load_emulators () =
  running_emulator_serials ()
  |> List.map (fun serial ->
      let name = try emulator_name serial with Failure _ -> serial in
      { serial; name })

let capture_emulator_screenshot serial =
  match
    Effect.perform
      (Process_bytes
         (Args ("adb", [| "adb"; "-s"; serial; "exec-out"; "screencap"; "-p" |])))
  with
  | screenshot, Unix.WEXITED 0 -> screenshot
  | _ -> failwith "emulator screenshot failed"

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
  try parse [] None (lines (Shell command))
  with Failure _ -> failwith "git worktree list failed"

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

let field name fields = List.assoc_opt name fields

let json line =
  try Yojson.Basic.from_string line
  with Yojson.Json_error _ -> raise (Protocol_error "malformed agent JSON")

let claude_events line =
  match json line with
  | `Assoc fields ->
      let session =
        match field "session_id" fields with
        | Some (`String session_id) -> [ Session session_id ]
        | Some _ -> raise (Protocol_error "invalid Claude session ID")
        | None -> []
      in
      let text =
        match (field "type" fields, field "event" fields) with
        | Some (`String "stream_event"), Some (`Assoc event) -> (
            match (field "type" event, field "delta" event) with
            | Some (`String "content_block_delta"), Some (`Assoc delta) -> (
                match (field "type" delta, field "text" delta) with
                | Some (`String "text_delta"), Some (`String text) ->
                    [ Text text ]
                | _ -> [])
            | _ -> [])
        | _ -> []
      in
      session @ text
  | _ -> []

let opencode_events line =
  match json line with
  | `Assoc fields ->
      let session =
        match field "sessionID" fields with
        | Some (`String session_id) -> [ Session session_id ]
        | Some _ -> raise (Protocol_error "invalid OpenCode session ID")
        | None -> []
      in
      let text =
        match (field "type" fields, field "part" fields) with
        | Some (`String "text"), Some (`Assoc part) -> (
            match (field "type" part, field "text" part) with
            | Some (`String "text"), Some (`String text) -> [ Text text ]
            | _ -> [])
        | _ -> []
      in
      session @ text
  | _ -> []

let claude_process cwd prompt session_id =
  let command, arguments =
    match session_id with
    | None ->
        ( "cd \"$1\" && exec claude --print --output-format stream-json \
           --verbose --include-partial-messages -- \"$2\"",
          [ cwd; prompt ] )
    | Some session_id ->
        ( "cd \"$1\" && exec claude --print --output-format stream-json \
           --verbose --include-partial-messages --resume \"$2\" -- \"$3\"",
          [ cwd; session_id; prompt ] )
  in
  Args
    ("/bin/sh", Array.of_list ([ "/bin/sh"; "-c"; command; "sh" ] @ arguments))

let is_space = function ' ' | '\t' | '\n' | '\r' -> true | _ -> false

let opencode_input prompt =
  let input = String.trim prompt in
  if String.length input < 2 || input.[0] <> '/' then `Prompt prompt
  else
    let rec boundary index =
      if index = String.length input || is_space input.[index] then index
      else boundary (index + 1)
    in
    let index = boundary 1 in
    if index = 1 then `Prompt prompt
    else
      let command = String.sub input 1 (index - 1) in
      let arguments =
        String.sub input index (String.length input - index) |> String.trim
      in
      `Command (command, arguments)

(* OpenCode 1.18.20 rejoins argv with spaces and quotes arguments that contain
   one, so splitting only on spaces preserves the exact original input. *)
let opencode_message value = "--" :: String.split_on_char ' ' value

let opencode_process cwd prompt session_id =
  let arguments =
    [ "opencode"; "run"; "--dir"; cwd; "--format"; "json"; "--auto" ]
    @
    match session_id with
    | Some session_id -> [ "--session"; session_id ]
    | None -> []
  in
  let arguments =
    arguments
    @
    match opencode_input prompt with
    | `Prompt prompt -> opencode_message prompt
    | `Command (command, "") -> [ "--command"; command ]
    | `Command (command, arguments) ->
        [ "--command"; command ] @ opencode_message arguments
  in
  Args ("opencode", Array.of_list arguments)

let stream_prompt agent ~cwd ~prompt ~session_id on_event =
  let seen_session = ref None in
  let emit = function
    | Session id when id = "" -> raise (Protocol_error "empty session ID")
    | Session id -> (
        (match session_id with
        | Some requested when requested <> id ->
            raise (Protocol_error "resumed session ID changed")
        | Some _ | None -> ());
        match !seen_session with
        | None ->
            seen_session := Some id;
            on_event (Session id)
        | Some previous when previous <> id ->
            raise (Protocol_error "conflicting session IDs")
        | Some _ -> ())
    | Text _ as event -> on_event event
  in
  let process, parse, failure =
    match agent with
    | Claude ->
        (claude_process cwd prompt session_id, claude_events, "claude failed")
    | OpenCode ->
        ( opencode_process cwd prompt session_id,
          opencode_events,
          "opencode failed" )
  in
  match
    Effect.perform
      (Process_lines (process, fun line -> List.iter emit (parse line)))
  with
  | Unix.WEXITED 0 when Option.is_none !seen_session ->
      raise (Protocol_error "agent stream omitted session ID")
  | Unix.WEXITED 0 -> ()
  | _ -> failwith failure

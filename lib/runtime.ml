type worktree = { path : string; branch : string } [@@deriving yojson]
type emulator = { serial : string; name : string } [@@deriving yojson]
type process = Shell of string | Args of string * string array
type agent = Claude_agent | OpenCode_agent
type environment = Claude of { root : string } | OpenCode
type stream_event = Session of string | Text of string
type opencode_status = Idle | Busy | Retry of string [@@deriving yojson]

type opencode_session = {
  id : string;
  title : string;
  directory : string;
  workspace : string option;
  agent : string option;
  model : (string * string * string option) option;
  status : opencode_status;
}
[@@deriving yojson]

type opencode_role = User | Assistant [@@deriving yojson]

type opencode_message = { role : opencode_role; text : string }
[@@deriving yojson]

type opencode_detail = {
  session : opencode_session;
  messages : opencode_message list;
  needs_input : bool;
}
[@@deriving yojson]

type http_request = {
  meth : Httpun.Method.t;
  target : string;
  headers : (string * string) list;
  body : string;
}

type http_response = { status : int; body : string }

exception Protocol_error of string
exception OpenCode_not_found

let parse_args argv =
  let agent = ref None and root = ref None in
  let set_agent value =
    if Option.is_some !agent then
      raise (Arg.Bad "--agent specified more than once");
    agent :=
      Some
        (match value with
        | "claude" -> Claude_agent
        | "opencode" -> OpenCode_agent
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
  match (!agent, !root) with
  | Some Claude_agent, root ->
      Claude { root = Option.value ~default:(Sys.getcwd ()) root }
  | Some OpenCode_agent, None -> OpenCode
  | Some OpenCode_agent, Some _ ->
      raise
        (Arg.Bad
           ("repository root is only valid with --agent claude\n"
           ^ Arg.usage_string options usage))
  | None, _ ->
      raise (Arg.Bad ("--agent is required\n" ^ Arg.usage_string options usage))

type _ Effect.t +=
  | Process_lines : (process * (string -> unit)) -> Unix.process_status Effect.t
  | Process_bytes : process -> (string * Unix.process_status) Effect.t
  | Http_request : http_request -> http_response Effect.t

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

let http_error = function
  | `Malformed_response message -> message
  | `Invalid_response_body_length _ -> "invalid response body length"
  | `Exn exn -> Printexc.to_string exn

let request_http ~net (request : http_request) =
  Eio.Switch.run @@ fun sw ->
  let socket =
    Eio.Net.connect ~sw net (`Tcp (Eio.Net.Ipaddr.V4.loopback, 4096))
  in
  let client = Httpun_eio.Client.create_connection ~sw socket in
  let finished, resolve = Eio.Promise.create () in
  let response_handler response reader =
    let body = Buffer.create 4096 in
    let rec on_read chunk ~off ~len =
      Buffer.add_string body (Bigstringaf.substring chunk ~off ~len);
      Httpun.Body.Reader.schedule_read reader ~on_eof ~on_read
    and on_eof () =
      ignore
        (Eio.Promise.try_resolve resolve
           (Ok
              {
                status = Httpun.Status.to_code response.Httpun.Response.status;
                body = Buffer.contents body;
              }))
    in
    Httpun.Body.Reader.schedule_read reader ~on_eof ~on_read
  in
  let error_handler error =
    ignore (Eio.Promise.try_resolve resolve (Error (http_error error)))
  in
  let headers =
    Httpun.Headers.of_list
      (("host", "127.0.0.1:4096")
      :: ("content-length", string_of_int (String.length request.body))
      :: request.headers)
  in
  let writer =
    Httpun_eio.Client.request client
      (Httpun.Request.create ~headers request.meth request.target)
      ~error_handler ~response_handler
  in
  Httpun.Body.Writer.write_string writer request.body;
  Httpun.Body.Writer.close writer;
  let response = Eio.Promise.await finished in
  Eio.Promise.await (Httpun_eio.Client.shutdown client);
  match response with
  | Ok response -> response
  | Error message -> failwith message

let with_http (handle : http_request -> http_response) f =
  try f ()
  with effect Http_request request, k -> (
    match handle request with
    | response -> Effect.Deep.continue k response
    | exception exn -> Effect.Deep.discontinue k exn)

let with_opencode_http ~net = with_http (request_http ~net)

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

let stream_claude ~cwd ~prompt ~session_id on_event =
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
  match
    Effect.perform
      (Process_lines
         ( claude_process cwd prompt session_id,
           fun line -> List.iter emit (claude_events line) ))
  with
  | Unix.WEXITED 0 when Option.is_none !seen_session ->
      raise (Protocol_error "agent stream omitted session ID")
  | Unix.WEXITED 0 -> ()
  | _ -> failwith "claude failed"

let required_string name fields =
  match field name fields with
  | Some (`String value) -> value
  | _ -> raise (Protocol_error ("invalid OpenCode " ^ name))

let required_assoc name fields =
  match field name fields with
  | Some (`Assoc value) -> value
  | _ -> raise (Protocol_error ("invalid OpenCode " ^ name))

let required_list name fields =
  match field name fields with
  | Some (`List value) -> value
  | _ -> raise (Protocol_error ("invalid OpenCode " ^ name))

let optional_string name fields =
  match field name fields with
  | None | Some `Null -> None
  | Some (`String value) -> Some value
  | Some _ -> raise (Protocol_error ("invalid OpenCode " ^ name))

let required_timestamp name fields =
  match field name fields with
  | Some (`Int value) -> string_of_int value
  | Some (`Float value) -> Printf.sprintf "%.0f" value
  | _ -> raise (Protocol_error ("invalid OpenCode " ^ name))

let opencode_session = function
  | `Assoc fields ->
      let model =
        match field "model" fields with
        | None | Some `Null -> None
        | Some (`Assoc model) ->
            Some
              ( required_string "providerID" model,
                required_string "id" model,
                optional_string "variant" model )
        | Some _ -> raise (Protocol_error "invalid OpenCode model")
      in
      let updated =
        required_assoc "time" fields |> required_timestamp "updated"
      in
      ( {
          id = required_string "id" fields;
          title = required_string "title" fields;
          directory = required_string "directory" fields;
          workspace = optional_string "workspaceID" fields;
          agent = optional_string "agent" fields;
          model;
          status = Idle;
        },
        updated )
  | _ -> raise (Protocol_error "invalid OpenCode session")

let opencode_session_page body =
  match json body with
  | `List sessions -> List.map opencode_session sessions
  | _ -> raise (Protocol_error "invalid OpenCode session list")

let opencode_sessions body = opencode_session_page body |> List.map fst

let opencode_status = function
  | `Assoc fields -> (
      match required_string "type" fields with
      | "idle" -> Idle
      | "busy" -> Busy
      | "retry" -> Retry (required_string "message" fields)
      | _ -> raise (Protocol_error "invalid OpenCode session status"))
  | _ -> raise (Protocol_error "invalid OpenCode session status")

let opencode_statuses body =
  match json body with
  | `Assoc fields ->
      List.map (fun (id, value) -> (id, opencode_status value)) fields
  | _ -> raise (Protocol_error "invalid OpenCode status list")

let opencode_pending body =
  match json body with
  | `List requests ->
      List.map
        (function
          | `Assoc fields -> required_string "sessionID" fields
          | _ -> raise (Protocol_error "invalid OpenCode pending input"))
        requests
  | _ -> raise (Protocol_error "invalid OpenCode pending input list")

let opencode_role fields =
  match required_string "role" fields with
  | "user" -> User
  | "assistant" -> Assistant
  | _ -> raise (Protocol_error "invalid OpenCode message role")

let opencode_messages body =
  match json body with
  | `List messages ->
      List.concat_map
        (function
          | `Assoc fields ->
              let role = opencode_role (required_assoc "info" fields) in
              required_list "parts" fields
              |> List.filter_map (function
                | `Assoc part when field "type" part = Some (`String "text") ->
                    Some { role; text = required_string "text" part }
                | _ -> None)
          | _ -> raise (Protocol_error "invalid OpenCode message"))
        messages
  | _ -> raise (Protocol_error "invalid OpenCode message list")

let opencode_context session model =
  Option.to_list
    (Option.map (fun agent -> ("agent", `String agent)) session.agent)
  @
  match session.model with
  | None -> []
  | Some (provider, id, variant) ->
      ("model", model provider id)
      :: Option.to_list
           (Option.map (fun value -> ("variant", `String value)) variant)

let opencode_prompt_body session prompt =
  `Assoc
    (opencode_context session (fun provider model ->
         `Assoc [ ("providerID", `String provider); ("modelID", `String model) ])
    @ [
        ( "parts",
          `List
            [ `Assoc [ ("type", `String "text"); ("text", `String prompt) ] ] );
      ])
  |> Yojson.Basic.to_string

let opencode_command_body session command arguments =
  `Assoc
    (opencode_context session (fun provider model ->
         `String (provider ^ "/" ^ model))
    @ [ ("command", `String command); ("arguments", `String arguments) ])
  |> Yojson.Basic.to_string

let is_uri_component = function
  | 'A' .. 'Z'
  | 'a' .. 'z'
  | '0' .. '9'
  | '-' | '_' | '.' | '!' | '~' | '*' | '\'' | '(' | ')' ->
      true
  | _ -> false

let uri_component value =
  let output = Buffer.create (String.length value) in
  String.iter
    (fun character ->
      if is_uri_component character then Buffer.add_char output character
      else
        Buffer.add_string output (Printf.sprintf "%%%02X" (Char.code character)))
    value;
  Buffer.contents output

let perform_http ?directory ?workspace meth target body =
  let target, headers =
    match (meth, directory) with
    | `GET, Some directory ->
        let query =
          "directory=" ^ uri_component directory
          ^
          match workspace with
          | Some workspace -> "&workspace=" ^ uri_component workspace
          | None -> ""
        in
        ( (target
          ^ if String.contains target '?' then "&" ^ query else "?" ^ query),
          [] )
    | `POST, Some directory ->
        ( (match workspace with
          | Some workspace -> target ^ "?workspace=" ^ uri_component workspace
          | None -> target),
          [ ("x-opencode-directory", uri_component directory) ] )
    | (`GET | `POST), None -> (target, [])
    | _ -> assert false
  in
  let headers =
    if meth = `POST && body <> "" then
      ("content-type", "application/json") :: headers
    else headers
  in
  Effect.perform (Http_request { meth; target; headers; body })

let expect_status expected { status; body } =
  if status = expected then body
  else if status = 404 then raise OpenCode_not_found
  else
    failwith
      (Printf.sprintf "OpenCode server returned HTTP %d%s" status
         (if body = "" then "" else ": " ^ body))

let get ?directory ?workspace target =
  perform_http ?directory ?workspace `GET target "" |> expect_status 200

let post ?directory ?workspace ?(body = "") expected target =
  perform_http ?directory ?workspace `POST target body |> expect_status expected

let session_status statuses id =
  Option.value ~default:Idle (List.assoc_opt id statuses)

let load_opencode_sessions () =
  let rec load cursor sessions =
    let target =
      "/experimental/session?limit=100"
      ^ match cursor with Some value -> "&cursor=" ^ value | None -> ""
    in
    let page = get target |> opencode_session_page in
    let sessions = List.rev_append (List.map fst page) sessions in
    if List.length page < 100 then List.rev sessions
    else load (List.rev page |> List.hd |> snd |> Option.some) sessions
  in
  let sessions = load None [] in
  let statuses =
    sessions
    |> List.map (fun session -> (session.directory, session.workspace))
    |> List.sort_uniq compare
    |> List.concat_map (fun (directory, workspace) ->
        get ~directory ?workspace "/session/status" |> opencode_statuses)
  in
  List.map
    (fun (session : opencode_session) ->
      { session with status = session_status statuses session.id })
    sessions

let load_opencode_detail (session : opencode_session) =
  let directory = session.directory in
  let id = uri_component session.id in
  let messages =
    get ~directory ?workspace:session.workspace ("/session/" ^ id ^ "/message")
    |> opencode_messages
  in
  let statuses =
    get ~directory ?workspace:session.workspace "/session/status"
    |> opencode_statuses
  in
  let permissions =
    get ~directory ?workspace:session.workspace "/permission"
    |> opencode_pending
  in
  let questions =
    get ~directory ?workspace:session.workspace "/question" |> opencode_pending
  in
  {
    session = { session with status = session_status statuses session.id };
    messages;
    needs_input =
      List.mem session.id permissions || List.mem session.id questions;
  }

let submit_opencode_prompt session prompt =
  ignore
    (post ~directory:session.directory ?workspace:session.workspace
       ~body:(opencode_prompt_body session prompt)
       204
       ("/session/" ^ uri_component session.id ^ "/prompt_async"))

let validate_command_response body =
  match json body with
  | `Assoc fields ->
      ignore (required_assoc "info" fields);
      ignore (required_list "parts" fields)
  | _ -> raise (Protocol_error "invalid OpenCode command response")

let submit_opencode_command session command arguments =
  post ~directory:session.directory ?workspace:session.workspace
    ~body:(opencode_command_body session command arguments)
    200
    ("/session/" ^ uri_component session.id ^ "/command")
  |> validate_command_response

let abort_opencode session =
  match
    post ~directory:session.directory ?workspace:session.workspace 200
      ("/session/" ^ uri_component session.id ^ "/abort")
    |> json
  with
  | `Bool true -> ()
  | _ -> raise (Protocol_error "invalid OpenCode abort response")

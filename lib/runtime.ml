type worktree = { path : string; branch : string } [@@deriving yojson]
type emulator = { serial : string; name : string } [@@deriving yojson]
type process = Shell of string | Args of string * string array
type agent = Claude_agent | OpenCode_agent
type environment = Claude of { root : string } | OpenCode of { root : string }
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

type opencode_endpoint = {
  host : string;
  address : Eio.Net.Ipaddr.v4v6;
  port : int;
  pid : int;
  version : string option;
  password : string option;
}

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
    | Some _ -> raise (Arg.Bad "only one directory is allowed")
  in
  let current = ref 0 in
  let usage = "Usage: remote_dev --agent claude|opencode [directory]" in
  let options =
    [ ("--agent", Arg.String set_agent, "claude|opencode Coding agent") ]
  in
  Arg.parse_argv ~current argv options set_root usage;
  let cwd = Sys.getcwd () in
  let root = Option.value ~default:cwd !root in
  let root =
    if Filename.is_relative root then Filename.concat cwd root else root
  in
  match !agent with
  | Some Claude_agent -> Claude { root }
  | Some OpenCode_agent -> OpenCode { root }
  | None ->
      raise (Arg.Bad ("--agent is required\n" ^ Arg.usage_string options usage))

type _ Effect.t +=
  | Process_lines : (process * (string -> unit)) -> Unix.process_status Effect.t
  | Process_bytes : process -> (string * Unix.process_status) Effect.t
  | Http_request : http_request -> http_response Effect.t
  | OpenCode_connect : unit Effect.t

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

let request_http ~net endpoint (request : http_request) =
  Eio.Switch.run @@ fun sw ->
  let socket =
    Eio.Net.connect ~sw net (`Tcp (endpoint.address, endpoint.port))
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
      (("host", endpoint.host)
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

let with_http ?(connect = fun () -> ()) (handle : http_request -> http_response)
    f =
  try f () with
  | effect OpenCode_connect, k -> (
      match connect () with
      | () -> Effect.Deep.continue k ()
      | exception exn -> Effect.Deep.discontinue k exn)
  | effect Http_request request, k -> (
      match handle request with
      | response -> Effect.Deep.continue k response
      | exception exn -> Effect.Deep.discontinue k exn)

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

let tap_emulator serial ~x ~y =
  match
    Effect.perform
      (Process_lines
         ( Args
             ( "adb",
               [|
                 "adb";
                 "-s";
                 serial;
                 "shell";
                 "input";
                 "tap";
                 string_of_int x;
                 string_of_int y;
               |] ),
           ignore ))
  with
  | Unix.WEXITED 0 -> ()
  | _ -> failwith "emulator tap failed"

let capture_emulator_screenshot serial =
  match
    Effect.perform
      (Process_bytes
         (Args ("adb", [| "adb"; "-s"; serial; "exec-out"; "screencap"; "-p" |])))
  with
  | screenshot, Unix.WEXITED 0 -> screenshot
  | _ -> failwith "emulator screenshot failed"

let load_directories root =
  (* ponytail: full scan and O(n log n) sort; use bounded top-10 if large-directory
     measurements show sorting is a bottleneck. *)
  Sys.readdir root |> Array.to_list
  |> List.filter_map (fun name ->
      let stat = Unix.lstat (Filename.concat root name) in
      if stat.st_kind = Unix.S_DIR then Some (name, stat.st_mtime) else None)
  |> List.sort (fun (a, a_time) (b, b_time) ->
      let order = Float.compare b_time a_time in
      if order = 0 then String.compare a b else order)
  |> List.take 10 |> List.map fst

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

let opencode_registration_path ?(getenv = Sys.getenv_opt) () =
  let state =
    match getenv "XDG_STATE_HOME" with
    | Some path -> path
    | None -> (
        match getenv "HOME" with
        | Some home -> Filename.concat home ".local/state"
        | None -> failwith "OpenCode service registration directory unavailable"
        )
  in
  Filename.concat state "opencode/service.json"

let read_opencode_registration () =
  In_channel.with_open_bin (opencode_registration_path ()) In_channel.input_all

let opencode_endpoint body =
  let invalid () =
    raise (Protocol_error "invalid OpenCode service registration")
  in
  try
    let fields =
      match json body with `Assoc fields -> fields | _ -> invalid ()
    in
    let url = required_string "url" fields in
    if not (String.starts_with ~prefix:"http://" url) then invalid ();
    let host = String.sub url 7 (String.length url - 7) in
    let host =
      if String.ends_with ~suffix:"/" host then
        String.sub host 0 (String.length host - 1)
      else host
    in
    let colon = String.rindex host ':' in
    let hostname = String.sub host 0 colon in
    let port_text =
      String.sub host (colon + 1) (String.length host - colon - 1)
    in
    if
      port_text = ""
      || not
           (String.for_all
              (function '0' .. '9' -> true | _ -> false)
              port_text)
    then invalid ();
    let port = int_of_string port_text in
    if port < 1 || port > 65535 then invalid ();
    let address =
      match hostname with
      | "localhost" | "127.0.0.1" -> Eio.Net.Ipaddr.V4.loopback
      | "[::1]" -> Eio.Net.Ipaddr.V6.loopback
      | _ -> invalid ()
    in
    let pid =
      match field "pid" fields with
      | Some (`Int pid) when pid > 0 -> pid
      | _ -> invalid ()
    in
    {
      host;
      address;
      port;
      pid;
      version = optional_string "version" fields;
      password = optional_string "password" fields;
    }
  with Protocol_error _ | Failure _ | Invalid_argument _ | Not_found ->
    invalid ()

let opencode_auth endpoint =
  match endpoint.password with
  | None -> []
  | Some password ->
      [
        ("authorization", "Basic " ^ Base64.encode_exn ("opencode:" ^ password));
      ]

let discover_opencode ~clock ?(read = read_opencode_registration) ~request () =
  let endpoint =
    let body =
      try read ()
      with Sys_error _ -> failwith "OpenCode service registration unavailable"
    in
    opencode_endpoint body
  in
  let response =
    try
      Eio.Time.with_timeout_exn clock 5. (fun () ->
          request endpoint
            {
              meth = `GET;
              target = "/api/info";
              headers = opencode_auth endpoint;
              body = "";
            })
    with Eio.Time.Timeout ->
      failwith "OpenCode service health check timed out"
  in
  if response.status <> 200 then
    failwith (Printf.sprintf "OpenCode server returned HTTP %d" response.status);
  let fields =
    match json response.body with
    | `Assoc fields -> fields
    | _ -> raise (Protocol_error "invalid OpenCode health response")
  in
  let version = required_string "version" fields in
  if
    field "pid" fields <> Some (`Int endpoint.pid)
    || (not (String.starts_with ~prefix:"2." version))
    ||
    match endpoint.version with
    | Some registered -> registered <> version
    | None -> false
  then
    failwith "OpenCode service registration does not match a healthy V2 service";
  endpoint

let with_opencode_service ~clock ?(read = read_opencode_registration) ~request f
    =
  let endpoint = ref None in
  with_http
    ~connect:(fun () ->
      endpoint := Some (discover_opencode ~clock ~read ~request ()))
    (fun req ->
      let endpoint =
        match !endpoint with
        | Some endpoint -> endpoint
        | None -> failwith "OpenCode operation has no connection"
      in
      request endpoint
        { req with headers = opencode_auth endpoint @ req.headers })
    f

let with_opencode_http ~net ~clock f =
  with_opencode_service ~clock ~request:(request_http ~net) f

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
          title =
            Option.value ~default:"Без названия"
              (optional_string "title" fields);
          directory =
            required_assoc "location" fields |> required_string "directory";
          workspace = None;
          agent = optional_string "agent" fields;
          model;
          status = Idle;
        },
        updated )
  | _ -> raise (Protocol_error "invalid OpenCode session")

let opencode_session_page body =
  match json body with
  | `Assoc fields -> required_list "data" fields |> List.map opencode_session
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
      required_assoc "data" fields
      |> List.map (fun (id, value) ->
          match value with
          | `Assoc status when field "type" status = Some (`String "running") ->
              (id, Busy)
          | _ -> raise (Protocol_error "invalid OpenCode active execution"))
  | _ -> raise (Protocol_error "invalid OpenCode status list")

let opencode_pending body =
  match json body with
  | `Assoc fields ->
      let requests = required_list "data" fields in
      List.map
        (function
          | `Assoc fields -> required_string "sessionID" fields
          | _ -> raise (Protocol_error "invalid OpenCode pending input"))
        requests
  | _ -> raise (Protocol_error "invalid OpenCode pending input list")

let opencode_message_page body =
  match json body with
  | `Assoc fields ->
      ( required_list "data" fields,
        required_assoc "cursor" fields |> optional_string "next" )
  | _ -> raise (Protocol_error "invalid OpenCode message list")

let opencode_text messages =
  List.concat_map
    (function
      | `Assoc fields -> (
          match required_string "type" fields with
          | "user" -> [ { role = User; text = required_string "text" fields } ]
          | "assistant" ->
              required_list "content" fields
              |> List.filter_map (function
                | `Assoc part when field "type" part = Some (`String "text") ->
                    Some
                      { role = Assistant; text = required_string "text" part }
                | _ -> None)
          | _ -> [])
      | _ -> raise (Protocol_error "invalid OpenCode message"))
    messages

let opencode_messages body = opencode_message_page body |> fst |> opencode_text

let opencode_retry messages =
  List.fold_left
    (fun latest -> function
      | `Assoc fields when field "type" fields = Some (`String "assistant") -> (
          match field "retry" fields with
          | None | Some `Null -> None
          | Some (`Assoc retry) ->
              Some (required_assoc "error" retry |> required_string "message")
          | _ -> raise (Protocol_error "invalid OpenCode retry"))
      | _ -> latest)
    None messages

let status_with_retry status messages =
  match (status, opencode_retry messages) with
  | Busy, Some message -> Retry message
  | _ -> status

let opencode_prompt_body (_session : opencode_session) prompt =
  `Assoc [ ("text", `String prompt) ] |> Yojson.Basic.to_string

let opencode_command_body (_session : opencode_session) command arguments =
  `Assoc [ ("name", `String command); ("text", `String arguments) ]
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

let perform_http meth target body =
  let headers =
    if meth = `POST && body <> "" then [ ("content-type", "application/json") ]
    else []
  in
  Effect.perform (Http_request { meth; target; headers; body })

let expect_status expected { status; body } =
  if status = expected then body
  else
    let tag =
      if status = 401 then None
      else
        try
          match json body with
          | `Assoc fields -> optional_string "_tag" fields
          | _ -> None
        with Protocol_error _ -> None
    in
    if status = 404 && tag = Some "SessionNotFoundError" then
      raise OpenCode_not_found;
    let detail =
      match tag with
      | Some
          (( "CommandNotFoundError" | "LocationNotFoundError"
           | "CommandExecutionError" | "ConflictError" | "InvalidRequestError"
             ) as tag) ->
          " (" ^ tag ^ ")"
      | _ -> ""
    in
    failwith (Printf.sprintf "OpenCode server returned HTTP %d%s" status detail)

let get target = perform_http `GET target "" |> expect_status 200

let post ?(body = "") expected target =
  perform_http `POST target body |> expect_status expected

let session_status statuses id =
  Option.value ~default:Idle (List.assoc_opt id statuses)

let load_opencode_session_list ?directory () =
  Effect.perform OpenCode_connect;
  let target =
    "/api/session?limit=20&order=desc"
    ^
    match directory with
    | Some directory -> "&directory=" ^ uri_component directory
    | None -> ""
  in
  let sessions = get target |> opencode_sessions in
  let statuses =
    if sessions = [] then [] else get "/api/session/active" |> opencode_statuses
  in
  List.map
    (fun (session : opencode_session) ->
      let status = session_status statuses session.id in
      let status =
        if status = Busy then
          get
            ("/api/session/" ^ uri_component session.id
           ^ "/message?type=assistant&order=desc&limit=1")
          |> opencode_message_page |> fst |> status_with_retry status
        else status
      in
      { session with status })
    sessions

let load_opencode_sessions () = load_opencode_session_list ()

let load_opencode_folder_sessions directory =
  load_opencode_session_list ~directory ()

let create_opencode_session directory =
  Effect.perform OpenCode_connect;
  let body =
    `Assoc [ ("location", `Assoc [ ("directory", `String directory) ]) ]
    |> Yojson.Basic.to_string
  in
  match post ~body 200 "/api/session" |> json with
  | `Assoc fields ->
      required_assoc "data" fields |> fun data ->
      fst (opencode_session (`Assoc data))
  | _ -> raise (Protocol_error "invalid OpenCode create response")

let load_opencode_detail (session : opencode_session) =
  Effect.perform OpenCode_connect;
  let id = uri_component session.id in
  let target = "/api/session/" ^ id in
  let session =
    match get target |> json with
    | `Assoc fields ->
        required_assoc "data" fields |> fun fields ->
        fst (opencode_session (`Assoc fields))
    | _ -> raise (Protocol_error "invalid OpenCode session response")
  in
  let rec load_messages query acc =
    let messages, next =
      get (target ^ "/message?" ^ query) |> opencode_message_page
    in
    let acc = List.rev_append messages acc in
    match (messages, next) with
    | [], _ | _, None -> List.rev acc
    | _, Some cursor -> load_messages ("cursor=" ^ uri_component cursor) acc
  in
  let messages = load_messages "order=asc" [] in
  let statuses = get "/api/session/active" |> opencode_statuses in
  let permissions = get (target ^ "/permission") |> opencode_pending in
  let questions = get (target ^ "/form") |> opencode_pending in
  {
    session =
      {
        session with
        status = status_with_retry (session_status statuses session.id) messages;
      };
    messages = opencode_text messages;
    needs_input =
      List.mem session.id permissions || List.mem session.id questions;
  }

let submit_opencode_prompt session prompt =
  Effect.perform OpenCode_connect;
  match
    post
      ~body:(opencode_prompt_body session prompt)
      200
      ("/api/session/" ^ uri_component session.id ^ "/prompt")
    |> json
  with
  | `Assoc fields ->
      let data = required_assoc "data" fields in
      let id = required_string "id" data in
      if
        (not (String.starts_with ~prefix:"msg_" id))
        || required_string "sessionID" data <> session.id
        || required_string "type" data <> "user"
        || not (List.mem (required_string "delivery" data) [ "steer"; "queue" ])
      then raise (Protocol_error "invalid OpenCode prompt admission");
      ignore (required_assoc "time" data |> required_timestamp "created");
      ignore (required_assoc "payload" data |> required_string "text")
  | _ -> raise (Protocol_error "invalid OpenCode prompt admission")

let submit_opencode_command session command arguments =
  Effect.perform OpenCode_connect;
  ignore
    (post
       ~body:(opencode_command_body session command arguments)
       204
       ("/api/session/" ^ uri_component session.id ^ "/command"))

let abort_opencode session =
  Effect.perform OpenCode_connect;
  match
    post 200 ("/api/session/" ^ uri_component session.id ^ "/interrupt") |> json
  with
  | `Assoc fields
    when match field "interrupted" fields with
         | Some (`Bool _) -> true
         | _ -> false ->
      ()
  | _ -> raise (Protocol_error "invalid OpenCode abort response")

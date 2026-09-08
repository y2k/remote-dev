module J = Yojson.Safe
open Home_components

type request = { event : J.t; value : string option }

let field name fields = List.assoc_opt name fields

let decode_request body =
  try
    match J.from_string body with
    | `Assoc fields -> (
        match (field "event" fields, field "value" fields) with
        | Some event, Some ((`Null | `String _) as value) ->
            Ok
              {
                event;
                value =
                  (match value with
                  | `String value -> Some value
                  | `Null -> None);
              }
        | _ -> Error "Invalid event request")
    | _ -> Error "Invalid event request"
  with Yojson.Json_error _ -> Error "Invalid event request"

let rec replace_value value = function
  | `String "__VALUE__" -> `String value
  | `Assoc fields ->
      `Assoc
        (List.map (fun (key, json) -> (key, replace_value value json)) fields)
  | `List values -> `List (List.map (replace_value value) values)
  | json -> json

let decode body =
  match decode_request body with
  | Error _ as error -> error
  | Ok { event; value } -> (
      match
        Home.msg_of_yojson
          (replace_value (Option.value ~default:"" value) event)
      with
      | Ok (Home.Worktree_msg (Worktree.Session_started _)) ->
          Error "Invalid event request"
      | Ok (Home.Sessions_msg (Sessions.Loaded _))
      | Ok (Home.Session_msg (Session.Loaded _))
      | Ok (Home.Session_msg Session.Missing)
      | Ok (Home.Session_msg (Session.Submitted _))
      | Ok (Home.Session_msg (Session.Command_finished _)) ->
          Error "Invalid event request"
      | result -> result)

let to_json environment model =
  Components.to_json Home.msg_to_yojson (Home.view environment model)

let document environment model = J.pretty_to_string (to_json environment model)
let stream_document environment model = J.to_string (to_json environment model)

let state =
  Atomic.make
    {
      Home.screen =
        Worktrees { Home_components.Worktrees.worktrees = []; error = None };
      emulator =
        { Emulator.emulators = []; selected_emulator = None; error = None };
    }

let stream_start environment = stream_document environment (Atomic.get state)
let reset environment = Atomic.set state (Home.init environment |> fst)

let step environment message =
  let next, cmd = Home.update environment (Atomic.get state) message in
  Atomic.set state next;
  (next, cmd)

let rec dispatch environment message =
  let next, cmd = step environment message in
  match Components.Cmd.run cmd with
  | None -> next
  | Some message -> dispatch environment message

type prompt_stream = {
  cwd : string;
  prompt : string;
  session_id : string option;
}

let start_prompt_stream environment body =
  match (environment, decode body) with
  | ( Runtime.Claude _,
      Ok (Home.Worktree_msg (Worktree.Run_prompt prompt) as message) ) -> (
      let next, _ = step environment message in
      match next.screen with
      | Home.Worktree { path; session_id; _ } ->
          Some { cwd = path; prompt; session_id }
      | Home.Worktrees _ | Home.New_worktree _ | Home.Sessions _
      | Home.Session _ ->
          None)
  | (Runtime.Claude _ | Runtime.OpenCode), (Ok _ | Error _) -> None

type opencode_command = {
  session : Runtime.opencode_session;
  command : string;
  arguments : string;
}

let start_opencode_command environment body =
  match (environment, decode body) with
  | ( Runtime.OpenCode,
      Ok (Home.Session_msg (Session.Run_prompt prompt) as message) ) -> (
      match Runtime.opencode_input prompt with
      | `Prompt _ -> None
      | `Command (command, arguments) -> (
          let next, _ = step environment message in
          match next.screen with
          | Home.Session (_, { session; _ }) ->
              Some { session; command; arguments }
          | Home.Worktrees _ | Home.New_worktree _ | Home.Worktree _
          | Home.Sessions _ ->
              None))
  | (Runtime.Claude _ | Runtime.OpenCode), (Ok _ | Error _) -> None

let complete_opencode_command environment { session; command; arguments } =
  let result =
    try
      Runtime.submit_opencode_command session command arguments;
      Ok ()
    with exn -> Error (Printexc.to_string exn)
  in
  ignore
    (dispatch environment
       (Home.Session_msg (Session.Command_finished (session.id, result))))

let start_opencode_prompt environment body =
  match (environment, decode body) with
  | ( Runtime.OpenCode,
      Ok (Home.Session_msg (Session.Run_prompt prompt) as message) ) -> (
      match Runtime.opencode_input prompt with
      | `Prompt _ -> Some (step environment message)
      | `Command _ -> None)
  | (Runtime.Claude _ | Runtime.OpenCode), (Ok _ | Error _) -> None

let stream_event environment = function
  | Runtime.Session session_id ->
      ignore
        (dispatch environment
           (Home.Worktree_msg (Worktree.Session_started session_id)));
      None
  | Runtime.Text output ->
      Some
        (J.to_string
           (to_json environment
              (dispatch environment (Home.Worktree_msg (Worktree.Output output)))))

let stream_error environment error =
  J.to_string
    (to_json environment
       (dispatch environment
          (Home.Worktree_msg (Worktree.Finished (Error error)))))

let protect_prompt f =
  try
    f ();
    `Done
  with
  | Runtime.Protocol_error _ as exn -> raise exn
  | exn -> `Error (Printexc.to_string exn)

let produce_prompt run add = add (protect_prompt run)

let screenshot_serial target =
  let prefix = "/emulators/" and suffix = "/screenshot.png" in
  let length = String.length target in
  if
    String.starts_with ~prefix target
    && String.ends_with ~suffix target
    && length > String.length prefix + String.length suffix
  then
    let serial =
      String.sub target (String.length prefix)
        (length - String.length prefix - String.length suffix)
    in
    if String.contains serial '/' then None else Some serial
  else None

let screenshot_response serial =
  if
    Runtime.load_emulators ()
    |> List.exists (fun (emulator : Runtime.emulator) ->
        emulator.serial = serial)
  then (`OK, Runtime.capture_emulator_screenshot serial, "image/png")
  else (`Not_found, "Emulator Not Found", "text/plain")

let stream_body environment state cmd =
  let documents = ref [ stream_document environment state ] in
  let rec run cmd =
    match Components.Cmd.run cmd with
    | None -> ()
    | Some message ->
        let state, next = step environment message in
        documents := stream_document environment state :: !documents;
        run next
  in
  run cmd;
  String.concat "\n" (List.rev !documents) ^ "\n"

let initialize environment =
  let model, cmd = Home.init environment in
  Atomic.set state model;
  match Components.Cmd.run cmd with
  | None -> ()
  | Some message -> ignore (dispatch environment message)

let response environment ?(body = "") meth target =
  match (meth, target) with
  | `GET, "/" ->
      (`OK, document environment (Atomic.get state), "application/json")
  | `GET, target -> (
      match screenshot_serial target with
      | Some serial -> screenshot_response serial
      | None -> (`Not_found, "Not Found", "text/plain"))
  | `POST, "/" -> (
      match start_opencode_prompt environment body with
      | Some (state, cmd) ->
          let state =
            match Components.Cmd.run cmd with
            | None -> state
            | Some message -> dispatch environment message
          in
          (`OK, document environment state, "application/json")
      | None -> (
          match decode body with
          | Error message -> (`Bad_request, message, "text/plain")
          | Ok message -> (
              let state, cmd = step environment message in
              match cmd with
              | Components.Cmd.Empty ->
                  (`OK, document environment state, "application/json")
              | Components.Cmd.Run _ ->
                  ( `OK,
                    stream_body environment state cmd,
                    "application/x-ndjson" ))))
  | _ -> (`Not_found, "Not Found", "text/plain")

let stream_headers =
  Httpun.Headers.of_list
    [
      ("content-type", "application/x-ndjson"); ("transfer-encoding", "chunked");
    ]

let screenshot_headers body =
  Httpun.Headers.of_list
    [
      ("content-length", string_of_int (String.length body));
      ("content-type", "image/png");
      ("cache-control", "no-store");
    ]

let respond environment ~net ~sw ~domain_mgr { Gluten.reqd; _ } =
  let request = Httpun.Reqd.request reqd in
  let reply ?headers (status, body, content_type) =
    let headers =
      Option.value
        ~default:
          (Httpun.Headers.of_list
             [
               ("content-length", string_of_int (String.length body));
               ("content-type", content_type);
             ])
        headers
    in
    Httpun.Reqd.respond_with_string reqd
      (Httpun.Response.create ~headers status)
      body
  in
  let stream { cwd; prompt; session_id } =
    let writer =
      Httpun.Reqd.respond_with_streaming ~flush_headers_immediately:true reqd
        (Httpun.Response.create ~headers:stream_headers `OK)
    in
    let updates = Eio.Stream.create 1 in
    let write document =
      Httpun.Body.Writer.write_string writer (document ^ "\n");
      let flushed, resolve = Eio.Promise.create () in
      Httpun.Body.Writer.flush writer (fun _ -> Eio.Promise.resolve resolve ());
      Eio.Promise.await flushed
    in
    write (stream_start environment);
    let producer () =
      produce_prompt
        (fun () ->
          Eio.Domain_manager.run domain_mgr (fun () ->
              Runtime.with_unix_process (fun () ->
                  Runtime.stream_claude ~cwd ~prompt ~session_id (fun event ->
                      Eio.Stream.add updates (`Event event)))))
        (Eio.Stream.add updates)
    in
    let rec consumer () =
      match Eio.Stream.take updates with
      | `Event event ->
          Option.iter write (stream_event environment event);
          consumer ()
      | `Done -> ()
      | `Error error -> write (stream_error environment error)
    in
    Eio.Fiber.both producer consumer;
    Httpun.Body.Writer.close writer
  in
  let stream_ui state cmd =
    let writer =
      Httpun.Reqd.respond_with_streaming ~flush_headers_immediately:true reqd
        (Httpun.Response.create ~headers:stream_headers `OK)
    in
    let write state =
      Httpun.Body.Writer.write_string writer
        (stream_document environment state ^ "\n");
      let flushed, resolve = Eio.Promise.create () in
      Httpun.Body.Writer.flush writer (fun _ -> Eio.Promise.resolve resolve ());
      Eio.Promise.await flushed
    in
    write state;
    let rec run cmd =
      match Components.Cmd.run cmd with
      | None -> ()
      | Some message ->
          let state, next = step environment message in
          write state;
          run next
    in
    run cmd;
    Httpun.Body.Writer.close writer
  in
  (* ponytail: trusted local demo; bound bodies if the server becomes public. *)
  let body = Buffer.create 128 in
  let rec read () =
    Httpun.Body.Reader.schedule_read
      (Httpun.Reqd.request_body reqd)
      ~on_eof:(fun () ->
        Runtime.with_opencode_http ~net @@ fun () ->
        let body = Buffer.contents body in
        let event_request = request.meth = `POST && request.target = "/" in
        match
          if event_request then start_prompt_stream environment body else None
        with
        | Some request -> stream request
        | None -> (
            match
              if event_request then start_opencode_command environment body
              else None
            with
            | Some { session; command; arguments } ->
                Eio.Fiber.fork ~sw (fun () ->
                    Runtime.with_opencode_http ~net (fun () ->
                        complete_opencode_command environment
                          { session; command; arguments }));
                reply
                  ( `OK,
                    document environment (Atomic.get state),
                    "application/json" )
            | None -> (
                match
                  if event_request then start_opencode_prompt environment body
                  else None
                with
                | Some (state, cmd) ->
                    let state =
                      match Components.Cmd.run cmd with
                      | None -> state
                      | Some message -> dispatch environment message
                    in
                    reply (`OK, document environment state, "application/json")
                | None -> (
                    match (request.meth, request.target) with
                    | `GET, "/" ->
                        reply
                          ( `OK,
                            document environment (Atomic.get state),
                            "application/json" )
                    | `GET, target -> (
                        match screenshot_serial target with
                        | Some serial -> (
                            let response =
                              Eio.Domain_manager.run domain_mgr (fun () ->
                                  Runtime.with_unix_process (fun () ->
                                      screenshot_response serial))
                            in
                            match response with
                            | `OK, body, _ ->
                                reply ~headers:(screenshot_headers body)
                                  response
                            | _ -> reply response)
                        | None -> reply (`Not_found, "Not Found", "text/plain"))
                    | `POST, "/" -> (
                        match decode body with
                        | Error message ->
                            reply (`Bad_request, message, "text/plain")
                        | Ok message -> (
                            let state, cmd = step environment message in
                            match cmd with
                            | Components.Cmd.Empty ->
                                reply
                                  ( `OK,
                                    document environment state,
                                    "application/json" )
                            | Components.Cmd.Run _ -> stream_ui state cmd))
                    | _ -> reply (`Not_found, "Not Found", "text/plain")))))
      ~on_read:(fun chunk ~off ~len ->
        Buffer.add_string body (Bigstringaf.substring chunk ~off ~len);
        read ())
  in
  read ()

let run environment ~net ~domain_mgr =
  Runtime.with_opencode_http ~net (fun () -> initialize environment);
  Eio.Switch.run @@ fun sw ->
  let socket =
    Eio.Net.listen ~sw ~reuse_addr:true ~backlog:128 net
      (`Tcp (Eio.Net.Ipaddr.V4.any, 8080))
  in
  let handler =
    Httpun_eio.Server.create_connection_handler ~sw
      ~request_handler:(fun _ reqd ->
        respond environment ~net ~sw ~domain_mgr reqd)
      ~error_handler:(fun _ ?request:_ _ start_response ->
        Httpun.Body.Writer.close (start_response Httpun.Headers.empty))
  in
  Eio.Net.run_server socket ~on_error:raise (fun client client_addr ->
      handler client_addr client)

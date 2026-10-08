module R = Remote_dev.Runtime
module H = Remote_dev.Home
module S = Remote_dev.Server
module J = Yojson.Safe

let rec find key value = function
  | `Assoc fields as node ->
      if List.assoc_opt key fields = Some (`String value) then Some node
      else List.find_map (fun (_, child) -> find key value child) fields
  | `List children -> List.find_map (find key value) children
  | _ -> None

let has_text value document = Option.is_some (find "text" value document)

let event label document =
  match find "label" label document with
  | Some node -> J.Util.member "event" node
  | None -> failwith ("Missing control: " ^ label)

let request ?(value = `Null) event =
  J.to_string (`Assoc [ ("event", event); ("value", value) ])

let document environment = S.to_json environment (Atomic.get S.state)

let post environment ?value event =
  let status, _, _ =
    S.response environment ~body:(request ?value event) `POST "/"
  in
  assert (status = `OK);
  document environment

let click environment label =
  post environment (event label (document environment))

let back environment = post environment (H.msg_to_yojson H.Back)
let refresh environment = post environment (H.msg_to_yojson H.Refresh)

let session_json directory id =
  Printf.sprintf
    {|{"id":%S,"title":%S,"location":{"directory":%S},"time":{"created":1,"updated":2}}|}
    id id directory

let response body = { R.status = 200; body }
let page rows = "{\"data\":[" ^ String.concat "," rows ^ "],\"cursor\":{}}"

let reject environment message =
  let before = Atomic.get S.state in
  let status, _, _ =
    S.response environment ~body:(request (H.msg_to_yojson message)) `POST "/"
  in
  assert (status = `Bad_request);
  assert (Atomic.get S.state = before)

let () =
  let root = Filename.temp_dir "remote-dev-folder-tabs-" "" in
  let folder = Filename.concat root "project" in
  Unix.mkdir folder 0o700;
  Fun.protect
    ~finally:(fun () ->
      Unix.rmdir folder;
      Unix.rmdir root)
    (fun () ->
      let environment = R.OpenCode { root } in
      let calls = ref [] in
      let offline = ref false in
      let fail_create = ref false in
      let fail_detail = ref false in
      let creations = ref 0 in
      let handle (req : R.http_request) =
        calls := req.target :: !calls;
        if !offline then failwith "offline";
        match req.target with
        | "/api/session" ->
            assert (req.meth = `POST);
            assert (
              Yojson.Basic.from_string req.body
              = `Assoc
                  [ ("location", `Assoc [ ("directory", `String folder) ]) ]);
            incr creations;
            if !fail_create then failwith "creation unavailable";
            response ("{\"data\":" ^ session_json folder "ses_new" ^ "}")
        | target
          when target
               = "/api/session?limit=20&order=desc&directory="
                 ^ R.uri_component folder ->
            response (page [ session_json folder "ses_existing" ])
        | "/api/session/active" -> response {|{"data":{}}|}
        | "/api/session/ses_existing" ->
            response ("{\"data\":" ^ session_json folder "ses_existing" ^ "}")
        | "/api/session/ses_existing/message?order=asc" ->
            response
              (page [ {|{"type":"user","text":"previous conversation"}|} ])
        | "/api/session/ses_existing/permission"
        | "/api/session/ses_existing/form" ->
            response (page [])
        | "/api/session/ses_new" ->
            if !fail_detail then failwith "detail unavailable";
            response ("{\"data\":" ^ session_json folder "ses_new" ^ "}")
        | "/api/session/ses_new/message?order=asc"
        | "/api/session/ses_new/permission" | "/api/session/ses_new/form" ->
            response (page [])
        | target -> failwith ("Unexpected request " ^ target)
      in
      R.with_http handle (fun () ->
          S.reset environment;
          assert (not (has_text "Directories" (document environment)));
          ignore (click environment "+");
          assert (!calls = []);
          let listed = click environment "project" in
          assert (has_text "OpenCode sessions:" listed);
          assert (has_text folder listed);
          let module T = Remote_dev.Home_components.Project_tabs in
          let module L = Remote_dev.Home_components.Sessions in
          reject environment
            (H.Project_tabs_msg
               (T.Content (1, 1, T.Sessions_event (L.Loaded (Ok [])))));
          reject environment
            (H.Project_tabs_msg
               (T.Content (1, 1, T.Sessions_event (L.Created (Error "forged")))));
          ignore (event "Создать новую сессию" listed);
          ignore (click environment "ses_existing");
          assert (has_text "User: previous conversation" (document environment));
          let loaded_calls = !calls in
          ignore (click environment "+");
          assert (has_text "Directories" (document environment));
          ignore (click environment "Tab 1");
          assert (has_text "User: previous conversation" (document environment));
          assert (!calls = loaded_calls);
          assert (has_text "OpenCode sessions:" (back environment));
          assert (has_text "Directories" (back environment));
          assert (!calls = loaded_calls);
          ignore (refresh environment);
          assert (!calls = loaded_calls);
          offline := true;
          let failed = click environment "project" in
          assert (has_text "OpenCode sessions:" failed);
          assert (not (has_text "No OpenCode sessions" failed));
          offline := false;
          ignore (refresh environment);
          ignore (event "ses_existing" (document environment));
          offline := true;
          ignore (refresh environment);
          ignore (event "ses_existing" (document environment));
          offline := false;
          fail_create := true;
          let failed = click environment "Создать новую сессию" in
          assert (!creations = 1);
          assert (has_text "OpenCode sessions:" failed);
          ignore (event "ses_existing" failed);
          fail_create := false;
          fail_detail := true;
          let created = click environment "Создать новую сессию" in
          assert (!creations = 2);
          assert (has_text "OpenCode session" created);
          assert (has_text "ses_new" created);
          ignore (event "Prompt" created);
          assert (
            not
              (List.exists
                 (fun path -> String.ends_with ~suffix:"/prompt" path)
                 !calls));
          let returned = back environment in
          ignore (event "ses_new" returned);
          ignore (event "ses_existing" returned);
          assert (!creations = 2)))

(* A completion must retain its tab/screen address across switches and closure. *)
let () =
  let module C = Remote_dev.Home_components in
  let module T = C.Project_tabs in
  let initial, _ = T.init "/projects" in
  let one, _ = T.update initial T.Create in
  let one, _ =
    T.update one (T.Directories_msg (C.Directories.Loaded (Ok [ "a" ])))
  in
  let opened, load =
    T.update one
      (T.Content (1, 0, T.Directory_event (C.Directories.Click "/projects/a")))
  in
  let switched, _ = T.update opened T.Create in
  let result =
    R.with_http
      (fun _ -> response (page []))
      (fun () -> Remote_dev.Components.Cmd.run load |> Option.get)
  in
  let loaded, _ = T.update switched result in
  assert (loaded.active = Some 2);
  let selected, cmd = T.update loaded (T.Select 1) in
  assert (Remote_dev.Components.Cmd.run cmd = None);
  let view model =
    T.view model |> Remote_dev.Components.to_json T.msg_to_yojson
  in
  assert (has_text "No OpenCode sessions" (view selected));
  let creating, create =
    T.update selected (T.Content (1, 1, T.Sessions_event C.Sessions.Create))
  in
  let duplicate, cmd =
    T.update creating (T.Content (1, 1, T.Sessions_event C.Sessions.Create))
  in
  assert (duplicate = creating && Remote_dev.Components.Cmd.run cmd = None);
  let closed, _ = T.update creating (T.Close 1) in
  let created =
    R.with_http
      (fun req ->
        assert (req.R.target = "/api/session");
        response ("{\"data\":" ^ session_json "/projects/a" "ses_new" ^ "}"))
      (fun () -> Remote_dev.Components.Cmd.run create |> Option.get)
  in
  let after, cmd = T.update closed created in
  assert (after = closed && Remote_dev.Components.Cmd.run cmd = None);
  let back, _ = T.update selected T.Back in
  let reopened, _ =
    T.update back
      (T.Content (1, 2, T.Directory_event (C.Directories.Click "/projects/a")))
  in
  let after, cmd = T.update reopened result in
  assert (after = reopened && Remote_dev.Components.Cmd.run cmd = None)

(* Leaving a list invalidates its pending work, not the ability to create later. *)
let () =
  let module C = Remote_dev.Home_components in
  let module T = C.Project_tabs in
  let summary =
    fst
      (R.opencode_session
         (Yojson.Basic.from_string (session_json "/projects/a" "ses_existing")))
  in
  List.iter
    (fun outcome ->
      let model, _ = T.init "/projects" in
      let model, _ = T.update model T.Create in
      let model, _ =
        T.update model (T.Directories_msg (C.Directories.Loaded (Ok [ "a" ])))
      in
      let model, _ =
        T.update model
          (T.Content
             (1, 0, T.Directory_event (C.Directories.Click "/projects/a")))
      in
      let model, _ =
        T.update model
          (T.Content
             (1, 1, T.Sessions_event (C.Sessions.Loaded (Ok [ summary ]))))
      in
      let creating, _ =
        T.update model (T.Content (1, 1, T.Sessions_event C.Sessions.Create))
      in
      let chatting, _ =
        T.update creating
          (T.Content (1, 1, T.Sessions_event (C.Sessions.Select summary.id)))
      in
      let completed, _ =
        T.update chatting
          (T.Content (1, 1, T.Sessions_event (C.Sessions.Created outcome)))
      in
      assert (completed = chatting);
      let returned, _ = T.update completed T.Back in
      let view model =
        T.view model |> Remote_dev.Components.to_json T.msg_to_yojson
      in
      ignore (event "Создать новую сессию" (view returned));
      assert (not (has_text "Creating session..." (view returned)));
      let refreshing, cmd = T.update returned T.Refresh in
      let result =
        R.with_http
          (fun _ -> response (page []))
          (fun () -> Remote_dev.Components.Cmd.run cmd |> Option.get)
      in
      let refreshed, _ = T.update refreshing result in
      ignore (event "Создать новую сессию" (view refreshed)))
    [ Ok summary; Error "creation failed" ]

let () =
  let module C = Remote_dev.Home_components in
  let module T = C.Project_tabs in
  let environment = R.OpenCode { root = "/projects" } in
  let state, _ = H.init environment in
  let tabs, _ = T.init "/projects" in
  let tabs, _ = T.update tabs T.Create in
  let tabs, _ =
    T.update tabs (T.Directories_msg (C.Directories.Loaded (Ok [ "a" ])))
  in
  let tabs, _ =
    T.update tabs
      (T.Content (1, 0, T.Directory_event (C.Directories.Click "/projects/a")))
  in
  let summary =
    fst
      (R.opencode_session
         (Yojson.Basic.from_string (session_json "/projects/a" "ses_chat")))
  in
  let tabs, _ =
    T.update tabs
      (T.Content (1, 1, T.Sessions_event (C.Sessions.Created (Ok summary))))
  in
  Atomic.set S.state { state with screen = H.Project_tabs tabs };
  let voice =
    find "@type" "voice_input" (document environment)
    |> Option.get |> J.Util.member "event"
  in
  ignore (post environment ~value:(`String "voice draft") voice);
  ignore (click environment "+");
  ignore (click environment "Tab 1");
  let input = find "label" "Prompt" (document environment) |> Option.get in
  assert (J.Util.member "text" input = `String "voice draft");
  let prompt_event = event "Prompt" (document environment) in
  let calls = ref [] in
  let busy = ref true in
  let missing = ref false in
  let handle (req : R.http_request) =
    calls := req.target :: !calls;
    match req.target with
    | "/api/session/ses_chat/prompt" ->
        assert (
          Yojson.Basic.from_string req.body
          = `Assoc [ ("text", `String "literal $(input)") ]);
        response
          {|{"data":{"id":"msg_accepted","sessionID":"ses_chat","type":"user","delivery":"queue","time":{"created":1},"payload":{"text":"literal $(input)"}}}|}
    | "/api/session/ses_chat/command" -> failwith "command failed"
    | "/api/session/ses_chat" ->
        if !missing then
          { R.status = 404; body = {|{"_tag":"SessionNotFoundError"}|} }
        else
          response ("{\"data\":" ^ session_json "/projects/a" "ses_chat" ^ "}")
    | "/api/session/ses_chat/message?order=asc" ->
        response
          (page
             [
               {|{"type":"assistant","content":[{"type":"text","text":"updated answer"}]}|};
             ])
    | "/api/session/active" ->
        response
          (if !busy then {|{"data":{"ses_chat":{"type":"running"}}}|}
           else {|{"data":{}}|})
    | "/api/session/ses_chat/permission" ->
        response (page [ {|{"sessionID":"ses_chat"}|} ])
    | "/api/session/ses_chat/form" -> response (page [])
    | "/api/session/ses_chat/interrupt" ->
        busy := false;
        response {|{"interrupted":true}|}
    | target -> failwith ("Unexpected request " ^ target)
  in
  R.with_http handle (fun () ->
      let status, _, media =
        S.response environment
          ~body:(request ~value:(`String "literal $(input)") prompt_event)
          `POST "/"
      in
      assert (status = `OK && media = "application/json");
      assert (!calls = [ "/api/session/ses_chat/prompt" ]);
      let command =
        S.start_opencode_command environment
          (request ~value:(`String "/review main") prompt_event)
        |> Option.get
      in
      assert (!calls = [ "/api/session/ses_chat/prompt" ]);
      ignore (click environment "+");
      let inactive = document environment in
      S.complete_opencode_command environment command;
      assert (document environment = inactive);
      ignore (click environment "Tab 1");
      assert (
        has_text "Error: Failure(\"command failed\")" (document environment));
      let refreshed = refresh environment in
      assert (has_text "Assistant: updated answer" refreshed);
      assert (has_text "Needs input in OpenCode" refreshed);
      List.iter
        (fun message ->
          reject environment
            (H.Project_tabs_msg (T.Content (1, 2, T.Session_event message))))
        [
          C.Session.Submitted (Ok ());
          C.Session.Missing;
          C.Session.Command_finished ("ses_chat", Ok ());
          C.Session.Loaded
            (Ok { session = summary; messages = []; needs_input = false });
        ];
      ignore (click environment "Stop");
      assert (has_text "Status: idle" (document environment));
      assert (Option.is_none (find "label" "Stop" (document environment)));
      let pending =
        S.start_opencode_command environment
          (request ~value:(`String "/review") prompt_event)
        |> Option.get
      in
      missing := true;
      assert (has_text "OpenCode sessions:" (refresh environment));
      let before = Atomic.get S.state in
      S.complete_opencode_command environment pending;
      assert (Atomic.get S.state = before);
      missing := false;
      ignore (click environment "ses_chat");
      busy := true;
      ignore (refresh environment);
      let prompt = event "Prompt" (document environment) in
      let pending =
        S.start_opencode_command environment
          (request ~value:(`String "/review") prompt)
        |> Option.get
      in
      let calls_before = !calls in
      ignore
        (post environment (H.msg_to_yojson (H.Project_tabs_msg (T.Close 1))));
      assert (!calls = calls_before);
      let closed = Atomic.get S.state in
      S.complete_opencode_command environment pending;
      assert (Atomic.get S.state = closed);
      ignore (post environment ~value:(`String "stale prompt") prompt);
      assert (Atomic.get S.state = closed))

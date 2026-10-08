module R = Remote_dev.Runtime

let () =
  if Sys.getenv_opt "REMOTE_DEV_LIVE_READ_ONLY" = Some "1" then (
    Eio_main.run (fun env ->
        R.with_opencode_http ~net:(Eio.Stdenv.net env)
          ~clock:(Eio.Stdenv.clock env) (fun () ->
            let sessions = R.load_opencode_folder_sessions (Sys.getcwd ()) in
            assert (
              List.for_all
                (fun (s : R.opencode_session) -> s.directory = Sys.getcwd ())
                sessions);
            List.iter
              (fun session -> ignore (R.load_opencode_detail session))
              (List.take 1 sessions);
            ignore (R.load_opencode_sessions ());
            Printf.printf
              "Live runtime reads passed: %d exact-folder sessions\n"
              (List.length sessions)));
    exit 0)

let fails f =
  match f () with
  | _ -> false
  | exception (Failure _ | R.Protocol_error _) -> true

let registration ?(url = "http://127.0.0.1:49374") ?(password = Some "secret")
    () =
  Yojson.Basic.to_string
    (`Assoc
       ([
          ("url", `String url); ("pid", `Int 42); ("version", `String "2.0.24");
        ]
       @ Option.to_list (Option.map (fun p -> ("password", `String p)) password)
       ))

let health = { R.status = 200; body = {|{"pid":42,"version":"2.0.24"}|} }

let () =
  assert (
    R.opencode_registration_path
      ~getenv:(function "XDG_STATE_HOME" -> Some "/state" | _ -> None)
      ()
    = "/state/opencode/service.json");
  assert (
    R.opencode_registration_path
      ~getenv:(function "HOME" -> Some "/home/user" | _ -> None)
      ()
    = "/home/user/.local/state/opencode/service.json");
  Eio_main.run @@ fun env ->
  let clock = Eio.Stdenv.clock env in
  let discover ?(read = fun () -> registration ()) request =
    R.discover_opencode ~clock ~read ~request ()
  in
  let endpoint =
    discover (fun endpoint request ->
        assert (endpoint.R.host = "127.0.0.1:49374");
        assert (endpoint.port = 49374);
        assert (request.R.meth = `GET && request.target = "/api/info");
        assert (
          List.assoc_opt "authorization" request.headers
          = Some "Basic b3BlbmNvZGU6c2VjcmV0");
        health)
  in
  assert (endpoint.port = 49374);
  List.iter
    (fun body ->
      assert (
        fails (fun () ->
            discover ~read:(fun () -> body) (fun _ _ -> assert false))))
    [
      "not-json";
      "{}";
      registration ~url:"https://localhost:1234" ();
      registration ~url:"http://example.com:1234" ();
      registration ~url:"http://localhost:0" ();
      registration ~url:"http://localhost:1234@evil" ();
    ];
  assert (
    fails (fun () ->
        discover
          ~read:(fun () -> raise (Sys_error "missing"))
          (fun _ _ -> assert false)));
  List.iter
    (fun response -> assert (fails (fun () -> discover (fun _ _ -> response))))
    [
      { health with body = {|{"pid":43,"version":"2.0.24"}|} };
      { health with body = {|{"pid":42,"version":"2.1.0"}|} };
      { health with body = "{}" };
      { R.status = 401; body = "secret" };
    ];
  assert (fails (fun () -> discover (fun _ _ -> failwith "offline")));
  List.iter
    (fun (url, host) ->
      ignore
        (discover
           ~read:(fun () -> registration ~url ())
           (fun endpoint _ ->
             assert (endpoint.R.host = host);
             health)))
    [
      ("http://localhost:1234", "localhost:1234");
      ("http://[::1]:1234", "[::1]:1234");
    ];
  List.iter
    (fun (password, expected) ->
      ignore
        (discover
           ~read:(fun () -> registration ?password:(Some password) ())
           (fun _ request ->
             assert (List.assoc_opt "authorization" request.R.headers = expected);
             health)))
    [ (None, None); (Some "", Some "Basic b3BlbmNvZGU6") ];
  let started = Unix.gettimeofday () in
  assert (fails (fun () -> discover (fun _ _ -> Eio.Fiber.await_cancel ())));
  assert (Unix.gettimeofday () -. started < 7.)

let () =
  Eio_main.run @@ fun env ->
  let clock = Eio.Stdenv.clock env in
  let reads = ref 0 and requests = ref [] in
  let read () =
    incr reads;
    registration
      ~url:
        (if !reads = 1 then "http://localhost:1234" else "http://localhost:5678")
      ()
  in
  let request endpoint (req : R.http_request) =
    requests := (endpoint.R.port, req) :: !requests;
    assert (
      List.assoc_opt "authorization" req.headers
      = Some "Basic b3BlbmNvZGU6c2VjcmV0");
    if req.target = "/api/info" then health
    else { R.status = 200; body = {|{"data":[],"cursor":{}}|} }
  in
  Unix.putenv "OPENCODE_SERVER_PASSWORD" "wrong";
  R.with_opencode_service ~clock ~read ~request (fun () ->
      ignore (R.load_directories (Sys.getcwd ()));
      assert (!reads = 0);
      ignore (R.load_opencode_sessions ());
      assert (!reads = 1);
      ignore (R.load_opencode_sessions ());
      assert (!reads = 2));
  assert (List.exists (fun (port, _) -> port = 5678) !requests);
  let writes = ref 0 in
  let session : R.opencode_session =
    {
      id = "ses_test";
      title = "";
      directory = "/project";
      workspace = None;
      agent = None;
      model = None;
      status = Idle;
    }
  in
  assert (
    fails (fun () ->
        R.with_opencode_service ~clock ~read
          ~request:(fun _ req ->
            if req.R.target = "/api/info" then health
            else (
              incr writes;
              failwith "offline"))
          (fun () -> R.submit_opencode_prompt session "hello")));
  assert (!writes = 1)

let () =
  Eio_main.run @@ fun env ->
  let net = Eio.Stdenv.net env in
  List.iter
    (fun (hostname, address) ->
      Eio.Switch.run @@ fun sw ->
      let listener = Eio.Net.listen ~sw ~backlog:1 net (`Tcp (address, 0)) in
      let port =
        match Eio.Net.listening_addr listener with
        | `Tcp (_, port) -> port
        | _ -> assert false
      in
      let host = Printf.sprintf "%s:%d" hostname port in
      let endpoint =
        R.opencode_endpoint (registration ~url:("http://" ^ host) ())
      in
      Eio.Fiber.both
        (fun () ->
          let socket, _ = Eio.Net.accept ~sw listener in
          let reader = Eio.Buf_read.of_flow socket ~max_size:4096 in
          assert (Eio.Buf_read.line reader = "GET /api/info HTTP/1.1");
          let rec headers acc =
            match Eio.Buf_read.line reader with
            | "" -> acc
            | line -> headers (String.lowercase_ascii line :: acc)
          in
          assert (List.mem ("host: " ^ host) (headers []));
          Eio.Flow.copy_string
            "HTTP/1.1 200 OK\r\n\
             Content-Length: 2\r\n\
             Connection: close\r\n\
             \r\n\
             {}"
            socket;
          Eio.Flow.close socket)
        (fun () ->
          let response =
            R.request_http ~net endpoint
              { meth = `GET; target = "/api/info"; headers = []; body = "" }
          in
          assert (response.status = 200 && response.body = "{}")))
    [
      ("127.0.0.1", Eio.Net.Ipaddr.V4.loopback);
      ("localhost", Eio.Net.Ipaddr.V4.loopback);
      ("[::1]", Eio.Net.Ipaddr.V6.loopback);
    ]

let session_json =
  {|{"id":"ses_test","projectID":"p","location":{"directory":"/project a%"},"time":{"created":1,"updated":2},"cost":0,"tokens":{}}|}

let titled_json =
  {|{"id":"ses_titled","title":"Review","agent":"plan","model":{"providerID":"p","id":"m","variant":"high"},"location":{"directory":"/project"},"time":{"created":1,"updated":3},"projectID":"p","cost":0,"tokens":{}}|}

let page ?(cursor = "{}") rows =
  "{\"data\":[" ^ String.concat "," rows ^ "],\"cursor\":" ^ cursor ^ "}"

let () =
  let sessions = R.opencode_sessions (page [ session_json; titled_json ]) in
  let empty = List.hd sessions in
  assert (
    empty.id = "ses_test"
    && empty.directory = "/project a%"
    && empty.title = "Без названия");
  assert (empty.agent = None && empty.model = None && empty.workspace = None);
  let titled = List.nth sessions 1 in
  assert (
    titled.title = "Review" && titled.agent = Some "plan"
    && titled.model = Some ("p", "m", Some "high"));
  List.iter
    (fun body -> assert (fails (fun () -> R.opencode_sessions body)))
    [ "[]"; page [ "{}" ]; page [ {|{"id":"ses_bad","time":{"updated":1}}|} ] ]

let response body = { R.status = 200; body }

let () =
  let calls = ref [] in
  let other_rows =
    List.init 24 (fun i ->
        let directory =
          List.nth [ "/other"; "/project a%/child"; "/worktree" ] (i mod 3)
        in
        Printf.sprintf
          {|{"id":"ses_other%d","title":"Other","location":{"directory":%s},"time":{"updated":100}}|}
          i
          (Yojson.Basic.to_string (`String directory)))
  in
  let handle (request : R.http_request) =
    calls := request.target :: !calls;
    match request.target with
    | "/api/session?limit=20&order=desc&directory=%2Fproject%20a%25" ->
        response (page ~cursor:{|{"next":"unused"}|} [ session_json ])
    | "/api/session?limit=20&order=desc" ->
        response (page (List.take 20 other_rows))
    | "/api/session/active" ->
        response {|{"data":{"ses_unrelated":{"type":"running"}}}|}
    | target -> failwith ("unexpected request " ^ target)
  in
  R.with_http handle (fun () ->
      assert (List.length (R.load_opencode_sessions ()) = 20);
      let sessions = R.load_opencode_folder_sessions "/project a%" in
      assert (
        List.map (fun (s : R.opencode_session) -> s.id) sessions
        = [ "ses_test" ]));
  assert (List.length !calls = 4);
  assert (
    R.with_http
      (fun req ->
        assert (
          req.R.target = "/api/session?limit=20&order=desc&directory=%2Fempty");
        response (page []))
      (fun () -> R.load_opencode_folder_sessions "/empty")
    = [])

let () =
  let calls = ref 0 in
  let created =
    R.with_http
      (fun req ->
        incr calls;
        assert (req.R.meth = `POST && req.target = "/api/session");
        assert (
          Yojson.Basic.from_string req.body
          = `Assoc
              [ ("location", `Assoc [ ("directory", `String "/project a%") ]) ]);
        response ("{\"data\":" ^ session_json ^ "}"))
      (fun () -> R.create_opencode_session "/project a%")
  in
  assert (!calls = 1 && created.id = "ses_test" && created.agent = None);
  calls := 0;
  assert (
    fails (fun () ->
        R.with_http
          (fun _ ->
            incr calls;
            failwith "response lost")
          (fun () -> R.create_opencode_session "/project a%")));
  assert (!calls = 1)

let selected () = List.hd (R.opencode_sessions (page [ session_json ]))

let user_message i =
  Printf.sprintf
    {|{"id":"msg_%d","type":"user","text":"message %d","time":{"created":1}}|} i
    i

let assistant_message =
  {|{"id":"msg_assistant","type":"assistant","agent":"build","model":{"providerID":"p","id":"m"},"time":{"created":1},"content":[{"type":"text","text":"answer"},{"type":"reasoning","text":"private"},{"type":"tool","name":"ignored"}]}|}

let () =
  List.iter
    (fun last_cursor ->
      let calls = ref [] in
      let detail =
        R.with_http
          (fun req ->
            calls := req.R.target :: !calls;
            match req.target with
            | "/api/session/ses_test" ->
                response ("{\"data\":" ^ session_json ^ "}")
            | "/api/session/ses_test/message?order=asc" ->
                response
                  (page ~cursor:{|{"next":"page+2"}|}
                     (List.init 50 user_message))
            | "/api/session/ses_test/message?cursor=page%2B2" ->
                response
                  (page ~cursor:last_cursor
                     [
                       user_message 50;
                       assistant_message;
                       {|{"type":"idle","outcome":"succeeded"}|};
                     ])
            | "/api/session/ses_test/message?cursor=end" -> response (page [])
            | "/api/session/active" -> response {|{"data":{}}|}
            | "/api/session/ses_test/permission" | "/api/session/ses_test/form"
              ->
                response {|{"data":[]}|}
            | target -> failwith ("unexpected " ^ target))
          (fun () -> R.load_opencode_detail (selected ()))
      in
      assert (List.length detail.messages = 52);
      assert ((List.hd detail.messages).text = "message 0");
      assert ((List.nth detail.messages 50).text = "message 50");
      assert (
        List.nth detail.messages 51 = { R.role = Assistant; text = "answer" });
      assert (detail.session.status = R.Idle && not detail.needs_input);
      assert (List.length !calls = if last_cursor = "{}" then 6 else 7))
    [ "{}"; {|{"next":"end"}|} ];
  assert (
    fails (fun () ->
        R.with_http
          (fun req ->
            match req.R.target with
            | "/api/session/ses_test" ->
                response ("{\"data\":" ^ session_json ^ "}")
            | "/api/session/ses_test/message?order=asc" ->
                response (page ~cursor:{|{"next":"broken"}|} [ user_message 0 ])
            | _ -> response "not-json")
          (fun () -> R.load_opencode_detail (selected ()))))

let retry_message =
  {|{"id":"msg_retry","type":"assistant","agent":"build","model":{"providerID":"p","id":"m"},"time":{"created":1,"completed":2},"content":[],"retry":{"attempt":1,"at":1234,"error":{"message":"rate limited","name":"RateLimit"}}}|}

let () =
  List.iter
    (fun (active, messages, expected) ->
      List.iter
        (fun pending ->
          let reads = ref [] in
          let handle (req : R.http_request) =
            reads := req.target :: !reads;
            match req.target with
            | "/api/session?limit=20&order=desc" ->
                response (page [ session_json ])
            | "/api/session/ses_test" ->
                response ("{\"data\":" ^ session_json ^ "}")
            | "/api/session/active" ->
                response
                  (if active then
                     {|{"data":{"ses_test":{"type":"running"},"ses_other":{"type":"running"}}}|}
                   else {|{"data":{}}|})
            | "/api/session/ses_test/message?type=assistant&order=desc&limit=1"
              ->
                response (page (List.take 1 (List.rev messages)))
            | "/api/session/ses_test/message?order=asc" ->
                response (page messages)
            | "/api/session/ses_test/permission" ->
                response
                  (if pending = "permission" then
                     {|{"data":[{"sessionID":"ses_test"}]}|}
                   else {|{"data":[]}|})
            | "/api/session/ses_test/form" ->
                response
                  (if pending = "form" then
                     {|{"data":[{"sessionID":"ses_test"}]}|}
                   else {|{"data":[]}|})
            | target -> failwith ("unexpected " ^ target)
          in
          R.with_http handle (fun () ->
              let sessions = R.load_opencode_sessions () in
              assert ((List.hd sessions).status = expected);
              assert (List.length !reads = if active then 3 else 2);
              let detail = R.load_opencode_detail (selected ()) in
              assert (detail.session.status = expected);
              assert (detail.needs_input = (pending <> "none"))))
        [ "none"; "permission"; "form" ])
    [
      (true, [ retry_message ], R.Retry "rate limited");
      (true, [ retry_message; assistant_message ], R.Busy);
      (false, [ retry_message ], R.Idle);
      (true, [], R.Busy);
    ]

let admission =
  {|{"data":{"id":"msg_accepted","sessionID":"ses_test","type":"user","time":{"created":1},"payload":{"text":"hello"},"delivery":"steer"}}|}

let () =
  let session =
    {
      (selected ()) with
      agent = Some "old";
      model = Some ("old", "old", None);
      workspace = Some "old";
    }
  in
  let text = "  -prompt; $(literal) \"quoted\"  " in
  R.with_http
    (fun req ->
      assert (req.R.meth = `POST);
      assert (List.assoc_opt "x-opencode-directory" req.headers = None);
      match req.target with
      | "/api/session/ses_test/prompt" ->
          assert (
            Yojson.Basic.from_string req.body
            = `Assoc [ ("text", `String text) ]);
          response admission
      | "/api/session/ses_test/command" ->
          assert (
            Yojson.Basic.from_string req.body
            = `Assoc
                [
                  ("name", `String "review");
                  ("text", `String "main; $(literal)");
                ]);
          { R.status = 204; body = "" }
      | target -> failwith ("unexpected " ^ target))
    (fun () ->
      R.submit_opencode_prompt session text;
      R.submit_opencode_command session "review" "main; $(literal)");
  List.iter
    (fun body ->
      assert (
        fails (fun () ->
            R.with_http
              (fun _ -> response body)
              (fun () -> R.submit_opencode_prompt session text))))
    [ "{}"; {|{"data":{"id":"msg_only"}}|}; "not-json" ];
  assert (R.opencode_input "/" = `Prompt "/");
  assert (R.opencode_input " /review main " = `Command ("review", "main"));
  assert (R.opencode_input "/ review" = `Prompt "/ review")

let () =
  List.iter
    (fun interrupted ->
      R.with_http
        (fun req ->
          assert (
            req.R.target = "/api/session/ses_test/interrupt"
            && req.meth = `POST && req.body = "");
          response (Printf.sprintf {|{"interrupted":%b}|} interrupted))
        (fun () -> R.abort_opencode (selected ())))
    [ true; false ];
  assert (
    fails (fun () ->
        R.with_http
          (fun _ -> response "true")
          (fun () -> R.abort_opencode (selected ()))));
  List.iter
    (fun tag ->
      let calls = ref 0 in
      assert (
        fails (fun () ->
            R.with_http
              (fun req ->
                incr calls;
                assert (req.R.target = "/api/session/ses_test/command");
                {
                  R.status = 404;
                  body =
                    Printf.sprintf {|{"_tag":"%s","message":"missing"}|} tag;
                })
              (fun () -> R.submit_opencode_command (selected ()) "missing" "")));
      assert (!calls = 1))
    [ "CommandNotFoundError"; "LocationNotFoundError" ];
  assert (
    try
      R.with_http
        (fun _ ->
          { R.status = 404; body = {|{"_tag":"SessionNotFoundError"}|} })
        (fun () -> R.load_opencode_detail (selected ()))
      |> ignore;
      false
    with R.OpenCode_not_found -> true);
  assert (
    try
      R.with_http
        (fun _ ->
          { R.status = 401; body = "secret Authorization: Basic secret" })
        (fun () -> R.load_opencode_sessions ())
      |> ignore;
      false
    with Failure message -> message = "OpenCode server returned HTTP 401")

module J = Yojson.Safe
module Cmd = Remote_dev.Components.Cmd
module Home_components = Remote_dev.Home_components

let with_process f =
  try f ()
  with effect Remote_dev.Runtime.Process_lines (_, on_line), k ->
    List.iter on_line [ "worktree /tmp/remote-dev"; "branch refs/heads/main" ];
    Effect.Deep.continue k (Unix.WEXITED 0)

let with_created_worktree f =
  try f ()
  with effect Remote_dev.Runtime.Process_lines (process, on_line), k ->
    (match process with
    | Remote_dev.Runtime.Args _ -> ()
    | Remote_dev.Runtime.Shell _ ->
        List.iter on_line
          [
            "worktree /tmp/remote-dev";
            "branch refs/heads/main";
            "worktree /tmp/remote-dev-feature";
            "branch refs/heads/feature/new-worktree";
          ]);
    Effect.Deep.continue k (Unix.WEXITED 0)

let with_failed_worktree_creation f =
  try f ()
  with effect Remote_dev.Runtime.Process_lines (process, _), k ->
    (match process with
    | Remote_dev.Runtime.Args _ -> ()
    | Remote_dev.Runtime.Shell _ -> assert false);
    Effect.Deep.continue k (Unix.WEXITED 1)

module Todo = struct
  type event = Submit

  let encode = function Submit -> `Assoc [ ("type", `String "todo") ]
end

module App = struct
  type event = Todo of Todo.event

  let encode = function Todo event -> Todo.encode event
end

let () =
  let request_body message =
    J.to_string
      (`Assoc
         [
           ("event", Remote_dev.Home.Home.msg_to_yojson message);
           ("value", `Null);
         ])
  in
  let stream_documents body =
    body |> String.split_on_char '\n'
    |> List.filter (fun line -> line <> "")
    |> List.map J.from_string
  in
  let rec has_event event = function
    | `Assoc fields ->
        List.exists
          (fun (name, value) ->
            (name = "event" && value = event) || has_event event value)
          fields
    | `List values -> List.exists (has_event event) values
    | _ -> false
  in
  assert (
    Remote_dev.Components.to_json Todo.encode
      (Remote_dev.Components.edit ~event:Todo.Submit "Command")
    = `Assoc
        [
          ("@type", `String "input");
          ("label", `String "Command");
          ("event", `Assoc [ ("type", `String "todo") ]);
        ]);
  assert (
    Remote_dev.Components.to_json App.encode
      (Remote_dev.Components.map
         (fun event -> App.Todo event)
         (Remote_dev.Components.button ~event:Todo.Submit "Button"))
    = `Assoc
        [
          ("@type", `String "button");
          ("label", `String "Button");
          ("event", `Assoc [ ("type", `String "todo") ]);
        ]);
  assert (
    Remote_dev.Components.to_json Todo.encode
      (Remote_dev.Components.edit ~text:"draft" ~event:Todo.Submit "Command")
    = `Assoc
        [
          ("@type", `String "input");
          ("label", `String "Command");
          ("event", `Assoc [ ("type", `String "todo") ]);
          ("text", `String "draft");
        ]);
  assert (
    Remote_dev.Components.to_json Todo.encode
      (Remote_dev.Components.column
         [
           Remote_dev.Components.text "Text";
           Remote_dev.Components.row
             [ Remote_dev.Components.button ~event:Todo.Submit "Button" ];
         ])
    = `Assoc
        [
          ("@type", `String "column");
          ( "children",
            `List
              [
                `Assoc [ ("@type", `String "text"); ("text", `String "Text") ];
                `Assoc
                  [
                    ("@type", `String "row");
                    ( "children",
                      `List
                        [
                          `Assoc
                            [
                              ("@type", `String "button");
                              ("label", `String "Button");
                              ("event", `Assoc [ ("type", `String "todo") ]);
                            ];
                        ] );
                  ];
              ] );
        ]);
  let worktrees_document model =
    Remote_dev.Home.Home.to_json
      { screen = Remote_dev.Home.Home.Worktrees model }
  in
  let worktree_document model =
    Remote_dev.Home.Home.to_json
      { screen = Remote_dev.Home.Home.Worktree model }
  in
  let creation_document model =
    let creation = Home_components.New_worktree.initial in
    Remote_dev.Home.Home.to_json
      { screen = Remote_dev.Home.Home.New_worktree (model, creation) }
  in
  let creation_document_with model creation =
    Remote_dev.Home.Home.to_json
      { screen = Remote_dev.Home.Home.New_worktree (model, creation) }
  in
  let home_event = Remote_dev.Home.Home.msg_to_yojson in
  let round_trip message =
    assert (
      Remote_dev.Home.Home.msg_of_yojson
        (Remote_dev.Home.Home.msg_to_yojson message)
      = Ok message)
  in
  round_trip
    (Remote_dev.Home.Home.Worktrees_msg
       (Home_components.Worktrees.Loaded (Ok [])));
  round_trip
    (Remote_dev.Home.Home.Worktrees_msg
       (Home_components.Worktrees.Loaded (Error "failed")));
  round_trip
    (Remote_dev.Home.Home.Worktree_msg
       (Home_components.Worktree.Finished (Ok "answer")));
  round_trip
    (Remote_dev.Home.Home.Worktree_msg
       (Home_components.Worktree.Finished (Error "failed")));
  assert (
    Remote_dev.Home.decode (request_body Remote_dev.Home.Home.Back)
    = Ok Remote_dev.Home.Home.Back);
  assert (
    Remote_dev.Home.decode
      (J.to_string
         (`Assoc
            [
              ( "event",
                Remote_dev.Home.Home.msg_to_yojson
                  (Remote_dev.Home.Home.Worktree_msg
                     (Home_components.Worktree.Run_claude "__VALUE__")) );
              ("value", `String "prompt");
            ]))
    = Ok
        (Remote_dev.Home.Home.Worktree_msg
           (Home_components.Worktree.Run_claude "prompt")));
  assert (
    match
      Remote_dev.Home.decode
        (J.to_string
           (`Assoc
              [
                ( "event",
                  `List
                    [
                      `String "Worktrees_msg";
                      `List
                        [
                          `String "Loaded"; `List [ `String "Other"; `List [] ];
                        ];
                    ] );
                ("value", `Null);
              ]))
    with
    | Error _ -> true
    | Ok _ -> false);
  let initial, cmd = Remote_dev.Home.Home.init () in
  assert (
    match initial.screen with
    | Remote_dev.Home.Home.Worktrees { worktrees = []; error = None } -> true
    | Remote_dev.Home.Home.Worktrees _ | Remote_dev.Home.Home.New_worktree _
    | Remote_dev.Home.Home.Worktree _ ->
        false);
  assert (
    match with_process (fun () -> Cmd.run cmd) with
    | Some
        (Remote_dev.Home.Home.Worktrees_msg (Home_components.Worktrees.Loaded _))
      ->
        true
    | _ -> false);
  Remote_dev.Home.reset ();
  let initial = Atomic.get Remote_dev.Home.state in
  let documents =
    Remote_dev.Server.stream_body initial
      (Cmd.Run
         (fun () ->
           Some
             (Remote_dev.Home.Home.Worktrees_msg
                (Home_components.Worktrees.Loaded (Error "failed")))))
    |> stream_documents
  in
  assert (List.length documents = 2);
  assert (
    match (Atomic.get Remote_dev.Home.state).screen with
    | Remote_dev.Home.Home.Worktrees { error = Some "failed"; _ } -> true
    | Remote_dev.Home.Home.Worktrees _ | Remote_dev.Home.Home.New_worktree _
    | Remote_dev.Home.Home.Worktree _ ->
        false);
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Home.Worktrees_msg
            (Home_components.Worktrees.Select "/tmp/clicked")))
      (worktrees_document
         {
           worktrees = [ { path = "/tmp/clicked"; branch = "main" } ];
           error = None;
         }));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Home.Worktrees_msg
            Home_components.Worktrees.Open_creation))
      (worktrees_document
         {
           worktrees = [ { path = "/tmp/clicked"; branch = "main" } ];
           error = None;
         }));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Home.New_worktree_msg
            (Home_components.New_worktree.Create "__VALUE__")))
      (creation_document
         {
           worktrees = [ { path = "/tmp/clicked"; branch = "main" } ];
           error = None;
         }));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Home.Worktree_msg
            (Home_components.Worktree.Run_claude "__VALUE__")))
      (worktree_document
         { path = "/tmp/clicked"; prompt = ""; output = None; error = None }));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Home.Worktree_msg
            (Home_components.Worktree.Set_prompt "/igor-pending-reviews")))
      (worktree_document
         { path = "/tmp/clicked"; prompt = ""; output = None; error = None }));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Home.Worktree_msg
            (Home_components.Worktree.Set_prompt "/igor-restart-mr-tests")))
      (worktree_document
         { path = "/tmp/clicked"; prompt = ""; output = None; error = None }));
  assert (Cmd.run Cmd.none = None);
  assert (
    Cmd.run
      (Cmd.map
         (fun message -> "home:" ^ message)
         (Cmd.Run (fun () -> Some "child")))
    = Some "home:child");
  let next, cmd =
    Remote_dev.Home.Home.update
      {
        screen =
          Remote_dev.Home.Home.Worktrees Home_components.Worktrees.initial;
      }
      (Remote_dev.Home.Home.Worktrees_msg
         (Home_components.Worktrees.Loaded (Ok [])))
  in
  assert (Cmd.run cmd = None);
  assert (
    match next.screen with
    | Remote_dev.Home.Home.Worktrees { worktrees = []; error = None } -> true
    | Remote_dev.Home.Home.Worktrees _ | Remote_dev.Home.Home.New_worktree _
    | Remote_dev.Home.Home.Worktree _ ->
        false);
  let next, cmd =
    Remote_dev.Home.Home.update
      {
        screen =
          Remote_dev.Home.Home.Worktrees Home_components.Worktrees.initial;
      }
      Remote_dev.Home.Home.Back
  in
  assert (Cmd.run cmd = None);
  assert (
    match next.screen with
    | Remote_dev.Home.Home.Worktrees { worktrees = []; error = None } -> true
    | Remote_dev.Home.Home.Worktrees _ | Remote_dev.Home.Home.New_worktree _
    | Remote_dev.Home.Home.Worktree _ ->
        false);
  let listed_worktrees =
    {
      Home_components.Worktrees.worktrees =
        [ { path = "/tmp/clicked"; branch = "main" } ];
      error = None;
    }
  in
  let creation, cmd =
    Remote_dev.Home.Home.update
      { screen = Remote_dev.Home.Home.Worktrees listed_worktrees }
      (Remote_dev.Home.Home.Worktrees_msg
         Home_components.Worktrees.Open_creation)
  in
  assert (Cmd.run cmd = None);
  assert (
    Remote_dev.Home.Home.to_json creation = creation_document listed_worktrees);
  let creation, cmd =
    Remote_dev.Home.Home.update creation
      (Remote_dev.Home.Home.New_worktree_msg
         (Home_components.New_worktree.Create "feature/new-worktree"))
  in
  assert (match cmd with Cmd.Run _ -> true | Cmd.Empty -> false);
  assert (
    Remote_dev.Home.Home.to_json creation = creation_document listed_worktrees);
  let listed, cmd =
    Remote_dev.Home.Home.update creation Remote_dev.Home.Home.Back
  in
  assert (Cmd.run cmd = None);
  assert (
    Remote_dev.Home.Home.to_json listed = worktrees_document listed_worktrees);
  Remote_dev.Home.reset ();
  let status, body, _ =
    Remote_dev.Server.response
      ~body:
        (request_body
           (Remote_dev.Home.Home.Worktrees_msg
              Home_components.Worktrees.Open_creation))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body = creation_document Home_components.Worktrees.initial);
  let status, body, _ =
    with_created_worktree (fun () ->
        Remote_dev.Server.response
          ~body:
            (request_body
               (Remote_dev.Home.Home.New_worktree_msg
                  (Home_components.New_worktree.Create "feature/new-worktree")))
          `POST "/")
  in
  assert (status = `OK);
  let documents = stream_documents body in
  assert (
    List.hd documents = creation_document Home_components.Worktrees.initial);
  assert (
    List.hd (List.rev documents)
    = worktrees_document
        {
          worktrees =
            [
              { path = "/tmp/remote-dev"; branch = "main" };
              {
                path = "/tmp/remote-dev-feature";
                branch = "feature/new-worktree";
              };
            ];
          error = None;
        });
  Atomic.set Remote_dev.Home.state
    {
      Remote_dev.Home.Home.screen =
        Remote_dev.Home.Home.New_worktree
          (listed_worktrees, Home_components.New_worktree.initial);
    };
  let status, body, _ =
    with_failed_worktree_creation (fun () ->
        Remote_dev.Server.response
          ~body:
            (request_body
               (Remote_dev.Home.Home.New_worktree_msg
                  (Home_components.New_worktree.Create "broken")))
          `POST "/")
  in
  assert (status = `OK);
  assert (List.length (stream_documents body) = 2);
  assert (
    match (Atomic.get Remote_dev.Home.state).screen with
    | Remote_dev.Home.Home.New_worktree (_, { error = Some _ }) -> true
    | Remote_dev.Home.Home.Worktrees _ | Remote_dev.Home.Home.New_worktree _
    | Remote_dev.Home.Home.Worktree _ ->
        false);
  Atomic.set Remote_dev.Home.state
    {
      Remote_dev.Home.Home.screen =
        Remote_dev.Home.Home.New_worktree
          (listed_worktrees, Home_components.New_worktree.initial);
    };
  let status, body, _ =
    Remote_dev.Server.response
      ~body:
        (request_body
           (Remote_dev.Home.Home.New_worktree_msg
              (Home_components.New_worktree.Create "")))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body
    = creation_document_with listed_worktrees
        { error = Some "Branch is required" });
  let status, body, _ =
    Remote_dev.Server.response
      ~body:(request_body Remote_dev.Home.Home.Back)
      `POST "/"
  in
  assert (status = `OK);
  assert (J.from_string body = worktrees_document listed_worktrees);
  Remote_dev.Home.reset ();
  let status, body, content_type =
    Remote_dev.Server.response
      ~body:
        (request_body
           (Remote_dev.Home.Home.Worktrees_msg
              (Home_components.Worktrees.Select "/tmp/clicked")))
      `POST "/"
  in
  assert (status = `OK);
  assert (content_type = "application/json");
  let worktree = J.from_string body in
  assert (
    worktree
    = worktree_document
        { path = "/tmp/clicked"; prompt = ""; output = None; error = None });
  assert (not (has_event (`Assoc [ ("type", `String "back") ]) worktree));
  let status, body, _ =
    Remote_dev.Server.response
      ~body:
        (request_body
           (Remote_dev.Home.Home.Worktree_msg
              (Home_components.Worktree.Set_prompt "/igor-pending-reviews")))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body
    = worktree_document
        {
          path = "/tmp/clicked";
          prompt = "/igor-pending-reviews";
          output = None;
          error = None;
        });
  let status, body, _ =
    Remote_dev.Server.response
      ~body:
        (request_body
           (Remote_dev.Home.Home.Worktree_msg
              (Home_components.Worktree.Set_prompt "/igor-restart-mr-tests")))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body
    = worktree_document
        {
          path = "/tmp/clicked";
          prompt = "/igor-restart-mr-tests";
          output = None;
          error = None;
        });
  let document =
    Remote_dev.Home.dispatch
      (Remote_dev.Home.Home.Worktree_msg
         (Home_components.Worktree.Finished (Ok "answer")))
  in
  assert (
    Remote_dev.Home.Home.to_json document
    = worktree_document
        {
          path = "/tmp/clicked";
          prompt = "/igor-restart-mr-tests";
          output = Some "answer";
          error = None;
        });
  let status, body, _ =
    Remote_dev.Server.response
      ~body:
        (request_body
           (Remote_dev.Home.Home.Worktree_msg
              (Home_components.Worktree.Run_claude "new prompt")))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body
    = worktree_document
        {
          path = "/tmp/clicked";
          prompt = "new prompt";
          output = None;
          error = None;
        });
  let status, body, content_type =
    with_process (fun () ->
        Remote_dev.Server.response
          ~body:(request_body Remote_dev.Home.Home.Back)
          `POST "/")
  in
  assert (status = `OK);
  assert (content_type = "application/x-ndjson");
  assert (
    match (Atomic.get Remote_dev.Home.state).screen with
    | Remote_dev.Home.Home.Worktrees model ->
        List.hd (List.rev (stream_documents body)) = worktrees_document model
    | Remote_dev.Home.Home.New_worktree _ | Remote_dev.Home.Home.Worktree _ ->
        false);

  Remote_dev.Home.reset ();
  with_process Remote_dev.Server.initialize;
  let status, body, content_type = Remote_dev.Server.response `GET "/" in
  assert (status = `OK);
  assert (content_type = "application/json");
  assert (
    match (Atomic.get Remote_dev.Home.state).screen with
    | Remote_dev.Home.Home.Worktrees model ->
        J.from_string body = worktrees_document model
    | Remote_dev.Home.Home.New_worktree _ | Remote_dev.Home.Home.Worktree _ ->
        false);
  let status, body, content_type = Remote_dev.Server.response `GET "/" in
  assert (status = `OK);
  assert (content_type = "application/json");
  assert (
    match (Atomic.get Remote_dev.Home.state).screen with
    | Remote_dev.Home.Home.Worktrees model ->
        J.from_string body = worktrees_document model
    | Remote_dev.Home.Home.New_worktree _ | Remote_dev.Home.Home.Worktree _ ->
        false);
  let previous = J.from_string body in
  let status, body, content_type =
    with_process (fun () ->
        Remote_dev.Server.response
          ~body:
            (request_body
               (Remote_dev.Home.Home.Worktrees_msg
                  Home_components.Worktrees.Load))
          `POST "/")
  in
  assert (status = `OK);
  assert (content_type = "application/x-ndjson");
  let documents = stream_documents body in
  assert (List.length documents = 2);
  assert (List.hd documents = previous);
  assert (
    match (Atomic.get Remote_dev.Home.state).screen with
    | Remote_dev.Home.Home.Worktrees model ->
        List.hd (List.rev documents) = worktrees_document model
    | Remote_dev.Home.Home.New_worktree _ | Remote_dev.Home.Home.Worktree _ ->
        false);
  let status, _, _ = Remote_dev.Server.response `POST "/missing" in
  assert (status = `Not_found);
  let status, _, _ = Remote_dev.Server.response `GET "/missing" in
  assert (status = `Not_found);
  let status, _, _ = Remote_dev.Server.response ~body:"{}" `POST "/" in
  assert (status = `Bad_request);
  Remote_dev.Home.reset ();
  let status, body, _ =
    Remote_dev.Server.response
      ~body:(request_body Remote_dev.Home.Home.Back)
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body = worktrees_document { worktrees = []; error = None });
  let next, cmd =
    Remote_dev.Home.Home.update
      {
        screen =
          Remote_dev.Home.Home.Worktree
            (Home_components.Worktree.initial "/tmp/clicked");
      }
      Remote_dev.Home.Home.Back
  in
  assert (
    match with_process (fun () -> Cmd.run cmd) with
    | Some
        (Remote_dev.Home.Home.Worktrees_msg (Home_components.Worktrees.Loaded _))
      ->
        true
    | _ -> false);
  assert (
    match next.screen with
    | Remote_dev.Home.Home.Worktrees { error = None; _ } -> true
    | Remote_dev.Home.Home.Worktrees _ | Remote_dev.Home.Home.New_worktree _
    | Remote_dev.Home.Home.Worktree _ ->
        false);
  Remote_dev.Home.reset ();
  let status, body, _ =
    Remote_dev.Server.response
      ~body:
        (request_body
           (Remote_dev.Home.Home.Worktree_msg
              (Home_components.Worktree.Run_claude "prompt")))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body = worktrees_document { worktrees = []; error = None });
  Remote_dev.Home.reset ();
  assert (
    match (Atomic.get Remote_dev.Home.state).screen with
    | Remote_dev.Home.Home.Worktrees _ -> true
    | Remote_dev.Home.Home.New_worktree _ | Remote_dev.Home.Home.Worktree _ ->
        false);
  let model = Home_components.Worktree.initial "/tmp/clicked" in
  let model, _cmd =
    Home_components.Worktree.update model
      (Home_components.Worktree.Run_claude "prompt")
  in
  let model, _cmd =
    Home_components.Worktree.update model
      (Home_components.Worktree.Finished (Ok "answer"))
  in
  assert (model.output = Some "answer");
  let model, _ =
    Home_components.Worktree.update model
      (Home_components.Worktree.Finished (Error "failed"))
  in
  assert (model.error = Some "failed");
  assert (
    Httpun.Headers.get Remote_dev.Server.stream_headers "content-type"
    = Some "application/x-ndjson");
  assert (
    Httpun.Headers.get Remote_dev.Server.stream_headers "transfer-encoding"
    = Some "chunked");
  assert (
    not (Httpun.Headers.mem Remote_dev.Server.stream_headers "content-length"));
  Atomic.set Remote_dev.Home.state
    {
      Remote_dev.Home.Home.screen =
        Remote_dev.Home.Home.Worktree
          (Home_components.Worktree.initial "/tmp/clicked");
    };
  assert (
    match
      Remote_dev.Home.start_claude_stream
        (request_body
           (Remote_dev.Home.Home.Worktree_msg
              (Home_components.Worktree.Run_claude "prompt")))
    with
    | Some { cwd; prompt } -> cwd = "/tmp/clicked" && prompt = "prompt"
    | None -> false);
  let hel = Remote_dev.Home.stream_output "Hel" in
  assert (not (String.contains hel '\n'));
  assert (
    J.from_string hel
    = worktree_document
        {
          path = "/tmp/clicked";
          prompt = "prompt";
          output = Some "Hel";
          error = None;
        });
  let hello = Remote_dev.Home.stream_output "lo" in
  assert (
    J.from_string hello
    = worktree_document
        {
          path = "/tmp/clicked";
          prompt = "prompt";
          output = Some "Hello";
          error = None;
        });
  assert (
    J.from_string (Remote_dev.Home.stream_error "failed")
    = worktree_document
        {
          path = "/tmp/clicked";
          prompt = "prompt";
          output = Some "Hello";
          error = Some "failed";
        })

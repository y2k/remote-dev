module Todo = struct
  type event = Submit

  let encode = function Submit -> `Assoc [ ("type", `String "todo") ]
end

module App = struct
  type event = Todo of Todo.event

  let encode = function Todo event -> Todo.encode event
end

let () =
  let event fields value =
    Yojson.Basic.to_string
      (`Assoc [ ("event", `Assoc fields); ("value", value) ])
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
  assert (
    has_event
      (`Assoc
         [
           ("type", `String "select_worktree"); ("path", `String "/tmp/clicked");
         ])
      (worktrees_document
         {
           worktrees = [ { path = "/tmp/clicked"; branch = "main" } ];
           error = None;
         }));
  assert (
    has_event
      (`Assoc [ ("type", `String "run_claude") ])
      (worktree_document
         { path = "/tmp/clicked"; prompt = ""; output = None; error = None }));
  assert (
    has_event
      (`Assoc
         [
           ("type", `String "set_prompt");
           ("prompt", `String "/igor-pending-reviews");
         ])
      (worktree_document
         { path = "/tmp/clicked"; prompt = ""; output = None; error = None }));
  assert (
    has_event
      (`Assoc
         [
           ("type", `String "set_prompt");
           ("prompt", `String "/igor-restart-mr-tests");
         ])
      (worktree_document
         { path = "/tmp/clicked"; prompt = ""; output = None; error = None }));
  assert (Remote_dev.Home.Cmd.none () = None);
  assert (
    Remote_dev.Home.Cmd.map
      (fun message -> "home:" ^ message)
      (fun () -> Some "child")
      ()
    = Some "home:child");
  let _, _, route =
    Remote_dev.Home.Worktrees.update Remote_dev.Home.Worktrees.initial
      (Remote_dev.Home.Worktrees.Select "/tmp/clicked")
  in
  assert (route = Some (Remote_dev.Home.Route.Worktree "/tmp/clicked"));
  let next, cmd =
    Remote_dev.Home.Home.update
      {
        screen =
          Remote_dev.Home.Home.Worktrees Remote_dev.Home.Worktrees.initial;
      }
      (Remote_dev.Home.Home.Worktrees_msg
         (Remote_dev.Home.Worktrees.Loaded (Ok [])))
  in
  assert (cmd () = None);
  assert (
    match next.screen with
    | Remote_dev.Home.Home.Worktrees { worktrees = []; error = None } -> true
    | Remote_dev.Home.Home.Worktrees _ | Remote_dev.Home.Home.Worktree _ ->
        false);
  let next, cmd =
    Remote_dev.Home.Home.update
      {
        screen =
          Remote_dev.Home.Home.Worktrees Remote_dev.Home.Worktrees.initial;
      }
      Remote_dev.Home.Home.Back
  in
  assert (cmd () = None);
  assert (
    match next.screen with
    | Remote_dev.Home.Home.Worktrees { worktrees = []; error = None } -> true
    | Remote_dev.Home.Home.Worktrees _ | Remote_dev.Home.Home.Worktree _ ->
        false);
  Remote_dev.Home.reset ();
  let status, body, content_type =
    Remote_dev.Server.response
      ~body:
        (event
           [
             ("type", `String "select_worktree");
             ("path", `String "/tmp/clicked");
           ]
           `Null)
      `POST "/"
  in
  assert (status = `OK);
  assert (content_type = "application/json");
  let worktree = Yojson.Basic.from_string body in
  assert (
    worktree
    = worktree_document
        { path = "/tmp/clicked"; prompt = ""; output = None; error = None });
  assert (not (has_event (`Assoc [ ("type", `String "back") ]) worktree));
  let status, body, _ =
    Remote_dev.Server.response
      ~body:
        (event
           [
             ("type", `String "set_prompt");
             ("prompt", `String "/igor-pending-reviews");
           ]
           `Null)
      `POST "/"
  in
  assert (status = `OK);
  assert (
    Yojson.Basic.from_string body
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
        (event
           [
             ("type", `String "set_prompt");
             ("prompt", `String "/igor-restart-mr-tests");
           ]
           `Null)
      `POST "/"
  in
  assert (status = `OK);
  assert (
    Yojson.Basic.from_string body
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
         (Remote_dev.Home.Worktree.Finished (Ok "answer")))
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
      ~body:(event [ ("type", `String "run_claude") ] `Null)
      `POST "/"
  in
  assert (status = `OK);
  assert (
    Yojson.Basic.from_string body
    = worktree_document
        {
          path = "/tmp/clicked";
          prompt = "/igor-restart-mr-tests";
          output = Some "answer";
          error = Some "Command event requires a value";
        });
  let status, body, _ =
    Remote_dev.Server.response
      ~body:(event [ ("type", `String "load") ] `Null)
      `POST "/"
  in
  assert (status = `OK);
  assert (
    Yojson.Basic.from_string body
    = worktree_document
        {
          path = "/tmp/clicked";
          prompt = "/igor-restart-mr-tests";
          output = Some "answer";
          error = None;
        });
  let status, body, _ =
    Remote_dev.Server.response
      ~body:(event [ ("type", `String "back") ] `Null)
      `POST "/"
  in
  assert (status = `OK);
  assert (
    match (Atomic.get Remote_dev.Home.state).screen with
    | Remote_dev.Home.Home.Worktrees model ->
        Yojson.Basic.from_string body = worktrees_document model
    | Remote_dev.Home.Home.Worktree _ -> false);

  let status, _, _ = Remote_dev.Server.response `GET "/" in
  assert (status = `Not_found);
  let status, _, _ = Remote_dev.Server.response `POST "/missing" in
  assert (status = `Not_found);
  let status, _, _ = Remote_dev.Server.response ~body:"{}" `POST "/" in
  assert (status = `Bad_request);
  Remote_dev.Home.reset ();
  let status, body, _ =
    Remote_dev.Server.response
      ~body:(event [ ("type", `String "back") ] `Null)
      `POST "/"
  in
  assert (status = `OK);
  assert (
    Yojson.Basic.from_string body
    = worktrees_document { worktrees = []; error = None });
  let next, _ =
    Remote_dev.Home.Home.update
      {
        screen =
          Remote_dev.Home.Home.Worktree
            (Remote_dev.Home.Worktree.initial "/tmp/clicked");
      }
      Remote_dev.Home.Home.Back
  in
  assert (
    match next.screen with
    | Remote_dev.Home.Home.Worktrees { error = None; _ } -> true
    | Remote_dev.Home.Home.Worktrees _ | Remote_dev.Home.Home.Worktree _ ->
        false);
  Remote_dev.Home.reset ();
  let status, body, _ =
    Remote_dev.Server.response
      ~body:(event [ ("type", `String "run_claude") ] `Null)
      `POST "/"
  in
  assert (status = `OK);
  assert (
    Yojson.Basic.from_string body
    = worktrees_document
        { worktrees = []; error = Some "Command requires a selected worktree" });
  Remote_dev.Home.reset ();
  assert (
    match (Atomic.get Remote_dev.Home.state).screen with
    | Remote_dev.Home.Home.Worktrees _ -> true
    | Remote_dev.Home.Home.Worktree _ -> false);
  let model = Remote_dev.Home.Worktree.initial "/tmp/clicked" in
  let model, _cmd, route =
    Remote_dev.Home.Worktree.update model
      (Remote_dev.Home.Worktree.Event
         (Remote_dev.Home.Worktree.Run_claude, Some "prompt"))
  in
  assert (route = None);
  let model, _cmd, _ =
    Remote_dev.Home.Worktree.update model
      (Remote_dev.Home.Worktree.Finished (Ok "answer"))
  in
  assert (model.output = Some "answer");
  let model, _, _ =
    Remote_dev.Home.Worktree.update model
      (Remote_dev.Home.Worktree.Finished (Error "failed"))
  in
  assert (model.error = Some "failed")

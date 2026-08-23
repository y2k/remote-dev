let () =
  let event fields value =
    Yojson.Basic.to_string
      (`Assoc [ ("event", `Assoc fields); ("value", value) ])
  in
  let rec has_back = function
    | `Assoc fields ->
        List.exists
          (fun (name, value) ->
            (name = "event" && value = `Assoc [ ("type", `String "back") ])
            || has_back value)
          fields
    | `List values -> List.exists has_back values
    | _ -> false
  in
  assert (
    Remote_dev.Components.edit
      ~event:(`Assoc [ ("type", `String "todo") ])
      "Command"
    = `Assoc
        [
          ("@type", `String "input");
          ("label", `String "Command");
          ("event", `Assoc [ ("type", `String "todo") ]);
        ]);
  assert (
    Remote_dev.Components.edit ~text:"draft"
      ~event:(`Assoc [ ("type", `String "todo") ])
      "Command"
    = `Assoc
        [
          ("@type", `String "input");
          ("label", `String "Command");
          ("event", `Assoc [ ("type", `String "todo") ]);
          ("text", `String "draft");
        ]);
  assert (Remote_dev.Home.Cmd.none () = None);
  assert (
    Remote_dev.Home.Cmd.map
      (fun message -> "home:" ^ message)
      (fun () -> Some "child")
      ()
    = Some "home:child");
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
    = Remote_dev.Home.Worktree.view
        { path = "/tmp/clicked"; output = None; error = None });
  assert (not (has_back worktree));
  let document =
    Remote_dev.Home.dispatch
      (Remote_dev.Home.Home.Worktree_msg
         (Remote_dev.Home.Worktree.Finished (Ok "answer")))
  in
  assert (
    Remote_dev.Home.Home.document document
    = Remote_dev.Home.Worktree.view
        { path = "/tmp/clicked"; output = Some "answer"; error = None });

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
    = Remote_dev.Home.Worktrees.view { worktrees = []; error = None });
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
    = Remote_dev.Home.Worktrees.view
        { worktrees = []; error = Some "Command requires a selected worktree" });
  Remote_dev.Home.reset ();
  assert (
    match (Atomic.get Remote_dev.Home.state).screen with
    | Remote_dev.Home.Home.Worktrees _ -> true
    | Remote_dev.Home.Home.Worktree _ -> false);
  let model = Remote_dev.Home.Worktree.initial "/tmp/clicked" in
  let model, _cmd, action =
    Remote_dev.Home.Worktree.update model
      (Remote_dev.Home.Worktree.Run (Some "prompt"))
  in
  assert (action = Remote_dev.Home.Worktree.Stay);
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

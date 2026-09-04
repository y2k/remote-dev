module J = Yojson.Safe
module Cmd = Remote_dev.Components.Cmd
module Home_components = Remote_dev.Home_components

let claude_environment : Remote_dev.Runtime.environment =
  { agent = Remote_dev.Runtime.Claude; root = "/tmp/remote-dev-root" }

let opencode_environment : Remote_dev.Runtime.environment =
  { agent = Remote_dev.Runtime.OpenCode; root = "/tmp/remote-dev-root" }

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

let with_emulator_screenshot ~available f =
  try f () with
  | effect
      Remote_dev.Runtime.Process_lines
        (Remote_dev.Runtime.Args ("adb", argv), on_line), k ->
      (match argv with
      | [| "adb"; "devices"; "-l" |] ->
          if available then List.iter on_line [ "emulator-5554\tdevice" ]
      | [| "adb"; "-s"; "emulator-5554"; "emu"; "avd"; "name" |] ->
          List.iter on_line [ "Pixel"; "OK" ]
      | _ -> assert false);
      Effect.Deep.continue k (Unix.WEXITED 0)
  | effect
      Remote_dev.Runtime.Process_bytes (Remote_dev.Runtime.Args ("adb", argv)), k
    ->
      assert (
        argv = [| "adb"; "-s"; "emulator-5554"; "exec-out"; "screencap"; "-p" |]);
      Effect.Deep.continue k ("\137PNG", Unix.WEXITED 0)

let with_failed_emulator_load f =
  try f () with
  | effect
      Remote_dev.Runtime.Process_lines (Remote_dev.Runtime.Args ("adb", argv), _), k
    ->
      assert (argv = [| "adb"; "devices"; "-l" |]);
      Effect.Deep.continue k (Unix.WEXITED 1)
  | effect Remote_dev.Runtime.Process_lines (_, on_line), k ->
      List.iter on_line [ "worktree /tmp/remote-dev"; "branch refs/heads/main" ];
      Effect.Deep.continue k (Unix.WEXITED 0)

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
         [ ("event", Remote_dev.Home.msg_to_yojson message); ("value", `Null) ])
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
  let rec has_image src = function
    | `Assoc fields ->
        List.assoc_opt "@type" fields = Some (`String "image")
        && List.assoc_opt "src" fields = Some (`String src)
        || List.exists (fun (_, value) -> has_image src value) fields
    | `List values -> List.exists (has_image src) values
    | _ -> false
  in
  let rec has_text text = function
    | `Assoc fields ->
        List.assoc_opt "text" fields = Some (`String text)
        || List.exists (fun (_, value) -> has_text text value) fields
    | `List values -> List.exists (has_text text) values
    | _ -> false
  in
  let root_panes = function
    | `Assoc fields -> (
        match
          ( List.assoc_opt "@type" fields,
            List.assoc_opt "children" fields,
            List.assoc_opt "weights" fields )
        with
        | ( Some (`String "row"),
            Some (`List [ left; right ]),
            Some (`List [ `Int 2; `Int 1 ]) ) ->
            Some (left, right)
        | _ -> None)
    | _ -> None
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
         (Remote_dev.Components.column
            [
              Remote_dev.Components.row
                [
                  Remote_dev.Components.image
                    ~src:"/emulators/emulator-5554/screenshot.png"
                    ~label:"Pixel";
                ];
            ]))
    = `Assoc
        [
          ("@type", `String "column");
          ( "children",
            `List
              [
                `Assoc
                  [
                    ("@type", `String "row");
                    ( "children",
                      `List
                        [
                          `Assoc
                            [
                              ("@type", `String "image");
                              ( "src",
                                `String
                                  "/emulators/emulator-5554/screenshot.png" );
                              ("label", `String "Pixel");
                            ];
                        ] );
                  ];
              ] );
        ]);
  assert (
    Remote_dev.Components.to_json App.encode
      (Remote_dev.Components.map
         (fun event -> App.Todo event)
         (Remote_dev.Components.row ~weights:[ 2; 1 ]
            [
              Remote_dev.Components.button ~event:Todo.Submit "Button";
              Remote_dev.Components.text "Preview";
            ]))
    = `Assoc
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
                `Assoc
                  [ ("@type", `String "text"); ("text", `String "Preview") ];
              ] );
          ("weights", `List [ `Int 2; `Int 1 ]);
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
  let initial_emulator = Home_components.Emulator.init () |> fst in
  let initial_new_worktree = Home_components.New_worktree.init () |> fst in
  let initial_worktrees =
    Home_components.Worktrees.init claude_environment.root |> fst
  in
  let initial_worktree path = Home_components.Worktree.init path |> fst in
  let worktrees_document ?(environment = claude_environment)
      ?(emulator = initial_emulator) model =
    Remote_dev.Server.to_json environment
      { screen = Remote_dev.Home.Worktrees model; emulator }
  in
  let worktree_document ?(environment = claude_environment)
      ?(emulator = initial_emulator) model =
    Remote_dev.Server.to_json environment
      { screen = Remote_dev.Home.Worktree model; emulator }
  in
  let creation_document ?(environment = claude_environment)
      ?(emulator = initial_emulator) model =
    let creation = initial_new_worktree in
    Remote_dev.Server.to_json environment
      { screen = Remote_dev.Home.New_worktree (model, creation); emulator }
  in
  let creation_document_with ?(environment = claude_environment)
      ?(emulator = initial_emulator) model creation =
    Remote_dev.Server.to_json environment
      { screen = Remote_dev.Home.New_worktree (model, creation); emulator }
  in
  let home_event = Remote_dev.Home.msg_to_yojson in
  let selected_emulator =
    {
      Home_components.Emulator.emulators =
        [ { Remote_dev.Runtime.serial = "emulator-5554"; name = "Pixel" } ];
      selected_emulator = Some "emulator-5554";
      error = None;
    }
  in
  let assert_root_split document left_text check_right =
    match root_panes document with
    | Some (left, right) ->
        assert (has_text left_text left);
        assert (not (has_text "Emulators" left));
        assert (has_text "Emulators" right);
        check_right right
    | None -> assert false
  in
  let listed_worktree =
    {
      Home_components.Worktrees.worktrees =
        [ { path = "/tmp/clicked"; branch = "main" } ];
      error = None;
    }
  in
  assert_root_split
    (worktrees_document ~emulator:selected_emulator listed_worktree)
    "Worktrees:" (fun right ->
      assert (has_image "/emulators/emulator-5554/screenshot.png" right));
  assert_root_split
    (creation_document ~emulator:selected_emulator listed_worktree)
    "New worktree" (fun right ->
      assert (has_image "/emulators/emulator-5554/screenshot.png" right));
  let worktree = initial_worktree "/tmp/clicked" in
  assert_root_split (worktree_document ~emulator:selected_emulator worktree)
    "Worktree" (fun right ->
      assert (has_image "/emulators/emulator-5554/screenshot.png" right));
  assert_root_split (worktree_document worktree) "Worktree" (fun right ->
      assert (has_text "No running emulators" right));
  assert_root_split
    (worktree_document
       ~emulator:{ initial_emulator with error = Some "failed" }
       worktree)
    "Worktree"
    (fun right -> assert (has_text "Error: failed" right));
  assert_root_split
    (worktree_document
       ~emulator:{ selected_emulator with error = Some "adb unavailable" }
       worktree)
    "Worktree"
    (fun right ->
      assert (has_text "Error: adb unavailable" right);
      assert (has_image "/emulators/emulator-5554/screenshot.png" right));
  List.iter
    (fun document ->
      assert (has_text "Agent: Claude" document);
      assert (not (has_text "Agent: OpenCode" document)))
    [
      worktrees_document listed_worktree;
      creation_document listed_worktree;
      worktree_document worktree;
    ];
  List.iter
    (fun document ->
      assert (has_text "Agent: OpenCode" document);
      assert (not (has_text "Agent: Claude" document)))
    [
      worktrees_document ~environment:opencode_environment listed_worktree;
      creation_document ~environment:opencode_environment listed_worktree;
      worktree_document ~environment:opencode_environment worktree;
    ];
  assert (
    not
      (has_event
         (home_event
            (Remote_dev.Home.Worktrees_msg
               Home_components.Worktrees.Open_creation))
         (worktrees_document ~environment:opencode_environment listed_worktree)));
  assert (
    not
      (has_event
         (home_event
            (Remote_dev.Home.Worktree_msg
               (Home_components.Worktree.Set_prompt "/igor-pending-reviews")))
         (worktree_document ~environment:opencode_environment worktree)));
  assert (
    not
      (has_event
         (home_event
            (Remote_dev.Home.Worktree_msg
               (Home_components.Worktree.Set_prompt "/igor-restart-mr-tests")))
         (worktree_document ~environment:opencode_environment worktree)));
  let opencode_home =
    {
      Remote_dev.Home.screen = Remote_dev.Home.Worktrees listed_worktree;
      emulator = initial_emulator;
    }
  in
  let unchanged, cmd =
    Remote_dev.Home.update opencode_environment opencode_home
      (Remote_dev.Home.Worktrees_msg Home_components.Worktrees.Open_creation)
  in
  assert (unchanged = opencode_home);
  assert (Cmd.run cmd = None);
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Worktree_msg
            (Home_components.Worktree.Run_prompt "__VALUE__")))
      (worktree_document worktree));
  let round_trip message =
    assert (
      Remote_dev.Home.msg_of_yojson (Remote_dev.Home.msg_to_yojson message)
      = Ok message)
  in
  round_trip
    (Remote_dev.Home.Worktrees_msg (Home_components.Worktrees.Loaded (Ok [])));
  round_trip
    (Remote_dev.Home.Worktrees_msg
       (Home_components.Worktrees.Loaded (Error "failed")));
  round_trip
    (Remote_dev.Home.Worktree_msg
       (Home_components.Worktree.Finished (Ok "answer")));
  round_trip
    (Remote_dev.Home.Worktree_msg
       (Home_components.Worktree.Finished (Error "failed")));
  round_trip
    (Remote_dev.Home.Emulator_msg
       (Home_components.Emulator.Select "emulator-5554"));
  assert (
    Remote_dev.Server.decode (request_body Remote_dev.Home.Back)
    = Ok Remote_dev.Home.Back);
  assert (
    Remote_dev.Server.decode
      (J.to_string
         (`Assoc
            [
              ( "event",
                Remote_dev.Home.msg_to_yojson
                  (Remote_dev.Home.Worktree_msg
                     (Home_components.Worktree.Run_prompt "__VALUE__")) );
              ("value", `String "prompt");
            ]))
    = Ok
        (Remote_dev.Home.Worktree_msg
           (Home_components.Worktree.Run_prompt "prompt")));
  assert (
    match
      Remote_dev.Server.decode
        (request_body
           (Remote_dev.Home.Worktree_msg
              (Home_components.Worktree.Session_started "attacker")))
    with
    | Error _ -> true
    | Ok _ -> false);
  assert (
    match
      Remote_dev.Server.decode
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
  let initial, cmd = Remote_dev.Home.init claude_environment in
  assert (initial.emulator = initial_emulator);
  assert (
    match initial.screen with
    | Remote_dev.Home.Worktrees { worktrees = []; error = None } -> true
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _
    | Remote_dev.Home.Worktree _ ->
        false);
  let initialized =
    match with_emulator_screenshot ~available:true (fun () -> Cmd.run cmd) with
    | Some
        (Remote_dev.Home.Initialize_emulator
           (Home_components.Emulator.Loaded (Ok [ emulator ]))) ->
        assert (emulator.name = "Pixel");
        Remote_dev.Home.Initialize_emulator
          (Home_components.Emulator.Loaded (Ok [ emulator ]))
    | _ -> assert false
  in
  let initialized_state, cmd =
    Remote_dev.Home.update claude_environment initial initialized
  in
  assert (initialized_state.emulator.selected_emulator = Some "emulator-5554");
  assert (
    match with_process (fun () -> Cmd.run cmd) with
    | Some (Remote_dev.Home.Worktrees_msg (Home_components.Worktrees.Loaded _))
      ->
        true
    | _ -> false);
  let failed_state, cmd =
    Remote_dev.Home.update claude_environment initial
      (Remote_dev.Home.Initialize_emulator
         (Home_components.Emulator.Loaded (Error "adb failed")))
  in
  assert (failed_state.emulator.error = Some "adb failed");
  assert (
    match with_process (fun () -> Cmd.run cmd) with
    | Some (Remote_dev.Home.Worktrees_msg (Home_components.Worktrees.Loaded _))
      ->
        true
    | _ -> false);
  Atomic.set Remote_dev.Server.state initialized_state;
  Remote_dev.Server.reset claude_environment;
  let initial = Atomic.get Remote_dev.Server.state in
  assert (initial.emulator = initial_emulator);
  let documents =
    Remote_dev.Server.stream_body claude_environment initial
      (Cmd.Run
         (fun () ->
           Some
             (Remote_dev.Home.Worktrees_msg
                (Home_components.Worktrees.Loaded (Error "failed")))))
    |> stream_documents
  in
  assert (List.length documents = 2);
  assert (
    match (Atomic.get Remote_dev.Server.state).screen with
    | Remote_dev.Home.Worktrees { error = Some "failed"; _ } -> true
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _
    | Remote_dev.Home.Worktree _ ->
        false);
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Worktrees_msg
            (Home_components.Worktrees.Select "/tmp/clicked")))
      (worktrees_document
         {
           worktrees = [ { path = "/tmp/clicked"; branch = "main" } ];
           error = None;
         }));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Worktrees_msg Home_components.Worktrees.Open_creation))
      (worktrees_document
         {
           worktrees = [ { path = "/tmp/clicked"; branch = "main" } ];
           error = None;
         }));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.New_worktree_msg
            (Home_components.New_worktree.Create "__VALUE__")))
      (creation_document
         {
           worktrees = [ { path = "/tmp/clicked"; branch = "main" } ];
           error = None;
         }));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Worktree_msg
            (Home_components.Worktree.Run_prompt "__VALUE__")))
      (worktree_document
         {
           path = "/tmp/clicked";
           prompt = "";
           output = None;
           error = None;
           session_id = None;
         }));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Worktree_msg
            (Home_components.Worktree.Set_prompt "/igor-pending-reviews")))
      (worktree_document
         {
           path = "/tmp/clicked";
           prompt = "";
           output = None;
           error = None;
           session_id = None;
         }));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Worktree_msg
            (Home_components.Worktree.Set_prompt "/igor-restart-mr-tests")))
      (worktree_document
         {
           path = "/tmp/clicked";
           prompt = "";
           output = None;
           error = None;
           session_id = None;
         }));
  assert (Cmd.run Cmd.none = None);
  assert (
    Cmd.run
      (Cmd.map
         (fun message -> "home:" ^ message)
         (Cmd.Run (fun () -> Some "child")))
    = Some "home:child");
  let next, cmd =
    Remote_dev.Home.update claude_environment
      {
        screen = Remote_dev.Home.Worktrees initial_worktrees;
        emulator = initial_emulator;
      }
      (Remote_dev.Home.Worktrees_msg (Home_components.Worktrees.Loaded (Ok [])))
  in
  assert (Cmd.run cmd = None);
  assert (
    match next.screen with
    | Remote_dev.Home.Worktrees { worktrees = []; error = None } -> true
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _
    | Remote_dev.Home.Worktree _ ->
        false);
  let next, cmd =
    Remote_dev.Home.update claude_environment
      {
        screen = Remote_dev.Home.Worktrees initial_worktrees;
        emulator = initial_emulator;
      }
      Remote_dev.Home.Back
  in
  assert (Cmd.run cmd = None);
  assert (
    match next.screen with
    | Remote_dev.Home.Worktrees { worktrees = []; error = None } -> true
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _
    | Remote_dev.Home.Worktree _ ->
        false);
  let listed_worktrees =
    {
      Home_components.Worktrees.worktrees =
        [ { path = "/tmp/clicked"; branch = "main" } ];
      error = None;
    }
  in
  let creation, cmd =
    Remote_dev.Home.update claude_environment
      {
        screen = Remote_dev.Home.Worktrees listed_worktrees;
        emulator = selected_emulator;
      }
      (Remote_dev.Home.Worktrees_msg Home_components.Worktrees.Open_creation)
  in
  assert (Cmd.run cmd = None);
  assert (
    Remote_dev.Server.to_json claude_environment creation
    = creation_document ~emulator:selected_emulator listed_worktrees);
  let creation, cmd =
    Remote_dev.Home.update claude_environment creation
      (Remote_dev.Home.New_worktree_msg
         (Home_components.New_worktree.Create "feature/new-worktree"))
  in
  assert (match cmd with Cmd.Run _ -> true | Cmd.Empty -> false);
  assert (
    Remote_dev.Server.to_json claude_environment creation
    = creation_document ~emulator:selected_emulator listed_worktrees);
  let finished, cmd =
    Remote_dev.Home.update claude_environment creation
      (Remote_dev.Home.New_worktree_msg
         (Home_components.New_worktree.Finished (Ok ())))
  in
  assert (finished.emulator = selected_emulator);
  assert (
    match with_process (fun () -> Cmd.run cmd) with
    | Some (Remote_dev.Home.Worktrees_msg (Home_components.Worktrees.Loaded _))
      ->
        true
    | _ -> false);
  let listed, cmd =
    Remote_dev.Home.update claude_environment creation Remote_dev.Home.Back
  in
  assert (Cmd.run cmd = None);
  assert (
    Remote_dev.Server.to_json claude_environment listed
    = worktrees_document ~emulator:selected_emulator listed_worktrees);
  Remote_dev.Server.reset claude_environment;
  let status, body, _ =
    Remote_dev.Server.response claude_environment
      ~body:
        (request_body
           (Remote_dev.Home.Worktrees_msg
              Home_components.Worktrees.Open_creation))
      `POST "/"
  in
  assert (status = `OK);
  assert (J.from_string body = creation_document initial_worktrees);
  let status, body, _ =
    with_created_worktree (fun () ->
        Remote_dev.Server.response claude_environment
          ~body:
            (request_body
               (Remote_dev.Home.New_worktree_msg
                  (Home_components.New_worktree.Create "feature/new-worktree")))
          `POST "/")
  in
  assert (status = `OK);
  let documents = stream_documents body in
  assert (List.hd documents = creation_document initial_worktrees);
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
  Atomic.set Remote_dev.Server.state
    {
      Remote_dev.Home.screen =
        Remote_dev.Home.New_worktree (listed_worktrees, initial_new_worktree);
      emulator = initial_emulator;
    };
  let status, body, _ =
    with_failed_worktree_creation (fun () ->
        Remote_dev.Server.response claude_environment
          ~body:
            (request_body
               (Remote_dev.Home.New_worktree_msg
                  (Home_components.New_worktree.Create "broken")))
          `POST "/")
  in
  assert (status = `OK);
  assert (List.length (stream_documents body) = 2);
  assert (
    match (Atomic.get Remote_dev.Server.state).screen with
    | Remote_dev.Home.New_worktree (_, { error = Some _ }) -> true
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _
    | Remote_dev.Home.Worktree _ ->
        false);
  Atomic.set Remote_dev.Server.state
    {
      Remote_dev.Home.screen =
        Remote_dev.Home.New_worktree (listed_worktrees, initial_new_worktree);
      emulator = initial_emulator;
    };
  let status, body, _ =
    Remote_dev.Server.response claude_environment
      ~body:
        (request_body
           (Remote_dev.Home.New_worktree_msg
              (Home_components.New_worktree.Create "")))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body
    = creation_document_with listed_worktrees
        { error = Some "Branch is required" });
  let status, body, _ =
    Remote_dev.Server.response claude_environment
      ~body:(request_body Remote_dev.Home.Back)
      `POST "/"
  in
  assert (status = `OK);
  assert (J.from_string body = worktrees_document listed_worktrees);
  Remote_dev.Server.reset claude_environment;
  let selected_emulators =
    [ { Remote_dev.Runtime.serial = "emulator-5554"; name = "Pixel" } ]
  in
  let emulator_model =
    {
      Home_components.Emulator.emulators = selected_emulators;
      selected_emulator = Some "emulator-5554";
      error = None;
    }
  in
  Atomic.set Remote_dev.Server.state
    {
      Remote_dev.Home.screen = Remote_dev.Home.Worktrees initial_worktrees;
      emulator = emulator_model;
    };
  let status, body, content_type =
    Remote_dev.Server.response claude_environment
      ~body:
        (request_body
           (Remote_dev.Home.Worktrees_msg
              (Home_components.Worktrees.Select "/tmp/clicked")))
      `POST "/"
  in
  assert (status = `OK);
  assert (content_type = "application/json");
  let worktree = J.from_string body in
  assert (
    worktree
    = worktree_document ~emulator:emulator_model
        {
          path = "/tmp/clicked";
          prompt = "";
          output = None;
          error = None;
          session_id = None;
        });
  assert (not (has_event (`Assoc [ ("type", `String "back") ]) worktree));
  let status, body, _ =
    Remote_dev.Server.response claude_environment
      ~body:
        (request_body
           (Remote_dev.Home.Worktree_msg
              (Home_components.Worktree.Set_prompt "/igor-pending-reviews")))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body
    = worktree_document ~emulator:emulator_model
        {
          path = "/tmp/clicked";
          prompt = "/igor-pending-reviews";
          output = None;
          error = None;
          session_id = None;
        });
  let status, body, _ =
    Remote_dev.Server.response claude_environment
      ~body:
        (request_body
           (Remote_dev.Home.Worktree_msg
              (Home_components.Worktree.Set_prompt "/igor-restart-mr-tests")))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body
    = worktree_document ~emulator:emulator_model
        {
          path = "/tmp/clicked";
          prompt = "/igor-restart-mr-tests";
          output = None;
          error = None;
          session_id = None;
        });
  let document =
    Remote_dev.Server.dispatch claude_environment
      (Remote_dev.Home.Worktree_msg
         (Home_components.Worktree.Finished (Ok "answer")))
  in
  assert (
    Remote_dev.Server.to_json claude_environment document
    = worktree_document ~emulator:emulator_model
        {
          path = "/tmp/clicked";
          prompt = "/igor-restart-mr-tests";
          output = Some "answer";
          error = None;
          session_id = None;
        });
  let status, body, _ =
    Remote_dev.Server.response claude_environment
      ~body:
        (request_body
           (Remote_dev.Home.Worktree_msg
              (Home_components.Worktree.Run_prompt "new prompt")))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body
    = worktree_document ~emulator:emulator_model
        {
          path = "/tmp/clicked";
          prompt = "new prompt";
          output = None;
          error = None;
          session_id = None;
        });
  let status, body, content_type =
    with_process (fun () ->
        Remote_dev.Server.response claude_environment
          ~body:(request_body Remote_dev.Home.Back)
          `POST "/")
  in
  assert (status = `OK);
  assert (content_type = "application/x-ndjson");
  assert (
    match Atomic.get Remote_dev.Server.state with
    | { screen = Remote_dev.Home.Worktrees model; emulator } ->
        List.hd (List.rev (stream_documents body))
        = worktrees_document ~emulator model
    | { screen = Remote_dev.Home.New_worktree _; _ }
    | { screen = Remote_dev.Home.Worktree _; _ } ->
        false);

  Remote_dev.Server.reset claude_environment;
  with_emulator_screenshot ~available:true (fun () ->
      with_process (fun () -> Remote_dev.Server.initialize claude_environment));
  let status, body, content_type =
    Remote_dev.Server.response claude_environment `GET "/"
  in
  assert (status = `OK);
  assert (content_type = "application/json");
  assert (
    match Atomic.get Remote_dev.Server.state with
    | { screen = Remote_dev.Home.Worktrees model; emulator } ->
        J.from_string body = worktrees_document ~emulator model
    | { screen = Remote_dev.Home.New_worktree _; _ }
    | { screen = Remote_dev.Home.Worktree _; _ } ->
        false);
  let status, body, content_type =
    Remote_dev.Server.response claude_environment `GET "/"
  in
  assert (status = `OK);
  assert (content_type = "application/json");
  assert (
    match Atomic.get Remote_dev.Server.state with
    | { screen = Remote_dev.Home.Worktrees model; emulator } ->
        J.from_string body = worktrees_document ~emulator model
    | { screen = Remote_dev.Home.New_worktree _; _ }
    | { screen = Remote_dev.Home.Worktree _; _ } ->
        false);
  let previous = J.from_string body in
  let status, body, content_type =
    with_process (fun () ->
        Remote_dev.Server.response claude_environment
          ~body:
            (request_body
               (Remote_dev.Home.Worktrees_msg Home_components.Worktrees.Load))
          `POST "/")
  in
  assert (status = `OK);
  assert (content_type = "application/x-ndjson");
  let documents = stream_documents body in
  assert (List.length documents = 2);
  assert (List.hd documents = previous);
  assert (
    match Atomic.get Remote_dev.Server.state with
    | { screen = Remote_dev.Home.Worktrees model; emulator } ->
        List.hd (List.rev documents) = worktrees_document ~emulator model
    | { screen = Remote_dev.Home.New_worktree _; _ }
    | { screen = Remote_dev.Home.Worktree _; _ } ->
        false);
  Remote_dev.Server.reset claude_environment;
  with_failed_emulator_load (fun () ->
      Remote_dev.Server.initialize claude_environment);
  assert (
    match Atomic.get Remote_dev.Server.state with
    | {
     screen = Remote_dev.Home.Worktrees { worktrees = _ :: _; _ };
     emulator = { error = Some _; _ };
    } ->
        true
    | _ -> false);
  let status, _, _ =
    Remote_dev.Server.response claude_environment `POST "/missing"
  in
  assert (status = `Not_found);
  let status, _, _ =
    Remote_dev.Server.response claude_environment `GET "/missing"
  in
  assert (status = `Not_found);
  let status, _, _ =
    Remote_dev.Server.response claude_environment ~body:"{}" `POST "/"
  in
  assert (status = `Bad_request);
  Remote_dev.Server.reset claude_environment;
  let status, body, _ =
    Remote_dev.Server.response claude_environment
      ~body:(request_body Remote_dev.Home.Back)
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body = worktrees_document { worktrees = []; error = None });
  let next, cmd =
    Remote_dev.Home.update claude_environment
      {
        screen = Remote_dev.Home.Worktree (initial_worktree "/tmp/clicked");
        emulator = selected_emulator;
      }
      Remote_dev.Home.Back
  in
  assert (
    match with_process (fun () -> Cmd.run cmd) with
    | Some (Remote_dev.Home.Worktrees_msg (Home_components.Worktrees.Loaded _))
      ->
        true
    | _ -> false);
  assert (
    match next.screen with
    | Remote_dev.Home.Worktrees { error = None; _ } -> true
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _
    | Remote_dev.Home.Worktree _ ->
        false);
  assert (next.emulator = selected_emulator);
  Remote_dev.Server.reset claude_environment;
  let status, body, _ =
    Remote_dev.Server.response claude_environment
      ~body:
        (request_body
           (Remote_dev.Home.Worktree_msg
              (Home_components.Worktree.Run_prompt "prompt")))
      `POST "/"
  in
  assert (status = `OK);
  assert (
    J.from_string body = worktrees_document { worktrees = []; error = None });
  Remote_dev.Server.reset claude_environment;
  assert (
    match (Atomic.get Remote_dev.Server.state).screen with
    | Remote_dev.Home.Worktrees _ -> true
    | Remote_dev.Home.New_worktree _ | Remote_dev.Home.Worktree _ -> false);
  let model = initial_worktree "/tmp/clicked" in
  let emulators =
    [
      { Remote_dev.Runtime.serial = "emulator-5554"; name = "Pixel" };
      { serial = "emulator-5556"; name = "Test" };
    ]
  in
  let initialized_emulator, load = Home_components.Emulator.init () in
  assert (initialized_emulator = initial_emulator);
  assert (
    match with_emulator_screenshot ~available:true (fun () -> Cmd.run load) with
    | Some (Home_components.Emulator.Loaded (Ok [ emulator ])) ->
        emulator = List.hd emulators
    | _ -> false);
  let emulator, cmd =
    Home_components.Emulator.update initialized_emulator
      (Home_components.Emulator.Loaded (Ok emulators))
  in
  assert (Cmd.run cmd = None);
  assert (emulator.selected_emulator = Some "emulator-5554");
  let emulator_document =
    Remote_dev.Components.to_json Home_components.Emulator.msg_to_yojson
      (Home_components.Emulator.view emulator)
  in
  assert (
    has_event
      (Home_components.Emulator.msg_to_yojson
         (Home_components.Emulator.Select "emulator-5556"))
      emulator_document);
  assert (has_image "/emulators/emulator-5554/screenshot.png" emulator_document);
  let selected, cmd =
    Home_components.Emulator.update emulator
      (Home_components.Emulator.Select "emulator-5556")
  in
  assert (Cmd.run cmd = None);
  assert (selected.selected_emulator = Some "emulator-5556");
  let unchanged, cmd =
    Home_components.Emulator.update selected
      (Home_components.Emulator.Select "missing")
  in
  assert (Cmd.run cmd = None);
  assert (unchanged = selected);
  let empty, cmd =
    Home_components.Emulator.update emulator
      (Home_components.Emulator.Loaded (Ok []))
  in
  assert (Cmd.run cmd = None);
  assert (empty.selected_emulator = None);
  assert (
    not
      (has_image "/emulators/emulator-5554/screenshot.png"
         (Remote_dev.Components.to_json Home_components.Emulator.msg_to_yojson
            (Home_components.Emulator.view empty))));
  let failed, cmd =
    Home_components.Emulator.update emulator
      (Home_components.Emulator.Loaded (Error "failed"))
  in
  assert (Cmd.run cmd = None);
  assert (failed.error = Some "failed");
  let initialized_worktree, cmd =
    Home_components.Worktree.init "/tmp/clicked"
  in
  assert (initialized_worktree = model);
  assert (Cmd.run cmd = None);
  let home =
    { Remote_dev.Home.screen = Remote_dev.Home.Worktree model; emulator }
  in
  let emulator_document = Remote_dev.Server.to_json claude_environment home in
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Emulator_msg
            (Home_components.Emulator.Select "emulator-5554")))
      emulator_document);
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Emulator_msg
            (Home_components.Emulator.Select "emulator-5556")))
      emulator_document);
  assert (has_image "/emulators/emulator-5554/screenshot.png" emulator_document);
  let home, cmd =
    Remote_dev.Home.update claude_environment home
      (Remote_dev.Home.Emulator_msg
         (Home_components.Emulator.Select "emulator-5556"))
  in
  assert (Cmd.run cmd = None);
  assert (home.emulator.selected_emulator = Some "emulator-5556");
  assert (
    match home.screen with
    | Remote_dev.Home.Worktree model ->
        model.path = "/tmp/clicked"
        && model.prompt = "" && model.output = None && model.error = None
        && model.session_id = None
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _ -> false);
  assert (
    has_image "/emulators/emulator-5556/screenshot.png"
      (Remote_dev.Server.to_json claude_environment home));
  let home, _cmd =
    Remote_dev.Home.update claude_environment home
      (Remote_dev.Home.Worktree_msg
         (Home_components.Worktree.Run_prompt "prompt"))
  in
  assert (home.emulator.selected_emulator = Some "emulator-5556");
  let home, _cmd =
    Remote_dev.Home.update claude_environment home
      (Remote_dev.Home.Worktree_msg
         (Home_components.Worktree.Finished (Ok "answer")))
  in
  assert (
    match home.screen with
    | Remote_dev.Home.Worktree { output = Some "answer"; _ } -> true
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _
    | Remote_dev.Home.Worktree _ ->
        false);
  assert (home.emulator.selected_emulator = Some "emulator-5556");
  let home, _ =
    Remote_dev.Home.update claude_environment home
      (Remote_dev.Home.Worktree_msg
         (Home_components.Worktree.Finished (Error "failed")))
  in
  assert (
    match home.screen with
    | Remote_dev.Home.Worktree { error = Some "failed"; _ } -> true
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _
    | Remote_dev.Home.Worktree _ ->
        false);
  assert (home.emulator.selected_emulator = Some "emulator-5556");
  assert (
    Httpun.Headers.get Remote_dev.Server.stream_headers "content-type"
    = Some "application/x-ndjson");
  assert (
    Httpun.Headers.get Remote_dev.Server.stream_headers "transfer-encoding"
    = Some "chunked");
  assert (
    not (Httpun.Headers.mem Remote_dev.Server.stream_headers "content-length"));
  Atomic.set Remote_dev.Server.state
    {
      Remote_dev.Home.screen =
        Remote_dev.Home.Worktree
          {
            (initial_worktree "/tmp/clicked") with
            output = Some "old response";
            error = Some "old error";
          };
      emulator = selected_emulator;
    };
  assert (
    match
      Remote_dev.Server.start_prompt_stream claude_environment
        (request_body
           (Remote_dev.Home.Worktree_msg
              (Home_components.Worktree.Run_prompt "prompt")))
    with
    | Some { agent; cwd; prompt; session_id } ->
        agent = Remote_dev.Runtime.Claude
        && cwd = "/tmp/clicked" && prompt = "prompt" && session_id = None
    | None -> false);
  assert (
    J.from_string (Remote_dev.Server.stream_start claude_environment)
    = worktree_document ~emulator:selected_emulator
        {
          path = "/tmp/clicked";
          prompt = "prompt";
          output = None;
          error = None;
          session_id = None;
        });
  assert (
    Remote_dev.Server.stream_event claude_environment
      (Remote_dev.Runtime.Session "session-1")
    = None);
  assert (
    match (Atomic.get Remote_dev.Server.state).screen with
    | Remote_dev.Home.Worktree { session_id = Some "session-1"; _ } -> true
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _
    | Remote_dev.Home.Worktree _ ->
        false);
  assert (
    match
      Remote_dev.Server.start_prompt_stream claude_environment
        (request_body
           (Remote_dev.Home.Worktree_msg
              (Home_components.Worktree.Run_prompt "continued")))
    with
    | Some { agent; cwd; prompt; session_id } ->
        agent = Remote_dev.Runtime.Claude
        && cwd = "/tmp/clicked" && prompt = "continued"
        && session_id = Some "session-1"
    | None -> false);
  let hel =
    Remote_dev.Server.stream_event claude_environment
      (Remote_dev.Runtime.Text "Hel")
    |> Option.get
  in
  assert (not (String.contains hel '\n'));
  assert (
    J.from_string hel
    = worktree_document ~emulator:selected_emulator
        {
          path = "/tmp/clicked";
          prompt = "continued";
          output = Some "Hel";
          error = None;
          session_id = Some "session-1";
        });
  let hello =
    Remote_dev.Server.stream_event claude_environment
      (Remote_dev.Runtime.Text "lo")
    |> Option.get
  in
  assert (
    J.from_string hello
    = worktree_document ~emulator:selected_emulator
        {
          path = "/tmp/clicked";
          prompt = "continued";
          output = Some "Hello";
          error = None;
          session_id = Some "session-1";
        });
  assert (
    J.from_string (Remote_dev.Server.stream_error claude_environment "failed")
    = worktree_document ~emulator:selected_emulator
        {
          path = "/tmp/clicked";
          prompt = "continued";
          output = Some "Hello";
          error = Some "failed";
          session_id = Some "session-1";
        });
  let producer_updates = ref [] in
  Remote_dev.Server.produce_prompt
    (fun () -> failwith "ordinary")
    (fun update -> producer_updates := update :: !producer_updates);
  assert (!producer_updates = [ `Error "Failure(\"ordinary\")" ]);
  assert (
    try
      Remote_dev.Server.produce_prompt
        (fun () -> raise (Remote_dev.Runtime.Protocol_error "fatal"))
        (fun update -> producer_updates := update :: !producer_updates);
      false
    with
    | Remote_dev.Runtime.Protocol_error "fatal" -> true
    | _ -> false);
  assert (!producer_updates = [ `Error "Failure(\"ordinary\")" ]);
  let selected = Atomic.get Remote_dev.Server.state in
  let listed, _ =
    Remote_dev.Home.update claude_environment selected Remote_dev.Home.Back
  in
  let reopened, _ =
    Remote_dev.Home.update claude_environment listed
      (Remote_dev.Home.Worktrees_msg
         (Home_components.Worktrees.Select "/tmp/clicked"))
  in
  assert (
    match reopened.screen with
    | Remote_dev.Home.Worktree { session_id = None; _ } -> true
    | Remote_dev.Home.Worktrees _ | Remote_dev.Home.New_worktree _
    | Remote_dev.Home.Worktree _ ->
        false);
  let status, body, content_type =
    with_emulator_screenshot ~available:true (fun () ->
        Remote_dev.Server.response claude_environment `GET
          "/emulators/emulator-5554/screenshot.png")
  in
  assert (status = `OK);
  assert (body = "\137PNG");
  assert (content_type = "image/png");
  let headers = Remote_dev.Server.screenshot_headers body in
  assert (Httpun.Headers.get headers "cache-control" = Some "no-store");
  let status, _, _ =
    with_emulator_screenshot ~available:false (fun () ->
        Remote_dev.Server.response claude_environment `GET
          "/emulators/emulator-5554/screenshot.png")
  in
  assert (status = `Not_found);
  let status, _, _ =
    Remote_dev.Server.response claude_environment `GET
      "/emulators/emulator-5554/other.png"
  in
  assert (status = `Not_found)

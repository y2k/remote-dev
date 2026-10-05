module J = Yojson.Safe

[@@@warning "-8"]

module Cmd = Remote_dev.Components.Cmd
module Home_components = Remote_dev.Home_components
module Result_yojson = Remote_dev.Result_yojson

let claude_environment : Remote_dev.Runtime.environment =
  Remote_dev.Runtime.Claude { root = "/tmp/remote-dev-root" }

let opencode_environment : Remote_dev.Runtime.environment =
  Remote_dev.Runtime.OpenCode { root = Sys.getcwd () }

let with_process f =
  try f ()
  with effect Remote_dev.Runtime.Process_lines (_, on_line), k ->
    List.iter on_line [ "worktree /tmp/remote-dev"; "branch refs/heads/main" ];
    Effect.Deep.continue k (Unix.WEXITED 0)

let with_http
    (handle :
      Remote_dev.Runtime.http_request -> Remote_dev.Runtime.http_response) f =
  try f ()
  with effect Remote_dev.Runtime.Http_request request, k ->
    Effect.Deep.continue k (handle request)

let with_http_failure f =
  try f ()
  with effect Remote_dev.Runtime.Http_request _, k ->
    Effect.Deep.discontinue k (Failure "offline")

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

let capture_stdout f =
  let path = Filename.temp_file "remote-dev-log-" "" in
  let saved = Unix.dup Unix.stdout in
  let output = open_out path in
  flush stdout;
  Fun.protect
    ~finally:(fun () ->
      flush stdout;
      Unix.dup2 saved Unix.stdout;
      Unix.close saved;
      close_out output;
      Sys.remove path)
    (fun () ->
      Unix.dup2 (Unix.descr_of_out_channel output) Unix.stdout;
      let result = f () in
      let log = In_channel.with_open_bin path In_channel.input_all in
      (result, log))

module Todo = struct
  type event = Submit

  let encode = function Submit -> `Assoc [ ("type", `String "todo") ]
end

module App = struct
  type event = Todo of Todo.event

  let encode = function Todo event -> Todo.encode event
end

let () =
  let module Server = Remote_dev.Server in
  let module Home = Remote_dev.Home in
  let module Tabs = Home_components.Project_tabs in
  let root = Filename.temp_dir "remote-dev-tabs-http-" "" in
  let project = Filename.concat root "project" in
  let environment = Remote_dev.Runtime.OpenCode { root } in
  let rec contains key value = function
    | `Assoc fields ->
        List.assoc_opt key fields = Some value
        || List.exists (fun (_, v) -> contains key value v) fields
    | `List values -> List.exists (contains key value) values
    | _ -> false
  in
  let request message =
    J.to_string
      (`Assoc [ ("event", Home.msg_to_yojson message); ("value", `Null) ])
  in
  let post message =
    Server.response environment ~body:(request message) `POST "/"
  in
  let tabs () =
    match (Atomic.get Server.state).screen with
    | Home.Project_tabs model -> model
    | _ -> assert false
  in
  Fun.protect
    ~finally:(fun () ->
      Unix.rmdir project;
      Unix.rmdir root)
    (fun () ->
      Unix.mkdir project 0o700;
      with_emulator_screenshot ~available:true (fun () ->
          Server.initialize environment);
      let status, body, media = Server.response environment `GET "/" in
      assert (status = `OK && media = "application/json");
      let initial = J.from_string body in
      assert (
        contains "event"
          (Home.msg_to_yojson (Home.Project_tabs_msg Tabs.Create))
          initial);
      assert (not (contains "text" (`String "Directories") initial));
      assert ((tabs ()).tabs = [] && (tabs ()).directories.entries = []);
      ignore
        (post
           (Home.Emulator_msg (Home_components.Emulator.Select "emulator-5554")));
      let emulator = (Atomic.get Server.state).emulator in
      let status, body, media = post (Home.Project_tabs_msg Tabs.Create) in
      assert (status = `OK && media = "application/x-ndjson");
      let documents =
        String.split_on_char '\n' body
        |> List.filter (( <> ) "")
        |> List.map J.from_string
      in
      assert (List.length documents = 2);
      let loaded = List.nth documents 1 in
      assert (contains "text" (`String root) loaded);
      assert (contains "label" (`String "project") loaded);
      assert ((tabs ()).directories.entries = [ "project" ]);
      assert (
        contains "event"
          (Home.msg_to_yojson (Home.Project_tabs_msg (Tabs.Select 1)))
          loaded);
      assert (
        contains "event"
          (Home.msg_to_yojson (Home.Project_tabs_msg (Tabs.Close 1)))
          loaded);
      let click =
        Home.Project_tabs_msg
          (Tabs.Directories_msg (Home_components.Directories.Click project))
      in
      assert (contains "event" (Home.msg_to_yojson click) loaded);
      let before = Atomic.get Server.state in
      let (_, _, _), log = capture_stdout (fun () -> post click) in
      assert (
        log = Printf.sprintf "Directory clicked: %S\n" project
        && Atomic.get Server.state = before);
      let status, _, _ =
        post
          (Home.Project_tabs_msg
             (Tabs.Directories_msg
                (Home_components.Directories.Loaded (Ok [ "forged" ]))))
      in
      assert (status = `Bad_request && Atomic.get Server.state = before);
      List.iter
        (fun message ->
          ignore (post message);
          assert (Atomic.get Server.state = before))
        [
          Home.Session_msg (Home_components.Session.Run_prompt "stale");
          Home.Session_msg (Home_components.Session.Run_prompt "/review");
          Home.Worktree_msg (Home_components.Worktree.Run_prompt "stale");
        ];
      ignore (post (Home.Project_tabs_msg Tabs.Create));
      ignore (post (Home.Project_tabs_msg (Tabs.Select 1)));
      let before = Atomic.get Server.state in
      ignore (Server.response environment `GET "/");
      ignore (post Home.Refresh);
      assert (Atomic.get Server.state = before && (tabs ()).active = Some 1);
      ignore (post (Home.Project_tabs_msg (Tabs.Close 1)));
      assert ((tabs ()).tabs = [ 2 ] && (tabs ()).active = Some 2);
      ignore (post (Home.Project_tabs_msg (Tabs.Close 2)));
      let status, body, media = post Home.Refresh in
      assert (status = `OK && media = "application/json");
      assert (not (contains "text" (`String "Directories") (J.from_string body)));
      assert ((Atomic.get Server.state).emulator = emulator);
      ignore (post (Home.Project_tabs_msg Tabs.Create));
      assert ((tabs ()).tabs = [ 3 ]);
      with_emulator_screenshot ~available:false (fun () ->
          Server.initialize environment);
      assert ((tabs ()).tabs = [] && (tabs ()).active = None))

let () =
  let module Home = Remote_dev.Home in
  let module Tabs = Home_components.Project_tabs in
  let environment =
    Remote_dev.Runtime.OpenCode { root = "/missing-tab-root" }
  in
  let initial, command = Home.init environment in
  assert (
    match initial.screen with
    | Home.Project_tabs { tabs = []; active = None; _ } -> true
    | _ -> false);
  let message =
    with_emulator_screenshot ~available:true (fun () ->
        Cmd.run command |> Option.get)
  in
  let initialized, command = Home.update environment initial message in
  assert (Cmd.run command = None);
  assert (List.length initialized.emulator.emulators = 1);
  let selected, _ =
    Home.update environment initialized
      (Home.Emulator_msg (Home_components.Emulator.Select "emulator-5554"))
  in
  List.iter
    (fun message ->
      let next, cmd = Home.update environment selected message in
      assert (next = selected && Cmd.run cmd = None))
    [ Home.Back; Home.Refresh ];
  let created, command =
    Home.update environment selected (Home.Project_tabs_msg Tabs.Create)
  in
  assert (created.emulator = selected.emulator);
  let loaded, _ =
    Home.update environment created (Cmd.run command |> Option.get)
  in
  assert (
    match loaded.screen with
    | Home.Project_tabs
        {
          tabs = [ 1 ];
          active = Some 1;
          directories = { error = Some _; _ };
          _;
        } ->
        true
    | _ -> false);
  let back, cmd = Home.update environment loaded Home.Back in
  assert (back = loaded && Cmd.run cmd = None);
  let refreshed, command = Home.update environment loaded Home.Refresh in
  let refreshed, _ =
    Home.update environment refreshed (Cmd.run command |> Option.get)
  in
  assert (refreshed.emulator = selected.emulator);
  let deleted, command =
    Home.update environment refreshed (Home.Project_tabs_msg (Tabs.Close 1))
  in
  assert (deleted.emulator = selected.emulator && Cmd.run command = None);
  assert (
    match deleted.screen with
    | Home.Project_tabs { tabs = []; active = None; _ } -> true
    | _ -> false)

let () =
  let module Tabs = Home_components.Project_tabs in
  let initial, cmd = Tabs.init "/missing-project-root" in
  assert (initial.tabs = [] && initial.active = None && Cmd.run cmd = None);
  let step model message = Tabs.update model message |> fst in
  let one = step initial Tabs.Create in
  assert (one.tabs = [ 1 ] && one.active = Some 1);
  let two = step one Tabs.Create in
  let three = step two Tabs.Create in
  assert (three.tabs = [ 1; 2; 3 ] && three.active = Some 3);
  let selected = step three (Tabs.Select 2) in
  assert (selected.tabs = [ 1; 2; 3 ] && selected.active = Some 2);
  let inactive_deleted = step selected (Tabs.Close 1) in
  assert (inactive_deleted.tabs = [ 2; 3 ] && inactive_deleted.active = Some 2);
  let middle_deleted = step selected (Tabs.Close 2) in
  assert (middle_deleted.tabs = [ 1; 3 ] && middle_deleted.active = Some 3);
  let last_deleted = step middle_deleted (Tabs.Close 3) in
  assert (last_deleted.tabs = [ 1 ] && last_deleted.active = Some 1);
  let empty = step last_deleted (Tabs.Close 1) in
  assert (empty.tabs = [] && empty.active = None);
  let recreated = step empty Tabs.Create in
  assert (recreated.tabs = [ 4 ] && recreated.active = Some 4);
  assert (step recreated (Tabs.Select 2) = recreated);
  assert (step recreated (Tabs.Close 2) = recreated)

let () =
  let module Tabs = Home_components.Project_tabs in
  let root = Filename.temp_dir "remote-dev-tabs-" "" in
  let path = Filename.concat root "project" in
  Fun.protect
    ~finally:(fun () ->
      if Sys.file_exists path then Unix.rmdir path;
      if Sys.file_exists root then Unix.rmdir root)
    (fun () ->
      Unix.mkdir path 0o700;
      let empty, _ = Tabs.init root in
      assert (Cmd.run (snd (Tabs.update empty Tabs.Refresh)) = None);
      let first, load = Tabs.update empty Tabs.Create in
      let loaded = Tabs.update first (Option.get (Cmd.run load)) |> fst in
      assert (loaded.directories.entries = [ "project" ]);
      let two, cmd = Tabs.update loaded Tabs.Create in
      assert (Cmd.run cmd = None);
      let selected, cmd = Tabs.update two (Tabs.Select 1) in
      assert (Cmd.run cmd = None && selected.directories = loaded.directories);
      let (clicked, cmd), log =
        capture_stdout (fun () ->
            Tabs.update selected
              (Tabs.Directories_msg (Home_components.Directories.Click path)))
      in
      assert (clicked = selected && log = "");
      let result, log = capture_stdout (fun () -> Cmd.run cmd) in
      assert (
        result = None && log = Printf.sprintf "Directory clicked: %S\n" path);
      Unix.rmdir path;
      Unix.rmdir root;
      let refreshing, cmd = Tabs.update selected Tabs.Refresh in
      let failed = Tabs.update refreshing (Option.get (Cmd.run cmd)) |> fst in
      assert (failed.tabs = [ 1; 2 ] && failed.active = Some 1);
      assert (
        failed.directories.entries = [ "project" ]
        && Option.is_some failed.directories.error);
      Unix.mkdir root 0o700;
      let retrying, cmd = Tabs.update failed Tabs.Refresh in
      let recovered = Tabs.update retrying (Option.get (Cmd.run cmd)) |> fst in
      assert (
        recovered.directories.entries = [] && recovered.directories.error = None);
      let switched, cmd = Tabs.update recovered (Tabs.Select 2) in
      assert (Cmd.run cmd = None && switched.directories = recovered.directories);
      let empty = Tabs.update switched (Tabs.Close 1) |> fst in
      let empty = Tabs.update empty (Tabs.Close 2) |> fst in
      Unix.rmdir root;
      let created, cmd = Tabs.update empty Tabs.Create in
      let failed = Tabs.update created (Option.get (Cmd.run cmd)) |> fst in
      assert (failed.active = Some 3 && Option.is_some failed.directories.error))

let () =
  let open Remote_dev.Components in
  let scroll =
    row ~horizontal_scroll:true [ button ~event:1 "Tab 1" ]
    |> map string_of_int
    |> to_json (fun value -> `String value)
  in
  assert (J.Util.member "horizontalScroll" scroll = `Bool true);
  assert (
    J.Util.member "children" scroll
    |> J.Util.to_list |> List.hd |> J.Util.member "event" = `String "1");
  assert (J.Util.member "horizontalScroll" (to_json Fun.id (row [])) = `Null);
  assert (
    try
      ignore (row ~horizontal_scroll:true ~weights:[] []);
      false
    with Invalid_argument _ -> true)

let () =
  let module Tabs = Home_components.Project_tabs in
  let json model =
    Tabs.view model |> Remote_dev.Components.to_json Tabs.msg_to_yojson
  in
  let children node = J.Util.member "children" node |> J.Util.to_list in
  let initial, _ = Tabs.init "/projects" in
  let empty = json initial in
  let strip = children empty |> List.hd in
  let viewport, add =
    match children strip with
    | [ viewport; add ] -> (viewport, add)
    | _ -> assert false
  in
  assert (J.Util.member "weights" strip = `List [ `Int 1; `Int 0 ]);
  assert (J.Util.member "horizontalScroll" viewport = `Bool true);
  assert (children viewport = []);
  assert (J.Util.member "label" add = `String "+");
  assert (J.Util.member "event" add = Tabs.msg_to_yojson Tabs.Create);
  assert (List.length (children empty) = 1);
  let first = Tabs.update initial Tabs.Create |> fst in
  let second = Tabs.update first Tabs.Create |> fst in
  let document = json second in
  let strip = children document |> List.hd in
  let tabs = children strip |> List.hd |> children in
  assert (List.length tabs = 2);
  List.iteri
    (fun index tab ->
      let id = index + 1 in
      match children tab with
      | [ select; close ] ->
          assert (
            J.Util.member "event" select = Tabs.msg_to_yojson (Tabs.Select id));
          assert (
            J.Util.member "event" close = Tabs.msg_to_yojson (Tabs.Close id))
      | _ -> assert false)
    tabs;
  assert (
    J.Util.member "background" (List.nth tabs 1) = `String "primaryContainer");
  assert (List.length (children document) = 2);
  let closed = Tabs.update second (Tabs.Close 2) |> fst in
  let closed = Tabs.update closed (Tabs.Close 1) |> fst in
  assert (List.length (children (json closed)) = 1)

let () =
  assert (
    let open Remote_dev.Components in
    column [ row [ voice_input ~event:() ] ]
    |> map (fun () -> `List [ `String "Voice" ])
    |> to_json Fun.id
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
                              ("@type", `String "voice_input");
                              ("event", `List [ `String "Voice" ]);
                            ];
                        ] );
                  ];
              ] );
        ]);
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
  let rec find_weighted_column weights = function
    | `Assoc fields ->
        if
          List.assoc_opt "@type" fields = Some (`String "column")
          && List.assoc_opt "weights" fields = Some weights
        then
          match List.assoc_opt "children" fields with
          | Some (`List children) -> Some children
          | _ -> None
        else
          List.find_map
            (fun (_, value) -> find_weighted_column weights value)
            fields
    | `List values -> List.find_map (find_weighted_column weights) values
    | _ -> None
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
            assert (
              List.assoc_opt "gap" fields
              = Some
                  (`Assoc
                     [ ("size", `Int 1); ("color", `String "outlineVariant") ]));
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
                    ~label:"Pixel" ();
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
         (Remote_dev.Components.column ~stretch:true ~weights:[ 0; 1 ]
            [
              Remote_dev.Components.button ~event:Todo.Submit "Button";
              Remote_dev.Components.text "Output";
            ]))
    = `Assoc
        [
          ("@type", `String "column");
          ( "children",
            `List
              [
                `Assoc
                  [
                    ("@type", `String "button");
                    ("label", `String "Button");
                    ("event", `Assoc [ ("type", `String "todo") ]);
                  ];
                `Assoc [ ("@type", `String "text"); ("text", `String "Output") ];
              ] );
          ("stretch", `Bool true);
          ("weights", `List [ `Int 0; `Int 1 ]);
        ]);
  let () =
    let open Remote_dev.Components in
    List.iter
      (fun (background, name) ->
        let tree =
          column ~stretch:true ~weights:[ 1 ] ~background
            [ row ~weights:[ 1 ] ~background [ button ~event:1 "Go" ] ]
        in
        let json = tree |> map succ |> to_json (fun n -> `Int n) in
        let open Yojson.Basic.Util in
        let nested = json |> member "children" |> to_list |> List.hd in
        assert (json |> member "background" = `String name);
        assert (json |> member "stretch" = `Bool true);
        assert (json |> member "weights" = `List [ `Int 1 ]);
        assert (nested |> member "background" = `String name);
        assert (nested |> member "weights" = `List [ `Int 1 ]);
        assert (
          nested |> member "children" |> to_list |> List.hd |> member "event"
          = `Int 2))
      [
        (Background, "background");
        (Surface, "surface");
        (Surface_container, "surfaceContainer");
        (Primary, "primary");
        (Primary_container, "primaryContainer");
        (Outline_variant, "outlineVariant");
      ];
    List.iter
      (fun node ->
        match to_json (fun n -> `Int n) node with
        | `Assoc fields -> assert (not (List.mem_assoc "background" fields))
        | _ -> assert false)
      [ column []; row [] ]
  in
  let () =
    let open Remote_dev.Components in
    assert (
      Padding.all 12 = Padding.only ~start:12 ~top:12 ~end_:12 ~bottom:12 ());
    assert (
      Padding.symmetric ~horizontal:16 ~vertical:8
      = Padding.only ~start:16 ~top:8 ~end_:16 ~bottom:8 ());
    assert (
      Padding.only ~top:8 ~bottom:16 ()
      = { Padding.start = 0; top = 8; end_ = 0; bottom = 16 });
    assert ((Gap.make 2147483647).size = 2147483647);
    List.iter
      (fun value ->
        List.iter
          (fun make ->
            match make () with
            | () -> assert false
            | exception Invalid_argument _ -> ())
          [
            (fun () -> ignore (Padding.all value));
            (fun () -> ignore (Padding.symmetric ~horizontal:0 ~vertical:value));
            (fun () -> ignore (Padding.only ~start:value ()));
            (fun () -> ignore (Padding.only ~top:value ()));
            (fun () -> ignore (Padding.only ~end_:value ()));
            (fun () -> ignore (Padding.only ~bottom:value ()));
            (fun () -> ignore (Gap.make value));
            (fun () -> ignore (Border.make ~color:Primary value));
            (fun () -> ignore (row ~corner_radius:value []));
            (fun () -> ignore (column ~corner_radius:value []));
          ])
      [ -1; 2147483648 ];
    let open Yojson.Basic.Util in
    List.iter
      (fun (color, name) ->
        let padding = Padding.only ~top:8 ~bottom:16 () in
        let gap = Gap.make ~color 8 in
        let border = Border.make ~color 2 in
        let json =
          column ~stretch:true ~weights:[ 1 ] ~background:Surface ~padding ~gap
            ~border ~corner_radius:12
            [
              row ~weights:[ 1 ] ~background:Surface ~padding ~gap ~border
                ~corner_radius:12
                [ button ~event:1 "Go" ];
            ]
          |> Remote_dev.Components.map succ
          |> to_json (fun n -> `Int n)
        in
        let nested = json |> member "children" |> to_list |> List.hd in
        List.iter
          (fun node ->
            assert (
              node |> member "padding"
              = `Assoc
                  [
                    ("start", `Int 0);
                    ("top", `Int 8);
                    ("end", `Int 0);
                    ("bottom", `Int 16);
                  ]);
            assert (
              node |> member "gap"
              = `Assoc [ ("size", `Int 8); ("color", `String name) ]);
            assert (node |> member "background" = `String "surface");
            assert (
              node |> member "border"
              = `Assoc [ ("width", `Int 2); ("color", `String name) ]);
            assert (node |> member "cornerRadius" = `Int 12);
            assert (node |> member "weights" = `List [ `Int 1 ]))
          [ json; nested ];
        assert (json |> member "stretch" = `Bool true);
        assert (
          nested |> member "children" |> to_list |> List.hd |> member "event"
          = `Int 2))
      [
        (Background, "background");
        (Surface, "surface");
        (Surface_container, "surfaceContainer");
        (Primary, "primary");
        (Primary_container, "primaryContainer");
        (Outline_variant, "outlineVariant");
      ];
    List.iter
      (fun node ->
        let json = to_json (fun () -> `Null) node in
        assert (json |> member "gap" = `Assoc [ ("size", `Int 0) ]);
        assert (
          json |> member "padding"
          = `Assoc
              [
                ("start", `Int 0);
                ("top", `Int 0);
                ("end", `Int 0);
                ("bottom", `Int 0);
              ]))
      [
        row ~padding:(Padding.all 0) ~gap:(Gap.make 0) [];
        column ~padding:(Padding.all 0) ~gap:(Gap.make 0) [];
      ];
    List.iter
      (fun node ->
        match to_json (fun () -> `Null) node with
        | `Assoc fields ->
            assert (not (List.mem_assoc "padding" fields));
            assert (not (List.mem_assoc "gap" fields))
        | _ -> assert false)
      [ row []; column [] ]
  in
  let () =
    let open Remote_dev.Components in
    let open Yojson.Basic.Util in
    List.iter
      (fun make ->
        List.iter
          (fun radius ->
            List.iter
              (fun border ->
                let json =
                  make border radius
                  |> Remote_dev.Components.map succ
                  |> to_json (fun n -> `Int n)
                in
                assert (
                  json |> member "cornerRadius"
                  = match radius with None -> `Null | Some n -> `Int n);
                assert (
                  json |> member "border"
                  =
                  match border with
                  | None -> `Null
                  | Some (b : Border.t) ->
                      `Assoc
                        [
                          ("width", `Int b.width); ("color", `String "primary");
                        ]))
              [
                None;
                Some (Border.make ~color:Primary 0);
                Some (Border.make ~color:Primary 2147483647);
              ])
          [ None; Some 0; Some 2147483647 ])
      [
        (fun border corner_radius -> row ?border ?corner_radius []);
        (fun border corner_radius -> column ?border ?corner_radius []);
      ]
  in
  let image_event = `List [ `String "Tap" ] in
  assert (
    Remote_dev.Components.image ~event:() ~src:"/preview.png" ~label:"Pixel" ()
    |> Remote_dev.Components.map (fun () -> image_event)
    |> Remote_dev.Components.to_json Fun.id
    = `Assoc
        [
          ("@type", `String "image");
          ("src", `String "/preview.png");
          ("label", `String "Pixel");
          ("event", image_event);
        ]);
  let children = [ Remote_dev.Components.text "Default" ] in
  assert (
    Remote_dev.Components.to_json App.encode
      (Remote_dev.Components.column ~stretch:false children)
    = Remote_dev.Components.to_json App.encode
        (Remote_dev.Components.column children));
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
    Home_components.Worktrees.init "/tmp/remote-dev-root" |> fst
  in
  let initial_worktree path = Home_components.Worktree.init path |> fst in
  let initial_directories =
    Home_components.Directories.init "/tmp/remote-dev-root" |> fst
  in
  let directories_document ?(environment = claude_environment)
      ?(emulator = initial_emulator) model =
    Remote_dev.Server.to_json environment
      { screen = Remote_dev.Home.Directories model; emulator }
  in
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
        let fields =
          match right with `Assoc fields -> fields | _ -> assert false
        in
        assert (List.assoc "background" fields = `String "surface");
        assert (List.assoc "weights" fields = `List [ `Int 0; `Int 0 ]);
        assert (
          has_event
            (home_event
               (Remote_dev.Home.Emulator_msg Home_components.Emulator.Refresh))
            right);
        check_right right
    | None -> assert false
  in
  let module Directories = Home_components.Directories in
  let root = Filename.temp_dir "remote-dev-ui-" "" |> Unix.realpath in
  let cwd = Sys.getcwd () in
  Fun.protect
    ~finally:(fun () ->
      Sys.chdir cwd;
      Sys.readdir root
      |> Array.iter (fun name -> Unix.rmdir (Filename.concat root name));
      Unix.rmdir root)
    (fun () ->
      let dir = "example\nquoted\"" in
      let path = Filename.concat root dir in
      let model, load = Directories.init root in
      assert (Cmd.run load = Some (Directories.Loaded (Ok [])));
      assert (has_text "No subdirectories" (directories_document model));
      Unix.mkdir path 0o700;
      let loaded, _ = Directories.update model (Option.get (Cmd.run load)) in
      assert (loaded.entries = [ dir ]);
      let failed, _ =
        Directories.update loaded (Directories.Loaded (Error "failed"))
      in
      assert (failed.entries = loaded.entries);
      let initial_failure, _ =
        Directories.update model (Directories.Loaded (Error "failed"))
      in
      let failure_document = directories_document initial_failure in
      assert (has_text "Error: failed" failure_document);
      assert (not (has_text "No subdirectories" failure_document));
      let _, retry = Directories.update failed Directories.Load in
      let recovered, _ =
        Directories.update failed (Option.get (Cmd.run retry))
      in
      assert (recovered = loaded);
      let (clicked, command), log =
        capture_stdout (fun () ->
            Directories.update failed (Directories.Click path))
      in
      assert (log = "");
      assert (clicked = failed);
      let (), log =
        capture_stdout (fun () ->
            assert (Cmd.run command = None);
            assert (Cmd.run command = None))
      in
      let line = Printf.sprintf "Directory clicked: %S\n" path in
      assert (log = line ^ line);
      List.iter
        (fun agent ->
          Sys.chdir (Filename.dirname root);
          let environment =
            Remote_dev.Runtime.parse_args
              [| "remote_dev"; "--agent"; agent; Filename.basename root |]
          in
          Sys.chdir cwd;
          let initial, _ = Remote_dev.Home.init environment in
          assert (initial.screen = Remote_dev.Home.Directories model);
          with_emulator_screenshot ~available:false (fun () ->
              Remote_dev.Server.initialize environment);
          let started = Atomic.get Remote_dev.Server.state in
          assert (started.screen = Remote_dev.Home.Directories loaded);
          let status, body, content_type =
            Remote_dev.Server.response environment `GET "/"
          in
          assert (status = `OK && content_type = "application/json");
          let document = J.from_string body in
          assert_root_split document "Directories" (fun _ -> ());
          assert (has_text root document);
          assert (
            not
              (has_text "Worktrees:" document
              || has_text "OpenCode sessions:" document));
          let click =
            Remote_dev.Home.Directories_msg (Directories.Click path)
          in
          assert (has_event (home_event click) document);
          let before = { started with emulator = selected_emulator } in
          Atomic.set Remote_dev.Server.state before;
          let (status, body, _), log =
            capture_stdout (fun () ->
                Remote_dev.Server.response environment
                  ~body:(request_body click) `POST "/")
          in
          assert (status = `OK && log = line);
          assert (
            stream_documents body
            = [ Remote_dev.Server.to_json environment before ]);
          assert (Atomic.get Remote_dev.Server.state = before);
          List.iter
            (fun message ->
              ignore
                (Remote_dev.Server.response environment
                   ~body:(request_body message) `POST "/");
              assert (Atomic.get Remote_dev.Server.state = before))
            [
              Remote_dev.Home.Back;
              Remote_dev.Home.Worktree_msg
                (Home_components.Worktree.Run_prompt "stale");
              Remote_dev.Home.Session_msg
                (Home_components.Session.Run_prompt "stale");
              Remote_dev.Home.Session_msg
                (Home_components.Session.Run_prompt "/review");
            ];
          assert (
            Remote_dev.Server.start_prompt_stream environment
              (request_body
                 (Remote_dev.Home.Worktree_msg
                    (Home_components.Worktree.Run_prompt "stale")))
            = None);
          assert (
            Remote_dev.Server.start_opencode_command environment
              (request_body
                 (Remote_dev.Home.Session_msg
                    (Home_components.Session.Run_prompt "/review")))
            = None);
          let status, _, _ =
            Remote_dev.Server.response environment
              ~body:
                (request_body
                   (Remote_dev.Home.Directories_msg
                      (Directories.Loaded (Ok [ "forged" ]))))
              `POST "/"
          in
          assert (status = `Bad_request);
          with_emulator_screenshot ~available:false (fun () ->
              ignore
                (Remote_dev.Server.response environment
                   ~body:
                     (request_body
                        (Remote_dev.Home.Emulator_msg
                           Home_components.Emulator.Refresh))
                   `POST "/"));
          assert ((Atomic.get Remote_dev.Server.state).screen = before.screen);
          Atomic.set Remote_dev.Server.state before;
          Sys.chdir cwd;
          Unix.rmdir path;
          let status, body, content_type =
            Remote_dev.Server.response environment
              ~body:(request_body Remote_dev.Home.Refresh)
              `POST "/"
          in
          assert (status = `OK && content_type = "application/x-ndjson");
          assert (List.length (stream_documents body) = 2);
          let refreshed = Atomic.get Remote_dev.Server.state in
          assert (refreshed.emulator = before.emulator);
          assert (refreshed.screen = Remote_dev.Home.Directories model);
          Unix.rmdir root;
          ignore
            (Remote_dev.Server.response environment
               ~body:(request_body Remote_dev.Home.Refresh)
               `POST "/");
          (match (Atomic.get Remote_dev.Server.state).screen with
          | Remote_dev.Home.Directories { error = Some _; entries = []; _ } ->
              ()
          | _ -> assert false);
          with_emulator_screenshot ~available:false (fun () ->
              Remote_dev.Server.initialize environment);
          let status, body, _ =
            Remote_dev.Server.response environment `GET "/"
          in
          assert (status = `OK);
          assert (has_text root (J.from_string body));
          assert (not (has_text "No subdirectories" (J.from_string body)));
          (match (Atomic.get Remote_dev.Server.state).screen with
          | Remote_dev.Home.Directories
              { root = actual; error = Some _; entries = [] } ->
              assert (actual = root)
          | _ -> assert false);
          Unix.mkdir root 0o700;
          Unix.mkdir path 0o700;
          ignore
            (Remote_dev.Server.response environment
               ~body:(request_body Remote_dev.Home.Refresh)
               `POST "/");
          assert ((Atomic.get Remote_dev.Server.state).screen = before.screen))
        [ "claude" ]);
  let listed_worktree =
    {
      Home_components.Worktrees.worktrees =
        [ { path = "/tmp/clicked"; branch = "main" } ];
      error = None;
    }
  in
  List.iter
    (fun (emulator, message) ->
      assert_root_split (worktrees_document ~emulator listed_worktree)
        "Worktrees:" (fun right -> assert (has_text message right)))
    [
      (initial_emulator, "No running emulators");
      ({ selected_emulator with selected_emulator = None }, "Select an emulator");
      ({ selected_emulator with error = Some "failed" }, "Error: failed");
    ];
  (match
     find_weighted_column
       (`List [ `Int 0; `Int 0; `Int 0; `Int 1 ])
       (worktrees_document listed_worktree)
   with
  | Some [ errors; heading; creation; worktrees ] ->
      assert (not (has_text "Error: failed" errors));
      assert (has_text "Worktrees:" heading);
      assert (has_text "/tmp/clicked" worktrees);
      assert (
        has_event
          (home_event
             (Remote_dev.Home.Worktrees_msg
                Home_components.Worktrees.Open_creation))
          creation)
  | _ -> assert false);
  assert_root_split
    (worktrees_document ~emulator:selected_emulator listed_worktree)
    "Worktrees:" (fun right ->
      assert (has_image "/emulators/emulator-5554/screenshot.png" right));
  assert_root_split
    (creation_document ~emulator:selected_emulator listed_worktree)
    "New worktree" (fun right ->
      assert (has_image "/emulators/emulator-5554/screenshot.png" right));
  let worktree = initial_worktree "/tmp/clicked" in
  let rec has_button_column buttons = function
    | Remote_dev.Components.Column (stretch, _, _, _, _, _, _, children) ->
        (stretch && children = buttons)
        || List.exists (has_button_column buttons) children
    | Remote_dev.Components.Row (_, _, _, _, _, _, _, children) ->
        List.exists (has_button_column buttons) children
    | _ -> false
  in
  assert (
    has_button_column
      (List.map
         (fun label ->
           Remote_dev.Components.button
             ~event:(Home_components.Worktree.Set_prompt label) label)
         [ "/igor-pending-reviews"; "/igor-restart-mr-tests" ])
      (Home_components.Worktree.view worktree));
  let voiced, cmd =
    Home_components.Worktree.update worktree
      (Home_components.Worktree.Set_prompt "voice")
  in
  assert (voiced.prompt = "voice" && Cmd.run cmd = None);
  let assert_voice_row label value set_prompt view =
    let open Remote_dev.Components in
    match view with
    | Column (_, _, _, _, _, _, _, children) ->
        assert (
          List.exists
            (function
              | Row
                  ( _,
                    Some [ 1; 0 ],
                    _,
                    _,
                    _,
                    _,
                    _,
                    [ Edit (name, Some text, _); Voice_input event ] ) ->
                  name = label && text = value && event = set_prompt
              | _ -> false)
            children)
    | _ -> assert false
  in
  assert_voice_row "Commands" "voice"
    (Home_components.Worktree.Set_prompt "__VALUE__")
    (Home_components.Worktree.view voiced);
  let assert_worktree_layout ?output ?error ~shortcuts document =
    match
      find_weighted_column
        (`List [ `Int 0; `Int 0; `Int 0; `Int 1; `Int 0; `Int 0 ])
        document
    with
    | Some [ errors; heading; path; messages; shortcut_buttons; input ] ->
        assert (has_text "Worktree" heading);
        assert (has_text "/tmp/clicked" path);
        assert (
          has_event
            (home_event
               (Remote_dev.Home.Worktree_msg
                  (Home_components.Worktree.Run_prompt "__VALUE__")))
            input);
        Option.iter (fun value -> assert (has_text value messages)) output;
        Option.iter
          (fun value -> assert (has_text ("Error: " ^ value) errors))
          error;
        assert (
          shortcuts
          = has_event
              (home_event
                 (Remote_dev.Home.Worktree_msg
                    (Home_components.Worktree.Set_prompt "/igor-pending-reviews")))
              shortcut_buttons)
    | _ -> assert false
  in
  assert_worktree_layout ~shortcuts:true (worktree_document worktree);
  assert_worktree_layout ~output:"long output" ~shortcuts:true
    (worktree_document { worktree with output = Some "long output" });
  assert_worktree_layout ~error:"failed" ~shortcuts:true
    (worktree_document { worktree with error = Some "failed" });
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
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Worktree_msg
            (Home_components.Worktree.Run_prompt "__VALUE__")))
      (worktree_document worktree));
  let idle_session : Remote_dev.Runtime.opencode_session =
    {
      id = "idle";
      title = "Idle session";
      directory = "/tmp/idle";
      workspace = None;
      agent = Some "build";
      model = Some ("anthropic", "claude", None);
      status = Idle;
    }
  in
  let busy_session : Remote_dev.Runtime.opencode_session =
    {
      id = "busy";
      title = "Busy session";
      directory = "/tmp/busy";
      workspace = None;
      agent = Some "build";
      model = Some ("anthropic", "claude", None);
      status = Busy;
    }
  in
  let retry_session : Remote_dev.Runtime.opencode_session =
    {
      id = "retry";
      title = "Retry session";
      directory = "/tmp/retry";
      workspace = None;
      agent = Some "build";
      model = Some ("anthropic", "claude", None);
      status = Retry "backoff";
    }
  in
  let sessions_model : Home_components.Sessions.model =
    { sessions = [ idle_session; busy_session; retry_session ]; error = None }
  in
  let sessions_home =
    {
      Remote_dev.Home.screen = Remote_dev.Home.Sessions sessions_model;
      emulator = initial_emulator;
    }
  in
  let sessions_document =
    Remote_dev.Server.to_json opencode_environment sessions_home
  in
  assert (has_text "Agent: OpenCode" sessions_document);
  assert (has_text "Status: idle" sessions_document);
  assert (has_text "Status: busy" sessions_document);
  assert (has_text "Status: retry: backoff" sessions_document);
  assert (not (has_text "Worktrees:" sessions_document));
  assert (not (has_text "New worktree" sessions_document));
  assert (
    has_event
      (home_event
         (Remote_dev.Home.Sessions_msg (Home_components.Sessions.Select "busy")))
      sessions_document);
  let empty_sessions =
    Remote_dev.Server.to_json opencode_environment
      {
        Remote_dev.Home.screen =
          Remote_dev.Home.Sessions { sessions = []; error = None };
        emulator = initial_emulator;
      }
  in
  assert (has_text "No OpenCode sessions" empty_sessions);
  let failed_sessions, cmd =
    Home_components.Sessions.update sessions_model
      (Home_components.Sessions.Loaded (Error "offline"))
  in
  assert (Cmd.run cmd = None);
  assert (failed_sessions.error = Some "offline");
  let selected_home, load =
    Remote_dev.Home.update opencode_environment sessions_home
      (Remote_dev.Home.Sessions_msg (Home_components.Sessions.Select "busy"))
  in
  assert (match load with Cmd.Run _ -> true | Cmd.Empty -> false);
  let selected_model =
    match selected_home.screen with
    | Remote_dev.Home.Session (_, model) -> model
    | _ -> assert false
  in
  let loaded_model =
    {
      selected_model with
      messages =
        [
          { Remote_dev.Runtime.role = User; text = "question" };
          { role = Assistant; text = "answer" };
        ];
      needs_input = true;
    }
  in
  let selected_home =
    {
      selected_home with
      screen = Remote_dev.Home.Session (sessions_model, loaded_model);
    }
  in
  let selected_document =
    Remote_dev.Server.to_json opencode_environment selected_home
  in
  let voiced, cmd =
    Home_components.Session.update loaded_model
      (Home_components.Session.Set_prompt "voice")
  in
  assert (voiced.prompt = "voice" && Cmd.run cmd = None);
  assert_voice_row "Prompt" "voice"
    (Home_components.Session.Set_prompt "__VALUE__")
    (Home_components.Session.view voiced);
  assert (has_text "User: question" selected_document);
  assert (has_text "Assistant: answer" selected_document);
  assert (has_text "Needs input in OpenCode" selected_document);
  assert (
    Option.is_some
      (find_weighted_column
         (`List
            [ `Int 0; `Int 0; `Int 0; `Int 0; `Int 0; `Int 1; `Int 0; `Int 0 ])
         selected_document));
  assert (
    has_event
      (home_event (Remote_dev.Home.Session_msg Home_components.Session.Stop))
      selected_document);
  let retry_document =
    Remote_dev.Server.to_json opencode_environment
      {
        selected_home with
        screen =
          Remote_dev.Home.Session
            ( sessions_model,
              { loaded_model with session = retry_session; needs_input = false }
            );
      }
  in
  assert (has_text "Status: retry: backoff" retry_document);
  assert (
    not
      (has_event
         (home_event (Remote_dev.Home.Session_msg Home_components.Session.Stop))
         retry_document));
  let initial_opencode, _ = Remote_dev.Home.init opencode_environment in
  assert (
    match initial_opencode.screen with
    | Remote_dev.Home.Project_tabs { tabs = []; active = None; _ } -> true
    | _ -> false);
  let listed, cmd =
    Remote_dev.Home.update opencode_environment selected_home
      Remote_dev.Home.Back
  in
  assert (Cmd.run cmd = None);
  assert (listed = sessions_home);
  let _, refresh =
    Remote_dev.Home.update opencode_environment sessions_home
      Remote_dev.Home.Refresh
  in
  assert (match refresh with Cmd.Run _ -> true | Cmd.Empty -> false);
  let _, refresh =
    Remote_dev.Home.update opencode_environment selected_home
      Remote_dev.Home.Refresh
  in
  assert (match refresh with Cmd.Run _ -> true | Cmd.Empty -> false);
  let missing, cmd =
    Remote_dev.Home.update opencode_environment selected_home
      (Remote_dev.Home.Session_msg Home_components.Session.Missing)
  in
  assert (Cmd.run cmd = None);
  assert (
    match missing.screen with
    | Remote_dev.Home.Sessions { error = Some _; _ } -> true
    | _ -> false);
  Atomic.set Remote_dev.Server.state selected_home;
  let prompt_body =
    request_body
      (Remote_dev.Home.Session_msg
         (Home_components.Session.Run_prompt "$(literal); \"quoted\""))
  in
  let status, body, content_type =
    with_http
      (fun (request : Remote_dev.Runtime.http_request) ->
        assert (request.meth = `POST);
        assert (String.ends_with ~suffix:"/prompt_async" request.target);
        assert (String.contains request.body '$');
        { status = 204; body = "" })
      (fun () ->
        Remote_dev.Server.response opencode_environment ~body:prompt_body `POST
          "/")
  in
  assert (status = `OK);
  assert (content_type = "application/json");
  assert (has_text "Busy session" (J.from_string body));
  assert (
    match (Atomic.get Remote_dev.Server.state).screen with
    | Remote_dev.Home.Session (_, { prompt = ""; error = None; _ }) -> true
    | _ -> false);
  Atomic.set Remote_dev.Server.state selected_home;
  let status, body, _ =
    with_http_failure (fun () ->
        Remote_dev.Server.response opencode_environment ~body:prompt_body `POST
          "/")
  in
  assert (status = `OK);
  assert (has_text "Error: Failure(\"offline\")" (J.from_string body));
  Atomic.set Remote_dev.Server.state selected_home;
  let status, body, content_type =
    with_http
      (fun (request : Remote_dev.Runtime.http_request) ->
        if request.meth = `POST then { status = 200; body = "true" }
        else if
          String.starts_with ~prefix:"/session/busy/message" request.target
        then { status = 200; body = "[]" }
        else if String.starts_with ~prefix:"/session/status" request.target then
          { status = 200; body = "{}" }
        else { status = 200; body = "[]" })
      (fun () ->
        Remote_dev.Server.response opencode_environment
          ~body:
            (request_body
               (Remote_dev.Home.Session_msg Home_components.Session.Stop))
          `POST "/")
  in
  assert (status = `OK);
  assert (content_type = "application/x-ndjson");
  assert (List.length (stream_documents body) = 2);
  assert (
    match (Atomic.get Remote_dev.Server.state).screen with
    | Remote_dev.Home.Session (_, { session = { status = Idle; _ }; _ }) -> true
    | _ -> false);
  Atomic.set Remote_dev.Server.state selected_home;
  let command_request =
    match
      Remote_dev.Server.start_opencode_command opencode_environment
        (request_body
           (Remote_dev.Home.Session_msg
              (Home_components.Session.Run_prompt "/review main branch")))
    with
    | Some { session; command; arguments } ->
        assert (session.id = "busy");
        assert (command = "review");
        assert (arguments = "main branch");
        { Remote_dev.Server.session; command; arguments }
    | None -> assert false
  in
  Atomic.set Remote_dev.Server.state selected_home;
  assert (
    Remote_dev.Server.start_opencode_command opencode_environment
      (request_body
         (Remote_dev.Home.Session_msg (Home_components.Session.Run_prompt "/")))
    = None);
  Atomic.set Remote_dev.Server.state selected_home;
  with_http
    (fun (request : Remote_dev.Runtime.http_request) ->
      assert (String.ends_with ~suffix:"/command" request.target);
      assert (not (String.ends_with ~suffix:"/prompt_async" request.target));
      { status = 400; body = "unknown command" })
    (fun () ->
      Remote_dev.Server.complete_opencode_command opencode_environment
        command_request);
  assert (
    match (Atomic.get Remote_dev.Server.state).screen with
    | Remote_dev.Home.Session (_, { background_error = Some error; _ }) ->
        String.contains error '4'
    | _ -> false);
  let status, body, _ =
    with_http
      (fun (request : Remote_dev.Runtime.http_request) ->
        if String.starts_with ~prefix:"/session/busy/message" request.target
        then
          {
            status = 200;
            body =
              "[{\"info\":{\"role\":\"assistant\"},\"parts\":[{\"type\":\"text\",\"text\":\"refreshed\"}]}]";
          }
        else if String.starts_with ~prefix:"/session/status" request.target then
          {
            status = 200;
            body = "{\"busy\":{\"type\":\"retry\",\"message\":\"later\"}}";
          }
        else if String.starts_with ~prefix:"/permission" request.target then
          { status = 200; body = "[{\"sessionID\":\"busy\"}]" }
        else { status = 200; body = "[]" })
      (fun () ->
        Remote_dev.Server.response opencode_environment
          ~body:(request_body Remote_dev.Home.Refresh)
          `POST "/")
  in
  assert (status = `OK);
  let refreshed = stream_documents body |> List.rev |> List.hd in
  assert (has_text "Assistant: refreshed" refreshed);
  assert (has_text "Status: retry: later" refreshed);
  assert (has_text "Needs input in OpenCode" refreshed);
  assert (not (has_text "User: question" refreshed));
  assert (
    refreshed
    |> has_text
         "Error: Failure(\"OpenCode server returned HTTP 400: unknown \
          command\")");
  Atomic.set Remote_dev.Server.state selected_home;
  ignore (Remote_dev.Server.dispatch opencode_environment Remote_dev.Home.Back);
  with_http
    (fun (_ : Remote_dev.Runtime.http_request) ->
      { status = 400; body = "late failure" })
    (fun () ->
      Remote_dev.Server.complete_opencode_command opencode_environment
        command_request);
  assert (
    match (Atomic.get Remote_dev.Server.state).screen with
    | Remote_dev.Home.Sessions { error = None; _ } -> true
    | _ -> false);
  let string_to_yojson value = `String value in
  let string_of_yojson = function
    | `String value -> Ok value
    | _ -> Error "string"
  in
  let result_to_yojson =
    Result_yojson.result_to_yojson string_to_yojson string_to_yojson
  in
  let result_of_yojson =
    Result_yojson.result_of_yojson string_of_yojson string_of_yojson
  in
  assert (
    result_to_yojson (Ok "value") = `List [ `String "Ok"; `String "value" ]);
  assert (
    result_to_yojson (Error "failed")
    = `List [ `String "Error"; `String "failed" ]);
  assert (
    result_of_yojson (`List [ `String "Ok"; `String "value" ]) = Ok (Ok "value"));
  assert (
    result_of_yojson (`List [ `String "Error"; `String "failed" ])
    = Ok (Error "failed"));
  assert (Result.is_error (result_of_yojson (`List [ `String "Other"; `Null ])));
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
  let startup_environment =
    Remote_dev.Runtime.parse_args [| "remote_dev"; "--agent"; "claude" |]
  in
  let initial, cmd = Remote_dev.Home.init startup_environment in
  assert (initial.emulator = initial_emulator);
  assert (
    match initial.screen with
    | Remote_dev.Home.Directories { entries = []; error = None; root } ->
        root = Sys.getcwd ()
    | _ -> false);
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
    Remote_dev.Home.update startup_environment initial initialized
  in
  assert (initialized_state.emulator.selected_emulator = None);
  assert (
    match Cmd.run cmd with
    | Some
        (Remote_dev.Home.Directories_msg
           (Home_components.Directories.Loaded (Ok _))) ->
        true
    | _ -> false);
  let failed_state, cmd =
    Remote_dev.Home.update startup_environment initial
      (Remote_dev.Home.Initialize_emulator
         (Home_components.Emulator.Loaded (Error "adb failed")))
  in
  assert (failed_state.emulator.error = Some "adb failed");
  assert (
    match Cmd.run cmd with
    | Some
        (Remote_dev.Home.Directories_msg
           (Home_components.Directories.Loaded (Ok _))) ->
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
             (Remote_dev.Home.Directories_msg
                (Home_components.Directories.Loaded (Error "failed")))))
    |> stream_documents
  in
  assert (List.length documents = 2);
  assert (
    match (Atomic.get Remote_dev.Server.state).screen with
    | Remote_dev.Home.Directories { error = Some "failed"; _ } -> true
    | _ -> false);
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
  Atomic.set Remote_dev.Server.state
    {
      screen = Remote_dev.Home.Worktrees initial_worktrees;
      emulator = initial_emulator;
    };
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
    | { screen = Remote_dev.Home.Directories model; emulator } ->
        J.from_string body = directories_document ~emulator model
    | _ -> false);
  let status, body, content_type =
    Remote_dev.Server.response claude_environment `GET "/"
  in
  assert (status = `OK);
  assert (content_type = "application/json");
  assert (
    match Atomic.get Remote_dev.Server.state with
    | { screen = Remote_dev.Home.Directories model; emulator } ->
        J.from_string body = directories_document ~emulator model
    | _ -> false);
  let previous = J.from_string body in
  let status, body, content_type =
    Remote_dev.Server.response claude_environment
      ~body:(request_body Remote_dev.Home.Refresh)
      `POST "/"
  in
  assert (status = `OK);
  assert (content_type = "application/x-ndjson");
  let documents = stream_documents body in
  assert (List.length documents = 2);
  assert (List.hd documents = previous);
  assert (
    match Atomic.get Remote_dev.Server.state with
    | { screen = Remote_dev.Home.Directories model; emulator } ->
        List.hd (List.rev documents) = directories_document ~emulator model
    | _ -> false);
  Remote_dev.Server.reset claude_environment;
  with_failed_emulator_load (fun () ->
      Remote_dev.Server.initialize startup_environment);
  assert (
    match Atomic.get Remote_dev.Server.state with
    | {
     screen = Remote_dev.Home.Directories { error = None; _ };
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
  assert (J.from_string body = directories_document initial_directories);
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
  assert (J.from_string body = directories_document initial_directories);
  Remote_dev.Server.reset claude_environment;
  assert (
    match (Atomic.get Remote_dev.Server.state).screen with
    | Remote_dev.Home.Directories _ -> true
    | _ -> false);
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
  assert (emulator.selected_emulator = None);
  let emulator, _ =
    Home_components.Emulator.update emulator
      (Home_components.Emulator.Select "emulator-5554")
  in
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
  assert (empty.selected_emulator = Some "emulator-5554");
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
  assert (failed.emulators = emulator.emulators);
  assert (failed.selected_emulator = emulator.selected_emulator);
  let refreshing, cmd =
    Home_components.Emulator.update failed Home_components.Emulator.Refresh
  in
  assert (refreshing = failed);
  let result =
    with_emulator_screenshot ~available:true (fun () -> Cmd.run cmd)
    |> Option.get
  in
  let retried, _ = Home_components.Emulator.update refreshing result in
  assert (retried.error = None);
  assert (retried.selected_emulator = emulator.selected_emulator);
  let renamed =
    { Remote_dev.Runtime.serial = "emulator-5556"; name = "Renamed" }
  in
  List.iter
    (fun devices ->
      let refreshed, _ =
        Home_components.Emulator.update selected
          (Home_components.Emulator.Loaded (Ok devices))
      in
      assert (refreshed.emulators = devices);
      assert (refreshed.selected_emulator = Some "emulator-5556"))
    [ List.rev emulators; [ renamed ]; [ List.hd emulators ]; []; emulators ];
  let emulator_view model =
    Remote_dev.Components.to_json Home_components.Emulator.msg_to_yojson
      (Home_components.Emulator.view model)
  in
  let unselected = { emulator with selected_emulator = None } in
  let missing = { emulator with emulators = [ List.nth emulators 1 ] } in
  List.iter
    (fun (model, message, image) ->
      let document = emulator_view model in
      assert (
        has_event
          (Home_components.Emulator.msg_to_yojson
             Home_components.Emulator.Refresh)
          document);
      Option.iter (fun message -> assert (has_text message document)) message;
      assert (
        has_image "/emulators/emulator-5554/screenshot.png" document = image))
    [
      (initial_emulator, Some "No running emulators", false);
      (unselected, Some "Select an emulator", false);
      (emulator, None, true);
      (missing, Some "Selected emulator unavailable", false);
      (empty, Some "Selected emulator unavailable", false);
      (failed, Some "Error: failed", true);
    ];
  assert (
    has_event
      (Home_components.Emulator.msg_to_yojson
         (Home_components.Emulator.Select "emulator-5556"))
      (emulator_view missing));
  let replacement, _ =
    Home_components.Emulator.update missing
      (Home_components.Emulator.Select "emulator-5556")
  in
  assert (replacement.selected_emulator = Some "emulator-5556");
  assert (
    has_image "/emulators/emulator-5556/screenshot.png"
      (emulator_view replacement));
  let initialized_worktree, cmd =
    Home_components.Worktree.init "/tmp/clicked"
  in
  assert (initialized_worktree = model);
  assert (Cmd.run cmd = None);
  let home =
    { Remote_dev.Home.screen = Remote_dev.Home.Worktree model; emulator }
  in
  let tap_event =
    Remote_dev.Home.Emulator_msg
      (Home_components.Emulator.Tap ("emulator-5554", "__VALUE__"))
  in
  let tap_payload = {|{"x":540,"y":960,"width":1080,"height":1920}|} in
  let tap_body payload =
    J.to_string
      (`Assoc
         [
           ("event", Remote_dev.Home.msg_to_yojson tap_event);
           ("value", `String payload);
         ])
  in
  assert (
    Remote_dev.Server.decode (tap_body tap_payload)
    = Ok
        (Remote_dev.Home.Emulator_msg
           (Home_components.Emulator.Tap ("emulator-5554", tap_payload))));
  assert (
    has_event
      (Remote_dev.Home.msg_to_yojson tap_event)
      (Remote_dev.Server.to_json claude_environment home));
  Atomic.set Remote_dev.Server.state home;
  let send_tap (status : Unix.process_status) =
    let calls = ref 0 in
    let response =
      try
        Remote_dev.Server.response claude_environment
          ~body:(tap_body tap_payload) `POST "/"
      with effect Remote_dev.Runtime.Process_lines (process, _), k ->
        assert (
          process
          = Remote_dev.Runtime.Args
              ( "adb",
                [|
                  "adb";
                  "-s";
                  "emulator-5554";
                  "shell";
                  "input";
                  "tap";
                  "540";
                  "960";
                |] ));
        incr calls;
        Effect.Deep.continue k status
    in
    assert (!calls = 1);
    let status, body, content_type = response in
    assert (status = `OK && content_type = "application/x-ndjson");
    let documents = stream_documents body in
    assert (List.length documents = 2);
    assert (
      List.for_all
        (has_image "/emulators/emulator-5554/screenshot.png")
        documents);
    let after = Atomic.get Remote_dev.Server.state in
    assert (after.screen = home.screen);
    assert (after.emulator.emulators = home.emulator.emulators);
    assert (after.emulator.selected_emulator = home.emulator.selected_emulator);
    (after, List.nth documents 1)
  in
  let success, _ = send_tap (Unix.WEXITED 0) in
  assert (success = home);
  let failure, document = send_tap (Unix.WEXITED 1) in
  assert (Option.is_some failure.emulator.error);
  assert (has_text ("Error: " ^ Option.get failure.emulator.error) document);
  let retry, _ = send_tap (Unix.WEXITED 0) in
  assert (retry = home);
  List.iter
    (fun payload ->
      Atomic.set Remote_dev.Server.state home;
      let status, _, _ =
        Remote_dev.Server.response claude_environment ~body:(tap_body payload)
          `POST "/"
      in
      assert (status = `OK);
      let after = Atomic.get Remote_dev.Server.state in
      assert (after.screen = home.screen);
      assert (
        after.emulator = { emulator with error = Some "Invalid emulator tap" }))
    [
      "not json";
      "null";
      "{}";
      {|{"x":1.5,"y":0,"width":1080,"height":1920}|};
      {|{"x":"1","y":0,"width":1080,"height":1920}|};
      {|{"x":-1,"y":0,"width":1080,"height":1920}|};
      {|{"x":1080,"y":0,"width":1080,"height":1920}|};
      {|{"x":0,"y":1920,"width":1080,"height":1920}|};
      {|{"x":0,"y":0,"width":0,"height":1920}|};
      {|{"x":0,"y":0,"width":1080,"height":-1}|};
    ];
  List.iter
    (fun emulator ->
      let state = { home with emulator } in
      Atomic.set Remote_dev.Server.state state;
      ignore
        (Remote_dev.Server.response claude_environment
           ~body:(tap_body tap_payload) `POST "/");
      assert (Atomic.get Remote_dev.Server.state = state))
    [ selected; unselected; missing ];
  List.iter
    (fun message ->
      let status, _, _ =
        Remote_dev.Server.response claude_environment
          ~body:(request_body message) `POST "/"
      in
      assert (status = `Bad_request))
    [
      Remote_dev.Home.Emulator_msg (Home_components.Emulator.Tapped (Ok ()));
      Remote_dev.Home.Initialize_emulator
        (Home_components.Emulator.Tapped (Error "forged"));
    ];
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
    | Some { cwd; prompt; session_id } ->
        cwd = "/tmp/clicked" && prompt = "prompt" && session_id = None
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
    | Some { cwd; prompt; session_id } ->
        cwd = "/tmp/clicked" && prompt = "continued"
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
  assert (Atomic.get Remote_dev.Server.state = selected);
  let refresh_event =
    Remote_dev.Home.Emulator_msg Home_components.Emulator.Refresh
  in
  let refresh available =
    let before = Atomic.get Remote_dev.Server.state in
    assert (
      has_event (home_event refresh_event)
        (Remote_dev.Server.to_json claude_environment before));
    let status, body, content_type =
      with_emulator_screenshot ~available (fun () ->
          Remote_dev.Server.response claude_environment
            ~body:(request_body refresh_event)
            `POST "/")
    in
    assert (status = `OK);
    assert (content_type = "application/x-ndjson");
    let documents =
      String.split_on_char '\n' body
      |> List.filter (fun line -> line <> "")
      |> List.map J.from_string
    in
    assert (List.length documents = 2);
    let after = Atomic.get Remote_dev.Server.state in
    assert (after.screen = before.screen);
    assert (after.emulator.selected_emulator = before.emulator.selected_emulator);
    let document = List.nth documents 1 in
    assert (document = Remote_dev.Server.to_json claude_environment after);
    assert (
      match (root_panes (List.hd documents), root_panes document) with
      | Some (before_left, _), Some (after_left, _) -> before_left = after_left
      | _ -> false);
    document
  in
  let missing_document = refresh false in
  assert (has_text "Selected emulator unavailable" missing_document);
  assert (
    not (has_image "/emulators/emulator-5554/screenshot.png" missing_document));
  let missing = Atomic.get Remote_dev.Server.state in
  let navigated, _ =
    Remote_dev.Home.update claude_environment missing Remote_dev.Home.Back
  in
  assert (navigated.emulator = missing.emulator);
  assert (has_image "/emulators/emulator-5554/screenshot.png" (refresh true));
  with_emulator_screenshot ~available:true (fun () ->
      with_process (fun () -> Remote_dev.Server.initialize claude_environment));
  assert ((Atomic.get Remote_dev.Server.state).emulator.selected_emulator = None);
  assert (has_text "Select an emulator" (refresh true));
  let status, _, _ =
    Remote_dev.Server.response claude_environment `GET
      "/emulators/emulator-5554/other.png"
  in
  assert (status = `Not_found)

open Components

module Directories = struct
  type model = { root : string; entries : string list; error : string option }

  open Result_yojson

  type msg = Load | Loaded of (string list, string) result | Click of string
  [@@deriving yojson]

  let view { root; entries; error } : msg Components.t =
    let errors =
      match error with Some error -> [ text ("Error: " ^ error) ] | None -> []
    in
    let entries =
      match (entries, error) with
      | [], None -> [ text "No subdirectories" ]
      | entries, _ ->
          List.map
            (fun name -> button ~event:(Click (Filename.concat root name)) name)
            entries
    in
    column ~stretch:true ~weights:[ 0; 0; 0; 1 ]
      [
        text "Directories";
        text root;
        column errors;
        column ~stretch:true entries;
      ]

  let load root : msg Cmd.t =
    Cmd.Run
      (fun () ->
        try Some (Loaded (Ok (Runtime.load_directories root)))
        with exn -> Some (Loaded (Error (Printexc.to_string exn))))

  let init root = ({ root; entries = []; error = None }, load root)

  let update model = function
    | Load -> (model, load model.root)
    | Loaded (Ok entries) -> ({ model with entries; error = None }, Cmd.none)
    | Loaded (Error error) -> ({ model with error = Some error }, Cmd.none)
    | Click path ->
        ( model,
          Cmd.Run
            (fun () ->
              Printf.printf "Directory clicked: %S\n%!" path;
              None) )
end

module New_worktree = struct
  type model = { error : string option }

  open Result_yojson

  type msg =
    | Clear_error
    | Create of string
    | Finished of (unit, string) result
    | Error of string
  [@@deriving yojson]

  let init () = ({ error = None }, Cmd.none)

  let view { error } : msg Components.t =
    let content =
      column ~stretch:true
        [ text "New worktree"; edit ~event:(Create "__VALUE__") "Branch" ]
    in
    match error with
    | None -> content
    | Some error -> column [ text ("Error: " ^ error); content ]

  let update root model = function
    | Clear_error -> ({ error = None }, Cmd.none)
    | Create name when String.trim name = "" ->
        ({ error = Some "Branch is required" }, Cmd.none)
    | Create name ->
        ( { error = None },
          Cmd.Run
            (fun () ->
              try
                Runtime.create_worktree root name;
                Some (Finished (Ok ()))
              with exn -> Some (Finished (Error (Printexc.to_string exn)))) )
    | Finished (Ok ()) -> (model, Cmd.none)
    | Finished (Error error) -> ({ error = Some error }, Cmd.none)
    | Error error -> ({ error = Some error }, Cmd.none)
end

module Emulator = struct
  type model = {
    emulators : Runtime.emulator list;
    selected_emulator : string option;
    error : string option;
  }

  open Result_yojson

  type msg =
    | Refresh
    | Loaded of (Runtime.emulator list, string) result
    | Select of string
    | Tap of string * string
    | Tapped of (unit, string) result
  [@@deriving yojson]

  type tap = { x : int; y : int; width : int; height : int }
  [@@deriving of_yojson]

  let view { emulators; selected_emulator; error } : msg Components.t =
    let preview =
      match selected_emulator with
      | Some serial -> (
          match
            List.find_opt
              (fun (emulator : Runtime.emulator) -> emulator.serial = serial)
              emulators
          with
          | Some emulator ->
              image
                ~event:(Tap (serial, "__VALUE__"))
                ~src:("/emulators/" ^ serial ^ "/screenshot.png")
                ~label:emulator.name ()
          | None -> text "Selected emulator unavailable")
      | None ->
          text
            (if emulators = [] then "No running emulators"
             else "Select an emulator")
    in
    column ~background:Surface ~padding:(Padding.all 8) ~weights:[ 0; 0 ]
      [
        column
          (match error with
          | None -> []
          | Some error -> [ text ("Error: " ^ error) ]);
        column
          [
            text "Emulators";
            row ~gap:(Gap.make 8)
              (button ~event:Refresh "Refresh"
              :: List.map
                   (fun (emulator : Runtime.emulator) ->
                     button ~event:(Select emulator.serial) emulator.name)
                   emulators);
            preview;
          ];
      ]

  let load : msg Cmd.t =
    Cmd.Run
      (fun () ->
        try Some (Loaded (Ok (Runtime.load_emulators ())))
        with exn -> Some (Loaded (Error (Printexc.to_string exn))))

  let init () =
    ({ emulators = []; selected_emulator = None; error = None }, load)

  let update model = function
    | Refresh -> (model, load)
    | Loaded (Ok emulators) -> ({ model with emulators; error = None }, Cmd.none)
    | Loaded (Error error) -> ({ model with error = Some error }, Cmd.none)
    | Select serial
      when List.exists
             (fun (emulator : Runtime.emulator) -> emulator.serial = serial)
             model.emulators ->
        ({ model with selected_emulator = Some serial }, Cmd.none)
    | Select _ -> (model, Cmd.none)
    | Tap (serial, payload)
      when model.selected_emulator = Some serial
           && List.exists
                (fun (emulator : Runtime.emulator) -> emulator.serial = serial)
                model.emulators -> (
        match
          try tap_of_yojson (Yojson.Safe.from_string payload)
          with Yojson.Json_error _ -> Error "Invalid tap"
        with
        | Ok { x; y; width; height }
          when width > 0 && height > 0 && x >= 0 && x < width && y >= 0
               && y < height ->
            ( model,
              Cmd.Run
                (fun () ->
                  Some
                    (Tapped
                       (try
                          Runtime.tap_emulator serial ~x ~y;
                          Ok ()
                        with exn -> Error (Printexc.to_string exn)))) )
        | _ -> ({ model with error = Some "Invalid emulator tap" }, Cmd.none))
    | Tap _ -> (model, Cmd.none)
    | Tapped result ->
        ( {
            model with
            error =
              (match result with Ok () -> None | Error error -> Some error);
          },
          Cmd.none )
end

module Worktree = struct
  type model = {
    path : string;
    prompt : string;
    output : string option;
    error : string option;
    session_id : string option;
  }

  open Result_yojson

  type msg =
    | Clear_error
    | Run_prompt of string
    | Set_prompt of string
    | Session_started of string
    | Output of string
    | Finished of (string, string) result
    | Error of string
  [@@deriving yojson, variants]

  let init path =
    ( { path; prompt = ""; output = None; error = None; session_id = None },
      Cmd.none )

  let view { path; prompt; output; error; session_id = _ } : msg Components.t =
    let messages =
      match output with Some output -> [ text output ] | None -> []
    in
    let errors =
      match error with Some error -> [ text ("Error: " ^ error) ] | None -> []
    in
    let shortcuts =
      [
        column ~stretch:true
          [
            button ~event:(Set_prompt "/igor-pending-reviews")
              "/igor-pending-reviews";
            button ~event:(Set_prompt "/igor-restart-mr-tests")
              "/igor-restart-mr-tests";
          ];
      ]
    in
    column ~stretch:true ~weights:[ 0; 0; 0; 1; 0; 0 ]
      [
        column errors;
        text "Worktree";
        row [ text "Path:"; text path ];
        column messages;
        column shortcuts;
        row ~weights:[ 1; 0 ]
          [
            edit ~text:prompt ~event:(Run_prompt "__VALUE__") "Commands";
            voice_input ~event:(Set_prompt "__VALUE__");
          ];
      ]

  let update model = function
    | Clear_error -> ({ model with error = None }, Cmd.none)
    | Run_prompt prompt ->
        ({ model with prompt; output = None; error = None }, Cmd.none)
    | Set_prompt prompt -> ({ model with prompt; error = None }, Cmd.none)
    | Session_started session_id ->
        ({ model with session_id = Some session_id }, Cmd.none)
    | Output output ->
        ( {
            model with
            output = Some (Option.value ~default:"" model.output ^ output);
            error = None;
          },
          Cmd.none )
    | Finished (Ok output) ->
        ({ model with output = Some output; error = None }, Cmd.none)
    | Finished (Error error) -> ({ model with error = Some error }, Cmd.none)
    | Error error -> ({ model with error = Some error }, Cmd.none)
end

module Sessions = struct
  type model = {
    sessions : Runtime.opencode_session list;
    error : string option;
    directory : string option;
    loading : bool;
    creating : bool;
  }

  open Result_yojson

  type msg =
    | Load
    | Loaded of (Runtime.opencode_session list, string) result
    | Select of string
    | Create
    | Created of (Runtime.opencode_session, string) result
    | Error of string
  [@@deriving yojson]

  let status = function
    | Runtime.Idle -> "idle"
    | Runtime.Busy -> "busy"
    | Runtime.Retry message -> "retry: " ^ message

  let view { sessions; error; directory; loading; creating } : msg Components.t
      =
    let errors =
      match error with Some error -> [ text ("Error: " ^ error) ] | None -> []
    in
    let sessions =
      match sessions with
      | [] when loading -> [ text "Loading sessions..." ]
      | [] when Option.is_some error -> []
      | [] -> [ text "No OpenCode sessions" ]
      | sessions ->
          List.map
            (fun (session : Runtime.opencode_session) ->
              column ~stretch:true ~background:Surface
                ~border:(Border.make ~color:Outline_variant 1)
                ~corner_radius:12 ~padding:(Padding.all 16) ~gap:(Gap.make 8)
                [
                  row ~weights:[ 1; 0 ] ~gap:(Gap.make 12)
                    [
                      button ~event:(Select session.id) session.title;
                      text ("Status: " ^ status session.status);
                    ];
                  text session.directory;
                ])
            sessions
    in
    column ~stretch:true ~weights:[ 0; 0; 0; 1 ] ~padding:(Padding.all 12)
      ~gap:(Gap.make 12)
      [
        column errors;
        text "OpenCode sessions:";
        column
          (match directory with
          | None -> []
          | Some path ->
              [
                text path;
                (if creating then text "Creating session..."
                 else button ~event:Create "Создать новую сессию");
              ]);
        column ~stretch:true ~gap:(Gap.make 12) sessions;
      ]

  let load directory : msg Cmd.t =
    Cmd.Run
      (fun () ->
        try
          Some
            (Loaded
               (Ok
                  (match directory with
                  | None -> Runtime.load_opencode_sessions ()
                  | Some path -> Runtime.load_opencode_folder_sessions path)))
        with exn -> Some (Loaded (Error (Printexc.to_string exn))))

  let init ?directory () =
    ( {
        sessions = [];
        error = None;
        directory;
        loading = true;
        creating = false;
      },
      load directory )

  let update model = function
    | Load -> ({ model with error = None; loading = true }, load model.directory)
    | Loaded (Ok sessions) ->
        ({ model with sessions; error = None; loading = false }, Cmd.none)
    | Loaded (Error error) ->
        ({ model with error = Some error; loading = false }, Cmd.none)
    | Create when not model.creating -> (
        match model.directory with
        | None -> (model, Cmd.none)
        | Some path ->
            ( { model with creating = true; error = None },
              Cmd.Run
                (fun () ->
                  try Some (Created (Ok (Runtime.create_opencode_session path)))
                  with exn -> Some (Created (Error (Printexc.to_string exn))))
            ))
    | Created (Error error) ->
        ({ model with creating = false; error = Some error }, Cmd.none)
    | Created (Ok session) ->
        ( {
            model with
            creating = false;
            error = None;
            sessions =
              List.take 20
                (session
                :: List.filter
                     (fun (s : Runtime.opencode_session) -> s.id <> session.id)
                     model.sessions);
          },
          Cmd.none )
    | Select _ | Create -> (model, Cmd.none)
    | Error error -> ({ model with error = Some error }, Cmd.none)
end

module Session = struct
  type model = {
    session : Runtime.opencode_session;
    messages : Runtime.opencode_message list;
    needs_input : bool;
    prompt : string;
    error : string option;
    background_error : string option;
  }

  open Result_yojson

  type msg =
    | Load
    | Loaded of (Runtime.opencode_detail, string) result
    | Missing
    | Run_prompt of string
    | Set_prompt of string
    | Submitted of (unit, string) result
    | Stop
    | Command_finished of string * (unit, string) result
    | Error of string
  [@@deriving yojson]

  let load session : msg Cmd.t =
    Cmd.Run
      (fun () ->
        try Some (Loaded (Ok (Runtime.load_opencode_detail session))) with
        | Runtime.OpenCode_not_found -> Some Missing
        | exn -> Some (Loaded (Error (Printexc.to_string exn))))

  let init session =
    ( {
        session;
        messages = [];
        needs_input = false;
        prompt = "";
        error = None;
        background_error = None;
      },
      load session )

  let status = function
    | Runtime.Idle -> "idle"
    | Runtime.Busy -> "busy"
    | Runtime.Retry message -> "retry: " ^ message

  let view { session; messages; needs_input; prompt; error; background_error } :
      msg Components.t =
    let errors =
      [ error; background_error ]
      |> List.filter_map (Option.map (fun error -> text ("Error: " ^ error)))
    in
    let messages =
      List.map
        (fun ({ Runtime.role; text = value } : Runtime.opencode_message) ->
          text
            ((match role with
               | Runtime.User -> "User: "
               | Runtime.Assistant -> "Assistant: ")
            ^ value))
        messages
    in
    let pending =
      if needs_input then [ text "Needs input in OpenCode" ] else []
    in
    let stop =
      match session.status with
      | Runtime.Busy -> [ button ~event:Stop "Stop" ]
      | Runtime.Idle | Runtime.Retry _ -> []
    in
    column ~stretch:true ~weights:[ 0; 0; 0; 0; 0; 1; 0; 0 ]
      [
        column errors;
        text "OpenCode session";
        text session.title;
        text session.directory;
        text ("Status: " ^ status session.status);
        column messages;
        column (pending @ stop);
        row ~weights:[ 1; 0 ]
          [
            edit ~text:prompt ~event:(Run_prompt "__VALUE__") "Prompt";
            voice_input ~event:(Set_prompt "__VALUE__");
          ];
      ]

  let update model = function
    | Load -> ({ model with error = None }, load model.session)
    | Loaded (Ok detail) ->
        ( {
            model with
            session = detail.session;
            messages = detail.messages;
            needs_input = detail.needs_input;
            error = None;
          },
          Cmd.none )
    | Loaded (Error error) -> ({ model with error = Some error }, Cmd.none)
    | Missing -> (model, Cmd.none)
    | Set_prompt prompt -> ({ model with prompt; error = None }, Cmd.none)
    | Run_prompt prompt -> (
        match Runtime.opencode_input prompt with
        | `Prompt prompt ->
            ( { model with prompt; error = None; background_error = None },
              Cmd.Run
                (fun () ->
                  try
                    Runtime.submit_opencode_prompt model.session prompt;
                    Some (Submitted (Ok ()))
                  with exn ->
                    Some (Submitted (Error (Printexc.to_string exn)))) )
        | `Command _ ->
            ( { model with prompt = ""; error = None; background_error = None },
              Cmd.none ))
    | Submitted (Ok ()) -> ({ model with prompt = ""; error = None }, Cmd.none)
    | Submitted (Error error) -> ({ model with error = Some error }, Cmd.none)
    | Stop ->
        ( { model with error = None; background_error = None },
          Cmd.Run
            (fun () ->
              try
                Runtime.abort_opencode model.session;
                Some (Loaded (Ok (Runtime.load_opencode_detail model.session)))
              with
              | Runtime.OpenCode_not_found -> Some Missing
              | exn -> Some (Loaded (Error (Printexc.to_string exn)))) )
    | Command_finished (id, Ok ()) when id = model.session.id ->
        (model, Cmd.none)
    | Command_finished (id, Error error) when id = model.session.id ->
        ({ model with background_error = Some error }, Cmd.none)
    | Command_finished _ -> (model, Cmd.none)
    | Error error -> ({ model with error = Some error }, Cmd.none)
end

module Project_tabs = struct
  type screen =
    | Directories
    | Sessions of Sessions.model
    | Session of Sessions.model * Session.model

  type page = { generation : int; screen : screen }

  type model = {
    tabs : int list;
    active : int option;
    next_id : int;
    directories : Directories.model;
    pages : (int * page) list;
  }

  type content_msg =
    | Directory_event of Directories.msg
    | Sessions_event of Sessions.msg
    | Session_event of Session.msg
  [@@deriving yojson, variants]

  type msg =
    | Create
    | Select of int
    | Close of int
    | Back
    | Refresh
    | Directories_msg of Directories.msg
    | Content of int * int * content_msg
  [@@deriving yojson, variants]

  let init root =
    ( {
        tabs = [];
        active = None;
        next_id = 1;
        directories = fst (Directories.init root);
        pages = [];
      },
      Cmd.none )

  let update_directories model message =
    let directories, cmd = Directories.update model.directories message in
    ({ model with directories }, Cmd.map directories_msg cmd)

  let put model id page =
    {
      model with
      pages =
        List.map
          (fun (key, old) -> (key, if key = id then page else old))
          model.pages;
    }

  let wrap id generation message = Content (id, generation, message)

  let view model =
    let tabs =
      List.map
        (fun id ->
          let active = model.active = Some id in
          let label = Printf.sprintf "Tab %d" id in
          row
            ~background:(if active then Primary_container else Surface)
            [
              button ~event:(Select id) (if active then "* " ^ label else label);
              button ~event:(Close id) "X";
            ])
        model.tabs
    in
    let strip =
      row ~weights:[ 1; 0 ]
        [ row ~horizontal_scroll:true tabs; button ~event:Create "+" ]
    in
    let content =
      match model.active with
      | None -> []
      | Some id -> (
          match List.assoc_opt id model.pages with
          | None -> []
          | Some { generation; screen } ->
              let content =
                match screen with
                | Directories ->
                    Components.map directory_event
                      (Directories.view model.directories)
                | Sessions sessions ->
                    Components.map sessions_event (Sessions.view sessions)
                | Session (_, session) ->
                    Components.map session_event (Session.view session)
              in
              [ Components.map (wrap id generation) content ])
    in
    column ~stretch:true
      ~weights:(if content = [] then [ 0 ] else [ 0; 1 ])
      (strip :: content)

  let session_target model id generation =
    match List.assoc_opt id model.pages with
    | Some { generation = current; screen = Session (_, session) }
      when generation = current ->
        Some session
    | _ -> None

  let update_content model id page message =
    let same screen lift (value, cmd) =
      ( put model id { page with screen = screen value },
        Cmd.map (fun msg -> wrap id page.generation (lift msg)) cmd )
    in
    let navigate screen lift (value, cmd) =
      let generation = page.generation + 1 in
      ( put model id { generation; screen = screen value },
        Cmd.map (fun msg -> wrap id generation (lift msg)) cmd )
    in
    let open_session (sessions : Sessions.model) summary =
      let sessions = { sessions with loading = false; creating = false } in
      navigate
        (fun m -> Session (sessions, m))
        session_event (Session.init summary)
    in
    match (page.screen, message) with
    | Directories, Directory_event (Directories.Click path)
      when List.exists
             (fun name -> Filename.concat model.directories.root name = path)
             model.directories.entries ->
        navigate
          (fun m -> Sessions m)
          sessions_event
          (Sessions.init ~directory:path ())
    | Sessions sessions, Sessions_event (Sessions.Select id') -> (
        match
          List.find_opt
            (fun (s : Runtime.opencode_session) -> s.id = id')
            sessions.sessions
        with
        | None -> (model, Cmd.none)
        | Some summary -> open_session sessions summary)
    | ( Sessions sessions,
        Sessions_event (Sessions.Created (Ok summary) as message) ) ->
        let sessions, _ = Sessions.update sessions message in
        open_session sessions summary
    | Sessions sessions, Sessions_event message ->
        same
          (fun m -> Sessions m)
          sessions_event
          (Sessions.update sessions message)
    | Session (sessions, _), Session_event Session.Missing ->
        ( put model id
            {
              generation = page.generation + 1;
              screen =
                Sessions
                  {
                    sessions with
                    error = Some "Selected OpenCode session no longer exists";
                  };
            },
          Cmd.none )
    | Session (sessions, session), Session_event message ->
        same
          (fun m -> Session (sessions, m))
          session_event
          (Session.update session message)
    | _ -> (model, Cmd.none)

  let update model = function
    | Create ->
        ( {
            model with
            tabs = model.tabs @ [ model.next_id ];
            active = Some model.next_id;
            next_id = model.next_id + 1;
            pages =
              model.pages
              @ [ (model.next_id, { generation = 0; screen = Directories }) ];
          },
          if model.tabs = [] then
            Cmd.map directories_msg (Directories.load model.directories.root)
          else Cmd.none )
    | Select id when List.mem id model.tabs ->
        ({ model with active = Some id }, Cmd.none)
    | Close id when List.mem id model.tabs ->
        let rec neighbor previous = function
          | current :: next :: _ when current = id -> Some next
          | [ current ] when current = id -> previous
          | current :: rest -> neighbor (Some current) rest
          | [] -> None
        in
        ( {
            model with
            tabs = List.filter (( <> ) id) model.tabs;
            pages = List.remove_assoc id model.pages;
            active =
              (if model.active = Some id then neighbor None model.tabs
               else model.active);
          },
          Cmd.none )
    | Content (id, generation, message) -> (
        match List.assoc_opt id model.pages with
        | Some page when page.generation = generation ->
            update_content model id page message
        | _ -> (model, Cmd.none))
    | (Back | Refresh) as message -> (
        match
          Option.bind model.active (fun id ->
              Option.map
                (fun page -> (id, page))
                (List.assoc_opt id model.pages))
        with
        | None -> (model, Cmd.none)
        | Some (id, page) -> (
            match (message, page.screen) with
            | Back, Directories -> (model, Cmd.none)
            | Back, (Sessions _ | Session _) ->
                let screen =
                  match page.screen with
                  | Session (sessions, _) -> Sessions sessions
                  | _ -> Directories
                in
                ( put model id { generation = page.generation + 1; screen },
                  Cmd.none )
            | Refresh, Directories -> update_directories model Directories.Load
            | Refresh, Sessions _ ->
                update_content model id page (Sessions_event Sessions.Load)
            | Refresh, Session _ ->
                update_content model id page (Session_event Session.Load)
            | _ -> (model, Cmd.none)))
    | Directories_msg (Directories.Loaded _ as message) when model.tabs <> [] ->
        update_directories model message
    | Select _ | Close _ | Directories_msg _ -> (model, Cmd.none)
end

module Worktrees = struct
  type model = { worktrees : Runtime.worktree list; error : string option }

  open Result_yojson

  type msg =
    | Load
    | Loaded of (Runtime.worktree list, string) result
    | Select of string
    | Open_creation
    | Error of string
  [@@deriving yojson]

  let view { worktrees; error } : msg Components.t =
    let errors =
      match error with Some error -> [ text ("Error: " ^ error) ] | None -> []
    in
    let worktrees =
      worktrees
      |> List.map (fun (w : Runtime.worktree) ->
          column [ text w.path; button ~event:(Select w.path) w.branch ])
    in
    let creation = [ button ~event:Open_creation "New" ] in
    column ~weights:[ 0; 0; 0; 1 ]
      [ column errors; text "Worktrees:"; column creation; column worktrees ]

  let load root : msg Cmd.t =
    Cmd.Run
      (fun () ->
        try Some (Loaded (Ok (Runtime.load_worktrees root)))
        with exn -> Some (Loaded (Error (Printexc.to_string exn))))

  let init root = ({ worktrees = []; error = None }, load root)

  let update root model = function
    | Load -> ({ model with error = None }, load root)
    | Loaded (Ok worktrees) -> ({ worktrees; error = None }, Cmd.none)
    | Loaded (Error error) -> ({ model with error = Some error }, Cmd.none)
    | Select _ | Open_creation -> (model, Cmd.none)
    | Error error -> ({ model with error = Some error }, Cmd.none)
end

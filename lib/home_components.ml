open Components

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
      column [ text "New worktree"; edit ~event:(Create "__VALUE__") "Branch" ]
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
    | Loaded of (Runtime.emulator list, string) result
    | Select of string
  [@@deriving yojson]

  let view { emulators; selected_emulator; error } : msg Components.t =
    let content =
      match selected_emulator with
      | Some serial -> (
          match
            List.find_opt
              (fun (emulator : Runtime.emulator) -> emulator.serial = serial)
              emulators
          with
          | Some emulator ->
              column
                [
                  text "Emulators";
                  row
                    (List.map
                       (fun (emulator : Runtime.emulator) ->
                         button ~event:(Select emulator.serial) emulator.name)
                       emulators);
                  image
                    ~src:("/emulators/" ^ serial ^ "/screenshot.png")
                    ~label:emulator.name;
                ]
          | None -> column [ text "Emulators"; text "No running emulators" ])
      | None -> column [ text "Emulators"; text "No running emulators" ]
    in
    match error with
    | None -> content
    | Some error -> column [ text ("Error: " ^ error); content ]

  let load : msg Cmd.t =
    Cmd.Run
      (fun () ->
        try Some (Loaded (Ok (Runtime.load_emulators ())))
        with exn -> Some (Loaded (Error (Printexc.to_string exn))))

  let init () =
    ({ emulators = []; selected_emulator = None; error = None }, load)

  let update model = function
    | Loaded (Ok emulators) ->
        let selected_emulator =
          match emulators with
          | (emulator : Runtime.emulator) :: _ -> Some emulator.serial
          | [] -> None
        in
        ({ emulators; selected_emulator; error = None }, Cmd.none)
    | Loaded (Error error) -> ({ model with error = Some error }, Cmd.none)
    | Select serial
      when List.exists
             (fun (emulator : Runtime.emulator) -> emulator.serial = serial)
             model.emulators ->
        ({ model with selected_emulator = Some serial }, Cmd.none)
    | Select _ -> (model, Cmd.none)
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
        row
          [
            button ~event:(Set_prompt "/igor-pending-reviews")
              "/igor-pending-reviews";
            button ~event:(Set_prompt "/igor-restart-mr-tests")
              "/igor-restart-mr-tests";
          ];
      ]
    in
    column ~weights:[ 0; 0; 0; 1; 0; 0 ]
      [
        column errors;
        text "Worktree";
        row [ text "Path:"; text path ];
        column messages;
        column shortcuts;
        edit ~text:prompt ~event:(Run_prompt "__VALUE__") "Commands";
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
  }

  open Result_yojson

  type msg =
    | Load
    | Loaded of (Runtime.opencode_session list, string) result
    | Select of string
    | Error of string
  [@@deriving yojson]

  let status = function
    | Runtime.Idle -> "idle"
    | Runtime.Busy -> "busy"
    | Runtime.Retry message -> "retry: " ^ message

  let view { sessions; error } : msg Components.t =
    let errors =
      match error with Some error -> [ text ("Error: " ^ error) ] | None -> []
    in
    let sessions =
      match sessions with
      | [] -> [ text "No OpenCode sessions" ]
      | sessions ->
          List.map
            (fun (session : Runtime.opencode_session) ->
              column
                [
                  button ~event:(Select session.id) session.title;
                  text session.directory;
                  text ("Status: " ^ status session.status);
                ])
            sessions
    in
    column ~weights:[ 0; 0; 1 ]
      [ column errors; text "OpenCode sessions:"; column sessions ]

  let load : msg Cmd.t =
    Cmd.Run
      (fun () ->
        try Some (Loaded (Ok (Runtime.load_opencode_sessions ())))
        with exn -> Some (Loaded (Error (Printexc.to_string exn))))

  let init () = ({ sessions = []; error = None }, load)

  let update model = function
    | Load -> ({ model with error = None }, load)
    | Loaded (Ok sessions) -> ({ sessions; error = None }, Cmd.none)
    | Loaded (Error error) -> ({ model with error = Some error }, Cmd.none)
    | Select _ -> (model, Cmd.none)
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
    column ~weights:[ 0; 0; 0; 0; 0; 1; 0; 0 ]
      [
        column errors;
        text "OpenCode session";
        text session.title;
        text session.directory;
        text ("Status: " ^ status session.status);
        column messages;
        column (pending @ stop);
        edit ~text:prompt ~event:(Run_prompt "__VALUE__") "Prompt";
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

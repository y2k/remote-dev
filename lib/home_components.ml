open Components

module New_worktree = struct
  type model = { error : string option }

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
  }

  type msg =
    | Clear_error
    | Run_claude of string
    | Set_prompt of string
    | Output of string
    | Finished of (string, string) result
    | Error of string
  [@@deriving yojson, variants]

  let init path = ({ path; prompt = ""; output = None; error = None }, Cmd.none)

  let view { path; prompt; output; error } : msg Components.t =
    let messages =
      match output with Some output -> [ text output ] | None -> []
    in
    let content =
      column
        [
          text "Worktree";
          row [ text "Path:"; text path ];
          column messages;
          row
            [
              button ~event:(Set_prompt "/igor-pending-reviews")
                "/igor-pending-reviews";
              button ~event:(Set_prompt "/igor-restart-mr-tests")
                "/igor-restart-mr-tests";
            ];
          edit ~text:prompt ~event:(Run_claude "__VALUE__") "Commands";
        ]
    in
    match error with
    | None -> content
    | Some error -> column [ text ("Error: " ^ error); content ]

  let update model = function
    | Clear_error -> ({ model with error = None }, Cmd.none)
    | Run_claude prompt ->
        ({ model with prompt; output = None; error = None }, Cmd.none)
    | Set_prompt prompt -> ({ model with prompt; error = None }, Cmd.none)
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

module Worktrees = struct
  type model = { worktrees : Runtime.worktree list; error : string option }

  type msg =
    | Load
    | Loaded of (Runtime.worktree list, string) result
    | Select of string
    | Open_creation
    | Error of string
  [@@deriving yojson]

  let view { worktrees; error } : msg Components.t =
    let worktrees =
      worktrees
      |> List.map (fun (w : Runtime.worktree) ->
          column [ text w.path; button ~event:(Select w.path) w.branch ])
    in
    let content =
      column
        [
          text "Worktrees:"; button ~event:Open_creation "New"; column worktrees;
        ]
    in
    match error with
    | None -> content
    | Some error -> column [ text ("Error: " ^ error); content ]

  let root () =
    if Array.length Sys.argv > 1 then Sys.argv.(1) else Sys.getcwd ()

  let load : msg Cmd.t =
    Cmd.Run
      (fun () ->
        try Some (Loaded (Ok (Runtime.load_worktrees (root ()))))
        with exn -> Some (Loaded (Error (Printexc.to_string exn))))

  let init () = ({ worktrees = []; error = None }, load)

  let update model = function
    | Load -> ({ model with error = None }, load)
    | Loaded (Ok worktrees) -> ({ worktrees; error = None }, Cmd.none)
    | Loaded (Error error) -> ({ model with error = Some error }, Cmd.none)
    | Select _ | Open_creation -> (model, Cmd.none)
    | Error error -> ({ model with error = Some error }, Cmd.none)
end

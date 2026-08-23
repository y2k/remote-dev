module J = Yojson.Basic
open Components

let event fields = `Assoc fields
let root () = if Array.length Sys.argv > 1 then Sys.argv.(1) else Sys.getcwd ()

module Cmd = struct
  type 'msg t = unit -> 'msg option

  let none () = None
  let map f cmd () = Option.map f (cmd ())
end

module Worktrees = struct
  type model = { worktrees : Runtime.worktree list; error : string option }

  type msg =
    | Load
    | Loaded of (Runtime.worktree list, string) result
    | Select of string
    | Error of string

  type action = Stay | Open of string

  let initial = { worktrees = []; error = None }

  let view { worktrees; error } : J.t =
    let worktrees =
      worktrees
      |> List.map (fun (w : Runtime.worktree) ->
          column
            [
              text w.path;
              button
                ~event:
                  (event
                     [
                       ("type", `String "select_worktree");
                       ("path", `String w.path);
                     ])
                w.branch;
            ])
    in
    let content =
      column [ text "Worktrees:"; button "New"; column worktrees ]
    in
    match error with
    | None -> content
    | Some error -> column [ text ("Error: " ^ error); content ]

  let load : msg Cmd.t =
   fun () ->
    try Some (Loaded (Ok (Runtime.load_worktrees (root ()))))
    with exn -> Some (Loaded (Error (Printexc.to_string exn)))

  let update model = function
    | Load -> ({ model with error = None }, load, Stay)
    | Loaded (Ok worktrees) -> ({ worktrees; error = None }, Cmd.none, Stay)
    | Loaded (Error error) -> ({ model with error = Some error }, Cmd.none, Stay)
    | Select path -> ({ model with error = None }, Cmd.none, Open path)
    | Error error -> ({ model with error = Some error }, Cmd.none, Stay)
end

module Worktree = struct
  type model = { path : string; output : string option; error : string option }

  type msg =
    | Clear_error
    | Run of string option
    | Finished of (string, string) result
    | Back
    | Error of string

  type action = Stay | Back_to_worktrees

  let initial path = { path; output = None; error = None }

  let view { path; output; error } : J.t =
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
            [ button "/igor-pending-reviews"; button "/igor-restart-mr-tests" ];
          edit ~event:(event [ ("type", `String "run_claude") ]) "Command2";
        ]
    in
    match error with
    | None -> content
    | Some error -> column [ text ("Error: " ^ error); content ]

  let run path prompt : msg Cmd.t =
   fun () ->
    try Some (Finished (Ok (Runtime.run_claude path prompt)))
    with exn -> Some (Finished (Error (Printexc.to_string exn)))

  let update model = function
    | Clear_error -> ({ model with error = None }, Cmd.none, Stay)
    | Run (Some prompt) ->
        ({ model with error = None }, run model.path prompt, Stay)
    | Run None ->
        ( { model with error = Some "Command event requires a value" },
          Cmd.none,
          Stay )
    | Finished (Ok output) ->
        ({ model with output = Some output; error = None }, Cmd.none, Stay)
    | Finished (Error error) ->
        ({ model with error = Some error }, Cmd.none, Stay)
    | Back -> ({ model with error = None }, Cmd.none, Back_to_worktrees)
    | Error error -> ({ model with error = Some error }, Cmd.none, Stay)
end

module Home = struct
  type screen = Worktrees of Worktrees.model | Worktree of Worktree.model
  type state = { screen : screen }

  type msg =
    | Load
    | Select_worktree of string
    | Back
    | Run_claude of string option
    | Error of string
    | Worktrees_msg of Worktrees.msg
    | Worktree_msg of Worktree.msg

  let document { screen } =
    match screen with
    | Worktrees model -> Worktrees.view model
    | Worktree model -> Worktree.view model

  let lift_worktrees = Cmd.map (fun message -> Worktrees_msg message)
  let lift_worktree = Cmd.map (fun message -> Worktree_msg message)

  let update_worktrees model message =
    let model, cmd, action = Worktrees.update model message in
    match action with
    | Worktrees.Open path ->
        ({ screen = Worktree (Worktree.initial path) }, Cmd.none)
    | Worktrees.Stay -> ({ screen = Worktrees model }, lift_worktrees cmd)

  let load_worktrees () = update_worktrees Worktrees.initial Worktrees.Load

  let update_worktree model message =
    let model, cmd, action = Worktree.update model message in
    match action with
    | Worktree.Back_to_worktrees -> load_worktrees ()
    | Worktree.Stay -> ({ screen = Worktree model }, lift_worktree cmd)

  let update { screen } message =
    match (screen, message) with
    | Worktrees model, Load -> update_worktrees model Worktrees.Load
    | Worktree model, Load -> update_worktree model Worktree.Clear_error
    | Worktrees model, Select_worktree path ->
        update_worktrees model (Worktrees.Select path)
    | Worktree model, Back -> update_worktree model Worktree.Back
    | Worktree model, Run_claude value ->
        update_worktree model (Worktree.Run value)
    | Worktrees model, Worktrees_msg message -> update_worktrees model message
    | Worktree model, Worktree_msg message -> update_worktree model message
    | Worktrees model, Run_claude _ ->
        update_worktrees model
          (Worktrees.Error "Command requires a selected worktree")
    | Worktree model, Select_worktree _ | Worktree model, Worktrees_msg _ ->
        update_worktree model (Worktree.Error "Unknown event")
    | Worktrees model, Back -> ({ screen = Worktrees model }, Cmd.none)
    | Worktrees model, Worktree_msg _ ->
        update_worktrees model (Worktrees.Error "Unknown event")
    | Worktrees model, Error error ->
        update_worktrees model (Worktrees.Error error)
    | Worktree model, Error error ->
        update_worktree model (Worktree.Error error)
end

let state = Atomic.make { Home.screen = Home.Worktrees Worktrees.initial }

let reset () =
  Atomic.set state { Home.screen = Home.Worktrees Worktrees.initial }

let rec dispatch message =
  let next, cmd = Home.update (Atomic.get state) message in
  Atomic.set state next;
  match cmd () with None -> next | Some message -> dispatch message

let field name fields = List.assoc_opt name fields

let decode body =
  try
    match J.from_string body with
    | `Assoc fields -> (
        match (field "event" fields, field "value" fields) with
        | Some (`Assoc event), Some ((`Null | `String _) as value) -> (
            let value =
              match value with `String value -> Some value | `Null -> None
            in
            match field "type" event with
            | Some (`String "load") -> Ok Home.Load
            | Some (`String "select_worktree") -> (
                match field "path" event with
                | Some (`String path) -> Ok (Home.Select_worktree path)
                | _ -> Ok (Home.Error "Invalid worktree event"))
            | Some (`String "back") -> Ok Home.Back
            | Some (`String "run_claude") -> Ok (Home.Run_claude value)
            | _ -> Ok (Home.Error "Unknown event"))
        | _ -> Error "Invalid event request")
    | _ -> Error "Invalid event request"
  with Yojson.Json_error _ -> Error "Invalid event request"

let response body =
  match decode body with
  | Ok message -> Ok (J.pretty_to_string (Home.document (dispatch message)))
  | Error message -> Error message

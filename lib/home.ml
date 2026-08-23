module J = Yojson.Basic
open Components

let event fields = `Assoc fields
let root () = if Array.length Sys.argv > 1 then Sys.argv.(1) else Sys.getcwd ()

module Cmd = struct
  type 'msg t = unit -> 'msg option

  let none () = None
  let map f cmd () = Option.map f (cmd ())
end

module Route = struct
  type t = Worktrees | Worktree of string
end

type request = { event : (string * J.t) list; value : string option }

let field name fields = List.assoc_opt name fields

let decode_request body =
  try
    match J.from_string body with
    | `Assoc fields -> (
        match (field "event" fields, field "value" fields) with
        | Some (`Assoc event), Some ((`Null | `String _) as value) ->
            Ok
              {
                event;
                value =
                  (match value with
                  | `String value -> Some value
                  | `Null -> None);
              }
        | _ -> Error "Invalid event request")
    | _ -> Error "Invalid event request"
  with Yojson.Json_error _ -> Error "Invalid event request"

module Worktrees = struct
  type model = { worktrees : Runtime.worktree list; error : string option }
  type action = Select_worktree of string

  type msg =
    | Load
    | Loaded of (Runtime.worktree list, string) result
    | Select of string
    | Ignore
    | Error of string

  let initial = { worktrees = []; error = None }

  let encode_action = function
    | Select_worktree path ->
        event [ ("type", `String "select_worktree"); ("path", `String path) ]

  let view { worktrees; error } : action Components.t =
    let worktrees =
      worktrees
      |> List.map (fun (w : Runtime.worktree) ->
          column
            [ text w.path; button ~event:(Select_worktree w.path) w.branch ])
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

  let enter () = (initial, load)

  let decode { event; _ } =
    match field "type" event with
    | Some (`String "load") -> Load
    | Some (`String "select_worktree") -> (
        match field "path" event with
        | Some (`String path) -> Select path
        | _ -> Error "Invalid worktree event")
    | Some (`String "back") -> Ignore
    | Some (`String "run_claude") ->
        Error "Command requires a selected worktree"
    | _ -> Error "Unknown event"

  let update model = function
    | Load -> ({ model with error = None }, load, None)
    | Loaded (Ok worktrees) -> ({ worktrees; error = None }, Cmd.none, None)
    | Loaded (Error error) -> ({ model with error = Some error }, Cmd.none, None)
    | Select path ->
        ({ model with error = None }, Cmd.none, Some (Route.Worktree path))
    | Ignore -> (model, Cmd.none, None)
    | Error error -> ({ model with error = Some error }, Cmd.none, None)
end

module Worktree = struct
  type model = {
    path : string;
    prompt : string;
    output : string option;
    error : string option;
  }

  type action = Run_claude | Set_prompt of string

  type msg =
    | Clear_error
    | Event of action * string option
    | Finished of (string, string) result
    | Back
    | Error of string

  let initial path = { path; prompt = ""; output = None; error = None }

  let encode_action = function
    | Run_claude -> event [ ("type", `String "run_claude") ]
    | Set_prompt prompt ->
        event [ ("type", `String "set_prompt"); ("prompt", `String prompt) ]

  let view { path; prompt; output; error } : action Components.t =
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
          edit ~text:prompt ~event:Run_claude "Commands";
        ]
    in
    match error with
    | None -> content
    | Some error -> column [ text ("Error: " ^ error); content ]

  let run path prompt : msg Cmd.t =
   fun () ->
    try Some (Finished (Ok (Runtime.run_claude path prompt)))
    with exn -> Some (Finished (Error (Printexc.to_string exn)))

  let enter path = (initial path, Cmd.none)

  let decode { event; value } =
    match field "type" event with
    | Some (`String "load") -> Clear_error
    | Some (`String "back") -> Back
    | Some (`String "run_claude") -> Event (Run_claude, value)
    | Some (`String "set_prompt") -> (
        match field "prompt" event with
        | Some (`String prompt) -> Event (Set_prompt prompt, value)
        | _ -> Error "Invalid prompt shortcut event")
    | _ -> Error "Unknown event"

  let update model = function
    | Clear_error -> ({ model with error = None }, Cmd.none, None)
    | Event (Run_claude, Some prompt) ->
        ({ model with error = None }, run model.path prompt, None)
    | Event (Run_claude, None) ->
        ( { model with error = Some "Command event requires a value" },
          Cmd.none,
          None )
    | Event (Set_prompt prompt, _) ->
        ({ model with prompt; error = None }, Cmd.none, None)
    | Finished (Ok output) ->
        ({ model with output = Some output; error = None }, Cmd.none, None)
    | Finished (Error error) ->
        ({ model with error = Some error }, Cmd.none, None)
    | Back -> ({ model with error = None }, Cmd.none, Some Route.Worktrees)
    | Error error -> ({ model with error = Some error }, Cmd.none, None)
end

module Home = struct
  type screen = Worktrees of Worktrees.model | Worktree of Worktree.model
  type state = { screen : screen }
  type msg = Worktrees_msg of Worktrees.msg | Worktree_msg of Worktree.msg

  type event =
    | Worktrees_event of Worktrees.action
    | Worktree_event of Worktree.action

  let view { screen } =
    match screen with
    | Worktrees model ->
        Components.map
          (fun event -> Worktrees_event event)
          (Worktrees.view model)
    | Worktree model ->
        Components.map (fun event -> Worktree_event event) (Worktree.view model)

  let encode_event = function
    | Worktrees_event event -> Worktrees.encode_action event
    | Worktree_event event -> Worktree.encode_action event

  let to_json state = Components.to_json encode_event (view state)
  let lift_worktrees = Cmd.map (fun message -> Worktrees_msg message)
  let lift_worktree = Cmd.map (fun message -> Worktree_msg message)

  let enter = function
    | Route.Worktrees ->
        let model, cmd = Worktrees.enter () in
        ({ screen = Worktrees model }, lift_worktrees cmd)
    | Route.Worktree path ->
        let model, cmd = Worktree.enter path in
        ({ screen = Worktree model }, lift_worktree cmd)

  let update_page screen lift update model message =
    let model, cmd, route = update model message in
    match route with
    | Some route -> enter route
    | None -> ({ screen = screen model }, lift cmd)

  let update { screen } message =
    match (screen, message) with
    | Worktrees model, Worktrees_msg message ->
        update_page
          (fun model -> Worktrees model)
          lift_worktrees Worktrees.update model message
    | Worktree model, Worktree_msg message ->
        update_page
          (fun model -> Worktree model)
          lift_worktree Worktree.update model message
    | _ -> ({ screen }, Cmd.none)

  let decode { screen } request =
    match screen with
    | Worktrees _ -> Worktrees_msg (Worktrees.decode request)
    | Worktree _ -> Worktree_msg (Worktree.decode request)
end

let state = Atomic.make { Home.screen = Home.Worktrees Worktrees.initial }

let reset () =
  Atomic.set state { Home.screen = Home.Worktrees Worktrees.initial }

let rec dispatch message =
  let next, cmd = Home.update (Atomic.get state) message in
  Atomic.set state next;
  match cmd () with None -> next | Some message -> dispatch message

let decode body =
  Result.map (Home.decode (Atomic.get state)) (decode_request body)

let response body =
  match decode body with
  | Ok message -> Ok (J.pretty_to_string (Home.to_json (dispatch message)))
  | Error message -> Error message

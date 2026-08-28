module J = Yojson.Safe
open Components
open Home_components

let trace prefix to_string x =
  prerr_endline @@ prefix ^ ": " ^ to_string x;
  x

let event fields = `Assoc fields

type request = { event : J.t; value : string option }

let field name fields = List.assoc_opt name fields

let decode_request body =
  try
    match J.from_string body with
    | `Assoc fields -> (
        match (field "event" fields, field "value" fields) with
        | Some event, Some ((`Null | `String _) as value) ->
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

module Home = struct
  type screen =
    | Worktrees of Worktrees.model
    | New_worktree of Worktrees.model * New_worktree.model
    | Worktree of Worktree.model

  type state = { screen : screen }

  type msg =
    | Back
    | Worktrees_msg of Worktrees.msg
    | New_worktree_msg of New_worktree.msg
    | Worktree_msg of Worktree.msg
  [@@deriving yojson]

  let view { screen } =
    match screen with
    | Worktrees model ->
        Components.map
          (fun message -> Worktrees_msg message)
          (Worktrees.view model)
    | New_worktree (_, model) ->
        Components.map
          (fun message -> New_worktree_msg message)
          (New_worktree.view model)
    | Worktree model ->
        Components.map
          (fun message -> Worktree_msg message)
          (Worktree.view model)

  let to_json state = Components.to_json msg_to_yojson (view state)
  let lift_worktrees = Cmd.map (fun message -> Worktrees_msg message)
  let lift_new_worktree = Cmd.map (fun message -> New_worktree_msg message)
  let lift_worktree = Cmd.map (fun message -> Worktree_msg message)

  let enter_worktrees () =
    let model, cmd = Worktrees.enter () in
    ({ screen = Worktrees model }, lift_worktrees cmd)

  let enter_worktree path =
    let model, cmd = Worktree.enter path in
    ({ screen = Worktree model }, lift_worktree cmd)

  let enter_new_worktree worktrees =
    let model, cmd = New_worktree.enter () in
    ({ screen = New_worktree (worktrees, model) }, lift_new_worktree cmd)

  let init () = enter_worktrees ()

  let update_page screen lift update model message =
    let model, cmd = update model message in
    ({ screen = screen model }, lift cmd)

  let update { screen } message =
    match (screen, message) with
    | Worktrees _, Back -> ({ screen }, Cmd.none)
    | New_worktree (worktrees, _), Back ->
        ({ screen = Worktrees worktrees }, Cmd.none)
    | Worktree _, Back -> enter_worktrees ()
    | Worktrees _, Worktrees_msg (Worktrees.Select path) -> enter_worktree path
    | Worktrees model, Worktrees_msg Worktrees.Open_creation ->
        enter_new_worktree model
    | ( New_worktree (worktrees, _),
        New_worktree_msg (New_worktree.Finished (Ok ())) ) ->
        update_page
          (fun model -> Worktrees model)
          lift_worktrees Worktrees.update worktrees Worktrees.Load
    | New_worktree (worktrees, model), New_worktree_msg message ->
        update_page
          (fun model -> New_worktree (worktrees, model))
          lift_new_worktree
          (New_worktree.update (Worktrees.root ()))
          model message
    | Worktrees model, Worktrees_msg message ->
        update_page
          (fun model -> Worktrees model)
          lift_worktrees Worktrees.update model message
    | Worktree model, Worktree_msg message ->
        update_page
          (fun model -> Worktree model)
          lift_worktree Worktree.update model message
    | _ -> ({ screen }, Cmd.none)
end

let state = Atomic.make { Home.screen = Home.Worktrees Worktrees.initial }

let reset () =
  Atomic.set state { Home.screen = Home.Worktrees Worktrees.initial }

let step message =
  let next, cmd = Home.update (Atomic.get state) message in
  Atomic.set state next;
  (next, cmd)

let init () = Home.init ()

let rec dispatch message =
  let next, cmd = step message in
  match Cmd.run cmd with None -> next | Some message -> dispatch message

let rec replace_value value = function
  | `String "__VALUE__" -> `String value
  | `Assoc fields ->
      `Assoc
        (List.map (fun (key, json) -> (key, replace_value value json)) fields)
  | `List values -> `List (List.map (replace_value value) values)
  | json -> json

let decode body =
  match decode_request body with
  | Error _ as error -> error
  | Ok { event; value } ->
      Home.msg_of_yojson (replace_value (Option.value ~default:"" value) event)

type claude_stream = { cwd : string; prompt : string }

let start_claude_stream body =
  match decode body with
  | Ok (Home.Worktree_msg (Worktree.Run_claude prompt) as message) -> (
      let next, _ = step message in
      match next.screen with
      | Home.Worktree { path; _ } -> Some { cwd = path; prompt }
      | Home.Worktrees _ | Home.New_worktree _ -> None)
  | Ok _ | Error _ -> None

let stream_output output =
  J.to_string
    (Home.to_json (dispatch (Home.Worktree_msg (Worktree.Output output))))

let stream_error error =
  J.to_string
    (Home.to_json
       (dispatch (Home.Worktree_msg (Worktree.Finished (Error error)))))

let response body =
  match decode body with
  | Ok message -> Ok (J.pretty_to_string (Home.to_json (dispatch message)))
  | Error message ->
      prerr_endline @@ "ERROR: " ^ message;
      Error message

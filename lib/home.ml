module J = Yojson.Safe
open Components

let trace prefix to_string x =
  prerr_endline @@ prefix ^ ": " ^ to_string x;
  x

let event fields = `Assoc fields
let root () = if Array.length Sys.argv > 1 then Sys.argv.(1) else Sys.getcwd ()

module Cmd = struct
  type 'msg t = Empty | Run of (unit -> 'msg option)

  let none = Empty
  let run = function Empty -> Option.none | Run cmd -> cmd ()

  let map f = function
    | Empty -> Empty
    | Run cmd -> Run (fun () -> Option.map f (cmd ()))
end

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

let result_to_yojson ok_to_yojson error_to_yojson = function
  | Ok value -> `List [ `String "Ok"; ok_to_yojson value ]
  | Error value -> `List [ `String "Error"; error_to_yojson value ]

let result_of_yojson ok_of_yojson error_of_yojson = function
  | `List [ `String "Ok"; value ] ->
      Result.map (fun value -> Ok value) (ok_of_yojson value)
  | `List [ `String "Error"; value ] ->
      Result.map (fun value -> Error value) (error_of_yojson value)
  | _ -> Error "result"

module Worktrees = struct
  type model = { worktrees : Runtime.worktree list; error : string option }

  type msg =
    | Load
    | Loaded of (Runtime.worktree list, string) result
    | Select of string
    | Open_creation
    | Error of string
  [@@deriving yojson]

  let initial = { worktrees = []; error = None }

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

  let load : msg Cmd.t =
    Cmd.Run
      (fun () ->
        try Some (Loaded (Ok (Runtime.load_worktrees (root ()))))
        with exn -> Some (Loaded (Error (Printexc.to_string exn))))

  let enter () = (initial, load)

  let update model = function
    | Load -> ({ model with error = None }, load)
    | Loaded (Ok worktrees) -> ({ worktrees; error = None }, Cmd.none)
    | Loaded (Error error) -> ({ model with error = Some error }, Cmd.none)
    | Select _ | Open_creation -> (model, Cmd.none)
    | Error error -> ({ model with error = Some error }, Cmd.none)
end

module New_worktree = struct
  type model = { error : string option }

  type msg = Clear_error | Create of string | Error of string
  [@@deriving yojson]

  let initial = { error = None }

  let view { error } : msg Components.t =
    let content =
      column [ text "New worktree"; edit ~event:(Create "__VALUE__") "Branch" ]
    in
    match error with
    | None -> content
    | Some error -> column [ text ("Error: " ^ error); content ]

  let enter () = (initial, Cmd.none)

  let update _ = function
    | Clear_error | Create _ -> ({ error = None }, Cmd.none)
    | Error error -> ({ error = Some error }, Cmd.none)
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
  [@@deriving yojson]

  let initial path = { path; prompt = ""; output = None; error = None }

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

  let enter path = (initial path, Cmd.none)

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
    | New_worktree (worktrees, model), New_worktree_msg message ->
        update_page
          (fun model -> New_worktree (worktrees, model))
          lift_new_worktree New_worktree.update model message
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

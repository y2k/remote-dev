open Components
open Home_components

type screen =
  | Worktrees of Worktrees.model
  | New_worktree of Worktrees.model * New_worktree.model
  | Worktree of Worktree.model
  | Sessions of Sessions.model
  | Session of Sessions.model * Session.model

type model = { screen : screen; emulator : Emulator.model }

type msg =
  | Back
  | Refresh
  | Worktrees_msg of Worktrees.msg
  | New_worktree_msg of New_worktree.msg
  | Worktree_msg of Worktree.msg
  | Sessions_msg of Sessions.msg
  | Session_msg of Session.msg
  | Initialize_emulator of Emulator.msg
  | Emulator_msg of Emulator.msg
[@@deriving yojson, variants]

let view environment { screen; emulator } =
  let screen =
    match screen with
    | Worktrees model -> Components.map worktrees_msg (Worktrees.view model)
    | New_worktree (_, model) ->
        Components.map new_worktree_msg (New_worktree.view model)
    | Worktree model -> Components.map worktree_msg (Worktree.view model)
    | Sessions model -> Components.map sessions_msg (Sessions.view model)
    | Session (_, model) -> Components.map session_msg (Session.view model)
  in
  row ~weights:[ 2; 1 ]
    [
      column
        [
          text
            (match environment with
            | Runtime.Claude _ -> "Agent: Claude"
            | Runtime.OpenCode -> "Agent: OpenCode");
          screen;
        ];
      Components.map emulator_msg (Emulator.view emulator);
    ]

let lift_worktrees = Cmd.map worktrees_msg
let lift_new_worktree = Cmd.map new_worktree_msg
let lift_worktree = Cmd.map worktree_msg
let lift_sessions = Cmd.map sessions_msg
let lift_session = Cmd.map session_msg
let lift_emulator = Cmd.map emulator_msg

let init environment =
  let emulator, cmd = Emulator.init () in
  let screen =
    match environment with
    | Runtime.Claude { root } -> Worktrees (Worktrees.init root |> fst)
    | Runtime.OpenCode -> Sessions (Sessions.init () |> fst)
  in
  ({ screen; emulator }, Cmd.map initialize_emulator cmd)

let update_page state screen lift update model message =
  let model, cmd = update model message in
  ({ state with screen = screen model }, lift cmd)

let claude_root = function
  | Runtime.Claude { root } -> root
  | Runtime.OpenCode -> assert false

let update environment ({ screen; _ } as state) message =
  match (screen, message) with
  | _, Initialize_emulator message ->
      let emulator, _ = Emulator.update state.emulator message in
      let screen, cmd =
        match environment with
        | Runtime.Claude { root } ->
            let worktrees, cmd = Worktrees.init root in
            (Worktrees worktrees, lift_worktrees cmd)
        | Runtime.OpenCode ->
            let sessions, cmd = Sessions.init () in
            (Sessions sessions, lift_sessions cmd)
      in
      ({ screen; emulator }, cmd)
  | _, Emulator_msg message ->
      let emulator, cmd = Emulator.update state.emulator message in
      ({ state with emulator }, lift_emulator cmd)
  | Worktrees model, Refresh ->
      update_page state
        (fun model -> Worktrees model)
        lift_worktrees
        (Worktrees.update (claude_root environment))
        model Worktrees.Load
  | Sessions model, Refresh ->
      update_page state
        (fun model -> Sessions model)
        lift_sessions Sessions.update model Sessions.Load
  | Session (sessions, model), Refresh ->
      update_page state
        (fun model -> Session (sessions, model))
        lift_session Session.update model Session.Load
  | (New_worktree _ | Worktree _), Refresh -> (state, Cmd.none)
  | Worktrees _, Back -> (state, Cmd.none)
  | Sessions _, Back -> (state, Cmd.none)
  | New_worktree (worktrees, _), Back ->
      ({ state with screen = Worktrees worktrees }, Cmd.none)
  | Worktree _, Back ->
      let worktrees, cmd = Worktrees.init (claude_root environment) in
      ({ state with screen = Worktrees worktrees }, lift_worktrees cmd)
  | Session (sessions, _), Back ->
      ({ state with screen = Sessions sessions }, Cmd.none)
  | Worktrees _, Worktrees_msg (Worktrees.Select path) ->
      let worktree, cmd = Worktree.init path in
      ({ state with screen = Worktree worktree }, lift_worktree cmd)
  | Worktrees model, Worktrees_msg Worktrees.Open_creation ->
      let new_worktree, cmd = New_worktree.init () in
      ( { state with screen = New_worktree (model, new_worktree) },
        lift_new_worktree cmd )
  | ( New_worktree (worktrees, _),
      New_worktree_msg (New_worktree.Finished (Ok ())) ) ->
      update_page state
        (fun model -> Worktrees model)
        lift_worktrees
        (Worktrees.update (claude_root environment))
        worktrees Worktrees.Load
  | New_worktree (worktrees, model), New_worktree_msg message ->
      update_page state
        (fun model -> New_worktree (worktrees, model))
        lift_new_worktree
        (New_worktree.update (claude_root environment))
        model message
  | Worktrees model, Worktrees_msg message ->
      update_page state
        (fun model -> Worktrees model)
        lift_worktrees
        (Worktrees.update (claude_root environment))
        model message
  | Worktree model, Worktree_msg message ->
      update_page state
        (fun model -> Worktree model)
        lift_worktree Worktree.update model message
  | Sessions model, Sessions_msg (Sessions.Select id) -> (
      match
        List.find_opt
          (fun (session : Runtime.opencode_session) -> session.id = id)
          model.sessions
      with
      | Some summary ->
          let session, cmd = Session.init summary in
          ({ state with screen = Session (model, session) }, lift_session cmd)
      | None -> (state, Cmd.none))
  | Sessions model, Sessions_msg message ->
      update_page state
        (fun model -> Sessions model)
        lift_sessions Sessions.update model message
  | Session (sessions, _), Session_msg Session.Missing ->
      ( {
          state with
          screen =
            Sessions
              {
                sessions with
                error = Some "Selected OpenCode session no longer exists";
              };
        },
        Cmd.none )
  | Session (sessions, model), Session_msg message ->
      update_page state
        (fun model -> Session (sessions, model))
        lift_session Session.update model message
  | _ -> (state, Cmd.none)

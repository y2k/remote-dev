open Components
open Home_components

type screen =
  | Worktrees of Worktrees.model
  | New_worktree of Worktrees.model * New_worktree.model
  | Worktree of Worktree.model

type model = { screen : screen; emulator : Emulator.model }

type msg =
  | Back
  | Worktrees_msg of Worktrees.msg
  | New_worktree_msg of New_worktree.msg
  | Worktree_msg of Worktree.msg
  | Initialize_emulator of Emulator.msg
  | Emulator_msg of Emulator.msg
[@@deriving yojson, variants]

let view { screen; emulator } =
  let screen =
    match screen with
    | Worktrees model -> Components.map worktrees_msg (Worktrees.view model)
    | New_worktree (_, model) ->
        Components.map new_worktree_msg (New_worktree.view model)
    | Worktree model -> Components.map worktree_msg (Worktree.view model)
  in
  row ~weights:[ 2; 1 ]
    [ screen; Components.map emulator_msg (Emulator.view emulator) ]

let lift_worktrees = Cmd.map worktrees_msg
let lift_new_worktree = Cmd.map new_worktree_msg
let lift_worktree = Cmd.map worktree_msg
let lift_emulator = Cmd.map emulator_msg

let init () =
  let emulator, cmd = Emulator.init () in
  let worktrees, _ = Worktrees.init () in
  ({ screen = Worktrees worktrees; emulator }, Cmd.map initialize_emulator cmd)

let update_page state screen lift update model message =
  let model, cmd = update model message in
  ({ state with screen = screen model }, lift cmd)

let update ({ screen; _ } as state) message =
  match (screen, message) with
  | _, Initialize_emulator message ->
      let emulator, _ = Emulator.update state.emulator message in
      let worktrees, cmd = Worktrees.init () in
      (* ponytail: bootstrap loads are one-shot; add Cmd.batch if child updates
         start returning commands. *)
      ({ screen = Worktrees worktrees; emulator }, lift_worktrees cmd)
  | _, Emulator_msg message ->
      let emulator, cmd = Emulator.update state.emulator message in
      ({ state with emulator }, lift_emulator cmd)
  | Worktrees _, Back -> (state, Cmd.none)
  | New_worktree (worktrees, _), Back ->
      ({ state with screen = Worktrees worktrees }, Cmd.none)
  | Worktree _, Back ->
      let worktrees, cmd = Worktrees.init () in
      ({ state with screen = Worktrees worktrees }, lift_worktrees cmd)
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
        lift_worktrees Worktrees.update worktrees Worktrees.Load
  | New_worktree (worktrees, model), New_worktree_msg message ->
      update_page state
        (fun model -> New_worktree (worktrees, model))
        lift_new_worktree
        (New_worktree.update (Worktrees.root ()))
        model message
  | Worktrees model, Worktrees_msg message ->
      update_page state
        (fun model -> Worktrees model)
        lift_worktrees Worktrees.update model message
  | Worktree model, Worktree_msg message ->
      update_page state
        (fun model -> Worktree model)
        lift_worktree Worktree.update model message
  | _ -> (state, Cmd.none)

type theme_color =
  | Background
  | Surface
  | Surface_container
  | Primary
  | Primary_container
  | Outline_variant

let spacing_size value =
  if value < 0 || value > 2147483647 then
    invalid_arg "Spacing must be an integer in 0..2147483647";
  value

module Padding = struct
  type t = { start : int; top : int; end_ : int; bottom : int }

  let only ?(start = 0) ?(top = 0) ?(end_ = 0) ?(bottom = 0) () =
    {
      start = spacing_size start;
      top = spacing_size top;
      end_ = spacing_size end_;
      bottom = spacing_size bottom;
    }

  let symmetric ~horizontal ~vertical =
    only ~start:horizontal ~end_:horizontal ~top:vertical ~bottom:vertical ()

  let all size = symmetric ~horizontal:size ~vertical:size
end

module Gap = struct
  type t = { size : int; color : theme_color option }

  let make ?color size = { size = spacing_size size; color }
end

module Border = struct
  type t = { width : int; color : theme_color }

  let make ~color width = { width = spacing_size width; color }
end

type 'event t =
  | Button of string * 'event option
  | Column of
      bool
      * int list option
      * theme_color option
      * Padding.t option
      * Gap.t option
      * Border.t option
      * int option
      * 'event t list
  | Row of
      int list option
      * theme_color option
      * Padding.t option
      * Gap.t option
      * Border.t option
      * int option
      * 'event t list
  | Text of string
  | Edit of string * string option * 'event
  | Voice_input of 'event
  | Image of string * string * 'event option

module Cmd = struct
  type 'msg t = Empty | Run of (unit -> 'msg option)

  let none = Empty
  let run = function Empty -> Option.none | Run cmd -> cmd ()

  let map f = function
    | Empty -> Empty
    | Run cmd -> Run (fun () -> Option.map f (cmd ()))
end

let button ?event title = Button (title, event)

let column ?(stretch = false) ?weights ?background ?padding ?gap ?border
    ?corner_radius children =
  Column
    ( stretch,
      weights,
      background,
      padding,
      gap,
      border,
      Option.map spacing_size corner_radius,
      children )

let row ?weights ?background ?padding ?gap ?border ?corner_radius children =
  Row
    ( weights,
      background,
      padding,
      gap,
      border,
      Option.map spacing_size corner_radius,
      children )

let text value = Text value
let edit ?text ~event label = Edit (label, text, event)
let voice_input ~event = Voice_input event
let image ?event ~src ~label () = Image (src, label, event)

let rec map f = function
  | Button (title, event) -> Button (title, Option.map f event)
  | Column
      ( stretch,
        weights,
        background,
        padding,
        gap,
        border,
        corner_radius,
        children ) ->
      Column
        ( stretch,
          weights,
          background,
          padding,
          gap,
          border,
          corner_radius,
          List.map (map f) children )
  | Row (weights, background, padding, gap, border, corner_radius, children) ->
      Row
        ( weights,
          background,
          padding,
          gap,
          border,
          corner_radius,
          List.map (map f) children )
  | Text value -> Text value
  | Edit (label, text, event) -> Edit (label, text, f event)
  | Voice_input event -> Voice_input (f event)
  | Image (src, label, event) -> Image (src, label, Option.map f event)

let color_fields key = function
  | None -> []
  | Some color ->
      let name =
        match color with
        | Background -> "background"
        | Surface -> "surface"
        | Surface_container -> "surfaceContainer"
        | Primary -> "primary"
        | Primary_container -> "primaryContainer"
        | Outline_variant -> "outlineVariant"
      in
      [ (key, `String name) ]

let spacing_fields padding gap =
  (match padding with
    | None -> []
    | Some (p : Padding.t) ->
        [
          ( "padding",
            `Assoc
              [
                ("start", `Int p.start);
                ("top", `Int p.top);
                ("end", `Int p.end_);
                ("bottom", `Int p.bottom);
              ] );
        ])
  @
  match gap with
  | None -> []
  | Some (g : Gap.t) ->
      [
        ("gap", `Assoc (("size", `Int g.size) :: color_fields "color" g.color));
      ]

let decoration_fields border corner_radius =
  (match border with
    | None -> []
    | Some (b : Border.t) ->
        [
          ( "border",
            `Assoc
              (("width", `Int b.width) :: color_fields "color" (Some b.color))
          );
        ])
  @
  match corner_radius with
  | None -> []
  | Some radius -> [ ("cornerRadius", `Int radius) ]

let rec to_json event = function
  | Voice_input action ->
      `Assoc [ ("@type", `String "voice_input"); ("event", event action) ]
  | Button (label, action) ->
      let fields = [ ("@type", `String "button"); ("label", `String label) ] in
      `Assoc
        (match action with
        | Some action -> fields @ [ ("event", event action) ]
        | None -> fields)
  | Column
      ( stretch,
        weights,
        background,
        padding,
        gap,
        border,
        corner_radius,
        children ) ->
      let fields =
        [
          ("@type", `String "column");
          ("children", `List (List.map (to_json event) children));
        ]
      in
      let fields =
        if stretch then fields @ [ ("stretch", `Bool true) ] else fields
      in
      let fields =
        fields
        @ color_fields "background" background
        @ spacing_fields padding gap
        @ decoration_fields border corner_radius
      in
      `Assoc
        (match weights with
        | Some weights ->
            fields @ [ ("weights", `List (List.map (fun x -> `Int x) weights)) ]
        | None -> fields)
  | Row (weights, background, padding, gap, border, corner_radius, children) ->
      let fields =
        [
          ("@type", `String "row");
          ("children", `List (List.map (to_json event) children));
        ]
        @ color_fields "background" background
        @ spacing_fields padding gap
        @ decoration_fields border corner_radius
      in
      `Assoc
        (match weights with
        | Some weights ->
            fields @ [ ("weights", `List (List.map (fun x -> `Int x) weights)) ]
        | None -> fields)
  | Text value -> `Assoc [ ("@type", `String "text"); ("text", `String value) ]
  | Edit (label, text, action) ->
      let fields =
        [
          ("@type", `String "input");
          ("label", `String label);
          ("event", event action);
        ]
      in
      `Assoc
        (match text with
        | Some value -> fields @ [ ("text", `String value) ]
        | None -> fields)
  | Image (src, label, action) ->
      let fields =
        [
          ("@type", `String "image");
          ("src", `String src);
          ("label", `String label);
        ]
      in
      `Assoc
        (match action with
        | Some action -> fields @ [ ("event", event action) ]
        | None -> fields)

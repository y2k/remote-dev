type 'event t =
  | Button of string * 'event option
  | Column of 'event t list
  | Row of int list option * 'event t list
  | Text of string
  | Edit of string * string option * 'event
  | Image of string * string

module Cmd = struct
  type 'msg t = Empty | Run of (unit -> 'msg option)

  let none = Empty
  let run = function Empty -> Option.none | Run cmd -> cmd ()

  let map f = function
    | Empty -> Empty
    | Run cmd -> Run (fun () -> Option.map f (cmd ()))
end

let button ?event title = Button (title, event)
let column children = Column children
let row ?weights children = Row (weights, children)
let text value = Text value
let edit ?text ~event label = Edit (label, text, event)
let image ~src ~label = Image (src, label)

let rec map f = function
  | Button (title, event) -> Button (title, Option.map f event)
  | Column children -> Column (List.map (map f) children)
  | Row (weights, children) -> Row (weights, List.map (map f) children)
  | Text value -> Text value
  | Edit (label, text, event) -> Edit (label, text, f event)
  | Image (src, label) -> Image (src, label)

let rec to_json event = function
  | Button (label, action) ->
      let fields = [ ("@type", `String "button"); ("label", `String label) ] in
      `Assoc
        (match action with
        | Some action -> fields @ [ ("event", event action) ]
        | None -> fields)
  | Column children ->
      `Assoc
        [
          ("@type", `String "column");
          ("children", `List (List.map (to_json event) children));
        ]
  | Row (weights, children) ->
      let fields =
        [
          ("@type", `String "row");
          ("children", `List (List.map (to_json event) children));
        ]
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
  | Image (src, label) ->
      `Assoc
        [
          ("@type", `String "image");
          ("src", `String src);
          ("label", `String label);
        ]

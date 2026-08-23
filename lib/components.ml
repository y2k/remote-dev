type 'event t =
  | Button of string * 'event option
  | Column of 'event t list
  | Row of 'event t list
  | Text of string
  | Edit of string * string option * 'event

let button ?event title = Button (title, event)
let column children = Column children
let row children = Row children
let text value = Text value
let edit ?text ~event label = Edit (label, text, event)

let rec map f = function
  | Button (title, event) -> Button (title, Option.map f event)
  | Column children -> Column (List.map (map f) children)
  | Row children -> Row (List.map (map f) children)
  | Text value -> Text value
  | Edit (label, text, event) -> Edit (label, text, f event)

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
  | Row children ->
      `Assoc
        [
          ("@type", `String "row");
          ("children", `List (List.map (to_json event) children));
        ]
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

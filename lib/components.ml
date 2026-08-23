let button ?event title =
  let fields = [ ("@type", `String "button"); ("label", `String title) ] in
  `Assoc
    (match event with
    | Some event -> fields @ [ ("event", event) ]
    | None -> fields)

let column children =
  `Assoc [ ("@type", `String "column"); ("children", `List children) ]

let row children =
  `Assoc [ ("@type", `String "row"); ("children", `List children) ]

let text value = `Assoc [ ("@type", `String "text"); ("text", `String value) ]

let edit ?text ~event label =
  let fields =
    [ ("@type", `String "input"); ("label", `String label); ("event", event) ]
  in
  `Assoc
    (match text with
    | Some value -> fields @ [ ("text", `String value) ]
    | None -> fields)

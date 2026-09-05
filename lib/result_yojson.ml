let result_to_yojson ok_to_yojson error_to_yojson = function
  | Result.Ok value -> `List [ `String "Ok"; ok_to_yojson value ]
  | Result.Error value -> `List [ `String "Error"; error_to_yojson value ]

let result_of_yojson ok_of_yojson error_of_yojson = function
  | `List [ `String "Ok"; value ] ->
      Result.map (fun value -> Result.Ok value) (ok_of_yojson value)
  | `List [ `String "Error"; value ] ->
      Result.map (fun value -> Result.Error value) (error_of_yojson value)
  (* ponytail: Error detail is internal; add decoder paths if callers expose it. *)
  | _ -> Result.Error "result"

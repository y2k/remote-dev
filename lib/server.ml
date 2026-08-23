let response ?(body = "") meth target =
  match (meth, target) with
  | `POST, "/" -> (
      match Home.response body with
      | Ok body -> (`OK, body, "application/json")
      | Error message -> (`Bad_request, message, "text/plain"))
  | _ -> (`Not_found, "Not Found", "text/plain")

let respond { Gluten.reqd; _ } =
  let request = Httpun.Reqd.request reqd in
  let reply (status, body, content_type) =
    let headers =
      Httpun.Headers.of_list
        [
          ("content-length", string_of_int (String.length body));
          ("content-type", content_type);
        ]
    in
    Httpun.Reqd.respond_with_string reqd
      (Httpun.Response.create ~headers status)
      body
  in
  (* ponytail: trusted local demo; bound bodies if the server becomes public. *)
  let body = Buffer.create 128 in
  let rec read () =
    Httpun.Body.Reader.schedule_read
      (Httpun.Reqd.request_body reqd)
      ~on_eof:(fun () ->
        reply
          (response ~body:(Buffer.contents body) request.meth request.target))
      ~on_read:(fun chunk ~off ~len ->
        Buffer.add_string body (Bigstringaf.substring chunk ~off ~len);
        read ())
  in
  read ()

let run ~net =
  Eio.Switch.run @@ fun sw ->
  let socket =
    Eio.Net.listen ~sw ~reuse_addr:true ~backlog:128 net
      (`Tcp (Eio.Net.Ipaddr.V4.any, 8080))
  in
  let handler =
    Httpun_eio.Server.create_connection_handler ~sw
      ~request_handler:(fun _ reqd -> respond reqd)
      ~error_handler:(fun _ ?request:_ _ start_response ->
        Httpun.Body.Writer.close (start_response Httpun.Headers.empty))
  in
  Eio.Net.run_server socket ~on_error:raise (fun client client_addr ->
      handler client_addr client)

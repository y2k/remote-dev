let response ?(body = "") meth target =
  match (meth, target) with
  | `POST, "/" -> (
      match Home.response body with
      | Ok body -> (`OK, body, "application/json")
      | Error message -> (`Bad_request, message, "text/plain"))
  | _ -> (`Not_found, "Not Found", "text/plain")

let stream_headers =
  Httpun.Headers.of_list
    [
      ("content-type", "application/x-ndjson"); ("transfer-encoding", "chunked");
    ]

let respond ~domain_mgr { Gluten.reqd; _ } =
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
  let stream { Home.cwd; prompt } =
    let writer =
      Httpun.Reqd.respond_with_streaming ~flush_headers_immediately:true reqd
        (Httpun.Response.create ~headers:stream_headers `OK)
    in
    let updates = Eio.Stream.create 1 in
    let write document =
      Httpun.Body.Writer.write_string writer (document ^ "\n");
      let flushed, resolve = Eio.Promise.create () in
      Httpun.Body.Writer.flush writer (fun _ -> Eio.Promise.resolve resolve ());
      Eio.Promise.await flushed
    in
    let producer () =
      let result =
        try
          Eio.Domain_manager.run domain_mgr (fun () ->
              Runtime.stream_claude cwd prompt (fun delta ->
                  Eio.Stream.add updates (`Delta delta)));
          `Done
        with exn -> `Error (Printexc.to_string exn)
      in
      Eio.Stream.add updates result
    in
    let rec consumer () =
      match Eio.Stream.take updates with
      | `Delta delta ->
          write (Home.stream_output delta);
          consumer ()
      | `Done -> ()
      | `Error error -> write (Home.stream_error error)
    in
    Eio.Fiber.both producer consumer;
    Httpun.Body.Writer.close writer
  in
  (* ponytail: trusted local demo; bound bodies if the server becomes public. *)
  let body = Buffer.create 128 in
  let rec read () =
    Httpun.Body.Reader.schedule_read
      (Httpun.Reqd.request_body reqd)
      ~on_eof:(fun () ->
        let body = Buffer.contents body in
        match Home.start_claude_stream body with
        | Some request -> stream request
        | None -> reply (response ~body request.meth request.target))
      ~on_read:(fun chunk ~off ~len ->
        Buffer.add_string body (Bigstringaf.substring chunk ~off ~len);
        read ())
  in
  read ()

let run ~net ~domain_mgr =
  Eio.Switch.run @@ fun sw ->
  let socket =
    Eio.Net.listen ~sw ~reuse_addr:true ~backlog:128 net
      (`Tcp (Eio.Net.Ipaddr.V4.any, 8080))
  in
  let handler =
    Httpun_eio.Server.create_connection_handler ~sw
      ~request_handler:(fun _ reqd -> respond ~domain_mgr reqd)
      ~error_handler:(fun _ ?request:_ _ start_response ->
        Httpun.Body.Writer.close (start_response Httpun.Headers.empty))
  in
  Eio.Net.run_server socket ~on_error:raise (fun client client_addr ->
      handler client_addr client)

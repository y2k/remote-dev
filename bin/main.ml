let () =
  let environment =
    try Remote_dev.Runtime.parse_args Sys.argv with
    | Arg.Bad message ->
        prerr_string message;
        exit 2
    | Arg.Help message ->
        print_string message;
        exit 0
  in
  Remote_dev.Runtime.with_unix_process (fun () ->
      Eio_main.run (fun env ->
          Remote_dev.Server.run environment ~net:(Eio.Stdenv.net env)
            ~domain_mgr:(Eio.Stdenv.domain_mgr env)))

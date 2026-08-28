let () =
  Remote_dev.Runtime.with_unix_process (fun () ->
      Eio_main.run (fun env ->
          Remote_dev.Server.run ~net:(Eio.Stdenv.net env)
            ~domain_mgr:(Eio.Stdenv.domain_mgr env)))

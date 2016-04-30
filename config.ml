open Mirage

let my_noop_job =
  foreign "Noop.Job" (Mirage.job)
  (* https://mirage.github.io/functoria/Functoria.html#VALjob *)

let hello_world =
  foreign "Hello_world.Job" (Mirage.console @-> Mirage.job)
  (* "@->" is Functoria syntax: https://mirage.github.io/functoria/Functoria.html#VAL%28@-%3E%29 *)
  (* Mirage.console: https://mirage.github.io/mirage/Mirage.html#VALconsole *)

let () =
  Mirage.register "mything"
  [ my_noop_job
  ; hello_world $ Mirage.default_console
  (* the dollar sign is also Functoria syntax:
     https://mirage.github.io/functoria/Functoria.html#VAL%28$%29 *)
  ]

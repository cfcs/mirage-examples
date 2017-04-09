open Mirage

let my_hello_xyz =
  let key =
    let doc = Mirage.Key.Arg.info
      ~doc:"Specify a name for the hello_world_xyz job"
      ["name"]
    in
    Mirage.Key.(create "my_name" Arg.(opt string "John Doe" doc) )
  in
  Mirage.foreign
    ~keys:[Mirage.Key.abstract key]
      (* https://mirage.github.io/functoria/Functoria_key.html#VALabstract *)
    "Hello_xyz.Job"
    (Mirage.console @-> Mirage.job)

let () =
  Mirage.register
    "hello_xyz"
    [ my_hello_xyz $ Mirage.default_console
    ]

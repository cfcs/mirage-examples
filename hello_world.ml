module type Job_t =
(* note that providing a signature / module type like this is entirely optional *)
functor (Console : V1_LWT.CONSOLE) ->
sig
  val start : Console.t -> unit Lwt.t
end

module Job : Job_t =
functor (Console : V1_LWT.CONSOLE) ->
struct
  let start (my_console : Console.t) =
    Lwt.return (Console.log my_console "Hello, World!")
end

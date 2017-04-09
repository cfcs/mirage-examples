module type Job_t =
functor (Console : Mirage_console.S) ->
sig
  val start : Console.t -> unit Console.io Lwt.t
end

module Job : Job_t =
functor (Console : Mirage_console.S) ->
struct
  let start (my_console : Console.t) =
    Lwt.return @@
    Console.log my_console
      ("Hello, " ^ Key_gen.(my_name () ) ^ "!" )
end

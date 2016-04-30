module type Job_t =
sig
  val start : unit Lwt.t
end

module Job : Job_t =
struct
  let start = Lwt.return_unit
end
